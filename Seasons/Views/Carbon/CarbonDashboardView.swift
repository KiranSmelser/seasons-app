import SwiftUI
import SwiftData

struct CarbonDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(SubscriptionService.self) private var subscriptionService
    @Query(filter: #Predicate<CarbonLog> { !$0.isSoftDeleted }, sort: \CarbonLog.date, order: .reverse) private var logs: [CarbonLog]
    @State private var viewModel = CarbonViewModel()
    @State private var showAddSheet = false
    @State private var showPaywall = false

    private var filteredLogs: [CarbonLog] {
        viewModel.filteredLogs(from: logs)
    }

    var body: some View {
        NavigationStack {
            if subscriptionService.isPro {
                dashboardContent
            } else {
                CarbonLockedView(showPaywall: $showPaywall)
                    .navigationTitle("Impact")
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
            }
        }
    }

    @ViewBuilder
    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                timePeriodPicker
                summaryCard
                if !filteredLogs.isEmpty {
                    equivalenciesSection
                    topProduceSection
                    recentLogsSection
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Impact")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ShareLink(item: viewModel.shareText(from: filteredLogs)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(filteredLogs.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCarbonLogView(viewModel: viewModel) { entry in
                modelContext.insert(entry)
                try? modelContext.save()
                if subscriptionService.isPro { syncCoordinator.notifyMutation() }
            }
        }
    }

    @ViewBuilder
    private var timePeriodPicker: some View {
        Picker("Time Period", selection: $viewModel.selectedTimePeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var summaryCard: some View {
        let total = viewModel.totalCarbonSaved(from: filteredLogs)
        VStack(spacing: 8) {
            Text("Total CO\u{2082} Saved")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(CarbonCalculationService.formattedCarbon(total))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(Color.seasonGreen)
            Text("by choosing local, seasonal produce")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.seasonGreen.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var equivalenciesSection: some View {
        let equivalencies = viewModel.equivalencies(from: filteredLogs)
        VStack(alignment: .leading, spacing: 12) {
            Text("That's equivalent to...")
                .font(.headline)

            ForEach(equivalencies, id: \.description) { equiv in
                HStack {
                    Text(equiv.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f %@", equiv.value, equiv.unit))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var topProduceSection: some View {
        let breakdown = viewModel.topProduceBreakdown(from: filteredLogs)
        if !breakdown.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Produce")
                    .font(.headline)

                ForEach(breakdown) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.produceName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(item.logCount) log\(item.logCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("-\(CarbonCalculationService.formattedCarbon(item.totalCarbonSavedKg)) CO\u{2082}")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.seasonGreen)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    @ViewBuilder
    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(.headline)

            ForEach(filteredLogs.prefix(10)) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.produceName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(log.date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f kg", log.quantityKg))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("-\(CarbonCalculationService.formattedCarbon(log.carbonSavedKg)) CO\u{2082}")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.seasonGreen)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contextMenu {
                    Button(role: .destructive) {
                        log.isSoftDeleted = true
                        log.isSynced = false
                        log.updatedAt = Date()
                        try? modelContext.save()
                        if subscriptionService.isPro { syncCoordinator.notifyMutation() }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Logs Yet", systemImage: "chart.bar.fill")
        } description: {
            Text("Tap + to log when you buy local, seasonal produce and track your carbon savings.")
        }
    }
}

struct AddCarbonLogView: View {
    @Bindable var viewModel: CarbonViewModel
    let onSave: (CarbonLog) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you buy?") {
                    Picker("Produce", selection: $viewModel.selectedProduceId) {
                        Text("Select...").tag(nil as String?)
                        ForEach(viewModel.availableProduce) { item in
                            Text(item.name).tag(item.id as String?)
                        }
                    }
                }

                Section("How much? (kg)") {
                    TextField("e.g. 0.5", text: $viewModel.quantityString)
                        .keyboardType(.decimalPad)
                }

                if let produce = viewModel.selectedProduce, let qty = Double(viewModel.quantityString), qty > 0 {
                    Section("Estimated Savings") {
                        let saved = CarbonCalculationService.carbonSaved(produce: produce, quantityKg: qty)
                        HStack {
                            Text("CO\u{2082} saved vs. imported")
                            Spacer()
                            Text(CarbonCalculationService.formattedCarbon(saved))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.seasonGreen)
                        }
                    }
                }
            }
            .navigationTitle("Log Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let entry = viewModel.createLogEntry() {
                            onSave(entry)
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.canLog)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct CarbonLockedView: View {
    @Binding var showPaywall: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.seasonGreen.opacity(0.4))

                VStack(spacing: 8) {
                    Text("Carbon Impact")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Track your CO\u{2082} savings from choosing local, seasonal produce. Available with Seasons Pro.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ProFeatureRow(icon: "chart.bar.fill", text: "Carbon Impact dashboard")
                    ProFeatureRow(icon: "icloud.fill", text: "Cross-device sync for favorites")
                    ProFeatureRow(icon: "arrow.triangle.2.circlepath", text: "Carbon logs synced everywhere")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.seasonGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
    }
}

#Preview("Pro") {
    CarbonDashboardView()
        .environment(SyncCoordinator.preview)
        .environment(SubscriptionService())
        .modelContainer(for: CarbonLog.self, inMemory: true)
}

#Preview("Locked") {
    CarbonDashboardView()
        .environment(SyncCoordinator.preview)
        .environment(SubscriptionService())
        .modelContainer(for: CarbonLog.self, inMemory: true)
}
