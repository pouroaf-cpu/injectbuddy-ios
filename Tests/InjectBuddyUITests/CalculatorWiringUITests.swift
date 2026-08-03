import XCTest

/// Proves the DISPLAYED number is the number the engine used.
///
/// The unit suite covers `CalculatorEngine` and `DoseProjection` — 27 tests, green
/// throughout — and it stayed green through a bug where a quick-value chip set the
/// binding but the field's local text did not follow: the field read **100** while
/// the engine computed **300 mg/week**. That is the wiring between a control and the
/// engine, not the maths, and nothing tested it until this file.
///
/// Every assertion here therefore reads the FIELD and the RESULT together. A test
/// that only checks the field cannot catch this class of bug, which is exactly how
/// it survived.
final class CalculatorWiringUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        // The erased device sits in iOS first-boot with permission prompts. This
        // lives in setUp rather than in one test, or the second test meets a prompt
        // nobody is handling.
        addUIInterruptionMonitor(withDescription: "system prompts") { alert in
            for label in ["Allow While Using App", "Don’t Allow", "Don't Allow", "Continue", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app = XCUIApplication()

        // Credentials are injected from the environment and NEVER committed. A
        // machine without them SKIPS — it must not fail. A red test for a missing
        // secret trains people to ignore red tests, and then a real desync goes by
        // unnoticed; that costs more than these tests are worth.
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "QA_EMAIL / QA_PASSWORD not set — skipping signed-in UI tests.")

        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()

        dismissDisclaimerIfPresent()
        signInIfNeeded(email: email, password: password)
    }

    // MARK: - Entry

    private func dismissDisclaimerIfPresent() {
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
    }

    /// Signs in only when the app is actually signed out.
    ///
    /// The session lives in the **Keychain**, not the app container — established by
    /// finding that `simctl uninstall` did not sign out and `simctl erase` did. So it
    /// survives relaunch, one sign-in covers the whole run, and repeated sign-ins
    /// against real Supabase auth would eventually rate-limit into a suite that gets
    /// slower and then fails on lockout.
    ///
    /// Nothing here logs the credential. Assertions are on the OUTCOME — did we reach
    /// the app — because an xcresult bundle is a place a password leaks by accident.
    private func signInIfNeeded(email: String, password: String) {
        if app.buttons["Dashboard"].waitForExistence(timeout: 6) { return }

        let signIn = app.buttons["Sign in"]
        if signIn.waitForExistence(timeout: 5) { signIn.tap() }

        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 8) else {
            XCTFail("Signed out, but no email field appeared.")
            return
        }
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields.firstMatch
        guard passwordField.waitForExistence(timeout: 5) else {
            XCTFail("No password field.")
            return
        }
        passwordField.tap()
        passwordField.typeText(password)

        app.buttons["Sign in"].firstMatch.tap()

        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 25),
                      "Sign-in did not reach the app.")
    }

    /// Any calculator by row label, asserting arrival on the NAVIGATION BAR TITLE.
    ///
    /// `openTRTCalculator` taps the first hittable row and concludes nothing about
    /// where it landed. That is survivable while every test in this file is about one
    /// screen's fields; it is not survivable for a test whose whole subject is WHICH
    /// calculator is on screen. Measuring the wrong screen is quieter than
    /// photographing one — the run goes green about a screen nobody asked about, which
    /// is how a capture of the Tools list once shipped under a calculator's filename.
    /// The title is the screen's own identity and every route publishes it.
    private func openCalculator(named name: String) {
        // Pop back to the Tools ROOT first. Tapping the tab while pushed onto a
        // calculator does not necessarily unwind it, and the second screen in a loop
        // would then be looked for on the first screen.
        let back = app.navigationBars.buttons.matching(identifier: "Tools").firstMatch
        if back.exists && back.isHittable { back.tap() }

        // The LOWEST hittable `Tools` — the tab item. The Tools list itself carries a
        // row with the same label once the drawer is in the tree.
        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()

        // Return the list to the top, or the row found on the previous iteration's
        // scroll position decides what this one can reach.
        if let list = (app.collectionViews.allElementsBoundByIndex
                       + app.tables.allElementsBoundByIndex
                       + app.scrollViews.allElementsBoundByIndex)
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) {
            for _ in 0..<8 { list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 500)) }
        }

        // Do NOT wait for existence first: the list is lazy, so a row two swipes away
        // reports "does not exist" while being perfectly reachable. Re-query in the
        // loop and treat absent and present-but-off-screen as the same condition.
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
        guard let hit = row else {
            return XCTFail("\(name) never became hittable after 12 scrolls.")
        }
        hit.tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 8),
                      "Tapped `\(name)` and did not land on it — no navigation bar titled "
                      + "`\(name)`. Present instead: "
                      + app.navigationBars.allElementsBoundByIndex
                          .map(\.identifier).joined(separator: ", "))
    }

    private func openTRTCalculator() {
        app.buttons["Tools"].tap()

        // Take the HITTABLE match, not the first. The off-canvas drawer carries a
        // row with the same label; before the accessibility fix it resolved at
        // x = -290 and the tap failed with kAXErrorCannotComplete. Asking for the
        // hittable one is also just the honest query — "the row the user can see".
        let candidates = app.staticTexts.matching(identifier: "TRT Dose")
        XCTAssertTrue(candidates.firstMatch.waitForExistence(timeout: 8),
                      "Tools did not list TRT Dose.")
        let visible = candidates.allElementsBoundByIndex.first { $0.isHittable }
        guard let trt = visible else {
            XCTFail("TRT Dose exists but nothing hittable — is it off-canvas?")
            return
        }
        trt.tap()
    }

    // MARK: - Addressing

    /// Resolves an identifier and PROVES it is unique first.
    ///
    /// `result_Weekly total` used to match two elements — the pinned bar and the
    /// copy inside the scroll — and an ambiguous `XCUIElement` fails when it is
    /// resolved, before any assertion runs. That is why these tests once died
    /// without printing their own messages, and why "it failed" was read as "the
    /// element is missing". Counting first turns that into a named failure.
    /// `type` defaults to `.any`, which is the honest query: one identifier, one
    /// element, whatever kind it is. It is narrowed in exactly one place —
    /// `kb_done` — because a keyboard `ToolbarItemGroup` bridges its items to UIKit
    /// and publishes the identifier on both the bridged bar button and the hosted
    /// SwiftUI label. That duplication is not removable from the app side; it was
    /// measured, and the narrowing is recorded here rather than applied quietly
    /// everywhere. Narrowing this by habit is how `firstMatch` hid a stepper bug for
    /// a session.
    @discardableResult
    private func unique(_ identifier: String,
                        type: XCUIElement.ElementType = .any,
                        file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let matches = app.descendants(matching: type).matching(identifier: identifier)
        if matches.count != 1 {
            // Name the duplicates. "found 2" sends you back to the simulator; this
            // says which two, which is usually enough to see the cause.
            let detail = matches.allElementsBoundByIndex
                .map { "type=\($0.elementType.rawValue) label=\"\($0.label)\" frame=\($0.frame)" }
                .joined(separator: " | ")
            XCTFail("\(identifier) should address exactly one element, found \(matches.count): \(detail)",
                    file: file, line: line)
        }
        return matches.element(boundBy: 0)
    }

    /// "300.0 mg" -> 300.0. Fails loudly rather than returning nil, because a row
    /// that has lost its number is the thing under test.
    private func number(in element: XCUIElement,
                        file: StaticString = #filePath, line: UInt = #line) -> Double? {
        let digits = element.label.components(separatedBy: " ").first ?? ""
        let value = Double(digits)
        XCTAssertNotNil(value, "Could not read a number out of \"\(element.label)\".",
                        file: file, line: line)
        return value
    }

    // MARK: - The gate

    /// PROVES: a quick-value chip moves the field, the engine and the result row
    /// together, and `result_Weekly total` addresses exactly one element while it
    /// does so.
    func testQuickChip_fieldAndResultBothFollow() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Weekly dose field not found.")

        app.buttons["quick_mgWeek_300"].tap()

        XCTAssertEqual(field.value as? String, "300",
                       "The FIELD did not follow the chip — this is the 100-vs-300 bug.")

        // And the UNIT, not just the number. "0.250" and "0.250 mL" are different
        // claims, and losing the unit at AX5 was the worst finding of the audit — a
        // test asserting a naked number would not have caught it.
        let weeklyTotal = unique("result_Weekly total")
        XCTAssertTrue(weeklyTotal.waitForExistence(timeout: 5), "No weekly total row.")
        XCTAssertEqual(weeklyTotal.label, "300.0 mg",
                       "The RESULT disagrees with the field, or has lost its unit.")
    }

    /// PROVES: the ± pair belonging to `mgWeek` moves `mgWeek` by its configured
    /// step of 10 — not that *some* stepper on the screen moved *something*.
    /// `buttons["Increase"].firstMatch` resolved to vial strength's stepper, so the
    /// old version incremented one field and asserted on another.
    func testStep_movesByTen() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        app.buttons["quick_mgWeek_300"].tap()
        XCTAssertEqual(field.value as? String, "300")

        // The other field must not move. Without this the test still passes if the
        // identifiers are ever wired to the wrong pair.
        let strength = app.textFields["field_strength"]
        let strengthBefore = strength.value as? String

        unique("step_up_mgWeek").tap()
        XCTAssertEqual(field.value as? String, "310", "Step moved by the wrong amount.")

        unique("step_down_mgWeek").tap()
        XCTAssertEqual(field.value as? String, "300")

        XCTAssertEqual(strength.value as? String, strengthBefore,
                       "Stepping the weekly dose changed the vial strength.")
    }

    /// PROVES: with the keypad up, the quick values are REACHABLE and the field
    /// follows them.
    ///
    /// Both halves were broken. `typeText` appended to the existing value because
    /// focusing a populated field did not select it, and the chip the test reached
    /// for was underneath the pinned result bar — where `tap()` reported success and
    /// moved nothing. A tap that passes is not evidence of an interaction; only a
    /// state change is. The chip now comes from the keyboard toolbar, which is the
    /// one a user can actually reach while typing.
    func testTypeThenChip_neverDesyncs() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))

        field.tap()
        field.typeText("250")
        XCTAssertEqual(field.value as? String, "250",
                       "Typing appended to the existing value instead of replacing it.")

        let chip = unique("kb_quick_mgWeek_400")
        XCTAssertTrue(chip.isHittable,
                      "The keyboard toolbar's quick values are not reachable with the keypad up.")
        chip.tap()

        XCTAssertEqual(field.value as? String, "400",
                       "Chip after typing did not update the field.")

        // Dismiss the keypad before reading the pinned bar: with the keyboard up
        // that bar is deliberately collapsed to the primary row (finding F11), so
        // the weekly-total cross-check is not on it. Tapping Done is also the only
        // way out of a decimal pad, so this exercises that too.
        unique("kb_done", type: .button).tap()

        let weeklyTotal = unique("result_Weekly total")
        XCTAssertEqual(weeklyTotal.label, "400.0 mg",
                       "Result disagrees with the field after chip-following-type.")
    }

    /// PROVES: the calculator's `Add` is gated on `canSaveProtocol` — dead on the
    /// calculators that cannot produce a protocol, live on the ones that can.
    ///
    /// THE DEFECT THIS IS AIMED AT is a WRITE, not a layout: on `BMI` the button
    /// wrote a `saved_dosages` row from a height and a weight and advanced to a screen
    /// reading "ADDED TO YOUR PROTOCOLS", asking the user to confirm the day the
    /// protocol begins "so the calendar and dose reminders line up". Driven, and the
    /// row deleted afterwards. `canSaveProtocol` already existed and `AddScreen`
    /// already honoured it; the missing code was on this screen.
    ///
    /// SHOWN RED BEFORE IT WAS TRUSTED (§5.24): run against the commit before the
    /// gate, this reports `BMI`, `Free T Index` — the two calculators whose CTA was
    /// enabled — and passes on the third leg. The red half and the green half were
    /// watched in the same run, which is the only version of this that is evidence.
    ///
    /// BOTH ENDS (§5.30), and the second end is the whole reason this is not a
    /// one-liner. A gate on a CTA is exactly the change that quietly disables a button
    /// somewhere it should still work, and a test that only asserts "dead on BMI"
    /// passes just as happily with the CTA dead on all fifteen.
    ///
    /// FAILURES ARE COLLECTED, not thrown at the first screen. `continueAfterFailure`
    /// is false in this suite, so asserting inline would stop at `BMI` and say nothing
    /// about `Free T Index` — the same "a loop that fails on the third calculator stops
    /// measuring the rest" problem that decided D5's shape. The point is to learn the
    /// state of every screen in ONE run.
    func testAddCTA_isGatedOnCanSaveProtocol() {
        var wrong: [String] = []

        // The three slugs with `canSaveProtocol == false` are bmi, freeTestIndex and
        // cyclePlotter. `Cycle Plotter` is EXCLUDED WITH ITS REASON RATHER THAN
        // SILENTLY: it is not a `CalculatorScreen` at all — it routes to
        // `CyclePlotterScreen`, which renders no `cta_add` — and it is also absent from
        // the Tools list entirely (BOARD §1), so this helper could not reach it anyway.
        for name in ["BMI", "Free T Index"] {
            openCalculator(named: name)
            let cta = unique("cta_add")
            guard cta.exists else {
                wrong.append("\(name): no cta_add at all")
                continue
            }
            if cta.isEnabled {
                wrong.append("\(name): Add is ENABLED on a calculator that cannot save "
                             + "a protocol — pressing it writes a saved_dosages row "
                             + "(frame \(cta.frame))")
            }
        }

        // THE OTHER END. TRT can save, so its CTA must be live — with a valid result
        // under it, which is why the chip is tapped first: `isEnabled` is
        // `canSaveProtocol && result.isValid && isOnline`, and asserting on a screen
        // whose defaults might not produce a result would go red for a reason that has
        // nothing to do with the gate.
        openCalculator(named: "TRT Dose")
        app.buttons["quick_mgWeek_300"].tap()
        XCTAssertEqual(app.textFields["field_mgWeek"].value as? String, "300",
                       "Precondition failed: the chip did not set the field, so what "
                       + "follows would be measuring the wrong state (§5.35).")
        let trtCTA = unique("cta_add")
        if !trtCTA.isEnabled {
            wrong.append("TRT Dose: Add is DISABLED on a calculator that CAN save. "
                         + "The gate has been applied too widely.")
        }

        XCTAssertTrue(wrong.isEmpty,
                      "The Add CTA does not honour `canSaveProtocol`:\n  "
                      + wrong.joined(separator: "\n  "))
    }

    /// PROVES THE INVARIANT: the field never displays a number the engine did not
    /// use. Asserted as an agreement between what is on screen and what was
    /// computed — not against the literal "1000", which would pin the symptom and
    /// go stale the moment a spec range changes.
    ///
    /// Reached by typing past `mgWeek`'s ceiling of 1000. Before the fix the field
    /// read 100250 while the result bar showed a 2.500 mL draw computed from 1000.
    func testOverRange_fieldNeverShowsANumberTheEngineRejected() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))

        field.tap()
        field.typeText("100250")   // spec range is 0...1000
        unique("kb_done", type: .button).tap()    // the pinned bar carries the total only when expanded

        let shown = Double((field.value as? String) ?? "")
        XCTAssertNotNil(shown, "The field is not showing a number at all.")

        let weeklyTotal = unique("result_Weekly total")
        let computed = number(in: weeklyTotal)

        XCTAssertEqual(shown, computed,
                       "The field shows \(shown as Any) while the engine used \(computed as Any).")
    }
}
