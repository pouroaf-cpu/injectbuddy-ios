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
    /// Something only the destination renders. **A tab tap is not arrival**, and this is
    /// the difference between the two.
    ///
    /// ─── WHY, AND IT COST TWO CAPTURE CYCLES ───────────────────────────────────────
    ///
    /// `shot()` used to fire during the cross-fade after `tab()`, so **every shell frame
    /// landed one screen behind.** `03-calendar-IB2245755.png` in `2026-08-02-current` is
    /// the DASHBOARD mid-fade; `04-tools-IB2245756.png` is the CALENDAR, with a
    /// **pre-H6** Tools list ghosting behind it. Both were filed as evidence and one
    /// finding was read off the second.
    ///
    /// **Why nothing caught it — this is the transferable part.** `shot()` fails a frame
    /// that is BYTE-IDENTICAL to a previous one. A mid-transition frame is byte-identical
    /// to *nothing*, so it passes every check that looks for repetition **while being a
    /// photograph of a different screen.** ***Repetition-detection cannot detect
    /// wrongness.***
    ///
    /// **And why the calculator captures were already safe:** a frame that renders its
    /// own identity is self-verifying. `19-calculator-semaglutide.png` has the word
    /// `Semaglutide` in its pixels, so a mistimed capture would be visibly wrong.
    /// `03-calendar` has nothing in it that says "calendar" — **which is exactly why the
    /// defect could live there.** So an identity assertion is **mandatory for shell
    /// frames and belt-and-braces for the rest, and that is a property of the SCREEN,
    /// not of this harness's mood.**
    ///
    /// **NOT a settle-wait.** A sleep is a guess that gets tuned until it stops failing.
    /// This cannot pass on the previous screen at any timing.
    private enum ShellTab: String {
        case dashboard = "Dashboard"
        case calendar = "Calendar"
        case tools = "Tools"
        case add = "Add"
        /// The raised hero slot. It presents a SHEET rather than switching tab, so its
        /// proof is the sheet's own title — arrival here means the sheet is up, not that
        /// a tab changed. **This case exists because the assertion refused to capture it
        /// without one**, which is the enumeration doing its job on its second run.
        case logDose = "Log dose"

        /// Enumerated, with no `default`: a new tab cannot be captured until someone
        /// says what proves you have arrived on it.
        var arrivalProof: (query: (XCUIApplication) -> XCUIElement, what: String) {
            switch self {
            case .dashboard:
                return ({ $0.descendants(matching: .any)
                            .matching(identifier: "cta_add_protocol").firstMatch },
                        "the Protocols section's Add control")
            case .calendar:
                return ({ $0.buttons["Today"].firstMatch }, "the calendar's Today button")
            case .tools:
                return ({ $0.staticTexts["Reconstitution"].firstMatch },
                        "a calculator row (Reconstitution)")
            case .add:
                // The FOOTER, not the "What are you adding?" header. That header is a
                // `Section` header under `.insetGrouped`, which SwiftUI UPPERCASES — so
                // `staticTexts["What are you adding?"]` never matches and the proof
                // fails on a screen it is standing on. Caught on the first run of this
                // assertion, which is the assertion working: a wrong proof fails loudly
                // instead of letting a frame be shot on trust.
                //
                // The footer is unique to this screen and is not case-transformed.
                return ({ $0.staticTexts["Pick a category to find the right calculator, "
                                         + "fill it in, then add it to your protocols."].firstMatch },
                        "the Add screen's footer")
            case .logDose:
                // The sheet's navigation title. Not the "Which protocol?" header — that
                // one is `.uppercased()` in the source, so the string here and the string
                // in the tree are different, which is the trap the Add proof already hit.
                return ({ $0.navigationBars["Log a dose"].firstMatch },
                        "the Log a dose sheet's title")
            }
        }
    }

    private func tab(_ label: String) {
        let matches = app.buttons.matching(identifier: label)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 8), "No \(label) tab.")
        let lowest = matches.allElementsBoundByIndex
            .filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "\(label) exists but nothing hittable.")
        lowest?.tap()
        _ = app.wait(for: .runningForeground, timeout: 2)

        // ARRIVAL, ASSERTED. A tab whose destination this harness does not know how to
        // recognise fails loudly rather than being captured on trust.
        guard let destination = ShellTab(rawValue: label) else {
            return XCTFail("`tab(\"\(label)\")` has no arrival proof. Add one to `ShellTab` "
                           + "before capturing it — a frame taken on trust is how "
                           + "`03-calendar` came to be a photograph of the Dashboard.")
        }
        let proof = destination.arrivalProof
        XCTAssertTrue(proof.query(app).waitForExistence(timeout: 8),
                      "Tapped \(label) but never arrived: \(proof.what) is not on screen. "
                      + "Any frame taken here would be a photograph of the PREVIOUS screen "
                      + "under a filename claiming \(label).")
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
    /// Measure the LAYOUT off the framebuffer, not the view hierarchy —
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

    /// TRT's `Ester` picker, scrolled into view — a SECOND screen and a SECOND control,
    /// to settle whether the overlap on `Steroid Dosage` is that screen's or the shared
    /// picker's. T1's lesson: "the TRT dose field" and "every dose field in the app"
    /// were different findings and only the second was true.
    func testCaptureEsterPickerAtSize() {
        openTRT()
        let size = ProcessInfo.processInfo.environment["SIZE_LABEL"] ?? "unknown"

        let ester = app.buttons["control_esterType"]
        guard let form = app.scrollViews.allElementsBoundByIndex
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) else {
            return XCTFail("No on-screen scroll view.")
        }
        for _ in 0..<8 where !(ester.exists && ester.isHittable) {
            form.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
        }
        XCTAssertTrue(ester.exists, "control_esterType never appeared.")
        print("ESTER frame=\(ester.frame) label=\(ester.label)")
        shot("14-calculator-trt-ester-\(size).png")
    }

    // MARK: - The full default-size sweep

    /// EVERY screen, at DEFAULT content size, at ONE SHA, in ONE run.
    ///
    /// Why this is not the "three frames only" refresh: `2026-08-02-current` was
    /// INTERNALLY INCONSISTENT. `02`–`05` and `08` were shot at 10:38 — before the
    /// measured pinning gate, before the material, before the type scale landed in its
    /// final form — while `06`/`07`/`11` are from after. A folder called "current state"
    /// held two different builds photographed an hour apart, which is §5.31: a name
    /// outliving its content.
    ///
    /// So this is ONE test method rather than several, deliberately. `taken` is
    /// per-instance, so a method boundary resets the byte-identical guard and relaunches
    /// the app; one method keeps the whole sweep under one guard and one launch.
    ///
    /// THE BYTE-IDENTICAL GUARD IS NOT THE ARRIVAL CHECK, and it is weaker than it
    /// looks here: the status-bar clock is in every frame, so two shots of the same
    /// screen a minute apart are not byte-identical and the guard passes. It catches a
    /// dead tap within the same clock minute and nothing more. What actually stops a
    /// frame being filed under the wrong screen's name is `openCalculator`'s assertion
    /// on the NAVIGATION BAR TITLE, below — and that assertion was shown red before
    /// this run was trusted.
    ///
    ///     xcrun simctl ui booted content_size large \
    ///       && TEST_RUNNER_CAPTURE=1 TEST_RUNNER_SIZE_LABEL=default xcodebuild test … \
    ///          -only-testing:InjectBuddyUITests/CaptureCurrentState/testCaptureFullDefaultSweep ; \
    ///     xcrun simctl ui booted content_size large
    ///
    /// NOT SHOT, and both are decisions rather than omissions: the drawer and Settings
    /// render the account's real email and avatar (standing decision, and these frames
    /// go into a chat window); and the welcome/signed-out path costs the Keychain
    /// session and a real sign-in to recover.
    func testCaptureFullDefaultSweep() {
        // THE RIG SIZE, ASSERTED BEFORE ANY FRAME IS WRITTEN. Every filename in this
        // sweep claims "default". Until `size=` was added to the gate probe, nothing in
        // the harness could tell `large` from `xxxLarge` — `ax=false` is true for both —
        // so a run at the wrong size produced a full set of frames that lie, and reported
        // success. Asserted once, at the top, so the whole run is gated on it.
        openTRT()
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "bar_gate probe absent — DEBUG build?")
        XCTAssertTrue(gate.label.contains("size=large"),
                      "The rig is NOT at default content size — gate reports: \(gate.label). "
                      + "Every frame in this sweep would be filed under a name claiming "
                      + "default. Run `xcrun simctl ui booted content_size large` first.")
        print("GATE \(gate.label)")
        toolsRoot()

        // ── The shell ───────────────────────────────────────────────────────────────
        tab("Dashboard");  shot("02-dashboard.png")
        tab("Calendar");   shot("03-calendar.png")
        tab("Tools");      shot("04-tools.png")
        tab("Add");        shot("05-add.png")

        tab("Log dose")
        XCTAssertTrue(app.navigationBars["Log a dose"].waitForExistence(timeout: 8),
                      "Log-dose sheet never presented.")
        shot("08-logdose-sheet.png")
        app.buttons["Cancel"].firstMatch.tap()

        // ── Every calculator, in enum order ─────────────────────────────────────────
        // The three TRT frames keep their existing numbers so they read against the
        // frames they supersede; the twelve that have never been shot at default take
        // 15–28. `Steroid Dosage` and `Reconstitution` are in here for the FIRST TIME at
        // this size — Reconstitution carries the `Units (U-100)` × tab-bar overlap at
        // default, an open finding with no photograph.
        // `fromTools: false` on exactly one row, and it is a FINDING rather than a
        // harness convenience — see `openCalculator`. It is asserted from both ends: a
        // row flagged false that turns up on Tools fails the run asking for the flag to
        // be deleted, so the day `Cycle Plotter` is put in a category this stops lying.
        let sweep: [(name: String, file: String, fromTools: Bool)] = [
            ("TRT Dose",       "06-calculator-trt",            true),
            ("TRT & EOD",      "15-calculator-eod",            true),
            ("HCG",            "16-calculator-hcg",            true),
            ("Peptide",        "17-calculator-peptide",        true),
            ("Reconstitution", "18-calculator-reconstitution", true),
            ("Semaglutide",    "19-calculator-semaglutide",    true),
            ("Tirzepatide",    "20-calculator-tirzepatide",    true),
            ("Retatrutide",    "21-calculator-retatrutide",    true),
            ("BPC-157",        "22-calculator-bpc157",         true),
            ("BPC+TB500",      "23-calculator-bpc157blend",    true),
            // `BMI` (`24-calculator-bmi`) and `Free T Index` (`25-calculator-freetest`)
            // were REMOVED 2026-08-03, and not because the capture broke.
            //
            // Both calculators are WITHDRAWN by the owner's decision (H6, `bf52ecc`) —
            // "no layout work, no shear work, no styling on either screen". Photographing
            // them every sweep is layout work by another name.
            //
            // The route is also gone, so this could not be repaired by flipping
            // `fromTools` to `false`: `NavItems.isListed` removes both from all four
            // browse surfaces — Tools, the drawer, the dashboard add-dialog and
            // `AddCategoryScreen` — so NOTHING in the app reaches either screen now.
            //
            // The existing frames `IB2245771` / `IB2245772` are NOT deleted; they are
            // evidence and the archive is left alone. Their `SCREENSHOT-LOG.md` and
            // `2026-08-02-current/README.md` rows carry a dated retirement note, because
            // a frame that stops being taken with no note is indistinguishable from a
            // frame that failed to take.
            //
            // If either calculator is ever re-listed, these two entries come back IN THE
            // SAME COMMIT that re-lists it — same rule as the Add-gate test leg in
            // `CalculatorWiringUITests`.
            ("TRT Microdose",  "26-calculator-microdose",      true),
            ("Steroid Dosage", "28-calculator-steroid",        true),
            // `Cycle Plotter` is NOT in this list — it is captured last, after the F-F
            // frame, and the ordering is load-bearing rather than tidy. It is the one
            // frame reached by a route the harness had never driven, and when that route
            // failed it took the whole run down with it — twice, at thirteen minutes a
            // time, discarding twenty-two frames that had already been taken correctly.
            // Putting a known-fragile step last does not hide it: it still fails the run,
            // it just stops costing the frames that have nothing to do with it.
        ]

        // F-F says the hero circle covers the disclaimer tail on EVERY calculator at
        // default size. That is asserted for THREE of them in `LeafOverlapUITests` and
        // claimed for the rest. Measuring it on all fifteen here costs one scroll each
        // and turns the claim into an enumeration — and it picks the frame to shoot on a
        // measurement rather than on which one looked worst to me.
        var heroOverlaps: [(name: String, area: CGFloat, rect: CGRect)] = []

        for (name, file, fromTools) in sweep {
            openCalculator(named: name, fromTools: fromTools)
            shot("\(file).png")

            if name == "TRT Dose" {
                // The barrel row and the keypad, while we are here — same visit, same
                // scroll origin as the frames they supersede.
                guard let form = onScreenScrollView() else { return XCTFail("No scroll view on TRT.") }
                form.swipeUp()
                shot("07-calculator-barrel-row.png")
                form.swipeDown(); form.swipeDown()

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
                app.buttons["kb_done"].firstMatch.tap()
            }

            if let hit = measureDisclaimerOcclusion(on: name) {
                heroOverlaps.append(hit)
            }
            toolsRoot()
        }

        // ── F-F ─────────────────────────────────────────────────────────────────────
        // NO SEPARATE FRAME IS SHOT FOR THIS, and that is the finding rather than a
        // saving. The overlap exists only at REST, and the at-rest frame of the
        // calculator it happens on has already been taken in the loop above — so a
        // dedicated F-F capture would be a byte-identical duplicate of
        // `18-calculator-reconstitution` under a second serial, which is precisely the
        // "spends a serial saying nothing" the three-frame refresh was cut down for.
        // The README names which frame carries the finding instead.
        let ranked = heroOverlaps.sorted { $0.area > $1.area }
        for h in ranked {
            print(String(format: "DISCLAIMER-OCCLUDED %@ area=%.1fpt² rect=%@",
                         h.name, h.area, NSCoder.string(for: h.rect)))
        }

        // ─── WHAT THIS ASSERTS, AND WHY IT IS NOT A TRIPWIRE ON THE WON'T-FIX ───────
        //
        // It used to assert `!ranked.isEmpty` — "the hero overlaps SOMEWHERE" — as a
        // guard against F-F silently lapsing. **That assertion was retired 2026-08-03,
        // and it behaved correctly right up to the end:** it refused to let a change
        // pass unnoticed and its message said in terms *"do not close F-F on this"*.
        // It is gone because the world changed and because the probe behind it was
        // measuring one occluder out of three — not because it was wrong.
        //
        // F-F itself is **struck as WON'T FIX by the owner** (H4; `BOARD.md:373`,
        // `TASKS.md:221`). H4 deliberately removed the expected-failure entries so the
        // suite would stop tracking a debt nobody intends to pay, so a check that goes
        // red on the accepted condition is **a permanent red by decision — the stale
        // pass wearing the other colour.**
        //
        // So: **measure and report every calculator, assert only the enumerated set that
        // currently clears.** Report-only would leave nothing able to fail — if
        // Reconstitution's disclaimer disappeared next week the sweep would print a
        // number into a log and stay green. An enumerated must-hold set asserts what is
        // TRUE, can only shrink deliberately, and gives regression cover without
        // carrying a red for something the owner has accepted.
        let occludedNames = Set(ranked.map(\.name))
        let regressed = Self.disclaimerMustClear.intersection(occludedNames).sorted()
        XCTAssertTrue(regressed.isEmpty,
                      "REGRESSION: \(regressed.joined(separator: ", ")) — the disclaimer is "
                      + "in `disclaimerMustClear` because it was measured CLEAR of the pinned "
                      + "bottom furniture on 2026-08-03, and it no longer is. This is not F-F "
                      + "re-opening (F-F is struck won't-fix, H4): it is a screen that was "
                      + "good regressing. Fix it, or remove it from the set DELIBERATELY and "
                      + "say why.")

        // ── Cycle Plotter, last, by the only route that reaches it ──────────────────
        openCalculator(named: "Cycle Plotter", fromTools: false)
        shot("27-calculator-plotter.png")
    }

    /// The on-screen form scroll view. NOT `scrollViews.firstMatch` — that is the
    /// off-canvas drawer at x = -344.
    ///
    /// Retried, because "not there yet" and "not there" are different and this could not
    /// tell them apart. Straight after a tab switch the dashboard's scroll view is not
    /// yet hittable, so a single query returned nil and the run failed with "No dashboard
    /// scroll view" on a screen that plainly has one — while the same code passed in a
    /// standalone probe, where the app had launched onto that tab and settled.
    private func onScreenScrollView(retries: Int = 0) -> XCUIElement? {
        for _ in 0...max(0, retries) {
            if let hit = app.scrollViews.allElementsBoundByIndex
                .first(where: { $0.isHittable && $0.frame.minX >= 0 }) {
                return hit
            }
            _ = app.staticTexts.firstMatch.waitForExistence(timeout: 1)
        }
        return nil
    }

    /// Back to the Tools LIST, at the TOP.
    ///
    /// Two things that are easy to get wrong and both were. Each tab owns its own
    /// `NavigationStack` (`MainShell`), so tapping the Tools TAB while a calculator is
    /// pushed does not pop it — the back button has to be tapped. And the row search
    /// below only ever scrolls DOWN, so a list left at the bottom by the previous
    /// calculator would never find a row above it: the reset is what makes the sweep
    /// order-independent rather than accidentally alphabetical.
    private func toolsRoot() {
        let back = app.navigationBars.buttons.matching(identifier: "Tools").firstMatch
        if back.exists && back.isHittable { back.tap() }
        tab("Tools")
        if let list = (app.collectionViews.allElementsBoundByIndex
                       + app.tables.allElementsBoundByIndex
                       + app.scrollViews.allElementsBoundByIndex)
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) {
            for _ in 0..<8 { list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 500)) }
        }
    }

    /// Any calculator by row label, asserting arrival on the NAV BAR TITLE.
    ///
    /// The existing `openCalculator(named:expecting:)` asserts a named text field, which
    /// only works for calculators that have one — `BMI`, `Free T Index` and
    /// `Cycle Plotter` do not share a field key with the rest. The title is the screen's
    /// own identity and every route publishes it (`RouteContent.navigationTitle`).
    ///
    /// SHOWN RED BEFORE IT WAS TRUSTED: asserted `Reconstitution` after tapping
    /// `TRT Dose` and the run failed with "landed on TRT Dose". An arrival check that has
    /// never been watched to fail is the thing that let a photograph of the Tools screen
    /// ship under a calculator's filename.
    ///
    /// `fromTools: false` — `CYCLE PLOTTER IS NOT ON THE TOOLS SCREEN`, and this run is
    /// how that was found rather than a thing anyone knew. The first sweep died on
    /// "Cycle Plotter never became hittable after 12 scrolls" after finding the other
    /// thirteen by the identical mechanism, which is the behavioural half; the source
    /// half is that `CalculatorCategory.members` enumerates 14 of the 15 slugs and
    /// `.cyclePlotter` is in none of them, so `ToolsScreen` — whose own comment says it
    /// "Shows ALL calculators including the ones that cannot save a protocol (BMI, Free
    /// T Index, the plotter)" — cannot render it. It is reachable only from the
    /// dashboard's `Add a protocol` dialog, which enumerates `allCases`. So the frame is
    /// taken by that route rather than dropped, and the finding is recorded here and on
    /// the board instead of living in a harness workaround.
    private func openCalculator(named name: String, fromTools: Bool = true) {
        toolsRoot()
        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            guard let list = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first(where: { $0.isHittable && $0.frame.minX >= 0 }) else {
                return XCTFail("Nothing scrollable after \(attempt) attempts looking for \(name).")
            }
            list.swipeUp()
        }

        // BOTH ENDS (§5.30). A row declared absent from Tools that turns up there is a
        // debt that has been paid, and leaving the flag in place would route the frame
        // through a fallback nobody needs any more — silently, since the fallback works.
        guard fromTools else {
            XCTAssertNil(row, "`\(name)` IS on the Tools screen now. It is flagged "
                         + "`fromTools: false` because it was absent — delete the flag.")
            print("ROUTE \(name): NOT on Tools; reached via the dashboard `Add a protocol` dialog.")
            openFromDashboardDialog(name)
            return
        }

        guard let hit = row else { return XCTFail("\(name) never became hittable after 12 scrolls.") }
        hit.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 8),
                      "Tapped `\(name)` and did not land on it — no navigation bar titled "
                      + "`\(name)`. Present instead: "
                      + app.navigationBars.allElementsBoundByIndex
                          .map(\.identifier).joined(separator: ", "))
    }

    /// The only route in the app that reaches every calculator: the dashboard's
    /// `Add a protocol` confirmation dialog, which enumerates `CalculatorSlug.allCases`.
    ///
    /// Worth knowing what this route IS while using it. `AddScreen` deliberately filters
    /// to `savableMembers` because — its own words — "a calculator with no save path
    /// strands them at the last step". This dialog does no such filtering, so it offers
    /// `BMI`, `Free T Index` and `Cycle Plotter` under the title `Add a protocol`, and
    /// none of the three can save one. Filed; not fixed here.
    private func openFromDashboardDialog(_ name: String) {
        tab("Dashboard")
        guard let scroll = onScreenScrollView(retries: 8) else {
            return XCTFail("No dashboard scroll view after 8 retries.")
        }

        // THE TAB BAR HAS ITS OWN `Add`, WITH THE SAME `plus` GLYPH, and the Protocols
        // section's button starts BELOW THE FOLD on this account. The first attempt took
        // "the highest hittable Add", which — with the real one off-screen — was the TAB
        // ITEM. That lands on `AddScreen`, where `Cycle Plotter` is filtered out on
        // purpose, so the run concluded "not in the dialog either… unreachable from
        // anywhere in the app" about a dialog that had never been opened. Exactly the
        // §5.24 shape pointed the other way: an assertion failing for a reason that has
        // nothing to do with what it claims to measure.
        //
        // So: only buttons ABOVE the tab bar, and scroll until one appears.
        let tabTop = app.buttons.matching(identifier: "Dashboard").allElementsBoundByIndex
            .filter { $0.isHittable }.map(\.frame.minY).max() ?? .greatestFiniteMagnitude
        func sectionAdd() -> XCUIElement? {
            app.buttons.allElementsBoundByIndex.first {
                ($0.identifier == "Add" || $0.label == "Add")
                    && $0.isHittable && $0.frame.maxY < tabTop
            }
        }
        var target = sectionAdd()
        for _ in 0..<6 where target == nil {
            scroll.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
            target = sectionAdd()
        }
        guard let add = target else {
            return XCTFail("No `Add` button above the tab bar (top \(tabTop)) on the dashboard "
                           + "after scrolling — cannot open the calculator dialog.")
        }
        print("ROUTE dashboard Add button at \(add.frame), tab bar top \(tabTop)")
        add.tap()

        // ASSERT THE DIALOG IS OPEN before drawing any conclusion about its contents.
        // Without this, a tap that went somewhere else reports "`X` is not in the
        // dialog", which is a claim about a screen that was never on.
        XCTAssertTrue(app.staticTexts["Add a protocol"].waitForExistence(timeout: 6),
                      "The `Add a protocol` dialog did not open. Anything concluded about "
                      + "its contents would be about the wrong screen.")

        // The dialog carries 16 actions on an 874pt display, so it is a SCROLLABLE action
        // sheet and the ones past the fold are not in the tree until they are scrolled
        // to. `waitForExistence` on an entry near the end reports "does not exist" while
        // it is two drags away — the same lazy-list trap that cost this project three
        // attempts at the AX5 TRT capture.
        let entry = app.buttons[name]
        if !entry.waitForExistence(timeout: 3) {
            let sheet = app.sheets.firstMatch.exists
                ? app.sheets.firstMatch
                : (app.scrollViews.allElementsBoundByIndex.first { $0.isHittable } ?? app.windows.firstMatch)
            for _ in 0..<8 where !entry.exists {
                sheet.swipeUp(velocity: XCUIGestureVelocity(rawValue: 220))
            }
        }
        XCTAssertTrue(entry.exists,
                      "`\(name)` is not in the dashboard `Add a protocol` dialog either — "
                      + "and the dialog IS open and was scrolled, so it would be unreachable "
                      + "from anywhere in the app. The dialog offers: "
                      + app.buttons.allElementsBoundByIndex
                          .filter { $0.isHittable }.map(\.label).joined(separator: ", "))
        entry.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 8),
                      "Tapped `\(name)` in the dashboard dialog and did not land on it. "
                      + "Present instead: "
                      + app.navigationBars.allElementsBoundByIndex
                          .map(\.identifier).joined(separator: ", "))
    }

    /// The hero circle over the disclaimer tail — F-F — as a measured intersection,
    /// READ AT REST.
    ///
    /// At rest is not a convenience, it is where the defect lives. Walking the form one
    /// drag at a time on `TRT Dose`, `Reconstitution` and `Steroid Dosage` — nine
    /// positions each, from rest to the scroll end — the hero sits at a FIXED
    /// (172, 762, 58, 58) throughout (it is the overlay, per F-G) while the disclaimer
    /// moves, and the two meet in exactly one place:
    ///
    ///     Reconstitution, UNSCROLLED   disclaimer y 761.67, hero y 762
    ///                                  -> intersect (172, 762, 19.33 x 13.0)
    ///
    /// That 19.33pt is the board's "the last ~19pt of the disclaimer". On `TRT Dose` and
    /// `Steroid Dosage` it never happens: their disclaimer is at y 1031 at rest — off the
    /// bottom of an 874pt display — and scrolling steps it 842 -> 653, straight past the
    /// hero's 762…820 band. So F-F is ONE calculator, not "every calculator": it happens
    /// on Reconstitution because that form's content ends exactly at the hero's y.
    ///
    /// Returns nil when the screen has no disclaimer of this exact wording
    /// (`CyclePlotterScreen` has its own, longer one) or when the two do not intersect.
    /// The calculators whose disclaimer is CURRENTLY CLEAR of the pinned bottom
    /// furniture, and which must stay that way.
    ///
    /// **AN ENUMERATED MUST-HOLD SET, NOT A TRIPWIRE ON THE WON'T-FIX.** It asserts what
    /// is TRUE today rather than what a struck finding once claimed. It is a list rather
    /// than a predicate, so it can only change deliberately: **a screen joining this set
    /// is a decision someone makes in a commit; a screen leaving it is a red.** That is
    /// D7's shape from the other end, and it gives regression protection without
    /// carrying a permanent red for a condition the owner has accepted.
    ///
    /// Measured 2026-08-03. Reconstitution's disclaimer sits at y 641.67 and the pinned
    /// region starts far below it. **Do not add a screen here without a measurement.**
    private static let disclaimerMustClear: Set<String> = ["Reconstitution"]

    /// Where the disclaimer is, relative to EVERYTHING pinned to the bottom.
    ///
    /// ─── WHY THIS REPLACED `measureHeroOverDisclaimer`, 2026-08-03 ──────────────────
    ///
    /// The old probe intersected the disclaimer with **the hero circle and nothing
    /// else** — and F-F is *"the disclaimer is unreadable at rest"*, which
    /// `SCREENSHOT-LOG.md:74` records as being caused by **three** things: *"the `Add`
    /// plate, the hero circle and the tab bar"*.
    ///
    /// **So `overlap=none` never meant "readable". It meant "does not intersect a 58×58
    /// circle".** The two coincided on the six screens where the disclaimer happened to
    /// land on the circle, and nobody noticed *because they agreed* — the same shape as
    /// a citation that sits beside a real source and is never checked, because two
    /// things agreed for a while and only one of them was ever measuring the claim.
    ///
    /// **It came apart on BPC-157**, whose disclaimer sits at y 845.67 — BELOW the
    /// circle, so `overlap=none` — and inside the tab bar. **The string is absent from
    /// `22-calculator-bpc157.png` entirely.** A clean probe result for an invisible
    /// disclaimer. It also produced a real number about the wrong thing: a "clears by
    /// 8pt" margin measured to the circle, on screens whose actual occluder is the
    /// pinned bar starting well above it.
    ///
    /// **THE FRAME IS THE ARBITER.** This probe reports geometry; where geometry and
    /// pixels disagree, the pixels win and the probe is wrong.
    ///
    /// Returns the intersection when the disclaimer is occluded, `nil` when it is clear
    /// or not on screen at all.
    private func measureDisclaimerOcclusion(on name: String)
        -> (name: String, area: CGFloat, rect: CGRect)? {
        let disclaimer = app.staticTexts["Maths only — not medical advice."]
        guard disclaimer.exists else {
            print("DISCLAIMER \(name): not in the tree.")
            return nil
        }

        // Every occluder, not one of them. Each is optional: the result bar is absent on
        // screens that have no result, and a missing element must narrow the region
        // rather than silently pass the whole screen as clear.
        var occluders: [(String, CGRect)] = []
        let plate = app.descendants(matching: .any).matching(identifier: "bar_plate").firstMatch
        if plate.exists { occluders.append(("bar_plate", plate.frame)) }
        let hero = app.images["syringe"]
        if hero.exists { occluders.append(("hero", hero.frame)) }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists { occluders.append(("tabBar", tabBar.frame)) }

        let window = app.windows.firstMatch.frame
        let df = disclaimer.frame
        let onScreen = window.intersects(df)

        guard !occluders.isEmpty else {
            print("DISCLAIMER \(name): NO OCCLUDER RESOLVED — this probe measured nothing. "
                  + "Not a clear result.")
            return nil
        }

        // The pinned region's top edge is the highest thing pinned to the bottom.
        let pinnedTop = occluders.map(\.1.minY).min()!
        let margin = pinnedTop - df.maxY          // >0 clear, <=0 occluded

        var worst: (String, CGRect)? = nil
        for (label, rect) in occluders {
            let i = df.intersection(rect)
            guard !i.isNull, i.width > 0.5, i.height > 0.5 else { continue }
            if worst == nil || i.width * i.height > worst!.1.width * worst!.1.height {
                worst = (label, i)
            }
        }

        // ALWAYS printed, hit or miss, and the MARGIN is printed whenever it MEANS
        // something, so a shrinking number is visible run over run. **There is
        // deliberately no "fails below N points" threshold** — a threshold is a number
        // someone tunes, and the moment it exists a red means "below a figure we picked"
        // rather than "the thing collided". The margin is information; the collision is
        // the assertion.
        //
        // **`n/a` WHEN THE DISCLAIMER IS OFF-SCREEN, not a number.** A disclaimer below
        // the window produces a large negative — `-597pt` on TRT Dose — which reads as
        // "catastrophically occluded" and actually means "far below the fold". It is
        // disambiguated by `onScreen=false` on the same line, and that is not enough: a
        // field that cannot be misread beats a field that is disambiguated elsewhere.
        // Today has been a day about numbers that were correct and about the wrong thing.
        let marginText = onScreen ? String(format: "%.2fpt", margin) : "n/a (below the fold)"
        print(String(format: "DISCLAIMER %@: y=%.2f–%.2f onScreen=%@ pinnedTop=%.2f "
                     + "margin=%@ occluder=%@",
                     name, df.minY, df.maxY, onScreen ? "true" : "false", pinnedTop,
                     marginText, worst.map { "\($0.0) \($0.1)" } ?? "none"))

        guard onScreen, let hit = worst else { return nil }
        return (name, hit.1.width * hit.1.height, hit.1)
    }

    // MARK: - App Review: where account deletion lives

    /// Two frames for `launch/APP-REVIEW-NOTES.md`: the Settings row, and the confirm
    /// sheet it opens.
    ///
    /// **WHY THIS EXISTS AND WHY IT IS SEPARATE FROM THE SWEEP.** App Review rejects apps
    /// whose reviewer cannot find the deletion path (Guideline 5.1.1(v)), so the notes
    /// have to show *where it is*, not merely claim it exists. The sweep deliberately
    /// never visits Settings — it renders the account's real email and avatar — and that
    /// standing decision is not being widened. This is a separate, deliberate act.
    ///
    /// ─── THE EMAIL IS SCROLLED OFF, NOT REDACTED — AND THE ABSENCE IS ASSERTED ──────
    ///
    /// The profile header is the first section of `SettingsScreen`. Rather than draw a
    /// box over it afterwards — which edits the image in order to label it, the same
    /// objection the serial-stamping rule makes — the list is scrolled until the header
    /// is off screen and **the frame is a genuine unmodified photograph.**
    ///
    /// **And the absence is CHECKED before the shutter, not assumed.** A scroll that did
    /// not move is indistinguishable from a scroll that worked, right up until the
    /// account's email is sitting in a file bound for Apple. The email comes from the
    /// environment and **never appears in an assertion message.**
    func testCaptureDeletionPathForAppReview() {
        try? XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE"] == "1",
                           "TEST_RUNNER_CAPTURE=1 not set.")

        // Drawer → the profile row → Settings. The drawer itself shows the email, so it
        // is passed through and never photographed.
        let menu = app.buttons["Menu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "No Menu (hamburger) button.")
        menu.tap()

        let signOut = app.buttons["Sign out"].firstMatch
        XCTAssertTrue(signOut.waitForExistence(timeout: 8), "Drawer did not open.")

        // The drawer's profile row carries the display name and routes to Settings.
        let name = ProcessInfo.processInfo.environment["QA_DISPLAY_NAME"] ?? "devtools"
        let profileRow = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", name)).firstMatch
        XCTAssertTrue(profileRow.waitForExistence(timeout: 8), "No profile row in the drawer.")
        profileRow.tap()

        // ARRIVAL, ASSERTED — same rule as `tab()`.
        let deleteRow = app.descendants(matching: .any)
            .matching(identifier: "cta_delete_account").firstMatch
        XCTAssertTrue(deleteRow.waitForExistence(timeout: 10),
                      "Never arrived on Settings: the Delete account row is not on screen.")

        // Scroll the profile header off — **until the email is actually gone**, not a
        // fixed number of swipes.
        //
        // The first version swiped four times and then asserted. It failed, correctly:
        // the email was still on screen. A fixed count is a guess about how far a list
        // moves, and "swiped four times" is not the property that matters — "the email
        // is not in the tree" is. Loop on the condition, then assert it independently so
        // a loop that gave up cannot pass silently.
        guard let email = ProcessInfo.processInfo.environment["QA_EMAIL"], !email.isEmpty else {
            return XCTFail("QA_EMAIL not forwarded — cannot prove the account email is off "
                           + "screen, so this frame must not be captured.")
        }
        // `minX >= 0` excludes the off-canvas drawer at x = −344, which is a scrollable
        // view in the tree and would otherwise be the thing being swiped.
        let list = (app.collectionViews.allElementsBoundByIndex
                    + app.tables.allElementsBoundByIndex)
            .first(where: { $0.isHittable && $0.frame.minX >= 0 })
        XCTAssertNotNil(list, "No scrollable Settings list.")
        let window = app.windows.firstMatch.frame
        for _ in 0..<12 {
            let emailVisible = app.staticTexts
                .matching(NSPredicate(format: "label == %@", email))
                .allElementsBoundByIndex
                .contains { !window.intersection($0.frame).isNull }
            if !emailVisible && deleteRow.isHittable { break }
            list?.swipeUp(velocity: XCUIGestureVelocity(rawValue: 300))
        }

        // ─── SCROLLING CANNOT HIDE IT, AND THE MEASUREMENT SAYS SO ─────────────────
        //
        // Twelve swipes later the email is still at y≈178 — the top of the list, below
        // the nav bar. **`SettingsScreen` does not scroll far enough at default size to
        // put the profile header off the display while leaving the ACCOUNT section on
        // it.** Both have to be on screen for the frame to be worth anything, and one of
        // them carries the account's email.
        //
        // So the mask happens on the HOST, by cropping, and it is stated in the caption.
        // That is a deliberate reversal of the plan to avoid editing the image: the
        // no-edit rule exists for MEASURED frames in `SCREENSHOT-LOG`, and these are
        // illustrations for a reviewer, not evidence anything is measured off. **A crop
        // that is declared beats a scroll that silently did not happen.**
        //
        // The rect is printed so the host crop can be aimed at a measured number rather
        // than a guess. The EMAIL ITSELF IS NEVER PRINTED.
        for element in app.staticTexts.matching(NSPredicate(format: "label == %@", email))
            .allElementsBoundByIndex {
            print("REVIEW-CAP account-email-rect \(NSCoder.string(for: element.frame)) "
                  + "window \(NSCoder.string(for: window))")
        }
        XCTAssertTrue(deleteRow.isHittable,
                      "The Delete account row is not on screen — the frame would not show "
                      + "a reviewer where the path is.")
        shot("review-01-settings-delete-row-UNCROPPED.png")

        // Step 2 of 2 — the confirm sheet.
        //
        // **IT CARRIES THE EMAIL TOO, AND I ASSUMED IT WOULD NOT.** iOS scales the
        // presenting screen down behind a sheet rather than hiding it, so `SettingsScreen`
        // — profile header and all — is still on the display above the sheet card.
        // Measured: the email lands at `{{111.72, 226.14}, {140.82, 13.19}}`, at
        // fractional coordinates and a slightly smaller size, which is the scaled parent.
        // **Both frames need the crop, not just the first.**
        deleteRow.tap()
        let confirm = app.descendants(matching: .any)
            .matching(identifier: "cta_delete_account_confirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 8),
                      "The delete-account confirm sheet did not present.")
        for element in app.staticTexts.matching(NSPredicate(format: "label == %@", email))
            .allElementsBoundByIndex {
            print("REVIEW-CAP sheet account-email-rect \(NSCoder.string(for: element.frame))")
        }
        shot("review-02-delete-confirm-sheet-UNCROPPED.png")

        // Leave without deleting anything. THE QA ACCOUNT IS NOT TO BE DELETED.
        app.buttons["Cancel"].firstMatch.tap()
    }

    /// Fails if the signed-in account's email is anywhere in the tree.
    ///
    /// **The email is read from the environment and is NEVER interpolated into the
    /// failure message** — a credential must not reach an assertion, an `.xcresult` or a
    /// commit, and a failure message is all three.
    /// ─── `.exists` IS THE WRONG TEST, AND IT FAILED TWICE BEFORE I SAW WHY ──────────
    ///
    /// `app.staticTexts[email].exists` is true for elements that are **in the tree but
    /// not on the display.** The off-canvas drawer lives at **x = −344** and its header
    /// carries the account email — so the first two runs failed this assertion while the
    /// email was nowhere in the frame that would have been captured. Twelve swipes could
    /// never have fixed it: the email was not in the scrolling list.
    ///
    /// **The property that matters is "would it be in the photograph", not "is it in the
    /// tree".** So: intersect the element's frame with the window's.
    ///
    /// The diagnostic prints the RECT and never the email — a failure message is an
    /// assertion, an `.xcresult` and a commit at once.
    private func assertAccountIdentityIsOffScreen(file: StaticString = #filePath,
                                                  line: UInt = #line) {
        guard let email = ProcessInfo.processInfo.environment["QA_EMAIL"], !email.isEmpty else {
            return XCTFail("QA_EMAIL not forwarded — cannot prove the account email is off "
                           + "screen, so this frame must not be captured.", file: file, line: line)
        }
        let window = app.windows.firstMatch.frame
        for element in app.staticTexts.matching(NSPredicate(format: "label == %@", email))
            .allElementsBoundByIndex {
            let f = element.frame
            let visible = window.intersection(f)
            XCTAssertTrue(visible.isNull || visible.width < 1 || visible.height < 1,
                          "The account email is VISIBLE in this frame at "
                          + "\(NSCoder.string(for: f)) (window \(NSCoder.string(for: window))). "
                          + "This frame is bound for Apple and must not carry it.",
                          file: file, line: line)
        }
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
