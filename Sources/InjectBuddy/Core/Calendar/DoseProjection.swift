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

    /// Stable identity for diffing/SwiftUI lists: protocol + day.
    var id: String { "\(protocolId)@\(dpFormatDay(date))" }

    /// "YYYY-MM-DD" form, for matching against dose_log pins.
    var dayKey: String { dpFormatDay(date) }
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
        case .trt, .microdose, .peptide, .hcg, .bpc157, .bpc157blend:
            // Reasonable default cadence when the config omits an explicit one:
            // TRT/peptide families are most commonly twice-weekly.
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
                let offsetDays = Int((Double(step) * interval).rounded())
                guard let occDay = calendar.date(byAdding: .day, value: offsetDays, to: startDay) else { break }
                if occDay >= windowEnd { break }
                if occDay >= windowStart {
                    result.append(DoseOccurrence(date: occDay,
                                                 protocolId: proto.id,
                                                 slug: slug,
                                                 label: label))
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
