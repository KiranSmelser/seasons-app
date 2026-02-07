import Foundation
import SwiftUI

@Observable
final class SeasonalViewModel {
    let locationService: LocationService
    private let produceService = ProduceDataService.shared

    var selectedCategory: ProduceCategory?
    var searchText = ""

    init(locationService: LocationService) {
        self.locationService = locationService
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    var seasonalProduce: [ProduceItem] {
        var items = produceService.inSeason(
            region: locationService.region,
            month: currentMonth,
            category: selectedCategory
        )
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items.sorted { $0.name < $1.name }
    }

    var allProduce: [ProduceItem] {
        produceService.allProduce.sorted { $0.name < $1.name }
    }

    var inSeasonCount: Int {
        produceService.inSeason(region: locationService.region, month: currentMonth).count
    }
}
