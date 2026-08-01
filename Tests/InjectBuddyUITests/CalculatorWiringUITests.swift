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

    // MARK: - The gate

    /// Chip → field → result must all agree. The desync, as an assertion.
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
        let weeklyTotal = app.staticTexts["result_Weekly total"]
        XCTAssertTrue(weeklyTotal.waitForExistence(timeout: 5), "No weekly total row.")
        XCTAssertEqual(weeklyTotal.label, "300.0 mg",
                       "The RESULT disagrees with the field, or has lost its unit.")
    }

    /// The stepper must move by the configured step, not by one.
    func testStep_movesByTen() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        app.buttons["quick_mgWeek_300"].tap()
        XCTAssertEqual(field.value as? String, "300")

        app.buttons["Increase"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "310",
                       "Step moved by the wrong amount.")

        app.buttons["Decrease"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "300")
    }

    /// type → chip → type. The exact sequence that broke: an external write, then
    /// focus, then another external write.
    func testTypeThenChip_neverDesyncs() {
        openTRTCalculator()

        let field = app.textFields["field_mgWeek"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))

        field.tap()
        field.typeText("250")

        app.buttons["quick_mgWeek_400"].tap()
        XCTAssertEqual(field.value as? String, "400",
                       "Chip after typing did not update the field.")

        let weeklyTotal = app.staticTexts["result_Weekly total"]
        XCTAssertEqual(weeklyTotal.label, "400.0 mg",
                       "Result disagrees with the field after chip-following-type.")
    }
}
