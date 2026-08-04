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

    /// **`.loading` is only for a FIRST load** — identical to `DashboardViewModel.load`,
    /// and for the identical reason: blanking the month grid before the database has been
    /// asked anything leaves a cancelled load with no previous state to return to. See
    /// the note there; the two are meant to read the same.
    func load(backend: BackendClient, now: Date = Date()) async {
        #if DEBUG
        t05Entered += 1
        #endif
        if loaded == nil { state = .loading }
        selectedDay = startOfDay(now)
        do {
            #if DEBUG
            t05Requested += 1
            #endif
            async let dosagesT = backend.savedDosages()
            let since = dpFormatDay(addDays(-1, to: now))
            async let pinsT = backend.doseLog(since: since)
            let (dosages, pins) = try await (dosagesT, pinsT)
            #if DEBUG
            t05Returned += 1
            #endif

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
            #if DEBUG
            // T-05, THE LAST UNANSWERED HALF. Windows measured ZERO queries executed in
            // Postgres across the pull window on a database whose ambient rate was
            // proven to be zero — but `pg_stat_statements` records statements that RAN,
            // so it cannot separate "no request was ever made" from "a request was made
            // and died before PostgREST ran one". This counter is the difference.
            //
            // AND THIS `catch` IS THE PRIME SUSPECT, by its own comment: *"a cancelled
            // load surfaces NOTHING and touches NO state"*. A cancelled `Task` makes the
            // `async let` pair throw `CancellationError`, `LoadFailure.message` returns
            // nil for it by design, and the whole failure is swallowed — no state
            // change, no banner, nothing on screen. That is EXACTLY the shape of every
            // observation: the closure runs, the counter increments, no statement
            // executes, and the user sees a spinner return with stale data.
            //
            // If `threw` moves while `returned` does not, the pull IS reaching the
            // network layer and being cancelled — candidate (C), `reload()` mutating
            // `visibleMonth` (@State) before its await, which the Dashboard does not do.
            t05Threw += 1
            t05LastError = String(describing: type(of: error)) + ":" + "\(error)".prefix(60)
            #endif
            // A cancelled load surfaces NOTHING and touches NO state — see LoadFailure.
            if let message = LoadFailure.message(error) { state = .failed(message) }
        }
    }

    // MARK: - T-05 instrumentation (DEBUG only, not compiled into Release)
    //
    // Four counters, because four different things can happen and the previous two
    // measurements could each only see one of them. `reloads` (in `CalendarScreen`)
    // proved the closure runs; Windows' database read proved no statement executed.
    // These sit between: did `load` start, did it reach the backend call, did that
    // call RETURN, or did it throw — and what.
    #if DEBUG
    @Published var t05Entered = 0
    @Published var t05Requested = 0
    @Published var t05Returned = 0
    @Published var t05Threw = 0
    @Published var t05LastError = ""
    #endif

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
