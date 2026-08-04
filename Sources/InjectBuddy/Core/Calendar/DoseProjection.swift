import Foundation

// ─── DoseProjection ──────────────────────────────────────────────────────────
// PURE Swift (no SwiftUI). The shared scheduling engine behind BOTH the dashboard
// "next dose" card and the Calendar screen. Given the saved protocols (SavedDosage),
// it derives how often each one is injected (`injectionIntervalDays`) and projects
// concrete dose dates forward over a rolling window (`projectedDoses`).
//
// Deterministic + unit-testable: every entry point takes an explicit reference
// `Date` (no hidden `Date()`), and date math goes through `Calendar.current` only
// for day arithmetic. Protocol `start_date` / dose_log `dosed_on` are "YYYY-MM-DD"
// strings; parse them via the module-local `dpParseDay` helper (name kept unique to
// avoid clashing with the Calculators module's own parsers).

// MARK: - Day-string parsing (shared, module-local)

/// A single fixed UTC "YYYY-MM-DD" formatter. Used for both parsing protocol
/// `start_date` and formatting projected occurrence days back to strings so they
/// match what the backend stores in `dose_log.dosed_on`.
enum DoseDateFormat {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Parse a "YYYY-MM-DD" day string into a `Date` at 00:00 UTC. Returns nil on a
/// malformed / empty string.
func dpParseDay(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    // Tolerate full ISO timestamps ("2026-05-20T00:00:00Z") by taking the date part.
    let dayPart = String(string.prefix(10))
    return DoseDateFormat.dayFormatter.date(from: dayPart)
}

/// Format a `Date` back to "YYYY-MM-DD" (UTC) for comparison with `dosed_on`.
func dpFormatDay(_ date: Date) -> String {
    DoseDateFormat.dayFormatter.string(from: date)
}

// MARK: - A single projected dose

/// One concrete projected injection on a given day, attributed to a protocol.
struct DoseOccurrence: Equatable, Identifiable {
    let date: Date            // 00:00 UTC on the dose day
    let protocolId: String
    let slug: CalculatorSlug?
    let label: String
    /// Millilitres drawn for THIS injection, when the protocol produces a volume.
    ///
    /// Carried on the occurrence rather than looked up at the log site, so that the
    /// dashboard and the calendar — which both hold occurrences and NOT the protocols
    /// they came from — cannot write a dose without its volume. `dose_log.draw_ml` is
    /// what the web's inventory route subtracts from the vial
    /// (`app/api/inventory/route.ts`: `(vial_count × vial_ml) − Σ draw_ml`), so a NULL
    /// here is a dose that consumes nothing and a stock reading that never goes down.
    let drawMl: Double?

    /// The dose THIS injection delivers, in the protocol's own unit. Carried for the
    /// same reason as `drawMl` and beside it: the dashboard and the calendar log doses
    /// holding only occurrences, and `dose_log.dose_label` is the column the web's
    /// history renders as "Dose". Nil wherever a single dose cannot be stated.
    var dose: DoseAmount?

    /// What the PROTOCOL looked like, frozen for `dose_log`'s history ledger — the other
    /// four display-snapshot columns.
    ///
    /// Carried here for the third time for the same reason: the dashboard and the
    /// calendar log doses holding an occurrence and NOT the protocol behind it. Derived
    /// once per protocol in `projectedDoses`, so the two log paths cannot write a
    /// snapshot that disagrees with the projection — or, as before, write none at all
    /// (T-59).
    var snapshot: DoseSnapshot

    /// Stable identity for diffing/SwiftUI lists: protocol + day.
    var id: String { "\(protocolId)@\(dpFormatDay(date))" }

