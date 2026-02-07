import Foundation
import SwiftData

@Observable
final class CarbonViewModel {
    private let produceService = ProduceDataService.shared

    var selectedProduceId: String?
    var quantityString = ""

    var availableProduce: [ProduceItem] {
        produceService.allProduce.sorted { $0.name < $1.name }
    }

    var selectedProduce: ProduceItem? {
        guard let id = selectedProduceId else { return nil }
        return produceService.produce(byId: id)
    }

    var canLog: Bool {
        selectedProduce != nil && (Double(quantityString) ?? 0) > 0
    }

    /// Creates a new CarbonLog entry for the selected produce and quantity.
    func createLogEntry() -> CarbonLog? {
        guard let produce = selectedProduce,
              let quantity = Double(quantityString), quantity > 0 else {
            return nil
        }
        let saved = CarbonCalculationService.carbonSaved(produce: produce, quantityKg: quantity)
        let entry = CarbonLog(
            produceId: produce.id,
            produceName: produce.name,
            quantityKg: quantity,
            carbonSavedKg: saved
        )
        selectedProduceId = nil
        quantityString = ""
        return entry
    }

    func totalCarbonSaved(from logs: [CarbonLog]) -> Double {
        logs.reduce(0) { $0 + $1.carbonSavedKg }
    }

    func equivalencies(from logs: [CarbonLog]) -> [CarbonEquivalent] {
        CarbonCalculationService.equivalencies(carbonSavedKg: totalCarbonSaved(from: logs))
    }
}
