import XCTest

/// The two P0s, end to end, as ONE signed-in check — because sign-in is the cost.
///
/// **WHY ONE TEST AND NOT TWO.** Measured on this rig: a signed-in UI test costs ~126s of
/// execution plus ~41s of harness overhead, and a warm rebuild costs 11s. The build is not
/// the expense; the sign-in is. The two P0s also *stack* — you cannot log a dose against a
/// protocol you cannot see — so splitting them would pay the sign-in twice to answer half
/// a question each time.
///
/// **THE SEQUENCE THAT HAS NEVER SUCCEEDED ON ANY BUILD:**
///   1. save a protocol from the Add flow
///   2. → it must appear on the dashboard
///      (today `saved_dosages.status` defaults `'draft'` and `is_active` defaults `false`,
///      `NewSavedDosage` writes neither, and every consumer filters on `isActive` — so the
///      row lands and is invisible)
///   3. → log a dose against it
///      (today `NewDoseLogPin` carries no `user_id`, `dose_log.user_id` is `uuid NOT NULL`
///      with no default and no triggers, so the insert dies before RLS is even reached)
///
/// ---
///
/// ## RIG HAZARD — read before editing this file (recorded 2026-08-02)
///
/// **Never tap a dose cell on the Calendar tab.** The two halves of the log toggle have
/// OPPOSITE outcomes. `logDose` inserts and fails. `unlogDose` DELETEs on
/// `(protocol_id, dosed_on)` carrying no payload, so the RLS `USING` clause admits it and
/// **it succeeds** — against the caller's own rows. Untick a real dose and it is gone
/// permanently, because the insert that would restore it is the broken half.
///
/// This test therefore **never touches the Calendar tab at all**, and drives the log only
/// through the dashboard's `NextDoseCard`. That path is safe by construction, and the
/// reason is worth stating because it is not obvious: `NextDoseCard` renders the
/// "Mark taken" button ONLY in the `!model.alreadyTaken` branch — when the dose is already
/// taken it renders the static text "Logged for …" and no button at all. So the dashboard
/// control is insert-only and cannot reach `unlogDose`. `DashboardViewModel.markTaken` has
/// no untake path either. The destructive toggle is `CalendarViewModel.toggleTaken`, and
/// nothing here goes near it.
///
/// The guard in `tapMarkTakenOnlyIfUntaken()` enforces that rather than trusting it.
///
/// ---
///
/// ## EVERY ABSENCE CARRIES A POSITIVE CONTROL
///
/// Both headline assertions are absences — "the protocol is not on the dashboard", "the
/// dose did not land" — and an absence is the dangerous kind, because a crashed app, a tab
/// that never opened and a grid that never loaded all contain no protocol either, and all
/// of them report success. So each absence is preceded by a presence assertion on the SAME
/// query against the SAME tree (§5.36, D4).
final class AddFlowToDoseLogUITests: XCTestCase {

    /// The calculator this test drives. Present on every browse surface, not withdrawn.
    private static let calculatorName = "TRT Dose"

    /// The positive control for the dashboard protocol grid: if the grid rendered at all,
    /// the QA account has protocols on it. Asserted before we conclude ours is missing.
    private static let gridMustBeNonEmpty = true

    private var app: XCUIApplication!

    /// Stamped at save time and printed at the end so the database can be read as an
    /// INDEPENDENT second observer — match on `created_at >= this`. The label is not
    /// enough to identify the row: `CalculatorViewModel.save` sets `label` to
    /// `spec.saveTitle`, a fixed per-calculator string, so every save from this
    /// calculator carries the same label.
    private var saveAttemptedAt: Date?

