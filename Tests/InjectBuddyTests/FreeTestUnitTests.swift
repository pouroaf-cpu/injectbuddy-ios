import XCTest
@testable import InjectBuddy

// ─── FreeTestUnitTests ───────────────────────────────────────────────────────
// T-43. The Free T Index `TT unit` picker used to change the unit and leave the
// number, so the SHIPPED DEFAULT — 20 with SHBG 50 — read FAI 40.0 "Normal" in
// nmol/L and FAI 1.4 "Low" the instant the picker moved to ng/dL, with no blood
// value changed. Same defect as T-41 on a second screen, factor 28.84 instead of
// 1000, and closed with a `unitScaling:` declaration on the existing mechanism
// rather than a new one.
//
// WHAT THESE TESTS ARE WRITTEN AGAINST, and it is not this repo's own reading of
// the web. `public/app.js` at 7878-7887, read from the checkout:
//
//   7876  // Toggling the unit converts the typed value so the physical quantity is
//   7877  // kept (600 ng/dL → ~20.8 nmol/L, not read as 600 nmol/L → a 28.84× wrong
//   7877  // FAI/band).
//   7878  const changeTtUnit = (u) => {
//   7879    if (u === ttUnit) return;
//   7880    const cur = parseFloat(ttRaw);
//   7881    if (isFinite(cur)) {
//   7882      const nmol = ttUnit === 'ngdl' ? cur / 28.84 : cur;
//   7883      const conv = u === 'ngdl' ? nmol * 28.84 : nmol;
//   7884      setTtRaw(String(Math.round(conv * 100) / 100));
//   7885    }
//   7886    setTtUnit(u);
//   7887  };
//
// The hazard is annotated IN THE WEB'S OWN SOURCE. The port dropped it.
//
// ── THE ROUND TRIP IS PINNED BOTH WAYS, AND ONE WAY IS NOT EXACT ─────────────
//
// A test that only asserts nmol/L → ng/dL multiplies passes on an implementation
// that CLAMPS, so both directions are pinned and `testConversionIsNotAClamp`
// names the trap. But unlike T-41's factor of 1000, 28.84 admits no exact
// two-way decimal round trip AT ALL, and that is arithmetic rather than a defect
// in the conversion:
//
//   • nmol/L → ng/dL → nmol/L IS exact for every two-decimal value. The ng/dL
//     rounding is worth at most 0.005 ng/dL = 0.00017 nmol/L, far inside the
//     nmol hundredth it lands back on.
//   • ng/dL → nmol/L → ng/dL CANNOT be. 0.005 nmol/L is 0.1442 ng/dL — WIDER
//     than the ng/dL hundredth — so 600 comes back 599.87.
//
// Exactness both ways needs the two decimal grids to correspond under the
// factor. They do for 1000 (1 mcg IS 0.001 mg) and no decimal pair can for
// 28.84: the ng/dL trip needs at least two more base decimals than alternate
// ones, the nmol trip needs at most one more, and both cannot hold. Rounding
// nmol/L to four decimals instead buys the ng/dL trip and loses the nmol one —
// it puts "20.7999" in a field the user typed 20.8 into, and disagrees with the
// web on a displayed number. So the web's two decimals are kept, and the ng/dL
// direction is asserted to return the original WITHIN THE ONE ROUNDING IT IS
// ALLOWED — `nmolTick`, 0.1442 ng/dL — never within a fudge chosen to make a
// green run. A clamp, a dropped conversion or a wrong factor all miss that
// window by three or more orders of magnitude.

@MainActor
final class FreeTestUnitTests: XCTestCase {

    private let nmol: Double = 0   // ttUnitNgdl picker values
    private let ngdl: Double = 1

    /// One nmol/L hundredth expressed in ng/dL — the entire error budget of a
    /// there-and-back trip that starts in ng/dL, derived rather than tuned.
    private let nmolTick: Double = 28.84 / 200   // 0.1442

    private func faiVM() -> CalculatorViewModel { CalculatorViewModel(slug: .freeTestIndex) }

    private func tt(_ vm: CalculatorViewModel) -> Double { vm.values.number("tt") }

