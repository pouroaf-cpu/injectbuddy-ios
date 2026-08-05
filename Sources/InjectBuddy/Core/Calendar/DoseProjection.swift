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
//
// ── T-82: A CALENDAR DAY IS NOT AN INSTANT, AND ONLY ONE FRAME NAMES IT ──────────
// This file deals in two different things and they used to be conflated:
//
//   • a DAY TOKEN — "which square on the wall calendar". `start_date`, `dosed_on`,
//     an occurrence's day. It has no time zone at all. It is CARRIED as 00:00 UTC
//     purely so it can be a `Date`, and all interval arithmetic runs on tokens in
//     that fixed frame, where a day is always exactly 86400s and no DST transition
//     can gain or lose an hour across an N-day step.
//
//   • an INSTANT — `now`, or the day the user picked in `LogDoseSheet`. A real
//     moment, which falls on ONE calendar day and the answer depends on the zone
//     you ask in.
//
// The defect was that the ONE conversion from an instant to a token — the start of
// the projection window — was done in UTC. East of UTC that names yesterday from
// local midnight until UTC midnight (twelve hours a day in Auckland), so a dose the
// user would call Tuesday was projected, displayed and LOGGED as Monday, while the
// same dose logged through `LogDoseSheet` was Tuesday. `dose_log`'s unique index is
// `(protocol_id, dosed_on)`, so the two are different rows and one injection
// upserts twice. **No instance of this was found in production (win, 2026-08-04) —
// it is latent, not live.**
//
// **The frame is LOCAL, and that is the web's decision, not ours.** Every
// web-written `dosed_on` comes from the `ymd` helper in `DashboardContext.tsx`,
// whose own comment says: *"local 'YYYY-MM-DD' (matches parseLocalDate / a Postgres
// `date`) — never toISOString (that would shift the calendar day for negative-UTC
// offsets)"*. Both clients write through the same index, so iOS agreeing with the
// web is not a preference; standardising on UTC would have made the two collide
// while each believed it was right.
//
// ── AND THE REASON IT HAPPENED AT ALL: THERE WAS NO NAMED WRITER ─────────────────
// Windows swept the web for this class on 2026-08-04 and found the same shape
// there, twice and LIVE in the owner's own zone — `CalendarView` seeding a new
// protocol's `start_date`, and `ProgressTracker` seeding `measured_on`, both with
// `new Date().toISOString().slice(0, 10)`. The root cause was not two careless call
// sites: `parseLocalDate` had always been exported to READ a Postgres date and
// **nothing was exported to WRITE one**, so six components each grew a private
// copy and the two that did not think about zones reached for `toISOString`. The
// web's fix was to export `localYmd` beside `parseLocalDate` — one obvious,
// shareable inverse — not to patch the two call sites.
//
// iOS was in exactly that state: `dpParseDay` to read, and four private
// `DateFormatter`s to write. So the pair is now named and exported here, and it is
// the ONLY way this app turns a moment into a day string:
//
//     read   day string → local Date   `dpParseLocalDay`   (the web's parseLocalDate)
//     write  instant    → day string   `dpLocalDay`        (the web's localYmd)
//
// plus `dpDayToken`, which is `dpLocalDay` landed back on the token frame so an
// instant can enter the arithmetic without dragging a zone in with it. The zone is
// a parameter on all three so a test can pin one instead of inheriting the
// machine's. **A new surface that needs a `dosed_on`, a `start_date` or any other
// bare `date` column calls these. It does not build a fifth formatter.**

// MARK: - Day-string parsing (shared, module-local)

/// A single fixed UTC "YYYY-MM-DD" formatter — the TOKEN frame.
///
/// UTC here is not a claim about anybody's day. It is the arbitrary fixed anchor a
/// zone-less calendar day is carried on so that day arithmetic is exact; see the
/// T-82 note above. Nothing that turns a real INSTANT into a day may use it.
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

/// Parse a "YYYY-MM-DD" day string into its token (00:00 UTC). Returns nil on a
/// malformed / empty string.
func dpParseDay(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    // Tolerate full ISO timestamps ("2026-05-20T00:00:00Z") by taking the date part.
    let dayPart = String(string.prefix(10))
    return DoseDateFormat.dayFormatter.date(from: dayPart)
}

