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
    private(set) var upsertCalls: [(table: String, payload: [String: AnyJSON])] = []
    private(set) var deleteCalls: [(table: String, id: UUID)] = []
    private(set) var selectCalls: [(table: String, userId: String, updatedAfter: String)] = []

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

    func delete(table: String, id: UUID) async throws {
        let index = deleteCalls.count
        deleteCalls.append((table, id))
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
                updatedAt: now
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

    func testPerformSync_pullUpdatesTimestamp() async throws {
        let future = Date(timeIntervalSinceNow: 3600) // 1 hour from now
        mockClient.remoteFavorites = [
            RemoteFavorite(
                id: UUID(),
                userId: testUserId,
                itemType: "produce",
                itemId: "carrot",
                dateAdded: future,
                updatedAt: future
            )
        ]

        let beforeSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")

        await syncService.performSync(userId: testUserId)

        let afterSync = UserDefaults.standard.double(forKey: "lastSyncTimestamp")
        XCTAssertGreaterThan(afterSync, beforeSync, "lastSyncTimestamp should advance after pulling newer data")
        XCTAssertEqual(afterSync, future.timeIntervalSince1970, accuracy: 1.0)
    }
}
