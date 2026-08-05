import Foundation

// ─── ProtocolSummary ─────────────────────────────────────────────────────────
// **T-53 — two protocol cards that render identically.**
//
// The log-dose sheet listed `TRT Dose` twice with nothing under either. They are
// legitimately different rows: the dedup index is `(user_id, calculator_type, config)`,
// so the QA account really does hold two active TRT protocols — 137 mg/wk and 149 mg/wk,
// identical in every other key. The card drew the LABEL, and iOS writes the calculator's
// static `saveTitle` into `label` on every save, so both said "TRT Dose". On the write
// path of a dosing tracker that means the user picks which dose to log by guessing.
//
// So the supporting line is DERIVED FROM THE CONFIG, never from the label. Every number
// in it is a number the calculator itself produced or the user typed.
//
// **One unit convention: per injection.** S-04 #5 recorded three conventions stacked in
// one list — `350mcg/inj`, `300 mg/wk`, and a blank. Per injection is the web's own
// `doseLabel` convention (`lib/account-schedule.ts` — every branch states the dose for
// ONE injection) and it is the number this sheet is about: the sheet logs one injection.
//
// **Distinguishability is guaranteed, not hoped for.** `lines(for:)` renders the whole
// list at once and, where two cards would still read alike, appends the config keys that
// actually differ between them. Two protocols cannot be identical in `calculator_type` +
// `config` — the unique index forbids it — so a differing key always exists to name. A
// line that is right most of the time is what this task exists to remove.

/// The dose ONE injection delivers, as a number plus the unit it is stated in.
///
/// The unit travels WITH the value and is never dropped: `0.25` on a U-100 barrel has two
/// readings, and `74.5` without `mg` has as many as there are compounds. Every rendering
/// of this type puts the two together.
struct DoseAmount: Equatable {
    /// Rounded at construction to the precision it is displayed and edited at, so an
    /// untouched field and the derivation behind it are the same number rather than two
    /// numbers that agree to two decimals.
    let value: Double
    let unit: String

    init(value: Double, unit: String) {
        self.value = (value * 100).rounded() / 100
        self.unit = unit
    }

    /// The value alone, trailing zeros trimmed. What seeds an editable field.
    var text: String { ProtocolSummary.trim(value) }

    /// Value and unit together — the shape the web writes into `dose_log.dose_label`
    /// ("74.5 mg", "800 mcg", "5000 IU"; `DoseHistory.tsx` renders this column verbatim).
    var labelled: String { "\(text) \(unit)" }
}

enum ProtocolSummary {

    /// The dose one injection of this protocol delivers, or nil when it cannot be stated
    /// honestly — an unknown `calculator_type`, a calculator with no dose (reconstitution,
    /// bmi, freetest, plotter), a blend that has two doses and no single one, an invalid
    /// config, or a config saved in a dosing MODE this build does not evaluate.
    ///
    /// Delegates to `DoseVolume.perInjection`, which owns the mode gate. There is one
    /// re-evaluation of a saved protocol in this app and this is not a second one.
    static func amount(for dosage: SavedDosage) -> DoseAmount? {
        DoseVolume.perInjection(for: dosage).dose
    }

    /// The supporting line for ONE card, without collision handling. Use `lines(for:)`
    /// for a list — a line that is unique on its own is not the property this needs.
    ///
    /// `title` is the card's own heading; a component already spelled out there is not
    /// repeated ("Masteron (Drostanolone) Enanthate · … · Enanthate" reads as two facts).
    static func line(for dosage: SavedDosage, title: String = "") -> String {
        var parts: [String] = []

        if let amount = amount(for: dosage) { parts.append(amount.labelled) }
        if let cadence = cadence(for: dosage) { parts.append(cadence) }
        if let vial = vial(for: dosage) { parts.append(vial) }
        if let compound = compound(for: dosage),
           !title.localizedCaseInsensitiveContains(compound) {
            parts.append(compound)
        }

        return parts.joined(separator: " · ")
    }

    /// Every card's supporting line, keyed by protocol id, resolved so that **no two
    /// entries in this list read the same**.
    ///
    /// Where two protocols would render an identical title + line, the keys whose values
    /// actually differ between them are appended to each. That is deliberately raw —
    /// `mode perweek` is not prose — because at that point the derived language has
    /// already failed to separate them and the honest thing left is the stored key. It is
    /// also rare: it needs two rows agreeing on dose, interval, vial and compound.
    ///
    /// `titles` is what each card renders as its heading, so the check is on what the
    /// user actually sees rather than on the line alone.
    static func lines(for dosages: [SavedDosage],
                      titles: [String: String] = [:]) -> [String: String] {
        var out: [String: String] = [:]
        for d in dosages { out[d.id] = line(for: d, title: titles[d.id] ?? "") }

        // Group by what is rendered — title AND line, since a shared line under two
        // different headings is not a collision.
        var groups: [String: [SavedDosage]] = [:]
        for d in dosages {
            groups["\(titles[d.id] ?? "")\u{1}\(out[d.id] ?? "")", default: []].append(d)
        }

        for (_, group) in groups where group.count > 1 {
            for d in group {
                let tokens = distinguishingTokens(for: d, against: group)
                guard !tokens.isEmpty else { continue }
                let existing = out[d.id] ?? ""
                out[d.id] = existing.isEmpty ? tokens.joined(separator: " · ")
                                             : ([existing] + tokens).joined(separator: " · ")
            }
        }
        return out
    }

