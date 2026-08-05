import XCTest

/// T-09, on the device — "The Calendar tells the user nothing is due when it has simply
/// not looked".
///
/// The unit tests (`T09CalendarWindowTests`) pin the schedule arithmetic. This pins that
/// it reaches the GRID: that a month three pages forward — always more than 30 days out,
/// so always past the window the old build stopped at — draws dose days, and still draws
/// empty days beside them.
///
/// ─── WHY BOTH HALVES ARE ASSERTED, AND WHY NEITHER IS A SCREENSHOT ────────────────
///
/// The defect was invisible BY CONSTRUCTION: an unprojected day and an empty day were
/// the same pixels. A photograph of the fixed screen therefore proves nothing on its own
/// — the reader cannot tell "these dots are real" from "this month happens to be busy",
/// and could not have told the broken month from a genuinely empty one either. What
/// makes this run mean something is that every day cell now carries its dose count as an
/// accessibility VALUE (`DayCell`), so the assertions read the grid's answer instead of
/// its appearance.
///
/// And "some day has doses" alone would pass on a build that painted a dot on every
/// cell, which is a worse defect than the one being fixed. So the far month is asserted
/// to contain BOTH kinds of day, by count.
///
/// FRAMES. Three, written into the runner's Documents directory and printed, for the
/// host to copy into `docs/ui-audit/`:
///   `t09-01-calendar-current-month.png`  the near month, the one that always worked
///   `t09-02-calendar-plus-3-months.png`  **THE TASK'S FRAME** — past the old window
///   `t09-03-calendar-far-day-agenda.png` a far dose day opened, showing a real dose
///
/// No blanket wipe in `setUp`: `XCTest` re-runs it before EVERY test method, so a
/// directory sweep there deletes the frames the previous method just took and the run
/// still reports green. Staleness is closed per NAME in `shot()`, immediately before the
/// file is rewritten. (That exact mistake is recorded in `T41PeptideDoseUnitUITests`.)
final class T09CalendarFarMonthUITests: XCTestCase {

    private var app: XCUIApplication!

