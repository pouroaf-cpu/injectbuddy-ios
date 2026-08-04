import Foundation

// ─── CalendarViewModel ───────────────────────────────────────────────────────
// Loads protocols + dose-log pins, then exposes:
//   • the active protocols reduced to a SCHEDULE each, answered per date
//   • the agenda for a selected day
//   • taken-state per occurrence (matched against dose_log)
// Toggling a dose taken/untaken writes first, then moves the tick. Renders off a
// single LoadState.
//
// ─── T-09: THERE IS NO PROJECTION WINDOW ON THIS SCREEN, AND THAT IS THE FIX ──
//
// This screen used to hold a 30-day series built by `DoseProjection.projectedDoses`
// while the grid rendered whole months. A day past day 30 drew with NO DOTS — and a
// day with no dots is exactly how the grid says "nothing is scheduled". So the
// calendar answered "is anything due?" with "no" on every day it had simply not
// looked at. On a dosing screen that is not a missing feature, it is a wrong answer:
// a user planning a month ahead was told their schedule was empty.
//
// The honest fix is not a bigger number. Widening the window to cover the grid leaves
// the same class of bug one page-turn further out, because a window and a grid are two
// independent bounds that must be kept in agreement by hand — and nothing in the type
// system makes them agree.
//
// THE WEB CANNOT HAVE THIS BUG, and it is worth saying why rather than just copying
// the shape. Its primitive is a pure per-date predicate — `isDoseDay(p, date)` in
// `lib/account-schedule.ts:428-437`, with `eventsForDay` at `:439-441` — which takes a
// protocol and A DATE and returns a boolean. There is no series, no accumulator, no
// step budget and no window, so "did we project far enough?" cannot be asked. The
// months it renders (`components/calendar/CalendarView.tsx:311-320`, one back and five
// forward) are a RENDERING choice with no scheduling consequence at all.
//
// `ScheduledProtocol` below is that primitive in Swift. Every day the grid draws is
// answered by asking the schedule about that day, so "no dots" now means "nothing is
// due" for every day that can appear on screen — there is no second state left for it
// to be confused with.
//
// It also removes the step budget from this screen's path, which is the mechanism
// behind T-81 (an iteration cap compared against a dose ordinal). A predicate has no
// iteration to cap.
//
// **`DoseProjection.projectedDoses` is untouched and still correct for its caller** —
// the dashboard genuinely wants "the next N days of doses, in order", which is a
// series question. It is the calendar that was asking a per-date question through a
// series API.
//
// PLACEMENT, AND IT IS A KNOWN DEBT: `ScheduledProtocol` and `CalendarWindow` belong
// beside `DoseProjection` in Core/Calendar — a scheduling primitive is not a Calendar-
// feature detail, and the dashboard's "next dose" is the same question asked over a
// range. They are in this feature file only because Core/Calendar was owned by another
// agent (T-82) while this was written. Moving them is a pure file move; it was not done
// here so that one file keeps one owner per change.

// MARK: - The per-date schedule primitive

/// One active protocol reduced to what a calendar needs: its cadence, its anchor, and
/// what one injection of it IS. Derived once per load, then asked about a date.
///
/// The derivation that is expensive — `DoseVolume.perInjection` re-runs the calculator
/// engine — happens here, once per protocol, exactly as `projectedDoses` does it once
/// per protocol rather than once per day. What is left is integer day arithmetic, so
/// asking about a day costs nothing and no caller has to decide how many days to ask
/// about in advance.
struct ScheduledProtocol: Equatable, Identifiable {
    let id: String
    let slug: CalculatorSlug?
    let label: String
    /// 00:00 UTC on the protocol's `start_date`.
    let startDay: Date
    /// Days between injections. May be fractional (3.5 for twice-weekly).
    let intervalDays: Double
    let drawMl: Double?
    let dose: DoseAmount?
    let snapshot: DoseSnapshot

