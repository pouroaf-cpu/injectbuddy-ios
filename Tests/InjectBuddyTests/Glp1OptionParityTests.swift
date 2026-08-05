import XCTest
@testable import InjectBuddy

// ─── Glp1OptionParityTests  (T-45) ───────────────────────────────────────────
//
// Pins the three GLP-1 calculators' option ladders, their warning thresholds and
// the copy of the warnings themselves to the web.
//
// WHY THIS FILE EXISTS RATHER THAN A LINE IN CalculatorEngineTests. That file pins
// the ARITHMETIC — `dose / conc` — and the arithmetic was never wrong on any of
// these three screens. What was wrong was the set of numbers the arithmetic could
// be handed: iOS shipped the first 12 / 11 / 7 / 16 entries of the web's four
// arrays, each dose list cut at exactly the value the web WARNS about, so the app
// enforced the ceiling by deleting the option instead of by explaining it. A test
// of the formula is green through all of that.
//
// THE EXPECTATIONS BELOW ARE TRANSCRIBED FROM `public/app.js`, NOT FROM THE SWIFT.
// A test that reads `CalcConst.semaDoses` and asserts things about it agrees with
// whatever ships. These are the literal arrays, checked on 2026-08-04 against three
// sources that agree to the value:
//
//   • the web working tree at ~/injectbuddy (`master`), lines 3720–3723
//   • `feature/dosage-status-model` — `git show FETCH_HEAD:public/app.js`
//   • the DEPLOYED bundle, `https://www.injectbuddy.com/app.js?v=e10ca869`
//
// Re-derive them from the source, never from this file, if they ever have to move.

final class Glp1OptionParityTests: XCTestCase {

    private let acc = 0.0001

    // MARK: - The four arrays, verbatim from app.js

    /// `SEMA_DOSE_VALUES` — 22 values, 0 … 7.5.
    private let webSemaDoses: [Double] = [
        0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.4, 2.5,
        3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5,
    ]
    /// `TIRZ_DOSE_VALUES` — 17 values, 0 … 40.
    private let webTirzDoses: [Double] = [
        0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5, 35, 37.5, 40,
    ]
    /// `RETA_DOSE_VALUES` — 22 values, 0 … 24.
    private let webRetaDoses: [Double] = [
        0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
        14, 16, 18, 20, 22, 24,
    ]
    /// `GLP1_CONC_VALUES` — 17 values, 0 … 60. Shared by all three pages.
    private let webGlp1Concs: [Double] = [
        0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60,
    ]

    private func assertSameLadder(_ swift: [Double], _ web: [Double],
                                  _ name: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        // Length FIRST and as its own assertion: the defect was a prefix, and a
        // zip-based comparison of a prefix against the whole is green.
        XCTAssertEqual(swift.count, web.count,
                       "\(name): \(swift.count) values, web has \(web.count)",
                       file: file, line: line)
        let swiftLast: Double? = swift.last
        let webLast: Double? = web.last
        XCTAssertEqual(swiftLast, webLast,
                       "\(name) stops at \(swiftLast.map { "\($0)" } ?? "nothing"), web runs to \(webLast!)",
                       file: file, line: line)
        for (i, expected) in web.enumerated() where i < swift.count {
            XCTAssertEqual(swift[i], expected, accuracy: acc,
                           "\(name)[\(i)]", file: file, line: line)
        }
    }

    func testSemaDoseLadderMatchesWeb() {
        assertSameLadder(CalcConst.semaDoses, webSemaDoses, "semaDoses")
        XCTAssertEqual(CalcConst.semaDoses.count, 22)
    }

    func testTirzDoseLadderMatchesWeb() {
        assertSameLadder(CalcConst.tirzDoses, webTirzDoses, "tirzDoses")
        XCTAssertEqual(CalcConst.tirzDoses.count, 17)
    }

    func testRetaDoseLadderMatchesWeb() {
        assertSameLadder(CalcConst.retaDoses, webRetaDoses, "retaDoses")
        XCTAssertEqual(CalcConst.retaDoses.count, 22)
    }

    func testConcLadderMatchesWeb() {
        assertSameLadder(CalcConst.glp1Concs, webGlp1Concs, "glp1Concs")
        XCTAssertEqual(CalcConst.glp1Concs.count, 17)
    }

