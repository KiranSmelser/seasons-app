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
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
        super.init()
        Task { await restoreSession() }
    }

    private func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
        } catch {
            print("[AuthService] Failed to restore session: \(error)")
            currentUser = nil
        }
    }

    @MainActor
    func signInWithApple() async throws {
        isLoading = true
        defer { isLoading = false }

        let rawNonce = generateNonce()
        let hashedNonce = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let authorization = try await performAppleSignIn(hashedNonce: hashedNonce)

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.missingToken
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
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

        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              let serverClientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String else {
            throw AuthError.missingGoogleConfig
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientID,
            serverClientID: serverClientID
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

    func generateNonce(length: Int = 32) -> String {
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let limit = (256 / charset.count) * charset.count
        var result = ""
        result.reserveCapacity(length)
        while result.count < length {
            var byte: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            if Int(byte) < limit {
                result.append(charset[Int(byte) % charset.count])
            }
        }
        return result
    }

    @MainActor
    private func performAppleSignIn(hashedNonce: String) async throws -> ASAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.email, .fullName]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let continuation = signInContinuation else { return }
        signInContinuation = nil
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard let continuation = signInContinuation else { return }
        signInContinuation = nil
        continuation.resume(throwing: error)
    }
}

enum AuthError: LocalizedError {
    case missingToken
    case missingGoogleToken
    case missingGoogleConfig
    case missingPresentingViewController

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Unable to retrieve Apple ID token."
        case .missingGoogleToken:
            return "Unable to retrieve Google ID token."
        case .missingGoogleConfig:
            return "Google Sign-In configuration is missing from Info.plist."
        case .missingPresentingViewController:
            return "Unable to find a presenting view controller."
        }
    }
}