/// Format a day TOKEN back to "YYYY-MM-DD".
///
/// Correct only for a value that already IS a token — one produced by `dpParseDay`,
/// `dpDayToken`, or a UTC-calendar day walk over either. Handing it `Date()` asks a
/// question it cannot answer: use `dpLocalDay`.
func dpFormatDay(_ date: Date) -> String {
    DoseDateFormat.dayFormatter.string(from: date)
}

/// **THE writer.** The day `instant` falls on, as the person holding the phone
/// would name it — and the only way this app produces a `dosed_on`, a `start_date`
/// or any other bare Postgres `date`.
///
/// This is iOS's `localYmd`, the counterpart of the `ymd` helper in the web's
/// `DashboardContext.tsx`, and deliberately the same shape: read the
/// year/month/day components in the local zone and print them. It is built from
/// `DateComponents` rather than a shared `DateFormatter` on purpose — a
/// `DateFormatter` holding `TimeZone.current` freezes the zone at first use, so it
/// would keep answering in the old zone after the device changed country, and it
/// would not be safe to retune per call from more than one thread.
///
/// `zone` defaults to the device's, and is a parameter so a test can pin Auckland
/// or Los Angeles without the machine being set to either.
func dpLocalDay(_ instant: Date, in zone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let parts = calendar.dateComponents([.year, .month, .day], from: instant)
    guard let y = parts.year, let m = parts.month, let d = parts.day else {
        return dpFormatDay(instant)
    }
    // `String(format:)` with `%d` is not locale-sensitive; `DateFormatter` would be.
    return String(format: "%04d-%02d-%02d", y, m, d)
}

/// **THE reader that pairs with it** — a stored day string as the local midnight a
/// date picker should show, so that what the user sees is the day the column holds.
/// The web's `parseLocalDate`, and its comment applies here verbatim: reading a bare
/// day as UTC midnight *"lands on the previous day for negative-UTC offsets (all of
/// the US)"*.
///
/// Distinct from `dpParseDay`, which reads the same string into the zone-less TOKEN
/// frame for arithmetic. Both are correct; they answer different questions, and the
/// one thing that must not happen is a surface reading with one and writing with the
/// other.
func dpParseLocalDay(_ string: String?, in zone: TimeZone = .current) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    let parts = String(string.prefix(10)).split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    var components = DateComponents()
    components.year = y; components.month = m; components.day = d
    return calendar.date(from: components)
}

/// The same answer as `dpLocalDay`, as a day TOKEN — so an instant can enter the
/// token arithmetic above without dragging a time zone in with it.
func dpDayToken(_ instant: Date, in zone: TimeZone = .current) -> Date {
    dpParseDay(dpLocalDay(instant, in: zone)) ?? instant
}

// MARK: - A single projected dose

