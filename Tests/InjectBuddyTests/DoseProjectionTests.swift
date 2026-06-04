import XCTest
@testable import InjectBuddy

// Unit tests for the pure scheduling engine. All dates are fixed/UTC so results are
// deterministic regardless of the machine's time zone.

final class DoseProjectionTests: XCTestCase {

    // MARK: helpers

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
        let occ = DoseProjection.projectedDoses(for: [proto], from: from, days: 30)

        let days = occ.map { $0.dayKey }
        XCTAssertEqual(days, ["2026-06-01", "2026-06-08", "2026-06-15", "2026-06-22", "2026-06-29"])
        XCTAssertTrue(occ.allSatisfy { $0.protocolId == "p" })
        XCTAssertEqual(occ.first?.slug, .semaglutide)
    }

    func testProjection_TwiceWeeklyDates() {
        // E3.5: from 2026-06-01 the rounded offsets are 0,3,7,10,14,… (Mon/Thu-ish).
        let proto = makeDosage(type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":2}"#)
        let occ = DoseProjection.projectedDoses(for: [proto], from: utcDay("2026-06-01"), days: 15)
        let days = occ.map { $0.dayKey }
        XCTAssertEqual(days, ["2026-06-01", "2026-06-04", "2026-06-08", "2026-06-11", "2026-06-15"])
    }

    func testProjection_StartsBeforeWindow_FastForwards() {
        // Weekly protocol that started well before the window: first emitted dose is
        // the first occurrence on/after the window start.
        let proto = makeDosage(type: "semaglutide", startDate: "2026-01-01", config: #"{"dose":0.5}"#)
        // 2026-06-04 is a Thursday; Jan 1 is a Thursday → weekly lands on Thursdays.
        let occ = DoseProjection.projectedDoses(for: [proto], from: utcDay("2026-06-04"), days: 8)
        XCTAssertEqual(occ.first?.dayKey, "2026-06-04")
        XCTAssertTrue(occ.allSatisfy { $0.date >= utcDay("2026-06-04") })
    }

    func testProjection_InactiveAndUnscheduledExcluded() {
        let active = makeDosage(id: "a", type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":1}"#)
        let inactive = makeDosage(id: "b", type: "trt", startDate: "2026-06-01", config: #"{"injPerWeek":1}"#, active: false)
        let noSchedule = makeDosage(id: "c", type: "bmi", startDate: "2026-06-01")
        let occ = DoseProjection.projectedDoses(for: [active, inactive, noSchedule],
                                                from: utcDay("2026-06-01"), days: 30)
        XCTAssertTrue(occ.allSatisfy { $0.protocolId == "a" })
        XCTAssertFalse(occ.isEmpty)
    }

    func testNextDose_ReturnsSoonest() {
        let trt = makeDosage(id: "trt", type: "trt", startDate: "2026-06-02", config: #"{"injPerWeek":2}"#)
        let sema = makeDosage(id: "sema", type: "semaglutide", startDate: "2026-06-01", config: #"{"dose":0.5}"#)
        let next = DoseProjection.nextDose(for: [trt, sema], from: utcDay("2026-06-01"))
        XCTAssertEqual(next?.dayKey, "2026-06-01")
        XCTAssertEqual(next?.protocolId, "sema")
    }
}
