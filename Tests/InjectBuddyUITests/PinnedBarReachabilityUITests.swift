import XCTest

/// D5, made into something that can go red.
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

    // MARK: - BATCH.md item 2 — the measurement, and NOTHING else

    /// **PURE OBSERVATION. It asserts only that it observed something.**
    ///
    /// `BATCH.md` item 2 is a question, not a fix: two existing measurements do not
    /// reconcile. The capture harness walked `trt` to its scroll end and the last
    /// element stopped at **y 653 against a plate top of 671** — content clearing the
    /// plate — while `control_syringeMl_0.5 mL (50u)` measures **642.7–686.7**, which
    /// crosses it. Both cannot be true at the same scroll position, so one of them is a
    /// measurement of a different scroll position than it claims.
    ///
    /// THE QUESTION, and the only thing this prints an answer to: **at FULL SCROLL, are
    /// `1 mL (100u)` and `3 mL (IM)` fully clear of the plate and tappable?**
    ///   • YES → the user reaches every barrel by scrolling. D5 violation, real defect,
    ///     NOT criterion 1.
    ///   • NO  → a barrel cannot be selected at all on the two most-used calculators.
    ///     Criterion 1, and it blocks.
    ///
    /// **THE TAP IS GUARDED, and the guard is not politeness.** `cta_add` lives ON the
    /// plate. Tapping a barrel whose frame is under the plate does not tap the barrel —
    /// it taps whatever the plate is drawing at those coordinates, which on every
    /// calculator is the save control, and this run would then write a protocol it never
    /// meant to and report it as a barrel measurement. So a control that is not already
    /// wholly clear of the plate is recorded as NOT REACHED and is never tapped: in that
    /// case the answer is already NO and the tap would add nothing but a side effect.
    ///
    /// Tappability is asserted as its CONSEQUENCE (P3) — the `.isSelected` trait
    /// `SegmentedRow` adds to the on option — never as "the tap call returned".
    func testItem2_barrelRowsAtFullScroll_TRT() throws {
        try openCalculator("TRT Dose")
        measureBarrels(screen: "TRT Dose")
    }

    func testItem2_barrelRowsAtFullScroll_Steroid() throws {
        try openCalculator("Steroid Dosage")
        measureBarrels(screen: "Steroid Dosage")
    }

    private func measureBarrels(screen: String) {
        let plate = app.descendants(matching: .any).matching(identifier: "bar_plate").firstMatch
        XCTAssertTrue(plate.waitForExistence(timeout: 8), "No bar_plate on \(screen).")
        let plateTop = plate.frame.minY
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        let window = app.windows.firstMatch.frame

        func barrels() -> [XCUIElement] {
            app.buttons.allElementsBoundByIndex
                .filter { $0.identifier.hasPrefix("control_syringeMl_") && $0.frame.minX >= 0 }
        }

        func snapshot(_ tag: String) {
            let rows = barrels()
            print("ITEM2 \(screen) [\(tag)] window=\(window) navBottom=\(navBottom) "
                  + "plateTop=\(plateTop) plateFrame=\(plate.frame) barrels=\(rows.count)")
            for b in rows {
                let f = b.frame
                let clear = f.maxY <= plateTop && f.minY >= navBottom
                print("ITEM2 \(screen) [\(tag)] id=\(b.identifier) "
                      + "y=\(f.minY)…\(f.maxY) x=\(f.minX)…\(f.maxX) h=\(f.height) "
                      + "hittable=\(b.isHittable) selected=\(b.isSelected) "
                      + "clearOfPlate=\(clear) straddles=\(f.minY < plateTop && f.maxY > plateTop)")
            }
        }

        snapshot("at-rest")

        // WALK TO THE SCROLL END, and stop when it stops moving rather than after a
        // fixed count — a fixed count is how "full scroll" ends up meaning "eight
        // swipes", which is the discrepancy this test exists to resolve.
        var swipes = 0
        if let form = app.scrollViews.allElementsBoundByIndex
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) {
            var previous = ""
            for i in 0..<20 {
                form.swipeUp(velocity: XCUIGestureVelocity(rawValue: 260))
                swipes = i + 1
                let signature = barrels()
                    .map { "\($0.identifier)@\($0.frame.minY)" }
                    .joined(separator: ",")
                if !signature.isEmpty && signature == previous {
                    print("ITEM2 \(screen): scroll end reached after \(swipes) swipes.")
                    break
                }
                previous = signature
            }
        } else {
            print("ITEM2 \(screen): NO SCROLL CONTAINER — nothing to walk.")
        }

        snapshot("full-scroll")

        // THE ANSWER, per row, with the tap guarded as described above.
        for label in ["1 mL (100u)", "3 mL (IM)"] {
            let id = "control_syringeMl_\(label)"
            let matches = app.buttons.matching(identifier: id).allElementsBoundByIndex
                .filter { $0.frame.minX >= 0 }
            guard matches.count == 1, let row = matches.first else {
                print("ITEM2 \(screen) VERDICT \(label): UNRESOLVED — \(matches.count) elements.")
                continue
            }
            let f = row.frame
            let clear = f.maxY <= plateTop && f.minY >= navBottom
            guard clear && row.isHittable else {
                print("ITEM2 \(screen) VERDICT \(label): **NO** — at full scroll it is "
                      + "y \(f.minY)…\(f.maxY) against plateTop \(plateTop) / navBottom "
                      + "\(navBottom); clearOfPlate=\(clear) hittable=\(row.isHittable). "
                      + "NOT TAPPED — `cta_add` is at those coordinates.")
                continue
            }
            row.tap()
            let took = row.isSelected
            print("ITEM2 \(screen) VERDICT \(label): **YES** — y \(f.minY)…\(f.maxY) "
                  + "clear of plateTop \(plateTop); tapped, selected=\(took).")
        }

        // The only assertion: this run looked at something. A measurement that
        // resolved zero barrels must not read as a clean sheet.
        XCTAssertFalse(barrels().isEmpty,
                       "\(screen): no `control_syringeMl_*` resolved at all — this "
                       + "measurement observed nothing and must not be read as an answer.")
    }

    // MARK: - BATCH.md batch 3 item 2 — the shear measurement, and NOTHING else

    /// **PURE OBSERVATION.** `BATCH.md` batch 3 item 2 says MEASURE FIRST, and this is
    /// that measurement: at rest, at default text size, `bar_plate`'s top edge against
    /// the frame of `result_Draw` — the emphasised dose VOLUME on the GLP-1 card.
    ///
    /// THE SAMPLE IS THREE CALCULATORS, NOT ONE (P5). `semaglutide`, `tirzepatide` and
    /// `retatrutide` share one field set (conc / dose — both numeric with a ruler since
    /// T-45, previously closed menu pickers — plus the syringe barrel) and
    /// one result shape (`Draw`, `Units (U-100)`, `Volume`), so they land at the same
    /// offset and a finding read off only the one it was first noticed on would be a
    /// finding about a screen rather than about the control underneath all three.
    ///
    /// It asserts only that it RESOLVED the two elements. Whether they intersect is
    /// printed, not asserted — turning it into an assertion here would make the run red
    /// before anyone had decided what the number means, which is the wrong order.
    ///
    /// The barrel rows are printed alongside, because the hypothesis under test is that
    /// `SegmentedRow` is in its COLUMN branch at default size: four rows one below the
    /// next at `Theme.minTarget` + `Spacing.xs` apart. Four distinct `minY` values is the
    /// column; one shared `minY` is the row. That is the difference between a screen
    /// that is 116pt too tall and one that is not, read off the renderer.
    func testItem2_shearAtRest_Retatrutide() throws {
        try openCalculator("Retatrutide")
        measureShear(screen: "Retatrutide")
    }

    func testItem2_shearAtRest_Semaglutide() throws {
        try openCalculator("Semaglutide")
        measureShear(screen: "Semaglutide")
    }

    func testItem2_shearAtRest_Tirzepatide() throws {
        try openCalculator("Tirzepatide")
        measureShear(screen: "Tirzepatide")
    }

    private func measureShear(screen: String) {
        // The rig, from the app's own probe. A frame filed under "default text size"
        // by a harness that cannot observe the text size is the §5.24 shape.
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 8), "No bar_gate on \(screen).")
        print("SHEAR \(screen) RIG \(gate.label)")

        let plates = app.descendants(matching: .any)
            .matching(identifier: "bar_plate").allElementsBoundByIndex
        guard plates.count == 1, let plate = plates.first else {
            return XCTFail("\(screen): `bar_plate` resolved \(plates.count) elements.")
        }
        let plateFrame = plate.frame
        let plateTop = plateFrame.minY
        let window = app.windows.firstMatch.frame
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        print("SHEAR \(screen) window=\(window) navBottom=\(navBottom) "
              + "plateFrame=\(plateFrame) plateTop=\(plateTop)")

        // Every result row, so the reader can see WHERE the card sits, not just whether
        // one string of it is under the plate. `Draw` is the one the finding is about.
        for label in ["Draw", "Units (U-100)", "Volume"] {
            let id = "result_\(label)"
            let matches = app.descendants(matching: .any).matching(identifier: id)
                .allElementsBoundByIndex.filter { $0.frame.minX >= 0 }
            guard matches.count == 1, let row = matches.first else {
                print("SHEAR \(screen) \(id): UNRESOLVED — \(matches.count) elements.")
                continue
            }
            let f = row.frame
            let straddles = f.minY < plateTop && f.maxY > plateTop
            let whollyUnder = f.minY >= plateTop
            let onScreen = window.contains(f)
            print("SHEAR \(screen) \(id) y=\(f.minY)…\(f.maxY) h=\(f.height) "
                  + "value=\"\(row.label)\" intersectsPlate=\(f.intersects(plateFrame)) "
                  + "straddlesPlateTop=\(straddles) whollyUnderPlate=\(whollyUnder) "
                  + "overlap=\(max(0, f.maxY - plateTop)) inWindow=\(onScreen)")
        }

        // The 116pt hypothesis: is `SegmentedRow` in its column branch?
        let barrels = app.buttons.allElementsBoundByIndex
            .filter { $0.identifier.hasPrefix("control_syringeMl_") && $0.frame.minX >= 0 }
        let tops = Set(barrels.map { $0.frame.minY })
        print("SHEAR \(screen) BARREL branch=\(tops.count == 1 ? "ROW" : "COLUMN") "
              + "count=\(barrels.count) distinctTops=\(tops.count)")
        for b in barrels {
            let f = b.frame
            print("SHEAR \(screen) BARREL id=\(b.identifier) y=\(f.minY)…\(f.maxY) "
                  + "x=\(f.minX)…\(f.maxX) w=\(f.width) h=\(f.height) "
                  + "hittable=\(b.isHittable) selected=\(b.isSelected)")
        }
        if let lo = barrels.map({ $0.frame.minY }).min(),
           let hi = barrels.map({ $0.frame.maxY }).max() {
            print("SHEAR \(screen) BARREL blockHeight=\(hi - lo)")
        }

        // D5, the other half, re-read on these three screens: at rest, which barrels are
        // clear of the plate and hittable? Printed so step 3 has a before to compare to.
        for b in barrels {
            let f = b.frame
            print("SHEAR \(screen) D5 id=\(b.identifier) "
                  + "clearOfPlate=\(f.maxY <= plateTop && f.minY >= navBottom) "
                  + "hittable=\(b.isHittable)")
        }

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "\(screen)-at-rest"
        shot.lifetime = .keepAlways
        add(shot)

        // AND THE ROW ITSELF, because the frames above say where the pills are and not
        // whether the labels inside them survived. `blockHeight` alone cannot tell a row
        // of four wrapped-but-whole pairs from a row of four clipped ones, and the whole
        // point of this control is that `0.3 mL (…` must never happen. Taken LAST, after
        // every at-rest number is recorded, so the scroll cannot redefine "at rest".
        if let last = barrels.last, !last.frame.isEmpty {
            // Enough of it to READ, not necessarily all of it: at AX5 a pill is 232pt
            // tall and the band between the header and the plate is 390pt, so insisting
            // on wholly-visible is a condition this loop can fail for reasons that have
            // nothing to do with the labels it is here to photograph.
            // A COORDINATE DRAG, not `scrollViews.first { isHittable }`. At AX5 that
            // query answered with something that did not move: three runs produced
            // byte-identical frames before and after fourteen swipes, which is a scroll
            // that reports success and does nothing. Dragging inside the band between
            // the header and the plate cannot address the wrong element.
            let midBand = (navBottom + plateTop) / 2 / window.height
            for _ in 0..<14 {
                let f = last.frame
                if f.minY >= navBottom && f.minY < plateTop - 40 { break }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: midBand))
                    .press(forDuration: 0.05,
                           thenDragTo: app.coordinate(
                            withNormalizedOffset: CGVector(dx: 0.5, dy: navBottom / window.height + 0.02)))
            }
            let rowShot = XCTAttachment(screenshot: app.screenshot())
            rowShot.name = "\(screen)-barrel-row"
            rowShot.lifetime = .keepAlways
            add(rowShot)
            let after = app.buttons.allElementsBoundByIndex
                .filter { $0.identifier.hasPrefix("control_syringeMl_") && $0.frame.minX >= 0 }
            for b in after {
                print("SHEAR \(screen) BARREL-SCROLLED id=\(b.identifier) frame=\(b.frame)")
            }
        }

        XCTAssertFalse(barrels.isEmpty,
                       "\(screen): no `control_syringeMl_*` resolved — this measurement "
                       + "observed nothing and must not be read as an answer.")
    }

    // MARK: - The invariant

    private func assertReachable(screen: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let plate = app.descendants(matching: .any).matching(identifier: "bar_plate").firstMatch
        XCTAssertTrue(plate.waitForExistence(timeout: 5),
                      "No bar_plate on \(screen) — cannot locate the plate's top edge.",
                      file: file, line: line)
        let plateTop = plate.frame.minY
        // Printed BEFORE anything is asserted, because `continueAfterFailure` is false
        // and the trailing `REACH` line never prints on a failing run — so the one
        // number every straddle verdict is measured against was invisible in exactly
        // the runs where you need it. It is also how the `bar_plate` probe's move from
        // `.overlay` to `.background` was shown not to move the plate: 564.6666666666666
        // on all three screens, before and after.
        print("PLATE \(screen): top=\(plateTop) frame=\(plate.frame)")

        // 1. THE COMMITTING ACTION. `Add` writes a protocol, so "mostly visible" is
        //    not a category — it is either wholly on screen or the screen is offering
        //    a write the user cannot see the whole of.
        //
        //    ADDRESSED BY IDENTIFIER, NOT BY LABEL. This used to read
        //    `buttons.matching(identifier: "Add").first { $0.isHittable }` with
        //    `?? buttons["Add"]` behind it, and THE BOTTOM TAB BAR HAS AN `Add` SLOT
        //    with the same label. Two elements answered; the fallback answered with
        //    the tab item, which is always enabled and always hittable. So on any
        //    screen where the real CTA was NOT hittable — the finding this suite
        //    exists to catch — the assertion would have measured the tab bar and gone
        //    green. §5.36: a check must be able to observe the condition its output
        //    asserts. Counted, never `firstMatch`ed, so a duplicate is a named failure.
        let ctas = app.buttons.matching(identifier: "cta_add").allElementsBoundByIndex
        guard ctas.count == 1 else {
            XCTFail("\(screen): `cta_add` should address exactly one button, found "
                    + "\(ctas.count): "
                    + ctas.map { "enabled=\($0.isEnabled) frame=\($0.frame)" }
                        .joined(separator: " | "),
                    file: file, line: line)
            return
        }
        let add = ctas[0]
        XCTAssertTrue(add.exists, "No Add button on \(screen).", file: file, line: line)
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(add.frame),
                      "\(screen): Add is not wholly on screen — \(add.frame) in \(window).",
                      file: file, line: line)
        XCTAssertTrue(add.isHittable,
                      "\(screen): Add is on screen but not hittable — something is over it.",
                      file: file, line: line)

        // NOTE FOR THE WIDENING (G2). All three screens this suite currently opens can
        // save a protocol, so `Add` is enabled on every one of them and `isHittable` is
        // the right question. `BMI` and `Free T Index` CANNOT save, and their CTA is now
        // deliberately disabled — a disabled control is not hittable, so widening this
        // suite to all fourteen without splitting the invariant will fail those two for
        // a reason that is the FIX rather than the defect. The invariant on a
        // non-saving calculator is "the committing action is wholly on screen and
        // NOT ENABLED"; on a saving one it is "wholly on screen and hittable". Split it
        // there, do not relax it here.

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
        var covered: Set<String> = []
        for control in inputControls() {
            guard control.exists else { continue }
            let f = control.frame
            guard f.height > 0 else { continue }
            measured.append(control.identifier)
            let straddles = f.minY < plateTop && f.maxY > plateTop

            // NAMED EXPECTED FAILURE, not a narrowed condition.
            //
            // The first cut of this simply stopped asserting the straddle rule at
            // accessibility sizes, because one screen — Steroid Dosage — shears
            // `field_mgWeek` at AX5 with the bar already at its floor, and a
            // permanently-red test is one people learn to ignore. That bought silence
            // on ONE known screen and paid for it with the assertion on EVERY screen at
            // AX5: including the ten not yet surveyed, at the size every finding this
            // week came out of, on the half of D5 that says the input must be
            // reachable too. It was a size gate on the assertion — the exact thing this
            // task rejected as a gate on the bar, and wrong for the same reason. A size
            // is a guess at where the problem lives.
            //
            // So the debt is NAMED, and asserted FROM BOTH ENDS: a listed case must
            // still fail, and if it starts passing the run goes red and says to delete
            // the entry. A narrowed check stays narrow forever and nobody remembers
            // why; a listed one has to shrink. A filed finding plus a green suite still
            // reads as green — the list puts the debt where people actually look.
            if let known = Self.expectedShear(screen: screen,
                                              control: control.identifier,
                                              isAccessibilitySize: isAccessibilitySize) {
                covered.insert(known.key)
                XCTAssertTrue(straddles,
                              "\(screen): `\(control.identifier)` NO LONGER shears — it is a known "
                              + "failure (\(known.finding)) and it is now clean. Delete its entry "
                              + "from `expectedShears`; a list that outlives its debt is a "
                              + "narrowed assertion with extra steps.",
                              file: file, line: line)
            } else {
                XCTAssertFalse(straddles,
                               "\(screen): `\(control.identifier)` is sheared by the result bar — "
                               + "control spans y \(f.minY)…\(f.maxY), plate top is \(plateTop). "
                               + "The user sees part of an input they are committing.",
                               file: file, line: line)
            }
        }

        // An entry naming a control that is not on screen suppresses nothing and hides
        // that it suppresses nothing.
        for known in Self.expectedShears
        where known.screen == screen && known.isAccessibilitySize == isAccessibilitySize {
            XCTAssertTrue(covered.contains(known.key),
                          "\(screen): `expectedShears` names `\(known.control)` and nothing on "
                          + "screen answers to that identifier. The entry is stale.",
                          file: file, line: line)
        }

        // PASS 2 — REACHABILITY, at every size, and this is the half with teeth. D5:
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

    // MARK: - Known failures, named rather than narrowed around

    /// One straddle this suite is currently expected to find, with the finding it
    /// belongs to. Every entry is a debt: it must still fail, and the moment it stops
    /// failing the run says so.
    struct ExpectedShear {
        let screen: String
        let control: String
        /// Which size the shear happens at. `Steroid Dosage` is clean at default and
        /// shears at AX5, so the entry has to name the size or it would suppress a
        /// default-size regression it knows nothing about.
        let isAccessibilitySize: Bool
        let finding: String
        var key: String { "\(screen)|\(control)|\(isAccessibilitySize)" }
    }

    /// FILED 2026-08-03, NOT ACTED ON — the one entry below is STALE, and this suite
    /// says so itself: at AX5 it now fails with "`field_mgWeek` NO LONGER shears …
    /// delete its entry". Left in place deliberately. It is the marker for a BOARD §1
    /// finding, and closing a board finding is the owner's, not a passing task's.
    ///
    /// ATTRIBUTED, so the next person does not have to guess and does not credit it to
    /// the wrong change. It is NOT a consequence of the `SegmentedRow` fit-test fix:
    /// the same AX5 run was taken against `415e6dd`'s `CalculatorScreen.swift` — the
    /// file as it stood BEFORE that fix — and failed identically. So the shear was
    /// already gone, and the likeliest cause is `69a674a` standing the pinned result
    /// card down, which is the change that gave this screen its vertical space back.
    /// Both runs: iPhone 16 Pro / iOS 18.3.1, `content_size` AX5, signed in.
    ///
    /// FOUND BY THIS SUITE, on its first run at AX5. The bar is at its floor there —
    /// the result card is stood down entirely and what is left is the committing action
    /// D5 requires — so no pinning gate can lift that edge. The fix belongs to the
    /// screen's layout, which is why it is a debt and not a bug in the bar.
    static let expectedShears: [ExpectedShear] = [
        .init(screen: "Steroid Dosage",
              control: "field_mgWeek",
              isAccessibilitySize: true,
              finding: "BOARD §1 — Steroid Dosage shears field_mgWeek at AX5"),
    ]

    static func expectedShear(screen: String,
                              control: String,
                              isAccessibilitySize: Bool) -> ExpectedShear? {
        expectedShears.first {
            $0.screen == screen && $0.control == control
                && $0.isAccessibilitySize == isAccessibilitySize
        }
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
