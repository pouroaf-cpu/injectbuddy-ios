import XCTest
@testable import InjectBuddy

/// T-17 — the calculator → plotter handoff, checked as ARITHMETIC rather than by
/// looking at a curve.
///
/// This is the half of T-17 that a photograph cannot answer. A frame proves the
/// plotter opened on a compound and a dose; it cannot prove the dose is the
/// PER-INJECTION one. `PK.seriesFor` applies the line's dose at every injection
/// time, so handing it a weekly total plots a curve several times too high — and it
/// would look entirely plausible, because nothing on that screen says what the
/// number should have been. That is the same class of defect as the config key that
/// would have written "a plausible wrong dose volume to every logged dose".
///
/// Every expectation below is the web's own `mapDosage`
/// (`public/legacy/cycle-plotter/app.jsx:127-215`) evaluated by hand, with the
/// branch quoted on the test.
final class PlotterSeedTests: XCTestCase {

    private func values(_ slug: CalculatorSlug,
                        _ overrides: [String: Double] = [:],
                        strings: [String: String] = [:]) -> CalculatorValues {
        var v = CalculatorValues.defaults(for: CalculatorCatalog.spec(for: slug).fields)
        for (k, n) in overrides { v.numbers[k] = n }
        for (k, s) in strings { v.strings[k] = s }
        return v
    }

    // MARK: - TRT, all three modes

