import XCTest
@testable import Seasons

final class AuthServiceTests: XCTestCase {

    func testInitialStateIsSignedOut() {
        let authService = AuthService()
        XCTAssertFalse(authService.isSignedIn)
        XCTAssertNil(authService.currentUser)
        XCTAssertFalse(authService.isLoading)
    }
}
