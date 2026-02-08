import XCTest
import CoreLocation
@testable import Seasons

final class ModelTests: XCTestCase {

    // MARK: - GrowingRegion Tests

    func testRegionFromCoordinateMidwest() {
        let coord = CLLocationCoordinate2D(latitude: 41.88, longitude: -87.63) // Chicago
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .midwest)
    }

    func testRegionFromCoordinateGreatPlains() {
        let coord = CLLocationCoordinate2D(latitude: 35.47, longitude: -97.52) // OKC
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .greatPlains)
    }

    func testRegionFromCoordinateSouthwest() {
        let coord = CLLocationCoordinate2D(latitude: 33.45, longitude: -112.07) // Phoenix
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .southwest)
    }

    func testRegionFromCoordinatePacificNorthwest() {
        let coord = CLLocationCoordinate2D(latitude: 47.61, longitude: -122.33) // Seattle
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .pacificNorthwest)
    }

    func testRegionDisplayNames() {
        let expected: [GrowingRegion: String] = [
            .northeast: "Northeast",
            .southeast: "Southeast",
            .midwest: "Midwest",
            .greatPlains: "Great Plains",
            .southwest: "Southwest",
            .pacificNorthwest: "Pacific Northwest",
            .california: "California"
        ]
        for (region, name) in expected {
            XCTAssertEqual(region.displayName, name, "Display name mismatch for \(region)")
        }
    }

    // MARK: - ProduceItem Tests

    func testSeasonalMonthsReturnsCorrectArray() {
        let produce = ProduceItem(
            id: "test", name: "Test", category: .vegetable,
            description: "Test", imageName: "test",
            seasonsByRegion: ["northeast": [5, 6, 7, 8, 9]],
            localCarbonKgPerKg: 0.3, importedCarbonKgPerKg: 1.5
        )
        XCTAssertEqual(produce.seasonalMonths(for: .northeast), [5, 6, 7, 8, 9])
    }

    func testSeasonalMonthsForMissingRegion() {
        let produce = ProduceItem(
            id: "test", name: "Test", category: .vegetable,
            description: "Test", imageName: "test",
            seasonsByRegion: ["northeast": [5, 6, 7]],
            localCarbonKgPerKg: 0.3, importedCarbonKgPerKg: 1.5
        )
        XCTAssertEqual(produce.seasonalMonths(for: .california), [])
    }

    func testCarbonSavingsPerKgNeverNegative() {
        let allProduce = ProduceDataService.shared.allProduce
        XCTAssertFalse(allProduce.isEmpty, "Produce data should be loaded")
        for item in allProduce {
            XCTAssertGreaterThanOrEqual(item.carbonSavingsPerKg, 0,
                "\(item.name) has negative carbon savings")
        }
    }

    // MARK: - Recipe Tests

    func testTotalTimeMinutes() {
        let recipe = Recipe(
            id: "test", name: "Test", description: "Test",
            ingredients: [],
            instructions: ["Step 1"],
            prepTimeMinutes: 15, cookTimeMinutes: 30,
            servings: 4, imageName: "test"
        )
        XCTAssertEqual(recipe.totalTimeMinutes, 45)
    }

    func testProduceIdsExcludesNil() {
        let recipe = Recipe(
            id: "test", name: "Test", description: "Test",
            ingredients: [
                RecipeIngredient(produceId: "tomato", name: "Tomato", quantity: "1", unit: "large"),
                RecipeIngredient(produceId: nil, name: "Salt", quantity: "1", unit: "pinch"),
                RecipeIngredient(produceId: "basil", name: "Basil", quantity: "1", unit: "bunch")
            ],
            instructions: ["Step 1"],
            prepTimeMinutes: 10, cookTimeMinutes: 0,
            servings: 2, imageName: "test"
        )
        XCTAssertEqual(recipe.produceIds, ["tomato", "basil"])
    }

    func testSeasonalMatchCountAllInSeason() {
        let recipe = Recipe(
            id: "test", name: "Test", description: "Test",
            ingredients: [
                RecipeIngredient(produceId: "tomato", name: "Tomato", quantity: "1", unit: "large"),
                RecipeIngredient(produceId: "basil", name: "Basil", quantity: "1", unit: "bunch")
            ],
            instructions: ["Step 1"],
            prepTimeMinutes: 10, cookTimeMinutes: 0,
            servings: 2, imageName: "test"
        )
        let inSeason: Set<String> = ["tomato", "basil", "kale"]
        XCTAssertEqual(recipe.seasonalMatchCount(inSeason: inSeason), 2)
    }

    func testSeasonalMatchCountNoneInSeason() {
        let recipe = Recipe(
            id: "test", name: "Test", description: "Test",
            ingredients: [
                RecipeIngredient(produceId: "tomato", name: "Tomato", quantity: "1", unit: "large"),
                RecipeIngredient(produceId: "basil", name: "Basil", quantity: "1", unit: "bunch")
            ],
            instructions: ["Step 1"],
            prepTimeMinutes: 10, cookTimeMinutes: 0,
            servings: 2, imageName: "test"
        )
        let inSeason: Set<String> = []
        XCTAssertEqual(recipe.seasonalMatchCount(inSeason: inSeason), 0)
    }

    // MARK: - ProduceCategory Tests

    func testProduceCategoryDisplayNamesAndImages() {
        let expected: [(ProduceCategory, String, String)] = [
            (.fruit, "Fruits", "apple.logo"),
            (.vegetable, "Vegetables", "carrot.fill"),
            (.herb, "Herbs", "leaf.fill")
        ]
        for (category, name, image) in expected {
            XCTAssertEqual(category.displayName, name)
            XCTAssertEqual(category.systemImage, image)
        }
    }
}
