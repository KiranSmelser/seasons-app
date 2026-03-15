import Foundation
import SwiftData
import Supabase
import os

/// Abstraction over the auth layer consumed by SyncCoordinator.
/// Enables unit-testing without a live Supabase session.
protocol AuthProviding {
    var currentUserId: UUID? { get }
}

@Observable
@MainActor
final class SyncCoordinator {
    private let syncService: SyncService
    private let authService: any AuthProviding
    private var debounceTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "SyncCoordinator")

    init(syncService: SyncService, authService: any AuthProviding) {
        self.syncService = syncService
        self.authService = authService
    }

    func notifyMutation() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            guard let userId = authService.currentUserId else {
                logger.warning("notifyMutation: skipping push — no signed-in user")
                return
            }
            logger.debug("notifyMutation: pushing for user \(userId, privacy: .private)")
            await syncService.pushOnly(userId: userId)
        }
    }

    func cancelPendingSync() {
        debounceTask?.cancel()
        debounceTask = nil
    }

    func deleteAllUserData() async throws {
        guard let userId = authService.currentUserId else {
            logger.warning("deleteAllUserData: no signed-in user")
            return
        }
        cancelPendingSync()
        try await syncService.deleteAllUserData(userId: userId)
    }

    static var preview: SyncCoordinator {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(
            for: CarbonLog.self, Favorite.self, PendingSyncDeletion.self,
            configurations: config
        ) else {
            fatalError("Failed to create in-memory ModelContainer for preview.")
        }
        let syncService = SyncService(client: NoOpSyncClient(), modelContainer: container)
        return SyncCoordinator(syncService: syncService, authService: AuthService())
    }
}

private struct NoOpSyncClient: SyncClient {
    func upsert(table: String, payload: [String: AnyJSON]) async throws {}
    func delete(table: String, id: UUID, userId: String) async throws {}
    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T] { [] }
    func deleteAllRows(table: String, userId: String) async throws {}
}
