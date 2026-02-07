import SwiftUI

struct SeasonalListView: View {
    @State private var locationService = LocationService()
    @State private var viewModel: SeasonalViewModel?
    @State private var showRegionPicker = false

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRegionPicker = true
                    } label: {
                        Label(locationService.region.displayName, systemImage: "location.fill")
                            .font(.caption)
                    }
                }
            }
            .sheet(isPresented: $showRegionPicker) {
                RegionPickerView(locationService: locationService)
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = SeasonalViewModel(locationService: locationService)
                }
                if !locationService.hasLocation {
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
                .foregroundStyle(.green)
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
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                ForEach(ProduceCategory.allCases) { category in
                    FilterChip(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func produceGrid(viewModel: SeasonalViewModel) -> some View {
        if viewModel.seasonalProduce.isEmpty {
            ContentUnavailableView(
                "No produce found",
                systemImage: "leaf.fill",
                description: Text("Try a different category or search term.")
            )
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.seasonalProduce) { item in
                    NavigationLink(value: item.id) {
                        ProduceCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationDestination(for: String.self) { produceId in
                if let item = ProduceDataService.shared.produce(byId: produceId) {
                    ProduceDetailView(item: item, region: locationService.region)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color(.systemGray6))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ProduceCard: View {
    let item: ProduceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .aspectRatio(1.0, contentMode: .fit)
                Image(systemName: item.category.systemImage)
                    .font(.system(size: 36))
                    .foregroundStyle(.green.opacity(0.6))
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
                                .foregroundStyle(.green)
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
    SeasonalListView()
}