    private func setUnit(_ vm: CalculatorViewModel, _ unit: Double) {
        vm.values.numbers["ttUnitNgdl"] = unit
    }

    private func ttField(_ vm: CalculatorViewModel) -> CalculatorInput {
        guard let f = vm.fields.first(where: { $0.key == "tt" }) else {
            XCTFail("free test index spec has no tt field")
            return .number("missing", "missing", default: 0)
        }
        return f
    }

    private func bounds(_ f: CalculatorInput) -> (unit: String?, range: ClosedRange<Double>?, step: Double?) {
        guard case let .number(unit, _, range, step) = f.kind else {
            XCTFail("tt is not a number field")
            return (nil, nil, nil)
        }
        return (unit, range, step)
    }

    private func row(_ vm: CalculatorViewModel, _ label: String) -> String? {
        vm.result.rows.first(where: { $0.label == label })?.value
    }

    // MARK: - The defect itself

    /// The shipped default, flipped once. 20 nmol/L must read 576.8 ng/dL, not 20.
    func testFlippingToNgdlConvertsTheShippedDefault() {
        let vm = faiVM()
        XCTAssertEqual(tt(vm), 20, accuracy: 1e-9, "spec default changed")
        setUnit(vm, ngdl)
        XCTAssertEqual(tt(vm), 576.8, accuracy: 1e-9)
        // Direction, named. A factor applied the wrong way round gives 0.69, which is
        // in range, plausible on the screen, and the same 28.84x error inverted.
        XCTAssertGreaterThan(tt(vm), 20, "the conversion ran backwards")
    }

    /// THE ACTUAL USER-VISIBLE DEFECT, and the test that would have caught it: a
    /// picker that only renames the unit must not move the number the user acts on.
    ///
    /// Before the fix the shipped default read FAI 40.0 "Normal" in nmol/L and FAI
    /// 1.4 "Low" in ng/dL — the same blood, one tap apart, on opposite sides of a
    /// clinical band. Both rows are asserted, not just the band, because a band is
    /// three values wide and would survive most of the ways this can go wrong.
    func testTheFaiAndItsBandDoNotMoveWhenOnlyTheUnitChanges() {
        // ── starting in nmol/L, the shipped default ──────────────────────────────
        let fromNmol = faiVM()
        XCTAssertEqual(row(fromNmol, "Free Androgen Index"), "40.0")
        XCTAssertEqual(row(fromNmol, "Band"), "Normal")
        let beforeRows = fromNmol.result.rows

        setUnit(fromNmol, ngdl)

        XCTAssertEqual(row(fromNmol, "Free Androgen Index"), "40.0",
                       "the FAI moved on a unit flip — the value did not convert")
        XCTAssertEqual(row(fromNmol, "Band"), "Normal")
        XCTAssertNotEqual(row(fromNmol, "Band"), "Low",
                          "this is the T-43 defect verbatim: 40.0 Normal became 1.4 Low")
        XCTAssertEqual(row(fromNmol, "TT (nmol/L)"), "20.00",
                       "the canonicalised TT moved, so the engine was handed a different blood value")
        XCTAssertEqual(fromNmol.result.rows, beforeRows,
                       "a unit flip changed a displayed row")
        XCTAssertEqual(fromNmol.result.isValid, true)

        // ── and starting in ng/dL, which is the web's own default unit ───────────
        // Unconverted this reads 600 nmol/L: FAI 1200.0 "Elevated". The opposite
        // band from the case above, so a fix that happened to bias one way is caught.
        let fromNgdl = faiVM()
        setUnit(fromNgdl, ngdl)
        fromNgdl.values.numbers["tt"] = 600
        XCTAssertEqual(row(fromNgdl, "Free Androgen Index"), "41.6")
        XCTAssertEqual(row(fromNgdl, "Band"), "Normal")
        let ngdlRows = fromNgdl.result.rows

        setUnit(fromNgdl, nmol)

        XCTAssertEqual(tt(fromNgdl), 20.8, accuracy: 1e-9)
        XCTAssertEqual(row(fromNgdl, "Free Androgen Index"), "41.6")
        XCTAssertEqual(row(fromNgdl, "Band"), "Normal")
        XCTAssertNotEqual(row(fromNgdl, "Band"), "Elevated",
                          "600 ng/dL was read as 600 nmol/L — the 28.84x the web warns about")
        XCTAssertEqual(fromNgdl.result.rows, ngdlRows)
    }

