import XCTest
@testable import Seasons

final class ViewModelTests: XCTestCase {

    // MARK: - SeasonalViewModel Tests

    private func makeSeasonalViewModel(region: GrowingRegion = .northeast) -> SeasonalViewModel {
        let locationService = LocationService()
        locationService.setManualRegion(region)
        return SeasonalViewModel(locationService: locationService)
    }

    func testCurrentMonthInRange() {
        let vm = makeSeasonalViewModel()
        XCTAssertTrue((1...12).contains(vm.currentMonth))
    }

    func testCurrentMonthNameNotEmpty() {
        let vm = makeSeasonalViewModel()
        XCTAssertFalse(vm.currentMonthName.isEmpty)
    }

    func testSeasonalProduceReturnsItems() {
        let vm = makeSeasonalViewModel()
        XCTAssertFalse(vm.seasonalProduce.isEmpty, "Should have seasonal produce for northeast")
    }

    func testSeasonalProduceFilteredByCategory() {
        let vm = makeSeasonalViewModel()
        vm.selectedCategory = .herb
        let items = vm.seasonalProduce
        for item in items {
            XCTAssertEqual(item.category, .herb, "\(item.name) should be an herb")
        }
    }

    func testSeasonalProduceSearchFilters() {
        let vm = makeSeasonalViewModel()
        vm.searchText = "tom"
        let items = vm.seasonalProduce
        for item in items {
            XCTAssertTrue(item.name.localizedCaseInsensitiveContains("tom"),
                "\(item.name) should contain 'tom'")
        }
    }

    func testFilteredProduceFavoritesOnly() {
        let vm = makeSeasonalViewModel()
        vm.showFavoritesOnly = true
        // With an empty favorites set, nothing should pass the filter
        let items = vm.filteredProduce(favoritedIds: [])
        XCTAssertTrue(items.isEmpty, "No items should show when favorites is empty and filter is on")

        // With a known favorited ID that's in season
        let allSeasonal = vm.seasonalProduce
        if let firstItem = allSeasonal.first {
            let filtered = vm.filteredProduce(favoritedIds: [firstItem.id])
            XCTAssertEqual(filtered.count, 1)
            XCTAssertEqual(filtered.first?.id, firstItem.id)
        }
    }

    // MARK: - RecipeViewModel Tests

    private func makeRecipeViewModel(region: GrowingRegion = .northeast) -> RecipeViewModel {
        let locationService = LocationService()
        locationService.setManualRegion(region)
        return RecipeViewModel(locationService: locationService)
    }

    func testRecipesReturnAll() {
        let vm = makeRecipeViewModel()
        vm.searchText = ""
        XCTAssertEqual(vm.recipes.count, 47, "Should return all 47 recipes with empty search")
    }

    func testRecipesSearchFilter() {
        let vm = makeRecipeViewModel()
        vm.searchText = "soup"
        let items = vm.recipes
        XCTAssertFalse(items.isEmpty, "Should find at least one soup recipe")
        for item in items {
            XCTAssertTrue(item.name.localizedCaseInsensitiveContains("soup"),
                "\(item.name) should contain 'soup'")
        }
    }

    func testSeasonalMatchCountNonNegative() {
        let vm = makeRecipeViewModel()
        for recipe in vm.recipes {
            XCTAssertGreaterThanOrEqual(vm.seasonalMatchCount(for: recipe), 0)
        }
    }

    func testIsIngredientInSeasonWithNilProduceId() {
        let vm = makeRecipeViewModel()
        let ingredient = RecipeIngredient(produceId: nil, name: "Salt", quantity: "1", unit: "pinch")
        XCTAssertFalse(vm.isIngredientInSeason(ingredient))
    }

    func testFilteredRecipesFavoritesOnly() {
        let vm = makeRecipeViewModel()
        vm.showFavoritesOnly = true

        let noFavorites = vm.filteredRecipes(favoritedIds: [])
        XCTAssertTrue(noFavorites.isEmpty, "Should be empty with no favorites")

        let withFavorite = vm.filteredRecipes(favoritedIds: ["caprese_salad"])
        XCTAssertEqual(withFavorite.count, 1)
        XCTAssertEqual(withFavorite.first?.id, "caprese_salad")
    }