    /// Nil for a row that has no injection schedule to put on a calendar: inactive,
    /// a calculator with no cadence (bmi / free-T / reconstitution / plotter), or an
    /// unparseable `start_date`. Same three exclusions `projectedDoses` applies, in
    /// the same order — a row it would skip is a row this returns nil for.
    init?(_ dosage: SavedDosage) {
        guard dosage.isActive,
              let interval = DoseProjection.injectionIntervalDays(for: dosage), interval > 0,
              let start = dpParseDay(dosage.startDate)
        else { return nil }

        let slug = CalculatorSlug(rawValue: dosage.calculatorType)
        let perInjection = DoseVolume.perInjection(for: dosage)

        self.id = dosage.id
        self.slug = slug
        self.label = dosage.label ?? slug?.shortTitle ?? dosage.calculatorType
        self.startDay = CalendarWindow.utc.startOfDay(for: start)
        self.intervalDays = interval
        self.drawMl = perInjection.ml
        self.dose = perInjection.dose
        self.snapshot = DoseSnapshot(for: dosage)
    }

    /// **THE PREDICATE.** Is a dose of this protocol due on `day`? Pure, total, and
    /// defined for every date — there is no range outside which it stops answering.
    ///
    /// It reproduces `projectedDoses`' day set EXACTLY rather than approximating it,
    /// and the equality is by construction rather than by argument. That loop emits day
    /// `Int(Double(step) * interval)` for `step = 0, 1, 2, …`, so a day `d` is a dose
    /// day iff some non-negative integer `step` satisfies `Int(Double(step) * interval)
    /// == d`. Since the expression is monotonic in `step`, the only candidates are the
    /// integers around `d / interval` — and the check below is the emitter's own
    /// expression, character for character, so a floating-point quirk in one is a
    /// floating-point quirk in the other. (A BAND of candidates is swept rather than a
    /// single rounding, so a `7.000000000000001` cannot put the answer one step out.)
    ///
    /// **This deliberately keeps iOS's FLOOR spacing (0,3,7,10,14 for E3.5D) and does
    /// not adopt the web's rounding (0,4,7,11,14 — `isDoseDay` rounds `d / f` and
    /// re-multiplies).** The two clients disagree about which days a fractional cadence
    /// lands on. That is a real difference and it is NOT T-09's: T-09 is that days were
    /// not answered at all. Changing the spacing here would move every twice-weekly
    /// dose day in the same commit that fixes coverage, and no later reader could tell
    /// which change did what.
    func isDoseDay(_ day: Date) -> Bool {
        guard let elapsed = CalendarWindow.wholeDays(from: startDay, to: day), elapsed >= 0
        else { return false }
        let approx = Double(elapsed) / intervalDays
        // The candidate band. A step that emits day `d` satisfies `d ≤ step × interval
        // < d + 1`, so `step` lies within `1 / interval` of `d / interval` — which is
        // ONE step for a cadence of a day or more, and more than one for a sub-daily
        // cadence (`injPerWeek > 7` gives an interval below 1, where several steps land
        // on the same day). Sized from the interval rather than fixed at ±1 so the
        // sub-daily case cannot fall out of the band and read as "not due".
        let reach = max(2, Int((1.0 / intervalDays).rounded(.up)) + 1)
        var step = max(0, Int(approx.rounded(.down)) - 1)
        let last = Int(approx.rounded(.up)) + reach
        while step <= last {
            if Int(Double(step) * intervalDays) == elapsed { return true }
            step += 1
        }
        return false
    }

    /// The occurrence on `day`, or nil if nothing is due. Field-for-field what
    /// `projectedDoses` would have emitted for that day.
    func occurrence(on day: Date) -> DoseOccurrence? {
        guard isDoseDay(day) else { return nil }
        return DoseOccurrence(date: CalendarWindow.utc.startOfDay(for: day),
                              protocolId: id,
                              slug: slug,
                              label: label,
                              drawMl: drawMl,
                              dose: dose,
                              snapshot: snapshot)
    }
}

// MARK: - What the grid may render

