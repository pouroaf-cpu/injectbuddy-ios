import Foundation

// ─── DashboardViewModel ──────────────────────────────────────────────────────
// Loads everything the dashboard needs (protocols + cycles + recent dose log) in
// parallel, then derives the screen's display model client-side:
//   • the soonest upcoming dose (via DoseProjection)
//   • active-cycle progress (day X of Y)
//   • weekly compound totals ("WEEK AT A GLANCE")
//   • per-protocol summary rows for the grid
// Renders off a single LoadState so the screen stays declarative.

// MARK: - Display model

/// A protocol summarised for the dashboard grid card.
struct DashboardProtocol: Equatable, Identifiable {
    let id: String
    let slug: CalculatorSlug?
    let title: String          // short title or user label
    let subtitle: String       // "50mg · E3.5", "0.5mg wk", …
    let startDate: String?
}

/// Active-cycle progress strip data.
struct CycleProgress: Equatable {
    let name: String
    let dayIndex: Int          // 1-based: "Day 12 of 84"
    let totalDays: Int
    var fraction: Double { totalDays > 0 ? min(1, max(0, Double(dayIndex) / Double(totalDays))) : 0 }
}

/// One weekly total line ("100mg test", "0.5mg sema").
struct WeeklyTotal: Equatable, Identifiable {
    let id: String             // compound/slug key
    let label: String
}

/// Everything the dashboard renders once loaded.
struct DashboardData: Equatable {
    var nextDose: DashboardNextDose?
    var cycle: CycleProgress?
    var protocols: [DashboardProtocol]
    var weeklyTotals: [WeeklyTotal]
    /// 14-day projection used to render the "THIS CYCLE" week strip dots.
    var upcoming: [DoseOccurrence]
}

/// The "NEXT DOSE" card model.
struct DashboardNextDose: Equatable {
    let occurrence: DoseOccurrence
    let title: String          // compound / protocol name
    let doseLine: String       // "50 mg · 0.25 mL" (best-effort from config)
    let date: Date
    var alreadyTaken: Bool
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var state: LoadState<DashboardData> = .loading

    private var loaded: DashboardData?

    /// Fetch + derive. `now` is injectable for stable previews/tests.
    func load(backend: BackendClient, userId: String?, now: Date = Date()) async {
        state = .loading
        do {
            async let dosagesT = backend.savedDosages()
            async let cyclesT = backend.cyclesWithItems()
            // Pull a month of recent pins so "already taken" can be flagged.
            let since = dpFormatDay(Calendar.current.date(byAdding: .day, value: -31, to: now) ?? now)
            async let pinsT = backend.doseLog(since: since)

            let (dosages, cycles, pins) = try await (dosagesT, cyclesT, pinsT)

            let active = dosages.filter { $0.isActive }
            if active.isEmpty {
                loaded = nil
                state = .empty
                return
            }

            let data = Self.derive(dosages: active, cycles: cycles, pins: pins, now: now)
            loaded = data
            state = .loaded(data)
        } catch {
            state = .failed(Self.message(error))
        }
    }

    /// Optimistically mark a projected dose as taken, then POST it.
    func markTaken(_ occurrence: DoseOccurrence, backend: BackendClient) async {
        // Optimistic flip in the loaded model.
        if var data = loaded, data.nextDose?.occurrence == occurrence {
            data.nextDose?.alreadyTaken = true
            loaded = data
            state = .loaded(data)
        }
        let pin = NewDoseLogPin(protocolId: occurrence.protocolId,
                                dosedOn: occurrence.dayKey,
                                drawMl: nil, site: nil)
        do {
            _ = try await backend.logDose(pin)
        } catch {
            // Roll back on failure.
            if var data = loaded, data.nextDose?.occurrence == occurrence {
                data.nextDose?.alreadyTaken = false
                loaded = data
                state = .loaded(data)
            }
        }
    }

    // MARK: - Derivation (pure, static for testability)

