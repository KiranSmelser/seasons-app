import XCTest
import SwiftData
@testable import Seasons

final class ServiceTests: XCTestCase {

    // MARK: - Helpers

    private func makeTestModelContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CarbonLog.self, Favorite.self, configurations: config)
        return ModelContext(container)
    }

    // MARK: - ProduceDataService Tests

    func testAllProduceLoaded() {
        XCTAssertEqual(ProduceDataService.shared.allProduce.count, 70)
    }

    func testProduceByIdFound() {
        let tomato = ProduceDataService.shared.produce(byId: "tomato")
        XCTAssertNotNil(tomato)
        XCTAssertEqual(tomato?.name, "Tomato")
    }

    func testProduceByIdNotFound() {
        XCTAssertNil(ProduceDataService.shared.produce(byId: "xyz"))
    }

    func testInSeasonFiltering() {
        let items = ProduceDataService.shared.inSeason(region: .northeast, month: 7)
        XCTAssertFalse(items.isEmpty, "Should have produce in season for northeast in July")
        XCTAssertTrue(items.contains { $0.id == "tomato" }, "Tomato should be in season in northeast in July")
    }

    func testInSeasonWithCategoryFilter() {
        let allSeasonal = ProduceDataService.shared.inSeason(region: .northeast, month: 7)
        let fruitsOnly = ProduceDataService.shared.inSeason(region: .northeast, month: 7, category: .fruit)
        XCTAssertLessThanOrEqual(fruitsOnly.count, allSeasonal.count)
        for item in fruitsOnly {
            XCTAssertEqual(item.category, .fruit)
        }
    }

    // MARK: - RecipeDataService Tests

    func testAllRecipesLoaded() {
        XCTAssertEqual(RecipeDataService.shared.allRecipes.count, 47)
    }

    func testRecipeByIdFound() {
        let recipe = RecipeDataService.shared.recipe(byId: "caprese_salad")
        XCTAssertNotNil(recipe)
        XCTAssertEqual(recipe?.name, "Summer Caprese Salad")
    }

    func testRecipeByIdNotFound() {
        XCTAssertNil(RecipeDataService.shared.recipe(byId: "xyz"))
    }

    func testRecipesSortedBySeasonalOrder() {
        let inSeasonIds = ProduceDataService.shared.inSeasonIds(region: .northeast, month: 7)
        let sorted = RecipeDataService.shared.recipesSortedBySeasonal(inSeasonIds: inSeasonIds)
        XCTAssertFalse(sorted.isEmpty)
        if sorted.count >= 2 {
            let firstCount = sorted.first!.seasonalMatchCount(inSeason: inSeasonIds)
            let lastCount = sorted.last!.seasonalMatchCount(inSeason: inSeasonIds)
            XCTAssertGreaterThanOrEqual(firstCount, lastCount)
        }
    }

    func testRecipesUsingProduce() {
        let tomatoRecipes = RecipeDataService.shared.recipes(using: "tomato")
        let tomatoRecipeIds = tomatoRecipes.map(\.id)
        XCTAssertTrue(tomatoRecipeIds.contains("caprese_salad"), "caprese_salad should use tomato")
        XCTAssertTrue(tomatoRecipeIds.contains("zucchini_pasta"), "zucchini_pasta should use tomato")
        XCTAssertTrue(tomatoRecipeIds.contains("stuffed_peppers"), "stuffed_peppers should use tomato")
        XCTAssertTrue(tomatoRecipeIds.contains("eggplant_parmesan"), "eggplant_parmesan should use tomato")
    }

    // MARK: - CarbonCalculationService Tests

    func testEquivalenciesCount() {
        let equivs = CarbonCalculationService.equivalencies(carbonSavedKg: 1.0)
        XCTAssertEqual(equivs.count, 5)
    }

    func testEquivalenciesWithZeroCarbon() {
        let equivs = CarbonCalculationService.equivalencies(carbonSavedKg: 0.0)
        for equiv in equivs {
            XCTAssertEqual(equiv.value, 0.0, accuracy: 0.001,
                "Equivalency '\(equiv.description)' should be 0 for 0 carbon")
        }
    }

    func testFormattedCarbonBoundary() {
        XCTAssertEqual(CarbonCalculationService.formattedCarbon(0.999), "999 g")
        XCTAssertEqual(CarbonCalculationService.formattedCarbon(1.0), "1.0 kg")
    }

    func testFormattedCarbonZero() {
        XCTAssertEqual(CarbonCalculationService.formattedCarbon(0.0), "0 g")
    }

    // MARK: - FavoritesService Tests (SwiftData)

    func testToggleFavoriteAddsAndRemoves() throws {
        let context = try makeTestModelContext()
        let service = FavoritesService(modelContext: context)

        XCTAssertFalse(service.isFavorited(itemType: "produce", itemId: "tomato"))

        service.toggleFavorite(itemType: "produce", itemId: "tomato")
        XCTAssertTrue(service.isFavorited(itemType: "produce", itemId: "tomato"))

        service.toggleFavorite(itemType: "produce", itemId: "tomato")
        XCTAssertFalse(service.isFavorited(itemType: "produce", itemId: "tomato"))
    }

    func testFavoritedIdsFiltersByType() throws {
        let context = try makeTestModelContext()
        let service = FavoritesService(modelContext: context)

        service.toggleFavorite(itemType: "produce", itemId: "tomato")
        service.toggleFavorite(itemType: "produce", itemId: "kale")
        service.toggleFavorite(itemType: "recipe", itemId: "caprese_salad")

        let produceIds = service.favoritedIds(for: "produce")
        XCTAssertEqual(produceIds, ["tomato", "kale"])

        let recipeIds = service.favoritedIds(for: "recipe")
        XCTAssertEqual(recipeIds, ["caprese_salad"])
    }

    func testIsFavorited() throws {
        let context = try makeTestModelContext()
        let service = FavoritesService(modelContext: context)

        service.toggleFavorite(itemType: "produce", itemId: "tomato")
        XCTAssertTrue(service.isFavorited(itemType: "produce", itemId: "tomato"))
        XCTAssertFalse(service.isFavorited(itemType: "produce", itemId: "kale"))

        service.toggleFavorite(itemType: "produce", itemId: "tomato")
        XCTAssertFalse(service.isFavorited(itemType: "produce", itemId: "tomato"))
    }

    // MARK: - CarbonLog Persistence Test

    func testCarbonLogPersistence() throws {
        let context = try makeTestModelContext()
        let log = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.5, carbonSavedKg: 2.25)
        context.insert(log)

        let descriptor = FetchDescriptor<CarbonLog>()
        let fetched = try context.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let first = try XCTUnwrap(fetched.first)
        XCTAssertEqual(first.produceId, "tomato")
        XCTAssertEqual(first.produceName, "Tomato")
        XCTAssertEqual(first.quantityKg, 1.5, accuracy: 0.01)
        XCTAssertEqual(first.carbonSavedKg, 2.25, accuracy: 0.01)
    }
}
