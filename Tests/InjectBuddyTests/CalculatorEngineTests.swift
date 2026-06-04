import XCTest
@testable import InjectBuddy

// ─── CalculatorEngineTests ───────────────────────────────────────────────────
// Locks the Swift engine to the web math. One test per calculator asserts the
// GOLDEN TEST VECTORS table at the bottom of CALC-MATH.md. A lighter sanity test
// covers the cycle-plotter PK (peak after tmax, decay toward zero).

final class CalculatorEngineTests: XCTestCase {

    private let acc = 0.001

    // 1. trt-dose: strength 200, mgWeek 100, perweek injPerWeek 2
    func testTrtDose() {
        let r = CalculatorEngine.trt(strength: 200, mgWeek: 100, mode: .perweek,
                                     nDays: 0, injPerWeek: 2, mlDrawn: 0)
        XCTAssertEqual(r.mgPerInj, 50, accuracy: acc)
        XCTAssertEqual(r.mlPerInj, 0.25, accuracy: acc)
        XCTAssertEqual(r.unitsPerInj, 25, accuracy: acc)
        XCTAssertEqual(r.weeklyTotal, 100, accuracy: acc)
        XCTAssertTrue(r.isValid)
    }

    // 2. trt-eod: strength 200, mgWeek 70
    func testTrtEod() {
        let r = CalculatorEngine.eod(strength: 200, mgWeek: 70)
        XCTAssertEqual(r.freqPerWeek, 3.5, accuracy: acc)
        XCTAssertEqual(r.mgPerInj, 20, accuracy: acc)
        XCTAssertEqual(r.mlPerInj, 0.1, accuracy: acc)
        XCTAssertEqual(r.unitsPerInj, 10, accuracy: acc)
    }

    // 3. hcg: vialIU 5000, bac 1, dose 250
    func testHcg() {
        let r = CalculatorEngine.hcg(vialIU: 5000, bacWaterMl: 1, dose: 250)
        XCTAssertEqual(r.concentration, 5000, accuracy: acc)
        XCTAssertEqual(r.drawMl, 0.05, accuracy: acc)
        XCTAssertEqual(r.units, 5, accuracy: acc)
        XCTAssertEqual(r.dosesPerVial, 20, accuracy: acc)
    }

    // 4. peptide: mg 50, baw 10, dose 500 mcg, inj/wk 1
    func testPeptide() {
        let r = CalculatorEngine.peptide(peptideMg: 50, bawMl: 10, dosePerInj: 500,
                                         doseUnit: "mcg", injPerWeek: 1)
        XCTAssertEqual(r.concentration, 5, accuracy: acc)
        XCTAssertEqual(r.mlPerInj, 0.1, accuracy: acc)
        XCTAssertEqual(r.unitsPerInj, 10, accuracy: acc)
        XCTAssertEqual(r.weeklyTotalMg, 0.5, accuracy: acc)
        XCTAssertEqual(r.totalDoses, 100, accuracy: acc)
    }

    // 5. reconstitution: mg 5, targetConc 1000
    func testReconstitution() {
        let r = CalculatorEngine.reconstitution(peptideMg: 5, targetConc: 1000)
        XCTAssertEqual(r.bacWaterMl, 5, accuracy: acc)
        XCTAssertEqual(r.vialContentsMcg, 5000, accuracy: acc)
    }

    // 6. semaglutide: conc 5, dose 0.5
    func testSemaglutide() {
        let r = CalculatorEngine.glp1(conc: 5, dose: 0.5)
        XCTAssertEqual(r.volumeMl, 0.1, accuracy: acc)
        XCTAssertEqual(r.units, 10, accuracy: acc)
    }

    // 7. tirzepatide: conc 7.5, dose 5
    func testTirzepatide() {
        let r = CalculatorEngine.glp1(conc: 7.5, dose: 5)
        XCTAssertEqual(r.volumeMl, 0.6667, accuracy: acc)
        XCTAssertEqual(r.units, 67, accuracy: acc)
    }

    // 8. retatrutide: conc 5, dose 2.5
    func testRetatrutide() {
        let r = CalculatorEngine.glp1(conc: 5, dose: 2.5)
        XCTAssertEqual(r.volumeMl, 0.5, accuracy: acc)
        XCTAssertEqual(r.units, 50, accuracy: acc)
    }

    // 9. bpc-157: concMcgMl 2500, dose 250
    func testBpc157() {
        let r = CalculatorEngine.bpc157(concMcgMl: 2500, dose: 250)
        XCTAssertEqual(r.drawMl, 0.1, accuracy: acc)
        XCTAssertEqual(r.units, 10, accuracy: acc)
    }

