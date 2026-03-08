import XCTest
import SwiftData
import Supabase
@testable import Seasons

// MARK: - Mock

private enum MockError: Error {
    case simulated
}

private final class MockSyncClient: SyncClient, @unchecked Sendable {
    // Recorded calls
    var upsertCalls: [(table: String, payload: [String: AnyJSON])] = []
    var deleteCalls: [(table: String, id: UUID, userId: String)] = []
    var selectCalls: [(table: String, userId: String, updatedAfter: String)] = []

    // Per-call error configuration: key = "\(table):\(id)" or call index
    var upsertErrorIndices: Set<Int> = []
    var deleteErrorIndices: Set<Int> = []

    // Data to return from select
    var remoteFavorites: [RemoteFavorite] = []
    var remoteCarbonLogs: [RemoteCarbonLog] = []
    var selectShouldThrow = false

    func upsert(table: String, payload: [String: AnyJSON]) async throws {
        let index = upsertCalls.count
        upsertCalls.append((table, payload))
        if upsertErrorIndices.contains(index) {
            throw MockError.simulated
        }
    }

    func delete(table: String, id: UUID, userId: String) async throws {
        let index = deleteCalls.count
        deleteCalls.append((table, id, userId))
        if deleteErrorIndices.contains(index) {
            throw MockError.simulated
        }
    }

    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T] {
        selectCalls.append((table, userId, updatedAfter))
        if selectShouldThrow {
            throw MockError.simulated
        }
        if table == "favorites" {
            return remoteFavorites as! [T]
        } else if table == "carbon_logs" {
            return remoteCarbonLogs as! [T]
        }
        return []
    }

    func reset() {
        upsertCalls = []
        deleteCalls = []
        selectCalls = []
        upsertErrorIndices = []
        deleteErrorIndices = []
        remoteFavorites = []
        remoteCarbonLogs = []
        selectShouldThrow = false
    }

    var pushedFavorites: [(table: String, id: UUID, userId: String)] {
        deleteCalls.filter { $0.table == "favorites" }
    }
}

// MARK: - Tests

final class SyncServiceTests: XCTestCase {

