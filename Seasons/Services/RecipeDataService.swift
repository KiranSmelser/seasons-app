import Foundation
import os

final class RecipeDataService {
    static let shared = RecipeDataService()

    private(set) var allRecipes: [Recipe] = []
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "RecipeDataService")

    private init() {
        loadRecipes()
    }

    private func loadRecipes() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else {
            logger.error("recipes.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allRecipes = try JSONDecoder().decode([Recipe].self, from: data)
        } catch {
            logger.error("Failed to decode recipes.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns recipes sorted by how many of their produce ingredients are currently in season.
    func recipesSortedBySeasonal(inSeasonIds: Set<String>) -> [Recipe] {
        allRecipes.sorted { a, b in
            a.seasonalMatchCount(inSeason: inSeasonIds) > b.seasonalMatchCount(inSeason: inSeasonIds)
        }
    }

    /// Returns a recipe by ID.
    func recipe(byId id: String) -> Recipe? {
        allRecipes.first { $0.id == id }
    }

    /// Returns recipes that use a given produce item.
    func recipes(using produceId: String) -> [Recipe] {
        allRecipes.filter { $0.produceIds.contains(produceId) }
    }
}
