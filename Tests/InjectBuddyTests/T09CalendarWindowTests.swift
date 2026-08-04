import XCTest
@testable import InjectBuddy

/// T-09 — "The Calendar tells the user nothing is due when it has simply not looked".
///
/// THE DEFECT, precisely: the calendar built a 30-day dose SERIES while the grid drew
/// whole months. Past day 30 a cell had no dots — which is the same cell the grid draws
/// for a day with nothing scheduled. So the screen answered "is anything due?" with
/// "no" on days it had never asked about.
///
/// THE FIX is not a bigger window. `CalendarViewModel` now holds `ScheduledProtocol`s
/// and answers PER DATE, the shape the web has had all along (`isDoseDay(p, date)` in
/// `lib/account-schedule.ts:428`). A predicate has no far end, so "did we look far
/// enough" cannot be asked.
///
/// ─── WHAT THESE TESTS HAVE TO PIN, AND WHY IT IS TWO THINGS ───────────────────────
///
/// A test that only checks "more days have dots now" passes on a fix that paints dots
/// on every day — which would be a WORSE bug than the one being fixed, because it puts
/// a dose on a day the user is not due one. So every coverage assertion below is paired
/// with an emptiness assertion at the same distance: a far-out day that IS due, and a
/// far-out day that is NOT, both asserted by name.
///
/// The equivalence tests are the other half. They compare the predicate against
/// `DoseProjection.projectedDoses` day for day over 400 days, so this change can be read
/// as what it is — the SAME dose days, answered without a window — rather than as a
/// change to which days a user injects on.
final class T09CalendarWindowTests: XCTestCase {

    // MARK: helpers

