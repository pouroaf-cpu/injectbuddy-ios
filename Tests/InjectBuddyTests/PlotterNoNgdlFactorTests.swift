import XCTest
@testable import InjectBuddy

// ─── PlotterNoNgdlFactorTests ────────────────────────────────────────────────
//
// T-42. The plotter multiplied its curve by `CalculatorEngine.testoNgdlFactor =
// 13.5` whenever every selected compound was a testosterone, and titled the axis
// `Estimated level (ng/dL)`. On the shipped default — 100 mg/week Test E, 12
// weeks — the model peaks at 118.56 and the scaled curve peaked at 1,600.5,
// which is the units AND the range of a real serum testosterone result. A
// number labelled ng/dL invites comparison against bloodwork, and a user whose
// lab disagrees with the curve has been given a reason to change a dose.
//
// ─── WHY ONE SCALAR COULD NEVER HAVE BEEN RIGHT ─────────────────────────────
//
// The live plotter publishes its own answer, and it names what a real conversion
// needs — `public/legacy/cycle-plotter/index.html:2297` on
// `feature/dosage-status-model`:
//
//   "Absolute serum concentrations (in ng/dL) require compound-specific
//    pharmacokinetic parameters including volume of distribution and
//    bioavailability that are not reliably available for all compounds."
//
// Volume of distribution and bioavailability, BOTH COMPOUND-SPECIFIC. iOS used
// ONE GLOBAL CONSTANT. One scalar cannot encode a per-compound parameter, let
// alone two. The factor was gated on all-testosterone selections, so 13.5 stood
// in for the Vd AND bioavailability of four different esters at once —
// enanthate, cypionate, propionate, undecanoate, half-lives 4.5 / 6.0 / 0.8 /
// 21.0 days — and no single value is correct for all four. So the number was not
// merely uncalibrated: it was structurally incapable of being right, while
// wearing the units of a test the user can go and have taken, on a screen whose
// compound list runs to 27 rows.
//
// `ng/dL` appears NOWHERE in `public/legacy/cycle-plotter/pk.js` — not an axis,
// not a label, not a computation. `spec/math-spec.md` §4.1, in a sentence
// written for ports: "A port must not add a unit conversion here."
//
// ─── WHAT MAKES THESE ASSERTIONS ABLE TO FAIL ───────────────────────────────
//
// A test that pinned a RECORDED curve would pass forever and would be
// re-baselined the moment someone changed the factor — the "reference recorded
// from a broken state" trap CLAUDE.md names for snapshots. So nothing here is a
// hardcoded expected curve. Every expectation is recomputed from
// `CalculatorEngine.pkBuildEntries` / `pkTotalLevel` — the model itself — at the
// series' own sample days. A reintroduced scalar of ANY value makes the shipped
// series differ from the model output, whatever the scalar is, so it cannot be
// absorbed by updating a number in this file.
//
// `test_theComparisonWouldCatchAScalar` proves that discriminates, by running
// the same comparison against a deliberately scaled curve and requiring it to
// fail. Without it, "series == model" would also pass on an implementation where
// this test computed the model wrongly in the same direction.
@MainActor
final class PlotterNoNgdlFactorTests: XCTestCase {

    /// The factor that was applied. Named ONCE, only so the defect can be
    /// reproduced inside `test_theComparisonWouldCatchAScalar` and so the
    /// 1,500-range claim is checked rather than asserted in prose. Nothing under
    /// test reads it — `CalculatorEngine.testoNgdlFactor` is deleted.
    private let deletedFactor: Double = 13.5

    /// The rounding the view model applies to every plotted point
    /// (`(lvl * 10000).rounded() / 10000`), and therefore the entire error budget
    /// of a series-vs-model comparison. Derived from the code, not tuned until a
    /// test went green: half of one ten-thousandth, with a little slack for the
    /// double arithmetic either side of it.
    private let plottedTick: Double = 1e-4

    /// The model, evaluated independently of the view model. Same inputs, same
    /// engine entry points, no scaling of any kind.
    private func modelCurve(compoundId: String,
                            dose: Double,
                            freqDays: Double,
                            cycleWeeks: Int,
                            at days: [Double]) throws -> [Double] {
        let c = try XCTUnwrap(PlotterCompound.all.first { $0.id == compoundId },
                              "\(compoundId) is not in the plotter table")
        let entries = CalculatorEngine.pkBuildEntries(
            halfLife: c.halfLife, tmax: c.tmax, dose: dose,
            freqDays: freqDays, cycleDays: Double(cycleWeeks) * 7)
        return days.map { CalculatorEngine.pkTotalLevel(t: $0, entries: entries) }
    }

