import XCTest
import UserNotifications
@testable import Seasons

// MARK: - Mock

@MainActor
private final class MockNotificationCenter: NotificationScheduling {
    var stubbedAuthStatus: UNAuthorizationStatus = .notDetermined
    var stubbedGranted = false
    var permissionError: Error? = nil
    var addError: Error? = nil

    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifierBatches: [[String]] = []

    func authorizationStatus() async -> UNAuthorizationStatus { stubbedAuthStatus }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        if let e = permissionError { throw e }
        return stubbedGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        if let e = addError { throw e }
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierBatches.append(identifiers)
    }
}

// MARK: - Tests

@MainActor
final class NotificationServiceTests: XCTestCase {

    // MARK: - Helper

    private func makeItem(name: String) -> ProduceItem {
        ProduceItem(
            id: name, name: name, category: .vegetable,
            description: "", imageName: "",
            seasonsByRegion: [:],
            localCarbonKgPerKg: 0.3, importedCarbonKgPerKg: 1.5
        )
    }

    // MARK: - notificationBody

    func testBodyOneItem() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let body = service.notificationBody(items: [makeItem(name: "Apple")], region: .california)
        XCTAssertEqual(body, "Apple are in season in California.")
    }

    func testBodyTwoItems() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let body = service.notificationBody(
            items: [makeItem(name: "Apple"), makeItem(name: "Pear")], region: .california)
        XCTAssertEqual(body, "Apple, Pear are in season in California.")
    }

    func testBodyThreeItems() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let body = service.notificationBody(
            items: [makeItem(name: "Apple"), makeItem(name: "Pear"), makeItem(name: "Plum")],
            region: .california)
        XCTAssertEqual(body, "Apple, Pear, Plum are in season in California.")
    }

    func testBodyFourItemsShowsRemaining() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let items = ["Apple", "Pear", "Plum", "Peach"].map { makeItem(name: $0) }
        let body = service.notificationBody(items: items, region: .california)
        XCTAssertEqual(body, "Apple, Pear, Plum, and 1 more are in season in California.")
    }

    func testBodyManyItemsCorrectCount() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let items = ["Apple", "Pear", "Plum", "Peach", "Fig", "Grape"].map { makeItem(name: $0) }
        let body = service.notificationBody(items: items, region: .california)
        XCTAssertEqual(body, "Apple, Pear, Plum, and 3 more are in season in California.")
    }

    func testBodyUsesRegionDisplayName() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        let body = service.notificationBody(items: [makeItem(name: "Apple")], region: .pacificNorthwest)
        XCTAssertTrue(body.hasSuffix("Pacific Northwest."), "Expected body to end with 'Pacific Northwest.' but got: \(body)")
    }

    // MARK: - Auth status

    func testCheckAuthorizationStatusAuthorized() async {
        let mock = MockNotificationCenter()
        mock.stubbedAuthStatus = .authorized
        let service = NotificationService(center: mock)
        await service.checkAuthorizationStatus()
        XCTAssertTrue(service.isAuthorized)
    }

    func testCheckAuthorizationStatusDenied() async {
        let mock = MockNotificationCenter()
        mock.stubbedAuthStatus = .denied
        let service = NotificationService(center: mock)
        await service.checkAuthorizationStatus()
        XCTAssertFalse(service.isAuthorized)
    }

    func testRequestPermissionGranted() async {
        let mock = MockNotificationCenter()
        mock.stubbedGranted = true
        let service = NotificationService(center: mock)
        let result = await service.requestPermission()
        XCTAssertTrue(result)
        XCTAssertTrue(service.isAuthorized)
    }

    func testRequestPermissionDenied() async {
        let mock = MockNotificationCenter()
        mock.stubbedGranted = false
        let service = NotificationService(center: mock)
        let result = await service.requestPermission()
        XCTAssertFalse(result)
        XCTAssertFalse(service.isAuthorized)
    }

    // MARK: - Scheduling

    func testScheduleCancelsBeforeAdding() async {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        await service.scheduleMonthlyNotifications(for: .california)
        XCTAssertEqual(mock.removedIdentifierBatches.count, 1,
                       "cancel should be called exactly once before adding")
        XCTAssertEqual(mock.removedIdentifierBatches[0].count, 12,
                       "cancel batch should contain all 12 month identifiers")
    }

    func testScheduleIdentifiersMatchMonth() async throws {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        await service.scheduleMonthlyNotifications(for: .california)
        XCTAssertFalse(mock.addedRequests.isEmpty, "Expected at least one notification to be scheduled")
        for request in mock.addedRequests {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            let month = try XCTUnwrap(trigger.dateComponents.month)
            XCTAssertEqual(request.identifier, "seasonal-month-\(month)")
        }
    }

    func testScheduleTriggerIsDayOneHourNine() async throws {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        await service.scheduleMonthlyNotifications(for: .california)
        XCTAssertFalse(mock.addedRequests.isEmpty, "Expected at least one notification to be scheduled")
        for request in mock.addedRequests {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertEqual(trigger.dateComponents.day, 1)
            XCTAssertEqual(trigger.dateComponents.hour, 9)
            XCTAssertEqual(trigger.dateComponents.minute, 0)
        }
    }

    func testCancelAllNotificationsRemovesAllTwelve() {
        let mock = MockNotificationCenter()
        let service = NotificationService(center: mock)
        service.cancelAllNotifications()
        let expected = (1...12).map { "seasonal-month-\($0)" }
        XCTAssertEqual(mock.removedIdentifierBatches.count, 1)
        XCTAssertEqual(mock.removedIdentifierBatches[0].sorted(), expected.sorted())
    }
}
