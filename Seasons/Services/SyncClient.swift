import Foundation
import Supabase

protocol SyncClient: Sendable {
    func upsert(table: String, payload: [String: AnyJSON]) async throws
    func delete(table: String, id: UUID) async throws
    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T]
}