    // MARK: - CarbonViewModel Tests

    func testCanLogRequiresBothFields() {
        let vm = CarbonViewModel()
        // Neither set
        XCTAssertFalse(vm.canLog)

        // Only produce set
        vm.selectedProduceId = "tomato"
        vm.quantityString = ""
        XCTAssertFalse(vm.canLog)

        // Only quantity set
        vm.selectedProduceId = nil
        vm.quantityString = "1.0"
        XCTAssertFalse(vm.canLog)

        // Both set
        vm.selectedProduceId = "tomato"
        vm.quantityString = "1.0"
        XCTAssertTrue(vm.canLog)
    }

    func testCreateLogEntryResetsState() {
        let vm = CarbonViewModel()
        vm.selectedProduceId = "tomato"
        vm.quantityString = "2.0"

        let entry = vm.createLogEntry()
        XCTAssertNotNil(entry)
        XCTAssertNil(vm.selectedProduceId, "selectedProduceId should be reset")
        XCTAssertEqual(vm.quantityString, "", "quantityString should be reset")
    }

    func testCreateLogEntryReturnsNilForInvalidState() {
        let vm = CarbonViewModel()

        // No produce selected
        vm.quantityString = "1.0"
        XCTAssertNil(vm.createLogEntry())

        // Zero quantity
        vm.selectedProduceId = "tomato"
        vm.quantityString = "0"
        XCTAssertNil(vm.createLogEntry())
    }

    func testFilteredLogsAllTime() {
        let vm = CarbonViewModel()
        vm.selectedTimePeriod = .allTime
        let logs = [
            CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5),
            CarbonLog(produceId: "kale", produceName: "Kale", quantityKg: 0.5, carbonSavedKg: 0.3)
        ]
        XCTAssertEqual(vm.filteredLogs(from: logs).count, 2)
    }

    func testFilteredLogsWeekExcludesOld() {
        let vm = CarbonViewModel()
        vm.selectedTimePeriod = .week

        let recentLog = CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 0.5)
        let oldLog = CarbonLog(produceId: "kale", produceName: "Kale", quantityKg: 0.5, carbonSavedKg: 0.3)
        // Manually set date to 10 days ago
        oldLog.date = Calendar.current.date(byAdding: .day, value: -10, to: Date())!

        let filtered = vm.filteredLogs(from: [recentLog, oldLog])
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.produceId, "tomato")
    }

    func testTotalCarbonSavedSumsCorrectly() {
        let vm = CarbonViewModel()
        let logs = [
            CarbonLog(produceId: "a", produceName: "A", quantityKg: 1.0, carbonSavedKg: 0.5),
            CarbonLog(produceId: "b", produceName: "B", quantityKg: 1.0, carbonSavedKg: 1.0),
            CarbonLog(produceId: "c", produceName: "C", quantityKg: 1.0, carbonSavedKg: 0.3)
        ]
        XCTAssertEqual(vm.totalCarbonSaved(from: logs), 1.8, accuracy: 0.001)
    }

    func testTopProduceBreakdownGroupsAndSorts() throws {
        let vm = CarbonViewModel()
        let logs = [
            CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 1.0, carbonSavedKg: 1.0),
            CarbonLog(produceId: "tomato", produceName: "Tomato", quantityKg: 0.5, carbonSavedKg: 0.5),
            CarbonLog(produceId: "kale", produceName: "Kale", quantityKg: 1.0, carbonSavedKg: 0.3)
        ]
        let breakdown = vm.topProduceBreakdown(from: logs)
        XCTAssertEqual(breakdown.count, 2)
        let first = try XCTUnwrap(breakdown.first)
        XCTAssertEqual(first.produceId, "tomato")
        XCTAssertEqual(first.logCount, 2)
        XCTAssertEqual(first.totalCarbonSavedKg, 1.5, accuracy: 0.001)
    }
}