    /// The band must hold across the whole clinical span, not only at the two values
    /// above. Low / Normal / Elevated are each entered from both units.
    func testEveryBandSurvivesAFlipInBothDirections() {
        // (tt in nmol/L, SHBG, band)
        let cases: [(Double, Double, String)] = [
            (10, 50, "Low"),        // FAI 20.0
            (20, 50, "Normal"),     // FAI 40.0
            (35, 40, "Normal"),     // FAI 87.5
            (40, 20, "Elevated"),   // FAI 200.0
        ]
        for (value, shbg, band) in cases {
            let toNgdl = faiVM()
            toNgdl.values.numbers["shbg"] = shbg
            toNgdl.values.numbers["tt"] = value
            XCTAssertEqual(row(toNgdl, "Band"), band, "\(value) nmol/L should band \(band)")
            setUnit(toNgdl, ngdl)
            XCTAssertEqual(row(toNgdl, "Band"), band,
                           "\(value) nmol/L changed band on a flip to ng/dL")

            // And the same physical value entered the other way round.
            let converted = toNgdl.values.number("tt")
            let toNmol = faiVM()
            toNmol.values.numbers["shbg"] = shbg
            setUnit(toNmol, ngdl)
            toNmol.values.numbers["tt"] = converted
            XCTAssertEqual(row(toNmol, "Band"), band)
            setUnit(toNmol, nmol)
            XCTAssertEqual(row(toNmol, "Band"), band,
                           "\(converted) ng/dL changed band on a flip to nmol/L")
        }
    }

    // MARK: - The round trip, both directions

    /// nmol/L → ng/dL → nmol/L returns the original number, EXACTLY, for every
    /// two-decimal value. See the header for why this direction can be exact and the
    /// next one cannot.
    func testRoundTripFromNmol() {
        // Forward values computed by hand from `Math.round(v * 28.84 * 100) / 100`,
        // not from this implementation, so a wrong factor cannot agree with itself.
        let expected: [Double: Double] = [
            1: 28.84, 5: 144.2, 10: 288.4, 12.5: 360.5, 17.3: 498.93,
            20: 576.8, 20.8: 599.87, 25.35: 731.09, 34.67: 999.88,
            50: 1442, 100: 2884,
        ]
        for (start, inNgdl) in expected {
            let vm = faiVM()
            vm.values.numbers["tt"] = start

            setUnit(vm, ngdl)
            XCTAssertEqual(tt(vm), inNgdl, accuracy: 1e-9,
                           "\(start) nmol/L should read \(inNgdl) ng/dL")

            setUnit(vm, nmol)
            XCTAssertEqual(tt(vm), start, accuracy: 1e-9,
                           "\(start) nmol/L did not survive the trip through ng/dL")
        }
    }

    /// ng/dL → nmol/L → ng/dL. Started in ng/dL, so a converter that only handles one
    /// direction, or clamps in either, fails here.
    ///
    /// EXACT WHERE IT CAN BE — the values that sit on the nmol hundredth grid come
    /// back untouched — and inside ONE nmol hundredth everywhere else. The residual is
    /// the web's own rounding and nothing more; the largest here is 0.13 ng/dL on 600,
    /// which is 0.02% and three orders of magnitude under any assay's precision.
    func testRoundTripFromNgdl() {
        // Forward values from `Math.round(x / 28.84 * 100) / 100`, again by hand.
        let expected: [Double: Double] = [
            50: 1.73, 288.4: 10, 300: 10.4, 400: 13.87, 576.8: 20,
            600: 20.8, 800: 27.74, 1000: 34.67, 1500: 52.01, 2884: 100,
        ]
        for (start, inNmol) in expected {
            let vm = faiVM()
            setUnit(vm, ngdl)
            vm.values.numbers["tt"] = start

            setUnit(vm, nmol)
            XCTAssertEqual(tt(vm), inNmol, accuracy: 1e-9,
                           "\(start) ng/dL should read \(inNmol) nmol/L")

            setUnit(vm, ngdl)
            XCTAssertEqual(tt(vm), start, accuracy: nmolTick,
                           "\(start) ng/dL did not survive the trip through nmol/L")
        }

        // The three that ARE exact, asserted as exact. They are the images of whole
        // nmol/L values (10, 20 and the 100 ceiling), so nothing is rounded away in
        // either hop — and if the conversion ever stops being reversible at all, these
        // fail with no tolerance to hide in.
        for start: Double in [288.4, 576.8, 2884] {
            let vm = faiVM()
            setUnit(vm, ngdl)
            vm.values.numbers["tt"] = start
            setUnit(vm, nmol)
            setUnit(vm, ngdl)
            XCTAssertEqual(tt(vm), start, accuracy: 1e-9,
                           "\(start) ng/dL is on the nmol grid and must return exactly")
        }
    }

