import XCTest
@testable import Seasons

private enum StubError: LocalizedError {
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .custom(let message): return message
        }
    }
}

final class ErrorFormattingTests: XCTestCase {

    func testCancelReturnsOperationCancelled() {
        let msg = friendlyMessage(for: StubError.custom("User did cancel"))
        XCTAssertEqual(msg, "Operation was cancelled.")
    }

    func testDismissReturnsOperationCancelled() {
        let msg = friendlyMessage(for: StubError.custom("Action was dismiss"))
        XCTAssertEqual(msg, "Operation was cancelled.")
    }

    func testNetworkReturnsNoInternet() {
        let msg = friendlyMessage(for: StubError.custom("A network error"))
        XCTAssertEqual(msg, "No internet connection. Please check your network and try again.")
    }

    func testOfflineReturnsNoInternet() {
        let msg = friendlyMessage(for: StubError.custom("Device is offline"))
        XCTAssertEqual(msg, "No internet connection. Please check your network and try again.")
    }

    func testConnectionReturnsNoInternet() {
        let msg = friendlyMessage(for: StubError.custom("The connection was reset"))
        XCTAssertEqual(msg, "No internet connection. Please check your network and try again.")
    }

    func testUnauthorizedReturnsSignInFailed() {
        let msg = friendlyMessage(for: StubError.custom("Request unauthorized"))
        XCTAssertEqual(msg, "Sign-in failed. Please try again.")
    }

    func testUnknownErrorReturnsFallback() {
        let msg = friendlyMessage(for: StubError.custom("Something unexpected"))
        XCTAssertEqual(msg, "Something went wrong. Please try again.")
    }
}
