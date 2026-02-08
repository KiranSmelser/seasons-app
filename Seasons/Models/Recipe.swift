import Foundation

struct RecipeIngredient: Codable, Identifiable {
    var id: String { name }
    let produceId: String?
    let name: String
    let quantity: String
    let unit: String
}

struct Recipe: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let ingredients: [RecipeIngredient]
    let instructions: [String]
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int
    let servings: Int

    var totalTimeMinutes: Int {
        prepTimeMinutes + cookTimeMinutes
    }

    /// IDs of produce items used in this recipe.
    var produceIds: [String] {
        ingredients.compactMap(\.produceId)
    }

    /// Returns how many of this recipe's produce ingredients are currently in season.
    func seasonalMatchCount(inSeason produceIds: Set<String>) -> Int {
        self.produceIds.filter { produceIds.contains($0) }.count
    }

    /// Total produce ingredients that are trackable (have a produceId).
    var trackableProduceCount: Int {
        self.produceIds.count
    }
}
