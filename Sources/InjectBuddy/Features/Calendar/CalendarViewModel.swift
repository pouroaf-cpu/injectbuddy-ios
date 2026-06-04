import Foundation

// ─── CalendarViewModel ───────────────────────────────────────────────────────
// Loads protocols + dose-log pins, then exposes:
//   • a 30-day projection (via DoseProjection) grouped by day → dose dots per day
//   • the agenda for a selected day
//   • taken-state per occurrence (matched against dose_log)
// Toggling a dose taken/untaken optimistically updates the pin set, then calls the
// backend. Renders off a single LoadState.

// MARK: - Display model

/// All projected occurrences over the window, plus the pins to test "taken".
struct CalendarData: Equatable {
    /// Occurrences keyed by "YYYY-MM-DD" for fast day lookups.
    var byDay: [String: [DoseOccurrence]]
    /// Set of "protocolId@YYYY-MM-DD" that are logged as taken.
    var takenKeys: Set<String>
    /// The window's day span (for the month grid), inclusive start.
    var windowStart: Date
    var windowDays: Int

    func occurrences(on day: Date) -> [DoseOccurrence] {
        byDay[dpFormatDay(day)] ?? []
    }
    func isTaken(_ occ: DoseOccurrence) -> Bool {
        takenKeys.contains("\(occ.protocolId)@\(occ.dayKey)")
    }
    var hasAnyDoses: Bool { !byDay.isEmpty }
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var state: LoadState<CalendarData> = .loading
    @Published var selectedDay: Date = Date()

    private var loaded: CalendarData?
    private let windowDays = 30

    func load(backend: BackendClient, now: Date = Date()) async {
        state = .loading
        selectedDay = startOfDay(now)
        do {
            async let dosagesT = backend.savedDosages()
            let since = dpFormatDay(addDays(-1, to: now))
            async let pinsT = backend.doseLog(since: since)
            let (dosages, pins) = try await (dosagesT, pinsT)

            let active = dosages.filter { $0.isActive }
            let occurrences = DoseProjection.projectedDoses(for: active, from: now, days: windowDays)

            if occurrences.isEmpty {
                loaded = nil
                state = .empty
                return
            }

            let data = CalendarData(
                byDay: Dictionary(grouping: occurrences, by: { $0.dayKey }),
                takenKeys: Set(pins.map { "\($0.protocolId)@\($0.dosedOn)" }),
                windowStart: startOfDay(now),
                windowDays: windowDays
            )
            loaded = data
            state = .loaded(data)
        } catch {
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Toggle a projected dose between taken / not-taken (optimistic).
    func toggleTaken(_ occ: DoseOccurrence, backend: BackendClient) async {
        guard var data = loaded else { return }
        let key = "\(occ.protocolId)@\(occ.dayKey)"
        let wasTaken = data.takenKeys.contains(key)

        if wasTaken { data.takenKeys.remove(key) } else { data.takenKeys.insert(key) }
        loaded = data
        state = .loaded(data)

        do {
            if wasTaken {
                try await backend.unlogDose(protocolId: occ.protocolId, dosedOn: occ.dayKey)
            } else {
                _ = try await backend.logDose(NewDoseLogPin(protocolId: occ.protocolId,
                                                            dosedOn: occ.dayKey,
                                                            drawMl: nil, site: nil))
            }
        } catch {
            // Roll back.
            if var rollback = loaded {
                if wasTaken { rollback.takenKeys.insert(key) } else { rollback.takenKeys.remove(key) }
                loaded = rollback
                state = .loaded(rollback)
            }
        }
    }

    // MARK: date helpers (UTC, consistent with the projection engine)

    private var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }
    private func startOfDay(_ date: Date) -> Date { utcCalendar.startOfDay(for: date) }
    private func addDays(_ n: Int, to date: Date) -> Date {
        utcCalendar.date(byAdding: .day, value: n, to: date) ?? date
    }
}
