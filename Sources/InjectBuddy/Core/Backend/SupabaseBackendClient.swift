import Foundation
import Supabase

// ─── SupabaseBackendClient ───────────────────────────────────────────────────
// The real data layer. Talks to PostgREST through supabase-swift; RLS scopes every
// row to the signed-in user, so we never pass user_id in selects (the policies do it).
// This mirrors what the web does server-side — same tables, same row shapes — so a
// protocol/cycle created on either platform shows on the other.
//
// READS and WRITES are not symmetric, and assuming they were has now cost us twice.
// A select without user_id is correct — the policy's USING clause filters it. A write
// without user_id is REJECTED, because the same policy's WITH CHECK compares
// auth.uid() to the user_id in the row being written, and there is nothing to compare
// to. Two rules follow, and both are enforced in this file so no call site can skip
// them:
//   1. Every INSERT/UPSERT carries user_id, sourced from the live session by an
//      Owned* wrapper private to this layer. The one DELETE that can destroy a row a
//      user already has — unlogDose — carries it in the PREDICATE for the same reason,
//      so the statement is scoped by its own terms and RLS is defence in depth rather
//      than the only defence.
//   2. Every write asks for the representation and throws if it comes back empty.
//      A statement that changed no row is how a refusal arrives on a FILTERED write
//      (update/delete): RLS narrows the statement's scope rather than raising, so
//      PostgREST answers 200 with `[]`. Without this check "refused" and "saved" are
//      the same thing to a caller that only watches for a thrown error — which, in a
//      dosing app, is the UI telling someone an injection is recorded when nothing
//      was written.

/// A write the database accepted and applied to nothing. Conforms to `LocalizedError`
/// because every call site in the app surfaces failures via
/// `(error as? LocalizedError)?.errorDescription`.
enum BackendWriteError: LocalizedError, Equatable {
    /// PostgREST returned an empty representation: zero rows written or changed.
    case wroteNothing(table: String, action: String)

    var errorDescription: String? {
        switch self {
        case let .wroteNothing(table, action):
            return "Nothing was saved. The \(action) changed no row in \(table) — "
                 + "the row may no longer exist, or it may belong to another account."
        }
    }
}

struct SupabaseBackendClient: BackendClient {
    private var client: SupabaseClient { SupabaseProvider.client }

    /// The owning user for a write, from the live session. Every INSERT/UPSERT in this
    /// file sources user_id here and nowhere else, so there is exactly one place that
    /// can get it wrong.
    private func currentUserId() async throws -> String {
        try await client.auth.session.user.id.uuidString.lowercased()
    }

