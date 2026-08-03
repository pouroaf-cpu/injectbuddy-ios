import XCTest

/// The Add flow end to end, as ONE signed-in check — because sign-in is the cost.
///
/// **WHY ONE TEST AND NOT TWO.** Measured on this rig: a signed-in UI test costs ~126s of
/// execution plus ~41s of harness overhead, and a warm rebuild costs 11s. The build is not
/// the expense; the sign-in is. The two P0s also *stack* — you cannot log a dose against a
/// protocol you cannot see — so splitting them would pay the sign-in twice to answer half
/// a question each time.
///
/// ---
///
/// ## WHAT CHANGED UNDER THIS FILE — re-aimed 2026-08-03
///
/// It was written while `BATCH.md` items 1–7 were unfixed, and every assertion in it was
/// aimed at PROVING THE TWO P0s EXISTED. Those items have since landed (6badb96, cdd2d4a,
/// 1cf8de0) and the calculator screen was rewritten under it (69a674a). **So the premises
/// this file used to state are now history, not fact, and the assertions have been turned
/// round to match.** A stale premise sitting in a test's own doc comment is how a green
/// gets misread six months later, which is why the old text is corrected here rather than
/// deleted.
///
/// **THE SEQUENCE THAT HAD NEVER SUCCEEDED ON ANY BUILD — and what now carries it:**
///   1. save a protocol from the Add flow
///      • `NewSavedDosage` carries `status: ProtocolStatus = .active` (`Models.swift`,
///        `var status: ProtocolStatus = .active`) and `SupabaseBackendClient`'s
///        `OwnedSavedDosage` encodes it alongside `user_id`. It never writes the
///        `is_active` mirror — that column is maintained by a database trigger off
///        `status`, which is exactly why `BATCH.md` item 4 requires the row to be read
///        back showing `status='active'` **and** `is_active=true`: the second half is the
///        only thing that proves the trigger's non-draft branch fired.
///      • every write RETURNS the row and throws `BackendWriteError.wroteNothing` on an
///        empty representation (`SupabaseBackendClient.requireRow`), so "it did not throw"
///        and "a row exists" are now the same statement.
///   2. → it must appear on the dashboard
///      *(The old premise, now false: the row landed `status='draft'` / `is_active=false`
///      because `NewSavedDosage` wrote neither, and every consumer filters on `isActive`,
///      so it was written and invisible.)*
///   3. → log a dose against it
///      *(The old premise, now false: `NewDoseLogPin` carried no `user_id` while
///      `dose_log.user_id` is `uuid NOT NULL` with no default and no trigger, so the
///      insert died before RLS was reached. `OwnedDoseLogPin` carries it now.)*
///
/// **So a PASSING run now looks like:** no save error, the confirm-start step reached
/// (which is the row being read back by id), the protocol on the dashboard carrying THIS
/// run's marker, and a tick that STAYS. `BATCH.md` item 5's sweep column, in its own
/// words: *"Look for a tick that STAYS, not a flicker."*
///
/// ---
///
/// ## THE CALENDAR TAB — the rig hazard is FIXED, and the guard stays anyway
///
/// Recorded 2026-08-02, and **no longer true**: the two halves of the Calendar's log
/// toggle had OPPOSITE outcomes. `logDose` inserted and failed on the NOT NULL, while
/// `unlogDose` DELETEd on `(protocol_id, dosed_on)` carrying no payload — the RLS `USING`
/// clause admitted it and it SUCCEEDED — so unticking a real dose destroyed a row the app
/// could not re-create.
///
/// Both halves work now. The insert carries `user_id`, and `unlogDose` carries `user_id`
/// **in its predicate** as well (`SupabaseBackendClient.unlogDose`, `.eq("user_id", …)`)
/// rather than leaning on the RLS `USING` clause alone — `BATCH.md` item 1, whose own note
/// says to strike the hazard section when it lands, because *"a rig hazard that outlives
/// its cause is the `content_size` trap again"*. The correction is stated instead of
/// dropped: a guard whose stated reason is false is worse than no comment at all.
///
/// **This test still never touches the Calendar tab, and still refuses to tap a dose that
/// is already logged** — but for the reasons that survive the fix, not the one that did
/// not. Unticking is not what this check measures; re-creating a row it destroyed is not
/// a write it should be making; and the dashboard path it does drive is insert-only BY
/// CONSTRUCTION. `NextDoseCard` renders the "Mark taken" button ONLY in the
/// `!model.alreadyTaken` branch — when the dose is already taken it renders the static
/// text "Logged for …" and no button at all — and `DashboardViewModel.markTaken` has no
/// untake path. The destructive toggle is `CalendarViewModel.toggleTaken`, and nothing
/// here goes near it.
///
/// The guard in `tapMarkTakenOnlyIfUntaken()` enforces that rather than trusting it. It
/// is cheap, and it is the difference between measuring a fresh insert and measuring
/// nothing.
///
/// ---
///
/// ## EVERY ABSENCE CARRIES A POSITIVE CONTROL
///
/// The headline assertions are now PRESENCES — the protocol IS on the dashboard carrying
/// this run's marker, the tick IS still there six seconds later. That is the safer
/// direction, because a crashed app, a tab that never opened and a grid that never loaded
/// all fail a presence. They are still each preceded by a presence assertion on the SAME
/// query against the SAME tree (§5.36, D4), because "no protocol card" and "no dashboard"
/// are otherwise the same observation.
///
/// **The one absence left is `errorShown == nil`, and its positive control is NOT in this
/// run — read that before trusting the green.** `firstVisibleErrorText` can only fire on
/// strings it knows, so its needles are taken from the app's actual failure copy and each
/// one is cited at the helper. But nothing in a passing run demonstrates that the detector
/// CAN fire, and a green indistinguishable from an absence is not evidence (§5.24). To
/// show it red on purpose: sign in, then put the device in airplane mode before the
/// "Mark taken" tap. `markTaken` throws, `DashboardViewModel` sets `actionError`, and
/// `DashboardScreen` renders it as an `InlineErrorNote` above the content. Until that has
/// been watched once, **the tick assertion — a presence — is the load-bearing one, and the
/// nil-error assertion is corroboration.**
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

    /// The distinctive weekly dose that makes this run's `config` JSON unique.
    ///
    /// Load-bearing, not cosmetic. Dedup on `saved_dosages` is a unique index on
    /// `(user_id, calculator_type, config)`, and `saveDosage` swallows the unique
    /// violation and returns the EXISTING row's id. So a run that entered the same
    /// numbers as a previous run would silently adopt an old row and prove nothing about
    /// saving. Override with `TEST_RUNNER_MARKER_DOSE` to force a fresh row.
    ///
    /// It is also the only thing that distinguishes THIS run's protocol from the ones
    /// already on the QA account. `label` cannot do it — `CalculatorViewModel.save` sets
    /// `label` to `spec.saveTitle`, a fixed per-calculator string ("TRT Dose"), so
    /// asserting on the name alone would go green on a protocol saved weeks ago. The
    /// dashboard renders the marker back as `"\(markerDose)mg"` via
    /// `DashboardFormat.subtitle`/`doseLine`, and that string is what the step-2
    /// assertion looks for.
    private var markerDose: String {
        ProcessInfo.processInfo.environment["MARKER_DOSE"] ?? "137"
    }

    /// How the marker reads back on the dashboard: `DashboardFormat.doseMagnitude`
    /// composes `"\(trim(mgWeek))mg"` with no space, and both the grid card's meta line
    /// and the next-dose card's dose line are built from it.
    private var markerOnScreen: String { "\(markerDose)mg" }

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

        // POSITIVE CONTROL for the save.
        //
        // RE-AIMED after 69a674a, and both halves of the old comment were wrong:
        //   • "three hidden bar candidates carry `cta_add` too" — 69a674a deleted the
        //     five-rung pinning gate, "the ladder, the hidden candidates, the 0.40 cap
        //     and PinnedMode with them", and `CalculatorScreen` says so at the site:
        //     "the ladder of hidden candidates that used to be measured here is gone".
        //     (The comment beside the identifier itself still describes the candidates.
        //     It is stale; correcting it belongs to that file, not this one.)
        //   • "and the tab bar's middle slot" — the tab bar collides by LABEL, never by
        //     identifier. `MainShell` builds it as `.tabItem { Label(tab.title, …) }`
        //     with no `accessibilityIdentifier` at all, which is the entire reason this
        //     identifier exists (§5.38: a check that resolved the CTA by its label spent
        //     a week measuring the tab bar, which is always enabled and always hittable).
        // `cta_add` is now written in exactly ONE place in the whole app, so `unique()`
        // can succeed here — verified by grep, not assumed.
        //
        // THE TYPE NARROWING IS DROPPED, back to `.any`. `DECISIONS-2026-08-02 §9` is
        // explicit that this suite narrows in exactly one place — `kb_done` — because
        // narrowing by habit is how `firstMatch` hid a stepper bug for a session. `.any`
        // is also the STRICTER query: a second element of some other type answering to
        // this identifier is a real ambiguity, and `type: .button` would not see it.
        // `CalculatorWiringUITests` resolves the same control the same way.
        //
        // The wait is separate from the resolution ON PURPOSE. `unique()` COUNTS, and a
        // count taken before the screen has settled reads zero and fails for the wrong
        // reason; `firstMatch` here only blocks until something exists, and the count
        // that follows is still the thing being asserted.
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "cta_add")
                        .firstMatch.waitForExistence(timeout: 10),
                      "POSITIVE CONTROL FAILED: no save control on the calculator — "
                      + "nothing below this line would mean anything.")
        let addCTA = unique("cta_add")
        XCTAssertTrue(addCTA.isEnabled,
                      "POSITIVE CONTROL FAILED: save control present but disabled, so the "
                      + "inputs were not accepted and this run never attempted a save. "
                      + "`isEnabled` is `canSaveProtocol && result.isValid && isOnline`.")

        saveAttemptedAt = Date()
        addCTA.tap()

        // A save failure renders `vm.saveState == .failed(msg)` as danger-coloured text
        // inside the bar, with the message coming from `error.localizedDescription`.
        // Assert on the OUTCOME, never on the credential.
        let saveError = firstVisibleErrorText(timeout: 8)
        XCTAssertNil(saveError,
                     "Add flow reported a save failure: \(saveError ?? "")")

        // THE WRITE RETURNED A ROW, AND THE ROW READS BACK. New, and aimed straight at
        // `BATCH.md` item 3.
        //
        // The Add closure pushes `.addConfirm(dosageId:)` ONLY when `saveState == .saved`
        // AND `vm.savedId != nil`, and `savedId` is what `saveDosage` RETURNED — which now
        // throws `BackendWriteError.wroteNothing` instead of returning empty. Then
        // `ConfirmStartScreen` re-reads that id from the database and renders this button
        // only in its `.loaded` case. So this one control standing on screen is
        // simultaneously "the insert returned a row" and "the row can be read back by
        // id" — the first two thirds of `BATCH.md`'s sweep sequence, and a state this app
        // has never reached from iOS.
        //
        // Addressed by its own label rather than by the section header: a `Form`
        // `Section` title is uppercased by the platform and whether that reaches the
        // accessibility label is not something this side can settle without a run, while
        // a `Button`'s label is exposed verbatim.
        let confirmStart = app.buttons["Confirm start day"]
        XCTAssertTrue(confirmStart.waitForExistence(timeout: 15),
                      "The save never reached the confirm-start step. Either `Add` did not "
                      + "write, or the write returned no row (`wroteNothing`), or the row "
                      + "could not be read back by id. On screen instead: "
                      + visibleTextSummary())

        // Leave by the documented exit rather than by the tab bar: `Set this later` calls
        // `navigator.goToDashboard()`, which is the path a user who does not want to
        // change the start day actually takes, and it unwinds the pushed stack instead of
        // parking a half-finished screen behind the dashboard. The start day stays at the
        // save-time default of today, which is what puts a dose in reach of step 3.
        let setLater = app.buttons["Set this later"]
        if setLater.exists && setLater.isHittable { setLater.tap() }

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

        // THE P0 #2 ASSERTION — and it is now expected to PASS. That is the whole point
        // of the batch: `status` is written `active`, the trigger mirrors it into
        // `is_active`, and `DashboardViewModel.load` filters `dosages.filter { $0.isActive }`
        // on exactly that column. A RED here means the batch did not do what it claims.
        //
        // TWO assertions, and the second is the load-bearing one:
        //   • the calculator's name is on the dashboard at all;
        //   • THIS RUN's marker is on it. Without the marker the check goes green on any
        //     `TRT Dose` protocol saved on any previous day, including one saved from the
        //     web, which would prove nothing about the write that just happened.
        //
        // NOT SETTLED FROM THE SOURCE, and it is why the name check is the weaker of the
        // two: whether a `TabView` leaves the OTHER tab's pushed `CalculatorScreen` — and
        // its `screen_title` labelled "TRT Dose" — in the accessibility tree is a runtime
        // question. If it does, the name check can be satisfied by the calculator we just
        // came from. `"\(markerDose)mg"` has no such problem: the calculator renders the
        // marker as a bare field value and as `"137.0 mg"` in a result row, and only
        // `DashboardFormat` composes it without the space.
        //
        // Queried across the WHOLE tree rather than `app.staticTexts`, because
        // `ProtocolCard` is a `Button` and SwiftUI merges a button's label subtree into
        // one accessibility element — the compound and the meta line may well arrive as
        // one concatenated label on the button rather than as two static texts. Which of
        // the two it is cannot be settled from the source; a query that is correct either
        // way is not a loosening, because the string must still be on screen.
        XCTAssertNotNil(anyElement(labelContaining: Self.calculatorName, timeout: 10),
                        "P0 #2: no protocol named '\(Self.calculatorName)' is on the "
                        + "dashboard at all. On screen: " + visibleTextSummary())
        XCTAssertNotNil(anyElement(labelContaining: markerOnScreen, timeout: 10),
                        "P0 #2: the dashboard shows no protocol carrying THIS run's marker "
                        + "(\(markerOnScreen)). Either the protocol just saved is not "
                        + "surfacing — check `status`/`is_active` on the row written at "
                        + "\(saveAttemptedAt.map(Self.iso) ?? "n/a") — or the marker never "
                        + "reached `config.mgWeek`. On screen: " + visibleTextSummary())

        // ---- Step 3: log a dose against it -------------------------------------------
        // Only reached when step 2 passes, which is correct: the two P0s stack, and
        // logging against a protocol the user cannot see is not a real user path.
        //
        // WHICH protocol the next-dose card is offering is NOT asserted, and that is a
        // deliberate limit rather than an oversight. `DoseProjection.nextDose` picks the
        // soonest dose across EVERY active protocol on the account, so on a QA account
        // carrying older protocols the card may be offering one of those instead of the
        // one just saved. Failing the run for that would be a red about the account's
        // contents, not about the write. So the card's title is RECORDED below and the
        // `protocol_id` in the printed cross-read is what settles it.
        let nextDoseTitle = nextDoseCardTitle()
        tapMarkTakenOnlyIfUntaken()

        // DOES THE TICK STAY? — and this is the assertion that changed direction.
        //
        // The old code predicted a silent revert, because `markTaken` used to flip
        // `alreadyTaken = true` BEFORE the await and roll it back inside a `catch` that
        // surfaced nothing. That code is gone. `DashboardViewModel.markTaken` is now
        // confirm-then-commit: it writes first, commits `alreadyTaken` only off the row
        // the database RETURNED (matching `protocolId` and `dosedOn`), sets `actionError`
        // on failure, and drives `isMarkingTaken` so the CTA shows a spinner across the
        // await instead of sitting inert.
        //
        // So the tick can no longer outrun the database by construction, and the
        // observation to make is `BATCH.md` item 5's, in its own words: **a tick that
        // STAYS, not a flicker.** A tick that appears and vanishes now means something
        // different from what it used to — the write threw after the commit, or the model
        // was replaced under it — and it is still a finding either way.
        let tickAppeared = tickIsShowing(waitingUpTo: 8)

        // Long enough for a write to land, a failure to surface, and any reload to
        // replace the model. If the tick is going to go away, it has gone by now.
        Thread.sleep(forTimeInterval: 6)

        let tickPersisted = tickIsShowing(waitingUpTo: 0)
        let errorShown = firstVisibleErrorText(timeout: 2)

        // Recorded first, asserted after — the printout is the observation the directing
        // side asked for, and it must survive the assertion that follows it.
        let verdict: String
        if errorShown != nil {
            verdict = "WRITE REFUSED, AND THE USER IS TOLD — \(errorShown!)"
        } else if tickAppeared && !tickPersisted {
            verdict = "FLICKER — tick appeared then vanished with NO message. "
                    + "Confirm-then-commit should make this impossible; if it happened, "
                    + "the commit landed and something replaced the model after it."
        } else if tickPersisted {
            verdict = "TICK STAYED — the expected pass. Cross-read the row to confirm it."
        } else {
            verdict = "NO VISIBLE RESPONSE to the tap at all."
        }

        print("""

        ===== ADD-FLOW OBSERVATION =====
        marker_dose:        \(markerDose)
        save_attempted_at:  \(saveAttemptedAt.map(Self.iso) ?? "n/a")
        next_dose_card:     \(nextDoseTitle ?? "unread")
        tick_appeared:      \(tickAppeared)
        tick_persisted:     \(tickPersisted)
        error_surfaced:     \(errorShown ?? "none")
        VERDICT:            \(verdict)
        Cross-read with (item 4 needs BOTH columns — is_active is the trigger's half):
          select id, status, is_active, calculator_type, label, config, created_at
            from saved_dosages where created_at >= '\(saveAttemptedAt.map(Self.iso) ?? "")';
          select user_id, protocol_id, dosed_on, draw_ml, site, created_at
            from dose_log where created_at >= '\(saveAttemptedAt.map(Self.iso) ?? "")';
        ================================

        """)

        // THE LOAD-BEARING ASSERTION, and it is a PRESENCE. A tick that is still on
        // screen after the write has had six seconds to fail is the observable end of
        // "the dose was logged"; the row cross-read above is the independent second
        // observer, because the app agreeing with itself is not evidence (§5.1).
        XCTAssertTrue(tickPersisted,
                      "The dose did not read as logged. \(verdict)")

        // CORROBORATION, NOT PROOF — see the note at the top of this file. This absence
        // has no positive control inside a passing run: nothing here shows that
        // `firstVisibleErrorText` is capable of firing. It is asserted because a screen
        // that shows BOTH a tick and an error is a contradiction worth failing on, not
        // because its silence is evidence of success.
        XCTAssertNil(errorShown,
                     "The tick is showing AND the app is reporting a failed write — those "
                     + "cannot both be true. \(errorShown ?? "")")
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
                assertLandedOnCalculator(named: name)
                return
            }
            guard let list = scrollContainer() else { break }
            list.swipeUp(velocity: XCUIGestureVelocity(rawValue: 600))
        }
        XCTFail("Could not reach the '\(name)' row in the Tools list.")
    }

    /// "I am on the right calculator" — RE-AIMED off the navigation bar and onto
    /// `screen_title`.
    ///
    /// This used to read `app.navigationBars[name].waitForExistence(…)`. 69a674a moved
    /// the calculator's title OUT of the navigation bar and into the content area as
    /// `ScreenHeader` — `DESIGN-PARITY §9` option (a), never `.principal` — because a
    /// wrapping `Text` in `.principal` renders two lines and CLIPS THE THIRD AT BOTH
    /// ENDS with no ellipsis and nothing on screen signalling the loss. On a dosing app
    /// a title that silently loses characters is worse than one that truncates visibly.
    ///
    /// THE NAV BAR IS NOT ASSERTED ON ANY MORE, and the reason is not that it is empty.
    /// `RouteContent` still applies `.navigationTitle(route.title)` to every route, and
    /// `CalculatorScreen` only demotes it to `.inline` — the title is kept because it is
    /// also the back control's label for anything pushed from here. So the old assertion
    /// may well still pass. It is dropped because the element it names is now explicitly
    /// TRANSITIONAL: the screen's own comment calls that line "AN INTERIM" and says the
    /// real fix moves the display-mode decision into `RouteContent` for all fifteen
    /// calculators. A check pinned to chrome that is documented as on its way out will go
    /// red for a reason that has nothing to do with the Add flow.
    ///
    /// `screen_title` is the element `DESIGN-PARITY §9` REQUIRES to exist, it carries the
    /// calculator name as its accessibility label, and it is what the user actually
    /// reads. Resolved through `unique()` with `.any` because the element type of a
    /// merged `.accessibilityElement(children: .ignore)` header carrying `.isHeader` is
    /// not something this side can settle by reading the source — naming a type here
    /// would be guessing, and a guess that resolves to zero elements fails for the wrong
    /// reason.
    private func assertLandedOnCalculator(named name: String) {
        let header = app.descendants(matching: .any).matching(identifier: "screen_title")
        XCTAssertTrue(header.firstMatch.waitForExistence(timeout: 10),
                      "Tapped '\(name)' and no `screen_title` appeared — measuring the "
                      + "wrong screen is quieter than photographing one. Navigation bars "
                      + "present: "
                      + app.navigationBars.allElementsBoundByIndex
                          .map(\.identifier).joined(separator: ", "))
        XCTAssertEqual(unique("screen_title").label, name,
                       "Landed on a calculator, but not '\(name)'.")
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

    /// Types the marker dose into the calculator's WEEKLY DOSE field.
    ///
    /// RE-AIMED. This used to take "the first hittable text field", which on `TRT Dose`
    /// is NOT the dose: the spec's field order is `strength` (vial strength, mg/mL),
    /// then `mgWeek`. So the marker was going into the vial concentration. It still made
    /// `config` unique, so the dedup argument held — but the doc comment called it a
    /// dose, the printed cross-read reads as a dose, and nothing on the dashboard renders
    /// `strength`, so there was no way to recognise this run's protocol once it was
    /// saved. `field_mgWeek` is the dose, it is addressed by identifier rather than by
    /// position, and `DashboardFormat` renders it straight back as `"137mg"`.
    private func enterMarkerDose() {
        let doseField = app.textFields["field_mgWeek"]
        guard doseField.waitForExistence(timeout: 8) else {
            XCTFail("No `field_mgWeek` on \(Self.calculatorName) — the weekly-dose field "
                    + "is what this run's marker identifies the protocol by.")
            return
        }
        doseField.tap()

        // Clear whatever the field defaults to, or the marker APPENDS to it. Not
        // theoretical: typing "100250" into a populated `mgWeek` is the exact input that
        // produced the field-shows-100250 / engine-used-1000 defect, and `mgWeek`'s
        // default is 100. The value is re-read here rather than assumed, because the
        // number of deletes has to match what is actually in the field.
        if let existing = doseField.value as? String, !existing.isEmpty {
            doseField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                      count: existing.count))
        }
        doseField.typeText(markerDose)

        // POSITIVE CONTROL on the input itself (§5.35). Everything after this measures a
        // protocol built from this number; if the field is holding "100137" or "100"
        // then the run is measuring a different protocol than the one it reports, and it
        // would say so nowhere. Asserted BEFORE the keypad is dismissed, so the failure
        // names the typing rather than the dismissal.
        XCTAssertEqual(doseField.value as? String, markerDose,
                       "The weekly-dose field is not holding the marker. Everything below "
                       + "would be measuring a protocol this run did not describe.")

        // `kb_done` — and this is the ONE place this suite narrows `unique()` by type,
        // which is `DECISIONS-2026-08-02 §9` and is not a habit to spread. A keyboard
        // `ToolbarItemGroup` bridges its items to UIKit and publishes the identifier on
        // BOTH the bridged bar button and the hosted SwiftUI content: measured as an
        // Other at (348.0, 539.0, 38.0, 44.0) and a Button at (345.0, 539.0, 44.0, 44.0).
        // `CalculatorScreen` records the same measurement at the site and states that
        // nothing on the app side removes the second element — reordering the modifiers
        // changed nothing and `accessibilityElement(children: .ignore)` changed nothing,
        // to the pixel. So `unique("kb_done")` at `.any` provably CANNOT succeed, and the
        // narrowing to `.button` is the resolution rather than a relaxation: it still
        // asserts exactly one BUTTON, and a second button answering to `kb_done` would
        // still be a named failure.
        //
        // Tapped unconditionally, not behind `if exists`. The old `if done.exists &&
        // done.isHittable` silently did nothing when the toolbar was missing, leaving the
        // keypad up over the rest of the run with no record that it had — an absence
        // reported as success. The toolbar is present whenever a field is focused, which
        // the tap above guarantees, so its absence is a finding and should read as one.
        unique("kb_done", type: .button).tap()
    }

    // MARK: - The guarded tap

    /// Taps "Mark taken" on the dashboard card, and ONLY when the dose is untaken.
    ///
    /// KEPT AFTER THE FIX, with its reason corrected — see the Calendar section at the
    /// top of this file. The original reason ("the insert that would restore the row is
    /// the broken half") is gone: `logDose` carries `user_id` now and works. What is left
    /// is still worth a guard. Tapping a dose that is already logged measures nothing —
    /// `markTaken` would either be unreachable or write a duplicate — and a run that
    /// silently did that would report a tick it did not cause. It also holds the line the
    /// board asks for: create a dose and read it back, never toggle an existing one.
    ///
    /// `NextDoseCard` renders this button only in the `!alreadyTaken` branch, so its mere
    /// presence already implies the dose is untaken. This asserts it rather than trusting
    /// it, because internally consistent code is not evidence (§5.1).
    private func tapMarkTakenOnlyIfUntaken() {
        let alreadyLogged = app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'Logged for'")).firstMatch
        XCTAssertFalse(alreadyLogged.exists,
                       "REFUSING TO TAP: this dose is already logged, so a tick after the "
                       + "tap would be one this run did not cause. Create a dose and read "
                       + "it back; never toggle an existing one.")

        let markTaken = app.buttons["Mark taken"]
        XCTAssertTrue(markTaken.waitForExistence(timeout: 10),
                      "No 'Mark taken' button on the dashboard — either the protocol is "
                      + "not surfacing a next dose, or the card is in its taken state.")
        markTaken.tap()
    }

    /// Whichever of the card's two taken-states is showing, if either.
    ///
    /// BOTH are read, because they are two different renderings of the same fact and
    /// they arrive from different places: the `Label("Taken", …)` in the card's header
    /// row, and the `Text("Logged for \(dayKey)")` that replaces the button. Reading only
    /// one would make "the tick vanished" and "the card re-laid-out" the same
    /// observation. `waitingUpTo: 0` reads the tree once, with no wait — which is what
    /// the persistence check needs, since a wait there would let a tick that came back
    /// count as one that never left.
    private func tickIsShowing(waitingUpTo timeout: TimeInterval) -> Bool {
        let logged = app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'Logged for'")).firstMatch
        if timeout > 0 {
            if app.staticTexts["Taken"].waitForExistence(timeout: timeout) { return true }
            return logged.exists
        }
        return app.staticTexts["Taken"].exists || logged.exists
    }

    /// The next-dose card's protocol name, for the record. Recorded, never asserted: see
    /// the note at the tap site about `DoseProjection.nextDose` picking the soonest dose
    /// across every active protocol on the account, not necessarily this run's.
    private func nextDoseCardTitle() -> String? {
        guard let marker = app.staticTexts.allElementsBoundByIndex
            .first(where: { $0.label == "Next dose" }) else { return nil }
        // The title is the card's own next line down, and the card is the only thing at
        // this x-origin, so "below the marker, nearest to it" identifies it without
        // depending on index order in the tree.
        return app.staticTexts.allElementsBoundByIndex
            .filter { $0.frame.minY > marker.frame.maxY && !$0.label.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }?
            .label
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

    /// Any ON-CANVAS element whose LABEL contains `needle`, or nil.
    ///
    /// Not `app.staticTexts`, on purpose. `ProtocolCard` is a `Button` and SwiftUI merges
    /// a button's label subtree into a single accessibility element, so the compound name
    /// and the meta line may arrive as one concatenated label on the button rather than
    /// as two static texts. Which of the two it is cannot be settled from the source.
    /// Searching the whole tree is correct either way and is not a loosening: the string
    /// still has to be on screen for this to return non-nil.
    ///
    /// **`frame.minX >= 0` IS THE LOAD-BEARING PART OF THIS FILTER.** The off-canvas
    /// drawer duplicates every calculator name and resolves at x = −290; without the
    /// filter, "is the protocol on the dashboard?" would be answered by a drawer row that
    /// is on the dashboard the way the back of the wardrobe is in the room. `isHittable`
    /// would exclude it too, and is the WRONG test here: a protocol card scrolled below
    /// the fold is not hittable and is still on the dashboard. Position, not reachability.
    private func anyElement(labelContaining needle: String,
                            timeout: TimeInterval) -> XCUIElement? {
        let query = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", needle))
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let onCanvas = query.allElementsBoundByIndex
                .first(where: { $0.frame.minX >= 0 }) {
                return onCanvas
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    /// What is on screen, for a failure message. Truncated per label and capped in count
    /// so a red prints a readable page rather than the whole accessibility tree.
    private func visibleTextSummary() -> String {
        app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
            .prefix(25)
            .map { $0.count > 60 ? String($0.prefix(60)) + "…" : $0 }
            .joined(separator: " | ")
    }

    /// The first user-visible error-ish string, or nil. Deliberately does not match on
    /// anything that could contain a credential.
    ///
    /// **THE NEEDLES ARE THE APP'S OWN COPY, and each one is here because a specific
    /// string would otherwise slip past.** The original list could not see the message
    /// this test now exists to look for: `DashboardViewModel.markTaken` sets
    /// `actionError` to `"That dose was not logged. …"` and the wrapped
    /// `BackendWriteError.wroteNothing` reads `"Nothing was saved. The insert changed no
    /// row in dose_log — …"`. Neither contains "failed", "error", "unable", "try again"
    /// or any spelling of "could not". A detector that cannot fire on the one message the
    /// screen is capable of showing turns `XCTAssertNil(errorShown)` into a green that is
    /// indistinguishable from an absence — §5.24, and on the exact assertion §5.24 is
    /// about.
    ///
    /// Both apostrophes are listed. The app's copy uses the ASCII `'` today, and a
    /// typographic `’` arriving later from a copy edit would silently un-match.
    ///
    /// This still has NO positive control inside a passing run — see the note at the top
    /// of the file for how to make it fire on purpose.
    private func firstVisibleErrorText(timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        let needles = [
            // Generic.
            "could not", "couldn't", "couldn’t", "failed", "try again", "error", "unable",
            // `DashboardViewModel.markTaken`, the one this run's tick assertion pairs with.
            "was not logged",
            // `BackendWriteError.wroteNothing`, wrapped by every write in the client.
            "nothing was saved",
            // `ConfirmStartScreen`, when the row cannot be read back after the save.
            "no longer available",
        ]
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
