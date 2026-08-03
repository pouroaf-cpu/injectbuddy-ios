import Foundation

// ─── BackendClient ───────────────────────────────────────────────────────────
// The app's data layer, expressed as a protocol so the rest of the app is decoupled
// from supabase-swift's exact API (which moves between versions). Only
// SupabaseBackendClient touches PostgREST; if the library API drifts on the Mac,
// this one file is the only thing to fix. A MockBackendClient (previews/tests) can
// conform without any network.

protocol BackendClient: Sendable {
    // Protocols (saved_dosages)
    func savedDosages() async throws -> [SavedDosage]
    func savedDosage(id: String) async throws -> SavedDosage?                 // one row, for confirm-start
    func saveDosage(_ dosage: NewSavedDosage) async throws -> String          // returns new id
    func updateStartDate(id: String, startDate: String?) async throws
    func deleteDosage(id: String) async throws

    // Cycles
    func cyclesWithItems() async throws -> [CycleWithItems]

    // Dose log (taken pins)
    func doseLog(since: String?) async throws -> [DoseLogPin]
    func logDose(_ pin: NewDoseLogPin) async throws -> DoseLogPin
    func unlogDose(protocolId: String, dosedOn: String) async throws

    // Profile
    func profile(userId: String) async throws -> Profile?
    func updateDisplayName(_ name: String, userId: String) async throws

    // Account
    //
    // Real, irreversible account deletion. SPEC: docs/SPEC-ACCOUNT-DELETION.md.
    //
    // THIS IS THE ONE CALL IN THE APP THAT MUST NEVER RETURN NORMALLY ON A PARTIAL
    // SUCCESS. It returns only when the server confirmed every table, bucket prefix
    // and the auth user itself; anything else throws. D9's sharpest case — a failed
    // deletion that reads as success leaves a user believing their health data is
    // gone when it is not.
    //
    // It is deliberately NOT a PostgREST call. iOS cannot hold a service-role key,
    // so the privileged work happens in the `delete-account` Edge Function and this
    // method only carries the user's own JWT to it.
    //
    // RETURNS the storage prefixes whose files could not be removed. Storage is
    // best-effort by design (SPEC §1.4) — a stuck file must not keep an account
    // alive — so a non-empty result is NOT a failure and the deletion did happen.
    // **It is returned rather than discarded because it is a real event that must
    // reach somewhere a human can see.** Empty is the normal case.
    func deleteAccount() async throws -> [String]
}
