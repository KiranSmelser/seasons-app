import SwiftUI
import SwiftData

struct RecipeListView: View {
    @State private var locationService = LocationService()
    @State private var viewModel: RecipeViewModel?

    @Environment(\.modelContext) private var modelContext

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
        let favoritesService = FavoritesService(modelContext: modelContext)
        let recipes = viewModel.filteredRecipes(favoritedIds: favoritesService.favoritedIds(for: "recipe"))

        List {
            Section {
                ForEach(recipes) { recipe in
                    NavigationLink(value: RecipeDestination(recipeId: recipe.id)) {
                        RecipeRow(
                            recipe: recipe,
                            viewModel: viewModel,
                            isFavorited: favoritesService.isFavorited(itemType: "recipe", itemId: recipe.id),
                            onToggleFavorite: {
                                favoritesService.toggleFavorite(itemType: "recipe", itemId: recipe.id)
                            }
                        )
                    }
                }
            } header: {
                HStack {
                    Spacer()
                    Button {
                        viewModel.showFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                            Text("Favorites")
                        }
                        .font(.subheadline)
                        .fontWeight(viewModel.showFavoritesOnly ? .semibold : .regular)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.showFavoritesOnly ? Color.seasonGreen : Color(.systemGray6))
                        .foregroundStyle(viewModel.showFavoritesOnly ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
                .textCase(nil)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search recipes")
        .navigationDestination(for: RecipeDestination.self) { destination in
            if let recipe = RecipeDataService.shared.recipe(byId: destination.recipeId) {
                RecipeDetailView(recipe: recipe, locationService: locationService)
            }
        }
        .navigationDestination(for: ProduceDestination.self) { destination in
            if let item = ProduceDataService.shared.produce(byId: destination.produceId) {
                ProduceDetailView(item: item, region: locationService.region)
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    let viewModel: RecipeViewModel
    let isFavorited: Bool
    let onToggleFavorite: () -> Void

    private var matchCount: Int {
        viewModel.seasonalMatchCount(for: recipe)
    }

    var body: some View {
        HStack {
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
                        .foregroundStyle(matchCount > 0 ? Color.seasonGreen : Color.secondary)
                    }

                    Label("\(recipe.totalTimeMinutes) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(recipe.servings) servings", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorited ? .red : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RecipeListView()
        .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
