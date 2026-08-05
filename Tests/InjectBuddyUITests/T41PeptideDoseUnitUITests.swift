import XCTest

/// T-41, on the device. The unit tests pin the arithmetic; this pins that the
/// arithmetic reaches the SCREEN — that the field the user reads shows `0.5` after a
/// flip to mg, not `500`.
///
/// It is a UI test and not a snapshot because the question is behavioural: a picker is
/// operated, and the field it is not part of has to change. A rendered view cannot
/// answer that.
///
/// FRAMES. Two, written into the runner's Documents directory and printed, for the
/// host to copy into `docs/ui-audit/`:
///   `t41-01-peptide-500-mcg.png`   the shipped default, before the flip
///   `t41-02-peptide-0.5-mg.png`    the same dose after it, reading 0.5
///
/// The frames are evidence, but THE ASSERTIONS ARE THE PROOF. A screenshot of `0.5`
/// beside a unit label proves the pair only to a reader; the assertions below prove it
/// to the run, and they are what makes a green here mean something. Both are taken
/// because this project has shipped a "refreshed" capture set that was byte-identical
/// to the last one — a photograph nobody asserted against is a photograph of whatever
/// was on screen.
///
/// Not opt-in behind `CAPTURE`: this is a regression test that happens to photograph,
/// not a capture sweep. It must run with the suite.
final class T41PeptideDoseUnitUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // NO BLANKET WIPE HERE, AND THE FIRST VERSION OF THIS FILE HAD ONE. It deleted
        // every `t41-*.png` in the Documents directory — which `XCTest` re-runs before
        // EVERY test method, so the second test in this class deleted the two frames the
        // first had just taken. The run reported `Executed 2 tests, with 0 failures`,
        // printed both frame paths, and left nothing on disk. A green run whose artefact
        // does not exist is the exact failure this project keeps re-finding: check the
        // artefact, never the exit code.
        //
        // Staleness is still closed, per NAME, in `shot()` — a frame is removed
        // immediately before it is rewritten, so a previous run's file can never be
        // copied out under this run's name. That is the property that was wanted; the
        // directory-wide sweep was a bigger hammer than the nail and hit the evidence.

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
        print("T41-FRAME: \(url.path)")
    }

    /// Tools → Peptide, ARRIVAL ASSERTED. A tap is not arrival; the frames below would
    /// otherwise be photographs of the Tools list under a filename claiming a dose.
    private func openPeptide() {
        let tools = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tools.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tools.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "Tools exists but nothing hittable.")
        lowest?.tap()
        XCTAssertTrue(app.staticTexts["Reconstitution"].firstMatch.waitForExistence(timeout: 8),
                      "Tapped Tools and never arrived.")

        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: "Peptide").allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else {
                return XCTFail("Nothing scrollable after \(attempt) attempts looking for Peptide.")
            }
            list.swipeUp()
        }
        guard let hit = row else { return XCTFail("Peptide never became hittable after 12 scrolls.") }
        hit.tap()
        XCTAssertTrue(app.textFields["field_dosePerInj"].waitForExistence(timeout: 8),
                      "Tapped Peptide and did not land on it — field_dosePerInj never appeared.")
    }

    /// THE TEST T-41 ASKS FOR: set 500 mcg, flip to mg, the field reads 0.5.
    func testFlippingTheDoseUnitConvertsTheNumberOnScreen() {
        openPeptide()

        let dose = app.textFields["field_dosePerInj"]
        let unit = app.staticTexts["unit_dosePerInj"]
        let picker = app.descendants(matching: .any).matching(identifier: "control_doseUnitMcg").firstMatch

        // The shipped default IS the 500 mcg the task names, so nothing is typed — a
        // typed value would be testing the keypad as well as the conversion.
        XCTAssertEqual(dose.value as? String, "500", "the peptide dose default is not 500")
        XCTAssertTrue(unit.waitForExistence(timeout: 4),
                      "the dose field carries no unit label — a bare 500 is the defect")
        XCTAssertEqual(unit.label, "mcg")
        shot("t41-01-peptide-500-mcg.png")

        // The engine's reading of the same dose, held across the flip. `0.5 mg` and
        // `500 mcg` are the same quantity, so the draw volume must not move: this is
        // the assertion that catches a conversion applied to the DISPLAY only.
        let weekly = app.staticTexts["result_Weekly total"]
        XCTAssertTrue(weekly.waitForExistence(timeout: 6), "no result to compare across the flip")
        let weeklyBefore = weekly.label

        XCTAssertTrue(picker.waitForExistence(timeout: 4), "no dose-unit picker on the screen")
        picker.tap()
        let mg = app.buttons["mg"].firstMatch
        XCTAssertTrue(mg.waitForExistence(timeout: 4), "the unit menu never opened")
        mg.tap()

        // THE DEFECT, INVERTED. Before T-41 this read `500` under a `mg` label.
        XCTAssertTrue(app.staticTexts["unit_dosePerInj"].waitForExistence(timeout: 4))
        XCTAssertEqual(app.staticTexts["unit_dosePerInj"].label, "mg",
                       "the picker did not change the unit")
        XCTAssertEqual(dose.value as? String, "0.5",
                       "500 mcg did not become 0.5 mg — this is the T-41 defect")
        shot("t41-02-peptide-0.5-mg.png")

        XCTAssertEqual(app.staticTexts["result_Weekly total"].label, weeklyBefore,
                       "the computed result moved on a flip that only renamed the unit")

        // And back, on the device: the round trip the unit tests pin, driven through
        // the real control. A clamp gets here reading 20, not 500.
        app.descendants(matching: .any).matching(identifier: "control_doseUnitMcg")
            .firstMatch.tap()
        let mcg = app.buttons["mcg"].firstMatch
        XCTAssertTrue(mcg.waitForExistence(timeout: 4), "the unit menu never reopened")
        mcg.tap()
        XCTAssertEqual(dose.value as? String, "500",
                       "0.5 mg did not return to 500 mcg — the conversion is one-way")
    }

    /// The quick chips move with the unit too. In mcg they are `250 · 500 · 750 · 1000
    /// · 2000`; in mg those numbers are three orders of magnitude out and tapping one
    /// would enter a dose 1000× the intended.
    func testQuickChipsMoveWithTheUnit() {
        openPeptide()

        XCTAssertTrue(app.buttons["quick_dosePerInj_250"].waitForExistence(timeout: 6),
                      "the mcg chips are not on screen")

        app.descendants(matching: .any).matching(identifier: "control_doseUnitMcg")
            .firstMatch.tap()
        let mg = app.buttons["mg"].firstMatch
        XCTAssertTrue(mg.waitForExistence(timeout: 4))
        mg.tap()

        XCTAssertTrue(app.buttons["quick_dosePerInj_0.25"].waitForExistence(timeout: 6),
                      "the chips did not follow the unit — 250 mg is 1000x a peptide dose")
        XCTAssertFalse(app.buttons["quick_dosePerInj_250"].exists,
                       "a 250 chip is still on screen in mg mode")

        // EXISTENCE, NOT A TAP, and that is deliberate rather than lazy. The in-scroll
        // chip row is the one the pinned result bar occludes — the measured defect that
        // put a second copy of these chips in the keyboard toolbar, where a XCUITest tap
        // on `quick_mgWeek_400` reported success and moved nothing. Asserting a tap here
        // would be asserting against that open defect, not against T-41; what T-41 owns
        // is which VALUES the row offers, and that is what is asserted.
    }
}
