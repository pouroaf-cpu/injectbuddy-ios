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

    /// One protocol by id, for the confirm-start-day screen. Decodes as an array and
    /// takes `.first` (this supabase-swift version's `.single()` throws on zero rows
    /// rather than returning nil) so a row deleted between saving and confirming
    /// returns nil instead of throwing. No user_id filter: RLS already scopes this to
    /// the caller, exactly as above.
    func savedDosage(id: String) async throws -> SavedDosage? {
        let rows: [SavedDosage] = try await client
            .from("saved_dosages")
            .select("id, calculator_type, label, config, created_at, start_date, is_active")
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Lets the start day be CHANGED after the fact. CalculatorViewModel.save already
    /// writes start_date on insert, but hardcoded to today — so a protocol the user
    /// actually began three weeks ago gets projected from the wrong day and every
    /// occurrence DoseProjection places on the calendar is shifted. Confirming the day
    /// is the fix; this is the write behind it. Nil clears it, matching the web PATCH.
    func updateStartDate(id: String, startDate: String?) async throws {
        _ = try await client
            .from("saved_dosages")
            .update(["start_date": startDate])
            .eq("id", value: id)
            .execute()
    }

    /// Save a protocol, returning the id — the EXISTING id when this config has
    /// already been saved.
    ///
    /// Dedup lives in the database as of 2026-08-01:
    ///     CREATE UNIQUE INDEX saved_dosages_user_calc_config_key
    ///       ON public.saved_dosages (user_id, calculator_type, config)
    /// `config` is jsonb, so key order and 1 vs 1.0 normalise on storage. Both
    /// platforms get identical dedup without either of them reimplementing a
    /// fingerprint.
    ///
    /// Insert-then-recover rather than `.upsert(onConflict:)` on purpose.
    /// PostgREST's upsert resolves to ON CONFLICT DO UPDATE, which would write
    /// every column in this payload over the surviving row — including
    /// `start_date`, which `CalculatorViewModel.save` always sets to TODAY. Re-saving
    /// an identical protocol would then silently reset a start date the user may have
    /// corrected on the confirm-start-day screen, shifting every projected occurrence
    /// on their calendar. Returning the existing row untouched is the behaviour the
    /// web has and the one that cannot corrupt a schedule.
    func saveDosage(_ dosage: NewSavedDosage) async throws -> String {
        // user_id must be on the INSERT. Every read on this table omits it because
        // RLS scopes selects for us, and the same assumption was carried into the
        // write — where it does not hold. The INSERT policy is a WITH CHECK on
        // user_id = auth.uid(), so a row without it is rejected outright:
        //   "new row violates row-level security policy for table saved_dosages"
        // Sourced from the live session rather than threaded down from the view, so
        // there is exactly one place that can get it wrong.
        let userId = try await client.auth.session.user.id.uuidString.lowercased()
        let owned = OwnedSavedDosage(dosage, userId: userId)
        do {
            let row: InsertedID = try await client
                .from("saved_dosages")
                .insert(owned, returning: .representation)
                .select("id")
                .single()
                .execute()
                .value
            return row.id
        } catch {
            guard Self.isUniqueViolation(error),
                  let existing = try await existingDosageId(for: dosage) else { throw error }
            return existing
        }
    }

    /// `NewSavedDosage` plus the owning user. Kept private to the data layer: the
    /// caller describes the protocol, the client decides who it belongs to.
    private struct OwnedSavedDosage: Encodable {
        let calculatorType: String
        let label: String?
        let config: JSONValue
        let startDate: String?
        let userId: String

        init(_ d: NewSavedDosage, userId: String) {
            calculatorType = d.calculatorType
            label = d.label
            config = d.config
            startDate = d.startDate
            self.userId = userId
        }

        enum CodingKeys: String, CodingKey {
            case calculatorType = "calculator_type"
            case label
            case config
            case startDate = "start_date"
            case userId = "user_id"
        }
    }

    /// The id of an already-saved protocol with this exact config, if there is one.
    /// jsonb equality is order-insensitive, so comparing against the serialised
    /// config is safe — it is the same comparison the unique index makes.
    private func existingDosageId(for dosage: NewSavedDosage) async throws -> String? {
        guard let configJSON = String(data: try JSONEncoder().encode(dosage.config), encoding: .utf8)
        else { return nil }
        let rows: [InsertedID] = try await client
            .from("saved_dosages")
            .select("id")
            .eq("calculator_type", value: dosage.calculatorType)
            .eq("config", value: configJSON)
            .limit(1)
            .execute()
            .value
        return rows.first?.id
    }

    /// Postgres unique-violation. Matched on SQLSTATE where supabase-swift surfaces
    /// it, with a message fallback so a shape change in the error type degrades to a
    /// thrown error rather than a wrong answer.
    private static func isUniqueViolation(_ error: Error) -> Bool {
        if let pg = error as? PostgrestError, pg.code == "23505" { return true }
        let text = String(describing: error)
        return text.contains("23505") || text.contains("saved_dosages_user_calc_config_key")
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
