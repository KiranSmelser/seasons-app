import Foundation

enum ProduceCategory: String, Codable, CaseIterable, Identifiable {
    case fruit
    case vegetable
    case herb

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fruit: "Fruits"
        case .vegetable: "Vegetables"
        case .herb: "Herbs"
        }
    }

    var systemImage: String {
        switch self {
        case .fruit: "apple.logo"
        case .vegetable: "carrot.fill"
        case .herb: "leaf.fill"
        }
    }
}

struct ProduceItem: Codable, Identifiable {
    let id: String
    let name: String
    let category: ProduceCategory
    let description: String
    let imageName: String
    let seasonsByRegion: [String: [Int]]
    let localCarbonKgPerKg: Double
    let importedCarbonKgPerKg: Double

    /// Returns the months (1-12) this item is in season for a given region.
    func seasonalMonths(for region: GrowingRegion) -> [Int] {
        seasonsByRegion[region.rawValue] ?? []
    }

    /// Whether this item is currently in season for the given region and month.
    func isInSeason(region: GrowingRegion, month: Int) -> Bool {
        seasonalMonths(for: region).contains(month)
    }

    /// Carbon savings in kg CO2 per kg of produce when choosing local over imported.
    var carbonSavingsPerKg: Double {
        importedCarbonKgPerKg - localCarbonKgPerKg
    }
}