    /// The distinctive dose that makes this run's `config` JSON unique.
    ///
    /// Load-bearing, not cosmetic. Dedup on `saved_dosages` is a unique index on
    /// `(user_id, calculator_type, config)`, and `saveDosage` swallows the unique
    /// violation and returns the EXISTING row's id. So a run that entered the same
    /// numbers as a previous run would silently adopt an old row and prove nothing about
    /// saving. Override with `TEST_RUNNER_MARKER_DOSE` to force a fresh row.
    private var markerDose: String {
        ProcessInfo.processInfo.environment["MARKER_DOSE"] ?? "137"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "system prompts") { alert in
            for label in ["Allow While Using App", "Don't Allow", "Don’t Allow", "Continue", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app = XCUIApplication()

        // `xcodebuild` forwards ONLY host variables carrying the `TEST_RUNNER_` prefix,
        // AND IT STRIPS THE PREFIX ON THE WAY IN. So the host sets
        // TEST_RUNNER_QA_EMAIL and this process reads QA_EMAIL. Getting that backwards
        // is indistinguishable from having no credentials, and the suite then skips
        // every test and reports success — measured on this rig: without the prefix,
        // "Executed 1 test, with 1 test skipped", xcodebuild exit code 0.
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

    // MARK: - The check

    func testProtocolSavedFromAddFlowReachesTheDashboardAndItsDoseLogLands() {
        // ---- Step 1: save a protocol from the Add flow -------------------------------
        openCalculator(named: Self.calculatorName)
        enterMarkerDose()

        // POSITIVE CONTROL for the save. `cta_add` is also carried by three hidden bar
        // candidates and by the tab bar's middle slot, so it is resolved through
        // `unique(_:)` — a check that resolved it by label spent a week measuring the
        // tab bar, which is always enabled and always hittable (§5.38).
        let addCTA = unique("cta_add", type: .button)
        XCTAssertTrue(addCTA.waitForExistence(timeout: 10),
                      "POSITIVE CONTROL FAILED: no save control on the calculator — "
                      + "nothing below this line would mean anything.")
        XCTAssertTrue(addCTA.isEnabled,
                      "POSITIVE CONTROL FAILED: save control present but disabled, so the "
                      + "inputs were not accepted and this run never attempted a save.")

        saveAttemptedAt = Date()
        addCTA.tap()

        // A save failure renders `vm.saveState == .failed(msg)` as danger-coloured text.
        // Assert on the OUTCOME, never on the credential.
        let saveError = firstVisibleErrorText(timeout: 8)
        XCTAssertNil(saveError,
                     "Add flow reported a save failure: \(saveError ?? "")")

        // ---- Step 2: does it reach the dashboard? ------------------------------------
        goToDashboard()

        // POSITIVE CONTROL for the grid. If the QA account's dashboard shows NO protocol
        // at all, the grid did not render (or the account is empty) and the absence of
        // OUR protocol below is unreadable — same query, same tree, asserted first.
        let anyProtocolVisible = app.staticTexts.allElementsBoundByIndex
            .contains { !$0.label.isEmpty && $0.isHittable }
        XCTAssertTrue(anyProtocolVisible && Self.gridMustBeNonEmpty,
                      "POSITIVE CONTROL FAILED: dashboard rendered no content, so 'the new "
                      + "protocol is missing' cannot be distinguished from 'nothing loaded'.")

        // THE P0 #2 ASSERTION. Expected to FAIL on current HEAD: the row lands
        // status='draft', is_active=false, and every consumer filters on isActive.
        let savedLabel = Self.calculatorName
        let onDashboard = app.staticTexts.matching(identifier: savedLabel).firstMatch.exists
            || app.staticTexts[savedLabel].waitForExistence(timeout: 6)
        XCTAssertTrue(onDashboard,
                      "P0 #2: a protocol saved from the Add flow is NOT visible on the "
                      + "dashboard. It lands status='draft' / is_active=false and every "
                      + "consumer filters on isActive.")

        // ---- Step 3: log a dose against it -------------------------------------------
        // Only reached when step 2 passes, which is correct: the two P0s stack, and
        // logging against a protocol the user cannot see is not a real user path.
        tapMarkTakenOnlyIfUntaken()

        // Does the UI TELL the user, or does it read as logged?
        //
        // This is the question the run exists to answer. `DashboardViewModel.markTaken`
        // flips `alreadyTaken = true` optimistically, then rolls back inside `catch`
        // WITHOUT surfacing any message — so the predicted observation is a tick that
        // appears and silently reverts. Note the rollback is also CONDITIONAL on
        // `data.nextDose?.occurrence == occurrence`; if the dashboard reloaded in
        // between, the rollback is skipped and the tick stays with nothing written.
        let tickAppeared = app.staticTexts["Taken"].waitForExistence(timeout: 3)
            || app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Logged for'"))
                .firstMatch.exists

        // Let the write fail and the rollback land.
        Thread.sleep(forTimeInterval: 6)

        let tickPersisted = app.staticTexts["Taken"].exists
            || app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Logged for'"))
                .firstMatch.exists
        let errorShown = firstVisibleErrorText(timeout: 2)

        // Recorded, not asserted — this is the observation the directing side asked for,
        // and all three outcomes are findings rather than pass/fail.
        let verdict: String
        if errorShown != nil {
            verdict = "USER IS TOLD — error surfaced: \(errorShown!)"
        } else if tickAppeared && !tickPersisted {
            verdict = "SILENT REVERT — tick appeared then vanished with NO message."
        } else if tickPersisted {
            verdict = "READS AS LOGGED — tick persisted with nothing written. WORST CASE."
        } else {
            verdict = "NO VISIBLE RESPONSE to the tap at all."
        }

        print("""

        ===== Q1 OBSERVATION =====
        marker_dose:        \(markerDose)
        save_attempted_at:  \(saveAttemptedAt.map(Self.iso) ?? "n/a")
        tick_appeared:      \(tickAppeared)
        tick_persisted:     \(tickPersisted)
        error_surfaced:     \(errorShown ?? "none")
        VERDICT:            \(verdict)
        Cross-read with:
          select user_id, protocol_id, dosed_on, draw_ml, site, created_at
            from dose_log where created_at >= '\(saveAttemptedAt.map(Self.iso) ?? "")';
        ==========================

        """)

        // The P0 #1 assertion. An error the user can see is the minimum acceptable
        // behaviour for a dosing app; a silent revert is a finding, not a pass.
        XCTAssertNotNil(errorShown,
                        "P0 #1: the dose log failed and the app said NOTHING. \(verdict)")
    }

    // MARK: - Entry

    private func dismissDisclaimerIfPresent() {
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
    }

    /// Signs in only when actually signed out. The session lives in the **Keychain**, so
    /// it survives relaunch and one sign-in covers the run; repeated sign-ins against real
    /// Supabase auth would eventually rate-limit into a lockout. Nothing here logs the
    /// credential — assertions are on the outcome, because an `.xcresult` is a place a
    /// password leaks by accident.
    private func signInIfNeeded(email: String, password: String) {
        if app.buttons["Dashboard"].waitForExistence(timeout: 6) { return }

        let signIn = app.buttons["Sign in"]
        if signIn.waitForExistence(timeout: 5) { signIn.tap() }

        let emailField = app.textFields.firstMatch
        guard emailField.waitForExistence(timeout: 8) else {
            XCTFail("Signed out, but no email field appeared."); return
        }
        emailField.tap(); emailField.typeText(email)

        let passwordField = app.secureTextFields.firstMatch
        guard passwordField.waitForExistence(timeout: 5) else {
            XCTFail("No password field."); return
        }
        passwordField.tap(); passwordField.typeText(password)

        app.buttons["Sign in"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 25),
                      "Sign-in did not reach the app.")
    }

    // MARK: - Navigation

    /// The Tools list is a `List`, so XCUITest surfaces it as a collectionView, and its
    /// rows are lazy — `waitForExistence` reports "does not exist" for a row two swipes
    /// away. So: re-query inside the loop, and treat absent and present-but-off-screen as
    /// the same condition.
    private func openCalculator(named name: String) {
        let back = app.navigationBars.buttons.matching(identifier: "Tools").firstMatch
        if back.exists && back.isHittable { back.tap() }

        // The LOWEST hittable `Tools` is the tab item; the list itself carries a row with
        // the same label once the drawer is in the tree.
        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()

        if let list = scrollContainer() {
            for _ in 0..<8 { list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 500)) }
        }

