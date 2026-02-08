import XCTest
@testable import Seasons

final class DataIntegrityTests: XCTestCase {

    private var allProduce: [ProduceItem] { ProduceDataService.shared.allProduce }
    private var allRecipes: [Recipe] { RecipeDataService.shared.allRecipes }

    // MARK: - Produce Data Integrity

    func testAllProduceHaveUniqueIds() {
        let ids = allProduce.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate produce IDs found")
    }

    func testAllProduceHaveValidSeasons() {
        for item in allProduce {
            for (region, months) in item.seasonsByRegion {
                for month in months {
                    XCTAssertTrue((1...12).contains(month),
                        "\(item.id) has invalid month \(month) for region \(region)")
                }
            }
        }
    }

    func testAllProduceHavePositiveCarbonValues() {
        for item in allProduce {
            XCTAssertGreaterThan(item.localCarbonKgPerKg, 0,
                "\(item.id) has non-positive localCarbonKgPerKg")
            XCTAssertGreaterThan(item.importedCarbonKgPerKg, 0,
                "\(item.id) has non-positive importedCarbonKgPerKg")
        }
    }

    func testAllProduceHaveAtLeastOneRegion() {
        for item in allProduce {
            XCTAssertFalse(item.seasonsByRegion.isEmpty,
                "\(item.id) has no regions defined")
        }
    }

    // MARK: - Recipe Data Integrity

    func testAllRecipesHaveUniqueIds() {
        let ids = allRecipes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Duplicate recipe IDs found")
    }

    func testAllRecipeProduceIdsExistInProduceData() {
        let produceIds = Set(allProduce.map(\.id))
        for recipe in allRecipes {
            for produceId in recipe.produceIds {
                XCTAssertTrue(produceIds.contains(produceId),
                    "Recipe '\(recipe.id)' references unknown produce '\(produceId)'")
            }
        }
    }

    func testAllRecipesHavePositiveServings() {
        for recipe in allRecipes {
            XCTAssertGreaterThan(recipe.servings, 0,
                "Recipe '\(recipe.id)' has non-positive servings")
        }
    }

    // MARK: - Cross-Referencing

    func testAllProduceHaveAtLeastOneRecipe() {
        let allRecipeProduceIds = Set(allRecipes.flatMap(\.produceIds))
        for item in allProduce {
            XCTAssertTrue(allRecipeProduceIds.contains(item.id),
                "Produce '\(item.id)' (\(item.name)) has no recipes")
        }
    }
}
