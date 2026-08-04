import XCTest

/// **T-53 and T-52, on the device and against the database.**
///
/// The unit suite pins the derivation — which line each config produces, and what
/// `NewDoseLogPin` puts in each column. Neither can answer the two questions these tasks
/// actually ask:
///
///  * T-53 — **does the rendered list show two distinguishable cards** on the account
///    that holds two `TRT Dose` protocols? The screenshot is the evidence; the frame in
///    `docs/ui-audit/2026-08-03-current/08-logdose-sheet-IB2245782.png` is what it
///    replaces.
///  * T-52 — **does an amount the user typed reach the row?** The sheet dismissing is
///    the app's opinion of the app. The `select … from dose_log` afterwards is the proof.
///
/// The amount typed is DELIBERATELY not the default. Logging the seeded value would go
/// green on a build where the field was decorative and the write used the derivation —
/// exactly the failure mode this task is about. It types a value no derivation produces.
///
/// Run:
///   TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… xcodebuild test \
///     -scheme InjectBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -only-testing:InjectBuddyUITests/LogDoseAmountRoundTripUITests
/// `xcodebuild` strips the `TEST_RUNNER_` prefix; without the variables this SKIPS, and a
/// skip and a pass share an exit code — so read the log, not the status.
final class LogDoseAmountRoundTripUITests: XCTestCase {

    private var app: XCUIApplication!

    /// The amount typed into the field. Not a dose any protocol on this account derives,
    /// so a row carrying it can only have come from the field.
    private let typedAmount = "12.75"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "QA_EMAIL / QA_PASSWORD not set — skipping the signed-in round trip.")

        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()

        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
        signInIfNeeded(email: email, password: password)
    }

    /// The session is in the Keychain, so a signed-in simulator never types a credential,
    /// and nothing here logs one.
    private func signInIfNeeded(email: String, password: String) {
        if app.buttons["Dashboard"].waitForExistence(timeout: 8) { return }

        let signIn = app.buttons["Sign in"]
        if signIn.waitForExistence(timeout: 5) { signIn.tap() }

        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 8) else {
            XCTFail("Signed out, but no email field appeared."); return
        }
        emailField.tap(); emailField.typeText(email)

        let passwordField = app.secureTextFields.firstMatch
        guard passwordField.waitForExistence(timeout: 5) else { XCTFail("No password field."); return }
        passwordField.tap(); passwordField.typeText(password)

        app.buttons["Sign in"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 25),
                      "Sign-in did not reach the app.")
    }

    func testTheSheetDistinguishesItsCardsAndLogsTheAmountTyped() throws {
        openSheet()

        // ── T-53 ────────────────────────────────────────────────────────────────
        // Every card's rendered text, gathered from the protocol rows themselves.
        // Two cards reading the same string is the defect, so the assertion is on the
        // set of strings and not on any one of them.
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'logDose.protocol.'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No protocol cards in the sheet.")

        let texts: [String] = rows.allElementsBoundByIndex.map { row in
            row.descendants(matching: .staticText).allElementsBoundByIndex
                .map(\.label).joined(separator: " | ")
        }
        XCTAssertGreaterThan(texts.count, 1, "Only one protocol — this account cannot show the defect.")
        for text in texts { print("T-53 CARD: \(text)") }
        XCTAssertEqual(Set(texts).count, texts.count,
                       "Two cards render the same text — the user still picks by guessing:\n"
                       + texts.joined(separator: "\n"))

        attachScreenshot(named: "T-53 log-dose sheet — every card distinguishable")

        // ── T-52 ────────────────────────────────────────────────────────────────
        let amount = app.textFields["logDose.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5),
                      "No DOSE AMOUNT field — a partial dose still records as the full one.")

        let seeded = amount.value as? String ?? ""
        print("T-52 SEEDED AMOUNT: \(seeded)")
        XCTAssertFalse(seeded.isEmpty, "The amount field is empty — it must default to the derived dose.")
        XCTAssertNotEqual(seeded, typedAmount, "Fixture clash: the derived dose is the value being typed.")

        amount.tap()
        // Clear whatever was seeded, character by character — a decimal pad has no
        // select-all, and a field that appended would log 74.512.75.
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: seeded.count + 2)
        amount.typeText(deletes)
        amount.typeText(typedAmount)
        XCTAssertEqual(amount.value as? String, typedAmount,
                       "The field did not take the typed amount.")

        attachScreenshot(named: "T-52 dose amount edited")

        let cta = app.buttons["logDose.submit"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "No Log dose CTA.")
        // The keypad can sit over the CTA; the CTA is pinned outside the list, so
        // dismissing the keyboard is enough to reach it.
        if !cta.isHittable { app.swipeDown() }
        XCTAssertTrue(cta.isEnabled, "CTA disabled — the typed amount was not accepted.")
        cta.tap()

        // The sheet dismisses ONLY on a write whose returned representation carries the
        // amount that was sent (`LogDoseSheet.log()` keeps it open and says so
        // otherwise). That is the app's strongest available statement, and it is still
        // the app's — which is why the SQL is the evidence and this is its trigger.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.navigationBars["Log a dose"])
        waitForExpectations(timeout: 25)

        print("T-52 ROUND TRIP — amount typed: \(typedAmount) (seeded was \(seeded))")
    }

    // MARK: - helpers

    private func openSheet() {
        // The raised hero is decorative and hit-tests through to the tab item, so the
        // TAB is what gets tapped. Lowest on screen — "Log dose" is also the CTA inside
        // the sheet once it is open.
        let logTabs = app.buttons.matching(identifier: "Log dose")
        XCTAssertTrue(logTabs.firstMatch.waitForExistence(timeout: 10), "No Log dose tab.")
        let tab = logTabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(tab, "Log dose tab not hittable.")
        tab?.tap()

        // ARRIVAL, asserted before anything is measured or photographed on it.
        XCTAssertTrue(app.navigationBars["Log a dose"].waitForExistence(timeout: 10),
                      "The log-dose sheet never appeared.")
    }

    private func attachScreenshot(named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