    // MARK: - Components

    /// How often this protocol is injected, from `DoseProjection` — the same interval the
    /// calendar and the dashboard project, so a card and the schedule behind it cannot
    /// disagree about cadence.
    static func cadence(for dosage: SavedDosage) -> String? {
        guard let days = DoseProjection.injectionIntervalDays(for: dosage),
              days.isFinite, days > 0 else { return nil }
        if days == 1 { return "every day" }
        return "every \(trim(days)) days"
    }

    /// What is in the vial, taken straight from the config keys the user typed. Display
    /// only — nothing here is written to a row — so it reads the inputs rather than
    /// re-deriving a concentration the engine already owns.
    static func vial(for dosage: SavedDosage) -> String? {
        guard let slug = CalculatorSlug(rawValue: dosage.calculatorType) else { return nil }
        let c = dosage.config
        switch slug {
        case .trt, .eod, .microdose, .steroid:
            guard let strength = c["strength"]?.double, strength > 0 else { return nil }
            return "\(trim(strength)) mg/mL"
        case .semaglutide, .tirzepatide, .retatrutide:
            guard let conc = c["conc"]?.double, conc > 0 else { return nil }
            return "\(trim(conc)) mg/mL"
        case .peptide:
            return mixed(c["peptideMg"]?.double, "mg", c["bawMl"]?.double)
        case .bpc157:
            return mixed(c["vialMg"]?.double, "mg", c["bawMl"]?.double)
        case .hcg:
            return mixed(c["vialIU"]?.double, "IU", c["bacWaterMl"]?.double)
        case .bpc157blend, .reconstitution, .bmi, .freeTestIndex, .cyclePlotter:
            return nil
        }
    }

    /// "25 mg in 3 mL" — a reconstituted vial stated as the two numbers that made it,
    /// which is what the user entered and what distinguishes two mixes of the same
    /// peptide. Nil unless both are real.
    private static func mixed(_ amount: Double?, _ unit: String, _ ml: Double?) -> String? {
        guard let amount, amount > 0, let ml, ml > 0 else { return nil }
        return "\(trim(amount)) \(unit) in \(trim(ml)) mL"
    }

    /// The compound the config names, where it names one.
    static func compound(for dosage: SavedDosage) -> String? {
        guard let slug = CalculatorSlug(rawValue: dosage.calculatorType) else { return nil }
        let c = dosage.config
        switch slug {
        case .trt, .eod, .microdose:
            return nonEmpty(c["esterType"]?.string)
        case .peptide:
            return nonEmpty(c["peptideType"]?.string)
        case .steroid:
            // The config stores the web's compound key and ester key, not display names.
            guard let key = nonEmpty(c["slug"]?.string),
                  let compound = SteroidCatalog.all.first(where: { $0.key == key })
            else { return nil }
            let esterKey = nonEmpty(c["esterKey"]?.string)
            let ester = compound.esters.first { $0.key == esterKey }
            return ester.map { "\(compound.displayName) \($0.label)" } ?? compound.displayName
        default:
            return nil
        }
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }

    // MARK: - Collision resolution

    /// The stored keys that separate `dosage` from the others it renders identically to.
    ///
    /// A differing `calculator_type` is named first and by itself: two rows of different
    /// families that somehow read alike are separated by the family, and appending config
    /// keys on top of that would be noise.
    private static func distinguishingTokens(for dosage: SavedDosage,
                                             against group: [SavedDosage]) -> [String] {
        let others = group.filter { $0.id != dosage.id }
        guard !others.isEmpty else { return [] }

        if others.contains(where: { $0.calculatorType != dosage.calculatorType }) {
            return [dosage.calculatorType]
        }

        let mine = dosage.config.object ?? [:]
        var keys = Set<String>()
        for other in others {
            let theirs = other.config.object ?? [:]
            for key in Set(mine.keys).union(theirs.keys) where mine[key] != theirs[key] {
                keys.insert(key)
            }
        }
        return keys.sorted().map { key in
            "\(key) \(mine[key].map(describe) ?? "—")"
        }
    }

    /// A stored value rendered for a human, for the collision case only.
    private static func describe(_ value: JSONValue) -> String {
        switch value {
        case .string(let s): return s.isEmpty ? "—" : s
        case .number(let n): return trim(n)
        case .bool(let b):   return b ? "yes" : "no"
        case .null:          return "—"
        case .object, .array:
            // Nested config is not something this app writes; naming the key is still a
            // separation even when the value cannot be shown.
            return "set"
        }
    }

    // MARK: - Formatting

    /// Fixed decimals then trailing zeros trimmed: `68.5`, `200`, `3.5`, `1.08`.
    ///
    /// Never localised — these strings sit beside units in a dosing line, and a decimal
    /// comma next to `mg` reads as a thousands separator to half the world.
    static func trim(_ v: Double, decimals: Int = 2) -> String {
        guard v.isFinite else { return "—" }
        var s = String(format: "%.\(decimals)f", v)
        if s.contains(".") {
            while s.hasSuffix("0") { s.removeLast() }
            if s.hasSuffix(".") { s.removeLast() }
        }
        return s == "-0" ? "0" : s
    }
}
