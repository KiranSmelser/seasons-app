import Foundation
import SwiftData
import Supabase

@Observable
@MainActor
final class SyncCoordinator {
    private let syncService: SyncService
    private let authService: AuthService
    private var debounceTask: Task<Void, Never>?

    init(syncService: SyncService, authService: AuthService) {
        self.syncService = syncService
        self.authService = authService
    }

    func notifyMutation() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            guard let user = authService.currentUser else { return }
            await syncService.pushOnly(userId: user.id)
        }
    }

    func cancelPendingSync() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    static var preview: SyncCoordinator {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: CarbonLog.self, Favorite.self, PendingSyncDeletion.self,
            configurations: config
        )
        let syncService = SyncService(client: NoOpSyncClient(), modelContainer: container)
        return SyncCoordinator(syncService: syncService, authService: AuthService())
    }
}

private struct NoOpSyncClient: SyncClient {
    func upsert(table: String, payload: [String: AnyJSON]) async throws {}
    func delete(table: String, id: UUID) async throws {}
    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T] { [] }
}