    /// A second flip must not move a value a first flip already settled. Without this,
    /// a conversion that drifts a little on every pass looks correct in a single-flip
    /// test and walks the number away over a session.
    func testRepeatedFlipsDoNotDrift() {
        let vm = faiVM()
        setUnit(vm, ngdl)
        vm.values.numbers["tt"] = 600

        setUnit(vm, nmol)
        let firstNmol = tt(vm)
        setUnit(vm, ngdl)
        let firstNgdl = tt(vm)

        for _ in 0..<10 {
            setUnit(vm, nmol)
            XCTAssertEqual(tt(vm), firstNmol, accuracy: 1e-9, "the value drifted in nmol/L")
            setUnit(vm, ngdl)
            XCTAssertEqual(tt(vm), firstNgdl, accuracy: 1e-9, "the value drifted in ng/dL")
        }
    }

    /// THE CLAMP TRAP, named — the reason the round trip is pinned in both directions
    /// rather than one. Before T-43 the field held ONE range in both units, `0...2000`;
    /// a "fix" that converted the value into a range that had not moved with it would
    /// clamp instead of convert, and a clamp is quiet: 600 ng/dL landing on a nmol/L
    /// ceiling is a smaller, entirely plausible number on the screen.
    func testConversionIsNotAClamp() {
        // The nmol/L ceiling converts to the ng/dL ceiling exactly — the bounds are
        // derived from one another, so nothing in range on one side is out of range on
        // the other, and there is no value the flip has to clamp.
        let atCeiling = faiVM()
        atCeiling.values.numbers["tt"] = 100
        setUnit(atCeiling, ngdl)
        XCTAssertEqual(tt(atCeiling), 2884, accuracy: 1e-9)

        // A real lab value, flipped to nmol/L. A clamp into the 0...100 nmol/L range
        // returns 100 — smaller than 600, well inside the plausible span for the unit,
        // and it passes any one-way check that only asks whether the number went down.
        let vm = faiVM()
        setUnit(vm, ngdl)
        vm.values.numbers["tt"] = 600
        setUnit(vm, nmol)
        XCTAssertEqual(tt(vm), 20.8, accuracy: 1e-9,
                       "600 ng/dL landed on the nmol/L ceiling — this is a clamp, not a conversion")
        XCTAssertNotEqual(tt(vm), 100, "the value was clamped to the nmol/L maximum")

        // And the same trap the other way: the old fixed 0...2000 would have clamped
        // nothing here, which is exactly why a one-way test would have missed it.
        let up = faiVM()
        up.values.numbers["tt"] = 90
        setUnit(up, ngdl)
        XCTAssertEqual(tt(up), 2595.6, accuracy: 1e-9,
                       "90 nmol/L is 2595.6 ng/dL — a 2000 ceiling would have clamped it")
    }

