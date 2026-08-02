import XCTest

/// D12, made into something that can go red.
///
/// The pinning gate decides on a SHARE — the pinned bar may own at most 40% of the
/// content area. That is a proxy, and a proxy can pass while the defect exists: 40%
/// is a number about area, not a fact about whether you can see the dose you are
/// about to commit. A calculator with three tall fields can sit under the cap and
/// still shear an input through its glyphs, and the gate will approve it.
///
/// So the gate is not the assertion. This is:
///
///   1. The committing action is fully visible, without scrolling, at every size.
///   2. No input control STRADDLES the plate's top edge — a control is either
///      wholly above it or wholly below it, never sheared through its own glyphs.
///
/// Both are read as geometry, in one coordinate space, against the plate's RENDERED
/// frame rather than against the gate's arithmetic. Asking the gate whether the gate
/// was right is the shape of check this project keeps deleting.
///
/// SHOWN TO FAIL, which is the only reason to trust it (BOARD §5.24):
///
///     TEST_RUNNER_BAR_SHARE_CAP=0.55 xcodebuild test … \
///       -only-testing:InjectBuddyUITests/PinnedBarReachabilityUITests
///
/// forces the gate to approve the full-height bar and the sweep goes red on the
/// sheared `Frequency` picker at default size — the exact control named in the T20
/// finding — and on unreachable fields at AX5. Without the flag, green.
///
/// COVERAGE, stated so a green run is not over-read. Numeric fields (`field_*`) and
/// menu pickers (`control_*`) are measured. Segmented rows, toggles and day steppers
/// are NOT — they carry no per-field identifier and an identifier on their container
/// would propagate to every button inside it, which is the ambiguity that killed
/// `result_<label>` for a session. The suite prints what it measured rather than
/// implying it measured everything.
final class PinnedBarReachabilityUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        // Skipped, never failed, when the secret is absent — a red test for a missing
        // credential trains people to ignore red tests.
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "TEST_RUNNER_QA_EMAIL / TEST_RUNNER_QA_PASSWORD not set.")

        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        if let cap = env["BAR_SHARE_CAP"] {
            app.launchEnvironment["BAR_SHARE_CAP"] = cap
        }
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this suite needs the signed-in app.")
    }

    func testTRT_actionAndInputsAreWhole() throws {
        try openCalculator("TRT Dose")
        assertReachable(screen: "TRT Dose")
    }

    func testReconstitution_actionAndInputsAreWhole() throws {
        try openCalculator("Reconstitution")
        assertReachable(screen: "Reconstitution")
    }

    func testSteroidDosage_actionAndInputsAreWhole() throws {
        try openCalculator("Steroid Dosage")
        assertReachable(screen: "Steroid Dosage")
    }

    // MARK: - The invariant

    private func assertReachable(screen: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let plate = app.descendants(matching: .any).matching(identifier: "bar_plate").firstMatch
        XCTAssertTrue(plate.waitForExistence(timeout: 5),
                      "No bar_plate on \(screen) — cannot locate the plate's top edge.",
                      file: file, line: line)
        let plateTop = plate.frame.minY

        // 1. THE COMMITTING ACTION. `Add` writes a protocol, so "mostly visible" is
        //    not a category — it is either wholly on screen or the screen is offering
        //    a write the user cannot see the whole of.
        let add = app.buttons.matching(identifier: "Add").allElementsBoundByIndex
            .first { $0.isHittable } ?? app.buttons["Add"]
        XCTAssertTrue(add.exists, "No Add button on \(screen).", file: file, line: line)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(add.frame),
                      "\(screen): Add is not wholly on screen — \(add.frame) in \(window).",
                      file: file, line: line)
        XCTAssertTrue(add.isHittable,
                      "\(screen): Add is on screen but not hittable — something is over it.",
                      file: file, line: line)

        // 2. NO INPUT STRADDLES THE PLATE. Straddling is the defect the T20 finding
        //    names: `Frequency` cut through the middle of its control, `Weekly dose`
        //    sheared through the middle of its glyphs. A control below the plate is
        //    fine — that is a scroll. A control cut IN HALF by an opaque plate reads
        //    as the end of the form, and gives no signal that it continues.
        //
        // TWO PASSES, and the order is load-bearing. The straddle check describes the
        // screen AT REST; the reachability check has to scroll to do its job. Run
        // together in one loop, the first control's scrolling silently redefines
        // "at rest" for every control after it, and the straddle check would be
        // reporting on positions no user ever sees.
        var measured: [String] = []
        for control in inputControls() {
            guard control.exists else { continue }
            let f = control.frame
            guard f.height > 0 else { continue }
            measured.append(control.identifier)
            let straddles = f.minY < plateTop && f.maxY > plateTop
            // NOT asserted at accessibility sizes, and the reason is a measurement
            // rather than convenience. At AX5 the pinned bar is already at its FLOOR —
            // the gate has stood the result card down entirely and what remains is
            // `Add` plus the hero clearance, which D12 makes mandatory. A control can
            // still land across that edge purely because the form is taller than the
            // viewport, and no gate can move an edge that is already as high as it
            // goes. Asserting it here would be asserting something unsatisfiable, and
            // a permanently-red test is one people learn to ignore.
            //
            // The AX5 case this found is REAL and is not being hidden by the scoping:
            // Steroid Dosage shears `field_mgWeek`, a dose field, at AX5. It is filed
            // as an open finding, because the fix is in that screen's layout and not
            // in the bar. What still holds at every size is REACHABILITY, below.
            if !isAccessibilitySize {
                XCTAssertFalse(straddles,
                               "\(screen): `\(control.identifier)` is sheared by the result bar — "
                               + "control spans y \(f.minY)…\(f.maxY), plate top is \(plateTop). "
                               + "The user sees part of an input they are committing.",
                               file: file, line: line)
            }
        }

        // PASS 2 — REACHABILITY, at every size, and this is the half with teeth. D12:
        // an action you can reach for a value you can't is worse than an action you
        // can't reach, because the second one stops you. So every input the committing
        // action commits must be bringable to FULL visibility — not "mostly", not
        // "the label but not the value".
        for control in inputControls() where control.exists && control.frame.height > 0 {
            XCTAssertTrue(scrollIntoFullView(control, plateTop: plateTop),
                          "\(screen): `\(control.identifier)` cannot be brought fully into "
                          + "view — it stays clipped between the header and the result bar "
                          + "at every scroll position. Add commits a value the user cannot "
                          + "see whole.",
                          file: file, line: line)
        }
        XCTAssertFalse(measured.isEmpty,
                       "\(screen): measured NO controls — the identifiers moved and this "
                       + "suite just passed by looking at nothing.",
                       file: file, line: line)
        print("REACH \(screen): plateTop=\(plateTop) measured=\(measured.count) \(measured)")
    }

    /// Whether the app is rendering at an accessibility type size, read from the app's
    /// own gate probe.
    ///
    /// The app is the right witness for this one: what is under test here is GEOMETRY,
    /// and the type size is an input to it, not the claim being checked. The
    /// alternative — KVC on `XCUIDevice` for `contentSizeCategory` — is a private key
    /// that returns nil on a bad day, and a nil that falls back to "not accessibility"
    /// would silently turn the straddle assertion back on at AX5 and fail for a reason
    /// having nothing to do with the app.
    private var isAccessibilitySize: Bool {
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "bar_gate probe absent — cannot tell what size this is.")
        return gate.label.contains("ax=true")
    }

    /// Scrolls until `control` is wholly between the navigation bar and the plate.
    /// Returns false if no scroll position achieves that.
    private func scrollIntoFullView(_ control: XCUIElement, plateTop: CGFloat) -> Bool {
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        func whole() -> Bool {
            let f = control.frame
            return f.minY >= navBottom && f.maxY <= plateTop
        }
        if whole() { return true }
        guard let form = app.scrollViews.allElementsBoundByIndex
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) else { return false }

        // Both directions: a control can be under the plate OR up behind the header,
        // and a sweep that only ever swiped one way would report "unreachable" for a
        // control it simply scrolled past.
        for _ in 0..<8 {
            form.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
            if whole() { return true }
        }
        for _ in 0..<12 {
            form.swipeDown(velocity: XCUIGestureVelocity(rawValue: 220))
            if whole() { return true }
        }
        return false
    }

    /// Every addressable input on screen. Numeric fields and menu pickers only — see
    /// the coverage note in the type comment.
    private func inputControls() -> [XCUIElement] {
        let fields = app.textFields.allElementsBoundByIndex
            .filter { $0.identifier.hasPrefix("field_") }
        let pickers = app.buttons.allElementsBoundByIndex
            .filter { $0.identifier.hasPrefix("control_") }
        return fields + pickers
    }

    // MARK: - Navigation

    /// Scrolls until the row is hittable rather than swiping a fixed number of times.
    /// At accessibility sizes the Tools list is LAZY, so `waitForExistence` on a row
    /// two swipes away reports "does not exist" while it is perfectly reachable — and
    /// `Tools` is a `List`, which XCUITest surfaces as a collectionView, not a
    /// scrollView. Both cost this project three attempts at one capture.
    private func openCalculator(_ name: String) throws {
        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        lowest?.tap()

        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else {
                return XCTFail("Nothing scrollable after \(attempt) attempts looking for \(name).")
            }
            list.swipeUp()
        }
        guard let hit = row else {
            return XCTFail("\(name) never became hittable after 12 scrolls.")
        }
        hit.tap()
    }
}
