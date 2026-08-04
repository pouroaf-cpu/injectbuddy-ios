import XCTest

/// T-42, on the device. `PlotterNoNgdlFactorTests` pins that the model is no
/// longer scaled; this pins that the SCREEN no longer claims a lab unit — that
/// the axis a user reads says `Estimated serum level` / `relative units`, and
/// that the explanation of why sits under the curve where they can find it.
///
/// It is a UI test and not a snapshot because the assertions are about strings
/// resolved on a live screen reached by real navigation, and because the whole
/// defect was that a rendered number wore the wrong units. A rendered view can
/// answer what a `Text` contains; it cannot answer whether the user who tapped
/// "See your levels over time" arrives at that `Text`.
///
/// FRAMES. Two, written into the runner's Documents directory and printed, for
/// the host to copy into `docs/ui-audit/`:
///   `t42-01-plotter-relative-units.png`  the axis, on the all-testosterone
///                                        default — the exact selection that
///                                        used to read `Estimated level (ng/dL)`
///   `t42-02-plotter-units-faq.png`       the ported FAQ answer, on screen
///
/// THE ASSERTIONS ARE THE PROOF, not the frames. A photograph of an axis proves
/// the wording only to a reader; the assertions below prove it to the run. Both
/// are taken because this project has shipped a "refreshed" capture set that was
/// byte-identical to the previous one.
///
/// Not opt-in behind `CAPTURE`: this is a regression test that happens to
/// photograph, not a capture sweep. It must run with the suite.
final class T42PlotterRelativeUnitsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // NO BLANKET WIPE HERE — deliberately, and the reason is recorded on
        // `T41PeptideDoseUnitUITests`. `XCTest` re-runs `setUp` before EVERY test
        // method, so a directory-wide sweep of `t42-*.png` would have the second
        // test in this class delete the frames the first had just taken; the run
        // reports green, prints both paths, and leaves nothing on disk.
        //
        // Staleness is still closed, per NAME, in `shot()` — the file is removed
        // immediately before it is rewritten, so a previous run's frame can never
        // be copied out under this run's name.

        app = XCUIApplication()
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this needs the signed-in app.")
    }

    private func shot(_ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = dir.appendingPathComponent(name)
        // Scoped staleness guard: this exact name, immediately before it is rewritten.
        try? FileManager.default.removeItem(at: url)
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
        print("T42-FRAME: \(url.path)")
    }

    /// The lowest hittable match. "Tools" is both a tab and, once a calculator is
    /// open, the nav back button — `buttons["Tools"]` then fails on ambiguity.
    private func tapToolsTab() {
        let tools = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tools.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tools.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "Tools exists but nothing hittable.")
        lowest?.tap()
        XCTAssertTrue(app.staticTexts["Reconstitution"].firstMatch.waitForExistence(timeout: 8),
                      "Tapped Tools and never arrived.")
    }

    private func scrollable() -> XCUIElement? {
        (app.collectionViews.allElementsBoundByIndex
         + app.tables.allElementsBoundByIndex
         + app.scrollViews.allElementsBoundByIndex)
            .first { $0.isHittable && $0.frame.minX >= 0 }
    }

    /// Tools → TRT Dose → "See your levels over time", ARRIVAL ASSERTED at every
    /// hop.
    ///
    /// The plotter is reached through a calculator and not from a Tools row
    /// because `ToolsScreen` does not list `Cycle Plotter` at all — no category
    /// claims it, which is its own open finding. `cta_plot_levels` is the route a
    /// user actually has, and it is the one `CaptureCurrentState` already proves
    /// works.
    ///
    /// A tap is not arrival. Without the final assertion the frames below would be
    /// photographs of the TRT calculator under a filename claiming the plotter —
    /// three frames in the old archive were exactly that.
    private func openPlotter() {
        tapToolsTab()

        // Re-query inside the loop: Tools is a lazy list, so the row is not
        // instantiated until it is scrolled near, and `waitForExistence` on it
        // fails with "does not exist" while it is two swipes away.
        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: "TRT Dose").allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            guard let list = scrollable() else {
                return XCTFail("Nothing scrollable after \(attempt) attempts looking for TRT Dose.")
            }
            list.swipeUp()
        }
        guard let hit = row else { return XCTFail("TRT Dose never became hittable after 12 scrolls.") }
        hit.tap()
        XCTAssertTrue(app.textFields["field_mgWeek"].waitForExistence(timeout: 8),
                      "Tapped TRT Dose and did not land on it — field_mgWeek never appeared.")

        let cta = app.descendants(matching: .any).matching(identifier: "cta_plot_levels").firstMatch
        for _ in 0..<10 where !(cta.exists && cta.isHittable) {
            scrollable()?.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
        }
        XCTAssertTrue(cta.exists && cta.isHittable,
                      "`cta_plot_levels` never became hittable on the TRT calculator.")
        cta.tap()

        XCTAssertTrue(app.buttons["control_plotCompound_0"].waitForExistence(timeout: 8),
                      "Tapped the levels link and never landed on the plotter — "
                      + "`control_plotCompound_0` is not on screen.")
    }

    /// THE PRECONDITION, ASSERTED BEFORE THE RESULT, and it is the one that would
    /// otherwise invert this test.
    ///
    /// The ng/dL factor and the ng/dL axis applied only when EVERY selected
    /// compound was a testosterone. A run that landed on any other selection would
    /// find no lab unit, pass cleanly, and clear the defect while never having
    /// gone near it — the exact shape of the silent-flag failure CLAUDE.md
    /// records for T-05. So the branch is proven before the axis is read.
    private func assertOnTheTestosteroneOnlyBranch() {
        let compound = app.buttons["control_plotCompound_0"]
        XCTAssertEqual(compound.value as? String, "Testosterone Enanthate",
                       "The plotter did not open on a testosterone. This test would "
                       + "then be reading the branch that NEVER claimed ng/dL, and its "
                       + "green would mean nothing.")
        XCTAssertFalse(app.buttons["control_plotCompound_1"].exists,
                       "A second compound line is present, so the selection may not be "
                       + "testosterone-only — the branch under test is not the one on "
                       + "screen.")
    }

    /// THE TEST T-42 ASKS FOR: the axis a user reads is the web's wording, and it
    /// is not a lab unit.
    func testTheAxisIsInRelativeUnitsAndNotNgdl() {
        openPlotter()
        assertOnTheTestosteroneOnlyBranch()

        let title = app.staticTexts["plotAxisTitle"]
        let unit = app.staticTexts["plotAxisUnit"]

        XCTAssertTrue(title.waitForExistence(timeout: 6),
                      "No `plotAxisTitle` on the plotter — the chart has no axis heading.")
        XCTAssertTrue(unit.waitForExistence(timeout: 6),
                      "No `plotAxisUnit` on the plotter — the chart states no unit at all, "
                      + "which is worse than stating the wrong one.")

        // The web's own two strings — `app.jsx:34` and `app.jsx:557`.
        XCTAssertEqual(title.label, "Estimated serum level",
                       "the axis heading is not the live plotter's `METRIC_LABEL.serum`")
        XCTAssertEqual(unit.label, "relative units",
                       "the axis unit is not the live plotter's `unitLabel`")

        // THE DEFECT, INVERTED. This screen used to read `Estimated level (ng/dL)`.
        XCTAssertFalse(title.label.lowercased().contains("ng/dl"),
                       "the axis heading still claims ng/dL")
        XCTAssertFalse(unit.label.lowercased().contains("ng/dl"),
                       "the axis unit still claims ng/dL")
        XCTAssertFalse(app.staticTexts["Estimated level (ng/dL)"].exists,
                       "the old ng/dL axis label is still rendered somewhere on this screen")

        shot("t42-01-plotter-relative-units.png")
    }

    /// The explanation is ON THE SCREEN, under the curve it explains — T-13's
    /// filter admits an FAQ entry that "explains a number the screen shows", and
    /// this is that.
    ///
    /// Asserted on the CLAUSE that carries the argument (volume of distribution
    /// and bioavailability, both compound-specific) rather than on the whole
    /// paragraph: a string equality here would fail on a line break or a typo fix
    /// and say nothing about whether the reasoning survived. The exact wording is
    /// pinned in `PlotterNoNgdlFactorTests`; what this adds is that it RENDERS.
    func testTheRelativeUnitsExplanationIsOnTheScreen() {
        openPlotter()
        assertOnTheTestosteroneOnlyBranch()

        let question = app.staticTexts["plotUnitsFaqQuestion"]
        let answer = app.staticTexts["plotUnitsFaqAnswer"]

        for _ in 0..<6 where !(answer.exists && answer.isHittable) {
            scrollable()?.swipeUp(velocity: XCUIGestureVelocity(rawValue: 200))
        }

        XCTAssertTrue(question.waitForExistence(timeout: 6),
                      "`plotUnitsFaqQuestion` is not on the plotter — the ported FAQ "
                      + "entry did not reach the screen.")
        XCTAssertTrue(answer.exists,
                      "`plotUnitsFaqAnswer` is not on the plotter — the question is "
                      + "rendered with no answer under it.")

        XCTAssertEqual(question.label,
                       "Why does the plotter use relative units instead of ng/dL?",
                       "the question was reworded on the way to the screen")

        // The argument, not the paragraph.
        let a = answer.label
        XCTAssertTrue(a.contains("volume of distribution"),
                      "the rendered answer has lost `volume of distribution` — one of "
                      + "the two compound-specific parameters that make a single global "
                      + "scalar structurally unable to produce a correct ng/dL")
        XCTAssertTrue(a.contains("bioavailability"),
                      "the rendered answer has lost `bioavailability`")
        XCTAssertTrue(a.contains("compound-specific"),
                      "the rendered answer has lost `compound-specific`, which is the "
                      + "word the whole argument turns on")
        XCTAssertTrue(a.contains("peak-to-trough"),
                      "the rendered answer has lost what the chart IS good for, leaving "
                      + "a disclaimer where an explanation was ported")

        // ARRIVAL ASSERTED IMMEDIATELY BEFORE THE FRAME, not at the top of the
        // test: the scroll above moved the screen between the two.
        XCTAssertTrue(answer.isHittable,
                      "the answer exists but is off-screen — a frame taken here would be "
                      + "a photograph of the chart under a filename claiming the FAQ.")
        shot("t42-02-plotter-units-faq.png")
    }
}