/// The span of months the calendar can page to, and the UTC day arithmetic shared by
/// the schedule and the screen.
///
/// **The months are the web's, read from its source:** `CalendarView.tsx:311-320`
/// builds its month list as `for (let i = -1; i <= 5; i++)` — one month back, five
/// forward, seven in all. iOS's chevrons used to page without limit, which sounds like
/// more but was not: every month past day 30 was drawn blank, so the extra reach only
/// produced more of the wrong answer.
///
/// This bound is a RENDERING bound and nothing else. The schedule above answers any
/// date; this only says which dates a user can put on screen. It exists so the pin
/// fetch below can be stated honestly — see `CalendarViewModel.load`.
enum CalendarWindow {
    /// `i = -1` in the web's loop.
    static let monthsBack = 1
    /// `i <= 5` in the web's loop.
    static let monthsForward = 5

    /// The TOKEN frame's calendar. UTC here is not a claim about anybody's day — it is
    /// the fixed anchor a zone-less calendar day is carried on, exactly as
    /// `DoseDateFormat.dayFormatter` is. Nothing that turns a real INSTANT into a day
    /// may use it; `dpDayToken` / `dpLocalDay` do that.
    ///
    /// A `let`, not a computed `var`: `isDoseDay` runs once per schedule per rendered
    /// cell — forty-two cells times a user's protocols on every grid pass — and building
    /// a `Calendar` each time is the one place this design could cost more than the
    /// series it replaced.
    static let utc: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Whole days between two calendar days in UTC. Nil only on a degenerate date.
    static func wholeDays(from: Date, to: Date) -> Int? {
        let cal = utc
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: from),
                                  to: cal.startOfDay(for: to)).day
    }

    /// The first day of the month `offset` months from the month containing `date`.
    static func firstOfMonth(offset: Int, from date: Date) -> Date {
        let cal = utc
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let first = cal.date(from: comps),
              let shifted = cal.date(byAdding: .month, value: offset, to: first)
        else { return cal.startOfDay(for: date) }
        return shifted
    }

    /// How many months `date`'s month is from `reference`'s month. The value the
    /// chevrons clamp against.
    static func monthOffset(of date: Date, from reference: Date) -> Int {
        let cal = utc
        let a = cal.dateComponents([.year, .month], from: reference)
        let b = cal.dateComponents([.year, .month], from: date)
        guard let ay = a.year, let am = a.month, let by = b.year, let bm = b.month
        else { return 0 }
        return (by - ay) * 12 + (bm - am)
    }

    /// Offsets the grid is allowed to show, `-1...5`.
    static var offsets: ClosedRange<Int> { -monthsBack...monthsForward }

    /// Is this grid cell today's?
    ///
    /// **A function rather than the one-liner it replaces, so the zone can be injected.**
    /// It stood in `DayCell` as `dpFormatDay(day) == dpFormatDay(Date())` — the exact
    /// call T-82's note forbids, since it asks the zone-less TOKEN formatter which day an
    /// INSTANT falls on. East of UTC that rings yesterday's cell every morning. Pulled
    /// out here because a comparison hard-coded inside a `View` body cannot be tested at
    /// any zone but the machine's, and "only passes in Auckland" is not a test.
    ///
    /// - Parameters:
    ///   - token: a grid day, already on the token frame.
    ///   - now:   the instant to call "now".
    ///   - zone:  the zone that names the day — the viewer's, by default.
    static func isToday(_ token: Date, now: Date = Date(), in zone: TimeZone = .current) -> Bool {
        dpFormatDay(token) == dpLocalDay(now, in: zone)
    }
}

// MARK: - Display model

/// The active schedules, plus the pins to test "taken".
///
/// It holds SCHEDULES, not a pre-built list of days — see the T-09 note at the top of
/// this file. `occurrences(on:)` is the only way to ask what is due, and it can be
/// asked about any date the grid draws.
struct CalendarData: Equatable {
    /// One per active protocol that has an injection schedule.
    var schedules: [ScheduledProtocol]
    /// Set of "protocolId@YYYY-MM-DD" that are logged as taken.
    var takenKeys: Set<String>

