import Foundation
import SwiftData

struct FavoritesService {
    let modelContext: ModelContext

    func isFavorited(itemType: String, itemId: String) -> Bool {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType && $0.itemId == itemId && !$0.isSoftDeleted }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    func toggleFavorite(itemType: String, itemId: String) {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType && $0.itemId == itemId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            if existing.isSoftDeleted {
                // Revive a soft-deleted favorite
                existing.isSoftDeleted = false
                existing.isSynced = false
                existing.updatedAt = Date()
            } else {
                // Soft-delete the favorite
                existing.isSoftDeleted = true
                existing.isSynced = false
                existing.updatedAt = Date()
            }
        } else {
            modelContext.insert(Favorite(itemType: itemType, itemId: itemId))
        }
    }

    func favoritedIds(for itemType: String) -> Set<String> {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType && !$0.isSoftDeleted }
        )
        let favorites = (try? modelContext.fetch(descriptor)) ?? []
        return Set(favorites.map(\.itemId))
    }
}
