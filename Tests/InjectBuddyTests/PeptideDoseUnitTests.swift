import XCTest
@testable import InjectBuddy

// ─── PeptideDoseUnitTests ────────────────────────────────────────────────────
// T-41. The peptide `Dose unit` picker used to change the unit and leave the
// number: 500 mcg became 500 mg, and every figure the engine produced from it —
// draw volume, units, weekly total, doses per vial — was internally consistent
// with a dose 1000× larger than the one entered.
//
// WHAT THESE TESTS ARE WRITTEN AGAINST, and it is not this repo's own reading of
// the web. `public/app.js` on `feature/dosage-status-model`, read directly:
//
//   6237  const handleUnitToggle = newUnit => {
//   6238    if (newUnit === doseUnit) return;
//   6239    const converted = newUnit === 'mg'
//   6240      ? Number((dosePerInj / 1000).toFixed(3))
//   6241      : Number((dosePerInj * 1000).toFixed(0));
//   6242    setDosePerInj(converted); ...
//
//   6232  const doseMin  = doseUnit === 'mcg' ? 1     : 0.001;
//   6233  const doseMax  = doseUnit === 'mcg' ? 20000 : 20;
//   6234  const doseStep = doseUnit === 'mcg' ? 1     : 0.001;
//
//   6335  const config = {peptideType, peptideMg, bawMl, dosePerInj, doseUnit,
//                        injPerWeek, syringeMl};
//
// THE ROUND TRIP IS THE POINT. A test that only asserts mcg → mg divides passes
// on an implementation that CLAMPS instead of converting — 500 mcg into a
// 0…20 mg range clamps to 20, which is smaller, plausible, and wrong. So both
// directions are pinned, and pinned to RETURN THE ORIGINAL NUMBER.

@MainActor
final class PeptideDoseUnitTests: XCTestCase {

    private let mcg: Double = 1   // doseUnitMcg picker values
    private let mg: Double = 0

    private func peptideVM() -> CalculatorViewModel { CalculatorViewModel(slug: .peptide) }

    private func dose(_ vm: CalculatorViewModel) -> Double { vm.values.number("dosePerInj") }

    private func setUnit(_ vm: CalculatorViewModel, _ unit: Double) {
        vm.values.numbers["doseUnitMcg"] = unit
    }

    private func doseField(_ vm: CalculatorViewModel) -> CalculatorInput {
        guard let f = vm.fields.first(where: { $0.key == "dosePerInj" }) else {
            XCTFail("peptide spec has no dosePerInj field")
            return .number("missing", "missing", default: 0)
        }
        return f
    }

    private func bounds(_ f: CalculatorInput) -> (unit: String?, range: ClosedRange<Double>?, step: Double?) {
        guard case let .number(unit, _, range, step) = f.kind else {
            XCTFail("dosePerInj is not a number field")
            return (nil, nil, nil)
        }
        return (unit, range, step)
    }

    // MARK: - The defect itself

    /// The shipped default, flipped once. This is the frame the task asks for, as an
    /// assertion: 500 mcg must read 0.5 mg, not 500 mg.
    func testFlippingToMgConvertsTheShippedDefault() {
        let vm = peptideVM()
        XCTAssertEqual(dose(vm), 500, accuracy: 1e-9, "spec default changed")
        setUnit(vm, mg)
        XCTAssertEqual(dose(vm), 0.5, accuracy: 1e-9)
    }

    /// And the engine agrees with the field. The invariant the whole screen rests on
    /// is that the number DISPLAYED is the number USED, so a flip that only renames
    /// the unit must not move the dose.
    ///
    /// ── WHY THIS NO LONGER COMPARES THE WHOLE `CalculatorResult` ─────────────────
    ///
    /// It did, and it went red when T-41 and T-52 were merged — on a tree where BOTH
    /// changes are correct. Worth writing down, because "a red test after a merge"
    /// normally means one side is wrong and here neither was.
    ///
    /// T-52 added `dosePerInjection` to `CalculatorResult`, and it deliberately carries
    /// **the user's own unit**, not the engine's internal mg — its own note says a
    /// peptide dosed at 350 mcg must not come back as "0.35 mg", "the same dose written
    /// in a way its owner never states it". So after a flip the struct legitimately
    /// differs in exactly that field: `500 mcg` becomes `0.5 mg`. Every rendered row is
    /// byte-identical (`0.100 mL`, `10` units, `5.00 mg/mL`, `0.500 mg` weekly,
    /// `100.0` doses) and so is `drawMl` — the maths never moved.
    ///
    /// A whole-struct compare therefore asserts something stronger than the invariant:
    /// it demands the RESULT be unchanged, when what must be unchanged is the DOSE.
    /// Weakening it to "rows only" would have been the easy fix and the wrong one — it
    /// would stop checking the thing T-41 exists to prevent. So the dose is still
    /// asserted, in the one form that survives a rename: same physical quantity,
    /// expressed in the unit now selected.
    func testTheEngineSeesTheSameDoseAfterAFlip() {
        let vm = peptideVM()
        let before = vm.result
        setUnit(vm, mg)

        // Everything the user reads must be untouched.
        XCTAssertEqual(vm.result.rows, before.rows,
                       "a unit flip changed a displayed row — the value did not convert")
        XCTAssertEqual(vm.result.drawMl, before.drawMl,
                       "a unit flip changed the draw volume — the value did not convert")
        XCTAssertEqual(vm.result.scheduleLine, before.scheduleLine)
        XCTAssertEqual(vm.result.isValid, before.isValid)

        // And the structured dose is the SAME DOSE, restated. 500 mcg = 0.5 mg.
        // If the conversion is ever removed this reads 500 mg and fails here, which is
        // the defect T-41 was filed for.
        guard let after = vm.result.dosePerInjection,
              let start = before.dosePerInjection else {
            return XCTFail("peptide stopped reporting a structured dose per injection")
        }
        XCTAssertEqual(start.unit, "mcg")
        XCTAssertEqual(after.unit, "mg")
        XCTAssertEqual(after.value, start.value / 1000, accuracy: 1e-9,
                       "the structured dose did not convert with the unit — a card or a "
                       + "logged row would state a dose 1000x wrong")
    }

