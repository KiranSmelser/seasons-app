import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe
    let locationService: LocationService

    @Environment(\.modelContext) private var modelContext

    @State private var isFavorited = false

    private var viewModel: RecipeViewModel {
        RecipeViewModel(locationService: locationService)
    }

    private var favoritesService: FavoritesService {
        FavoritesService(modelContext: modelContext)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                ingredientsSection
                instructionsSection
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesService.toggleFavorite(itemType: "recipe", itemId: recipe.id)
                    isFavorited.toggle()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .red : .secondary)
                }
            }
        }
        .onAppear {
            isFavorited = favoritesService.isFavorited(itemType: "recipe", itemId: recipe.id)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.description)
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if recipe.prepTimeMinutes > 0 {
                    Label("\(recipe.prepTimeMinutes) min prep", systemImage: "hands.sparkles")
                        .font(.caption)
                }
                if recipe.cookTimeMinutes > 0 {
                    Label("\(recipe.cookTimeMinutes) min cook", systemImage: "flame")
                        .font(.caption)
                }
                Label("\(recipe.servings) servings", systemImage: "person.2")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            if recipe.trackableProduceCount > 0 {
                let matchCount = viewModel.seasonalMatchCount(for: recipe)
                SeasonalBadge(matchCount: matchCount, totalCount: recipe.trackableProduceCount)
            }
        }
    }

    @ViewBuilder
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.headline)

            ForEach(recipe.ingredients) { ingredient in
                let isInSeason = viewModel.isIngredientInSeason(ingredient)
                let hasProduce = ingredient.produceId != nil

                if hasProduce {
                    NavigationLink(value: ProduceDestination(produceId: ingredient.produceId!)) {
                        ingredientRow(ingredient: ingredient, isInSeason: isInSeason, tappable: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    ingredientRow(ingredient: ingredient, isInSeason: isInSeason, tappable: false)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func ingredientRow(ingredient: RecipeIngredient, isInSeason: Bool, tappable: Bool) -> some View {
        HStack(spacing: 8) {
            if isInSeason {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(Color.seasonGreen)
            } else {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Color.secondary)
            }

            Text("\(ingredient.quantity) \(ingredient.unit)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(ingredient.name)
                .font(.subheadline)
                .fontWeight(isInSeason ? .semibold : .regular)

            if tappable {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.headline)

            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.seasonGreen)
                        .clipShape(Circle())

                    Text(step)
                        .font(.subheadline)
                }
            }
        }
    }
}

struct SeasonalBadge: View {
    let matchCount: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
            Text("\(matchCount) of \(totalCount) seasonal ingredients available now")
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(matchCount > 0 ? Color.seasonGreen.opacity(0.15) : Color(.systemGray6))
        .foregroundStyle(matchCount > 0 ? Color.seasonGreen : Color.secondary)
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(
            recipe: Recipe(
                id: "test",
                name: "Test Recipe",
                description: "A test recipe.",
                ingredients: [
                    RecipeIngredient(produceId: "tomato", name: "Tomato", quantity: "2", unit: "large"),
                    RecipeIngredient(produceId: nil, name: "Salt", quantity: "1", unit: "pinch")
                ],
                instructions: ["Step one.", "Step two."],
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                servings: 4
            ),
            locationService: LocationService()
        )
    }
    .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
