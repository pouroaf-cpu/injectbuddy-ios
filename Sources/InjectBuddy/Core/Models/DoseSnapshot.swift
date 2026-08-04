import Foundation

// ─── DoseSnapshot ────────────────────────────────────────────────────────────
// The DISPLAY-SNAPSHOT columns on `dose_log` that describe the PROTOCOL, and the
// injection MOMENT that goes with them. Pure Swift, no SwiftUI, no I/O — derived from
// the saved protocol exactly as the web derives them, so an iOS-logged history row and
// a web-logged one read the same for the same protocol.
//
// The fifth snapshot column, `dose_label`, is NOT here. It describes the INJECTION,
// not the protocol, and T-52 made it editable — it comes from `ProtocolSummary` /
// `DoseAmount` on `NewDoseLogPin`, seeded from this app's own calculator engine and
// overridable by the user. Freezing the planned dose here would silently undo that:
// a half dose would be recorded as a full one.
//
// WHY THE COLUMNS EXIST (`app/api/dose-log/route.ts`: "Body also carries an immutable
// display snapshot for the history ledger"). `DoseHistory.tsx:86-89` renders
//
//     row.protocol_label || p?.label || 'Unknown protocol'
//
// — a LIVE lookup of the protocol when the snapshot is NULL. iOS wrote none of the
// five, so an iOS-logged row re-read its label from the protocol on every render and
// **changed retroactively when the user renamed or deleted that protocol**, while a
// web-logged row for the same dose stayed frozen. T-59.
//
// WHY THESE THREE ARE THE WEB'S DERIVATION AND NOT THIS APP'S. The fallback they
// replace IS the web's own `deriveProtocols()` output. Writing the same strings means
// turning the snapshot on changes nothing a user sees today, and only stops it changing
// tomorrow. Ported from `components/account/protocol-meta.ts` (protoDisplay /
// abbrevCompound / compoundOf) and `lib/account-schedule.ts` (deriveProtocols) on
// branch `feature/dosage-status-model` — read from that source, not from a document
// about it.
//
// `draw_ml` and `dose_label` are deliberately NOT here: they are numbers a user acts
// on, and they have exactly one derivation each — this app's own calculator engine,
// through `DoseVolume.perInjection`. These three are display text for a ledger the web
// renders.

struct DoseSnapshot: Equatable {
    /// `protocol_label` — web: `ev.label`, i.e. `row.label ?? CALC_LABEL(calc)`.
    let protocolLabel: String
    /// `compound_label` — web: `compoundOf(row)`.
    let compoundLabel: String?
    /// `category` — web: `ev.calc`, the RAW `calculator_type` slug.
    ///
    /// Not a display name. `DoseHistory.tsx:88` maps it through its own `CATEGORY`
    /// table for rendering, and the live column reads `trt` / `peptide` / `steroid` /
    /// `tirzepatide` across the web-written rows (one legacy row says `Hormone`).
    /// Writing a pretty name here would filter into its own bucket and sort apart from
    /// every web row.
    let category: String

    init(for dosage: SavedDosage) {
        protocolLabel = dosage.label.flatMap { $0.isEmpty ? nil : $0 }
            ?? Self.calcLabel(dosage.calculatorType)
        category = dosage.calculatorType
        compoundLabel = Self.compoundOf(dosage)
    }

    // MARK: - protocol_label

    /// `CALC_LABEL` — `calc.charAt(0).toUpperCase() + calc.slice(1)`.
    static func calcLabel(_ calc: String) -> String {
        guard let first = calc.first else { return calc }
        return first.uppercased() + calc.dropFirst()
    }

    // MARK: - compound_label

    /// Longest-first, so "Testosterone Cypionate" matches before the bare
    /// "Testosterone". Mirrors `COMPOUND_ABBR` in `protocol-meta.ts` (which itself must
    /// stay in lock-step with `public/ib-rail.js`).
    private static let compoundAbbreviations: [(String, String)] = [
        ("Testosterone Cypionate", "Test C"), ("Testosterone Enanthate", "Test E"),
        ("Testosterone Propionate", "Test P"), ("Testosterone Undecanoate", "Test U"),
        ("Testosterone Suspension", "Test Susp"), ("Sustanon 250", "Sustanon"),
        ("Testosterone", "Test"),
    ]