    /// `mode === 'ndays'` → `freqDays = cfg.nDays`, `dose = wk * freqDays / 7`.
    func test_trt_everyNDays_isPerInjection() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(
            slug: .trt,
            values: values(.trt, ["mgWeek": 140, "nDays": 3.5],
                           strings: ["mode": "ndays", "esterType": "Testosterone Enanthate"])))
        XCTAssertEqual(seed.compoundId, "test-e")
        XCTAssertEqual(seed.freqDays, 3.5, accuracy: 0.0001)
        // 140 a week, twice a week → 70 an injection. NOT 140.
        XCTAssertEqual(seed.dose, 70, accuracy: 0.0001)
    }

    /// `else { const ipw = …; freqDays = Math.round((7 / ipw) * 100) / 100; }` — the
    /// two-decimal rounding is the web's, and it is why 3×/week is 2.33 and not a
    /// repeating figure.
    func test_trt_perWeek_roundsTheIntervalToTwoDecimals() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(
            slug: .trt,
            values: values(.trt, ["mgWeek": 140, "injPerWeek": 3],
                           strings: ["mode": "perweek", "esterType": "Testosterone Cypionate"])))
        XCTAssertEqual(seed.compoundId, "test-c")
        XCTAssertEqual(seed.freqDays, 2.33, accuracy: 0.0001)
        XCTAssertEqual(seed.dose, 140 * 2.33 / 7, accuracy: 0.0001)
    }

    /// `dose = mode === 'ml2mg' ? mlDrawn * strength : …` — the reverse calculation
    /// ignores `mgWeek` entirely, because the user typed a volume.
    func test_trt_mlToMg_readsTheVolumeAndNotTheWeeklyTotal() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(
            slug: .trt,
            values: values(.trt, ["mgWeek": 999, "mlDrawn": 0.5, "strength": 200, "injPerWeek": 2],
                           strings: ["mode": "ml2mg", "esterType": "Testosterone Enanthate"])))
        XCTAssertEqual(seed.dose, 100, accuracy: 0.0001)
        XCTAssertEqual(seed.freqDays, 3.5, accuracy: 0.0001)
    }

    // MARK: - The other calculators that seed

    /// `type === 'eod'` → `freqDays = 2; dose = wk * 2 / 7;`. The interval is
    /// hardcoded on both sides, because the calculator itself is.
    func test_eod_isEveryTwoDays() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(
            slug: .eod,
            values: values(.eod, ["mgWeek": 70],
                           strings: ["esterType": "Testosterone Propionate"])))
        XCTAssertEqual(seed.compoundId, "test-p")
        XCTAssertEqual(seed.freqDays, 2)
        XCTAssertEqual(seed.dose, 20, accuracy: 0.0001)
    }

    /// Microdose has NO `mode` and NO `esterType` field. The web's
    /// `cfg.mode || (cfg.nDays ? 'ndays' : 'perweek')` resolves to `ndays`, and
    /// `ESTER_TO_CID[undefined] || 'test-e'` to enanthate.
    func test_microdose_fallsBackToEveryNDaysAndEnanthate() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(
            slug: .microdose, values: values(.microdose, ["mgWeek": 14, "nDays": 3.5])))
        XCTAssertEqual(seed.compoundId, "test-e")
        XCTAssertEqual(seed.freqDays, 3.5, accuracy: 0.0001)
        XCTAssertEqual(seed.dose, 7, accuracy: 0.0001)
    }

    /// The GLP-1 trio carry neither `mode` nor `injPerWeek`, so the web's
    /// `parseFloat(cfg.injPerWeek) || 1` fallback puts them at once a week — which is
    /// what all three calculators' own help text says the dose is.
    func test_glp1_areWeeklyAndMapOntoTheiOSCompoundIds() throws {
        for (slug, cid, dose) in [(CalculatorSlug.semaglutide, "sema", 0.5),
                                  (.tirzepatide, "tirz", 5.0),
                                  (.retatrutide, "reta", 1.0)] {
            let seed = try XCTUnwrap(PlotterSeed.from(slug: slug, values: values(slug)),
                                     "\(slug.rawValue) seeded nothing")
            XCTAssertEqual(seed.compoundId, cid)
            XCTAssertEqual(seed.freqDays, 7, accuracy: 0.0001)
            XCTAssertEqual(seed.dose, dose, accuracy: 0.0001)
        }
    }

    /// `type === 'bpc157'` → `freqDays = 1`.
    func test_bpc157_isDaily() throws {
        let seed = try XCTUnwrap(PlotterSeed.from(slug: .bpc157, values: values(.bpc157)))
        XCTAssertEqual(seed.compoundId, "bpc157")
        XCTAssertEqual(seed.freqDays, 1)
        XCTAssertEqual(seed.dose, 250, accuracy: 0.0001)
    }

    // MARK: - Where it refuses, asserted from the other end

    /// `if (!cid || !(dose > 0) || !COMPOUNDS[cid]) return null;` — and refusing is
    /// the POINT, so it is tested as behaviour rather than left as a fallthrough.
    /// Each of these opens the plotter unseeded instead of drawing a wrong molecule.
    func test_refusesWhatItCannotHonestlyDraw() {
        // No named molecule to plot: the iOS peptide calculator takes a vial size and
        // a water volume, and the web's branch keys off a `peptideType` it has not got.
        XCTAssertNil(PlotterSeed.from(slug: .peptide, values: values(.peptide)))
        // The web has no branch for either.
        XCTAssertNil(PlotterSeed.from(slug: .reconstitution, values: values(.reconstitution)))
        XCTAssertNil(PlotterSeed.from(slug: .bpc157blend, values: values(.bpc157blend)))
        // The web maps HCG to a compound id `hcg`; the iOS plotter catalogue has no
        // HCG entry. T-32.
        XCTAssertNil(PlotterSeed.from(slug: .hcg, values: values(.hcg)))
        // A dose of zero is not a curve.
        XCTAssertNil(PlotterSeed.from(
            slug: .trt,
            values: values(.trt, ["mgWeek": 0], strings: ["mode": "ndays"])))
    }

    /// Two of the seven esters map to web compounds the iOS plotter does not carry.
    /// Asserted rather than assumed, because the day one is added this test is what
    /// says so. T-32.
    func test_theTwoUnplottableEsters() {
        for ester in ["Testosterone Acetate", "Sustanon 250"] {
            XCTAssertNil(PlotterSeed.from(
                slug: .trt,
                values: values(.trt, ["mgWeek": 140, "nDays": 3.5],
                               strings: ["mode": "ndays", "esterType": ester])),
                         "`\(ester)` now seeds — the iOS plotter has grown a compound "
                         + "for it, so delete this expectation and T-32 with it.")
        }
        // ...and the other five DO seed, so this test cannot pass by seeding nothing.
        for ester in ["Testosterone Enanthate", "Testosterone Cypionate",
                      "Testosterone Propionate", "Testosterone Undecanoate",
                      "Testosterone Suspension"] {
            XCTAssertNotNil(PlotterSeed.from(
                slug: .trt,
                values: values(.trt, ["mgWeek": 140, "nDays": 3.5],
                               strings: ["mode": "ndays", "esterType": ester])),
                            "`\(ester)` stopped seeding.")
        }
    }

    /// Every ester this table names must resolve to a real plotter compound or be one
    /// of the two known gaps — a typo in a compound id would otherwise fail silently
    /// as "this protocol does not seed", which looks exactly like the deliberate
    /// refusals above.
    func test_theEsterTableNamesRealCompounds() {
        let known = Set(PlotterCompound.all.map(\.id))
        let missing = PlotterSeed.esterToCompoundId.values.filter { !known.contains($0) }
        XCTAssertEqual(Set(missing), ["test-a", "sustanon"],
                       "The ester table's unresolved ids have changed. Expected exactly "
                       + "the two T-32 gaps; got \(Set(missing)).")
    }

    // MARK: - The route

    /// `AppRoute` is a `navigationDestination` value and the drawer's selection, so it
    /// has to stay `Hashable` — and two seeds that differ by a dose must be two
    /// different destinations, or a push from a re-edited calculator would be a no-op.
    func test_theRouteStaysHashableAndDiscriminates() {
        let a = PlotterSeed(compoundId: "test-e", dose: 70, freqDays: 3.5, sourceSlug: .trt)
        let b = PlotterSeed(compoundId: "test-e", dose: 100, freqDays: 3.5, sourceSlug: .trt)
        XCTAssertEqual(AppRoute.plotter(seed: a), AppRoute.plotter(seed: a))
        XCTAssertNotEqual(AppRoute.plotter(seed: a), AppRoute.plotter(seed: b))
        XCTAssertNotEqual(AppRoute.plotter(seed: a), AppRoute.calculator(.cyclePlotter))
        XCTAssertEqual(Set([AppRoute.plotter(seed: a), .plotter(seed: a), .plotter(seed: b)]).count, 2)
        XCTAssertEqual(AppRoute.plotter(seed: a).title, "Cycle Plotter")
    }
}