    // MARK: - The round trip, both directions

    /// mcg → mg → mcg returns the original number.
    func testRoundTripFromMcg() {
        for start: Double in [1, 50, 250, 500, 750, 1000, 2000, 1234, 12345, 20000] {
            let vm = peptideVM()
            vm.values.numbers["dosePerInj"] = start

            setUnit(vm, mg)
            let inMg = dose(vm)
            XCTAssertEqual(inMg, start / 1000, accuracy: 1e-9,
                           "\(start) mcg should read \(start / 1000) mg")

            setUnit(vm, mcg)
            XCTAssertEqual(dose(vm), start, accuracy: 1e-9,
                           "\(start) mcg did not survive the trip through mg")
        }
    }

    /// mg → mcg → mg returns the original number. Started in mg, so a converter that
    /// only handles one direction, or clamps in either, fails here.
    func testRoundTripFromMg() {
        for start: Double in [0.001, 0.25, 0.5, 0.75, 1, 2, 2.5, 12.345, 20] {
            let vm = peptideVM()
            setUnit(vm, mg)
            vm.values.numbers["dosePerInj"] = start

            setUnit(vm, mcg)
            let inMcg = dose(vm)
            XCTAssertEqual(inMcg, start * 1000, accuracy: 1e-9,
                           "\(start) mg should read \(start * 1000) mcg")

            setUnit(vm, mg)
            XCTAssertEqual(dose(vm), start, accuracy: 1e-9,
                           "\(start) mg did not survive the trip through mcg")
        }
    }

    /// THE CLAMP TRAP, named. 500 mcg is 0.5 mg; a clamp into the 0…20 mg range
    /// returns 20, which is smaller than 500, looks plausible on the screen, and
    /// passes any one-way "the number got smaller" check.
    /// A FRESH VM PER CASE, and the first draft of this test is the reason. It set
    /// 20000, flipped to mg, then set 500 on the SAME view model — which was by then in
    /// mg, so it was setting 500 mg, and the assertion that 500 should become 0.5 was
    /// asking the wrong question of a correct implementation. The unit a bare number is
    /// in is exactly what this defect is about; a test that loses track of it is
    /// reproducing the bug rather than catching it.
    func testConversionIsNotAClamp() {
        // The mcg ceiling converts to the mg ceiling exactly — the bounds are derived
        // from one another, so nothing in range on one side is out of range on the other.
        let atCeiling = peptideVM()
        atCeiling.values.numbers["dosePerInj"] = 20000
        setUnit(atCeiling, mg)
        XCTAssertEqual(dose(atCeiling), 20, accuracy: 1e-9)

        // THE TRAP THE WINDOWS SIDE NAMED. A clamp into the 0…20 mg range takes 500 mcg
        // to 20 — smaller, plausible on screen, and passes any one-way check that only
        // asks whether the number went down.
        let vm = peptideVM()
        XCTAssertEqual(dose(vm), 500, accuracy: 1e-9, "not starting from 500 mcg")
        setUnit(vm, mg)
        XCTAssertEqual(dose(vm), 0.5, accuracy: 1e-9,
                       "500 mcg landed on the mg ceiling — this is a clamp, not a conversion")
        XCTAssertNotEqual(dose(vm), 20, "the value was clamped to the mg maximum")
    }