    /// THE SHAPE OF THE OLD DEFECT, asserted directly so a future truncation is
    /// caught as the specific thing it is rather than as a count that drifted.
    ///
    /// Each list must extend PAST its own warning threshold. If it stops at the
    /// threshold, the app is refusing the dose instead of flagging it, and the
    /// warning branch below becomes unreachable — which is precisely how the
    /// warnings came to be missing in the first place.
    func testEveryDoseLadderExtendsPastItsWarningThreshold() {
        let cases: [(CalculatorSlug, [Double])] = [
            (.semaglutide, CalcConst.semaDoses),
            (.tirzepatide, CalcConst.tirzDoses),
            (.retatrutide, CalcConst.retaDoses),
        ]
        for (slug, ladder) in cases {
            guard let maxMg = CalcConst.weeklyMaxMg(for: slug) else {
                return XCTFail("\(slug) has no weekly maximum")
            }
            XCTAssertTrue(ladder.contains { $0 > maxMg },
                          "\(slug) ladder ends at \(ladder.last!), at or below its own \(maxMg) mg warning threshold — the ceiling is being enforced by deletion again")
            XCTAssertTrue(ladder.contains { abs($0 - maxMg) < acc },
                          "\(slug) ladder no longer contains the threshold value \(maxMg) itself")
        }
    }

    // MARK: - Thresholds and copy

    /// `isValid && dose > N` on the three pages: 2.4 / 15 / 12.
    func testWeeklyMaximaMatchWeb() {
        XCTAssertEqual(CalcConst.weeklyMaxMg(for: .semaglutide), 2.4)
        XCTAssertEqual(CalcConst.weeklyMaxMg(for: .tirzepatide), 15)
        XCTAssertEqual(CalcConst.weeklyMaxMg(for: .retatrutide), 12)
        // Only the GLP-1 trio carries one. The web raises this InfoBox on no other page.
        XCTAssertNil(CalcConst.weeklyMaxMg(for: .trt))
        XCTAssertNil(CalcConst.weeklyMaxMg(for: .peptide))
        XCTAssertNil(CalcConst.weeklyMaxMg(for: .bpc157))
        XCTAssertNil(CalcConst.weeklyMaxMg(for: .hcg))
    }

    /// The strings, to the character. The em dash is U+2014, as in `app.js`; an
    /// ASCII hyphen here would be a silent copy divergence that reads fine.
    func testWarningCopyIsTheWebs() {
        XCTAssertEqual(CalcConst.weeklyMaxNote(2.4),
                       "Exceeds typical weekly maximum of 2.4 mg \u{2014} verify with your prescriber.")
        XCTAssertEqual(CalcConst.weeklyMaxNote(15),
                       "Exceeds typical weekly maximum of 15 mg \u{2014} verify with your prescriber.")
        XCTAssertEqual(CalcConst.weeklyMaxNote(12),
                       "Exceeds typical weekly maximum of 12 mg \u{2014} verify with your prescriber.")
        XCTAssertEqual(CalcConst.subUnitDrawNote,
                       "Draw is less than 1 unit \u{2014} accuracy may be limited at this scale.")
    }

    /// A whole-number maximum prints without a decimal point — `15 mg`, not `15.0 mg`.
    /// The web interpolates a JS number, so this is what its sentence reads.
    func testWeeklyMaxNoteFormatsWholeNumbersWithoutADecimal() {
        XCTAssertTrue(CalcConst.weeklyMaxNote(15).contains("of 15 mg"))
        XCTAssertTrue(CalcConst.weeklyMaxNote(2.4).contains("of 2.4 mg"))
    }

    // MARK: - The warnings actually firing

    private func evaluate(_ slug: CalculatorSlug, conc: Double, dose: Double) -> CalculatorResult {
        var v = CalculatorValues()
        v.numbers["conc"] = conc
        v.numbers["dose"] = dose
        return CalculatorEngine.evaluate(slug: slug, values: v, scale: .u100)
    }

    func testOverMaximumWarningFiresJustAboveTheThresholdAndNotAtIt() {
        let cases: [(CalculatorSlug, Double)] = [
            (.semaglutide, 2.4), (.tirzepatide, 15), (.retatrutide, 12),
        ]
        for (slug, maxMg) in cases {
            // `dose > N`, strictly. The threshold value itself is a normal dose —
            // 2.4 mg is the Wegovy label dose, not an excess.
            let at = evaluate(slug, conc: 10, dose: maxMg)
            XCTAssertFalse(at.notes.contains(CalcConst.weeklyMaxNote(maxMg)),
                           "\(slug) warns AT its own maximum \(maxMg)")

            // One ladder step above. Uses the real next value from the array rather
            // than an epsilon, so this is a dose the user can actually reach.
            let ladder: [Double] = slug == .semaglutide ? CalcConst.semaDoses
                                 : slug == .tirzepatide ? CalcConst.tirzDoses
                                 : CalcConst.retaDoses
            guard let above = ladder.first(where: { $0 > maxMg }) else {
                return XCTFail("\(slug) ladder has nothing above \(maxMg)")
            }
            let over = evaluate(slug, conc: 10, dose: above)
            XCTAssertTrue(over.isValid)
            XCTAssertEqual(over.notes.first, CalcConst.weeklyMaxNote(maxMg),
                           "\(slug) at \(above) mg raised \(over.notes)")
        }
    }

