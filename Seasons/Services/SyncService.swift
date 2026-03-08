import Foundation
import SwiftData
import Supabase
import os

enum SyncResult {
    case success
    case failure(String)
}

/// Whitelist of Supabase table names the app is permitted to read/write/delete.
/// Any `PendingSyncDeletion` whose `tableName` is not in this enum is skipped.
private enum SyncTable: String {
    case favorites
    case carbonLogs = "carbon_logs"
}

actor SyncService {
    private let client: SyncClient
    private let modelContainer: ModelContainer
    private var isSyncing = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "SyncService")

    /// When `pushOnly` is called while another sync is in progress it sets this
    /// instead of silently dropping the request. The pending push fires as soon
    /// as the active sync finishes.
    private var pendingPushUserId: UUID?

    private let lastSyncKey = "lastSyncTimestamp"

    private var lastSyncTimestamp: Date {
        get {
            let interval = UserDefaults.standard.double(forKey: lastSyncKey)
            return interval > 0 ? Date(timeIntervalSince1970: interval) : .distantPast
        }
    }

    private func setLastSyncTimestamp(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastSyncKey)
    }

    init(client: SyncClient, modelContainer: ModelContainer) {
        self.client = client
        self.modelContainer = modelContainer
    }

    private let initialSyncPrefix = "hasCompletedInitialSync_"

    func resetSyncState() {
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        // Clear both Keychain and any legacy UserDefaults flags.
        KeychainStore.deleteAll(withPrefix: initialSyncPrefix)
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix(initialSyncPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func hasCompletedInitialSync(userId: UUID) -> Bool {
        let key = "\(initialSyncPrefix)\(userId.uuidString)"

        // Check Keychain first.
        if KeychainStore.bool(forKey: key) { return true }

        // One-time migration: if the flag was stored in UserDefaults before the
        // Keychain change, promote it so we don't re-run uploadAllLocalData.
        if UserDefaults.standard.bool(forKey: key) {
            KeychainStore.setBool(true, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }

        return false
    }

    func setInitialSyncCompleted(userId: UUID) {
        KeychainStore.setBool(true, forKey: "\(initialSyncPrefix)\(userId.uuidString)")
    }

    @discardableResult
    func performSync(userId: UUID) async -> SyncResult {
        guard !isSyncing else { return .success }
        isSyncing = true
        defer { isSyncing = false; flushPendingPush() }
        return await performSyncInternal(userId: userId)
    }

    @discardableResult
    func pushOnly(userId: UUID) async -> SyncResult {
        guard !isSyncing else {
            // Another sync is already in progress. Queue this push so it fires
            // automatically when the active sync finishes.
            logger.debug("pushOnly: sync in progress, queuing push for later")
            pendingPushUserId = userId
            return .success
        }
        isSyncing = true
        defer { isSyncing = false; flushPendingPush() }
        logger.debug("pushOnly: starting push for user \(userId, privacy: .private)")
        do {
            let context = ModelContext(modelContainer)
            try await pushChanges(userId: userId, context: context)
            try context.save()
            logger.debug("pushOnly: completed successfully")
            return .success
        } catch {
            logger.error("pushOnly failed: \(error.localizedDescription, privacy: .public)")
            return .failure(error.localizedDescription)
        }
    }

    @discardableResult
    func uploadAllLocalData(userId: UUID) async -> SyncResult {
        guard !isSyncing else { return .success }
        isSyncing = true
        defer { isSyncing = false; flushPendingPush() }

        do {
            let context = ModelContext(modelContainer)

            let allFavorites = try context.fetch(FetchDescriptor<Favorite>())
            for favorite in allFavorites {
                favorite.isSynced = false
            }

            let allLogs = try context.fetch(FetchDescriptor<CarbonLog>())
            for log in allLogs {
                log.isSynced = false
            }

            try context.save()
        } catch {
            logger.error("Upload all failed: \(error.localizedDescription, privacy: .public)")
            return .failure(error.localizedDescription)
        }

        return await performSyncInternal(userId: userId)
    }

    private func performSyncInternal(userId: UUID) async -> SyncResult {
        do {
            let context = ModelContext(modelContainer)
            try await pushChanges(userId: userId, context: context)
            try await pullChanges(userId: userId, context: context)
            try context.save()
            return .success
        } catch {
            logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
            return .failure(error.localizedDescription)
        }
    }

    /// Called from the `defer` of every sync entry-point. If a `pushOnly` was
    /// skipped while a sync was in progress, we kick it off now.
    private func flushPendingPush() {
        guard let userId = pendingPushUserId else { return }
        pendingPushUserId = nil
        Task { await self.pushOnly(userId: userId) }
    }

    // MARK: - Push

    private func pushChanges(userId: UUID, context: ModelContext) async throws {
        try await pushFavorites(userId: userId, context: context)
        try await pushCarbonLogs(userId: userId, context: context)
        try await pushDeletions(userId: userId, context: context)
        try context.save()
    }

    private func pushFavorites(userId: UUID, context: ModelContext) async throws {
        let unsynced = try context.fetch(FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.isSynced == false }
        ))

        for favorite in unsynced {
            let payload: [String: AnyJSON] = [
                "id": .string(favorite.id.uuidString),
                "user_id": .string(userId.uuidString),
                "item_type": .string(favorite.itemType),
                "item_id": .string(favorite.itemId),
                "date_added": .string(favorite.dateAdded.ISO8601Format()),
                "updated_at": .string(favorite.updatedAt.ISO8601Format()),
                "is_deleted": .bool(favorite.isSoftDeleted)
            ]

            do {
                try await client.upsert(table: "favorites", payload: payload)
                favorite.isSynced = true
            } catch {
                logger.error("Failed to push favorite: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func pushCarbonLogs(userId: UUID, context: ModelContext) async throws {
        let unsynced = try context.fetch(FetchDescriptor<CarbonLog>(
            predicate: #Predicate { $0.isSynced == false }
        ))

        for log in unsynced {
            let payload: [String: AnyJSON] = [
                "id": .string(log.id.uuidString),
                "user_id": .string(userId.uuidString),
                "date": .string(log.date.ISO8601Format()),
                "produce_id": .string(log.produceId),
                "produce_name": .string(log.produceName),
                "quantity_kg": .double(log.quantityKg),
                "carbon_saved_kg": .double(log.carbonSavedKg),
                "updated_at": .string(log.updatedAt.ISO8601Format()),
                "is_deleted": .bool(log.isSoftDeleted)
            ]

            do {
                try await client.upsert(table: "carbon_logs", payload: payload)
                log.isSynced = true
            } catch {
                logger.error("Failed to push carbon log: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func pushDeletions(userId: UUID, context: ModelContext) async throws {
        let deletions = try context.fetch(FetchDescriptor<PendingSyncDeletion>())

        for deletion in deletions {
            let table = deletion.tableName
            let recordId = deletion.recordId

            // Reject any table name not in the explicit whitelist to prevent
            // arbitrary-table deletion if local SwiftData is ever tampered with.
            guard SyncTable(rawValue: table) != nil else {
                context.delete(deletion)
                continue
            }

            do {
                try await client.delete(table: table, id: recordId, userId: userId.uuidString)
                context.delete(deletion)
            } catch {
                logger.error("Failed to push deletion from \(table, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Pull

    private func pullChanges(userId: UUID, context: ModelContext) async throws {
        let since = lastSyncTimestamp
        let sinceISO = since.ISO8601Format()
        var latestTimestamp = since

        // Pull favorites
        let remoteFavorites: [RemoteFavorite] = try await client.select(
            table: "favorites", userId: userId.uuidString, updatedAfter: sinceISO
        )

        /// Valid item types the server is permitted to return.
        let validItemTypes: Set<String> = ["produce", "recipe"]

        for remote in remoteFavorites {
            guard validItemTypes.contains(remote.itemType),
                  !remote.itemId.isEmpty, remote.itemId.count <= 500 else {
                logger.warning("Skipping remote favorite with invalid itemType or empty itemId.")
                continue
            }

            let remoteId = remote.id
            let existing = try context.fetch(FetchDescriptor<Favorite>(
                predicate: #Predicate { $0.id == remoteId }
            )).first

            if let existing {
                if remote.updatedAt > existing.updatedAt {
                    existing.itemType = remote.itemType
                    existing.itemId = remote.itemId
                    existing.dateAdded = remote.dateAdded
                    existing.updatedAt = remote.updatedAt
                    existing.isSoftDeleted = remote.isDeleted
                    existing.isSynced = true
                }
            } else {
                let favorite = Favorite(itemType: remote.itemType, itemId: remote.itemId)
                favorite.id = remote.id
                favorite.dateAdded = remote.dateAdded
                favorite.updatedAt = remote.updatedAt
                favorite.isSoftDeleted = remote.isDeleted
                favorite.isSynced = true
                context.insert(favorite)
            }

            if remote.updatedAt > latestTimestamp {
                latestTimestamp = remote.updatedAt
            }
        }

        // Pull carbon logs
        let remoteLogs: [RemoteCarbonLog] = try await client.select(
            table: "carbon_logs", userId: userId.uuidString, updatedAfter: sinceISO
        )

        let carbonKgRange: ClosedRange<Double> = 0...10_000

        for remote in remoteLogs {
            guard remote.quantityKg.isFinite && carbonKgRange.contains(remote.quantityKg),
                  remote.carbonSavedKg.isFinite && carbonKgRange.contains(remote.carbonSavedKg),
                  !remote.produceId.isEmpty, remote.produceId.count <= 200,
                  !remote.produceName.isEmpty, remote.produceName.count <= 500 else {
                logger.warning("Skipping remote carbon log with out-of-range or empty values.")
                continue
            }

            let remoteId = remote.id
            let existing = try context.fetch(FetchDescriptor<CarbonLog>(
                predicate: #Predicate { $0.id == remoteId }
            )).first

            if let existing {
                if remote.updatedAt > existing.updatedAt {
                    existing.date = remote.date
                    existing.produceId = remote.produceId
                    existing.produceName = remote.produceName
                    existing.quantityKg = remote.quantityKg
                    existing.carbonSavedKg = remote.carbonSavedKg
                    existing.updatedAt = remote.updatedAt
                    existing.isSoftDeleted = remote.isDeleted
                    existing.isSynced = true
                }
            } else {
                let log = CarbonLog(
                    produceId: remote.produceId,
                    produceName: remote.produceName,
                    quantityKg: remote.quantityKg,
                    carbonSavedKg: remote.carbonSavedKg
                )
                log.id = remote.id
                log.date = remote.date
                log.updatedAt = remote.updatedAt
                log.isSoftDeleted = remote.isDeleted
                log.isSynced = true
                context.insert(log)
            }

            if remote.updatedAt > latestTimestamp {
                latestTimestamp = remote.updatedAt
            }
        }

        if latestTimestamp > since {
            setLastSyncTimestamp(latestTimestamp)
        }
    }
}