    /// "YYYY-MM-DD" form, for matching against dose_log pins.
    var dayKey: String { dpFormatDay(date) }
}

// MARK: - Draw volume

/// THE derivation of "how many millilitres is one injection of this protocol".
/// One function, one answer, every caller.
///
/// It does not compute anything itself — it re-runs the calculator the protocol was
/// saved from. That is the point: the volume written to `dose_log.draw_ml` is the same
/// number the user read off the result card when they saved, produced by the same
/// engine, and if it is ever wrong it is wrong in ONE place rather than in a second
/// derivation that drifts from the first.
///
/// **`config["mlDrawn"]` is NOT this number and must never be used as it.** It is
/// present in trt/microdose/steroid configs at a flat `0.5` because
/// `CalculatorCatalog.configExtras` writes the web's default for "the unused half of
/// the mode pair" — its own comment says so. Reading it would put a plausible, wrong
/// volume on every dose, which is worse than a NULL: a NULL under-consumes the vial
/// visibly, a wrong number mis-decrements it silently.
enum DoseVolume {

    /// What one injection of this protocol is — the volume in the barrel and the dose it
    /// carries. Either half may be nil; both come from the SAME re-evaluation, so a card
    /// that shows "74.5 mg" and a row that stores "0.373 mL" can never be describing two
    /// different injections.
    struct PerInjection: Equatable {
        /// Millilitres drawn. Nil where the calculator produces no volume.
        var ml: Double?
        /// The dose itself, in the calculator's own unit. Nil where a single dose cannot
        /// be stated — see `CalculatorResult.dosePerInjection`.
        var dose: DoseAmount?

        static let none = PerInjection(ml: nil, dose: nil)
    }

    /// Millilitres for one injection, or nil when this protocol has no volume that can
    /// be stated honestly.
    ///
    /// Returns nil, deliberately, for: a `calculator_type` this build does not know;
    /// a calculator that produces no volume (bmi, freetest, reconstitution, plotter);
    /// an invalid config; and a config saved in a dosing MODE this app's `evaluate`
    /// does not run — see `modeIsEvaluatedAsSaved`.
    static func perInjectionMl(for dosage: SavedDosage) -> Double? {
        perInjection(for: dosage).ml
    }

    /// The one gated re-evaluation of a saved protocol. `perInjectionMl` and
    /// `ProtocolSummary.amount` are both this function; neither derives anything itself.
    ///
    /// The gate is why they must share: a row saved in a mode `evaluate` does not run
    /// yields a different volume AND a different dose from the same numbers, so a build
    /// that refused the volume but published the dose would put a number on a card that
    /// it had already decided was not safe to store.
    static func perInjection(for dosage: SavedDosage) -> PerInjection {
        guard let slug = CalculatorSlug(rawValue: dosage.calculatorType),
              modeIsEvaluatedAsSaved(dosage.config, slug: slug) else { return .none }
        let values = CalculatorCatalog.values(fromConfig: dosage.config, slug: slug)
        // `.u100` is not a guess and not a default that matters: the syringe scale
        // changes the UNITS row only (`unitsPerInj = mlPerInj × unitsPerML`). Every
        // family's volume — `mgPerInj / strength`, `dose / concentration` — is
        // scale-invariant, so this argument cannot move the number being written.
        let result = CalculatorEngine.evaluate(slug: slug, values: values, scale: .u100)
        guard result.isValid else { return .none }
        let ml = result.drawMl.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let dose = result.dosePerInjection.flatMap { $0.value.isFinite && $0.value > 0 ? $0 : nil }
        return PerInjection(ml: ml, dose: dose)
    }

