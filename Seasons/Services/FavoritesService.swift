import Foundation
import SwiftData

struct FavoritesService {
    let modelContext: ModelContext

    func isFavorited(itemType: String, itemId: String) -> Bool {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType && $0.itemId == itemId }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    func toggleFavorite(itemType: String, itemId: String) {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType && $0.itemId == itemId }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            let deletion = PendingSyncDeletion(tableName: "favorites", recordId: existing.id)
            modelContext.insert(deletion)
            modelContext.delete(existing)
        } else {
            modelContext.insert(Favorite(itemType: itemType, itemId: itemId))
        }
    }

    func favoritedIds(for itemType: String) -> Set<String> {
        let descriptor = FetchDescriptor<Favorite>(
            predicate: #Predicate { $0.itemType == itemType }
        )
        let favorites = (try? modelContext.fetch(descriptor)) ?? []
        return Set(favorites.map(\.itemId))
    }
}
