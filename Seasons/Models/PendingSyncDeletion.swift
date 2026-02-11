import Foundation
import SwiftData

@Model
final class PendingSyncDeletion {
    var id: UUID
    var tableName: String
    var recordId: UUID

    init(tableName: String, recordId: UUID) {
        self.id = UUID()
        self.tableName = tableName
        self.recordId = recordId
    }
}