    // 10. bpc-157-tb500 blend: bpc 5000/2/250, tb 5000/2/2000
    func testBlend() {
        let r = CalculatorEngine.blend(bpcVial: 5000, bpcWater: 2, bpcDose: 250,
                                       tbVial: 5000, tbWater: 2, tbDose: 2000)
        XCTAssertEqual(r.bpcDraw, 0.1, accuracy: acc)
        XCTAssertEqual(r.bpcUnits, 10, accuracy: acc)
        XCTAssertEqual(r.tbDraw, 0.8, accuracy: acc)
        XCTAssertEqual(r.tbUnits, 80, accuracy: acc)
        XCTAssertEqual(r.totalMl, 0.9, accuracy: acc)
        XCTAssertEqual(r.totalUnits, 90, accuracy: acc)
    }

    // 11. bmi metric: h 180cm, w 80kg
    func testBmiMetric() {
        let r = CalculatorEngine.bmiMetric(heightCm: 180, weightKg: 80)
        XCTAssertEqual(r.bmi, 24.69, accuracy: 0.01)
        XCTAssertEqual(r.category, "Normal")
    }

    // 12. bmi imperial: 5ft10, 180lb
    // NOTE: CALC-MATH.md table lists 25.81, but the verbatim JS formula
    // (703 * 180 / 70^2) = 25.8245. The table value is a rounding slip; we assert
    // the true formula output. Category "Overweight" matches the table either way.
    func testBmiImperial() {
        let r = CalculatorEngine.bmiImperial(heightFt: 5, heightIn: 10, weightLb: 180)
        XCTAssertEqual(r.bmi, 25.8245, accuracy: 0.001)
        XCTAssertEqual(r.category, "Overweight")
    }

    // 13. free-t-index: tt 20 nmol, shbg 50
    func testFreeTestIndex() {
        let r = CalculatorEngine.freeTestIndex(ttNum: 20, ttUnit: "nmol", shbgNum: 50)
        XCTAssertEqual(r.fai, 40, accuracy: acc)
        XCTAssertEqual(r.band, "Normal")
    }

    // 14. trt-microdose: strength 10, mgWeek 5, ndays 3
    func testTrtMicrodose() {
        let r = CalculatorEngine.trt(strength: 10, mgWeek: 5, mode: .ndays,
                                     nDays: 3, injPerWeek: 0, mlDrawn: 0)
        XCTAssertEqual(r.freqPerWeek, 2.333, accuracy: acc)
        XCTAssertEqual(r.mgPerInj, 2.143, accuracy: acc)
        XCTAssertEqual(r.mlPerInj, 0.2143, accuracy: acc)
        XCTAssertEqual(r.unitsPerInj, 21.4, accuracy: 0.1)
    }

    // Cycle-plotter PK sanity: peak occurs after tmax, level decays toward zero.
    func testCyclePlotterPK() {
        // Single dose of Test-E (half-life 4.5 d, tmax 2.0 d). Build one-dose entries
        // over a 1-day cycle so only the dose at t=0 contributes.
        let entries = CalculatorEngine.pkBuildEntries(
            halfLife: 4.5, tmax: 2.0, dose: 100, freqDays: 100, cycleDays: 1)
        XCTAssertEqual(entries.count, 1)

        let atTmax = CalculatorEngine.pkTotalLevel(t: 2.0, entries: entries)
        let beforeTmax = CalculatorEngine.pkTotalLevel(t: 0.5, entries: entries)
        let later = CalculatorEngine.pkTotalLevel(t: 20.0, entries: entries)
        let veryLate = CalculatorEngine.pkTotalLevel(t: 60.0, entries: entries)

        // Level at t<=0 is zero.
        XCTAssertEqual(CalculatorEngine.pkOneLevel(dt: 0, dose: 100, ke: 1, ka: 2), 0, accuracy: acc)
        // Peak is after tmax: level at tmax exceeds an early sample.
        XCTAssertGreaterThan(atTmax, beforeTmax)
        // Decays toward zero over time.
        XCTAssertGreaterThan(atTmax, later)
        XCTAssertGreaterThan(later, veryLate)
        XCTAssertGreaterThan(veryLate, 0)
        XCTAssertLessThan(veryLate, 1.0)

        // pkSolveKa actually reproduces tmax: time-of-peak from ka/ke ≈ requested tmax.
        let ke = 0.693147180559945 / 4.5
        let ka = CalculatorEngine.pkSolveKa(ke: ke, tmax: 2.0)
        let tPeak = log(ka / ke) / (ka - ke)
        XCTAssertEqual(tPeak, 2.0, accuracy: 0.01)
    }
}
