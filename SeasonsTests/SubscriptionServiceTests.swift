import XCTest
import StoreKitTest
@testable import Seasons

@MainActor
final class SubscriptionServiceTests: XCTestCase {

    private var session: SKTestSession!

    override func setUp() async throws {
        try await super.setUp()
        session = try SKTestSession(configurationFileNamed: "Seasons")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDown() async throws {
        // Expire any subscriptions purchased in this test so they don't contaminate
        // the next test's StoreKit state via the shared simulator receipt store.
        session.failTransactionsEnabled = true
        try? session.expireSubscription(productIdentifier: "com.kiransmelser.seasons.pro.monthly")
        try? session.expireSubscription(productIdentifier: "com.kiransmelser.seasons.pro.annual")
        try? await Task.sleep(for: .milliseconds(200))
        session.clearTransactions()
        session.resetToDefaultState()
        session = nil
        try await super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        let service = SubscriptionService()
        XCTAssertFalse(service.isPro, "isPro should start false")
        XCTAssertFalse(service.isLoading, "isLoading should start false")
        XCTAssertNil(service.errorMessage, "errorMessage should start nil")
    }

    // MARK: - Product Loading

    func testProductsLoadAfterInit() async {
        let service = SubscriptionService()
        await service.loadProducts()
        XCTAssertNotNil(service.monthlyProduct, "monthlyProduct should be non-nil after loadProducts")
        XCTAssertNotNil(service.annualProduct, "annualProduct should be non-nil after loadProducts")
    }

    // MARK: - Entitlement Check

    func testNoEntitlementWithoutPurchase() async {
        let service = SubscriptionService()
        await service.checkEntitlement()
        XCTAssertFalse(service.isPro, "isPro should be false when no transactions exist")
    }

    // MARK: - Purchase

    func testPurchaseMonthlyGrantsPro() async throws {
        let service = SubscriptionService()
        await service.loadProducts()
        let product = try XCTUnwrap(service.monthlyProduct, "Monthly product must be available")
        await service.purchase(product)
        XCTAssertTrue(service.isPro, "isPro should be true after purchasing monthly subscription")
        XCTAssertFalse(service.isLoading, "isLoading should be false after purchase completes")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil after successful purchase")
    }

    func testPurchaseAnnualGrantsPro() async throws {
        let service = SubscriptionService()
        await service.loadProducts()
        let product = try XCTUnwrap(service.annualProduct, "Annual product must be available")
        await service.purchase(product)
        XCTAssertTrue(service.isPro, "isPro should be true after purchasing annual subscription")
        XCTAssertFalse(service.isLoading, "isLoading should be false after purchase completes")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil after successful purchase")
    }

    func testIsLoadingDuringPurchase() async throws {
        let service = SubscriptionService()
        await service.loadProducts()
        let product = try XCTUnwrap(service.monthlyProduct)

        // isLoading must be false before the call
        XCTAssertFalse(service.isLoading, "isLoading should be false before purchase")

        await service.purchase(product)

        // defer { isLoading = false } ensures it's false after the call returns
        XCTAssertFalse(service.isLoading, "isLoading should be false after purchase returns")
        XCTAssertTrue(service.isPro)
    }

    // MARK: - Restore Purchases

    func testRestorePurchasesGrantsPro() async throws {
        // Purchase with one service instance (creates transaction in SKTestSession)
        let serviceA = SubscriptionService()
        await serviceA.loadProducts()
        let product = try XCTUnwrap(serviceA.monthlyProduct)
        await serviceA.purchase(product)
        XCTAssertTrue(serviceA.isPro, "serviceA should be pro after purchase")

        // A fresh instance that hasn't called checkEntitlement yet
        let serviceB = SubscriptionService()
        // restorePurchases syncs with the App Store and checks entitlements
        await serviceB.restorePurchases()
        XCTAssertTrue(serviceB.isPro, "restorePurchases should grant isPro when a prior purchase exists")
        XCTAssertFalse(serviceB.isLoading)
    }

    func testRestorePurchasesWithNothingToDo() async {
        // No prior purchases in the session
        let service = SubscriptionService()
        await service.restorePurchases()
        XCTAssertFalse(service.isPro, "isPro should remain false when there is nothing to restore")
        XCTAssertNil(service.errorMessage, "errorMessage should be nil when restore succeeds silently")
        XCTAssertFalse(service.isLoading)
    }

    // MARK: - Entitlement Dropped

    func testRevokedTransactionDropsPro() async throws {
        let service = SubscriptionService()
        await service.loadProducts()
        let product = try XCTUnwrap(service.monthlyProduct)
        await service.purchase(product)
        XCTAssertTrue(service.isPro, "Should be pro after purchase")

        // Block future transactions so the auto-renewal attempt fails after expiration.
        session.failTransactionsEnabled = true
        try session.expireSubscription(productIdentifier: "com.kiransmelser.seasons.pro.monthly")

        // Allow StoreKit time to process the expiration and failed renewal update.
        try await Task.sleep(for: .milliseconds(600))

        await service.checkEntitlement()
        XCTAssertFalse(service.isPro, "isPro should be false after subscription expires and renewal is blocked")
    }
}
