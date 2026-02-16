import Foundation
import AuthenticationServices
import UIKit
import CryptoKit
import Supabase
import Auth
import GoogleSignIn

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

    @MainActor
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw AuthError.missingPresentingViewController
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as! String,
            serverClientID: "134875106487-4ljn55lqgrh8kbgifr42ms0ku0d2pfn7.apps.googleusercontent.com"
        )

        let rawNonce = generateNonce()
        let hashedNonce = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC,
            hint: nil,
            additionalScopes: nil,
            nonce: hashedNonce
        )

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingGoogleToken
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .google, idToken: idToken, nonce: rawNonce)
        )
        currentUser = session.user
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
    }

    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
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
    case missingGoogleToken
    case missingPresentingViewController

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Unable to retrieve Apple ID token."
        case .missingGoogleToken:
            return "Unable to retrieve Google ID token."
        case .missingPresentingViewController:
            return "Unable to find a presenting view controller."
        }
    }
}