/// One concrete projected injection on a given day, attributed to a protocol.
struct DoseOccurrence: Equatable, Identifiable {
    /// The dose day as a TOKEN (00:00 UTC). Not an instant and not a claim about
    /// anyone's clock — see the T-82 note at the top of this file. `dayKey` prints it.
    let date: Date
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
    ///   - from:      reference INSTANT — the window starts on the calendar day this
    ///                moment falls on **in `zone`**.
    ///   - days:      window length in days (e.g. 30 for the calendar, 14 for the dash).
    ///   - zone:      the zone that names the day. Defaults to the device's, which is
    ///                the frame the web writes `dosed_on` in; a parameter so a test can
    ///                pin one rather than inherit the machine's.
    /// - Returns: occurrences sorted ascending by date.
    static func projectedDoses(
        for protocols: [SavedDosage],
        from: Date,
        days: Int,
        in zone: TimeZone = .current
    ) -> [DoseOccurrence] {
        guard days > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // **T-82 — the one and only instant → day conversion in this engine, and it is
        // LOCAL.** It was `calendar.startOfDay(for: from)` on a UTC calendar, which east
        // of UTC named yesterday for the first twelve hours of every Auckland day: the
        // window opened a day early and every occurrence in it — including the "next
        // dose" the dashboard logs — was labelled and WRITTEN as the previous day, while
        // `LogDoseSheet` wrote the same injection under today. Everything after this line
        // stays in the token frame, so the interval arithmetic is still DST-free.
        let windowStart = dpDayToken(from, in: zone)
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

            // Iterations of the walk below — NOT the dose ordinal. See the guard at the
            // bottom of the loop (T-81): conflating the two is what deleted long-running
            // protocols from every schedule surface.
            var emitted = 0

            // Emit occurrences within [windowStart, windowEnd).
            while true {
                // ── T-97 — ROUND, NOT FLOOR, AND THE OLD COMMENT HERE WAS BACKWARDS. ──
                // It read: "Floor … matching the web schedule rather than 0,4,7,11,14."
                // **0,4,7,11,14 IS the web schedule.** The sentence named the correct
                // behaviour and called it the thing it was avoiding, which is why the
                // divergence survived every review — a comment asserting a compatibility
                // it did not have.
                //
                // The web's rule, `lib/account-schedule.ts`:
                //
                //     if (Number.isInteger(f)) return d % f === 0
                //     const k = Math.round(d / f)
                //     return Math.round(k * f) === d
                //
                // i.e. a day is a dose day iff it is the NEAREST INTEGER DAY to some
                // exact multiple of the interval. Emitting `round(step × interval)` is
                // that same set, generated forwards.
                //
                // NEITHER SPACING WAS ARITHMETICALLY WRONG, which is the reason nothing
                // ever flagged this: web 3.5 gives gaps of 4,3,4,3 and the old floor gave
                // 3,4,3,4 — **both average exactly 3.5.** They differ only in PHASE, so
                // no aggregate check can see it; only a user holding both clients does.
                //
                // iOS moves rather than the web, and the reason is DATA, not correctness:
                // every existing `dose_log` row and every projection those users have
                // already seen was generated on the web's grid. Changing the web would
                // misalign rows that are already written.
                //
                // `Math.round` in JS is half-UP; Swift's `.rounded()` is
                // `.toNearestOrAwayFromZero`, which is IDENTICAL for non-negative values.
                // `step` is non-negative by construction here, which is what makes the
                // two agree — the equivalence is not general.
                let offsetDays = Int((Double(step) * interval).rounded())
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
                //
                // ── T-81 — THIS GUARD USED TO READ `if step > days * 4 + 8`, AND `step`
                // IS NOT THE QUANTITY THAT BUDGET DESCRIBES. ────────────────────────────
                // `step` is fast-forwarded above to *how many doses have occurred since
                // the protocol began*; `days * 4 + 8` bounds *iterations of this loop*,
                // which is a function of the WINDOW. Two different quantities compared to
                // each other. Once a protocol was older than the budget, the loop broke
                // after at most one emission — so a still-active, still-due protocol
                // simply STOPPED APPEARING on the dashboard and the calendar. No error,
                // no empty state, no "nothing scheduled" copy that would at least have
                // been a visible claim. It aged out.
                //
                // A daily protocol running since January, projected over 30 days:
                // `step` fast-forwards to ~200 against a budget of 128, and one day of
                // thirty is emitted. The bug is a THRESHOLD, not a constant, which is why
                // nothing ever caught it — a protocol projects perfectly right up until
                // the day it silently does not.
                //
                // `emitted` counts iterations of THIS loop, so the guard now measures the
                // quantity it is compared against. The bound itself is unchanged and is
                // still doing its original job: at the smallest interval the app can
                // produce, four doses a day, `days * 4` covers the window and `+ 8` is
                // slack for the fractional-interval walk.
                //
                // **THIS FIXES THE INSTANCE, NOT THE CLASS.** The projection still builds
                // the series statefully — a counter and a separately-derived bound that
                // can drift apart again. The web cannot have this bug at all because its
                // primitive is a pure per-date predicate (`isDoseDay(p, date)` in
                // `lib/account-schedule.ts`) with no accumulator and no budget. Making
                // this a per-date test would remove the class; that is a larger change
                // and is tracked separately.
                emitted += 1
                if emitted > days * 4 + 8 { break }
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
        lookAheadDays: Int = 30,
        in zone: TimeZone = .current
    ) -> DoseOccurrence? {
        projectedDoses(for: protocols, from: from, days: lookAheadDays, in: zone).first
    }
}
