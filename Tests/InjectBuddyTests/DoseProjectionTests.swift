import XCTest
@testable import InjectBuddy

// Unit tests for the pure scheduling engine. All dates are fixed/UTC so results are
// deterministic regardless of the machine's time zone.

final class DoseProjectionTests: XCTestCase {

    // MARK: helpers

    /// **The window origin is now a LOCAL day (T-82), so these must say which zone.**
    /// Every `from:` below is a day TOKEN (00:00 UTC) rather than a real moment, so UTC
    /// is the zone that reproduces the intended day for it — and passing it explicitly
    /// is what makes the header's claim true. Left to `.current`, a machine in
    /// Los Angeles would read a 00:00 UTC token as the PREVIOUS day and start every
    /// window there, which silently drops the last dose of a fixed-length window.
    private let utc = TimeZone(identifier: "UTC")!
    private let auckland = TimeZone(identifier: "Pacific/Auckland")!
    private let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// A real INSTANT: `y-m-d h:mm` as read in `zone`. Not a day token — the point of
    /// the T-82 tests is that the two are different things.
    private func moment(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int,
                        in zone: TimeZone) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        guard let date = cal.date(from: c) else {
            XCTFail("bad test moment"); return Date()
        }
        return date
    }

    private func utcDay(_ string: String) -> Date {
        // Reuse the engine's own parser so tests match its day handling exactly.
        guard let d = dpParseDay(string) else {
            XCTFail("bad test date \(string)"); return Date()
        }
        return d
    }

    /// Build a SavedDosage from a JSON object literal (mirrors the backend shape).
    private func makeDosage(
        id: String = "p",
        type: String,
        startDate: String = "2026-01-01",
        config: String = "{}",
        active: Bool = true
    ) -> SavedDosage {
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":null,"config":\(config),"start_date":"\(startDate)","is_active":\(active)}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    // MARK: - T-81 · the safety valve counts the wrong quantity

    /// **T-81 — a live, still-active protocol vanishes from the dashboard and the
    /// calendar once it is old enough, with no error and no empty state.**
    ///
    /// `step` is fast-forwarded to *how many doses have occurred since the protocol
    /// began*. The guard then compares it against `days * 4 + 8`, a budget derived from
    /// the *window length*. **Two different quantities.** Once a protocol is older than
    /// the budget, the loop breaks after at most one emission.
    ///
    /// This is the failure mode the app exists to prevent: not a wrong number, but a
    /// correct protocol that is simply absent from the screen the user checks to decide
    /// whether to inject today.
    ///
    /// Found by agent `t82-dayframe` while building an unrelated DST fixture — its daily
    /// protocol started in January and emitted a single day.
    func testT81_ALongRunningDailyProtocolStillFillsTheWholeWindow() {
        // Daily, started ~200 days before the window. step fast-forwards to ~200; the
        // budget is 30*4+8 = 128. 200 > 128, so the loop breaks after one emission.
        let d = makeDosage(type: "peptide", startDate: "2026-01-01",
                           config: #"{"mode":"daily"}"#)
        let doses = DoseProjection.projectedDoses(for: [d],
                                                  from: utcDay("2026-07-20"),
                                                  days: 30, in: utc)

        XCTAssertEqual(doses.count, 30,
                       "A daily protocol that has been running since January emits "
                       + "\(doses.count) of 30 days. The guard counts doses-since-start "
                       + "against a budget derived from the window length.")
    }

    /// The same defect from the other end, and it is why nobody has noticed: the bug is
    /// a THRESHOLD, not a constant. A protocol young enough that its dose ordinal still
    /// fits inside the window budget projects perfectly — so the calendar looks correct
    /// right up until the day it silently does not.
    func testT81_TheSameProtocolProjectsCorrectlyWhileItIsYoungEnough() {
        let d = makeDosage(type: "peptide", startDate: "2026-07-01",
                           config: #"{"mode":"daily"}"#)
        let doses = DoseProjection.projectedDoses(for: [d],
                                                  from: utcDay("2026-07-20"),
                                                  days: 30, in: utc)
        XCTAssertEqual(doses.count, 30,
                       "A recently-started daily protocol should fill the window; if this "
                       + "fails the projection is broken generally, not just for old ones.")
    }

    /// The guard must still exist. It is there so a degenerate interval cannot spin
    /// forever, and replacing a wrong bound with no bound would trade a silent omission
    /// for a hang on a dosing screen.
    func testT81_ADegenerateIntervalStillTerminates() {
        // interval 0.01 days → the walk would emit indefinitely without a bound.
        let d = makeDosage(type: "peptide", startDate: "2026-01-01",
                           config: #"{"freqDays":0.01}"#)
        let doses = DoseProjection.projectedDoses(for: [d],
                                                  from: utcDay("2026-07-20"),
                                                  days: 30, in: utc)
        // `days * 4 + 8` is the guard's threshold, and it is tested AFTER the increment,
        // so the walk performs one more pass than the threshold names: 129, not 128.
        // Stated exactly rather than rounded up to something comfortable — this test
        // first ran red at 129-vs-128 and the OFF-BY-ONE WAS IN THIS ASSERTION, not in
        // the guard. Recording that here because a bound quietly widened to go green is
        // indistinguishable from a bound that was always right.
        XCTAssertLessThanOrEqual(doses.count, 30 * 4 + 9,
                                 "the degenerate-interval bound is gone")
        XCTAssertGreaterThan(doses.count, 0,
                             "a degenerate interval now emits nothing at all, which is "
                             + "the opposite failure and would hide a protocol just as "
                             + "effectively as T-81 did")
    }

    // MARK: - interval derivation

    func testInterval_TRTPerWeek() {
        // TRT, 2 injections/week → 3.5 days between shots.
        let d = makeDosage(type: "trt", config: #"{"strength":250,"mgWeek":100,"injPerWeek":2,"mode":"perweek"}"#)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 3.5)
    }

    func testInterval_EODByCalculatorType() {
        // The dedicated EOD calculator → every 2 days regardless of config.
        let d = makeDosage(type: "eod", config: "{}")
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 2)
    }

    func testInterval_EODByMode() {
        // A TRT protocol explicitly flagged EOD via config.mode.
        let d = makeDosage(type: "trt", config: #"{"mode":"eod"}"#)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 2)
    }

    func testInterval_GLP1Weekly() {
        // Semaglutide with no explicit cadence → weekly (7).
        let d = makeDosage(type: "semaglutide", config: #"{"conc":5,"dose":0.5}"#)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 7)
    }

    func testInterval_GLP1HonoursExplicitInjPerWeek() {
        // If a GLP-1 config carries injPerWeek it wins over the weekly default.
        let d = makeDosage(type: "tirzepatide", config: #"{"injPerWeek":2}"#)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 3.5)
    }

    func testInterval_NDaysKey() {
        let d = makeDosage(type: "peptide", config: #"{"nDays":3}"#)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: d), 3)
    }

    func testInterval_NonScheduledReturnsNil() {
        XCTAssertNil(DoseProjection.injectionIntervalDays(for: makeDosage(type: "bmi")))
        XCTAssertNil(DoseProjection.injectionIntervalDays(for: makeDosage(type: "freetest")))
        XCTAssertNil(DoseProjection.injectionIntervalDays(for: makeDosage(type: "reconstitution")))
        XCTAssertNil(DoseProjection.injectionIntervalDays(for: makeDosage(type: "plotter")))
    }

    // MARK: - projection over a window

    func testProjection_WeeklyOver30Days() {
        // Weekly protocol starting on the window start → days 1, 8, 15, 22, 29 (5 doses).
        let proto = makeDosage(type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#)
        let from = utcDay("2026-06-01")
        let occ = DoseProjection.projectedDoses(for: [proto], from: from, days: 30, in: utc)

        let days = occ.map { $0.dayKey }
        XCTAssertEqual(days, ["2026-06-01", "2026-06-08", "2026-06-15", "2026-06-22", "2026-06-29"])
        XCTAssertTrue(occ.allSatisfy { $0.protocolId == "p" })
        XCTAssertEqual(occ.first?.slug, .semaglutide)
    }

    func testProjection_TwiceWeeklyDates() {
        // E3.5: from 2026-06-01 the rounded offsets are 0,3,7,10,14,… (Mon/Thu-ish).
        let proto = makeDosage(type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":2}"#)
        let occ = DoseProjection.projectedDoses(for: [proto], from: utcDay("2026-06-01"), days: 15, in: utc)
        let days = occ.map { $0.dayKey }
        XCTAssertEqual(days, ["2026-06-01", "2026-06-04", "2026-06-08", "2026-06-11", "2026-06-15"])
    }

    func testProjection_StartsBeforeWindow_FastForwards() {
        // Weekly protocol that started well before the window: first emitted dose is
        // the first occurrence on/after the window start.
        let proto = makeDosage(type: "semaglutide", startDate: "2026-01-01", config: #"{"dose":0.5}"#)
        // 2026-06-04 is a Thursday; Jan 1 is a Thursday → weekly lands on Thursdays.
        let occ = DoseProjection.projectedDoses(for: [proto], from: utcDay("2026-06-04"), days: 8, in: utc)
        XCTAssertEqual(occ.first?.dayKey, "2026-06-04")
        XCTAssertTrue(occ.allSatisfy { $0.date >= utcDay("2026-06-04") })
    }

    func testProjection_InactiveAndUnscheduledExcluded() {
        let active = makeDosage(id: "a", type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":1}"#)
        let inactive = makeDosage(id: "b", type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":1}"#, active: false)
        let noSchedule = makeDosage(id: "c", type: "bmi", startDate: "2026-06-01")
        let occ = DoseProjection.projectedDoses(for: [active, inactive, noSchedule],
                                                from: utcDay("2026-06-01"), days: 30, in: utc)
        XCTAssertTrue(occ.allSatisfy { $0.protocolId == "a" })
        XCTAssertFalse(occ.isEmpty)
    }

    func testNextDose_ReturnsSoonest() {
        let trt = makeDosage(id: "trt", type: "trt", startDate: "2026-06-02", config: #"{"injPerWeek":2}"#)
        let sema = makeDosage(id: "sema", type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#)
        let next = DoseProjection.nextDose(for: [trt, sema], from: utcDay("2026-06-01"), in: utc)
        XCTAssertEqual(next?.dayKey, "2026-06-01")
        XCTAssertEqual(next?.protocolId, "sema")
    }

    // MARK: - T-82 · one frame names the day

    /// A protocol that is due every single day, so "which day did the window open on"
    /// is the only variable in the projection's answer.
    ///
    /// **The start date is deliberately just before the window, not months before.**
    /// `projectedDoses`' safety valve is `step > days * 4 + 8`, and `step` counts doses
    /// since the PROTOCOL started rather than iterations of the loop it guards (T-81,
    /// open) — so a daily protocol started in January and projected over a week emits
    /// its first day and then breaks. These tests are about which day the window opens
    /// on; a fixture that also tripped that valve would be measuring two things and
    /// reporting one number.
    private func daily(id: String = "p", from startDate: String = "2026-08-01") -> SavedDosage {
        makeDosage(id: id, type: "peptide", startDate: startDate, config: #"{"nDays":1}"#)
    }

    /// **THE TASK.** `dose_log.dosed_on` is a calendar day and the app has two surfaces
    /// that write it: the log sheet, and a projected occurrence (the dashboard's "Mark
    /// taken" and the calendar's tick). They used to name the same morning differently —
    /// the sheet in the device's zone, the projection in UTC — and east of UTC that is
    /// twelve hours a day where the two disagree. `(protocol_id, dosed_on)` is unique, so
    /// disagreeing means one injection upserts into two rows and the supply ledger
    /// subtracts two draws. (Latent: no instance of it was found in production.)
    ///
    /// 2026-08-04 09:00 NZST is 2026-08-03 21:00 UTC. The user would call it Tuesday.
    func testT82_AnAucklandMorningIsTuesdayOnBothPaths() throws {
        let morning = moment(2026, 8, 4, 9, 0, in: auckland)

        // The hazard is ARMED, not assumed: the fixed token frame really does name the
        // previous day at this instant. Without this the rest could pass in a world
        // where the two frames never differed.
        XCTAssertEqual(dpFormatDay(morning), "2026-08-03",
                       "precondition: UTC names this Auckland morning as yesterday")

        // Path 1 — the log sheet.
        let fromSheet = LogDoseSheet.dosedOn(for: morning, in: auckland)
        XCTAssertEqual(fromSheet, "2026-08-04")

        // Path 2 — a projected occurrence.
        let occurrences = DoseProjection.projectedDoses(
            for: [daily()], from: morning, days: 7, in: auckland)
        let occurrence = try XCTUnwrap(occurrences.first, "projected nothing — fixture is wrong")
        XCTAssertEqual(occurrence.dayKey, "2026-08-04")

        // The agreement itself, which is what the unique index cares about.
        XCTAssertEqual(fromSheet, occurrence.dayKey)

        // And the agreement survives into the row that is actually written.
        let pin = NewDoseLogPin(for: occurrence, now: morning, timeZone: auckland)
        XCTAssertEqual(pin.dosedOn, fromSheet)
        XCTAssertEqual(pin.scheduledOn, fromSheet)

        // With the frames agreed, a same-day dashboard tap still carries the real clock
        // time WITHOUT `InjectionMoment.forLog`'s removed "today in either frame" arm.
        XCTAssertEqual(pin.injectionTime, "09:00")
        XCTAssertEqual(pin.injectedAt, "2026-08-03T21:00:00.000Z")
    }

    /// **Not "add twelve hours".** West of UTC the error runs the other way: 2026-08-03
    /// 19:00 PDT is already 2026-08-04 in UTC, so the old frame named a Monday evening
    /// as Tuesday. This is the case the web's own `ymd` comment is written against —
    /// *"never toISOString (that would shift the calendar day for negative-UTC
    /// offsets)"* — the comment above `ymd` in `DashboardContext.tsx`.
    func testT82_ALosAngelesEveningIsNotPushedIntoTomorrow() throws {
        let evening = moment(2026, 8, 3, 19, 0, in: losAngeles)

        XCTAssertEqual(dpFormatDay(evening), "2026-08-04",
                       "precondition: UTC names this LA evening as tomorrow")

        let fromSheet = LogDoseSheet.dosedOn(for: evening, in: losAngeles)
        XCTAssertEqual(fromSheet, "2026-08-03")

        let occurrences = DoseProjection.projectedDoses(
            for: [daily()], from: evening, days: 7, in: losAngeles)
        let occurrence = try XCTUnwrap(occurrences.first, "projected nothing — fixture is wrong")
        XCTAssertEqual(occurrence.dayKey, "2026-08-03")
        XCTAssertEqual(fromSheet, occurrence.dayKey)
    }

    /// The disagreement was never all day — it was half of it, which is why it could sit
    /// in the code unnoticed. Walking every hour of one day in each zone is the check
    /// that there is no hour left where the two surfaces would write different rows.
    func testT82_TheTwoPathsAgreeAtEveryHourOfTheDay() {
        for (zone, day) in [(auckland, 4), (losAngeles, 3)] {
            for hour in 0..<24 {
                let instant = moment(2026, 8, day, hour, 30, in: zone)
                let fromSheet = LogDoseSheet.dosedOn(for: instant, in: zone)
                let fromOccurrence = DoseProjection.projectedDoses(
                    for: [daily()], from: instant, days: 2, in: zone).first?.dayKey
                XCTAssertEqual(fromOccurrence, fromSheet,
                               "\(zone.identifier) at \(hour):30 — the two surfaces would write two rows")
                XCTAssertEqual(fromSheet, String(format: "2026-08-%02d", day),
                               "\(zone.identifier) at \(hour):30")
            }
        }
    }

    /// **The emitted day is local; the interval arithmetic is not.** Stepping N days in
    /// local time across a DST boundary gains or loses an hour and can drift a
    /// projection off its day. Only the window's origin is converted from an instant to
    /// a day; every step after that runs on day tokens in one fixed frame, where a day
    /// is always 86400s. New Zealand puts its clocks forward on 2026-09-27, so a daily
    /// protocol projected across it must produce consecutive days with nothing repeated
    /// and nothing skipped.
    func testT82_DSTDoesNotDriftTheProjection() {
        let before = moment(2026, 9, 25, 8, 0, in: auckland)
        let days = DoseProjection.projectedDoses(
            for: [daily(from: "2026-09-20")], from: before, days: 7, in: auckland).map(\.dayKey)
        XCTAssertEqual(days, ["2026-09-25", "2026-09-26", "2026-09-27",
                              "2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01"])
    }
}