    /// The gate every write in this file passes through. `rows` is the representation
    /// PostgREST sent back — the rows the statement actually touched. Empty means the
    /// database did nothing, and the caller must hear about it as a thrown error, not
    /// as a silent return.
    @discardableResult
    private static func requireRow<T>(_ rows: [T], _ table: String, _ action: String) throws -> T {
        guard let row = rows.first else {
            throw BackendWriteError.wroteNothing(table: table, action: action)
        }
        return row
    }

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
    ///
    /// Reads back the row it changed. `ConfirmStartScreen.confirm` returns true — and
    /// navigates the user away as though their start day is stored — on this call
    /// merely not throwing. An RLS-refused or id-missed PATCH answers 200 with an
    /// empty representation, so "not throwing" was true of both outcomes until the
    /// requireRow below made them different.
    func updateStartDate(id: String, startDate: String?) async throws {
        let rows: [InsertedID] = try await client
            .from("saved_dosages")
            .update(["start_date": startDate], returning: .representation)
            .eq("id", value: id)
            .select("id")
            .execute()
            .value
        try Self.requireRow(rows, "saved_dosages", "start-day update")
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
        let owned = try await OwnedSavedDosage(dosage, userId: currentUserId())
        do {
            let rows: [InsertedID] = try await client
                .from("saved_dosages")
                .insert(owned, returning: .representation)
                .select("id")
                .execute()
                .value
            return try Self.requireRow(rows, "saved_dosages", "protocol insert").id
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
        /// The SOURCE column, not the `is_active` mirror. `is_active` is derived from
        /// this by a database trigger and carries only two of the three states, so
        /// writing it from here would put the mirror out of step with the column it
        /// mirrors. Nothing in this file writes `is_active`, deliberately.
        let status: ProtocolStatus
        let userId: String

        init(_ d: NewSavedDosage, userId: String) {
            calculatorType = d.calculatorType
            label = d.label
            config = d.config
            startDate = d.startDate
            status = d.status
            self.userId = userId
        }

        enum CodingKeys: String, CodingKey {
            case calculatorType = "calculator_type"
            case label
            case config
            case startDate = "start_date"
            case status
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

    /// Reads back the deleted row. A DELETE the policy refuses, or one whose id is not
    /// there, deletes zero rows and returns 200 — so "the protocol is gone" and "the
    /// protocol is still there and still on your calendar" looked identical.
    func deleteDosage(id: String) async throws {
        let rows: [InsertedID] = try await client
            .from("saved_dosages")
            .delete(returning: .representation)
            .eq("id", value: id)
            .select("id")
            .execute()
            .value
        try Self.requireRow(rows, "saved_dosages", "protocol delete")
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

    /// Log a dose as taken. Idempotent on (protocol_id, dosed_on), which is a unique
    /// index — tapping the same day twice updates that day's pin rather than making a
    /// second one.
    ///
    /// user_id must be on this write, exactly as on saveDosage and for the same
    /// reason. `dose_log.user_id` is `uuid NOT NULL` with no default and there are no
    /// triggers on the table, and `dose_log_owner_all` is an ALL policy whose
    /// WITH CHECK is `auth.uid() = user_id`. `NewDoseLogPin` describes the dose and
    /// nothing about ownership, so — like NewSavedDosage — it is wrapped here with the
    /// session's user. Until this was added, every log-dose tap in the app was
    /// rejected and no iOS-written row had ever landed in dose_log.
    ///
    /// Nil `drawMl`/`site` encode as ABSENT keys, not nulls (synthesized Encodable
    /// uses encodeIfPresent), and PostgREST's upsert only writes the keys present. So
    /// a calendar toggle, which sends neither, cannot blank the draw volume or site on
    /// a pin that already has them.
    func logDose(_ pin: NewDoseLogPin) async throws -> DoseLogPin {
        let owned = try await OwnedDoseLogPin(pin, userId: currentUserId())
        let rows: [DoseLogPin] = try await client
            .from("dose_log")
            .upsert(owned, onConflict: "protocol_id,dosed_on", returning: .representation)
            .select("id, protocol_id, dosed_on, draw_ml, site")
            .execute()
            .value
        return try Self.requireRow(rows, "dose_log", "dose log")
    }

    /// `NewDoseLogPin` plus the owning user. Mirrors `OwnedSavedDosage` deliberately —
    /// same shape, same naming, same place in the file relative to its write. A second
    /// idiom for the same job is how the missing user_id survived on this table while
    /// saved_dosages was fixed.
    private struct OwnedDoseLogPin: Encodable {
        let protocolId: String
        let dosedOn: String
        let drawMl: Double?
        let site: String?
        let userId: String

        init(_ p: NewDoseLogPin, userId: String) {
            protocolId = p.protocolId
            dosedOn = p.dosedOn
            drawMl = p.drawMl
            site = p.site
            self.userId = userId
        }

        enum CodingKeys: String, CodingKey {
            case site
            case protocolId = "protocol_id"
            case dosedOn = "dosed_on"
            case drawMl = "draw_ml"
            case userId = "user_id"
        }
    }

    /// Un-log a dose.
    ///
    /// `user_id` is in the PREDICATE, which is the one write in this file where the
    /// owner is a filter rather than a column being written. A DELETE is the only
    /// statement here that can destroy a row that already exists, and its scope was
    /// `(protocol_id, dosed_on)` alone — leaving RLS's `USING` clause as the sole thing
    /// standing between this statement and another account's pin. That is a single
    /// point of failure on the destructive path, and it is the wrong one to leave
    /// unguarded: `dose_log_owner_all`'s USING is server-side policy this client cannot
    /// see, cannot version and does not test, and a policy loosened or dropped in a
    /// migration would turn this into a cross-account delete with nothing in the app
    /// objecting. Naming the owner here means the statement is correctly scoped by its
    /// own terms and the policy is defence in depth rather than the only defence.
    ///
    /// It also sharpens the read-back below. With the filter, zero rows means "you have
    /// no such pin" — a fact about this account, which is what the caller wants to hear.
    ///
    /// Reads back the row it removed: the calendar toggle only calls this for a day it
    /// believes is pinned, so nothing deleted means the pin was not ours to delete or
    /// was never written, and the tick must not move.
    func unlogDose(protocolId: String, dosedOn: String) async throws {
        let userId = try await currentUserId()
        let rows: [InsertedID] = try await client
            .from("dose_log")
            .delete(returning: .representation)
            .eq("user_id", value: userId)
            .eq("protocol_id", value: protocolId)
            .eq("dosed_on", value: dosedOn)
            .select("id")
            .execute()
            .value
        try Self.requireRow(rows, "dose_log", "dose un-log")
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

    /// `profiles` keys on `id` = the user's id — there is no separate user_id column,
    /// and `profiles_self_update` is a USING/WITH CHECK on `auth.uid() = id`, which the
    /// `.eq("id", …)` filter already satisfies. So this write is not missing an owner.
    /// It was missing the read-back: a user with no `profiles` row (the row is not
    /// created by any iOS path) updates nothing, and Settings reported "saved" on the
    /// call not throwing — the same false green DATA-CONTRACT §4.1 records on the web.
    func updateDisplayName(_ name: String, userId: String) async throws {
        let rows: [InsertedID] = try await client
            .from("profiles")
            .update(["display_name": name], returning: .representation)
            .eq("id", value: userId)
            .select("id")
            .execute()
            .value
        try Self.requireRow(rows, "profiles", "display-name update")
    }

    private struct InsertedID: Decodable { let id: String }

    // MARK: account deletion

    /// Invokes the `delete-account` Edge Function. SPEC: docs/SPEC-ACCOUNT-DELETION.md.
    ///
    /// **Why this is not a PostgREST call like everything else in this file.** The
    /// deletion has to clear tables some of which have no self-DELETE policy, plus
    /// three storage prefixes, plus the auth user — work that needs the service-role
    /// key. **A service-role key in the app binary is a service-role key in every
    /// user's hands**, so the privileged half lives in the Edge Function and this
    /// method's only job is to carry the caller's own JWT to it.
    ///
    /// The function derives the uid from that verified token and never from a request
    /// body, which is what makes it an account-deletion endpoint rather than an
    /// any-account-deletion endpoint. **That is why nothing is sent in the body here
    /// and why nothing should ever be added to it.**
    ///
    /// The `Authorization` header is set explicitly from the live session rather than
    /// left to the client's ambient token. On this one call it is worth being able to
    /// read the auth off the call site.
    @discardableResult
    func deleteAccount() async throws -> [String] {
        let session = try await client.auth.session

        let result: DeleteAccountResult
        do {
            result = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )
        } catch let FunctionsError.httpError(code, data) {
            // A non-2xx carries the function's own message in the body. Surfacing it
            // beats "the operation could not be completed" on the one screen where a
            // user needs to know whether their data is actually gone.
            throw AccountDeletionError.failed(
                message: DeleteAccountResult.message(fromErrorBody: data),
                statusCode: code)
        }

        // Belt and braces: the function returns `ok: false` only alongside a 500, so
        // this is unreachable today. It exists so that loosening the function's status
        // codes later cannot silently turn a failure into a success here.
        guard result.ok else {
            throw AccountDeletionError.failed(message: result.error, statusCode: nil)
        }

        // Storage is best-effort by design (SPEC §1.4) — a file that could not be
        // removed must not block the account going away, and every database step has
        // already succeeded by this point. So this is NOT thrown: the account really
        // is deleted and telling the user it failed would be as wrong as telling the
        // other case it succeeded.
        //
        // But it is not discarded either. It is handed back for the caller to log,
        // because a stuck file after a deletion is a retention event and it has to
        // reach somewhere a human can read it.
        return result.storageFailures
    }

    private struct DeleteAccountResult: Decodable {
        let ok: Bool
        let error: String?
        let storageFailures: [String]
        let emailTablesSkipped: [String]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
            error = try? c.decode(String.self, forKey: .error)
            storageFailures = (try? c.decode([String].self, forKey: .storageFailures)) ?? []
            emailTablesSkipped = (try? c.decode([String].self, forKey: .emailTablesSkipped)) ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case ok, error, storageFailures, emailTablesSkipped
        }

        /// Pulls the function's `error` string out of a non-2xx body, falling back to
        /// nil rather than to a decoding error — a failure to parse a failure must not
        /// replace the real problem with a JSON complaint.
        static func message(fromErrorBody data: Data) -> String? {
            struct Body: Decodable { let error: String? }
            return (try? JSONDecoder().decode(Body.self, from: data))?.error
        }
    }
}

/// Failures of the one irreversible operation in the app. `LocalizedError` because
/// every call site surfaces failures via `(error as? LocalizedError)?.errorDescription`.
enum AccountDeletionError: LocalizedError, Equatable {
    /// Nothing was deleted, or the deletion aborted part-way. Either way the account
    /// still exists and the user must not be told otherwise.
    ///
    /// **There is deliberately no `deletedButFilesRemain` case.** A stuck file is not
    /// a failed deletion — the account and every row are gone — so it is returned from
    /// `deleteAccount()` to be logged, not thrown at a user who has no action to take.
    case failed(message: String?, statusCode: Int?)

    var errorDescription: String? {
        switch self {
        case let .failed(message, _):
            return "Your account was NOT deleted. "
                + (message ?? "The server could not complete the deletion.")
                + " Nothing has been removed — you can try again."
        }
    }
}
