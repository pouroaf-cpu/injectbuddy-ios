import Foundation

// ─── Models ──────────────────────────────────────────────────────────────────
// Codable mirrors of the InjectBuddy Supabase tables (see Injectbuddy/lib/supabase/
// types.ts). Snake_case columns are mapped with CodingKeys. `config`/`result` are
// free-form JSON, modeled as JSONValue so any calculator's saved inputs round-trip.

// MARK: - Profile  (table: profiles)

struct Profile: Codable, Identifiable, Equatable {
    let id: String
    var displayName: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

/// The lightweight identity the app shows in the drawer header / settings.
/// Derived from the Supabase session user (email + metadata) + the profiles row.
struct AccountIdentity: Equatable {
    var email: String
    var displayName: String
    var avatarURL: URL?

    var initials: String {
        let parts = displayName
            .split(whereSeparator: { $0 == " " })
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let joined = parts.joined().uppercased()
        return joined.isEmpty ? String(email.prefix(2)).uppercased() : joined
    }
}

// MARK: - SavedDosage  (table: saved_dosages) — a "protocol" card on the dashboard

struct SavedDosage: Codable, Identifiable, Equatable {
    let id: String
    var calculatorType: String
    var label: String?
    var config: JSONValue
    var createdAt: String?
    var startDate: String?
    var isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case calculatorType = "calculator_type"
        case label
        case config
        case createdAt = "created_at"
        case startDate = "start_date"
        case isActive = "is_active"
    }

    // saved_dosages.is_active may be absent in some selects; default to true.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        calculatorType = try c.decode(String.self, forKey: .calculatorType)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        config = try c.decodeIfPresent(JSONValue.self, forKey: .config) ?? .object([:])
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        startDate = try c.decodeIfPresent(String.self, forKey: .startDate)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
    }
}

/// The lifecycle of a saved protocol. THIS is the source column — three states.
///
/// `saved_dosages.is_active` is a DERIVED MIRROR of it, maintained by a database
/// trigger, and it only carries two of the three (a draft and an archived row both
/// mirror to false, and nothing downstream can tell them apart again). So:
/// **read and write `status`; never write `is_active`.** Writing the mirror directly
/// would put it out of step with the column the trigger derives it from, and the two
/// would then disagree about the same row.
///
/// Why this matters in production: 71 of 102 saved rows are `draft` and 31 are
/// `active`, and 24 of 39 users have nothing active at all
/// (`docs/WHERE-WE-ARE-2026-08-03.md`). A protocol written without a status is not a
/// protocol the user has started.
enum ProtocolStatus: String, Codable, CaseIterable, Equatable {
    /// Running. What the Add flow writes, and what the dashboard and calendar project.
    case active
    /// Saved but never started — has no start day the user stood behind.
    case draft
    /// Finished or put away. Kept for history, not projected.
    case archived
}

/// Insert body for saving a protocol. iOS writes DIRECTLY to saved_dosages via
/// PostgREST — it never calls the web's /api/dosages (that route authenticates by
/// cookie and an iOS client holding a JWT cannot reach it). Dedup is a unique index
/// on (user_id, calculator_type, config); see SupabaseBackendClient.saveDosage.
struct NewSavedDosage: Encodable {
    var calculatorType: String
    var label: String?
    var config: JSONValue
    var startDate: String?

    /// Parameterised so a caller that saves a protocol WITHOUT starting it can say so,
    /// but defaulted to `.active` because the only path that writes this today is the
    /// Add flow, where the user has just chosen a start day. Left off the insert
    /// entirely, the row took the column's own default and the protocol did not appear
    /// as running.
    var status: ProtocolStatus = .active

    enum CodingKeys: String, CodingKey {
        case calculatorType = "calculator_type"
        case label
        case config
        case startDate = "start_date"
        case status
    }
}

// MARK: - Cycle  (table: cycles) + CycleItem (table: cycle_items)

struct Cycle: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var goal: String?
    var kind: String
    var startDate: String
    var onWeeks: Int?
    var notes: String?
    var isActive: Bool
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, goal, kind, notes
        case startDate = "start_date"
        case onWeeks = "on_weeks"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct CycleItem: Codable, Identifiable, Equatable {
    let id: String
    var cycleId: String
    var protocolId: String?
    var label: String?
    var compound: String?
    var role: String
    var phase: String
    var dose: Double?
    var doseUnit: String?
    var frequency: String?
    var halfLifeDays: Double?
    var startWeek: Int
    var durationWeeks: Int?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, label, compound, role, phase, dose, frequency
        case cycleId = "cycle_id"
        case protocolId = "protocol_id"
        case doseUnit = "dose_unit"
        case halfLifeDays = "half_life_days"
        case startWeek = "start_week"
        case durationWeeks = "duration_weeks"
        case sortOrder = "sort_order"
    }
}