    /// Whether `evaluate` would run this config under the mode it was SAVED in.
    ///
    /// `evaluate` hard-codes a mode for two families — microdose and steroid are both
    /// `.ndays` — because that is the one mode their iOS form offers. The web's pages
    /// offer more (`ndays`, `perweek`, `ml2mg`) and write the mode into the config, and
    /// the same row evaluated in the wrong mode yields a DIFFERENT volume from the same
    /// numbers.
    ///
    /// So a row saved in a mode this build does not run is refused rather than
    /// approximated. Refusing writes NULL, which under-reports consumption and is
    /// visible; approximating writes a wrong volume, which mis-decrements a vial and is
    /// not. This is not a second derivation — it is the one derivation declining to
    /// answer outside its domain.
    ///
    /// **T-24: `.trt` used to be on that list and had stopped being true.** It read
    /// `mode == "perweek"`, which was correct when `evaluate` hard-coded `.perweek` for
    /// TRT — but T-01a #1 made `mode` a real field and `evaluate` has honoured all three
    /// branches ever since. The stale gate was refusing **21 of 39 TRT rows across 13 of
    /// 22 TRT users** — every protocol saved in `ndays`, which is the web's own default —
    /// so those doses logged a NULL volume and, after T-53, showed no dose on their card
    /// and no amount field to correct. Refusing on a rule that is no longer true is not
    /// caution, it is the same wrong answer given confidently.
    ///
    /// **`ml2mg` stays refused, and not for iOS's sake.** `evaluate` runs it correctly
    /// (`mgPerInj = mlDrawn × strength`), but the WEB's `deriveDose` has no `ml2mg`
    /// branch for `trt` — it spaces by `injPerWeek` and computes the dose from `mgWeek`
    /// like `perweek`. The two clients therefore disagree about what such a row means,
    /// and a volume iOS is sure of and the web contradicts is worse than a NULL. One row
    /// in production. Filed against T-24.
    private static func modeIsEvaluatedAsSaved(_ config: JSONValue, slug: CalculatorSlug) -> Bool {
        guard let mode = config["mode"]?.string, !mode.isEmpty else { return true }
        switch slug {
        case .trt:                  return mode == "ndays" || mode == "perweek"
        case .microdose, .steroid:  return mode == "ndays"
        // The rest either ignore `mode` in `evaluate` (glp1 reads conc/dose only) or
        // never carry one (hcg, bpc157, bpc157blend, eod).
        default:                    return true
        }
    }
}

// MARK: - Engine

enum DoseProjection {

    /// Days between injections for a saved protocol, derived best-effort from its
    /// `calculator_type` + `config` JSON. Returns nil when the cadence can't be
    /// determined (e.g. one-shot calculators like BMI / Free-T / reconstitution that
    /// have no schedule), in which case the protocol is simply not projected.
    ///
    /// Mapping by calculator family:
    ///   • EOD (`eod`, or any `config.mode == "eod"`)            → every 2 days
    ///   • TRT / microdose / peptide / hcg / bpc — read cadence keys, in priority:
    ///       `injPerWeek`  → 7 / injPerWeek
    ///       `nDays`       → nDays   (explicit "every N days")
    ///       `freqDays`    → freqDays (alt key some calcs use)
    ///       `mode == "daily"` → 1
    ///   • GLP-1 (`semaglutide` / `tirzepatide` / `retatrutide`) → 7 (weekly), the
    ///     standard cadence; honours an explicit `injPerWeek` if present.
    ///   • No schedule (bmi, freetest, reconstitution, plotter, blend w/o cadence) → nil
    static func injectionIntervalDays(for dosage: SavedDosage) -> Double? {
        let config = dosage.config
        let slug = CalculatorSlug(rawValue: dosage.calculatorType)

        // 1. Explicit EOD — either the dedicated calculator or a mode flag.
        if slug == .eod { return 2 }
        if config["mode"]?.string == "eod" { return 2 }

        // 2. Explicit per-week injection count (most TRT/peptide configs).
        if let perWeek = config["injPerWeek"]?.double, perWeek > 0 {
            return 7.0 / perWeek
        }

        // 3. Explicit "every N days".
        if let nDays = config["nDays"]?.double, nDays > 0 { return nDays }
        if let freqDays = config["freqDays"]?.double, freqDays > 0 { return freqDays }

        // 4. Daily mode.
        if config["mode"]?.string == "daily" { return 1 }

        // 5. Family defaults.
        switch slug {
        case .semaglutide, .tirzepatide, .retatrutide:
            return 7                       // GLP-1 weekly
        case .trt, .microdose, .peptide, .hcg, .bpc157, .bpc157blend, .steroid:
            // Reasonable default cadence when the config omits an explicit one:
            // TRT/peptide families are most commonly twice-weekly. Injectable
            // steroids sit here too — the catalogue's own nDays default is 3.5.
            return 3.5
        case .eod:
            return 2
        case .bmi, .freeTestIndex, .reconstitution, .cyclePlotter, .none:
            return nil                     // no injection schedule
        }
    }

