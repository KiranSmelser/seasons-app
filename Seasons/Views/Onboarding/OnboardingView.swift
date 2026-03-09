import SwiftUI
import AuthenticationServices
import StoreKit
import os

struct OnboardingView: View {
    let authService: AuthService
    let onComplete: () -> Void

    @State private var locationService = LocationService()
    @State private var currentPage = 0
    @State private var errorMessage: String?

    private static let totalPages = 7
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "OnboardingView")

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                OnboardingWelcomePage()
                    .tag(0)
                OnboardingFeaturePage(
                    icon: "leaf.fill",
                    color: .seasonGreen,
                    title: "Discover What's in Season",
                    description: "Browse produce that's fresh, local, and at peak flavor, filtered for your growing region."
                )
                .tag(1)
                OnboardingFeaturePage(
                    icon: "book.fill",
                    color: .orange,
                    title: "Cook with the Seasons",
                    description: "Explore recipes built around seasonal ingredients so your meals are always fresh."
                )
                .tag(2)
                OnboardingCarbonPage()
                    .tag(3)
                OnboardingPaywallPage()
                    .tag(4)
                OnboardingRegionPage(locationService: locationService)
                    .tag(5)
                OnboardingSignInPage(
                    authService: authService,
                    onComplete: onComplete,
                    errorMessage: $errorMessage
                )
                .tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom navigation bar — hidden on sign-in page (it handles its own CTAs)
            if currentPage < Self.totalPages - 1 {
                bottomBar
            }
        }
        .alert("Sign-in Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("Skip") {
                onComplete()
            }
            .foregroundStyle(.secondary)

            Spacer()

            pageIndicator

            Spacer()

            Button {
                withAnimation {
                    currentPage = min(currentPage + 1, Self.totalPages - 1)
                }
            } label: {
                Text("Next")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(Color.seasonGreen)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.seasonGreen : Color(.systemGray4))
                    .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                    .animation(.easeInOut, value: currentPage)
            }
        }
    }
}

// MARK: - Page 1: Welcome

private struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.seasonGreen)

            VStack(spacing: 12) {
                Text("Welcome to Seasons")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Eat fresher, cook smarter, and reduce your carbon footprint. One season at a time.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Page 2 & 3: Feature Pages (reusable)

private struct OnboardingFeaturePage: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(color)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Page 4: Carbon Impact

private struct OnboardingCarbonPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "leaf.arrow.triangle.circlepath")
                .font(.system(size: 72))
                .foregroundStyle(Color.green)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Track Your Impact")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Pro")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green)
                        .clipShape(Capsule())
                }

                Text("Log what you're eating locally and see your estimated carbon savings. Requires Seasons Pro.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Page 5: Pro Subscription

private struct OnboardingPaywallPage: View {
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
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
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 14) {
                    ProFeatureRow(icon: "chart.bar.fill", text: "Carbon Impact dashboard")
                    ProFeatureRow(icon: "icloud.fill", text: "Cross-device sync for favorites")
                    ProFeatureRow(icon: "arrow.triangle.2.circlepath", text: "Carbon logs synced everywhere")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if subscriptionService.isPro {
                    Label("You're all set with Seasons Pro!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.seasonGreen)
                } else {
                    VStack(spacing: 12) {
                        if let annual = subscriptionService.annualProduct {
                            Button {
                                Task { await subscriptionService.purchase(annual) }
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
                            paywallPlaceholder(title: "Annual", subtitle: "$19.99 / year", badge: "Save 17%", isPrimary: true)
                        }

                        if let monthly = subscriptionService.monthlyProduct {
                            Button {
                                Task { await subscriptionService.purchase(monthly) }
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
                            paywallPlaceholder(title: "Monthly", subtitle: "$1.99 / month", badge: nil, isPrimary: false)
                        }

                        if subscriptionService.isLoading {
                            ProgressView().padding(.top, 4)
                        }
                    }

                    Button {
                        Task { await subscriptionService.restorePurchases() }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(subscriptionService.isLoading)

                    if let error = subscriptionService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }

                Text("Subscriptions renew automatically. Cancel anytime in Settings > Apple ID > Subscriptions.")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray3))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 80) // room for the bottom nav bar
            }
            .padding(.horizontal)
        }
        .task {
            await subscriptionService.loadProducts()
        }
    }

    @ViewBuilder
    private func paywallPlaceholder(title: String, subtitle: String, badge: String?, isPrimary: Bool) -> some View {
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
}