    /// Re-selecting the unit already selected must not convert. `handleUnitToggle`
    /// returns early on `newUnit === doseUnit`; here nothing writes `values` at all, so
    /// this pins that a no-op assignment of the same value cannot double-convert.
    func testReselectingTheSameUnitDoesNotConvert() {
        let vm = peptideVM()
        setUnit(vm, mcg)
        XCTAssertEqual(dose(vm), 500, accuracy: 1e-9)
        vm.values.numbers["peptideMg"] = 25   // an ordinary edit, no unit change
        XCTAssertEqual(dose(vm), 500, accuracy: 1e-9)
    }

    // MARK: - The bounds, the step and the chips move with the unit

    func testBoundsStepAndChipsFollowTheUnit() {
        let vm = peptideVM()

        var f = doseField(vm)
        var b = bounds(f)
        XCTAssertEqual(b.unit, "mcg")
        XCTAssertEqual(b.range?.lowerBound, 0)
        XCTAssertEqual(b.range?.upperBound, 20000)
        XCTAssertEqual(b.step, 1)
        XCTAssertEqual(f.quick, [250, 500, 750, 1000, 2000])

        setUnit(vm, mg)

        f = doseField(vm)
        b = bounds(f)
        XCTAssertEqual(b.unit, "mg")
        XCTAssertEqual(b.range?.lowerBound, 0)
        // 20, and NOT the old fixed 10000. iOS's own default of 500 in mg mode was
        // 25× the web's entire allowable maximum.
        XCTAssertEqual(b.range?.upperBound, 20)
        XCTAssertEqual(b.step ?? 0, 0.001, accuracy: 1e-12)
        XCTAssertEqual(f.quick, [0.25, 0.5, 0.75, 1, 2])

        setUnit(vm, mcg)
        b = bounds(doseField(vm))
        XCTAssertEqual(b.range?.upperBound, 20000, "the bounds did not come back")
    }

    /// The other thirteen calculators declare no unit scaling, so resolution is
    /// identity for them. Guards against the mechanism quietly rewriting a spec it was
    /// never meant to touch.
    func testResolutionIsIdentityForCalculatorsWithoutAUnitSelector() {
        for slug in CalculatorSlug.allCases where slug != .peptide && slug != .cyclePlotter {
            let spec = CalculatorCatalog.spec(for: slug)
            let values = CalculatorValues.defaults(for: spec.fields)
            XCTAssertEqual(spec.resolvedFields(values), spec.fields, "\(slug) was rewritten")
            XCTAssertNil(spec.convertingUnits(from: values, to: values), "\(slug) converted")
        }
    }

    // MARK: - The saved config shape

    /// THE PART MOST LIKELY TO GO WRONG SILENTLY. The database de-duplicates on the
    /// WHOLE config, so a changed key set makes every iOS save a different protocol
    /// from the equivalent web row.
    ///
    /// The web saves the DISPLAYED value in the CURRENT unit — `app.js:6335` puts
    /// `dosePerInj` and `doseUnit` into the config side by side, and `dosePerInj` is
    /// the state `handleUnitToggle` has just converted. It is NOT canonicalised to mg.
    /// So a dose of 0.5 mg saves as `{dosePerInj: 0.5, doseUnit: "mg"}`, never as
    /// `{dosePerInj: 500, doseUnit: "mg"}` and never as `500` with the unit dropped.
    func testSavedConfigCarriesTheDisplayedValueAndItsUnit() throws {
        let vm = peptideVM()

        var obj = try XCTUnwrap(vm.configJSON().object)
        XCTAssertEqual(obj["dosePerInj"]?.double, 500)
        XCTAssertEqual(obj["doseUnit"]?.string, "mcg")
        let mcgKeys = Set(obj.keys)

        setUnit(vm, mg)

        obj = try XCTUnwrap(vm.configJSON().object)
        XCTAssertEqual(obj["dosePerInj"]?.double, 0.5,
                       "the config must carry the value AS DISPLAYED, not canonicalised to mcg")
        XCTAssertEqual(obj["doseUnit"]?.string, "mg")
        XCTAssertNil(obj["doseUnitMcg"], "the iOS picker key must never reach the config")

        // THE KEY SET IS UNCHANGED, in both units and by the fix.
        XCTAssertEqual(Set(obj.keys), mcgKeys)
        XCTAssertEqual(Set(obj.keys),
                       ["peptideMg", "bawMl", "dosePerInj", "injPerWeek", "syringeMl",
                        "doseUnit", "peptideType"])
    }

    /// And the inverse survives it: a saved mg protocol reopens in mg, at the value it
    /// was saved at, without a conversion being applied to a value that was never
    /// toggled.
    func testASavedMgConfigRestoresUnconverted() {
        let vm = peptideVM()
        setUnit(vm, mg)
        vm.values.numbers["dosePerInj"] = 2.5

        let restored = CalculatorCatalog.values(fromConfig: vm.configJSON(), slug: .peptide)
        XCTAssertEqual(restored.number("dosePerInj"), 2.5, accuracy: 1e-9)
        XCTAssertEqual(restored.number("doseUnitMcg"), 0, accuracy: 1e-9)
    }
}
