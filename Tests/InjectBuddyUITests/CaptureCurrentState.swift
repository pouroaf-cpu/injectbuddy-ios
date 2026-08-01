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

    /// Frames taken so far this run, so an identical one is a failure rather than a
    /// file. This project has already shipped a "refreshed" set that came back
    /// byte-identical with matching checksums, because the taps had silently
    /// failed — the checksums were what eventually caught it, by hand. Doing it
    /// here means the run stops instead of a human noticing later.
    private var taken: [String: Data] = [:]

    private func shot(_ name: String,
                      file: StaticString = #filePath, line: UInt = #line) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation

        if let match = taken.first(where: { $0.value == png })?.key {
            XCTFail("\(name) is byte-identical to \(match) — the navigation between them did nothing.",
                    file: file, line: line)
            return
        }
        taken[name] = png

        try? png.write(to: dir.appendingPathComponent(name))
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

        // Scroll until the row is actually hittable, rather than swiping a fixed
        // number of times and hoping. At AX5 the calculator names wrap so hard that
        // four rows fill the display, so TRT sits well below the fold — that is why
        // this capture failed twice, once by photographing the Tools screen under
        // the calculator's filename and once by failing the run. Bounded, and a
        // failure here is a RED TEST rather than a missing file: an absent frame
        // reads as "nothing to see", and this is the most safety-critical screen in
        // the app and the only one that was never surveyed at large text.
        // Do NOT wait for existence first. At AX5 the list is lazy and the row is not
        // instantiated at all until it is scrolled near — `waitForExistence` on it
        // fails with "does not exist" while the row is perfectly reachable two swipes
        // away. Re-query inside the loop instead, and treat absent and present-but-
        // off-screen as the same condition: keep scrolling.
        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: "TRT Dose")
                .allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            // Tools is a `List`, which XCUITest surfaces as a collectionView or a
            // table depending on the style — NOT a scrollView. Asking only for
            // scrollViews found nothing to scroll and failed on attempt 0, on a
            // screen that scrolls perfectly well by hand.
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else {
                XCTFail("Nothing scrollable on screen after \(attempt) attempts.")
                return
            }
            list.swipeUp()
        }

        guard let trt = row else {
            XCTFail("TRT Dose never became hittable after 12 scrolls.")
            return
        }
        trt.tap()
        XCTAssertTrue(app.textFields["field_mgWeek"].waitForExistence(timeout: 8),
                      "Tapped TRT Dose and did not land on the calculator.")
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

        // NOT `scrollViews.firstMatch` — that is the off-canvas drawer at x = -344 —
        // and NOT `app.swipeUp()`, which resolved to a gesture the form did not
        // receive and produced a "scrolled" frame byte-identical to the unscrolled
        // one. The on-screen scroll view, explicitly.
        let form = app.scrollViews.allElementsBoundByIndex
            .first { $0.isHittable && $0.frame.minX >= 0 }
        XCTAssertNotNil(form, "No on-screen scroll view to scroll.")
        form?.swipeUp()
        shot("07-calculator-barrel-row.png")

        tab("Log dose")
        shot("08-logdose-sheet.png")
    }

    /// The keyboard toolbar, WITH the software keypad actually on screen.
    ///
    /// Focusing alone is not enough: this rig has a hardware keyboard attached, so
    /// iOS suppresses the software keypad and the accessory bar gets photographed
    /// sitting on the tab bar, in a position it will never occupy in front of a
    /// user. That frame looks like evidence and is not — a rig condition that does
    /// not announce itself in the image. Typing a character brings the keypad up,
    /// which is the only configuration where "the toolbar clears the pinned result
    /// bar" means anything.
    func testCaptureKeyboardToolbar() {
        openTRT()
        let field = app.textFields["field_mgWeek"]
        field.tap()
        field.typeText("300")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "No keyboard — the frame would not prove anything.")
        let keypadTop = app.keyboards.firstMatch.frame.minY
        XCTAssertLessThan(keypadTop, app.windows.firstMatch.frame.maxY,
                          "Keyboard is off-screen (\(keypadTop)) — hardware keyboard attached?")
        shot("11-calculator-keyboard-toolbar.png")
    }

    /// Set the size from the host first:
    ///   xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
    func testCaptureAX5Set() {
        tab("Dashboard")
        shot("09-dashboard-ax5.png")

        tab("Tools")
        shot("10-tools-ax5.png")

        openTRT()
        shot("12-calculator-trt-ax5.png")
    }
}