    static func abbrevCompound(_ s: String) -> String {
        var out = s
        for (from, to) in compoundAbbreviations { out = out.replacingOccurrences(of: from, with: to) }
        return out
    }

    /// `CALC_META[type].label` — the calculator's display name. Only reachable when the
    /// protocol has no label of its own.
    private static let calcMetaLabels: [String: String] = [
        "trt": "Testosterone (TRT)", "eod": "EOD", "peptide": "Peptide Dosage",
        "reconstitution": "Reconstitution", "semaglutide": "Semaglutide",
        "tirzepatide": "Tirzepatide", "retatrutide": "Retatrutide",
        "bpc157": "BPC-157", "bpc157blend": "BPC+TB500", "blend": "BPC+TB500",
        "bmi": "BMI", "freetest": "Free Testosterone", "hcg": "HCG",
        "steroid": "Steroid",
    ]

    /// `compoundOf(row)` — the configured ester when there is one (so a label-less TRT
    /// row still names its compound), else the card's primary display line.
    ///
    /// The empty-string guard is not cosmetic: `CalculatorCatalog.configExtras` writes
    /// `esterType: ""` for microdose, and `""` is falsy in the JavaScript this ports, so
    /// a Swift `!= nil` test would take a branch the web never takes and write an empty
    /// compound on every microdose row.
    static func compoundOf(_ dosage: SavedDosage) -> String? {
        if let ester = dosage.config["esterType"]?.string, !ester.isEmpty {
            return abbrevCompound(ester)
        }
        let primary = protoDisplayPrimary(dosage)
        return primary.isEmpty ? nil : primary
    }

    /// The `primary` half of `protoDisplay(row)`.
    static func protoDisplayPrimary(_ dosage: SavedDosage) -> String {
        let typeLabel = calcMetaLabels[dosage.calculatorType] ?? dosage.calculatorType
        let label = dosage.label.flatMap { $0.isEmpty ? nil : $0 }
        let raw = label.map(abbrevCompound) ?? "\(typeLabel) protocol"

        // JS: raw.split(/\s+[·—→+]\s+/) — only a clean two-part split is re-ordered.
        let parts = splitOnDivider(raw)
        guard parts.count == 2 else { return raw }
        let a = parts[0].trimmingCharacters(in: .whitespaces)
        let b = parts[1].trimmingCharacters(in: .whitespaces)
        let aNum = startsWithNumber(a)
        let bNum = startsWithNumber(b)
        // dose · compound → the compound is the primary line; anything else keeps order.
        return (aNum && !bNum) ? b : a
    }

    /// `/\s+[·—→+]\s+/` as a split.
    private static func splitOnDivider(_ raw: String) -> [String] {
        let dividers: Set<Character> = ["·", "—", "→", "+"]
        var parts: [String] = []
        var current = ""
        var pendingSpace = ""
        var index = raw.startIndex
        while index < raw.endIndex {
            let ch = raw[index]
            if ch.isWhitespace {
                pendingSpace.append(ch)
                index = raw.index(after: index)
                continue
            }
            if !pendingSpace.isEmpty, dividers.contains(ch) {
                // Require whitespace on BOTH sides, as the regex does.
                var after = raw.index(after: index)
                var trailing = ""
                while after < raw.endIndex, raw[after].isWhitespace {
                    trailing.append(raw[after])
                    after = raw.index(after: after)
                }
                if !trailing.isEmpty {
                    parts.append(current)
                    current = ""
                    pendingSpace = ""
                    index = after
                    continue
                }
            }
            current += pendingSpace
            pendingSpace = ""
            current.append(ch)
            index = raw.index(after: index)
        }
        parts.append(current + pendingSpace)
        return parts
    }

    /// `/^[\d.]/`
    private static func startsWithNumber(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        return first.isNumber || first == "."
    }

}

