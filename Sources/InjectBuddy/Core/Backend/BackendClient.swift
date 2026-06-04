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
    func saveDosage(_ dosage: NewSavedDosage) async throws -> String          // returns new id
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
}
