import SwiftUI
import AuthenticationServices
import os

struct AccountSheetView: View {
    let authService: AuthService
    let locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var errorMessage: String?
    @State private var showPaywall = false

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.kiransmelser.seasons", category: "AccountSheetView")

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if authService.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }
            }
            .padding()
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView(authService: authService, locationService: locationService)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }

    @ViewBuilder
    private var signedOutView: some View {
        Spacer()

        VStack(spacing: 16) {
            Image(systemName: "icloud")
                .font(.system(size: 48))
                .foregroundStyle(Color.seasonGreen)

            Text("Sync Your Data")
                .font(.title2)
                .fontWeight(.bold)

            Text("Sign in with a Seasons Pro subscription to sync your favorites and carbon logs across devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }

        SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
            .hidden()
            .frame(height: 0)

        Button {
            Task {
                do {
                    try await authService.signInWithApple()
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

        Spacer()
    }

    @ViewBuilder
    private var signedInView: some View {
        Spacer()

        VStack(spacing: 16) {
            Image(systemName: subscriptionService.isPro ? "checkmark.icloud.fill" : "icloud.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(subscriptionService.isPro ? Color.seasonGreen : Color(.systemGray3))

            Text("Signed In")
                .font(.title2)
                .fontWeight(.bold)

            if let email = authService.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if subscriptionService.isPro {
                Label("Pro · Syncing active", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.seasonGreen)
            } else {
                Text("Sync requires a Pro subscription.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade to Pro")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.seasonGreen)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }

        Spacer()

        Button(role: .destructive) {
            Task {
                do {
                    try await authService.signOut()
                    dismiss()
                } catch {
                    logger.error("Sign-out error: \(error, privacy: .private)")
                    errorMessage = friendlyMessage(for: error)
                }
            }
        } label: {
            Text("Sign Out")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }

    }

}