    static func derive(dosages: [SavedDosage],
                       cycles: [CycleWithItems],
                       pins: [DoseLogPin],
                       now: Date) -> DashboardData {
        let upcoming = DoseProjection.projectedDoses(for: dosages, from: now, days: 14)

        // Next dose = soonest projection in the next 30 days.
        var nextDose: DashboardNextDose?
        if let occ = DoseProjection.nextDose(for: dosages, from: now, lookAheadDays: 30) {
            let proto = dosages.first { $0.id == occ.protocolId }
            let taken = pins.contains { $0.protocolId == occ.protocolId && $0.dosedOn == occ.dayKey }
            nextDose = DashboardNextDose(
                occurrence: occ,
                title: occ.label,
                doseLine: proto.map { DashboardFormat.doseLine(for: $0) } ?? "",
                date: occ.date,
                alreadyTaken: taken
            )
        }

        // Active cycle progress.
        var cycle: CycleProgress?
        if let active = cycles.first(where: { $0.cycle.isActive }),
           let start = dpParseDay(active.cycle.startDate) {
            let onWeeks = active.cycle.onWeeks ?? 0
            let totalDays = onWeeks > 0 ? onWeeks * 7 : 0
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let elapsed = cal.dateComponents([.day], from: cal.startOfDay(for: start),
                                             to: cal.startOfDay(for: now)).day ?? 0
            if totalDays > 0 {
                let dayIndex = min(totalDays, max(1, elapsed + 1))
                cycle = CycleProgress(name: active.cycle.name, dayIndex: dayIndex, totalDays: totalDays)
            }
        }

        // Protocol grid rows.
        let protocols = dosages.map { d -> DashboardProtocol in
            let slug = CalculatorSlug(rawValue: d.calculatorType)
            return DashboardProtocol(
                id: d.id,
                slug: slug,
                title: d.label ?? slug?.shortTitle ?? d.calculatorType,
                subtitle: DashboardFormat.subtitle(for: d),
                startDate: d.startDate
            )
        }

        // Weekly totals.
        let weeklyTotals = DashboardFormat.weeklyTotals(for: dosages)

        return DashboardData(nextDose: nextDose,
                             cycle: cycle,
                             protocols: protocols,
                             weeklyTotals: weeklyTotals,
                             upcoming: upcoming)
    }

    private static func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

// ─── DashboardFormat ─────────────────────────────────────────────────────────
// Best-effort presentation strings derived from a protocol's free-form config.
// Reads JSONValue keys gracefully (missing → omitted). Names are unique to this
// module to avoid clashing with the Calculators agent's formatters.

enum DashboardFormat {

    /// Frequency phrase from the derived interval ("E3.5", "EOD", "weekly", "daily").
    static func frequency(for dosage: SavedDosage) -> String? {
        guard let interval = DoseProjection.injectionIntervalDays(for: dosage) else { return nil }
        switch interval {
        case 1: return "daily"
        case 2: return "EOD"
        case 7: return "weekly"
        default:
            // E3.5-style "every N days".
            let trimmed = interval == interval.rounded()
                ? String(Int(interval))
                : String(format: "%.1f", interval)
            return "E\(trimmed)"
        }
    }

    /// The grid card secondary line, e.g. "100mg · E3.5" or "0.5mg · weekly".
    static func subtitle(for dosage: SavedDosage) -> String {
        var parts: [String] = []
        if let dose = doseMagnitude(for: dosage) { parts.append(dose) }
        if let freq = frequency(for: dosage) { parts.append(freq) }
        return parts.joined(separator: " · ")
    }

    /// The next-dose card's dose line, e.g. "100 mg · 0.25 mL".
    static func doseLine(for dosage: SavedDosage) -> String {
        var parts: [String] = []
        if let dose = doseMagnitude(for: dosage) { parts.append(dose) }
        if let ml = dosage.config["drawMl"]?.double ?? dosage.config["mlPerDose"]?.double ?? dosage.config["ml"]?.double {
            parts.append(String(format: "%.2f mL", ml))
        }
        return parts.joined(separator: " · ")
    }

    /// A human dose magnitude string, reading the most-likely config keys per family.
    /// Returns nil if no recognised dose key is present.
    private static func doseMagnitude(for dosage: SavedDosage) -> String? {
        let c = dosage.config
        // GLP-1 / peptide style: a single `dose` in mg or mcg.
        if let mgWeek = c["mgWeek"]?.double {
            return "\(trim(mgWeek))mg"
        }
        if let dose = c["dose"]?.double {
            // mcg for peptides/HCG when a unit hint says so, else mg.
            let unit = c["doseUnit"]?.string ?? c["unit"]?.string
            if unit?.lowercased() == "mcg" { return "\(trim(dose))mcg" }
            return "\(trim(dose))mg"
        }
        if let mcg = c["doseMcg"]?.double { return "\(trim(mcg))mcg" }
        if let iu = c["doseIu"]?.double ?? c["doseIU"]?.double { return "\(trim(iu)) IU" }
        return nil
    }

    /// Weekly compound totals across all protocols ("WEEK AT A GLANCE").
    static func weeklyTotals(for dosages: [SavedDosage]) -> [WeeklyTotal] {
        dosages.compactMap { d -> WeeklyTotal? in
            let slug = CalculatorSlug(rawValue: d.calculatorType)
            let name = d.label ?? slug?.shortTitle ?? d.calculatorType
            // Prefer an explicit weekly figure; else dose × injections/week.
            let weekly: Double?
            if let mgWeek = d.config["mgWeek"]?.double {
                weekly = mgWeek
            } else if let dose = d.config["dose"]?.double,
                      let interval = DoseProjection.injectionIntervalDays(for: d), interval > 0 {
                weekly = dose * (7.0 / interval)
            } else {
                weekly = nil
            }
            guard let weekly else { return nil }
            let unit = (d.config["doseUnit"]?.string ?? d.config["unit"]?.string)?.lowercased() == "mcg" ? "mcg" : "mg"
            return WeeklyTotal(id: d.id, label: "\(trim(weekly))\(unit) \(name)")
        }
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%g", value)
    }
}