    /// `isValid && volumeMl < 0.01`. conc 60, dose 0.5 → 0.00833 mL, under one unit.
    func testSubUnitDrawWarningFires() {
        let r = evaluate(.semaglutide, conc: 60, dose: 0.5)
        XCTAssertEqual(r.drawMl!, 0.008333, accuracy: 0.0001)
        XCTAssertEqual(r.notes, [CalcConst.subUnitDrawNote])
    }

    func testSubUnitDrawWarningIsSilentAtExactlyOneUnit() {
        // conc 50, dose 0.5 → exactly 0.01 mL. `< 0.01` is strict, so no note.
        let r = evaluate(.semaglutide, conc: 50, dose: 0.5)
        XCTAssertEqual(r.drawMl!, 0.01, accuracy: 0.00001)
        XCTAssertTrue(r.notes.isEmpty, "warned at exactly one unit: \(r.notes)")
    }

    /// Both warnings are gated on `isValid`, exactly as the web gates them. An
    /// incomplete form has no dose to be over a maximum and no draw to be under a
    /// unit, and a warning on a blank form teaches the user to ignore the next one.
    func testNoWarningsOnAnIncompleteForm() {
        XCTAssertTrue(evaluate(.retatrutide, conc: 0, dose: 24).notes.isEmpty)
        XCTAssertTrue(evaluate(.retatrutide, conc: 5, dose: 0).notes.isEmpty)
    }

    /// Every other calculator keeps an empty `notes`, so nothing new renders on the
    /// twelve screens this task did not touch.
    func testNonGlp1CalculatorsRaiseNoNotes() {
        var v = CalculatorValues()
        v.numbers["strength"] = 200
        v.numbers["mgWeek"] = 100
        v.numbers["injPerWeek"] = 2
        v.strings["mode"] = "perweek"
        XCTAssertTrue(CalculatorEngine.evaluate(slug: .trt, values: v, scale: .u100).notes.isEmpty)
    }

    // MARK: - Reachability: the list is no longer the ceiling

    /// The control's SHAPE, which is half of what made the short list dangerous. A
    /// `.picker` is a closed `Menu`, so its options are the complete set of values
    /// the app can express; a `.number` accepts a typed value clamped to a range.
    func testConcAndDoseAcceptTypedEntryOnAllThreeGlp1Calculators() {
        for slug in [CalculatorSlug.semaglutide, .tirzepatide, .retatrutide] {
            let fields = CalculatorCatalog.spec(for: slug).fields
            for key in ["conc", "dose"] {
                guard let f = fields.first(where: { $0.key == key }) else {
                    return XCTFail("\(slug) has no \(key) field")
                }
                guard case let .number(_, _, range, _) = f.kind else {
                    return XCTFail("\(slug).\(key) is not a typed field — a closed picker makes its option list the ceiling again")
                }
                XCTAssertNotNil(range, "\(slug).\(key) has no range to clamp to")
            }
        }
    }

    /// The typed range is the web array's own bounds, and the ruler beside the field
    /// is the whole array.
    func testTypedRangeAndRulerComeFromTheWebArrays() {
        let expected: [(CalculatorSlug, [Double])] = [
            (.semaglutide, webSemaDoses), (.tirzepatide, webTirzDoses), (.retatrutide, webRetaDoses),
        ]
        for (slug, ladder) in expected {
            let fields = CalculatorCatalog.spec(for: slug).fields

            let dose = fields.first { $0.key == "dose" }!
            guard case let .number(_, _, doseRange, _) = dose.kind else { return XCTFail("dose not numeric") }
            XCTAssertEqual(doseRange?.lowerBound, ladder.first!)
            XCTAssertEqual(doseRange?.upperBound, ladder.last!)
            XCTAssertEqual(dose.drum, ladder, "\(slug) dose ruler")

            let conc = fields.first { $0.key == "conc" }!
            guard case let .number(_, _, concRange, _) = conc.kind else { return XCTFail("conc not numeric") }
            XCTAssertEqual(concRange?.lowerBound, webGlp1Concs.first!)
            XCTAssertEqual(concRange?.upperBound, webGlp1Concs.last!)
            XCTAssertEqual(conc.drum, webGlp1Concs, "\(slug) conc ruler")
        }
    }