// MARK: - Page 6: Region Setup

private struct OnboardingRegionPage: View {
    let locationService: LocationService

    @State private var gpsDetectedRegion: GrowingRegion?
    @State private var waitingForGPS = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.seasonGreen)

            VStack(spacing: 12) {
                Text("Where Are You Growing?")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Choose your region for accurate seasonal data.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                // Binding reads locationService.region directly so GPS updates
                // refresh the picker without re-triggering setManualRegion.
                Picker("Region", selection: Binding(
                    get: { locationService.region },
                    set: { newRegion in
                        locationService.setManualRegion(newRegion)
                        gpsDetectedRegion = nil
                    }
                )) {
                    ForEach(GrowingRegion.allCases) { region in
                        Text(region.displayName).tag(region)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    waitingForGPS = true
                    locationService.useCurrentLocation()
                } label: {
                    Label("Use My Location", systemImage: "location.circle")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.seasonGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let detected = gpsDetectedRegion {
                    Label("Detected: \(detected.displayName)", systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.seasonGreen)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut, value: gpsDetectedRegion != nil)

            Spacer()
            Spacer()
        }
        .padding()
        .onChange(of: locationService.region) { _, newRegion in
            guard waitingForGPS else { return }
            gpsDetectedRegion = newRegion
            waitingForGPS = false
        }
    }
}

// MARK: - Page 7: Sign In

private struct OnboardingSignInPage: View {
    let authService: AuthService
    let onComplete: () -> Void
    @Binding var errorMessage: String?

    @Environment(SubscriptionService.self) private var subscriptionService

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "OnboardingSignInPage")

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: subscriptionService.isPro ? "icloud.fill" : "person.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(subscriptionService.isPro ? Color.seasonGreen : Color(.systemGray3))

            VStack(spacing: 12) {
                Text(subscriptionService.isPro ? "Sync Across Devices" : "Sign In")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(subscriptionService.isPro
                     ? "Sign in to start syncing your favorites and carbon logs across all your devices."
                     : "Sign in to save your account. You can upgrade to Pro anytime to unlock sync.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                // Hidden Apple button to satisfy AuthenticationServices requirement
                SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                    .hidden()
                    .frame(height: 0)

                Button {
                    Task {
                        do {
                            try await authService.signInWithApple()
                            onComplete()
                        } catch {
                            logger.error("Apple sign-in error: \(error, privacy: .private)")
                            errorMessage = friendlyMessage(for: error)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                        Text("Sign in with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(authService.isLoading)

                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                    Text("or")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color(.systemGray4))
                }

                Button {
                    Task {
                        do {
                            try await authService.signInWithGoogle()
                            onComplete()
                        } catch {
                            logger.error("Google sign-in error: \(error, privacy: .private)")
                            errorMessage = friendlyMessage(for: error)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray3), lineWidth: 1)
                    )
                }
                .disabled(authService.isLoading)

                Button {
                    onComplete()
                } label: {
                    Text("Skip for now")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding()
    }

    private func friendlyMessage(for error: Error) -> String {
        let desc = error.localizedDescription.lowercased()
        if desc.contains("cancel") || desc.contains("dismiss") {
            return "Sign-in was cancelled."
        }
        if desc.contains("network") || desc.contains("internet") ||
           desc.contains("offline") || desc.contains("connection") {
            return "No internet connection. Please check your network and try again."
        }
        if desc.contains("invalid") || desc.contains("unauthorized") ||
           desc.contains("credential") || desc.contains("token") {
            return "Sign-in failed. Please try again."
        }
        return "Something went wrong. Please try again."
    }
}
