import Foundation
import SwiftData

@Model
final class Favorite {
    var id: UUID
    var itemType: String
    var itemId: String
    var dateAdded: Date
    var updatedAt: Date
    var isSynced: Bool

    init(itemType: String, itemId: String) {
        self.id = UUID()
        self.itemType = itemType
        self.itemId = itemId
        self.dateAdded = Date()
        self.updatedAt = Date()
        self.isSynced = false
    }
}