    /// Every `from:` here is a day TOKEN (00:00 UTC), not a moment, so UTC is the zone
    /// that reproduces the intended day for it — and it is passed explicitly for the
    /// reason `DoseProjectionTests` gives after T-82: left to `.current`, a machine in
    /// Los Angeles reads a 00:00 UTC token as the PREVIOUS day and every control series
    /// below would start a day early.
    private let utc = TimeZone(identifier: "UTC")!
    private let auckland = TimeZone(identifier: "Pacific/Auckland")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// A real INSTANT: `y-m-d h:mm` as read in `zone`. Not a day token — the whole point
    /// of the day-frame tests is that the two are different things.
    private func moment(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int,
                        in zone: TimeZone) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        guard let date = cal.date(from: c) else { XCTFail("bad test moment"); return Date() }
        return date
    }

    private func utcDay(_ string: String) -> Date {
        guard let d = dpParseDay(string) else { XCTFail("bad test date \(string)"); return Date() }
        return d
    }

    private func makeDosage(
        id: String = "p",
        type: String,
        startDate: String = "2026-06-01",
        config: String = "{}",
        active: Bool = true,
        label: String? = nil
    ) -> SavedDosage {
        let labelJSON = label.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":\(labelJSON),"config":\(config),"start_date":"\(startDate)","is_active":\(active)}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    private func schedule(_ dosage: SavedDosage, file: StaticString = #filePath, line: UInt = #line) -> ScheduledProtocol {
        guard let s = ScheduledProtocol(dosage) else {
            XCTFail("expected a schedule for \(dosage.calculatorType)", file: file, line: line)
            fatalError("unreachable")
        }
        return s
    }

    /// Every day in `[from, from + days)`, as UTC day starts.
    private func days(from: Date, count: Int) -> [Date] {
        let cal = CalendarWindow.utc
        return (0..<count).compactMap { cal.date(byAdding: .day, value: $0, to: from) }
    }

    // MARK: - THE DEFECT, and its inversion

    /// The 30-day window, stated as a fact rather than assumed — so that if someone
    /// later "fixes" T-09 by widening the number, this test still says what the old
    /// behaviour was and the next one says why widening is not enough.
    func testTheOldWindowGenuinelyStoppedAtThirtyDays() {
        let weekly = makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#)
        let series = DoseProjection.projectedDoses(for: [weekly], from: utcDay("2026-06-01"),
                                                   days: 30, in: utc)

        // Five doses, none of them past June — the entire visible autumn was silent.
        XCTAssertEqual(series.map(\.dayKey),
                       ["2026-06-01", "2026-06-08", "2026-06-15", "2026-06-22", "2026-06-29"])
        XCTAssertFalse(series.contains { $0.dayKey >= "2026-07-01" },
                       "the old series reached past its window — the premise of T-09 is wrong")
    }

    /// **THE TASK'S OWN QUESTION.** A day past the old window is now answered, and
    /// answered TRUE where a dose is genuinely due.
    func testADayPastTheOldWindowIsProjected() {
        let weekly = schedule(makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#))

        // 2026-09-07 is 98 days after the start — exactly 14 weeks, and 68 days past
        // the last day the old window ever reached.
        XCTAssertEqual(CalendarWindow.wholeDays(from: utcDay("2026-06-01"), to: utcDay("2026-09-07")), 98)
        XCTAssertTrue(weekly.isDoseDay(utcDay("2026-09-07")),
                      "a dose 98 days out is still not answered — this IS the T-09 defect")

        // And far beyond any window anyone would think to type: 2027-06-01 is 365 days
        // out, 52 weeks + 1 day, so it is NOT a dose day; 2027-05-31 (364 = 52 weeks) is.
        XCTAssertTrue(weekly.isDoseDay(utcDay("2027-05-31")))
        XCTAssertFalse(weekly.isDoseDay(utcDay("2027-06-01")))
    }

    /// **THE OTHER HALF, AND THE ONE THAT MAKES THE FIRST MEAN ANYTHING.** At the same
    /// distance where coverage is asserted, emptiness is asserted too. A fix that put a
    /// dot on every cell would satisfy the test above and fail this one.
    func testAGenuinelyEmptyDayPastTheOldWindowIsStillEmpty() {
        let weekly = schedule(makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#))

        // September 2026 in full: 30 days, three months past the old window's end.
        let september = days(from: utcDay("2026-09-01"), count: 30)
        let due = september.filter { weekly.isDoseDay($0) }.map(dpFormatDay)
        let notDue = september.filter { !weekly.isDoseDay($0) }

        XCTAssertEqual(due, ["2026-09-07", "2026-09-14", "2026-09-21", "2026-09-28"],
                       "the dose days in a far-out month are not the weekly ones")
        XCTAssertEqual(notDue.count, 26,
                       "26 of September's days carry no dose and must stay empty — a fix "
                       + "that marks every day is worse than the defect it replaces")
    }

    /// The same pairing on a fractional cadence, because 3.5 is the interval most of
    /// this app's real users are on (twice-weekly TRT) and it is where an off-by-one in
    /// the predicate would hide.
    func testTwiceWeeklyFarOutIsDenseButNotContinuous() {
        let trt = schedule(makeDosage(type: "trt", startDate: "2026-06-01",
                                      config: #"{"strength":250,"mgWeek":100,"injPerWeek":2,"mode":"perweek"}"#))
        let september = days(from: utcDay("2026-09-01"), count: 30)
        let due = september.filter { trt.isDoseDay($0) }

        XCTAssertGreaterThan(due.count, 6, "a twice-weekly protocol is due ~8 times a month")
        XCTAssertLessThan(due.count, 12, "a twice-weekly protocol is not due most days")
        XCTAssertEqual(due.count + september.filter { !trt.isDoseDay($0) }.count, 30)
    }

    // MARK: - Equivalence: the same dose days, without the window

    /// **THE DOSE DAYS DID NOT MOVE.** For every cadence this app derives, the predicate
    /// agrees with `DoseProjection.projectedDoses` on every one of 400 days — inside the
    /// old window and long past it. This is what makes the change readable as "the same
    /// schedule, answered per date" rather than as a silent reschedule.
    func testPredicateMatchesTheSeriesDayForDayOver400Days() {
        let cases: [(String, String, String)] = [
            ("weekly",        "semaglutide", #"{"dose":0.5}"#),
            ("twice-weekly",  "trt",         #"{"mode":"perweek","nDays":3.5,"mgWeek":149,"mlDrawn":0.5,"strength":200,"esterType":"Testosterone Enanthate","syringeMl":1,"injPerWeek":2}"#),
            ("EOD",           "eod",         "{}"),
            ("every 3 days",  "peptide",     #"{"nDays":3}"#),
            ("daily",         "bpc157",      #"{"mode":"daily","dose":250,"vialMg":5,"bawMl":2}"#),
            ("3x/week",       "peptide",     #"{"injPerWeek":3}"#),   // 2.333…, the ugly one
            ("5x/week",       "peptide",     #"{"injPerWeek":5}"#),   // 1.4
            // Sub-daily: the interval drops below 1, several steps land on one day, and
            // the candidate band in `isDoseDay` has to widen or the day reads "not due".
            // Rare in production; included because the code has a branch for it.
            ("twice daily",   "peptide",     #"{"injPerWeek":14}"#),  // 0.5
        ]

        for (name, type, config) in cases {
            let dosage = makeDosage(type: type, startDate: "2026-06-01", config: config)
            let sched = schedule(dosage)
            let start = utcDay("2026-06-01")
            let series = Set(DoseProjection.projectedDoses(for: [dosage], from: start, days: 400, in: utc)
                                .map(\.dayKey))

            for day in days(from: start, count: 400) {
                XCTAssertEqual(sched.isDoseDay(day), series.contains(dpFormatDay(day)),
                               "\(name): the predicate and the series disagree on \(dpFormatDay(day))")
            }
        }
    }

    /// The same equivalence when the protocol started long BEFORE the range asked about
    /// — the path the old series handled by fast-forwarding, and the one a per-date
    /// predicate has no equivalent of. It must still land on the same days.
    func testPredicateMatchesTheSeriesForAProtocolThatStartedLongAgo() {
        let dosage = makeDosage(type: "trt", startDate: "2025-01-15",
                                config: #"{"strength":200,"mgWeek":140,"injPerWeek":2,"mode":"perweek"}"#)
        let sched = schedule(dosage)
        let from = utcDay("2026-06-01")
        let series = Set(DoseProjection.projectedDoses(for: [dosage], from: from, days: 200, in: utc).map(\.dayKey))

        for day in days(from: from, count: 200) {
            XCTAssertEqual(sched.isDoseDay(day), series.contains(dpFormatDay(day)),
                           "disagreement on \(dpFormatDay(day)) for a protocol started in 2025")
        }
        XCTAssertFalse(series.isEmpty, "the control series is empty — the comparison proves nothing")
    }

    func testNothingIsDueBeforeTheProtocolStarts() {
        let weekly = schedule(makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#))
        XCTAssertTrue(weekly.isDoseDay(utcDay("2026-06-01")), "the start date is the first dose")
        for day in days(from: utcDay("2026-05-01"), count: 31) {
            XCTAssertFalse(weekly.isDoseDay(day),
                           "\(dpFormatDay(day)) is before the start and must never be due")
        }
    }

    // MARK: - The occurrence is not a degraded stub

    /// Coverage is worthless if the far-out occurrence has lost the numbers a dose is
    /// logged with. `draw_ml` is what the web's inventory subtracts from the vial and
    /// `dose_label` is what its history renders; an occurrence that reached the calendar
    /// without them would log a dose that consumes nothing and shows no amount.
    func testAFarOutOccurrenceCarriesTheSameFieldsAsTheSeriesWouldHave() {
        // A REAL row shape, not a plausible one: the QA account's `d94cc62b`, the same
        // config `ProtocolSummaryTests` is built on. A config invented for this test
        // could produce a nil volume for reasons that have nothing to do with T-09.
        let dosage = makeDosage(id: "trt1", type: "trt", startDate: "2026-06-01",
                                config: #"{"mode":"perweek","nDays":3.5,"mgWeek":149,"mlDrawn":0.5,"strength":200,"esterType":"Testosterone Enanthate","syringeMl":1,"injPerWeek":2}"#,
                                label: "TRT Dose")
        let sched = schedule(dosage)
        let series = DoseProjection.projectedDoses(for: [dosage], from: utcDay("2026-06-01"),
                                                   days: 120, in: utc)

        // A dose ~100 days out — well past the old window, and one the series above can
        // still be asked for, so the two are comparable field by field.
        guard let expected = series.last else { return XCTFail("no control occurrence") }
        XCTAssertGreaterThan(CalendarWindow.wholeDays(from: utcDay("2026-06-01"), to: expected.date) ?? 0, 30)

        let actual = sched.occurrence(on: expected.date)
        XCTAssertEqual(actual, expected,
                       "the per-date occurrence differs from the one the series produced")
        // 149 mg/week ÷ 2 injections = 74.5 mg; ÷ 200 mg/mL = 0.3725 mL. The numbers a
        // user acts on, on a day the old model had no occurrence for at all.
        XCTAssertEqual(actual?.drawMl ?? 0, 0.3725, accuracy: 0.00001,
                       "a TRT dose reached the calendar without its draw volume")
        XCTAssertEqual(actual?.dose?.labelled, "74.5 mg",
                       "a TRT dose reached the calendar without its dose")
        XCTAssertEqual(actual?.snapshot.protocolLabel, "TRT Dose")
        XCTAssertEqual(actual?.snapshot.compoundLabel, "Test E")
    }

    func testOccurrenceIsNilOnADayWithNoDose() {
        let weekly = schedule(makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#))
        XCTAssertNil(weekly.occurrence(on: utcDay("2026-09-08")))
        XCTAssertNotNil(weekly.occurrence(on: utcDay("2026-09-07")))
    }

    // MARK: - Which rows become schedules at all

    func testInactiveAndUnschedulableRowsProduceNoSchedule() {
        XCTAssertNil(ScheduledProtocol(makeDosage(type: "trt", active: false)),
                     "an inactive protocol must not appear on the calendar")
        XCTAssertNil(ScheduledProtocol(makeDosage(type: "bmi")))
        XCTAssertNil(ScheduledProtocol(makeDosage(type: "freetest")))
        XCTAssertNil(ScheduledProtocol(makeDosage(type: "reconstitution")))
        XCTAssertNil(ScheduledProtocol(makeDosage(type: "plotter")))
        XCTAssertNotNil(ScheduledProtocol(makeDosage(type: "trt", config: #"{"injPerWeek":2}"#)))
    }

    /// The empty state used to be decided by "did the 30-day window produce anything",
    /// so a user whose only protocol starts in five weeks was shown "Nothing scheduled —
    /// add a protocol" while holding one. It is now decided by whether anything CAN be
    /// scheduled.
    func testAProtocolStartingBeyondTheOldWindowStillProducesASchedule() {
        let dosage = makeDosage(type: "semaglutide", startDate: "2026-08-01", config: #"{"dose":0.5}"#)

        XCTAssertTrue(DoseProjection.projectedDoses(for: [dosage], from: utcDay("2026-06-01"),
                                                    days: 30, in: utc).isEmpty,
                      "control: the old window really did see nothing here")

        let data = CalendarData(schedules: [dosage].compactMap(ScheduledProtocol.init), takenKeys: [])
        XCTAssertTrue(data.hasAnySchedule, "a protocol starting in nine weeks is still a schedule")
        XCTAssertEqual(data.occurrences(on: utcDay("2026-08-01")).count, 1)
        XCTAssertEqual(data.occurrences(on: utcDay("2026-07-31")).count, 0)
    }

    // MARK: - Every day the grid can render is answered

    /// The bound that remains is a RENDERING bound. This walks every day of every month
    /// a user can page to — the web's own `-1…+5` — and asserts the far end behaves like
    /// the near end: some days due, some days not, none of them silent.
    func testEveryDayOfEveryReachableMonthIsAnswered() {
        let now = utcDay("2026-08-04")
        let data = CalendarData(
            schedules: [makeDosage(id: "a", type: "trt", startDate: "2026-05-20",
                                   config: #"{"strength":250,"mgWeek":100,"injPerWeek":2,"mode":"perweek"}"#),
                        makeDosage(id: "b", type: "semaglutide", startDate: "2026-05-22",
                                   config: #"{"conc":5,"dose":0.5}"#)].compactMap(ScheduledProtocol.init),
            takenKeys: []
        )
        XCTAssertEqual(data.schedules.count, 2)

        for offset in CalendarWindow.offsets {
            let first = CalendarWindow.firstOfMonth(offset: offset, from: now)
            let count = CalendarWindow.utc.range(of: .day, in: .month, for: first)?.count ?? 30
            let monthDays = days(from: first, count: count)
            let due = monthDays.filter { !data.occurrences(on: $0).isEmpty }

            XCTAssertFalse(due.isEmpty,
                           "month offset \(offset) (\(dpFormatDay(first))) has no dose days at all — "
                           + "that is the blank month T-09 is about")
            XCTAssertLessThan(due.count, monthDays.count,
                              "month offset \(offset) marks EVERY day — dots have stopped meaning anything")
        }
    }

    /// The furthest month a user can reach is ~5 months out; the old window stopped at
    /// 30 days. Stated as arithmetic so the claim "past the window" is checked rather
    /// than assumed.
    func testTheFurthestReachableMonthIsFarPastTheOldWindow() {
        let now = utcDay("2026-08-04")
        let firstOfLast = CalendarWindow.firstOfMonth(offset: CalendarWindow.monthsForward, from: now)
        let distance = CalendarWindow.wholeDays(from: now, to: firstOfLast) ?? 0
        XCTAssertGreaterThan(distance, 30,
                             "the furthest reachable month is inside the old 30-day window — "
                             + "then T-09 could not have been observed")
    }

    // MARK: - The rendering bound, and where it came from

    /// Read from the web's source, not from a document about it:
    /// `components/calendar/CalendarView.tsx:311-320` — `for (let i = -1; i <= 5; i++)`.
    func testTheReachableMonthsAreTheWebs() {
        XCTAssertEqual(CalendarWindow.monthsBack, 1)
        XCTAssertEqual(CalendarWindow.monthsForward, 5)
        XCTAssertEqual(Array(CalendarWindow.offsets), [-1, 0, 1, 2, 3, 4, 5])
        XCTAssertEqual(CalendarWindow.offsets.count, 7, "the web renders seven months")
    }

    func testMonthOffsetArithmeticCrossesTheYearBoundary() {
        let now = utcDay("2026-11-15")
        XCTAssertEqual(CalendarWindow.monthOffset(of: utcDay("2027-01-03"), from: now), 2)
        XCTAssertEqual(CalendarWindow.monthOffset(of: utcDay("2026-10-31"), from: now), -1)
        XCTAssertEqual(dpFormatDay(CalendarWindow.firstOfMonth(offset: 5, from: now)), "2027-04-01")
        XCTAssertEqual(dpFormatDay(CalendarWindow.firstOfMonth(offset: -1, from: now)), "2026-10-01")
    }

    // MARK: - The pin fetch follows the same bound

    /// **THE COROLLARY THAT WOULD OTHERWISE BE A NEW LIE.** Now that past days carry
    /// dots, the taken ticks on them have to be real. The pins used to be fetched from
    /// YESTERDAY; against a grid that can page a month back, every logged dose in that
    /// month would render untaken. This asserts `load` asks for the pins the grid can
    /// actually show — read off the request the view model made, not off the constant.
    @MainActor
    func testLoadFetchesPinsBackToTheFirstMonthTheGridCanShow() async {
        let spy = SinceRecordingBackend()
        let vm = CalendarViewModel()
        let now = utcDay("2026-08-04")

        await vm.load(backend: spy, now: now, zone: utc)

        XCTAssertEqual(spy.lastSince, "2026-07-01",
                       "the calendar asked for pins from \(spy.lastSince ?? "nil") while its grid "
                       + "can page back to 2026-07-01 — logged doses there would show untaken")
    }

    /// Loading against protocols that produce no schedule leaves `.empty`, and loading
    /// against one that does leaves `.loaded` with a schedule that answers far dates.
    @MainActor
    func testLoadProducesSchedulesNotAWindowedSeries() async {
        let backend = SinceRecordingBackend()
        let vm = CalendarViewModel()
        await vm.load(backend: backend, now: utcDay("2026-08-04"), zone: utc)

        guard case .loaded(let data) = vm.state else {
            return XCTFail("expected .loaded, got \(vm.state)")
        }
        XCTAssertFalse(data.schedules.isEmpty)
        // The seeded TRT protocol starts 2026-05-20 at E3.5D. A day 120 days past the
        // reference is answered — the state the old model had no data for at all.
        let far = CalendarWindow.utc.date(byAdding: .day, value: 120, to: utcDay("2026-08-04"))!
        let window = days(from: far, count: 7)
        XCTAssertTrue(window.contains { !data.occurrences(on: $0).isEmpty },
                      "no dose in any of seven days four months out — the far months are still blank")
        XCTAssertTrue(window.contains { data.occurrences(on: $0).isEmpty },
                      "every one of seven days four months out carries a dose — dots mean nothing")
    }

    // MARK: - T-82's frame, on the calendar's surfaces
    //
    // Handed over by `t82-dayframe`, which owned `DoseProjection` and could not reach
    // these call sites. It matters MORE after T-09, not less: while the grid only drew
    // dots forward from today, a mis-named "today" moved a highlight. Now that every
    // rendered day carries an occurrence, the agenda built from `selectedDay` is what a
    // tick writes `dose_log.dosed_on` from — so naming the day wrongly writes the
    // injection under the wrong date. The owner is in Auckland; this is every morning.

    /// **THE AUCKLAND MORNING.** 2026-08-04 09:00 NZST is 2026-08-03 21:00 UTC. The user
    /// would call it Tuesday the 4th, and so must the calendar.
    @MainActor
    func testTodayIsTheLocalDayOnAnAucklandMorning() async {
        let morning = moment(2026, 8, 4, 9, 0, in: auckland)

        // The hazard is ARMED, not assumed. Without this the test could pass in a world
        // where the two frames never differ, and prove nothing.
        XCTAssertEqual(dpFormatDay(morning), "2026-08-03",
                       "precondition: the token frame really does name this morning as yesterday")

        let vm = CalendarViewModel()
        await vm.load(backend: SinceRecordingBackend(dosages: [dailyPeptide()]),
                      now: morning, zone: auckland)

        XCTAssertEqual(dpFormatDay(vm.selectedDay), "2026-08-04",
                       "the calendar opened on yesterday — the agenda under it is yesterday's, "
                       + "and a tick on it writes yesterday's dosed_on")

        // The half that reaches the database. The occurrence the agenda hands to
        // `toggleTaken` must carry the day the user is actually having.
        guard case .loaded(let data) = vm.state else { return XCTFail("expected .loaded") }
        let agenda = data.occurrences(on: vm.selectedDay)
        XCTAssertEqual(agenda.count, 1, "the daily fixture is not due on the selected day")
        XCTAssertEqual(agenda.first?.dayKey, "2026-08-04",
                       "a tap on today would write dosed_on = \(agenda.first?.dayKey ?? "nil")")
    }

    /// The other side of UTC, because a fix that simply shifted everything one way would
    /// pass the test above. 2026-08-03 18:00 PDT is 2026-08-04 01:00 UTC — the token frame
    /// names it TOMORROW there.
    @MainActor
    func testTodayIsTheLocalDayOnALosAngelesEvening() async {
        let evening = moment(2026, 8, 3, 18, 0, in: losAngeles)
        XCTAssertEqual(dpFormatDay(evening), "2026-08-04",
                       "precondition: the token frame names this LA evening as tomorrow")

        let vm = CalendarViewModel()
        await vm.load(backend: SinceRecordingBackend(dosages: [dailyPeptide()]),
                      now: evening, zone: losAngeles)

        XCTAssertEqual(dpFormatDay(vm.selectedDay), "2026-08-03")
        guard case .loaded(let data) = vm.state else { return XCTFail("expected .loaded") }
        XCTAssertEqual(data.occurrences(on: vm.selectedDay).first?.dayKey, "2026-08-03")
    }

    /// The pin fetch is derived from the same "today", so it inherits the same bug. On the
    /// 1st of a month east of UTC the two frames name different MONTHS — the token frame
    /// says July, the user says August — and the fetch would reach back a month too far.
    @MainActor
    func testThePinFetchUsesTheLocalMonthAtAMonthBoundary() async {
        let morning = moment(2026, 8, 1, 9, 0, in: auckland)
        XCTAssertEqual(dpFormatDay(morning), "2026-07-31",
                       "precondition: the frames disagree about the month at this instant")

        let spy = SinceRecordingBackend()
        let vm = CalendarViewModel()
        await vm.load(backend: spy, now: morning, zone: auckland)

        XCTAssertEqual(spy.lastSince, "2026-07-01",
                       "the user is in August, so the one month back the grid can show is "
                       + "July — a UTC reading of this instant asks from June instead")
    }

    /// `isToday` was a comparison hard-coded in a `View` body, where no test could reach
    /// it at any zone but the machine's. Both sides of UTC, both directions of error.
    func testIsTodayNamesTheDayInTheViewersZone() {
        let aucklandMorning = moment(2026, 8, 4, 9, 0, in: auckland)
        XCTAssertTrue(CalendarWindow.isToday(utcDay("2026-08-04"), now: aucklandMorning, in: auckland))
        XCTAssertFalse(CalendarWindow.isToday(utcDay("2026-08-03"), now: aucklandMorning, in: auckland),
                       "the ring is on yesterday's cell — the pre-T-82 behaviour")

        let laEvening = moment(2026, 8, 3, 18, 0, in: losAngeles)
        XCTAssertTrue(CalendarWindow.isToday(utcDay("2026-08-03"), now: laEvening, in: losAngeles))
        XCTAssertFalse(CalendarWindow.isToday(utcDay("2026-08-04"), now: laEvening, in: losAngeles),
                       "the ring is on tomorrow's cell")
    }

    /// Due every single day, so "which day did the calendar select" is the only variable
    /// in what the agenda holds.
    private func dailyPeptide() -> SavedDosage {
        makeDosage(id: "daily", type: "peptide", startDate: "2026-01-01", config: #"{"nDays":1}"#)
    }
}

// MARK: - A backend that records what it was asked for

/// `MockBackendClient` discards `since`, so it cannot answer "what did the calendar ask
/// the database for". This does — and it is the only way to check the pin fetch without
/// the device, since the value never reaches the screen.
private final class SinceRecordingBackend: BackendClient, @unchecked Sendable {
    private(set) var lastSince: String?
    private let inner: MockBackendClient

    /// Defaults to the mock's seeded protocols; takes an explicit list where the test is
    /// about WHICH day a protocol lands on rather than about the fetch.
    init(dosages: [SavedDosage]? = nil) {
        inner = dosages.map { MockBackendClient(dosages: $0, cycles: []) } ?? MockBackendClient()
    }

    func savedDosages() async throws -> [SavedDosage] { try await inner.savedDosages() }
    func savedDosage(id: String) async throws -> SavedDosage? { try await inner.savedDosage(id: id) }
    func saveDosage(_ dosage: NewSavedDosage) async throws -> String { try await inner.saveDosage(dosage) }
    func updateStartDate(id: String, startDate: String?) async throws {
        try await inner.updateStartDate(id: id, startDate: startDate)
    }
    func deleteDosage(id: String) async throws { try await inner.deleteDosage(id: id) }
    func cyclesWithItems() async throws -> [CycleWithItems] { try await inner.cyclesWithItems() }

    func doseLog(since: String?) async throws -> [DoseLogPin] {
        lastSince = since
        return try await inner.doseLog(since: since)
    }

    func logDose(_ pin: NewDoseLogPin) async throws -> DoseLogPin { try await inner.logDose(pin) }
    func unlogDose(protocolId: String, dosedOn: String) async throws {
        try await inner.unlogDose(protocolId: protocolId, dosedOn: dosedOn)
    }
    func profile(userId: String) async throws -> Profile? { try await inner.profile(userId: userId) }
    func updateDisplayName(_ name: String, userId: String) async throws {
        try await inner.updateDisplayName(name, userId: userId)
    }
    func deleteAccount() async throws -> [String] { try await inner.deleteAccount() }
}
