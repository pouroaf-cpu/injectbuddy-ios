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

    /// A failed WRITE on an already-loaded calendar. Deliberately NOT `state`:
    /// CalendarScreen renders `.failed` as a full-screen banner or the offline screen,
    /// so pushing a toggle failure through it would take the month grid away from a
    /// user who only tapped one dose. Rendered as an `InlineErrorNote` by the loaded
    /// branch of CalendarScreen — the branch that is actually on screen when this is set.
    @Published var actionError: String?

    /// "protocolId@YYYY-MM-DD" of the toggle currently in flight, so the agenda row can
    /// show a spinner and a second tap on it is ignored. The taken tick no longer moves
    /// before the database answers, so this is the only in-flight feedback there is.
    @Published var pendingKey: String?

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

    /// Toggle a projected dose between taken and not-taken. Writes FIRST, then moves the
    /// tick to match what the database did.
    ///
    /// Was optimistic: the tick moved before the await and a silent `catch` moved it
    /// back. Against a write that could not succeed the row ticked, unticked, and told
    /// the user nothing — and a tick on this screen is the user's record of having
    /// injected. `logDose` returns the written row and `unlogDose` throws
    /// `BackendWriteError.wroteNothing` when the DELETE removed none, so reaching the
    /// commit below means a row really changed.
    func toggleTaken(_ occ: DoseOccurrence, backend: BackendClient) async {
        guard let data = loaded, pendingKey == nil else { return }
        let key = "\(occ.protocolId)@\(occ.dayKey)"
        let wasTaken = data.takenKeys.contains(key)

        pendingKey = key
        actionError = nil
        defer { pendingKey = nil }

        do {
            let writtenKey: String
            if wasTaken {
                try await backend.unlogDose(protocolId: occ.protocolId, dosedOn: occ.dayKey)
                writtenKey = key
            } else {
                let row = try await backend.logDose(NewDoseLogPin(for: occ))
                // Key off the row the database returned, not off the tapped occurrence.
                writtenKey = "\(row.protocolId)@\(row.dosedOn)"
            }
            // Re-read: a reload may have replaced the model during the await, and
            // committing into the captured copy would resurrect the stale one.
            guard var fresh = loaded else { return }
            if wasTaken { fresh.takenKeys.remove(writtenKey) } else { fresh.takenKeys.insert(writtenKey) }
            loaded = fresh
            state = .loaded(fresh)
        } catch {
            let verb = wasTaken ? "un-logged" : "logged"
            actionError = "That dose was not \(verb). "
                + ((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
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