    /// How many months forward this test pages. Three, because the FIRST day of the
    /// month three pages out is at minimum 59 days from today (a page from the end of a
    /// short month) — comfortably past the 30-day window, in every month of the year.
    private let pagesForward = 3

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this needs the signed-in app.")
    }

    // MARK: - harness

    private func shot(_ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)   // scoped staleness guard, this name only
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
        print("T09-FRAME: \(url.path)")
    }

    // ─── WHICH MONTH IS "NOW" — the T-82 distinction, on the test's side ─────────
    //
    // The app names today's day in the DEVICE's zone and then does its grid arithmetic
    // on the zone-free day-token frame (`dpDayToken`). This test cannot import those
    // helpers — a UI test bundle has no `@testable import` — so it reproduces the same
    // two steps: month components read in `.current`, then rendered on a UTC calendar.
    //
    // Reading the month in UTC instead would put this test a month out from the app for
    // the first hours of the 1st on a rig at UTC+12, and the failure would read as "the
    // calendar shows the wrong month" rather than "the test does".

    /// Year and month `offset` months from the month the DEVICE is currently in.
    private func yearMonth(offset: Int) -> (year: Int, month: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let parts = cal.dateComponents([.year, .month], from: Date())
        let total = (parts.year ?? 2026) * 12 + ((parts.month ?? 1) - 1) + offset
        return (total / 12, total % 12 + 1)
    }

    /// The first day of that month as a day TOKEN (00:00 UTC) — the frame `DayCell`
    /// builds its `day_YYYY-MM-DD` identifiers on.
    private func firstOfMonth(offset: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let ym = yearMonth(offset: offset)
        var comps = DateComponents()
        comps.year = ym.year; comps.month = ym.month; comps.day = 1
        return cal.date(from: comps) ?? Date()
    }

    /// The app's own header format — `MMMM yyyy` on a UTC calendar over the token.
    private func monthLabel(offset: Int) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: firstOfMonth(offset: offset))
    }

    /// The month half of a `day_` identifier.
    private func dayIdentifierPrefix(offset: Int) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-"
        return "day_" + f.string(from: firstOfMonth(offset: offset))
    }

    /// Today's LOCAL day, landed on the token frame — the same two steps as `dpDayToken`.
    private func todayToken() -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = .current
        let parts = local.dateComponents([.year, .month, .day], from: Date())
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        var comps = DateComponents()
        comps.year = parts.year; comps.month = parts.month; comps.day = parts.day
        return utc.date(from: comps) ?? Date()
    }

    /// `DayAgenda`'s header for a given `day_YYYY-MM-DD` identifier:
    /// `"Selected · EEE d MMM".uppercased()`, on the same UTC token frame.
    private func expectedAgendaHeader(forDayIdentifier id: String) -> String {
        let token = id.replacingOccurrences(of: "day_", with: "")
        let parse = DateFormatter()
        parse.calendar = Calendar(identifier: .gregorian)
        parse.locale = Locale(identifier: "en_US_POSIX")
        parse.timeZone = TimeZone(identifier: "UTC")
        parse.dateFormat = "yyyy-MM-dd"
        guard let date = parse.date(from: token) else { return "" }
        let show = DateFormatter()
        show.timeZone = TimeZone(identifier: "UTC")
        show.dateFormat = "EEE d MMM"
        return "Selected · \(show.string(from: date))".uppercased()
    }

    private func daysFromTodayToFirstOf(offset: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.dateComponents([.day],
                                  from: todayToken(),
                                  to: firstOfMonth(offset: offset)).day ?? 0
    }

    /// Calendar tab, ARRIVAL ASSERTED against this project's own enumerated proof for
    /// it (`CaptureCurrentState.ShellTab.calendar` → the Today button). A tap is not
    /// arrival, and every frame below would otherwise be a photograph of the dashboard
    /// under a filename claiming a calendar.
    private func goToCalendar() {
        let tabs = app.buttons.matching(identifier: "Calendar")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Calendar tab.")
        let lowest = tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "Calendar tab exists but nothing hittable.")
        lowest?.tap()
        XCTAssertTrue(app.buttons["Today"].firstMatch.waitForExistence(timeout: 20),
                      "Tapped Calendar and never arrived — no Today button.")
        XCTAssertTrue(app.staticTexts["calendar_month"].waitForExistence(timeout: 20),
                      "Arrived on the Calendar and the month grid never rendered.")
    }

    /// Every day cell of one month, as (identifier, value). The value is the cell's dose
    /// count — "0 doses" / "1 dose" / "N doses" — which is the grid's own answer to the
    /// question T-09 asks.
    private func dayCells(offset: Int) -> [(id: String, value: String)] {
        let prefix = dayIdentifierPrefix(offset: offset)
        let matches = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        return matches.allElementsBoundByIndex.compactMap { cell in
            let id = cell.identifier
            guard !id.isEmpty else { return nil }
            return (id, (cell.value as? String) ?? "")
        }
    }

    private func dueCells(_ cells: [(id: String, value: String)]) -> [(id: String, value: String)] {
        cells.filter { $0.value != "0 doses" && !$0.value.isEmpty }
    }

    /// Waits for the header to actually read `expected`. A chevron tap that did not land
    /// leaves the previous month on screen, and every assertion after it would be filed
    /// against the wrong month.
    private func waitForMonth(_ expected: String, timeout: TimeInterval = 10) {
        let header = app.staticTexts["calendar_month"]
        let predicate = NSPredicate(format: "label == %@", expected)
        let exp = expectation(for: predicate, evaluatedWith: header, handler: nil)
        let result = XCTWaiter.wait(for: [exp], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "The grid never reached \(expected) — it reads \"\(header.label)\".")
    }

    // MARK: - THE TEST

    func testAMonthPastTheOldThirtyDayWindowShowsRealDoseDays() {
        goToCalendar()

        // ─── PRECONDITION, ASSERTED, NOT ASSUMED ─────────────────────────────────
        // An account with no protocols renders the empty state, and then "no dose days
        // three months out" would be the correct answer rather than the defect. This
        // measurement must not be able to report a pass OR a fail on that account.
        XCTAssertFalse(app.staticTexts["Nothing scheduled"].exists,
                       "This account has no protocols — T-09 cannot be observed on it. "
                       + "Run against the QA account.")

        waitForMonth(monthLabel(offset: 0))
        let nearCells = dayCells(offset: 0)
        XCTAssertGreaterThanOrEqual(nearCells.count, 28,
                                    "The current month rendered \(nearCells.count) day cells.")
        let nearDue = dueCells(nearCells)
        XCTAssertFalse(nearDue.isEmpty,
                       "No dose day in the CURRENT month either — this is not the T-09 "
                       + "defect, it is an account or a load failure, and the far-month "
                       + "result below would mean nothing.")
        shot("t09-01-calendar-current-month.png")

        // ─── PAGE PAST THE OLD WINDOW ────────────────────────────────────────────
        let distance = daysFromTodayToFirstOf(offset: pagesForward)
        XCTAssertGreaterThan(distance, 30,
                             "The target month starts \(distance) days out, which is INSIDE "
                             + "the old 30-day window — this run cannot see the defect.")

        let next = app.buttons["calendar_next_month"]
        for step in 1...pagesForward {
            XCTAssertTrue(next.waitForExistence(timeout: 6), "No next-month control.")
            XCTAssertTrue(next.isEnabled,
                          "The next-month chevron is disabled \(step - 1) pages out; the web "
                          + "renders five months forward.")
            next.tap()
            waitForMonth(monthLabel(offset: step))
        }

        // ─── THE MEASUREMENT ─────────────────────────────────────────────────────
        let farCells = dayCells(offset: pagesForward)
        let farDue = dueCells(farCells)
        let farEmpty = farCells.filter { $0.value == "0 doses" }

        print("""

        ===== T-09: \(monthLabel(offset: pagesForward)) =====
        first day of month is \(distance) days out (old window: 30)
        day cells rendered:   \(farCells.count)
        days with a dose:     \(farDue.count)  \(farDue.map(\.id).joined(separator: " "))
        days with none:       \(farEmpty.count)
        ==========================================

        """)

        XCTAssertGreaterThanOrEqual(farCells.count, 28,
                                    "Only \(farCells.count) day cells three months out — the "
                                    + "grid did not render the month, so nothing below is about T-09.")

        // THE DEFECT, INVERTED. Before this fix every cell in this month read "0 doses".
        XCTAssertFalse(farDue.isEmpty,
                       "Every day of \(monthLabel(offset: pagesForward)) reads \"0 doses\" while "
                       + "the current month has \(nearDue.count) dose days. That is the T-09 "
                       + "defect: the calendar answering \"nothing is due\" for days it never "
                       + "looked at.")

        // AND THE OTHER HALF — without this, painting a dot on every cell would pass.
        XCTAssertFalse(farEmpty.isEmpty,
                       "EVERY day of \(monthLabel(offset: pagesForward)) carries a dose. A dot on "
                       + "every cell is not a fix — it tells the user they are due every day.")

        shot("t09-02-calendar-plus-3-months.png")

        // ─── A FAR DOSE DAY IS A REAL DOSE, NOT A STRAY DOT ──────────────────────
        // The dots would be worthless if the day behind them had no agenda: the user
        // taps a marked day to see WHAT is due, and a marked day with an empty agenda is
        // a third way of saying nothing.
        guard let target = farDue.first else { return }   // already failed above
        let cell = app.buttons[target.id]
        XCTAssertTrue(cell.waitForExistence(timeout: 6), "\(target.id) vanished between reads.")
        cell.tap()

        let agenda = app.staticTexts["agenda_header"]
        XCTAssertTrue(agenda.waitForExistence(timeout: 8), "No agenda header after tapping a day.")
        // Full equality, not "contains the day number": `contains("7")` is satisfied by
        // the 17th and the 27th, and an agenda showing the wrong day is precisely the
        // failure this assertion exists to catch.
        XCTAssertEqual(agenda.label, expectedAgendaHeader(forDayIdentifier: target.id),
                       "The agenda reads \"\(agenda.label)\" after tapping \(target.id) — it is "
                       + "showing a different day than the one about to be photographed.")
        XCTAssertFalse(app.staticTexts["No doses scheduled"].exists,
                       "\(target.id) is marked with \(target.value) on the grid and its agenda "
                       + "says nothing is scheduled — the grid and the agenda disagree.")

        shot("t09-03-calendar-far-day-agenda.png")
    }

    /// The rendering bound is the web's — one month back, five forward
    /// (`CalendarView.tsx:311-320`). Asserted at both ends, because a bound that is only
    /// asserted in the middle is not asserted.
    ///
    /// This matters beyond parity: the pin fetch is sized from the SAME constant, so a
    /// chevron that pages past it would show a month whose taken-state was never
    /// fetched — every logged dose there rendering untaken. Separate test because it is
    /// a separate claim, and a failure here should not obscure the one above.
    func testPagingStopsAtTheMonthsTheWebRenders() {
        goToCalendar()
        waitForMonth(monthLabel(offset: 0))

        let next = app.buttons["calendar_next_month"]
        let prev = app.buttons["calendar_prev_month"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "No next-month control.")
        XCTAssertTrue(prev.waitForExistence(timeout: 8), "No previous-month control.")

        // Five forward, all reachable; the sixth is not.
        for step in 1...5 {
            XCTAssertTrue(next.isEnabled, "Next disabled at +\(step - 1); the web reaches +5.")
            next.tap()
            waitForMonth(monthLabel(offset: step))
        }
        XCTAssertFalse(next.isEnabled,
                       "The grid pages past +5 months. Beyond it the taken-state pins were "
                       + "never fetched, so logged doses would render untaken.")

        // Back to today, then one month back — and no further.
        let today = app.buttons["Today"]
        XCTAssertTrue(today.waitForExistence(timeout: 6))
        today.tap()
        waitForMonth(monthLabel(offset: 0))

        XCTAssertTrue(prev.isEnabled, "Cannot page back at all; the web renders one month back.")
        prev.tap()
        waitForMonth(monthLabel(offset: -1))
        XCTAssertFalse(prev.isEnabled,
                       "The grid pages back past -1 month, beyond the pins that were fetched.")

        // The month BACK is answered too — the old build projected only forward from
        // today, so a user paging back saw the same false "nothing was due".
        //
        // ASSERTED: every cell carries a dose count. REPORTED, not asserted: how many
        // are dose days. A QA account whose protocols all started this month would have
        // a legitimately empty previous month, and a test that failed on that would be
        // reporting the account rather than the app.
        let backCells = dayCells(offset: -1)
        XCTAssertGreaterThanOrEqual(backCells.count, 28,
                                    "Only \(backCells.count) cells in the previous month.")
        XCTAssertTrue(backCells.allSatisfy { !$0.value.isEmpty },
                      "A cell in the previous month carries no dose count at all — the grid "
                      + "rendered a day it did not answer, which is the T-09 shape.")
        print("T09 PREVIOUS MONTH \(monthLabel(offset: -1)): "
              + "\(dueCells(backCells).count) of \(backCells.count) days carry a dose.")
        shot("t09-04-calendar-previous-month.png")
    }
}