    /// Project concrete dose days for every protocol over a rolling window of
    /// `days` length starting at the day containing `from`. Each protocol is
    /// projected from its own `start_date` forward at its interval; occurrences
    /// before the window start are skipped, the first in-window occurrence onward
    /// is emitted up to `from + days`.
    ///
    /// - Parameters:
    ///   - protocols: the user's saved protocols (only `is_active` ones are projected).
    ///   - from:      reference date — the window starts at its calendar day (UTC).
    ///   - days:      window length in days (e.g. 30 for the calendar, 14 for the dash).
    /// - Returns: occurrences sorted ascending by date.
    static func projectedDoses(
        for protocols: [SavedDosage],
        from: Date,
        days: Int
    ) -> [DoseOccurrence] {
        guard days > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let windowStart = calendar.startOfDay(for: from)
        guard let windowEnd = calendar.date(byAdding: .day, value: days, to: windowStart) else {
            return []
        }

        var result: [DoseOccurrence] = []

        for proto in protocols where proto.isActive {
            guard let interval = injectionIntervalDays(for: proto), interval > 0 else { continue }
            guard let start = dpParseDay(proto.startDate) else { continue }

            let slug = CalculatorSlug(rawValue: proto.calculatorType)
            let label = proto.label ?? slug?.shortTitle ?? proto.calculatorType
            // Once per protocol, not once per day: what one injection is is a property
            // of the protocol, and re-evaluating it inside the day loop would run the
            // engine thirty times for one answer.
            let perInjection = DoseVolume.perInjection(for: proto)
            // Same rule, same reason.
            let snapshot = DoseSnapshot(for: proto)

            // Walk dose days from the protocol start. Interval may be fractional
            // (e.g. 3.5 for twice-weekly): accumulate in days and round to the day.
            // Fast-forward to the first occurrence at/after the window start.
            let startDay = calendar.startOfDay(for: start)

            // Number of whole intervals between start and window start (>= 0).
            var step = 0
            if startDay < windowStart {
                let elapsed = windowStart.timeIntervalSince(startDay) / 86_400.0
                step = max(0, Int((elapsed / interval).rounded(.down)))
            }

            // Emit occurrences within [windowStart, windowEnd).
            while true {
                // Floor (not round-half-away) so a 3.5-day interval yields the
                // conventional alternating 3/4-day pattern (0,3,7,10,14 — e.g. Mon/Thu),
                // matching the web schedule rather than 0,4,7,11,14.
                let offsetDays = Int(Double(step) * interval)
                guard let occDay = calendar.date(byAdding: .day, value: offsetDays, to: startDay) else { break }
                if occDay >= windowEnd { break }
                if occDay >= windowStart {
                    result.append(DoseOccurrence(date: occDay,
                                                 protocolId: proto.id,
                                                 slug: slug,
                                                 label: label,
                                                 drawMl: perInjection.ml,
                                                 dose: perInjection.dose,
                                                 snapshot: snapshot))
                }
                step += 1
                // Safety: never loop forever on a degenerate interval.
                if step > days * 4 + 8 { break }
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    /// The soonest projected dose at/after `from` (used by the dashboard "next dose").
    /// Looks ahead `lookAheadDays` (default 30) and returns the earliest occurrence,
    /// or nil if nothing is scheduled in that window.
    static func nextDose(
        for protocols: [SavedDosage],
        from: Date,
        lookAheadDays: Int = 30
    ) -> DoseOccurrence? {
        projectedDoses(for: protocols, from: from, days: lookAheadDays).first
    }
}
