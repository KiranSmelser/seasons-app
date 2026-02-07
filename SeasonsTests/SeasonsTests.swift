import XCTest
import CoreLocation
@testable import Seasons

final class SeasonsTests: XCTestCase {

    // MARK: - GrowingRegion Tests

    func testRegionFromCoordinateNortheast() {
        let coord = CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589) // Boston
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .northeast)
    }

    func testRegionFromCoordinateCalifornia() {
        let coord = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437) // Los Angeles
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .california)
    }

    func testRegionFromCoordinateSoutheast() {
        let coord = CLLocationCoordinate2D(latitude: 33.749, longitude: -84.388) // Atlanta
        XCTAssertEqual(GrowingRegion.from(coordinate: coord), .southeast)
    }

    // MARK: - ProduceItem Tests

    func testProduceIsInSeason() {
        let produce = ProduceItem(
            id: "test",
            name: "Test",
            category: .vegetable,
            description: "Test",
            imageName: "test",
            seasonsByRegion: ["northeast": [6, 7, 8]],
            localCarbonKgPerKg: 0.3,
            importedCarbonKgPerKg: 1.5
        )

        XCTAssertTrue(produce.isInSeason(region: .northeast, month: 7))
        XCTAssertFalse(produce.isInSeason(region: .northeast, month: 1))
        XCTAssertFalse(produce.isInSeason(region: .southeast, month: 7))
    }

    func testCarbonSavingsPerKg() {
        let produce = ProduceItem(
            id: "test",
            name: "Test",
            category: .fruit,
            description: "Test",
            imageName: "test",
            seasonsByRegion: [:],
            localCarbonKgPerKg: 0.3,
            importedCarbonKgPerKg: 1.8
        )

        XCTAssertEqual(produce.carbonSavingsPerKg, 1.5, accuracy: 0.01)
    }

    // MARK: - CarbonCalculationService Tests

    func testCarbonSavedCalculation() {
        let produce = ProduceItem(
            id: "test",
            name: "Test",
            category: .fruit,
            description: "Test",
            imageName: "test",
            seasonsByRegion: [:],
            localCarbonKgPerKg: 0.3,
            importedCarbonKgPerKg: 1.8
        )

        let saved = CarbonCalculationService.carbonSaved(produce: produce, quantityKg: 2.0)
        XCTAssertEqual(saved, 3.0, accuracy: 0.01) // (1.8 - 0.3) * 2.0
    }

    func testFormattedCarbonGrams() {
        XCTAssertEqual(CarbonCalculationService.formattedCarbon(0.5), "500 g")
    }

    func testFormattedCarbonKilograms() {
        XCTAssertEqual(CarbonCalculationService.formattedCarbon(2.5), "2.5 kg")
    }

    // MARK: - Recipe Tests

    func testRecipeSeasonalMatchCount() {
        let recipe = Recipe(
            id: "test",
            name: "Test",
            description: "Test",
            ingredients: [
                RecipeIngredient(produceId: "tomato", name: "Tomato", quantity: "1", unit: "large"),
                RecipeIngredient(produceId: "basil", name: "Basil", quantity: "1", unit: "bunch"),
                RecipeIngredient(produceId: nil, name: "Salt", quantity: "1", unit: "pinch")
            ],
            instructions: ["Step 1"],
            prepTimeMinutes: 10,
            cookTimeMinutes: 0,
            servings: 2,
            imageName: "test"
        )

        let inSeason: Set<String> = ["tomato", "spinach"]
        XCTAssertEqual(recipe.seasonalMatchCount(inSeason: inSeason), 1)
        XCTAssertEqual(recipe.trackableProduceCount, 2)
    }
}
