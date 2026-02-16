import XCTest
@testable import Seasons

final class AuthServiceTests: XCTestCase {

    func testInitialStateIsSignedOut() {
        let authService = AuthService()
        XCTAssertFalse(authService.isSignedIn)
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isLoading)
    }

    func testNonceGenerationLengthAndCharset() {
        let authService = AuthService()
        let charset = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

        for _ in 0..<100 {
            let nonce = authService.generateNonce()
            XCTAssertEqual(nonce.count, 32, "Nonce should be 32 characters")
            for char in nonce {
                XCTAssertTrue(charset.contains(char), "Nonce contains invalid character: \(char)")
            }
        }

        let shortNonce = authService.generateNonce(length: 8)
        XCTAssertEqual(shortNonce.count, 8)

        let longNonce = authService.generateNonce(length: 64)
        XCTAssertEqual(longNonce.count, 64)
    }

    func testNonceGenerationUniformDistribution() {
        let authService = AuthService()
        let charset = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        var counts = [Character: Int]()
        for char in charset { counts[char] = 0 }

        let iterations = 10_000
        let nonceLength = 32
        let totalChars = iterations * nonceLength

        for _ in 0..<iterations {
            let nonce = authService.generateNonce(length: nonceLength)
            for char in nonce {
                counts[char, default: 0] += 1
            }
        }

        let expected = Double(totalChars) / Double(charset.count)
        // Allow 30% deviation — enough to catch modulo bias (which would cause ~3% skew
        // on some characters) while not flaking on random variation
        let tolerance = expected * 0.30

        for (char, count) in counts {
            let deviation = abs(Double(count) - expected)
            XCTAssertLessThan(
                deviation, tolerance,
                "Character '\(char)' appeared \(count) times, expected ~\(Int(expected)) ± \(Int(tolerance))"
            )
        }
    }

    func testAuthErrorDescriptions() {
        let cases: [AuthError] = [
            .missingToken,
            .missingGoogleToken,
            .missingGoogleConfig,
            .missingPresentingViewController
        ]

        for error in cases {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "\(error) description should not be empty")
        }
    }
}