    // MARK: - Preconditions
    //
    // Asserted before the result, because a comparison against an empty series
    // passes trivially and this project has shipped instruments that reported
    // success while doing nothing.

    /// The default plotter really does open on 100 mg/week Test E, really does
    /// build a series, and that series really is on the all-testosterone branch
    /// the factor used to key off. If any of that stops being true, the tests
    /// below are measuring something other than the defect.
    func test_theDefaultPlotterProducesATestosteroneOnlySeries() throws {
        let vm = CyclePlotterViewModel()

        XCTAssertEqual(vm.lines.count, 1, "the plotter no longer opens on one line")
        let line = try XCTUnwrap(vm.lines.first)
        XCTAssertEqual(line.compoundId, "test-e")
        XCTAssertEqual(line.dose, 100)
        XCTAssertEqual(line.freqDays, 7)
        XCTAssertEqual(line.compound.category, "Testosterone",
                       "the ng/dL factor keyed off this category — if the default line "
                       + "is no longer a testosterone, these tests exercise the branch "
                       + "that never had the defect")

        let series = try XCTUnwrap(vm.series.first, "the default plotter built no series")
        XCTAssertGreaterThan(series.points.count, 100,
                             "too few sample points to be the real curve")
        XCTAssertGreaterThan(series.points.map(\.level).max() ?? 0, 0,
                             "the curve is flat zero — nothing is being compared")
    }

    /// The defect's size, stated as a number rather than as prose: the factor
    /// this task deleted lifted the default curve's peak into the range of a real
    /// serum testosterone result. **This is why T-42 is a 9 and not a relabel.**
    ///
    /// A normal male total-testosterone reference range runs roughly 300–1,000
    /// ng/dL, so a peak between those and a little above is precisely the region
    /// a user would compare against their own lab report.
    func test_theDeletedFactorLandedTheCurveInLabRange() throws {
        let vm = CyclePlotterViewModel()
        let peak = try XCTUnwrap(vm.series.first?.points.map(\.level).max())

        let asShipped = peak
        let asItWas = peak * deletedFactor

        XCTAssertLessThan(asShipped, 300,
                          "the unscaled model peak is already in lab range — then the "
                          + "relabel alone would not have removed the invitation to "
                          + "compare, and this task's reasoning needs revisiting")
        XCTAssertGreaterThan(asItWas, 1000,
                             "the old scaled peak was NOT in lab range — the premise of "
                             + "T-42 is wrong and this test is the thing that says so")
        XCTAssertLessThan(asItWas, 2500,
                          "the old scaled peak was far outside any plausible assay "
                          + "result, which would have made it self-evidently not a lab "
                          + "number — again, worth revisiting rather than assuming")
    }

    // MARK: - The pin

    /// THE TEST T-42 ASKS FOR. Every plotted point of a testosterone-only
    /// selection equals the unscaled model output at the same day.
    ///
    /// Derived, not recorded: the expectation is `pkTotalLevel` recomputed here
    /// from the same compound row and dose. Reintroducing 13.5 — or 1.5, or 1.01
    /// — makes every non-zero point differ by far more than the 4-dp rounding
    /// tick, and there is no number in this file to re-baseline.
    func test_theTestosteroneOnlySeriesIsTheUNSCALEDModelOutput() throws {
        let vm = CyclePlotterViewModel()
        let series = try XCTUnwrap(vm.series.first)

        let days = series.points.map(\.day)
        let expected = try modelCurve(compoundId: "test-e", dose: 100, freqDays: 7,
                                      cycleWeeks: vm.cycleWeeks, at: days)

        XCTAssertEqual(series.points.count, expected.count)
        for (point, model) in zip(series.points, expected) {
            XCTAssertEqual(point.level, model, accuracy: plottedTick,
                           "day \(point.day): plotted \(point.level), model \(model). "
                           + "The plotter is scaling the curve — ratio "
                           + "\(model == 0 ? Double.nan : point.level / model). T-42.")
        }
    }

