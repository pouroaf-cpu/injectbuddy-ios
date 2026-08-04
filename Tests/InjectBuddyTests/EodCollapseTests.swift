import XCTest
@testable import InjectBuddy

/// **T-12 — EOD is removed as a CALCULATOR and retained as a PROTOCOL TYPE.**
///
/// The owner's decision was to collapse it: *"just remove the whole EOD completely, that
/// option is inside the TRT calc anyway."* Three separate claims are made by that
/// sentence and each can be true while another is false, so each is asserted here:
///
///   1. **No route in.** No browse surface, category or drawer offers EOD.
///   2. **Nothing a web-written protocol needs was deleted.** The slug still decodes,
///      still names itself, still projects every 2 days, still evaluates.
///   3. **The capability genuinely survives in the TRT calculator** — not "should",
///      *numerically*, against the same engine the EOD screen used.
///
/// **WHY (2) IS HERE AT ALL, AND IT IS THE REASON THIS FILE IS NOT JUST A DELETION
/// CHECK.** The task as written said to remove `.eod` from `CalculatorSlug`.
/// `CalculatorSlug.rawValue` is the decoder for `saved_dosages.calculator_type`, and the
/// WEB CAN STILL WRITE THAT TYPE — `app.js` keeps a live `EODPage` in `PAGES` and
/// `RAIL_PAGES`, and `:6054` posts `{calculator_type: 'eod', …}`. Its saved config is
/// `{strength, mgWeek, syringeMl, esterType}` and **carries no cadence key at all** — no
/// `mode`, no `nDays`, no `injPerWeek`. So the every-2-days interval hangs entirely on
/// the slug. Delete the case and `injectionIntervalDays` falls through to `.none → nil`
/// and the protocol is **never projected**: no error, no empty state, simply absent from
/// the calendar. That is T-57's shape and T-81's shape, and `testAWebWrittenEodProtocol…`
/// below is the regression guard for it.
///
/// **These fixtures are the web's shape, read from its source, not iOS's idea of it.**
/// `app.js:6051` — `const config = {strength, mgWeek, syringeMl, esterType};` — and the
/// label format on the next line, `Math.round(mgPerInj) + 'mg EOD · ' + esterType`.
final class EodCollapseTests: XCTestCase {

    // MARK: helpers

