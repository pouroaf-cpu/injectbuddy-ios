import Foundation
import Supabase

// ─── SupabaseBackendClient ───────────────────────────────────────────────────
// The real data layer. Talks to PostgREST through supabase-swift; RLS scopes every
// row to the signed-in user, so we never pass user_id in selects (the policies do it).
// This mirrors what the web does server-side — same tables, same row shapes — so a
// protocol/cycle created on either platform shows on the other.

struct SupabaseBackendClient: BackendClient {
    private var client: SupabaseClient { SupabaseProvider.client }

    // MARK: saved_dosages

    func savedDosages() async throws -> [SavedDosage] {
        try await client
            .from("saved_dosages")
            .select("id, calculator_type, label, config, created_at, start_date, is_active")
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func saveDosage(_ dosage: NewSavedDosage) async throws -> String {
        let row: InsertedID = try await client
            .from("saved_dosages")
            .insert(dosage, returning: .representation)
            .select("id")
            .single()
            .execute()
            .value
        return row.id
    }

    func deleteDosage(id: String) async throws {
        _ = try await client.from("saved_dosages").delete().eq("id", value: id).execute()
    }

    // MARK: cycles + cycle_items (two queries, grouped client-side like lib/cycles.ts)

    func cyclesWithItems() async throws -> [CycleWithItems] {
        async let cyclesTask: [Cycle] = client
            .from("cycles")
            .select()
            .order("is_active", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        async let itemsTask: [CycleItem] = client
            .from("cycle_items")
            .select()
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
            .value

        let (cycles, items) = try await (cyclesTask, itemsTask)
        var byCycle: [String: [CycleItem]] = [:]
        for it in items { byCycle[it.cycleId, default: []].append(it) }
        return cycles.map { CycleWithItems(cycle: $0, items: byCycle[$0.id] ?? []) }
    }

    // MARK: dose_log

    func doseLog(since: String?) async throws -> [DoseLogPin] {
        var query = client
            .from("dose_log")
            .select("id, protocol_id, dosed_on, draw_ml, site")
        if let since {
            query = query.gte("dosed_on", value: since)
        }
        return try await query.order("dosed_on", ascending: false).execute().value
    }

    func logDose(_ pin: NewDoseLogPin) async throws -> DoseLogPin {
        try await client
            .from("dose_log")
            .upsert(pin, onConflict: "protocol_id,dosed_on", returning: .representation)
            .select("id, protocol_id, dosed_on, draw_ml, site")
            .single()
            .execute()
            .value
    }

    func unlogDose(protocolId: String, dosedOn: String) async throws {
        _ = try await client
            .from("dose_log")
            .delete()
            .eq("protocol_id", value: protocolId)
            .eq("dosed_on", value: dosedOn)
            .execute()
    }

    // MARK: profiles

    func profile(userId: String) async throws -> Profile? {
        let rows: [Profile] = try await client
            .from("profiles")
            .select("id, display_name, created_at")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func updateDisplayName(_ name: String, userId: String) async throws {
        _ = try await client
            .from("profiles")
            .update(["display_name": name])
            .eq("id", value: userId)
            .execute()
    }

    private struct InsertedID: Decodable { let id: String }
}