    /// The same, for a selection that is testosterone-only but is NOT the
    /// default: two esters, a different dose and a different interval. The old
    /// factor applied to `allSatisfy { category == "Testosterone" }`, so a
    /// multi-line all-testo board is the case it hit hardest.
    func test_aTwoEsterTestosteroneBoardIsAlsoUnscaled() throws {
        let vm = CyclePlotterViewModel()
        vm.lines = [
            PlotterLine(compoundId: "test-c", dose: 250, freqDays: 3.5),
            PlotterLine(compoundId: "test-p", dose: 50, freqDays: 2),
        ]

        XCTAssertTrue(vm.lines.allSatisfy { $0.compound.category == "Testosterone" },
                      "this board is not all-testosterone — wrong branch")
        XCTAssertEqual(vm.series.count, 2)

        let specs = [("test-c", 250.0, 3.5), ("test-p", 50.0, 2.0)]
        for (series, spec) in zip(vm.series, specs) {
            let expected = try modelCurve(compoundId: spec.0, dose: spec.1,
                                          freqDays: spec.2, cycleWeeks: vm.cycleWeeks,
                                          at: series.points.map(\.day))
            for (point, model) in zip(series.points, expected) {
                XCTAssertEqual(point.level, model, accuracy: plottedTick,
                               "\(spec.0) day \(point.day) is scaled — T-42")
            }
        }
    }

    /// THE PROPERTY THAT DOES NOT DEPEND ON KNOWING THE FACTOR'S VALUE, and the
    /// one most likely to catch a future variant of this defect.
    ///
    /// The old code chose the scale by CATEGORY, so adding one non-testosterone
    /// compound silently divided the testosterone curve by 13.5 — the same
    /// protocol, redrawn at a different scale, because of a second line the user
    /// added beside it. Here the Test E curve must be byte-for-byte identical
    /// with and without a Masteron E line beside it.
    ///
    /// `masteron-e` is chosen so the SAMPLE GRID cannot move: it has the same
    /// 4.5-day half-life as `test-e`, so `maxWashout`, `minHalfLife` and
    /// therefore `step` and `totalDays` are all unchanged, and the two runs
    /// produce the same `labels`. Any other compound would have made a
    /// difference in the curve ambiguous between a rescale and a regrid.
    func test_addingANonTestosteroneLineDoesNotRescaleTheTestosteroneCurve() throws {
        let alone = CyclePlotterViewModel()
        let aloneSeries = try XCTUnwrap(alone.series.first)

        let mixed = CyclePlotterViewModel()
        mixed.lines = [
            PlotterLine(compoundId: "test-e", dose: 100, freqDays: 7),
            PlotterLine(compoundId: "masteron-e", dose: 100, freqDays: 7),
        ]
        XCTAssertFalse(mixed.lines.allSatisfy { $0.compound.category == "Testosterone" },
                       "the second line is a testosterone — this is not the mixed branch")
        XCTAssertEqual(mixed.series.count, 2)
        let mixedTestE = try XCTUnwrap(mixed.series.first)

        XCTAssertEqual(aloneSeries.points.count, mixedTestE.points.count,
                       "the sample grid moved between the two runs — masteron-e was "
                       + "chosen to keep it fixed, so this is a table change and the "
                       + "comparison below is no longer valid")

        for (a, m) in zip(aloneSeries.points, mixedTestE.points) {
            XCTAssertEqual(a.day, m.day, accuracy: 1e-9, "grids diverged")
            XCTAssertEqual(a.level, m.level, accuracy: plottedTick,
                           "day \(a.day): the SAME 100 mg/week Test E plots at \(a.level) "
                           + "alone and \(m.level) beside another compound. A curve whose "
                           + "scale depends on what else is on the board is T-42.")
        }
    }

    /// PROOF THE COMPARISON DISCRIMINATES. The three tests above assert
    /// `series ≈ model`; if this file computed the model with the same error the
    /// view model had, they would all pass on a broken app. So: run the identical
    /// comparison against a curve deliberately scaled by the deleted factor and
    /// require it to disagree, at every non-zero point.
    ///
    /// This is the "show it failing against a deliberately wrong reference"
    /// discipline CLAUDE.md demands of a snapshot, applied to an arithmetic pin.
    func test_theComparisonWouldCatchAScalar() throws {
        let vm = CyclePlotterViewModel()
        let series = try XCTUnwrap(vm.series.first)
        let days = series.points.map(\.day)
        let model = try modelCurve(compoundId: "test-e", dose: 100, freqDays: 7,
                                   cycleWeeks: vm.cycleWeeks, at: days)

        var disagreements = 0
        var nonZero = 0
        for (point, m) in zip(series.points, model) where m > plottedTick {
            nonZero += 1
            if abs(point.level - m * deletedFactor) > plottedTick { disagreements += 1 }
        }

        XCTAssertGreaterThan(nonZero, 100,
                             "almost every sample is zero — the comparison above is "
                             + "vacuous and its passing means nothing")
        XCTAssertEqual(disagreements, nonZero,
                       "the shipped series matched a 13.5x-scaled curve somewhere. The "
                       + "assertions in this file cannot tell a scaled curve from an "
                       + "unscaled one, so their green is worthless.")

        // And the smallest scalar this budget can still see, so the guarantee is
        // stated rather than assumed. A 0.1% factor moves the peak by far more
        // than the plotted tick.
        let peak = try XCTUnwrap(series.points.map(\.level).max())
        XCTAssertGreaterThan(peak * 0.001, plottedTick,
                             "a 0.1% scalar would fit inside the tolerance — the "
                             + "tolerance is too loose to pin this")
    }

