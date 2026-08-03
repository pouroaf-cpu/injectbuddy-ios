import Foundation

// ─── MockBackendClient ───────────────────────────────────────────────────────
// In-memory backend for SwiftUI previews and unit tests — no network. Seeded with
// a couple of protocols + an active cycle so dashboard/calendar previews look real.

struct MockBackendClient: BackendClient {
    var dosages: [SavedDosage]
    var cycles: [CycleWithItems]
    var pins: [DoseLogPin]
    var delay: UInt64 = 0  // nanoseconds; set >0 to preview loading states

    init(
        dosages: [SavedDosage] = MockBackendClient.sampleDosages,
        cycles: [CycleWithItems] = MockBackendClient.sampleCycles,
        pins: [DoseLogPin] = []
    ) {
        self.dosages = dosages
        self.cycles = cycles
        self.pins = pins
    }

    private func wait() async { if delay > 0 { try? await Task.sleep(nanoseconds: delay) } }

    func savedDosages() async throws -> [SavedDosage] { await wait(); return dosages }
    func savedDosage(id: String) async throws -> SavedDosage? { await wait(); return dosages.first { $0.id == id } }
    func saveDosage(_ dosage: NewSavedDosage) async throws -> String { await wait(); return UUID().uuidString }
    func updateStartDate(id: String, startDate: String?) async throws { await wait() }
    func deleteDosage(id: String) async throws { await wait() }
    func cyclesWithItems() async throws -> [CycleWithItems] { await wait(); return cycles }
    func doseLog(since: String?) async throws -> [DoseLogPin] { await wait(); return pins }
    func logDose(_ pin: NewDoseLogPin) async throws -> DoseLogPin {
        await wait()
        return DoseLogPin(id: UUID().uuidString, protocolId: pin.protocolId,
                          dosedOn: pin.dosedOn, drawMl: pin.drawMl, site: pin.site)
    }
    func unlogDose(protocolId: String, dosedOn: String) async throws { await wait() }
    func profile(userId: String) async throws -> Profile? {
        await wait(); return Profile(id: userId, displayName: "Pouroa", createdAt: nil)
    }
    func updateDisplayName(_ name: String, userId: String) async throws { await wait() }

    /// **Deletes nothing, and cannot.** Previews and tests run against this client;
    /// a mock that "succeeded" at deleting an account would let the deletion flow be
    /// exercised end to end without ever touching the Edge Function — which is the
    /// one path in this app that must never be signed off on a simulated green.
    /// SPEC §4: the evidence is a throwaway account and 26 queried surfaces.
    func deleteAccount() async throws -> [String] { await wait(); return [] }

    // MARK: sample data

    static let sampleDosages: [SavedDosage] = {
        let json = """
        [
          {"id":"p1","calculator_type":"trt","label":"Test E","config":{"strength":250,"mgWeek":100,"injPerWeek":2,"mode":"perweek"},"created_at":"2026-05-20T00:00:00Z","start_date":"2026-05-20","is_active":true},
          {"id":"p2","calculator_type":"semaglutide","label":"Sema","config":{"conc":5,"dose":0.5},"created_at":"2026-05-22T00:00:00Z","start_date":"2026-05-22","is_active":true}
        ]
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode([SavedDosage].self, from: json)) ?? []
    }()

    static let sampleCycles: [CycleWithItems] = {
        let cycle = Cycle(id: "c1", name: "Spring Cut", goal: "recomp", kind: "cycled",
                          startDate: "2026-05-20", onWeeks: 12, notes: nil, isActive: true,
                          createdAt: "2026-05-20T00:00:00Z")
        return [CycleWithItems(cycle: cycle, items: [])]
    }()
}