    /// THE 25 mg/mL VIAL — the case that named this task.
    ///
    /// The old list stopped at 20, so a user holding a 25 mg/mL compounded vial had
    /// no correct option and the nearest was 20. That is not a rounding error: the
    /// draw computed from 20 is 25 % larger than the true one, on a screen that
    /// looks entirely normal. Asserted as arithmetic rather than as a UI claim so it
    /// stays true without the simulator.
    func testTwentyFiveMgPerMlIsReachableAndTheOldNearestOptionOverDrew() {
        XCTAssertTrue(CalcConst.glp1Concs.contains(25))

        let truth = CalculatorEngine.glp1(conc: 25, dose: 0.5)
        let nearestOldOption = CalculatorEngine.glp1(conc: 20, dose: 0.5)
        XCTAssertEqual(truth.volumeMl, 0.02, accuracy: acc)
        XCTAssertEqual(truth.units, 2, accuracy: acc)
        XCTAssertEqual(nearestOldOption.volumeMl, 0.025, accuracy: acc)
        XCTAssertEqual(nearestOldOption.units, 3, accuracy: acc)
        XCTAssertEqual(nearestOldOption.volumeMl / truth.volumeMl, 1.25, accuracy: acc)

        // And it survives the field's clamp, which is the part the ladder alone
        // could not give: 25 is inside the range, so a typed 25 is kept.
        let conc = CalculatorCatalog.spec(for: .semaglutide).fields.first { $0.key == "conc" }!
        guard case let .number(_, _, range, _) = conc.kind, let range else {
            return XCTFail("conc field lost its range")
        }
        XCTAssertTrue(range.contains(25))
    }

    /// A strength the web's OWN FAQ names — *"some compounders produce 2 mg/mL,
    /// 7.5 mg/mL, or 12 mg/mL formulations"* — and one that is NOT on the ladder.
    /// It is reachable only because the field takes typed entry, which is the whole
    /// argument for the control change: a longer list would still not reach it.
    func testAnOffLadderConcentrationFromTheWebsOwnFaqIsStillReachable() {
        XCTAssertFalse(CalcConst.glp1Concs.contains(12),
                       "12 mg/mL is on the ladder now — pick another off-ladder value for this test")
        let conc = CalculatorCatalog.spec(for: .retatrutide).fields.first { $0.key == "conc" }!
        guard case let .number(_, _, range, _) = conc.kind, let range else {
            return XCTFail("conc field lost its range")
        }
        XCTAssertTrue(range.contains(12))

        let r = CalculatorEngine.glp1(conc: 12, dose: 3)
        XCTAssertEqual(r.volumeMl, 0.25, accuracy: acc)
    }

    // MARK: - The config fingerprint must not have moved

    /// THE TRAP THIS TASK WAS WARNED ABOUT. `saved_dosages` de-duplicates on the
    /// WHOLE config via a unique index on (user_id, calculator_type, config), so a
    /// key set that drifted by one would make every iOS save a different protocol
    /// from the equivalent web row.
    ///
    /// `.picker` and `.number` both encode through `case .number` in `configJSON()`,
    /// so swapping the control is key-set-neutral BY CONSTRUCTION — and this asserts
    /// it rather than trusting it. Semaglutide's six keys and the other two's three
    /// are UNCHANGED from before T-45, including the two that are known to be wrong
    /// (T-01b-4 #2 / T-01b-5 #2): fixing them is a separate, reported decision about
    /// rows that already exist, and doing it inside this commit would have hidden it.
    @MainActor
    func testConfigKeySetsAreUnchangedByTheControlSwap() {
        let expected: [CalculatorSlug: Set<String>] = [
            .semaglutide: ["conc", "dose", "syringeMl", "mode", "nDays", "injPerWeek"],
            .tirzepatide: ["conc", "dose", "syringeMl"],
            .retatrutide: ["conc", "dose", "syringeMl"],
        ]
        for (slug, keys) in expected {
            let vm = CalculatorViewModel(slug: slug)
            guard case let .object(obj) = vm.configJSON() else {
                return XCTFail("\(slug) config is not an object")
            }
            XCTAssertEqual(Set(obj.keys), keys, "\(slug) config key set")
            // And the two fields this task touched are still NUMBERS, not strings.
            XCTAssertNotNil(obj["conc"]?.double)
            XCTAssertNotNil(obj["dose"]?.double)
        }
    }

    /// The defaults are untouched, so an untouched save writes exactly what the
    /// previous build wrote. Changing them is SH-5's job, filed separately.
    @MainActor
    func testDefaultsAreUnchanged() {
        let expected: [(CalculatorSlug, Double, Double)] = [
            (.semaglutide, 5, 0.5), (.tirzepatide, 7.5, 5), (.retatrutide, 5, 1),
        ]
        for (slug, conc, dose) in expected {
            let vm = CalculatorViewModel(slug: slug)
            XCTAssertEqual(vm.values.number("conc"), conc, accuracy: acc, "\(slug) conc default")
            XCTAssertEqual(vm.values.number("dose"), dose, accuracy: acc, "\(slug) dose default")
            XCTAssertEqual(vm.values.number("syringeMl"), 1, accuracy: acc, "\(slug) barrel default")
        }
    }
}