    // MARK: - The label
    //
    // The axis wording is the web's, not a phrase written here:
    //   `public/legacy/cycle-plotter/app.jsx:34`
    //     const METRIC_LABEL = { serum: 'Estimated serum level', … };
    //   `public/legacy/cycle-plotter/app.jsx:557`
    //     const unitLabel = … : 'relative units';
    //
    // A unit test cannot read a SwiftUI `Text`, so these assert `PlotterCopy` —
    // the declaration the view itself renders — and NOT literals restated here.
    // A test that declares its own expected string and then asserts it equals
    // itself is a check that cannot fail, which is the failure mode this project
    // has now found eight times. The rendered axis is photographed and asserted
    // separately by `T42PlotterRelativeUnitsUITests`, which reads `plotAxisTitle`
    // / `plotAxisUnit` off the running screen. Both halves are needed: this one
    // cannot see the screen, and that one cannot see the model.

    /// The axis wording, pinned to the web's two strings.
    func test_theAxisIsTheWebsWordingAndNotALabUnit() {
        XCTAssertEqual(PlotterCopy.axisTitle, "Estimated serum level",
                       "the axis title is not the web's own string — "
                       + "`public/legacy/cycle-plotter/app.jsx:34`, "
                       + "`METRIC_LABEL.serum`")
        XCTAssertEqual(PlotterCopy.axisUnit, "relative units",
                       "the axis unit is not the web's own string — `app.jsx:557`. "
                       + "Its comment at :555 records that the abbreviated `rel.` was "
                       + "rejected, so the long form is deliberate and must not be "
                       + "shortened here either")
    }

    /// No plotter-facing string may claim ng/dL as the chart's unit again. The
    /// FAQ answer is exempt from the substring rule because explaining why the
    /// chart is NOT in ng/dL requires naming ng/dL — so it is checked for the
    /// clause that does the explaining instead.
    func test_noPlotterAxisStringClaimsALabUnit() {
        for s in [PlotterCopy.axisTitle, PlotterCopy.axisUnit] {
            XCTAssertFalse(s.lowercased().contains("ng/dl"),
                           "\"\(s)\" labels the chart in ng/dL. The model produces "
                           + "mg-equivalents; spec/math-spec.md §4.1: the chart "
                           + "\"must never claim a lab number\".")
        }
    }

    /// The ported FAQ answer is the web's, and specifically still carries the
    /// clause that is the whole argument: a real conversion needs volume of
    /// distribution AND bioavailability, both compound-specific — which is why
    /// one global scalar could never have produced a correct ng/dL. A paraphrase
    /// that dropped those two terms would leave the screen asserting a limit it
    /// no longer explains.
    func test_theFaqAnswerKeepsTheClauseThatMakesTheArgument() {
        let a = PlotterCopy.unitsFaqAnswer

        XCTAssertTrue(a.contains("compound-specific"), "lost 'compound-specific'")
        XCTAssertTrue(a.contains("volume of distribution"), "lost 'volume of distribution'")
        XCTAssertTrue(a.contains("bioavailability"), "lost 'bioavailability'")
        XCTAssertTrue(a.contains("not reliably available for all compounds"),
                      "lost the clause that says the parameters do not exist for the "
                      + "table iOS actually ships")

        // And what the chart IS still good for — the sentence the visible web copy
        // drops and the structured data at index.html:52 keeps.
        XCTAssertTrue(a.contains("peak-to-trough ratios"), "lost what the chart is for")
        XCTAssertTrue(a.contains("The shape and timing of the curve is correct"),
                      "lost the structured-data sentence — without it this reads as a "
                      + "disclaimer rather than an explanation")

        XCTAssertEqual(PlotterCopy.unitsFaqQuestion,
                       "Why does the plotter use relative units instead of ng/dL?",
                       "the question was reworded — `index.html:2296` is verbatim and "
                       + "porting it verbatim is the point")
    }
}
