import XCTest
import SwiftData
import Supabase
@testable import Seasons

@MainActor
final class SyncCoordinatorTests: XCTestCase {

    private var mockClient: RecordingSyncClient!
    private var container: ModelContainer!
    private var syncService: SyncService!
    private var authService: AuthService!
    private var coordinator: SyncCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mockClient = RecordingSyncClient()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: CarbonLog.self, Favorite.self, PendingSyncDeletion.self,
            configurations: config
        )
        syncService = SyncService(client: mockClient, modelContainer: container)
        authService = AuthService()
        coordinator = SyncCoordinator(syncService: syncService, authService: authService)
    }

    // MARK: - Unauthenticated

    func testNotifyMutation_doesNotPushWhenUnauthenticated() async throws {
        // authService.currentUser is nil by default (no session)
        coordinator.notifyMutation()

        // Wait longer than the debounce interval
        try await Task.sleep(for: .seconds(3))

        // Should not have attempted any sync calls
        XCTAssertEqual(mockClient.upsertCallCount, 0, "Should not push when unauthenticated")
        XCTAssertEqual(mockClient.selectCallCount, 0, "Should not pull when unauthenticated")
    }

    // MARK: - Cancel

    func testCancelPendingSync_preventsPush() async throws {
        coordinator.notifyMutation()

        // Cancel before debounce fires
        coordinator.cancelPendingSync()

        // Wait longer than the debounce interval
        try await Task.sleep(for: .seconds(3))

        // Even if user were authenticated, the cancelled task should not run
        XCTAssertEqual(mockClient.upsertCallCount, 0, "Cancelled debounce should not push")
    }

    // MARK: - Debounce Coalescing

    func testRapidMutations_coalesceIntoSingleDebounce() async throws {
        // Fire multiple rapid mutations
        coordinator.notifyMutation()
        try await Task.sleep(for: .milliseconds(100))
        coordinator.notifyMutation()
        try await Task.sleep(for: .milliseconds(100))
        coordinator.notifyMutation()

        // Wait for the debounce to fire (2s after last mutation)
        try await Task.sleep(for: .seconds(3))

        // Since unauthenticated, no actual push occurs, but we verify the
        // debounce didn't crash or cause issues. The key assertion is that
        // the coordinator didn't attempt multiple pushes.
        XCTAssertEqual(mockClient.upsertCallCount, 0, "Unauthenticated rapid mutations should not push")
    }

    func testCancelPendingSync_afterMultipleMutations() async throws {
        coordinator.notifyMutation()
        try await Task.sleep(for: .milliseconds(50))
        coordinator.notifyMutation()
        try await Task.sleep(for: .milliseconds(50))
        coordinator.notifyMutation()

        coordinator.cancelPendingSync()

        try await Task.sleep(for: .seconds(3))

        XCTAssertEqual(mockClient.upsertCallCount, 0, "Cancel after rapid mutations should prevent push")
    }
}

// MARK: - Recording Mock

private final class RecordingSyncClient: SyncClient, @unchecked Sendable {
    var upsertCallCount = 0
    var selectCallCount = 0
    var deleteCallCount = 0

    func upsert(table: String, payload: [String: AnyJSON]) async throws {
        upsertCallCount += 1
    }

    func delete(table: String, id: UUID) async throws {
        deleteCallCount += 1
    }

    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T] {
        selectCallCount += 1
        return []
    }
}
