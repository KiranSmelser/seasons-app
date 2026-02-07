import Foundation
import SwiftData

@Model
final class CarbonLog {
    var id: UUID
    var date: Date
    var produceId: String
    var produceName: String
    var quantityKg: Double
    var carbonSavedKg: Double

    init(produceId: String, produceName: String, quantityKg: Double, carbonSavedKg: Double) {
        self.id = UUID()
        self.date = Date()
        self.produceId = produceId
        self.produceName = produceName
        self.quantityKg = quantityKg
        self.carbonSavedKg = carbonSavedKg
    }
}
