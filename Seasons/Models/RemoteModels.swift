import Foundation

struct RemoteFavorite: Decodable {
    let id: UUID
    let userId: UUID
    let itemType: String
    let itemId: String
    let dateAdded: Date
    let updatedAt: Date
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemType = "item_type"
        case itemId = "item_id"
        case dateAdded = "date_added"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

struct RemoteCarbonLog: Decodable {
    let id: UUID
    let userId: UUID
    let date: Date
    let produceId: String
    let produceName: String
    let quantityKg: Double
    let carbonSavedKg: Double
    let updatedAt: Date
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case date
        case produceId = "produce_id"
        case produceName = "produce_name"
        case quantityKg = "quantity_kg"
        case carbonSavedKg = "carbon_saved_kg"
        case updatedAt = "updated_at"
        case isDeleted = "is_deleted"
    }
}

extension RemoteCarbonLog {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        date = try c.decode(Date.self, forKey: .date)
        produceId = try c.decode(String.self, forKey: .produceId)
        produceName = try c.decode(String.self, forKey: .produceName)
        quantityKg = try c.decode(Double.self, forKey: .quantityKg)
        carbonSavedKg = try c.decode(Double.self, forKey: .carbonSavedKg)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isDeleted = try c.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
