import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    featureList
                    planButtons
                    restoreButton
                    if let error = subscriptionService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    legalFooter
                }
                .padding()
            }
            .navigationTitle("Seasons Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await subscriptionService.loadProducts()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.seasonGreen)

            Text("Go Pro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Unlock Carbon Impact tracking and keep your favorites in sync across all your devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProFeatureRow(icon: "chart.bar.fill", text: "Carbon Impact dashboard")
            ProFeatureRow(icon: "icloud.fill", text: "Cross-device sync for favorites")
            ProFeatureRow(icon: "arrow.triangle.2.circlepath", text: "Carbon logs synced everywhere")
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var planButtons: some View {
        VStack(spacing: 12) {
            // Annual plan — highlighted as best value
            if let annual = subscriptionService.annualProduct {
                Button {
                    Task {
                        await subscriptionService.purchase(annual)
                        if subscriptionService.isPro { dismiss() }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Annual")
                                .fontWeight(.semibold)
                            Text(annual.displayPrice + " / year")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Spacer()
                        Text("Save 17%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.25))
                            .clipShape(Capsule())
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.seasonGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(subscriptionService.isLoading)
            } else {
                planPlaceholder(title: "Annual", subtitle: "$19.99 / year", badge: "Save 17%", isPrimary: true)
            }

            // Monthly plan
            if let monthly = subscriptionService.monthlyProduct {
                Button {
                    Task {
                        await subscriptionService.purchase(monthly)
                        if subscriptionService.isPro { dismiss() }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Monthly")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(monthly.displayPrice + " / month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(subscriptionService.isLoading)
            } else {
                planPlaceholder(title: "Monthly", subtitle: "$1.99 / month", badge: nil, isPrimary: false)
            }

            if subscriptionService.isLoading {
                ProgressView()
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func planPlaceholder(title: String, subtitle: String, badge: String?, isPrimary: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(isPrimary ? .white : .primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(isPrimary ? .white.opacity(0.85) : .secondary)
            }
            Spacer()
            if let badge {
                Text(badge)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isPrimary ? .white.opacity(0.25) : Color(.systemGray4))
                    .clipShape(Capsule())
                    .foregroundStyle(isPrimary ? .white : .primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(isPrimary ? Color.seasonGreen : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .redacted(reason: .placeholder)
    }

    @ViewBuilder
    private var restoreButton: some View {
        Button {
            Task { await subscriptionService.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .disabled(subscriptionService.isLoading)
    }

    @ViewBuilder
    private var legalFooter: some View {
        Text("Subscriptions renew automatically. Cancel anytime in Settings > Apple ID > Subscriptions.")
            .font(.caption2)
            .foregroundStyle(Color(.systemGray3))
            .multilineTextAlignment(.center)
    }
}

struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.seasonGreen)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionService())
}
