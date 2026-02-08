import Foundation

final class RecipeDataService {
    static let shared = RecipeDataService()

    private(set) var allRecipes: [Recipe] = []

    private init() {
        loadRecipes()
    }

    private func loadRecipes() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        allRecipes = (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
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
