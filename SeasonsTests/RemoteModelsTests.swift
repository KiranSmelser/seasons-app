import XCTest
@testable import Seasons

final class RemoteModelsTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testRemoteFavoriteDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "item_type": "produce",
            "item_id": "tomato",
            "date_added": "2025-06-15T10:30:00Z",
            "updated_at": "2025-06-15T10:30:00Z",
            "is_deleted": false
        }
        """.data(using: .utf8)!

        let favorite = try decoder.decode(RemoteFavorite.self, from: json)
        XCTAssertEqual(favorite.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertEqual(favorite.userId, UUID(uuidString: "660e8400-e29b-41d4-a716-446655440000"))
        XCTAssertEqual(favorite.itemType, "produce")
        XCTAssertEqual(favorite.itemId, "tomato")
        XCTAssertFalse(favorite.isDeleted)
    }

    func testRemoteCarbonLogDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "date": "2025-06-15T10:30:00Z",
            "produce_id": "tomato",
            "produce_name": "Tomato",
            "quantity_kg": 1.5,
            "carbon_saved_kg": 2.25,
            "updated_at": "2025-06-15T10:30:00Z",
            "is_deleted": false
        }
        """.data(using: .utf8)!

        let log = try decoder.decode(RemoteCarbonLog.self, from: json)
        XCTAssertEqual(log.id, UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertEqual(log.produceId, "tomato")
        XCTAssertEqual(log.produceName, "Tomato")
        XCTAssertEqual(log.quantityKg, 1.5, accuracy: 0.01)
        XCTAssertEqual(log.carbonSavedKg, 2.25, accuracy: 0.01)
        XCTAssertFalse(log.isDeleted)
    }

    // MARK: - Error / Edge Cases

    func testRemoteFavoriteMissingRequiredFieldFails() throws {
        // item_id is required — omitting it should fail decoding
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "item_type": "produce",
            "date_added": "2025-06-15T10:30:00Z",
            "updated_at": "2025-06-15T10:30:00Z",
            "is_deleted": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(RemoteFavorite.self, from: json),
                             "Decoding should fail when item_id is missing")
    }

    func testRemoteCarbonLogNegativeValues() throws {
        // The model itself accepts negative values — validation is in SyncService.pullChanges
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "date": "2025-06-15T10:30:00Z",
            "produce_id": "tomato",
            "produce_name": "Tomato",
            "quantity_kg": -1.0,
            "carbon_saved_kg": -0.5,
            "updated_at": "2025-06-15T10:30:00Z",
            "is_deleted": false
        }
        """.data(using: .utf8)!

        let log = try decoder.decode(RemoteCarbonLog.self, from: json)
        XCTAssertEqual(log.quantityKg, -1.0, accuracy: 0.01,
                       "Model decodes negative values; SyncService bounds-check rejects them")
        XCTAssertFalse((0...10_000).contains(log.quantityKg),
                       "Negative value should fail the SyncService bounds check")
    }

    func testRemoteFavoriteInvalidDateFormat() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "item_type": "produce",
            "item_id": "tomato",
            "date_added": "not-a-date",
            "updated_at": "also-not-a-date",
            "is_deleted": false
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(RemoteFavorite.self, from: json),
                             "Decoding should fail with an invalid date format")
    }

    func testRemoteCarbonLogIsDeletedDefaultsFalse() throws {
        // Omit the is_deleted field — should decode with isDeleted == false
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "date": "2025-06-15T10:30:00Z",
            "produce_id": "kale",
            "produce_name": "Kale",
            "quantity_kg": 0.5,
            "carbon_saved_kg": 0.3,
            "updated_at": "2025-06-15T10:30:00Z"
        }
        """.data(using: .utf8)!

        let log = try decoder.decode(RemoteCarbonLog.self, from: json)
        XCTAssertFalse(log.isDeleted, "is_deleted should default to false when absent")
    }

    func testRemoteCarbonLogDecodingWithDeletedTrue() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "user_id": "660e8400-e29b-41d4-a716-446655440000",
            "date": "2025-06-15T10:30:00Z",
            "produce_id": "kale",
            "produce_name": "Kale",
            "quantity_kg": 0.5,
            "carbon_saved_kg": 0.75,
            "updated_at": "2025-06-16T10:30:00Z",
            "is_deleted": true
        }
        """.data(using: .utf8)!

        let log = try decoder.decode(RemoteCarbonLog.self, from: json)
        XCTAssertTrue(log.isDeleted)
        XCTAssertEqual(log.produceId, "kale")
    }
}
