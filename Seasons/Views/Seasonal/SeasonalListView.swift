import SwiftUI
import SwiftData

struct SeasonalListView: View {
    let authService: AuthService

    @Environment(LocationService.self) private var locationService
    @State private var viewModel: SeasonalViewModel?
    @State private var showRegionPicker = false
    @State private var showAccountSheet = false

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Query(filter: #Predicate<Favorite> { !$0.isSoftDeleted }) private var favorites: [Favorite]

    private var produceFavoritedIds: Set<String> {
        Set(favorites.filter { $0.itemType == "produce" }.map(\.itemId))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    seasonalContent(viewModel: viewModel)
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("In Season")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAccountSheet = true
                    } label: {
                        Image(systemName: authService.isSignedIn ? "person.crop.circle.fill" : "person.crop.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRegionPicker = true
                    } label: {
                        Label(locationService.region.displayName, systemImage: "location.fill")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showAccountSheet) {
                AccountSheetView(authService: authService, locationService: locationService)
            }
            .sheet(isPresented: $showRegionPicker) {
                RegionPickerView(locationService: locationService)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SeasonalViewModel(locationService: locationService)
                }
                if !locationService.hasLocation && hasSeenOnboarding {
                    locationService.requestPermission()
                }
            }
        }
    }

    @ViewBuilder
    private func seasonalContent(viewModel: SeasonalViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection(viewModel: viewModel)
                categoryFilter(viewModel: viewModel)
                produceGrid(viewModel: viewModel)
            }
            .padding()
        }
        .searchable(text: Bindable(viewModel).searchText, prompt: "Search produce")
    }

    @ViewBuilder
    private func headerSection(viewModel: SeasonalViewModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.currentMonthName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.seasonGreen)
            Text("\(viewModel.inSeasonCount) items in season in the \(locationService.region.displayName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func categoryFilter(viewModel: SeasonalViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: viewModel.selectedCategory == nil && !viewModel.showFavoritesOnly
                ) {
                    viewModel.selectedCategory = nil
                    viewModel.showFavoritesOnly = false
                }

                FilterChip(
                    title: "Favorites",
                    isSelected: viewModel.showFavoritesOnly,
                    systemImage: "heart.fill"
                ) {
                    viewModel.showFavoritesOnly.toggle()
                    if viewModel.showFavoritesOnly {
                        viewModel.selectedCategory = nil
                    }
                }

                ForEach(ProduceCategory.allCases) { category in
                    FilterChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category && !viewModel.showFavoritesOnly
                    ) {
                        viewModel.selectedCategory = category
                        viewModel.showFavoritesOnly = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func produceGrid(viewModel: SeasonalViewModel) -> some View {
        let items = viewModel.filteredProduce(favoritedIds: produceFavoritedIds)

        if items.isEmpty {
            ContentUnavailableView(
                "No produce found",
                systemImage: "leaf.fill",
                description: Text("Try a different category or search term.")
            )
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink(value: ProduceDestination(produceId: item.id)) {
                        ProduceCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        let isFavorited = produceFavoritedIds.contains(item.id)
                        Button {
                            FavoritesService(modelContext: modelContext)
                                .toggleFavorite(itemType: "produce", itemId: item.id)
                            if subscriptionService.isPro {
                                syncCoordinator.notifyMutation()
                            }
                        } label: {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundStyle(isFavorited ? .red : .secondary)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(6)
                    }
                }
            }
            .navigationDestination(for: ProduceDestination.self) { destination in
                if let item = ProduceDataService.shared.produce(byId: destination.produceId) {
                    ProduceDetailView(item: item, region: locationService.region)
                } else {
                    ContentUnavailableView("Item Not Found", systemImage: "questionmark.circle")
                }
            }
            .navigationDestination(for: RecipeDestination.self) { destination in
                if let recipe = RecipeDataService.shared.recipe(byId: destination.recipeId) {
                    RecipeDetailView(recipe: recipe, locationService: locationService)
                } else {
                    ContentUnavailableView("Recipe Not Found", systemImage: "questionmark.circle")
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.seasonGreen : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

struct ProduceCard: View {
    let item: ProduceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if UIImage(named: item.imageName) != nil {
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .aspectRatio(1.0, contentMode: .fit)
                    Image(systemName: item.category.systemImage)
                        .font(.system(size: 36))
                        .foregroundStyle(Color.seasonGreen.opacity(0.6))
                }
            }

            Text(item.name)
                .font(.headline)
                .lineLimit(1)

            Text(item.category.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct RegionPickerView: View {
    let locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(GrowingRegion.allCases) { region in
                Button {
                    locationService.setManualRegion(region)
                    dismiss()
                } label: {
                    HStack {
                        Text(region.displayName)
                        Spacer()
                        if locationService.region == region {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.seasonGreen)
                        }
                    }
                }
            }
            .navigationTitle("Select Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    SeasonalListView(authService: AuthService())
        .environment(SyncCoordinator.preview)
        .environment(SubscriptionService())
        .environment(LocationService())
        .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
