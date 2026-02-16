import SwiftUI
import AuthenticationServices

struct AccountSheetView: View {
    let authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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

            Text("Sign in to sync your favorites and carbon logs across devices.")
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
                    errorMessage = error.localizedDescription
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
                    errorMessage = error.localizedDescription
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
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.seasonGreen)

            Text("Signed In")
                .font(.title2)
                .fontWeight(.bold)

            if let email = authService.currentUser?.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Your favorites and carbon logs are syncing across devices.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }

        Spacer()

        Button(role: .destructive) {
            Task {
                do {
                    try await authService.signOut()
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
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