// ─── InjectionMoment ─────────────────────────────────────────────────────────
// `injection_time`, `injection_timezone` and `injected_at` — the three columns iOS
// never wrote (T-51).
//
// The consequence was NOT a missing point on the serum chart: `SerumChart.tsx:169-178`
// falls back to `` `${row.dosed_on}T${row.injection_time || '12:00'}:00` ``, so the
// dose plots. It plots at NOON, on a curve whose own comment says it exists so the
// line "jumps the moment it lands" — and that fallback string carries no zone, so the
// browser resolves it in the VIEWER's local time. The same iOS row therefore sits at a
// different absolute moment for a reader in Auckland than for one in New York.
//
// TIMEZONE IS AN IANA IDENTIFIER, NOT AN OFFSET. The web writes
// `Intl.DateTimeFormat().resolvedOptions().timeZone` (`DashboardContext.tsx:193`) —
// "Pacific/Auckland". `TimeZone.current.identifier` is the same vocabulary.
// `secondsFromGMT` would be a plausible-looking value the web cannot use: it cannot
// name the zone, and it silently freezes one side of a DST transition.
enum InjectionMoment {

    /// The web's default when nothing asked the user for a time
    /// (`DashboardContext.tsx:342` `injectionTime = '12:00'`).
    static let defaultTime = "12:00"

    /// - Returns: `(time "HH:mm", IANA zone, injected_at as an ISO-8601 instant)`.
    ///
    /// **Logging today writes the real moment; logging any other day writes noon.**
    /// A dose ticked on the day it happens is happening now — that is every dashboard
    /// "Taken", every calendar toggle on today, and the log sheet's default day, and it
    /// is the case the serum curve exists for. Choose another day in the sheet and this
    /// app has not asked what time it was, so it writes the web's own `12:00` rather
    /// than stamping "now" onto a day the user was not injecting. (The web asks —
    /// `DashLogFlow` has a time picker. iOS has no such control: T-81.)
    ///
    /// When it IS today, `injected_at` is `now` verbatim rather than a recomposition of
    /// `dosed_on` + `time`. Those two are not the same instant, because the day strings
    /// reaching this function are not all in one frame: `LogDoseSheet` formats its day
    /// in `TimeZone.current` while `DoseProjection` formats occurrence days in UTC, and
    /// east of UTC those disagree for half of every day (T-82). `injected_at` is the
    /// column the chart actually plots (`SerumChart.tsx:171` prefers it and only falls
    /// back to `dosed_on + injection_time`), so it gets the instant that is true
    /// regardless of which frame labelled the day — and matching EITHER frame's "today"
    /// is what keeps a genuine same-day log from being demoted to noon.
    static func forLog(dosedOn: String,
                       now: Date = Date(),
                       timeZone: TimeZone = .current) -> (time: String, timezone: String, injectedAt: String?) {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let parts = local.dateComponents([.year, .month, .day, .hour, .minute], from: now)

        let isToday = day(parts) == dosedOn || dpFormatDay(now) == dosedOn
        guard isToday, let h = parts.hour, let mi = parts.minute else {
            return (defaultTime, timeZone.identifier,
                    instant(dosedOn: dosedOn, time: defaultTime, timeZone: timeZone))
        }
        return (String(format: "%02d:%02d", h, mi), timeZone.identifier,
                isoFormatter.string(from: now))
    }

    private static func day(_ parts: DateComponents) -> String? {
        guard let y = parts.year, let mo = parts.month, let d = parts.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, mo, d)
    }

    /// `zonedDateTimeToIso` — the wall clock `dosedOn` at `time` AS READ IN `timeZone`,
    /// as an absolute instant. Nil for a day string that is not `YYYY-MM-DD`, which is
    /// an absent key rather than a wrong moment.
    static func instant(dosedOn: String, time: String, timeZone: TimeZone) -> String? {
        let day = dosedOn.split(separator: "-")
        let clock = time.split(separator: ":")
        guard day.count == 3, let y = Int(day[0]), let mo = Int(day[1]), let d = Int(day[2]),
              clock.count >= 2, let h = Int(clock[0]), let mi = Int(clock[1]) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = y; components.month = mo; components.day = d
        components.hour = h; components.minute = mi; components.second = 0
        guard let date = calendar.date(from: components) else { return nil }
        return isoFormatter.string(from: date)
    }

    /// UTC, with fractional seconds — the same shape `Date.prototype.toISOString()`
    /// produces on the web side.
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
