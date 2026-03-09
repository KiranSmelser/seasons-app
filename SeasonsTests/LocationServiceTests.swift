import XCTest
@testable import Seasons

/// Unit tests for LocationService UserDefaults persistence.
/// setUp and tearDown both remove "manualRegion" to prevent cross-test residue.
final class LocationServiceTests: XCTestCase {

    private let udKey = "manualRegion"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: udKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: udKey)
        super.tearDown()
    }

    // MARK: - setManualRegion persistence

    func testSetManualRegionPersistsToUserDefaults() {
        let svc = LocationService()
        svc.setManualRegion(.california)
        XCTAssertEqual(UserDefaults.standard.string(forKey: udKey), "california")
    }

    func testSetManualRegionUpdatesRegionProperty() {
        let svc = LocationService()
        svc.setManualRegion(.southwest)
        XCTAssertEqual(svc.region, .southwest)
    }

    func testSetManualRegionSetsHasLocation() {
        let svc = LocationService()
        XCTAssertFalse(svc.hasLocation, "hasLocation should start false with no persisted key")
        svc.setManualRegion(.midwest)
        XCTAssertTrue(svc.hasLocation)
    }

    func testSetManualRegionOverwritesPreviousValue() {
        let svc = LocationService()
        svc.setManualRegion(.northeast)
        svc.setManualRegion(.pacificNorthwest)
        XCTAssertEqual(svc.region, .pacificNorthwest)
        XCTAssertEqual(UserDefaults.standard.string(forKey: udKey), "pacificNorthwest")
    }

    func testSetManualRegionAllRegionsPersistCorrectRawValues() {
        let svc = LocationService()
        for region in GrowingRegion.allCases {
            svc.setManualRegion(region)
            XCTAssertEqual(
                UserDefaults.standard.string(forKey: udKey),
                region.rawValue,
                "Expected rawValue '\(region.rawValue)' in UserDefaults"
            )
        }
    }

    // MARK: - init UserDefaults restoration

    func testInitRestoresPersistedRegion() {
        UserDefaults.standard.set("california", forKey: udKey)
        let svc = LocationService()
        XCTAssertEqual(svc.region, .california)
    }

    func testInitSetsHasLocationWhenPersistedRegionExists() {
        UserDefaults.standard.set("southeast", forKey: udKey)
        let svc = LocationService()
        XCTAssertTrue(svc.hasLocation)
    }

    func testInitDoesNotSetHasLocationWhenNoPersistedRegion() {
        let svc = LocationService()
        XCTAssertFalse(svc.hasLocation)
        XCTAssertEqual(svc.region, .northeast)
    }
}