    /// Re-selecting the unit already selected, and ordinary edits, must not convert.
    /// `changeTtUnit` returns early on `u === ttUnit`; here nothing writes `values` at
    /// all unless the selector moved, so this pins that an SHBG edit cannot drag the TT
    /// through a conversion.
    func testOrdinaryEditsDoNotConvert() {
        let vm = faiVM()
        setUnit(vm, nmol)                     // already nmol/L — a no-op assignment
        XCTAssertEqual(tt(vm), 20, accuracy: 1e-9)
        vm.values.numbers["shbg"] = 35        // an ordinary edit, no unit change
        XCTAssertEqual(tt(vm), 20, accuracy: 1e-9)
        vm.values.numbers["tt"] = 24          // typing in the field itself
        XCTAssertEqual(tt(vm), 24, accuracy: 1e-9)
    }

    // MARK: - The bounds and the step move with the unit

    /// CONVERTING ALONE WOULD HAVE BEEN WRONG, which is the half of T-41 worth
    /// carrying over. The field held `0...2000` in BOTH units: that is a ng/dL
    /// ceiling — a lab-report figure — and read as nmol/L it admits 2000 nmol/L, an
    /// FAI of 4000. The bounds are now declared once in nmol/L and resolved into
    /// ng/dL, so each is the image of the other.
    func testBoundsAndStepFollowTheUnit() {
        let vm = faiVM()

        var b = bounds(ttField(vm))
        XCTAssertEqual(b.unit, "nmol/L", "the TT field must state its own unit")
        XCTAssertEqual(b.range?.lowerBound, 0)
        // 100 nmol/L, and NOT the old 2000 — which as nmol/L was 29x any real assay
        // result and would have let a typed 2000 stand as an FAI of 4000.
        XCTAssertEqual(b.range?.upperBound, 100)
        XCTAssertEqual(b.step ?? 0, 0.1, accuracy: 1e-12)

        setUnit(vm, ngdl)

        b = bounds(ttField(vm))
        XCTAssertEqual(b.unit, "ng/dL")
        XCTAssertEqual(b.range?.lowerBound, 0)
        // The image of 100 nmol/L, clear of any real result including a
        // supraphysiological peak — and above the 2000 the field used to stop at, so
        // the change cannot clamp a value that was previously accepted.
        XCTAssertEqual(b.range?.upperBound ?? 0, 2884, accuracy: 1e-9)
        XCTAssertEqual(b.step ?? 0, 2.88, accuracy: 1e-12)

        setUnit(vm, nmol)
        XCTAssertEqual(bounds(ttField(vm)).range?.upperBound, 100,
                       "the bounds did not come back")
    }

    /// The floor stays 0 in both units, deliberately. iOS clamps on EVERY KEYSTROKE
    /// where the web clamps on blur, so a non-zero floor rewrites the leading "0" of a
    /// part-typed value — recorded on the peptide dose in T-41 and true here too.
    func testTheFloorIsZeroInBothUnits() {
        let vm = faiVM()
        XCTAssertEqual(bounds(ttField(vm)).range?.lowerBound, 0)
        setUnit(vm, ngdl)
        XCTAssertEqual(bounds(ttField(vm)).range?.lowerBound, 0)
    }

    /// The engine's own constant and the spec's are the SAME conversion, stated once
    /// each and in opposite directions — the spec's `factor` is "base units per
    /// alternate unit", so it is the reciprocal of the 28.84 the engine divides by.
    /// If either is ever edited alone, the field and the result part company on the
    /// same screen and every number stays internally consistent while doing it.
    func testTheSpecAndTheEngineAgreeOnTheFactor() {
        let vm = faiVM()
        vm.values.numbers["shbg"] = 50
        vm.values.numbers["tt"] = 20
        let inNmol = CalculatorEngine.freeTestIndex(ttNum: 20, ttUnit: "nmol", shbgNum: 50)

        setUnit(vm, ngdl)
        let converted = tt(vm)
        let inNgdl = CalculatorEngine.freeTestIndex(ttNum: converted, ttUnit: "ngdl", shbgNum: 50)

        XCTAssertEqual(inNgdl.ttNmol, inNmol.ttNmol, accuracy: 1e-9,
                       "the spec's factor and the engine's disagree")
        XCTAssertEqual(inNgdl.fai, inNmol.fai, accuracy: 1e-9)
        XCTAssertEqual(inNgdl.band, inNmol.band)
    }
}
