import Foundation

@Observable
final class RecipeViewModel {
    let locationService: LocationService
    private let recipeService = RecipeDataService.shared
    private let produceService = ProduceDataService.shared

    var searchText = ""
    var showFavoritesOnly = false

    init(locationService: LocationService) {
        self.locationService = locationService
    }

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var inSeasonIds: Set<String> {
        produceService.inSeasonIds(region: locationService.region, month: currentMonth)
    }

    var recipes: [Recipe] {
        var items = recipeService.recipesSortedBySeasonal(inSeasonIds: inSeasonIds)
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items
    }

    func filteredRecipes(favoritedIds: Set<String>) -> [Recipe] {
        var items = recipes
        if showFavoritesOnly {
            items = items.filter { favoritedIds.contains($0.id) }
        }
        return items
    }

    func seasonalMatchCount(for recipe: Recipe) -> Int {
        recipe.seasonalMatchCount(inSeason: inSeasonIds)
    }

    func isIngredientInSeason(_ ingredient: RecipeIngredient) -> Bool {
        guard let produceId = ingredient.produceId else { return false }
        return inSeasonIds.contains(produceId)
    }
}
