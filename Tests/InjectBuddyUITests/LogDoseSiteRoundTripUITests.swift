import XCTest

/// **T-03 — the injection site, end to end and on the device.**
///
/// `dose_log.site` was NULL on every iOS-written row while all fourteen web-written rows
/// carried it, and the web derives its whole rotation model from that column. The unit
/// suite pins the vocabulary and the rotation arithmetic, but neither can answer the only
/// question the task actually asks: **does a dose logged by a human tapping this app land
/// in the database carrying its site?**
///
/// Nothing a rendered view can answer is asked here — that is `InjectionSiteTests`. This
/// costs a signed-in launch, so it does exactly one thing with it.
///
/// **It picks a site the sheet did NOT suggest.** Logging the default would go green on a
/// build where the picker was decorative and the write simply used the rotation's
/// suggestion. The tapped label is the last row of the track and the suggestion is at
/// most one of them, so a run that writes "what the user tapped" and a run that writes
/// "whatever was defaulted" produce different rows.
///
/// **This test cannot see the database, and does not pretend to.** It asserts what it can
/// observe — the sheet opened, a site section rendered, a specific site was tapped, the
/// sheet dismissed without an error — and PRINTS the label it chose. The proof is the
/// `select … from dose_log` run against the site afterwards, quoted in the commit. A UI
/// test asserting its own write landed would be asserting the app's opinion of the app.
///
/// Run:
///   TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… xcodebuild test \
///     -scheme InjectBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
///     -only-testing:InjectBuddyUITests/LogDoseSiteRoundTripUITests
/// `xcodebuild` strips the `TEST_RUNNER_` prefix; without the variables this SKIPS, and a
/// skip and a pass share an exit code — so read the log, not the status.
final class LogDoseSiteRoundTripUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Every label the picker may offer, in the web's own order. Duplicated from
    /// `InjectionSite` rather than imported: a UI test target cannot `@testable import`
    /// the app, and a check that read its expectations out of the code under test would
    /// agree with a renamed site.
    private let imTrack = ["L Glute", "R Glute", "L VG", "R VG",
                           "L Quad", "R Quad", "L Delt", "R Delt"]
    private let subQTrack = ["Abdomen L", "Abdomen R", "L Love handle",
                             "R Love handle", "L Thigh", "R Thigh"]

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

    /// Same contract as `CalculatorWiringUITests`: the session is in the Keychain, so a
    /// signed-in simulator never types a credential, and nothing here logs one.
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

    func testLoggingADoseCarriesTheChosenSite() throws {
        // The raised hero is decorative and hit-tests through to the tab item, so the
        // TAB is what gets tapped. Lowest on screen — "Log dose" is also the CTA inside
        // the sheet once it is open.
        let logTabs = app.buttons.matching(identifier: "Log dose")
        XCTAssertTrue(logTabs.firstMatch.waitForExistence(timeout: 10), "No Log dose tab.")
        let tab = logTabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(tab, "Log dose tab not hittable.")
        tab?.tap()

        // ARRIVAL, asserted before anything is measured on it. Three frames in the old
        // archive were photographs of the previous screen.
        XCTAssertTrue(app.navigationBars["Log a dose"].waitForExistence(timeout: 10),
                      "The log-dose sheet never appeared.")

        // Which track is on screen — that is the selected protocol's route.
        let onScreen = imTrack.contains { siteRow($0).exists } ? imTrack : subQTrack
        XCTAssertTrue(siteRow(onScreen[0]).waitForExistence(timeout: 5),
                      "No injection-site picker in the sheet — `site` would be written NULL.")

        // The LAST site in the track: furthest from the top, and at most one site can be
        // both "the suggestion" and "the last row", so this is a choice and not a default.
        let chosen = onScreen[onScreen.count - 1]
        let row = siteRow(chosen)
        var scrolls = 0
        while !(row.exists && row.isHittable) && scrolls < 8 {
            app.swipeUp(); scrolls += 1
        }
        XCTAssertTrue(row.exists && row.isHittable, "Could not reach the site row \(chosen).")
        row.tap()

        // Printed rather than asserted: the database check is what closes this, and it
        // needs to know which label to look for.
        XCTContext.runActivity(named: "SITE CHOSEN: \(chosen)") { _ in }
        print("T-03 ROUND TRIP — site tapped: \(chosen)")

        let cta = app.buttons["logDose.submit"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "No Log dose CTA.")
        XCTAssertTrue(cta.isEnabled, "CTA disabled — no protocol selected, or offline.")
        cta.tap()

        // The sheet dismisses ONLY on a write that returned a row carrying the site
        // (`LogDoseSheet.log()` keeps it open and shows a message otherwise). So the
        // sheet going away is the app's strongest available statement that the row
        // landed — and it is still only the app's statement, which is why the SQL is
        // the evidence and this is the trigger for it.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.navigationBars["Log a dose"])
        waitForExpectations(timeout: 20)
    }

    private func siteRow(_ site: String) -> XCUIElement {
        app.descendants(matching: .any)["logDose.site.\(site)"]
    }
}