    private func dosage(id: String, type: String, label: String?, config: String) -> SavedDosage {
        let labelJSON = label.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":\(labelJSON),\
        "config":\(config),"start_date":null,"is_active":true}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    /// A row exactly as the web's EOD page writes it. Four keys, no cadence key.
    private var webWrittenEod: SavedDosage {
        dosage(id: "eod-web-1", type: "eod", label: "20mg EOD · Testosterone Enanthate", config: """
        {"strength":200,"mgWeek":70,"syringeMl":1,"esterType":"Testosterone Enanthate"}
        """)
    }

    // MARK: - 1. The collapse — no route in

    /// Restated here rather than read from the code under test. `XCTAssertEqual(x, x)`
    /// cannot fail, and this project has found eight of those.
    func testTheCollapsedSetIsExactlyEod() {
        XCTAssertEqual(Set(CalculatorSlug.collapsedCases), [.eod],
                       "The collapsed set has changed. T-12 collapsed EOD and nothing else.")
    }

    /// Every assertion in this section is satisfied trivially by an empty collapsed set.
    func testTheCollapsedSetIsNotEmpty() {
        XCTAssertFalse(CalculatorSlug.collapsedCases.isEmpty,
                       "Nothing is collapsed, so the checks below pass by having no work to do.")
    }

    func testNoCategoryClaimsEodAtAll() {
        for category in CalculatorCategory.allCases {
            XCTAssertFalse(category.allMembers.contains(.eod),
                           "\(category.title) still claims EOD. A collapse leaves the "
                           + "taxonomy entirely — `allMembers`, not just `members`, which "
                           + "is what separates it from a withdrawal.")
        }
    }

    func testNoBrowseSurfaceOffersEod() {
        XCTAssertFalse(CalculatorSlug.listedCases.contains(.eod),
                       "The dashboard's open-calculator dialog still offers EOD.")
        XCTAssertFalse(CalculatorCategory.allCases.flatMap(\.members).contains(.eod),
                       "The Tools list still offers EOD.")
        XCTAssertFalse(CalculatorCategory.allCases.flatMap(\.savableMembers).contains(.eod),
                       "The Add funnel still offers EOD.")
        let drawer = NavItems.calculators.compactMap { route -> CalculatorSlug? in
            if case .calculator(let slug) = route { return slug }
            return nil
        }
        XCTAssertFalse(drawer.contains(.eod), "The drawer still routes to EOD.")
    }

    /// The one push site fed by a stored `calculator_type` rather than a browse list.
    func testAnEodProtocolOpensTheTrtCalculator() {
        XCTAssertEqual(CalculatorSlug.eod.formSlug, .trt,
                       "Tapping a web-created EOD protocol must land on the TRT "
                       + "calculator — where the mode now lives, and where the web's own "
                       + "nav sends `eod` (nav-items.js:23 → /trt-calculator/).")
    }

    /// From the other end: the redirect must not have spread. A `formSlug` that
    /// rewrote more than one slug would silently send other calculators elsewhere.
    func testFormSlugIsIdentityForEveryOtherCalculator() {
        for slug in CalculatorSlug.allCases where slug != .eod {
            XCTAssertEqual(slug.formSlug, slug,
                           "\(slug.title) is being redirected to \(slug.formSlug.title). "
                           + "Only EOD is collapsed.")
        }
    }

    // MARK: - 2. Nothing a web-written protocol needs was deleted

    /// **The regression guard for the thing this task was originally told to delete.**
    func testAWebWrittenEodProtocolStillDecodesAndStillProjects() {
        let row = webWrittenEod

        XCTAssertEqual(CalculatorSlug(rawValue: row.calculatorType), .eod,
                       "`eod` no longer decodes to a slug. A protocol the web created is "
                       + "now invisible to iOS — no error, no empty state, simply absent.")

        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: row), 2,
                       "A web-written EOD protocol no longer projects every 2 days. Its "
                       + "config carries NO cadence key — no mode, no nDays, no "
                       + "injPerWeek — so this interval comes from the slug alone. Losing "
                       + "it means the protocol is never projected and the calendar shows "
                       + "nothing due while the user is still injecting.")
    }

    /// The card still says what the vial and the compound are, so the protocol reads as
    /// a real one rather than as a blank row with a label.
    func testAWebWrittenEodProtocolStillSummarises() {
        let row = webWrittenEod
        XCTAssertEqual(ProtocolSummary.vial(for: row), "200 mg/mL")
        XCTAssertEqual(ProtocolSummary.compound(for: row), "Testosterone Enanthate")
    }

    /// The calendar evaluates a protocol to get its dose (`DoseProjection:145`). If the
    /// `.eod` branch went, this returns a result with no dose and the calendar shows a
    /// day with nothing on it.
    func testAWebWrittenEodProtocolStillEvaluates() {
        let values = CalculatorCatalog.values(fromConfig: webWrittenEod.config, slug: .eod)
        let result = CalculatorEngine.evaluate(slug: .eod, values: values, scale: .u100)
        XCTAssertFalse(result.rows.isEmpty,
                       "Evaluating an EOD protocol produces nothing, so the calendar has "
                       + "no dose to show against it.")
    }

    // MARK: - 3. The capability survives in the TRT calculator

    /// **The proof that the collapse did not cost anything: the same engine, the same
    /// numbers.** `CalculatorEngine.eod` hardcodes 3.5 injections/week; TRT in `ndays`
    /// mode at 2 days computes `7/2 = 3.5`. Every field of the result must agree, not
    /// just the frequency — a matching frequency with a different volume would still be
    /// a dosing change.
    func testEveryNDaysAtTwoReproducesTheEodEngineExactly() {
        let eod = CalculatorEngine.eod(strength: 200, mgWeek: 70)
        let trt = CalculatorEngine.trt(strength: 200, mgWeek: 70, mode: .ndays,
                                       nDays: 2, injPerWeek: 0, mlDrawn: 0)
        XCTAssertEqual(trt, eod,
                       "Every N Days = 2 no longer reproduces the EOD calculator. The "
                       + "screen was removed on the strength of this equivalence.")
        XCTAssertEqual(eod.freqPerWeek, 3.5, accuracy: 1e-9)
        XCTAssertEqual(eod.mgPerInj, 20, accuracy: 1e-9)
    }

    /// The equivalence above must be specific to 2 days, or it is passing on something
    /// other than what it claims. `nDays: 3.5` is the TRT spec's own default and gives
    /// twice-weekly — a plausible, wrong neighbour.
    func testTheEquivalenceIsSpecificToTwoDays() {
        let eod = CalculatorEngine.eod(strength: 200, mgWeek: 70)
        let atDefault = CalculatorEngine.trt(strength: 200, mgWeek: 70, mode: .ndays,
                                             nDays: 3.5, injPerWeek: 0, mlDrawn: 0)
        XCTAssertNotEqual(atDefault, eod,
                          "TRT at its DEFAULT nDays already equals the EOD result, so the "
                          + "equivalence test above would pass whatever the interval was.")
    }

    /// The control has to be able to reach 2, not merely compute correctly if it did.
    ///
    /// The expected list is a literal transcription of the web's `EVERY_N_DAYS_VALUES`
    /// (`app.js:3891` — `[0]`, then `1 → 14` stepping `0.5`), written out rather than
    /// recomputed, so this compares iOS against the WEB and not against itself.
    func testTheEveryNDaysDrumOffersTwoAndMatchesTheWebsList() {
        let web: [Double] = [0,
                             1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7,
                             7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 13.5, 14]
        XCTAssertEqual(TickDrum.everyNDays, web,
                       "The Every N Days drum no longer matches the web's "
                       + "EVERY_N_DAYS_VALUES.")
        XCTAssertTrue(TickDrum.everyNDays.contains(2),
                      "The drum cannot reach 2 days, so EOD is not selectable and the "
                      + "collapse removed a capability instead of relocating it.")
    }
}
