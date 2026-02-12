import Foundation
import Supabase

struct SupabaseSyncClient: SyncClient {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func upsert(table: String, payload: [String: AnyJSON]) async throws {
        try await supabase.from(table)
            .upsert(payload)
            .execute()
    }

    func delete(table: String, id: UUID) async throws {
        try await supabase.from(table)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func select<T: Decodable & Sendable>(table: String, userId: String, updatedAfter: String) async throws -> [T] {
        try await supabase.from(table)
            .select()
            .eq("user_id", value: userId)
            .gt("updated_at", value: updatedAfter)
            .execute()
            .value
    }
}
