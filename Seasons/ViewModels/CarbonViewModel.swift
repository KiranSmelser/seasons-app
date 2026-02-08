import Foundation
import SwiftData

enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "This Week"
    case month = "This Month"
    case allTime = "All Time"

    var id: String { rawValue }
}

struct ProduceBreakdown: Identifiable {
    let produceId: String
    let produceName: String
    let totalCarbonSavedKg: Double
    let logCount: Int

    var id: String { produceId }
}

@Observable
final class CarbonViewModel {
    private let produceService = ProduceDataService.shared

    var selectedProduceId: String?
    var quantityString = ""
    var selectedTimePeriod: TimePeriod = .allTime

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

    func filteredLogs(from logs: [CarbonLog]) -> [CarbonLog] {
        let now = Date()
        let calendar = Calendar.current
        switch selectedTimePeriod {
        case .week:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return logs }
            return logs.filter { $0.date >= weekAgo }
        case .month:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return logs }
            return logs.filter { $0.date >= monthAgo }
        case .allTime:
            return logs
        }
    }

    func totalCarbonSaved(from logs: [CarbonLog]) -> Double {
        logs.reduce(0) { $0 + $1.carbonSavedKg }
    }

    func equivalencies(from logs: [CarbonLog]) -> [CarbonEquivalent] {
        CarbonCalculationService.equivalencies(carbonSavedKg: totalCarbonSaved(from: logs))
    }

    func topProduceBreakdown(from logs: [CarbonLog], limit: Int = 5) -> [ProduceBreakdown] {
        var grouped: [String: (name: String, carbon: Double, count: Int)] = [:]
        for log in logs {
            let existing = grouped[log.produceId] ?? (name: log.produceName, carbon: 0, count: 0)
            grouped[log.produceId] = (name: existing.name, carbon: existing.carbon + log.carbonSavedKg, count: existing.count + 1)
        }
        return grouped.map { ProduceBreakdown(produceId: $0.key, produceName: $0.value.name, totalCarbonSavedKg: $0.value.carbon, logCount: $0.value.count) }
            .sorted { $0.totalCarbonSavedKg > $1.totalCarbonSavedKg }
            .prefix(limit)
            .map { $0 }
    }

    func shareText(from logs: [CarbonLog]) -> String {
        let total = totalCarbonSaved(from: logs)
        let equivs = equivalencies(from: logs)
        var text = "🌱 My Seasons Impact\n\n"
        text += "I've saved \(CarbonCalculationService.formattedCarbon(total)) of CO₂ by choosing local, seasonal produce!\n\n"
        text += "That's equivalent to:\n"
        for equiv in equivs {
            text += "• \(String(format: "%.1f", equiv.value)) \(equiv.unit) — \(equiv.description)\n"
        }
        text += "\nTrack your own impact with the Seasons app!"
        return text
    }
}
