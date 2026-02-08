import SwiftUI
import SwiftData

struct ProduceDetailView: View {
    let item: ProduceItem
    let region: GrowingRegion

    @Environment(\.modelContext) private var modelContext

    private let monthAbbreviations = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    private var linkedRecipes: [Recipe] {
        RecipeDataService.shared.recipes(using: item.id)
    }

    private var favoritesService: FavoritesService {
        FavoritesService(modelContext: modelContext)
    }

    @State private var isFavorited = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                seasonalCalendar
                carbonSection
                descriptionSection
                if !linkedRecipes.isEmpty {
                    recipesSection
                }
            }
            .padding()
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    favoritesService.toggleFavorite(itemType: "produce", itemId: item.id)
                    isFavorited.toggle()
                } label: {
                    Image(systemName: isFavorited ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorited ? .red : .secondary)
                }
            }
        }
        .onAppear {
            isFavorited = favoritesService.isFavorited(itemType: "produce", itemId: item.id)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 16) {
            if UIImage(named: item.imageName) != nil {
                Image(item.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)
                    Image(systemName: item.category.systemImage)
                        .font(.system(size: 32))
                        .foregroundStyle(Color.seasonGreen)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(item.category.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if item.isInSeason(region: region, month: currentMonth) {
                    Label("In season now", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.seasonGreen)
                } else {
                    Label("Not in season", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var seasonalCalendar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seasonality in \(region.displayName)")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach(1...12, id: \.self) { month in
                    let inSeason = item.isInSeason(region: region, month: month)
                    let isCurrent = month == currentMonth

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(inSeason ? Color.seasonGreen : Color(.systemGray5))
                            .frame(height: 32)
                            .overlay {
                                if isCurrent {
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                }
                            }
                        Text(monthAbbreviations[month - 1])
                            .font(.system(size: 10))
                            .foregroundStyle(isCurrent ? .primary : .secondary)
                    }
                }
            }

            Text("Current month outlined")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var carbonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Carbon Footprint")
                .font(.headline)

            HStack(spacing: 16) {
                CarbonCard(
                    title: "Local & Seasonal",
                    value: String(format: "%.2f", item.localCarbonKgPerKg),
                    unit: "kg CO\u{2082}/kg",
                    color: .seasonGreen
                )
                CarbonCard(
                    title: "Imported",
                    value: String(format: "%.2f", item.importedCarbonKgPerKg),
                    unit: "kg CO\u{2082}/kg",
                    color: .orange
                )
            }

            Text("Choosing local saves **\(String(format: "%.2f", item.carbonSavingsPerKg)) kg CO\u{2082}** per kg")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)
            Text(item.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipes with \(item.name)")
                .font(.headline)

            ForEach(linkedRecipes) { recipe in
                NavigationLink(value: RecipeDestination(recipeId: recipe.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(recipe.totalTimeMinutes) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CarbonCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        ProduceDetailView(
            item: ProduceItem(
                id: "tomato",
                name: "Tomato",
                category: .vegetable,
                description: "Versatile and flavorful vine-ripened tomatoes.",
                imageName: "tomato",
                seasonsByRegion: ["northeast": [7, 8, 9]],
                localCarbonKgPerKg: 0.4,
                importedCarbonKgPerKg: 2.5
            ),
            region: .northeast
        )
    }
    .modelContainer(for: [CarbonLog.self, Favorite.self], inMemory: true)
}
