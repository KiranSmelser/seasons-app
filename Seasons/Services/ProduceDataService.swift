import Foundation
import os

final class ProduceDataService {
    static let shared = ProduceDataService()

    private(set) var allProduce: [ProduceItem] = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "ProduceDataService")

    private init() {
        loadProduce()
    }

    private func loadProduce() {
        guard let url = Bundle.main.url(forResource: "seasonal_produce", withExtension: "json") else {
            logger.error("seasonal_produce.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allProduce = try JSONDecoder().decode([ProduceItem].self, from: data)
        } catch {
            logger.error("Failed to decode seasonal_produce.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns produce items that are in season for the given region and month.
    func inSeason(region: GrowingRegion, month: Int) -> [ProduceItem] {
        allProduce.filter { $0.isInSeason(region: region, month: month) }
    }

    /// Returns produce items filtered by category that are in season.
    func inSeason(region: GrowingRegion, month: Int, category: ProduceCategory?) -> [ProduceItem] {
        let seasonal = inSeason(region: region, month: month)
        guard let category else { return seasonal }
        return seasonal.filter { $0.category == category }
    }

    /// Returns the set of produce IDs that are in season.
    func inSeasonIds(region: GrowingRegion, month: Int) -> Set<String> {
        Set(inSeason(region: region, month: month).map(\.id))
    }

    /// Finds a produce item by ID.
    func produce(byId id: String) -> ProduceItem? {
        allProduce.first { $0.id == id }
    }
}
