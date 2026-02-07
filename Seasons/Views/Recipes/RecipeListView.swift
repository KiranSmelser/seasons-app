import SwiftUI

struct RecipeListView: View {
    @State private var locationService = LocationService()
    @State private var viewModel: RecipeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    recipeContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Recipes")
            .onAppear {
                if viewModel == nil {
                    viewModel = RecipeViewModel(locationService: locationService)
                }
            }
        }
    }

    @ViewBuilder
    private func recipeContent(viewModel: RecipeViewModel) -> some View {
        List(viewModel.recipes) { recipe in
            NavigationLink(value: recipe.id) {
                RecipeRow(recipe: recipe, viewModel: viewModel)
            }
        }
        .listStyle(.plain)
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search recipes")
        .navigationDestination(for: String.self) { recipeId in
            if let recipe = RecipeDataService.shared.recipe(byId: recipeId) {
                RecipeDetailView(recipe: recipe, viewModel: viewModel)
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    let viewModel: RecipeViewModel

    private var matchCount: Int {
        viewModel.seasonalMatchCount(for: recipe)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.name)
                .font(.headline)

            Text(recipe.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                if recipe.trackableProduceCount > 0 {
                    Label(
                        "\(matchCount)/\(recipe.trackableProduceCount) in season",
                        systemImage: "leaf.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(matchCount > 0 ? .green : .secondary)
                }

                Label("\(recipe.totalTimeMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(recipe.servings) servings", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecipeListView()
}
