import XCTest

/// **T-12, on the device.** `EodCollapseTests` pins the model and the arithmetic; this
/// pins the two things a unit test provably cannot see.
///
/// **WHY A UI TEST IS REQUIRED HERE AND NOT MERELY NICE.** `CalculatorLinkWithdrawalTests`
/// names its own blind spot in its header: a unit test asserts the MODEL the screens
/// read, and it cannot see a screen that stops reading the model — a `ForEach` restating
/// `allCases` inline is exactly how `DashboardScreen` came to offer all fifteen
/// calculators. So the collapse is asserted here against the rendered Tools list, not
/// only against `CalculatorCategory.members`.
///
/// And the second half is the condition the owner's decision rests on: EOD was removed
/// because *"that option is inside the TRT calc anyway"*. That claim is about a control
/// a user operates. The engine equivalence is pinned in the unit test; this proves the
/// control **reaches** it — the mode exists, the interval is selectable, and the screen
/// prints 3.50 injections a week.
///
/// FRAMES, written to the runner's Documents directory and printed for the host:
///   `t12-01-tools-no-eod.png`   the Tools list with no EOD row
///   `t12-02-trt-every-2-days.png`   TRT in Every N Days at 2, reading 3.50 / week
///
/// THE ASSERTIONS ARE THE PROOF; the frames are evidence for a reader. This project has
/// shipped a "refreshed" capture set that was byte-identical to the previous one, so a
/// photograph nobody asserted against is a photograph of whatever was on screen.
final class T12EodCollapseUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this needs the signed-in app.")
    }

    /// Staleness closed per NAME, immediately before the rewrite — never a directory
    /// sweep in `setUp`, which XCTest runs before EVERY test method and which once
    /// deleted the frames the previous test had just taken while reporting green.
    private func shot(_ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
        print("T12-FRAME: \(url.path)")
    }

    /// Tools, ARRIVAL ASSERTED. A tap is not arrival — three frames in the old archive
    /// were photographs of the previous screen under the next screen's name.
    private func openTools() {
        let tools = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tools.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tools.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "Tools exists but nothing hittable.")
        lowest?.tap()
        XCTAssertTrue(app.staticTexts["Reconstitution"].firstMatch.waitForExistence(timeout: 8),
                      "Tapped Tools and never arrived.")
    }

    // MARK: - 1. The collapse, on the rendered list

    /// The whole Tools list is walked, scrolling to the end, because EOD sat in the
    /// Hormone group ABOVE the fold on a list that scrolls — asserting only what is
    /// visible on arrival would pass with the row still present further down.
    func testToolsNoLongerListsTheEodCalculator() {
        openTools()

        // TRT is the anchor: it proves the Hormone group rendered at all. Without it,
        // "no EOD row" would also be satisfied by a list that failed to load.
        XCTAssertTrue(app.staticTexts["TRT Dose"].firstMatch.waitForExistence(timeout: 8),
                      "The Tools list has no TRT Dose row, so its absence of an EOD row "
                      + "proves nothing — the list did not render.")

        var seenEod = false
        var lastFrame = CGRect.zero
        for _ in 0..<12 {
            if app.staticTexts["TRT & EOD"].firstMatch.exists { seenEod = true; break }
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else { break }
            if list.frame == lastFrame { break }
            lastFrame = list.frame
            list.swipeUp()
        }

        XCTAssertFalse(seenEod,
                       "The Tools list still offers `TRT & EOD`. T-12 collapsed that "
                       + "calculator — the model says it is gone, so this screen is "
                       + "enumerating something other than CalculatorCategory.members.")
        shot("t12-01-tools-no-eod.png")
    }

    // MARK: - 2. The capability the removal depends on

    /// **The condition the owner's decision rests on.** Set Every N Days to 2 and the
    /// TRT calculator must report 3.50 injections a week — the exact constant the
    /// deleted EOD screen hardcoded.
    func testEveryNDaysReachesAnEveryOtherDayInterval() {
        openTools()

        let trtRow = app.staticTexts["TRT Dose"].firstMatch
        XCTAssertTrue(trtRow.waitForExistence(timeout: 8), "No TRT Dose row in Tools.")
        trtRow.tap()

        let nDays = app.textFields["field_nDays"]
        XCTAssertTrue(nDays.waitForExistence(timeout: 8),
                      "Tapped TRT Dose and did not land on it — `field_nDays` never "
                      + "appeared, so the Every N Days mode is not even on screen.")

        // The mode switcher is the thing EOD was collapsed INTO. If it is absent the
        // removal took a capability with it, which is the outcome the task said to stop on.
        //
        // ── THE IDENTIFIER HERE WAS WRONG ON THE FIRST RUN, AND THE FAILURE IS WHY THIS
        // ASSERTION EXISTS AT ALL. ────────────────────────────────────────────────────
        // It asked for `control_mode_Every N Days`, on the pattern
        // `control_<key>_<label>` used by `SegmentedRow`'s pills. `.modePicker` does not
        // render that control — it renders `ModeTab`, whose segments are keyed by VALUE,
        // not label: `mode_ndays`, `mode_perweek`, `mode_ml2mg`, inside a `mode_tab`.
        // So the run reported "the TRT calculator has no Every N Days mode control" when
        // the control was on screen the whole time.
        //
        // **A precondition that fails because the PROBE is wrong looks identical to one
        // that fails because the FEATURE is missing**, and here the two readings pointed
        // opposite ways: the second would have meant stopping the whole EOD removal. What
        // separated them was that `field_nDays` above had ALREADY been found — the
        // `ndays`-only field cannot render unless that mode is live. Left as a comment
        // rather than a silent fix, because the next person to write a mode assertion
        // will reach for the same wrong pattern.
        // Queried across ANY element type, not `app.buttons`. A SwiftUI `Button` with a
        // custom label and `.buttonStyle(.plain)` does not reliably surface in the
        // `.button` collection, and a type-restricted query that misses reports the
        // control as ABSENT — the second wrong probe in a row on this one assertion.
        let ndays = app.descendants(matching: .any).matching(identifier: "mode_ndays").firstMatch
        if !ndays.waitForExistence(timeout: 6) {
            // Print the tree rather than guess a third time. A precondition that keeps
            // failing needs to say what IS there, not just what is not.
            print("T12-TREE-DUMP:\n\(app.debugDescription)")
        }
        XCTAssertTrue(ndays.exists,
                      "The TRT calculator has no `Every N Days` mode segment. EOD was "
                      + "removed on the understanding that this exists. See T12-TREE-DUMP.")
        // Select it explicitly rather than trusting the spec default — the whole claim
        // is that a user can REACH this mode, not that it happens to be preselected.
        if ndays.isHittable { ndays.tap() }

        nDays.tap()
        if let existing = nDays.value as? String {
            for _ in 0..<existing.count { nDays.typeText(XCUIKeyboardKey.delete.rawValue) }
        }
        nDays.typeText("2")
        let done = app.buttons["kb_done"]
        if done.waitForExistence(timeout: 3) { done.tap() }

        XCTAssertEqual(nDays.value as? String, "2",
                       "The interval field did not take 2, so whatever the result says "
                       + "below is not the every-other-day case.")

        let cta = app.buttons["cta_see_result"]
        if cta.waitForExistence(timeout: 3), cta.isHittable { cta.tap() }

        // 7 / 2 = 3.5, formatted to two places — the same number `CalculatorEngine.eod`
        // hardcoded as 3.5 injections a week.
        let freq = app.staticTexts["3.50"]
        XCTAssertTrue(freq.waitForExistence(timeout: 8),
                      "TRT at Every N Days = 2 does not report 3.50 injections/week. The "
                      + "EOD screen was removed on the strength of that equivalence.")

        shot("t12-02-trt-every-2-days.png")
    }
}
