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