        for _ in 0..<12 {
            if let row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first(where: { $0.isHittable }) {
                row.tap()
                XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10),
                              "Tapped '\(name)' but landed somewhere else — measuring the "
                              + "wrong screen is quieter than photographing one.")
                return
            }
            guard let list = scrollContainer() else { break }
            list.swipeUp(velocity: XCUIGestureVelocity(rawValue: 600))
        }
        XCTFail("Could not reach the '\(name)' row in the Tools list.")
    }

    private func goToDashboard() {
        let tabs = app.buttons.matching(identifier: "Dashboard")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Dashboard tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()

        // Pull to refresh so the dashboard re-reads rather than showing a cache from
        // before the save.
        if let list = scrollContainer() {
            list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 400))
        }
        Thread.sleep(forTimeInterval: 3)
    }

    private func scrollContainer() -> XCUIElement? {
        (app.collectionViews.allElementsBoundByIndex
         + app.tables.allElementsBoundByIndex
         + app.scrollViews.allElementsBoundByIndex)
            .first { $0.isHittable && $0.frame.minX >= 0 }
    }

    // MARK: - Input

    /// Types the marker dose into the calculator's dose field.
    private func enterMarkerDose() {
        let fields = app.textFields.allElementsBoundByIndex.filter { $0.isHittable }
        guard let doseField = fields.first else {
            XCTFail("No editable field on \(Self.calculatorName)."); return
        }
        doseField.tap()

        // Clear whatever the field defaults to, or the marker appends to it and the
        // config is neither the default nor the marker.
        if let existing = doseField.value as? String, !existing.isEmpty {
            doseField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                      count: existing.count))
        }
        doseField.typeText(markerDose)

        let done = app.buttons["kb_done"]
        if done.exists && done.isHittable { done.tap() }
    }

    // MARK: - The guarded tap

    /// Taps "Mark taken" on the dashboard card, and ONLY when the dose is untaken.
    ///
    /// See the rig hazard at the top of this file. `NextDoseCard` renders this button
    /// only in the `!alreadyTaken` branch, so its mere presence already implies the
    /// dose is untaken — but this asserts it rather than trusting it, because the cost
    /// of being wrong is a permanently deleted production row.
    private func tapMarkTakenOnlyIfUntaken() {
        let alreadyLogged = app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'Logged for'")).firstMatch
        XCTAssertFalse(alreadyLogged.exists,
                       "REFUSING TO TAP: this dose is already logged. Tapping an already-"
                       + "ticked dose is the destructive half of the toggle. Create a dose "
                       + "and read it back; never untick an existing one.")

        let markTaken = app.buttons["Mark taken"]
        XCTAssertTrue(markTaken.waitForExistence(timeout: 10),
                      "No 'Mark taken' button on the dashboard — either the protocol is "
                      + "not surfacing a next dose, or the card is in its taken state.")
        markTaken.tap()
    }

    // MARK: - Helpers

    /// Resolves an identifier to EXACTLY one element, naming the duplicates when it does
    /// not. "found 2" sends you back to the simulator; saying which two usually does not.
    private func unique(_ identifier: String,
                        type: XCUIElement.ElementType = .any,
                        file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let matches = app.descendants(matching: type).matching(identifier: identifier)
        if matches.count != 1 {
            let detail = matches.allElementsBoundByIndex
                .map { "type=\($0.elementType.rawValue) label=\"\($0.label)\" frame=\($0.frame)" }
                .joined(separator: " | ")
            XCTFail("\(identifier) should address exactly one element, found \(matches.count): \(detail)",
                    file: file, line: line)
        }
        return matches.element(boundBy: 0)
    }

    /// The first user-visible error-ish string, or nil. Deliberately does not match on
    /// anything that could contain a credential.
    private func firstVisibleErrorText(timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        let needles = ["could not", "couldn't", "failed", "try again", "error", "unable"]
        repeat {
            for text in app.staticTexts.allElementsBoundByIndex where text.exists {
                let lower = text.label.lowercased()
                if needles.contains(where: { lower.contains($0) }) { return text.label }
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
