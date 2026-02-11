import Foundation
import AuthenticationServices
import Supabase
import Auth

@Observable
final class AuthService: NSObject {
    let supabase: SupabaseClient

    private(set) var currentUser: User?
    private(set) var isLoading = false

    var isSignedIn: Bool { currentUser != nil }

    private var signInContinuation: CheckedContinuation<ASAuthorization, Error>?

    override init() {
        self.supabase = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
        super.init()
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            currentUser = nil
        }
    }

    @MainActor
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }

        let authorization = try await performAppleSignIn()

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken)
        )
        currentUser = session.user
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
    }

    @MainActor
    private func performAppleSignIn() async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        signInContinuation?.resume(returning: authorization)
        signInContinuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        signInContinuation?.resume(throwing: error)
        signInContinuation = nil
    }
}

enum AuthError: LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Unable to retrieve Apple ID token."
        }
    }
}