    func occurrences(on day: Date) -> [DoseOccurrence] {
        schedules.compactMap { $0.occurrence(on: day) }
    }
    func isTaken(_ occ: DoseOccurrence) -> Bool {
        takenKeys.contains("\(occ.protocolId)@\(occ.dayKey)")
    }
    /// Whether the user has anything that CAN be scheduled. Not "are there doses in
    /// some window" — that question no longer exists here, and it was the question
    /// that put the empty state in front of a user whose protocol simply started in
    /// five weeks.
    var hasAnySchedule: Bool { !schedules.isEmpty }
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

    /// **`.loading` is only for a FIRST load** — identical to `DashboardViewModel.load`,
    /// and for the identical reason: blanking the month grid before the database has been
    /// asked anything leaves a cancelled load with no previous state to return to. See
    /// the note there; the two are meant to read the same.
    ///
    /// - Parameter zone: the zone that NAMES the day. Defaults to the device's; it is a
    ///   parameter for the reason `DoseProjection` made it one — a test that can only
    ///   pin "the morning east of UTC" by setting the machine to Auckland is not a test.
    func load(backend: BackendClient, now: Date = Date(), zone: TimeZone = .current) async {
        #if DEBUG
        t05Entered += 1
        #endif
        if loaded == nil { state = .loading }
        // ─── T-82's frame, not a UTC `startOfDay` ────────────────────────────────
        // `now` is an INSTANT, and the day it falls on is the one the person holding the
        // phone would name. The old line read it on the token frame's UTC calendar, so
        // east of UTC it selected YESTERDAY for the first twelve hours of every day.
        //
        // That is not only a wrong highlight. The agenda is built from `selectedDay`, and
        // a tap on a row in it writes `dose_log.dosed_on` from the occurrence's own day —
        // so on an Auckland morning the user opened "today", saw yesterday's doses, and a
        // tick recorded the injection under yesterday's date. `dpDayToken` asks locally
        // and hands back a token, so the grid arithmetic below stays zone-free.
        selectedDay = dpDayToken(now, in: zone)
        do {
            #if DEBUG
            t05Requested += 1
            #endif
            async let dosagesT = backend.savedDosages()
            // **T-09 COROLLARY, and it is not optional.** This used to fetch pins from
            // YESTERDAY, which was consistent while the grid only ever drew dots from
            // today forward. Now that every rendered day is answered, a user paging back
            // sees the past month's dose days — and with a one-day pin fetch every one of
            // them would render UNTAKEN. That is the same lie this task is about, moved
            // one screen back: a dose the user logged and the database holds, shown as
            // not done. So the pins cover exactly what the grid can reach into the past
            // (`CalendarWindow.monthsBack`), and the two are stated from the same
            // constant rather than from two numbers that have to be kept equal by hand.
            // `dpDayToken` first, for the same reason as `selectedDay` above: `now` is an
            // instant and this has to be the month the USER is in.
            let since = dpFormatDay(
                CalendarWindow.firstOfMonth(offset: -CalendarWindow.monthsBack,
                                            from: dpDayToken(now, in: zone))
            )
            async let pinsT = backend.doseLog(since: since)
            let (dosages, pins) = try await (dosagesT, pinsT)
            #if DEBUG
            t05Returned += 1
            #endif

            let schedules = dosages.compactMap(ScheduledProtocol.init)

            // `.empty` now means "you have nothing that CAN be scheduled", not "nothing
            // falls in the next 30 days". The old test put the "Add a protocol" empty
            // state in front of users who had one — anyone whose only protocol starts
            // further out than the window reached, or whose cadence is longer than it.
            if schedules.isEmpty {
                loaded = nil
                state = .empty
                return
            }

            let data = CalendarData(
                schedules: schedules,
                takenKeys: Set(pins.map { "\($0.protocolId)@\($0.dosedOn)" })
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

}
