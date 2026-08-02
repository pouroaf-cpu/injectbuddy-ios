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

        // The runner's Documents directory SURVIVES between runs. When a frame is
        // skipped — the byte-identical guard returning early, or a run that fails
        // partway — the file from the PREVIOUS run is still sitting there under the
        // name this run was going to write, and the host copies it out as if it were
        // this run's evidence. Nearly measured one. Same family as the "refreshed"
        // set that came back byte-identical: the output directory holds exactly what
        // this run produced, or it is not evidence about this run.
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let stale = (try? FileManager.default.contentsOfDirectory(at: dir,
                                                                  includingPropertiesForKeys: nil)) ?? []
        for url in stale where url.pathExtension == "png" {
            try? FileManager.default.removeItem(at: url)
        }

        app = XCUIApplication()
        // `TEST_RUNNER_` reaches THIS process, not the app under test. Forwarding is
        // explicit, and the forwarded value is asserted where it lands (see
        // `testCaptureCalculatorAtRest`) — the first run with this override set
        // reported success while photographing the default gate, which is precisely
        // the "check that cannot fail" shape §5.24 is about.
        if let cap = ProcessInfo.processInfo.environment["BAR_SHARE_CAP"] {
            app.launchEnvironment["BAR_SHARE_CAP"] = cap
        }
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

        // `try?` used to swallow a failed write, so a frame could be "taken" and never
        // land — and with the directory surviving between runs, the host would then
        // copy out the PREVIOUS run's file under this name and measure it as evidence
        // about this commit. Both halves are closed: the directory is emptied in
        // setUp, and a frame that does not exist on disk afterwards fails the run
        // rather than resolving to whatever is sitting there.
        let url = dir.appendingPathComponent(name)
        do {
            try png.write(to: url)
        } catch {
            return XCTFail("Could not write \(name): \(error)", file: file, line: line)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.", file: file, line: line)
        print("CAPTURE-HOME: \(dir.path)")
    }

    /// `shot`, but a repeat returns false instead of failing the run — for a SEARCH
    /// that walks a scroll to its end, where "nothing moved" is the terminating
    /// condition rather than a broken gesture. Every other capture keeps the strict
    /// form; the caller here still has to prove drags work at all.
    @discardableResult
    private func shotAllowingScrollEnd(_ name: String) -> Bool {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if taken.values.contains(png) { return false }
        taken[name] = png
        try? png.write(to: dir.appendingPathComponent(name))
        return true
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

    private func openTRT() { openCalculator(named: "TRT Dose", expecting: "field_mgWeek") }

    /// Any calculator by its row label, asserting the DESTINATION before returning.
    /// `12-calculator-trt-ax5` was once a genuine photograph of the Tools screen under
    /// a filename claiming the calculator, because navigation failed and the run
    /// continued — so arriving is asserted, not assumed.
    private func openCalculator(named name: String, expecting field: String) {
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
            row = app.staticTexts.matching(identifier: name)
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
                XCTFail("Nothing scrollable on screen after \(attempt) attempts looking for \(name).")
                return
            }
            list.swipeUp()
        }

        guard let hit = row else {
            XCTFail("\(name) never became hittable after 12 scrolls.")
            return
        }
        hit.tap()
        XCTAssertTrue(app.textFields[field].waitForExistence(timeout: 8),
                      "Tapped \(name) and did not land on it — \(field) never appeared.")
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

    /// T20/T21 — the TRT calculator at rest, at whatever content size the DEVICE is
    /// set to, plus the chrome geometry needed to turn a PNG into a percentage.
    ///
    /// The frame is the evidence; the printed numbers are only the denominators.
    /// D11 says measure the LAYOUT off the framebuffer, not the view hierarchy —
    /// so what this prints is the fixed chrome (header bottom, tab bar top, screen
    /// height) which is what "the content area" MEANS, and the bar's extent is then
    /// read off the pixels. Asking the hierarchy how tall the bar is would be
    /// measuring what the layout claims rather than what the user sees.
    ///
    ///     xcrun simctl ui booted content_size large \
    ///       && TEST_RUNNER_CAPTURE=1 xcodebuild test … \
    ///          -only-testing:InjectBuddyUITests/CaptureCurrentState/testCaptureCalculatorAtRest
    func testCaptureCalculatorAtRest() {
        openTRT()

        // Named by the size so two runs at two sizes cannot overwrite each other —
        // and a run that failed to change the device size produces a filename that
        // says so rather than a quietly-replaced frame.
        let size = ProcessInfo.processInfo.environment["SIZE_LABEL"] ?? "unknown"
        shot("20-calculator-trt-\(size).png")

        let screen = app.windows.firstMatch.frame
        // The tab bar and the header are the two fixed edges. Both are addressed by
        // content, not by a container identifier, because the shell does not publish
        // one — so this asserts what it found rather than trusting a first match.
        let dashTab = app.buttons.matching(identifier: "Dashboard")
            .allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(dashTab, "No hittable Dashboard tab — cannot locate the tab bar.")

        // The nav bar has NO pixel signature on this screen — it is drawn on the same
        // #FAFAFB canvas as the form, so a band profile cannot find its bottom edge.
        // That is the one thing here the hierarchy has to supply; the bar's extent,
        // which is what is actually being judged, is still read off the pixels.
        let nav = app.navigationBars.firstMatch
        // What the GATE computed, not what the frame looks like. The frame is checked
        // separately, by band profile, and the two are meant to be cross-checkable.
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "bar_gate probe absent — DEBUG build?")
        print("GATE \(gate.label)")

        // The override has to be OBSERVED to have arrived. Without this the run is
        // green either way and the frame is filed under a cap it was not taken at.
        if let want = ProcessInfo.processInfo.environment["BAR_SHARE_CAP"],
           let wanted = Double(want) {
            XCTAssertTrue(gate.label.contains(String(format: "cap=%.4f", wanted)),
                          "BAR_SHARE_CAP=\(want) never reached the app — gate reports: \(gate.label)")
        }
        print("GEOM screen=\(screen.minY),\(screen.height) "
              + "navBottom=\(nav.exists ? nav.frame.maxY : -1) "
              + "tabTop=\(dashTab?.frame.minY ?? -1) "
              + "size=\(size)")
    }

    /// T21 — the WORST composite under the translucent plate, not a representative one.
    ///
    /// A material's legibility is a property of what is behind it, so a frame shot
    /// against the form's white cards proves nothing about the frame shot against the
    /// navy barrel selection. This walks the form under the plate one swipe at a time
    /// and keeps every position; the host then measures each and takes the darkest
    /// background behind the `#075E56` values as the number that counts.
    ///
    /// Searched rather than guessed. "The busiest content" is a claim about a layout
    /// nobody has looked at scrolled to an arbitrary offset, and this project has
    /// already shipped one frame that flattered the fix it was taken to prove.
    func testCaptureWorstComposite() {
        openTRT()
        let size = ProcessInfo.processInfo.environment["SIZE_LABEL"] ?? "unknown"

        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "bar_gate probe absent — DEBUG build?")
        print("GATE \(gate.label)")

        let form = app.scrollViews.allElementsBoundByIndex
            .first { $0.isHittable && $0.frame.minX >= 0 }
        XCTAssertNotNil(form, "No on-screen scroll view to scroll.")

        // Position 0 is at rest; each subsequent frame is one swipe further in. The
        // byte-identical guard in `shot` is what stops a swipe that never landed from
        // being recorded as a distinct scroll position.
        // NOT swipeUp(). A flick carries momentum and took this form from rest to its
        // scroll end in one gesture, so the series held two positions and neither had
        // any content behind the plate at all — the material was measured against an
        // empty backdrop, which is the FLATTERING case, not the worst one. A slow drag
        // has no momentum and lands where it is told.
        shot("30-composite-\(size)-0.png")
        var moved = 0
        for step in 1...6 {
            // Velocity, not duration. A 0.4s press-then-drag registered as a PRESS and
            // moved the form zero pixels — caught by the assertion below rather than
            // by six identically-named frames. A slow swipe is still a swipe.
            form!.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
            // A repeat here means the scroll END, which is a legitimate stop — unlike a
            // gesture that never landed. The two are told apart by asserting the FIRST
            // drag moved something: if drags do not work at all, position 1 repeats and
            // the run fails instead of quietly recording one frame six times.
            if !shotAllowingScrollEnd("30-composite-\(size)-\(step).png") {
                XCTAssertGreaterThan(moved, 0,
                    "The first drag moved nothing — drags are not reaching this form, "
                    + "so the series would be one frame under six names.")
                break
            }
            moved += 1
        }
        print("COMPOSITE positions=\(moved + 1)")
    }

    /// One frame per candidate plate material, same screen, same scroll position.
    ///
    /// A sweep rather than five separate runs, because the thing being compared is a
    /// COLOUR and five runs at five wall-clock times against a device whose status bar
    /// clock is in the frame is five variables where one is wanted.
    func testSweepPlateMaterials() {
        for material in ["ultraThin", "thin", "regular", "thick", "bar"] {
            app.terminate()
            app.launchEnvironment["PLATE_MATERIAL"] = material
            app.launch()
            let accept = app.buttons["I understand"]
            if accept.waitForExistence(timeout: 4) { accept.tap() }
            openTRT()
            shot("40-plate-\(material).png")
        }
    }

    /// The three frames T20/T21 actually changed, at DEFAULT size only.
    ///
    /// Deliberately not the whole set. Dashboard, calendar, tools, add and the log
    /// sheet are untouched by this work, and a reshoot with no change spends a serial
    /// and a log row saying nothing — which also makes the log harder to read for the
    /// frames that did move.
    func testCaptureT20Refresh() {
        openTRT()
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "bar_gate probe absent — DEBUG build?")
        print("GATE \(gate.label)")
        shot("06-calculator-trt.png")

        let form = app.scrollViews.allElementsBoundByIndex
            .first { $0.isHittable && $0.frame.minX >= 0 }
        XCTAssertNotNil(form, "No on-screen scroll view to scroll.")
        form?.swipeUp()
        shot("07-calculator-barrel-row.png")

        // Back to the top before focusing, so the keypad frame is comparable with the
        // one it supersedes rather than being shot at an arbitrary scroll offset.
        form?.swipeDown()
        form?.swipeDown()
        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No weekly dose field.")
        field.tap()
        field.typeText("300")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "No keyboard — the frame would not prove anything.")
        XCTAssertLessThan(app.keyboards.firstMatch.frame.minY,
                          app.windows.firstMatch.frame.maxY,
                          "Keyboard is off-screen — hardware keyboard attached?")
        shot("11-calculator-keyboard-toolbar.png")
    }

    /// `Steroid Dosage` at whatever size the device is set to, for the shear that the
    /// reachability sweep found and nobody has ever seen.
    ///
    /// The finding exists only as coordinates — `field_mgWeek` spanning y 636.33…701.33
    /// against a plate top of 651.67 — and the person who has to decide how much it
    /// matters cannot read a pair of numbers. §5.15: this screen has never been captured
    /// at large text, and the last screen that had never been captured at large text
    /// held the worst finding on the board.
    ///
    /// The BEFORE frame is the one that matters. A fix commit with no photograph of what
    /// it fixed is a claim.
    ///
    ///     xcrun simctl ui booted content_size accessibility-extra-extra-extra-large \
    ///       && TEST_RUNNER_CAPTURE=1 TEST_RUNNER_SIZE_LABEL=ax5 xcodebuild test … \
    ///          -only-testing:InjectBuddyUITests/CaptureCurrentState/testCaptureSteroidDosage ; \
    ///     xcrun simctl ui booted content_size large
    func testCaptureSteroidDosage() {
        openCalculator(named: "Steroid Dosage", expecting: "field_mgWeek")
        let size = ProcessInfo.processInfo.environment["SIZE_LABEL"] ?? "unknown"

        // Assert the DEFECT is in the frame before shooting it. A "before" photograph
        // that does not contain the thing it is evidence of is worse than none — it
        // reads as proof and disproves nothing, which is the whole §5.24 family. If the
        // shear is not there, the run fails and no file is written.
        let plate = app.descendants(matching: .any).matching(identifier: "bar_plate").firstMatch
        XCTAssertTrue(plate.waitForExistence(timeout: 5), "No bar_plate — cannot locate the edge.")
        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.exists, "No field_mgWeek on Steroid Dosage.")
        let plateTop = plate.frame.minY
        let f = field.frame
        XCTAssertTrue(f.minY < plateTop && f.maxY > plateTop,
                      "field_mgWeek is NOT sheared here (spans \(f.minY)…\(f.maxY), plate top "
                      + "\(plateTop)) — this frame is not evidence of the finding. Either the "
                      + "defect is gone, in which case delete its expectedShears entry, or the "
                      + "rig is not at the size the filename claims.")
        print("SHEAR field_mgWeek spans \(f.minY)…\(f.maxY), plateTop=\(plateTop)")

        shot("13-calculator-steroid-\(size).png")
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