struct CycleWithItems: Identifiable, Equatable {
    var cycle: Cycle
    var items: [CycleItem]
    var id: String { cycle.id }
}

// MARK: - DoseLog  (table: dose_log) — a dated "taken" pin

struct DoseLogPin: Codable, Identifiable, Equatable {
    let id: String
    var protocolId: String
    var dosedOn: String      // YYYY-MM-DD
    var drawMl: Double?
    var site: String?
    /// The dose this injection delivered, as text with its unit ("74.5 mg"). Read back
    /// so the write can be checked against the representation rather than the request —
    /// same contract as `site`.
    var doseLabel: String?

    enum CodingKeys: String, CodingKey {
        case id, site
        case protocolId = "protocol_id"
        case dosedOn = "dosed_on"
        case drawMl = "draw_ml"
        case doseLabel = "dose_label"
    }
}

/// Insert body for a logged dose.
///
/// **THE MEMBERWISE INITIALISER IS DELIBERATELY SUPPRESSED.** Declaring the two
/// initialisers below removes it, so no call site can build a pin by listing fields —
/// which is how `drawMl: nil` came to be written at all three log paths at once and
/// how the dashboard produced the only NULL `draw_ml` in the table. A fourth log path
/// added tomorrow does not compile until it says where its volume comes from.
///
/// `draw_ml` is `numeric` and NULLABLE in production and there are no triggers on the
/// table, so nothing server-side enforces this. The write is the only thing that can.
/// The column is consumed: the web's inventory route reads remaining supply as
/// `(vial_count × vial_ml) − Σ(dose_log.draw_ml since stocked_on)`, so a NULL is a dose
/// that consumes nothing — the "never run dry mid-protocol" promise failing in the
/// direction of running dry.
struct NewDoseLogPin: Encodable {
    var protocolId: String
    var dosedOn: String
    var drawMl: Double?
    var site: String?

    /// **T-52.** What was actually put in, as text with its unit — "74.5 mg". The web
    /// writes this on every row (`app/api/dose-log/route.ts` POST) and renders it as the
    /// history's "Dose" column, falling back to the PROTOCOL's planned dose when the
    /// column is null (`DoseHistory.tsx:89`). That fallback is precisely why iOS leaving
    /// it null was invisible and wrong: a half dose read back as a full one, because the
    /// only thing left to read was the plan.
    var doseLabel: String?

    enum CodingKeys: String, CodingKey {
        case site
        case protocolId = "protocol_id"
        case dosedOn = "dosed_on"
        case drawMl = "draw_ml"
        case doseLabel = "dose_label"
    }

    /// From the protocol itself — the log-a-dose sheet, which picks a protocol and a day
    /// and has no projection in hand.
    ///
    /// `amount` is what the user is logging, which is **not always what was planned**.
    /// Nil means "the plan", and the derived dose is recorded as-is. When it differs, the
    /// volume is scaled with it: a dosing tracker that recorded half the mg while still
    /// subtracting a whole draw from the vial would be wrong in both directions at once —
    /// the history under-reports and the supply over-reports.
    ///
    /// The scaling is exact rather than an approximation. Every family's volume is
    /// linear in its dose (`mgPerInj / strength`, `dose / concentration`), so half the
    /// dose is half the millilitres for all of them.
    init(for dosage: SavedDosage, dosedOn: String, site: String? = nil,
         amount: DoseAmount? = nil) {
        let planned = DoseVolume.perInjection(for: dosage)
        self.protocolId = dosage.id
        self.dosedOn = dosedOn
        self.site = site

        // A unit mismatch cannot arise from the sheet — the field edits the number and
        // never the unit — so it can only mean a caller built an amount for a different
        // protocol. Scaling across units would write a dose off by a thousand, so the
        // amount is refused and the plan stands.
        guard let logged = amount, let plan = planned.dose,
              logged.unit == plan.unit, plan.value > 0 else {
            self.drawMl = planned.ml
            self.doseLabel = planned.dose?.labelled
            return
        }
        self.doseLabel = logged.labelled
        self.drawMl = logged == plan ? planned.ml
                                     : planned.ml.map { $0 * logged.value / plan.value }
    }

    /// From a projected occurrence — the dashboard card and the calendar agenda, which
    /// hold occurrences and not the protocols behind them. The volume and the dose both
    /// travel ON the occurrence (`DoseProjection` computes them once per protocol), so
    /// these two paths need no second lookup and cannot fall out of step with the
    /// projection. Neither surface offers an amount to adjust: they log the plan.
    init(for occurrence: DoseOccurrence, site: String? = nil) {
        self.protocolId = occurrence.protocolId
        self.dosedOn = occurrence.dayKey
        self.drawMl = occurrence.drawMl
        self.site = site
        self.doseLabel = occurrence.dose?.labelled
    }
}
