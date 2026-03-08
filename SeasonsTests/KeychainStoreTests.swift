import XCTest
@testable import Seasons

/// Unit tests for KeychainStore.
/// Keys are prefixed with `testPrefix` to avoid polluting the production Keychain.
/// tearDown deletes all test keys via `deleteAll(withPrefix:)`.
final class KeychainStoreTests: XCTestCase {

    private let testPrefix = "__keychaintest__"

    override func tearDown() {
        KeychainStore.deleteAll(withPrefix: testPrefix)
        super.tearDown()
    }

    private func key(_ name: String) -> String { "\(testPrefix)\(name)" }

    // MARK: - Basic Read/Write

    func testSetAndReadBool() {
        KeychainStore.setBool(true, forKey: key("flag"))
        XCTAssertTrue(KeychainStore.bool(forKey: key("flag")))
    }

    func testDefaultFalseForMissingKey() {
        XCTAssertFalse(KeychainStore.bool(forKey: key("never_set")),
                       "Missing key should return false")
    }

    func testOverwriteValue() {
        KeychainStore.setBool(true, forKey: key("overwrite"))
        KeychainStore.setBool(false, forKey: key("overwrite"))
        XCTAssertFalse(KeychainStore.bool(forKey: key("overwrite")),
                       "Second write should overwrite the first")
    }

    // MARK: - Delete

    func testDeleteKey() {
        KeychainStore.setBool(true, forKey: key("todelete"))
        KeychainStore.delete(forKey: key("todelete"))
        XCTAssertFalse(KeychainStore.bool(forKey: key("todelete")),
                       "Key should return false after deletion")
    }

    func testDeleteNonExistentKey() {
        // Must not crash
        KeychainStore.delete(forKey: key("nonexistent"))
    }

    // MARK: - Delete All With Prefix

    func testDeleteAllWithPrefix() {
        let groupPrefix = "\(testPrefix)group_"
        KeychainStore.setBool(true, forKey: "\(groupPrefix)a")
        KeychainStore.setBool(true, forKey: "\(groupPrefix)b")
        // A key that shares testPrefix but NOT groupPrefix
        KeychainStore.setBool(true, forKey: key("other"))

        KeychainStore.deleteAll(withPrefix: groupPrefix)

        XCTAssertFalse(KeychainStore.bool(forKey: "\(groupPrefix)a"),
                       "group_a should be deleted")
        XCTAssertFalse(KeychainStore.bool(forKey: "\(groupPrefix)b"),
                       "group_b should be deleted")
        XCTAssertTrue(KeychainStore.bool(forKey: key("other")),
                      "other key (different prefix) should survive")
    }
}
