import XCTest

/// Re-shoots the `docs/ui-audit/<date>-current` set.
///
/// Drives the app through the automation layer — synthesized host clicks are dead
/// on this rig — and writes PNGs into the runner's Documents directory, printing
/// the path so the host can copy them out.
///
/// OPT-IN. It skips unless `TEST_RUNNER_CAPTURE=1`, so a normal suite run is not
/// two minutes of screenshots:
///
///     TEST_RUNNER_CAPTURE=1 xcodebuild test … \
///       -only-testing:InjectBuddyUITests/CaptureCurrentState
///
/// For the AX5 set, set the size from the host first:
///
///     xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
///
/// Deliberately does NOT visit Settings or the drawer: those carry the account's
/// real email and avatar, and the standing decision is not to capture more of them.
final class CaptureCurrentState: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE"] == "1",
                          "TEST_RUNNER_CAPTURE=1 not set — skipping the capture sweep.")

        // FALSE, deliberately. With this true, a failed navigation does not stop the
        // run: `12-calculator-trt-ax5` came back a genuine photograph of the Tools
        // screen under a filename claiming the TRT calculator, because openTRT()
        // could not find the row at AX5 and the capture ran anyway. A sweep that
        // cannot fail loudly will keep producing frames that lie, and this project
        // has already shipped bad evidence that looked fine twice.
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — capture needs the signed-in app.")
    }

    private func shot(_ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? XCUIScreen.main.screenshot().pngRepresentation
            .write(to: dir.appendingPathComponent(name))
        print("CAPTURE-HOME: \(dir.path)")
    }

    /// The lowest match on screen. "Tools" is both a tab and the nav back button
    /// once a calculator is open, and `buttons["Tools"]` then fails on ambiguity.
    private func tab(_ label: String) {
        let matches = app.buttons.matching(identifier: label)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 8), "No \(label) tab.")
        let lowest = matches.allElementsBoundByIndex
            .filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "\(label) exists but nothing hittable.")
        lowest?.tap()
        _ = app.wait(for: .runningForeground, timeout: 2)
    }

    private func openTRT() {
        tab("Tools")
        let candidates = app.staticTexts.matching(identifier: "TRT Dose")
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 8))
        candidates.allElementsBoundByIndex.first { $0.isHittable }?.tap()
        XCTAssertTrue(app.textFields["field_mgWeek"].waitForExistence(timeout: 8))
    }

    /// Default type size. Numbering matches `2026-08-01-current` so the two sets
    /// sit side by side.
    func testCaptureDefaultSizeSet() {
        tab("Dashboard")
        shot("02-dashboard.png")

        tab("Calendar")
        shot("03-calendar.png")

        tab("Tools")
        shot("04-tools.png")

        tab("Add")
        shot("05-add.png")

        openTRT()
        shot("06-calculator-trt.png")

        // NOT scrollViews.firstMatch — that is the off-canvas drawer, at x = -344.
        app.swipeUp()
        shot("07-calculator-barrel-row.png")

        // TODAY'S FIX: the focused field's quick values in the keyboard toolbar,
        // above the keypad, with a Done button. Previously this strip was behind
        // the pinned result bar and a tap on it passed while moving nothing.
        openTRT()
        app.textFields["field_mgWeek"].tap()
        shot("11-calculator-keyboard-toolbar.png")
        app.buttons.matching(identifier: "kb_done").element(boundBy: 0).tap()

        tab("Log dose")
        shot("08-logdose-sheet.png")
    }

    /// Set the size from the host first:
    ///   xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
    func testCaptureAX5Set() {
        tab("Dashboard")
        shot("09-dashboard-ax5.png")

        tab("Tools")
        shot("10-tools-ax5.png")

        // At AX5 the calculator names wrap so hard that four rows fill the screen,
        // so the TRT row is below the fold and openTRT() cannot see it. Scroll into
        // the list before asking for it, and let the assertion inside openTRT() stop
        // the run if it is still not there — do not shoot whatever happens to be on
        // screen and call it the calculator.
        app.swipeUp()
        openTRT()
        shot("12-calculator-trt-ax5.png")
    }
}