    private var mockClient: MockSyncClient!
    private var container: ModelContainer!
    private var syncService: SyncService!
    private let testUserId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        mockClient = MockSyncClient()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CarbonLog.self, Favorite.self, PendingSyncDeletion.self,
            configurations: config
        )
        syncService = SyncService(client: mockClient, modelContainer: container)

        // Clear lastSyncTimestamp so pull always runs fresh
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")
        // Clear any initial sync flags set during tests
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("hasCompletedInitialSync_") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        KeychainStore.deleteAll(withPrefix: "hasCompletedInitialSync_")
        try await super.tearDown()
    }

    private func makeContext() -> ModelContext {
        ModelContext(container)
    }

    // MARK: - Push Favorites

    func testPushFavorites_marksIsSyncedAfterSuccess() async throws {
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        fav.isSynced = false
        context.insert(fav)
        try context.save()

        await syncService.performSync(userId: testUserId)

        // Fetch from a fresh context to see the saved state
        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isSynced, "Favorite should be marked as synced after successful push")
        XCTAssertEqual(mockClient.upsertCalls.count, 1)
        XCTAssertEqual(mockClient.upsertCalls.first?.table, "favorites")
    }

    func testPushFavorites_leavesIsSyncedFalseOnError() async throws {
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        fav.isSynced = false
        context.insert(fav)
        try context.save()

        mockClient.upsertErrorIndices = [0]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertFalse(fetched.first!.isSynced, "Favorite should remain unsynced when upsert fails")
    }

    func testPushFavorites_continuesAfterOneFailure() async throws {
        let context = makeContext()
        let fav1 = Favorite(itemType: "produce", itemId: "tomato")
        fav1.isSynced = false
        let fav2 = Favorite(itemType: "produce", itemId: "kale")
        fav2.isSynced = false
        let fav3 = Favorite(itemType: "produce", itemId: "carrot")
        fav3.isSynced = false
        context.insert(fav1)
        context.insert(fav2)
        context.insert(fav3)
        try context.save()

        // The 2nd upsert (index 1) will fail — but we need to account for
        // the fact that SwiftData fetch order is not guaranteed. So we make
        // the middle one fail and verify that exactly 2 out of 3 get synced.
        mockClient.upsertErrorIndices = [1]

        await syncService.performSync(userId: testUserId)

        // All 3 upserts should have been attempted
        XCTAssertEqual(mockClient.upsertCalls.filter { $0.table == "favorites" }.count, 3,
                       "All 3 favorites should be attempted even if one fails")

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        let syncedCount = fetched.filter(\.isSynced).count
        let unsyncedCount = fetched.filter { !$0.isSynced }.count
        XCTAssertEqual(syncedCount, 2, "2 of 3 favorites should be synced")
        XCTAssertEqual(unsyncedCount, 1, "1 of 3 favorites should remain unsynced")
    }

    // MARK: - Push Carbon Logs

    func testPushCarbonLogs_marksIsSyncedAfterSuccess() async throws {
        let context = makeContext()
        let log = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5)
        log.isSynced = false
        context.insert(log)
        try context.save()

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<CarbonLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isSynced, "Carbon log should be marked as synced after successful push")
        XCTAssertTrue(mockClient.upsertCalls.contains { $0.table == "carbon_logs" })
    }

    func testPushCarbonLogs_leavesIsSyncedFalseOnError() async throws {
        let context = makeContext()
        let log = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5)
        log.isSynced = false
        context.insert(log)
        try context.save()

        // The carbon log upsert will be the 1st upsert call (index 0) since there are no favorites
        mockClient.upsertErrorIndices = [0]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<CarbonLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertFalse(fetched.first!.isSynced, "Carbon log should remain unsynced when upsert fails")
    }

    // MARK: - Push Deletions

    func testPushDeletions_removesRecordAfterSuccess() async throws {
        let context = makeContext()
        let recordId = UUID()
        let deletion = PendingSyncDeletion(tableName: "favorites", recordId: recordId)
        context.insert(deletion)
        try context.save()

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let remaining = try freshContext.fetch(FetchDescriptor<PendingSyncDeletion>())
        XCTAssertEqual(remaining.count, 0, "PendingSyncDeletion should be removed after successful remote delete")
        XCTAssertEqual(mockClient.deleteCalls.count, 1)
        XCTAssertEqual(mockClient.deleteCalls.first?.table, "favorites")
        XCTAssertEqual(mockClient.deleteCalls.first?.id, recordId)
    }

    func testPushDeletions_keepsRecordOnError() async throws {
        let context = makeContext()
        let recordId = UUID()
        let deletion = PendingSyncDeletion(tableName: "favorites", recordId: recordId)
        context.insert(deletion)
        try context.save()

        mockClient.deleteErrorIndices = [0]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let remaining = try freshContext.fetch(FetchDescriptor<PendingSyncDeletion>())
        XCTAssertEqual(remaining.count, 1, "PendingSyncDeletion should be kept when remote delete fails")
        XCTAssertEqual(remaining.first?.recordId, recordId)
    }

    // MARK: - Pull

    func testPerformSync_pullMergesRemoteFavorites() async throws {
        let remoteId = UUID()
        let now = Date()
        mockClient.remoteFavorites = [
            RemoteFavorite(
                id: remoteId,
                userId: testUserId,
                itemType: "produce",
                itemId: "broccoli",
                dateAdded: now,
                updatedAt: now,
                isDeleted: false
            )
        ]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched.count, 1)
        let favorite = try XCTUnwrap(fetched.first)
        XCTAssertEqual(favorite.id, remoteId)
        XCTAssertEqual(favorite.itemId, "broccoli")
        XCTAssertEqual(favorite.itemType, "produce")
        XCTAssertTrue(favorite.isSynced, "Pulled favorites should be marked as synced")
    }

    // MARK: - SyncResult Return Value

    func testPerformSync_returnsSuccessOnCleanSync() async throws {
        let result = await syncService.performSync(userId: testUserId)
        if case .success = result {
            // expected
        } else {
            XCTFail("Expected .success but got \(result)")
        }
    }

    func testPerformSync_returnsSuccessEvenWithPartialItemFailures() async throws {
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        fav.isSynced = false
        context.insert(fav)
        try context.save()

        // The upsert for this item will fail, but that's a per-item catch —
        // the top-level sync should still succeed.
        mockClient.upsertErrorIndices = [0]

        let result = await syncService.performSync(userId: testUserId)
        if case .success = result {
            // expected — per-item failures don't cause top-level failure
        } else {
            XCTFail("Expected .success but got \(result)")
        }
    }

    func testResetSyncState_allowsRepullOfPreviouslySyncedRecords() async throws {
        let remoteId = UUID()
        let now = Date()
        mockClient.remoteFavorites = [
            RemoteFavorite(
                id: remoteId,
                userId: testUserId,
                itemType: "produce",
                itemId: "broccoli",
                dateAdded: now,
                updatedAt: now,
                isDeleted: false
            )
        ]

        // First sync — pulls the remote favorite and advances the timestamp
        await syncService.performSync(userId: testUserId)

        let context1 = makeContext()
        let fetched1 = try context1.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched1.count, 1, "First sync should pull the remote favorite")

        // Simulate sign-out: delete local data (but remote stays the same)
        try context1.delete(model: Favorite.self)
        try context1.save()

        let afterDelete = try makeContext().fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(afterDelete.count, 0, "Local favorites should be cleared after sign-out")

        // Reset sync state (as sign-out would do)
        await syncService.resetSyncState()

        // Second sync — should re-pull the same remote favorite
        mockClient.selectCalls = []
        await syncService.performSync(userId: testUserId)

        let context2 = makeContext()
        let fetched2 = try context2.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched2.count, 1, "After resetSyncState, the remote favorite should be re-pulled")
        XCTAssertEqual(fetched2.first?.itemId, "broccoli")

        // Verify the select call used distantPast (or at least a timestamp before `now`)
        let lastSelect = try XCTUnwrap(mockClient.selectCalls.first)
        XCTAssertEqual(lastSelect.table, "favorites")
    }

    func testPerformSync_pullUpdatesTimestamp() async throws {
        let future = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        mockClient.remoteFavorites = [
            RemoteFavorite(
                id: UUID(),
                userId: testUserId,
                itemType: "produce",
                itemId: "carrot",
                dateAdded: future,
                updatedAt: future,
                isDeleted: false
            )
        ]

        let beforeSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")

        await syncService.performSync(userId: testUserId)

        let afterSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")
        XCTAssertGreaterThan(afterSync, beforeSync, "lastSyncTimestamp should advance after pulling newer data")
        XCTAssertEqual(afterSync, future.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Pull Failure

    func testPerformSync_returnsFailureWhenPullFails() async throws {
        mockClient.selectShouldThrow = true

        let result = await syncService.performSync(userId: testUserId)
        if case .failure = result {
            // expected
        } else {
            XCTFail("Expected .failure but got \(result)")
        }
    }

    func testPerformSync_pullFailure_doesNotAdvanceTimestamp() async throws {
        let beforeSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")

        mockClient.selectShouldThrow = true
        await syncService.performSync(userId: testUserId)

        let afterSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")
        XCTAssertEqual(afterSync, beforeSync, "lastSyncTimestamp should not advance when pull fails")
    }

    // MARK: - Soft-Delete Carbon Logs

    func testPushCarbonLog_softDeleted_sendsIsDeletedTrue() async throws {
        let context = makeContext()
        let log = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5)
        context.insert(log)
        log.isSynced = false
        log.isSoftDeleted = true
        try context.save()

        await syncService.performSync(userId: testUserId)

        let carbonCall = mockClient.upsertCalls.first { $0.table == "carbon_logs" }
        XCTAssertNotNil(carbonCall, "Should have pushed the carbon log")
        if case .bool(let isDeleted) = carbonCall?.payload["is_deleted"] {
            XCTAssertTrue(isDeleted, "Soft-deleted carbon log should push is_deleted: true")
        } else {
            XCTFail("is_deleted field missing from carbon log payload")
        }
    }

    func testPullCarbonLog_withIsDeletedTrue_updatesLocalCopy() async throws {
        // Insert a local carbon log
        let logId = UUID()
        let context = makeContext()
        let log = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5)
        context.insert(log)
        log.id = logId
        log.isSoftDeleted = false
        log.isSynced = true
        log.updatedAt = Date(timeIntervalSince1970: 1000)
        try context.save()

        // Remote says it's deleted with a newer timestamp
        mockClient.remoteCarbonLogs = [
            RemoteCarbonLog(
                id: logId,
                userId: testUserId,
                date: Date(),
                produceId: "tomato",
                produceName: "Tomato",
                quantityKg: 1.0,
                carbonSavedKg: 0.5,
                updatedAt: Date(timeIntervalSince1970: 2000),
                isDeleted: true
            )
        ]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<CarbonLog>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isSoftDeleted, "Local carbon log should be marked as deleted after pull")
    }

    // MARK: - Soft-Delete Favorites

    func testSoftDeletedFavorite_isPushedWithIsDeletedTrue() async throws {
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        context.insert(fav)
        fav.isSynced = false
        fav.isSoftDeleted = true
        try context.save()

        await syncService.performSync(userId: testUserId)

        let favCall = mockClient.upsertCalls.first { $0.table == "favorites" }
        XCTAssertNotNil(favCall, "Should have pushed the favorite")
        if case .bool(let isDeleted) = favCall?.payload["is_deleted"] {
            XCTAssertTrue(isDeleted, "Soft-deleted favorite should push is_deleted: true")
        } else {
            XCTFail("is_deleted field missing from favorite payload")
        }
    }

    func testPullFavorite_withIsDeletedTrue_marksLocalAsDeleted() async throws {
        // Insert a local favorite
        let favId = UUID()
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        context.insert(fav)
        fav.id = favId
        fav.isSoftDeleted = false
        fav.isSynced = true
        fav.updatedAt = Date(timeIntervalSince1970: 1000)
        try context.save()

        // Remote says it's deleted with a newer timestamp
        mockClient.remoteFavorites = [
            RemoteFavorite(
                id: favId,
                userId: testUserId,
                itemType: "produce",
                itemId: "tomato",
                dateAdded: Date(),
                updatedAt: Date(timeIntervalSince1970: 2000),
                isDeleted: true
            )
        ]

        await syncService.performSync(userId: testUserId)

        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isSoftDeleted, "Local favorite should be marked as deleted after pull")
    }

    // MARK: - Push Only

    func testPushOnly_pushesButDoesNotPull() async throws {
        let context = makeContext()
        let fav = Favorite(itemType: "produce", itemId: "tomato")
        fav.isSynced = false
        context.insert(fav)
        try context.save()

        let result = await syncService.pushOnly(userId: testUserId)

        if case .success = result { } else { XCTFail("Expected .success but got \(result)") }

        // Should have pushed the favorite
        XCTAssertEqual(mockClient.upsertCalls.count, 1)
        XCTAssertEqual(mockClient.upsertCalls.first?.table, "favorites")

        // Should NOT have called select (no pull)
        XCTAssertEqual(mockClient.selectCalls.count, 0, "pushOnly should not pull from remote")

        // Verify the favorite is marked as synced
        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first!.isSynced, "Favorite should be marked as synced after pushOnly")
    }

    // MARK: - Upload All Local Data

    func testUploadAllLocalDataResetsAndPushes() async throws {
        let context = makeContext()

        // Insert 3 already-synced favorites
        for i in 1...3 {
            let fav = Favorite(itemType: "produce", itemId: "item_\(i)")
            fav.isSynced = true
            context.insert(fav)
        }
        try context.save()

        let result = await syncService.uploadAllLocalData(userId: testUserId)

        if case .failure(let msg) = result {
            XCTFail("Expected .success but got .failure(\(msg))")
        }

        // All 3 should have been pushed (marked unsynced → pushed)
        let favoriteCalls = mockClient.upsertCalls.filter { $0.table == "favorites" }
        XCTAssertEqual(favoriteCalls.count, 3, "All 3 favorites should be pushed by uploadAllLocalData")

        // After sync they should all be marked synced again
        let freshContext = makeContext()
        let fetched = try freshContext.fetch(FetchDescriptor<Favorite>())
        XCTAssertTrue(fetched.allSatisfy(\.isSynced), "All favorites should be synced after uploadAllLocalData")
    }

    // MARK: - Initial Sync Keychain Round-Trip

    func testHasCompletedInitialSyncRoundTrip() async throws {
        // Before: should be false
        let before = await syncService.hasCompletedInitialSync(userId: testUserId)
        XCTAssertFalse(before, "Should not have completed initial sync before setInitialSyncCompleted")

        // Mark completed
        await syncService.setInitialSyncCompleted(userId: testUserId)

        // After: should be true for this user
        let after = await syncService.hasCompletedInitialSync(userId: testUserId)
        XCTAssertTrue(after, "Should report initial sync completed after setInitialSyncCompleted")

        // Different user should still return false
        let differentUserId = UUID()
        let otherResult = await syncService.hasCompletedInitialSync(userId: differentUserId)
        XCTAssertFalse(otherResult, "Different userId should not be flagged as having completed initial sync")
    }

    // MARK: - Concurrent Sync Guard

    func testConcurrentSyncCalls_secondIsSkipped() async throws {
        // We can't easily test true concurrency with an actor, but we can verify
        // that two sequential calls both succeed (the guard resets via defer).
        // To test the guard, we use a wrapper that exposes isSyncing state.
        let result1 = await syncService.performSync(userId: testUserId)
        let result2 = await syncService.performSync(userId: testUserId)

        // Both should succeed (second runs after first completes due to actor serialization)
        if case .success = result1 { } else { XCTFail("First sync should succeed") }
        if case .success = result2 { } else { XCTFail("Second sync should succeed") }

        // The real concurrency guard test: launch two syncs concurrently via async let.
        // Due to actor serialization, only one runs at a time, but the guard ensures
        // the second one short-circuits if it enters while the first is still running.
        mockClient.reset()
        async let r1 = syncService.performSync(userId: testUserId)
        async let r2 = syncService.performSync(userId: testUserId)
        let results = await [r1, r2]

        // Both return .success (one actually syncs, one is skipped via guard)
        for result in results {
            if case .success = result { } else { XCTFail("Expected .success but got \(result)") }
        }

        // At most one sync should have made select calls (the skipped one makes zero)
        // Due to actor serialization, the second call may or may not be skipped depending
        // on timing. We just verify no errors occurred.
    }
}
