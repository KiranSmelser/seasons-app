import Foundation
import SwiftData
import Supabase

actor SyncService {
    private let supabase: SupabaseClient
    private let modelContainer: ModelContainer

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

    init(supabase: SupabaseClient, modelContainer: ModelContainer) {
        self.supabase = supabase
        self.modelContainer = modelContainer
    }

    func performSync(userId: UUID) async {
        do {
            let context = ModelContext(modelContainer)
            try await pushChanges(userId: userId, context: context)
            try await pullChanges(userId: userId, context: context)
            try context.save()
        } catch {
            print("[SyncService] Sync failed: \(error)")
        }
    }

    func uploadAllLocalData(userId: UUID) async {
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
            await performSync(userId: userId)
        } catch {
            print("[SyncService] Upload all failed: \(error)")
        }
    }

    // MARK: - Push

    private func pushChanges(userId: UUID, context: ModelContext) throws {
        try pushFavorites(userId: userId, context: context)
        try pushCarbonLogs(userId: userId, context: context)
        try pushDeletions(context: context)
        try context.save()
    }

    private func pushFavorites(userId: UUID, context: ModelContext) throws {
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
                "updated_at": .string(favorite.updatedAt.ISO8601Format())
            ]

            Task {
                try await supabase.from("favorites")
                    .upsert(payload)
                    .execute()
            }

            favorite.isSynced = true
        }
    }

    private func pushCarbonLogs(userId: UUID, context: ModelContext) throws {
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
                "is_deleted": .bool(log.isDeleted)
            ]

            Task {
                try await supabase.from("carbon_logs")
                    .upsert(payload)
                    .execute()
            }

            log.isSynced = true
        }
    }

    private func pushDeletions(context: ModelContext) throws {
        let deletions = try context.fetch(FetchDescriptor<PendingSyncDeletion>())

        for deletion in deletions {
            let table = deletion.tableName
            let recordId = deletion.recordId

            Task {
                try await supabase.from(table)
                    .delete()
                    .eq("id", value: recordId.uuidString)
                    .execute()
            }

            context.delete(deletion)
        }
    }

    // MARK: - Pull

    private func pullChanges(userId: UUID, context: ModelContext) async throws {
        let since = lastSyncTimestamp
        let sinceISO = since.ISO8601Format()
        var latestTimestamp = since

        // Pull favorites
        let remoteFavorites: [RemoteFavorite] = try await supabase.from("favorites")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gt("updated_at", value: sinceISO)
            .execute()
            .value

        for remote in remoteFavorites {
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
                    existing.isSynced = true
                }
            } else {
                let favorite = Favorite(itemType: remote.itemType, itemId: remote.itemId)
                favorite.id = remote.id
                favorite.dateAdded = remote.dateAdded
                favorite.updatedAt = remote.updatedAt
                favorite.isSynced = true
                context.insert(favorite)
            }

            if remote.updatedAt > latestTimestamp {
                latestTimestamp = remote.updatedAt
            }
        }

        // Pull carbon logs
        let remoteLogs: [RemoteCarbonLog] = try await supabase.from("carbon_logs")
            .select()
            .eq("user_id", value: userId.uuidString)
            .gt("updated_at", value: sinceISO)
            .execute()
            .value

        for remote in remoteLogs {
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
                    existing.isDeleted = remote.isDeleted
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
                log.isDeleted = remote.isDeleted
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
