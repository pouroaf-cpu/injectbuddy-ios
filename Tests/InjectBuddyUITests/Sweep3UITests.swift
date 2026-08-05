import XCTest

/// SWEEP-3 — the four items that had been NOT OBSERVED all day and are reachable for
/// the first time: `BATCH.md` batch 1 items **1** (`unlogDose` carries `user_id`), **6**
/// (`CalendarScreen.refreshable`), **7** (delete-account dialog copy) and item **5's
/// 400ms clause** (visible feedback on the dose button).
///
/// ## WHY FIVE METHODS AND TWO INVOCATIONS
///
/// Item 1 needs a database read BETWEEN the log and the un-log — *print the row before,
/// unlog it, print the count after* — and nothing inside one `xcodebuild` run can pause
/// for an out-of-process reader. So `testA*` writes and `testB1` removes, launched
/// separately with `-only-testing`.
///
/// The `testA*` split is NOT for isolation's sake; each split is paid for by a fresh
/// app launch (~20s, no re-sign-in — the session is in the Keychain). Two of them are
/// load-bearing:
///   • `testA2` and `testA3` must NOT share a launch. `testA2` saves a protocol and then
///     asks whether the CALENDAR re-reads on a pull; `testA3` needs a dashboard that has
///     already seen that protocol. A relaunch is how `testA3` gets one WITHOUT pulling on
///     the dashboard — see the warning on that in `testA4`.
///   • `testA1` is first because it is independent and cheap, and a run that dies later
///     still answers item 7.
/// XCTest runs methods in name order, which is why they are numbered rather than named
/// for what they do.
///
/// ## NOTHING HERE ASSERTS ITS WAY TO A PASS
///
/// Every item records what it saw into a grep-able block. `continueAfterFailure = true`
/// on purpose: the items are independent, and aborting on the first red would throw away
/// observations that cost a sign-in, making "the run stopped" and "the item failed" the
/// same output. An item that could not be driven prints `NOT OBSERVED`, and that string
/// is the answer — not a placeholder for one.
final class Sweep3UITests: XCTestCase {

    private var app: XCUIApplication!

    /// The calculator `testA2` saves from. Present on every browse surface, not withdrawn.
    private static let calculatorName = "TRT Dose"

    /// The weekly dose that makes `testA2`'s `config` JSON unique.
    ///
    /// LOAD-BEARING. Dedup on `saved_dosages` is a unique index on
    /// `(user_id, calculator_type, config)` and `saveDosage` swallows the violation and
    /// returns the EXISTING row's id — so a repeat of a previous run's number would
    /// silently adopt an old protocol whose `start_date` is NOT today, put no occurrence
    /// on today's agenda, and quietly make item 6's probe unobservable while looking
    /// like it ran. 137 and 0 are already on this account; 149 is not.
    private var markerDose: String {
        ProcessInfo.processInfo.environment["MARKER_DOSE"] ?? "149"
    }

    /// Which agenda row `testB1` un-logs, by label. Supplied from the host AFTER the
    /// database has been read, so the test removes the row this session WROTE rather
    /// than whatever the calendar happens to be showing. Host sets
    /// `TEST_RUNNER_UNLOG_LABEL`; `xcodebuild` strips the prefix.
    private var unlogLabel: String {
        ProcessInfo.processInfo.environment["UNLOG_LABEL"] ?? ""
    }

    override func setUpWithError() throws {
        continueAfterFailure = true

        addUIInterruptionMonitor(withDescription: "system prompts") { alert in
            for label in ["Allow While Using App", "Don't Allow", "Don’t Allow", "Continue", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app = XCUIApplication()

        // `xcodebuild` forwards ONLY host variables carrying `TEST_RUNNER_`, AND STRIPS
        // THE PREFIX. Host sets TEST_RUNNER_QA_EMAIL, this process reads QA_EMAIL.
        // Without them the suite SKIPS and xcodebuild exits 0 in ~42s — a green
        // indistinguishable from an absence.
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "QA_EMAIL / QA_PASSWORD not set — skipping signed-in UI tests.")

        // LIVENESS MARKER — the one line a skipped run cannot print. The summary line
        // cannot tell a skip from a pass; this can.
        print("SWEEP3-LIVENESS: credentials arrived, launching. \(Self.iso(Date()))")

        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()

        dismissDisclaimerIfPresent()
        signInIfNeeded(email: email, password: password)
    }

    // MARK: - A1 — ITEM 7: the delete-account dialog copy

    /// READ AND DISMISSED. Nothing is tapped through: the destructive button on this
    /// dialog calls `deleteAccount()`, which is `auth.signOut()` and nothing else, and
    /// the Keychain session is what every other check in this batch stands on.
    ///
    /// **NO SCREENSHOT IS TAKEN ON THIS SCREEN.** Settings and the drawer header both
    /// render the account's real email, and an `.xcresult` is a place a credential leaks
    /// by accident. The dialog is transcribed from the accessibility tree and anything
    /// carrying an `@` is redacted before printing.
    func testA1DeleteAccountDialogCopy() {
        openSettingsViaDrawer()

        var dialogTitle = "NOT OBSERVED"
        var dialogMessage = "NOT OBSERVED"
        var dialogButtons = "NOT OBSERVED"
        var rowFooter = "NOT OBSERVED"

        // Scroll Settings until the ACCOUNT section is up.
        var reached = app.buttons["Delete account"].exists && app.buttons["Delete account"].isHittable
        if !reached, let list = scrollContainer() {
            for _ in 0..<10 where !reached {
                list.swipeUp(velocity: XCUIGestureVelocity(rawValue: 600))
                reached = app.buttons["Delete account"].exists
                       && app.buttons["Delete account"].isHittable
            }
        }

        // The row's OWN caption, which makes the same promise one screen earlier. Read
        // after the scroll, because it sits under the button.
        if let footer = app.staticTexts.allElementsBoundByIndex
            .first(where: { $0.label.contains("deletion isn't available")
                         || $0.label.contains("deletion isn’t available") }) {
            rowFooter = redact(footer.label)
        }

        if reached {
            app.buttons["Delete account"].tap()

            // A `.confirmationDialog` bridges to an action sheet on iPhone; which of
            // `sheets` / `alerts` it lands in is a runtime question, so both are tried
            // rather than guessed.
            let sheet = app.sheets.firstMatch
            let alert = app.alerts.firstMatch
            let dialog: XCUIElement? =
                sheet.waitForExistence(timeout: 6) ? sheet
                : (alert.waitForExistence(timeout: 3) ? alert : nil)

            if let dialog {
                let texts = dialog.staticTexts.allElementsBoundByIndex
                    .map(\.label).filter { !$0.isEmpty }
                dialogTitle = texts.first.map(redact) ?? "NOT OBSERVED"
                dialogMessage = texts.dropFirst().map(redact).joined(separator: " ⏎ ")
                if dialogMessage.isEmpty { dialogMessage = "NOT OBSERVED" }
                dialogButtons = dialog.buttons.allElementsBoundByIndex
                    .map { "\"\(redact($0.label))\"" }.joined(separator: ", ")

                // DISMISS. Cancel, never the destructive button.
                let cancel = dialog.buttons["Cancel"]
                if cancel.exists && cancel.isHittable { cancel.tap() }
                Thread.sleep(forTimeInterval: 1.5)
                XCTAssertFalse(app.sheets.firstMatch.exists && app.sheets.buttons["Cancel"].exists,
                               "The delete-account dialog did not dismiss on Cancel.")
            }
        }

        print("""

        ===== SWEEP3 ITEM 7 (delete-account dialog copy) =====
        reached_row:     \(reached)
        row_footer:      \(rowFooter)
        dialog_title:    \(dialogTitle)
        dialog_message:  \(dialogMessage)
        dialog_buttons:  \(dialogButtons)
        (emails redacted before printing; no screenshot taken on Settings)
        =====================================================

        """)

        XCTAssertTrue(reached, "Never reached the Delete account row; item 7 NOT OBSERVED.")
    }

    // MARK: - A2 — ITEM 6: CalendarScreen `.refreshable`

    /// **DRIVEN, WITH A PERSISTENT EFFECT — not a transient nobody can catch.**
    ///
    /// The obvious instrument is `LoadingView`'s `Text("Loading…")`, which `reload()`
    /// puts on screen by setting `state = .loading`. It is kept below as a secondary
    /// reading, but it CANNOT carry this item on its own and the first attempt proved
    /// why: the drag gesture takes ~4s to synthesize and XCUITest only returns control
    /// after it, by which time a sub-second re-read against Supabase is already over.
    /// Polling found nothing, and "nothing" there is the instrument's blind spot, not an
    /// absent refresh. **A green indistinguishable from an absence is not evidence, and
    /// so is a red.**
    ///
    /// So the load-bearing instrument is a state change the refresh must PICK UP and
    /// then KEEP:
    ///   1. Calendar loads; today's agenda is recorded — the BASELINE.
    ///   2. A protocol starting TODAY is saved from the Add flow, so a new occurrence
    ///      belongs on today's agenda.
    ///   3. Back on the Calendar, the agenda is recorded WITHOUT pulling. **This is the
    ///      control, and it is the half that makes the result readable.** If the new
    ///      protocol is already there, `.task` re-ran on tab re-appearance, the pull is
    ///      not what caused any later reading, and this item is NOT OBSERVED by this
    ///      method — which the block below says in those words rather than quietly
    ///      counting it as a pass.
    ///   4. Pull to refresh. The new protocol appearing NOW, and only now, is the
    ///      re-read — and it is still on screen to be read at leisure.
    func testA2CalendarRefreshableRereads() {
        goToTab("Calendar")
        let baseline = todaysAgendaLabels(waitingFor: 20)

        // Save a protocol whose start day is today.
        openCalculator(named: Self.calculatorName)
        let saved = saveProtocolWithMarkerDose()

        goToTab("Calendar")
        Thread.sleep(forTimeInterval: 3)
        let beforePull = todaysAgendaLabels(waitingFor: 20)

        let loadingBeforePull = loadingTextShowing()
        let pullAt = Date()
        pullToRefresh()

        var loadingSeenAfterPull = false
        let refreshDeadline = Date().addingTimeInterval(6)
        while Date() < refreshDeadline {
            if loadingTextShowing() { loadingSeenAfterPull = true; break }
        }

        Thread.sleep(forTimeInterval: 4)
        let afterPull = todaysAgendaLabels(waitingFor: 20)

        let grewOnPull = afterPull.count > beforePull.count
        let alreadyThere = beforePull.count > baseline.count
        let verdict: String
        if !saved {
            verdict = "NOT OBSERVED — the protocol never saved, so no change existed for a refresh to pick up"
        } else if alreadyThere {
            verdict = "NOT OBSERVED BY THIS METHOD — the new protocol was on the agenda BEFORE the pull, "
                    + "so `.task` re-ran on tab re-appearance and the pull is not what caused it"
        } else if grewOnPull {
            verdict = "OBSERVED — agenda grew ONLY after the pull; the refresh drove a real re-read"
        } else {
            verdict = "NOT OBSERVED — the agenda did not change after the pull"
        }

        print("""

        ===== SWEEP3 ITEM 6 (CalendarScreen .refreshable) =====
        protocol_saved:            \(saved)  (marker \(markerDose)mg, start day = today)
        baseline_agenda(\(baseline.count)):  \(baseline.joined(separator: " | "))
        before_pull_agenda(\(beforePull.count)): \(beforePull.joined(separator: " | "))
        after_pull_agenda(\(afterPull.count)):  \(afterPull.joined(separator: " | "))
        pull_at_utc:               \(Self.iso(pullAt))
        loading_text_before_pull:  \(loadingBeforePull)
        loading_text_after_pull:   \(loadingSeenAfterPull)   <- secondary only; see the doc comment
        VERDICT: \(verdict)
        ======================================================

        """)
    }

    // MARK: - A5 — ITEM 6, second attempt: an EXTERNAL change, with the screen parked

    /// **`testA2`'s probe was defeated by its own control, and this is the replacement.**
    /// Measured there: leaving the Calendar tab and coming back RE-RUNS `.task`, so a
    /// protocol saved in between was already on the agenda before any pull. The control
    /// caught it and the item was reported NOT OBSERVED rather than counted — but that
    /// left the item unanswered, and "the instrument was blind" is not an answer either.
    ///
    /// So this never leaves the screen. The Calendar is loaded and PARKED; the change is
    /// made from OUTSIDE the app, against production Postgres, while the test sleeps; and
    /// the only thing that can bring it into a screen nobody has navigated away from is
    /// the pull.
    ///
    /// The change is a LABEL EDIT on a protocol already on today's agenda — reversible in
    /// one statement, no new rows, no `is_active` trigger, and no effect on the
    /// projection, so the only thing it can move is the string this test reads.
    ///
    /// **THE SECOND READING IS THE CONTROL AND IT IS NOT OPTIONAL**: the agenda is read
    /// again after the sleep and BEFORE the pull. If the probe string is already there,
    /// something re-read on its own, the pull is not the cause, and this says so.
    ///
    /// Host contract — the run is started in the background and the operator watches for
    /// `SWEEP3-PROBE-WINDOW-OPEN`, then has 60s to run the UPDATE.
    func testA5CalendarRefreshPicksUpExternalChange() {
        let probe = ProcessInfo.processInfo.environment["PROBE_NEEDLE"] ?? "SWEEP3 PROBE"

        goToTab("Calendar")
        let baseline = todaysAgendaLabels(waitingFor: 25)
        let sawProbeAtBaseline = baseline.contains { $0.contains(probe) }

        print("SWEEP3-PROBE-WINDOW-OPEN \(Self.iso(Date())) — 60s; needle=\"\(probe)\"")
        Thread.sleep(forTimeInterval: 60)

        // CONTROL: still parked on the Calendar, nothing tapped, no pull.
        let beforePull = todaysAgendaLabels(waitingFor: 5)
        let sawProbeBeforePull = beforePull.contains { $0.contains(probe) }

        let pullAt = Date()
        pullToRefresh()
        var loadingSeen = false
        let d = Date().addingTimeInterval(6)
        while Date() < d { if loadingTextShowing() { loadingSeen = true; break } }
        Thread.sleep(forTimeInterval: 5)

        let afterPull = todaysAgendaLabels(waitingFor: 25)
        let sawProbeAfterPull = afterPull.contains { $0.contains(probe) }

        let verdict: String
        if sawProbeAtBaseline {
            verdict = "INVALID — the probe string was already on screen at baseline; "
                    + "the host set it too early and this run proves nothing"
        } else if sawProbeBeforePull {
            verdict = "NOT OBSERVED — the change arrived on a parked screen WITHOUT a pull, "
                    + "so something else re-reads and the pull is not the cause"
        } else if sawProbeAfterPull {
            verdict = "OBSERVED — the external change was invisible on the parked screen and "
                    + "appeared ONLY after the pull. `.refreshable` drove a real re-read."
        } else {
            verdict = "NOT OBSERVED — the change never appeared. Either the pull did not "
                    + "re-read, or the host never made the change (check the UPDATE landed)."
        }

        print("""

        ===== SWEEP3 ITEM 6 (CalendarScreen .refreshable) — external-change probe =====
        needle:                  \(probe)
        probe_at_baseline:       \(sawProbeAtBaseline)   <- must be false
        baseline_agenda(\(baseline.count)):     \(baseline.joined(separator: " | "))
        probe_before_pull:       \(sawProbeBeforePull)   <- THE CONTROL; must be false
        before_pull_agenda(\(beforePull.count)):  \(beforePull.joined(separator: " | "))
        pull_at_utc:             \(Self.iso(pullAt))
        loading_text_after_pull: \(loadingSeen)
        probe_after_pull:        \(sawProbeAfterPull)
        after_pull_agenda(\(afterPull.count)):   \(afterPull.joined(separator: " | "))
        VERDICT: \(verdict)
        ==============================================================================

        """)
    }

    // MARK: - A6 — ITEM 6, the discriminating run: is it the app or the gesture?

    /// `testA5` established that a pull on the Calendar produced **no network request at
    /// all** — checked against Supabase's own API log, which is an observer outside the
    /// app and outside this suite. That is either the app's `.refreshable` not firing or
    /// this suite's drag not arming it, and those are opposite conclusions.
    ///
    /// So both screens get the SAME gesture in the SAME run, and the two are told apart
    /// in the API log by a string neither side can fake: the dashboard reads
    /// `dose_log?dosed_on=gte.<today−31>` and the calendar reads
    /// `dose_log?dosed_on=gte.<today−1>`. If the dashboard's `gte` appears at T1 and the
    /// calendar's never appears at T2, the drag arms `.refreshable` fine and the Calendar
    /// is the difference. If neither appears, the instrument is blind and item 6 is NOT
    /// OBSERVED rather than failed.
    func testA6PullOnBothScreensForTheApiLog() {
        goToTab("Dashboard")
        _ = app.staticTexts["Next dose"].waitForExistence(timeout: 25)
        Thread.sleep(forTimeInterval: 3)
        let t1 = Date()
        pullToRefresh()
        Thread.sleep(forTimeInterval: 10)
        let dashError = firstVisibleErrorText(timeout: 2)

        goToTab("Calendar")
        _ = todaysAgendaLabels(waitingFor: 25)
        Thread.sleep(forTimeInterval: 3)
        let t2 = Date()
        pullToRefresh()
        Thread.sleep(forTimeInterval: 10)
        let calError = firstVisibleErrorText(timeout: 2)

        print("""

        ===== SWEEP3 ITEM 6 — discriminating pull (read the API log against these) =====
        dashboard_pull_at_utc: \(Self.iso(t1))   (expect dose_log?dosed_on=gte.<today-31>)
        dashboard_error_after: \(dashError ?? "none")
        calendar_pull_at_utc:  \(Self.iso(t2))   (expect dose_log?dosed_on=gte.<today-1>)
        calendar_error_after:  \(calError ?? "none")
        ===============================================================================

        """)
    }

    // MARK: - A3 — ITEM 5's 400ms clause, and ITEM 1's write half

    /// `DashboardComponents` now passes `isLoading: isMarking` to `PrimaryButton`, which
    /// renders a `ProgressView` and sets `.disabled(true)` across the await. Both are
    /// observable; neither is inferred from that fact.
    ///
    /// **THE INSTRUMENT'S OWN LIMIT, stated because it bounds the answer.** XCUITest
    /// `tap()` returns only once the app is quiescent. The `await` releases the main
    /// thread while the write is in flight, so the app IS idle during it and the tap
    /// should return promptly — but if the whole write completed inside `tap()`, the
    /// spinner is real and this instrument could not have seen it. That case reports
    /// `tap_returned_after_s` covering the whole operation and `NOT OBSERVED` for the
    /// feedback, never "there was no feedback".
    ///
    /// **THE DASHBOARD IS NOT PULLED ON HERE.** It does not need to be: this is a fresh
    /// launch, so `.task` has already re-read. Pulling would also walk straight into the
    /// defect `testA4` exists to record.
    func testA3DashboardMarkTakenFeedback() {
        goToTab("Dashboard")
        // Wait for the dashboard to actually LOAD before touching it.
        _ = app.staticTexts["Next dose"].waitForExistence(timeout: 25)
        Thread.sleep(forTimeInterval: 2)

        let cardTitle = nextDoseCardTitle() ?? "unread"
        let alreadyLogged = app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'Logged for'")).firstMatch.exists
        let markTaken = app.buttons["Mark taken"]
        let markTakenPresent = markTaken.waitForExistence(timeout: 10)

        var tapReturnedAfter = -1.0
        var firstFeedbackAfter = -1.0
        var feedbackKind = "NOT OBSERVED"
        var tickAfter = -1.0
        var logPath = "NOT OBSERVED — no 'Mark taken' on the dashboard"

        if markTakenPresent && !alreadyLogged {
            logPath = "dashboard NextDoseCard 'Mark taken' — card title \"\(cardTitle)\""
            let t0 = Date()
            markTaken.tap()
            tapReturnedAfter = Date().timeIntervalSince(t0)

            // Tight poll. Each query costs tens of ms, so resolution here is roughly
            // 100ms — the right order for a 400ms question, and stated rather than
            // dressed up as precision.
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline {
                let elapsed = Date().timeIntervalSince(t0)
                if firstFeedbackAfter < 0 {
                    if app.activityIndicators.count > 0 {
                        firstFeedbackAfter = elapsed
                        feedbackKind = "ProgressView (activityIndicator)"
                    } else if app.progressIndicators.count > 0 {
                        firstFeedbackAfter = elapsed
                        feedbackKind = "ProgressView (progressIndicator)"
                    } else if !markTaken.exists {
                        firstFeedbackAfter = elapsed
                        feedbackKind = "button gone — card left its untaken branch"
                    } else if !markTaken.isEnabled {
                        firstFeedbackAfter = elapsed
                        feedbackKind = "button disabled"
                    }
                }
                if tickIsShowing() { tickAfter = Date().timeIntervalSince(t0); break }
            }

            // The frame, for the record. THE DASHBOARD ONLY — never Settings, which
            // carries a real email.
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "dashboard-after-mark-taken"
            shot.lifetime = .keepAlways
            add(shot)
        } else if alreadyLogged {
            logPath = "NOT OBSERVED — the dashboard's next dose is ALREADY logged "
                    + "('Logged for …'). There is no insert to make, and tapping anything "
                    + "here would report a tick this run did not cause."
        }

        // FALLBACK, and it is labelled as one. If the dashboard has nothing to log, item
        // 1 still needs a row this session wrote. The Calendar agenda can make one —
        // but it is a DIFFERENT control on a different screen, so it buys item 1 its row
        // and buys item 5's clause nothing.
        var fallbackPath = "not needed"
        if tickAfter < 0 && !markTakenPresent {
            goToTab("Calendar")
            let target = app.buttons.allElementsBoundByIndex
                .first { $0.frame.minX >= 0 && $0.isHittable
                      && $0.label.contains(markerDose) }
            if let target {
                fallbackPath = "calendar agenda row \"\(target.label)\" — item 5's DASHBOARD "
                             + "clause stays NOT OBSERVED"
                target.tap()
                Thread.sleep(forTimeInterval: 6)
            } else {
                fallbackPath = "NOT OBSERVED — no untaken agenda row carrying the marker either"
            }
        }

        let logError = firstVisibleErrorText(timeout: 3)

        print("""

        ===== SWEEP3 ITEM 5 (400ms clause) + ITEM 1 (write half) =====
        next_dose_card:         \(cardTitle)
        already_logged:         \(alreadyLogged)
        mark_taken_present:     \(markTakenPresent)
        log_path:               \(logPath)
        fallback_path:          \(fallbackPath)
        tap_returned_after_s:   \(fmt(tapReturnedAfter))
        first_feedback_after_s: \(fmt(firstFeedbackAfter))
        feedback_kind:          \(feedbackKind)
        tick_after_s:           \(fmt(tickAfter))
        error_surfaced:         \(logError ?? "none")
        ==============================================================

        """)
    }

    // MARK: - A4 — FILED, NOT CHASED: pull-to-refresh puts the dashboard in `.failed`

    /// **Not one of the four items.** Seen while driving them and recorded here because
    /// it is cheap to re-observe and it is on the app's home screen.
    ///
    /// `DashboardViewModel.load` ends `catch { state = .failed(Self.message(error)) }`
    /// with no case for cancellation, and `CalendarViewModel.load` has the same shape.
    /// A load that is CANCELLED — which is what a second `reload()` arriving while one is
    /// in flight produces, and `.refreshable` next to `.task` is exactly that shape — is
    /// therefore rendered as a full-screen `ErrorBanner` reading
    /// *"The operation couldn't be completed. (Swift.CancellationError error 1.)"*.
    /// Measured, not reasoned: that string was on the dashboard in the first sweep run
    /// after a pull-to-refresh, and the next-dose card was gone with it.
    ///
    /// This runs LAST so that a reproduction cannot cost the items that matter.
    func testA4DashboardPullToRefreshCancellationFiled() {
        goToTab("Dashboard")
        _ = app.staticTexts["Next dose"].waitForExistence(timeout: 25)
        let loadedFirst = app.staticTexts["Next dose"].exists

        // ONE pull on a settled dashboard.
        pullToRefresh()
        Thread.sleep(forTimeInterval: 4)
        let afterOnePull = firstVisibleErrorText(timeout: 2)
        let cardAfterOne = app.staticTexts["Next dose"].exists

        // Two pulls in quick succession — a user double-pulling, and the shape that
        // makes one load cancel another.
        pullToRefresh()
        pullToRefresh()
        Thread.sleep(forTimeInterval: 4)
        let afterTwoPulls = firstVisibleErrorText(timeout: 2)
        let cardAfterTwo = app.staticTexts["Next dose"].exists

        print("""

        ===== SWEEP3 FILED (not one of the four): dashboard pull-to-refresh =====
        loaded_before:            \(loadedFirst)
        after_one_pull_error:     \(afterOnePull ?? "none")
        next_dose_card_after_one: \(cardAfterOne)
        after_two_pulls_error:    \(afterTwoPulls ?? "none")
        next_dose_card_after_two: \(cardAfterTwo)
        ========================================================================

        """)
    }

    // MARK: - B1 — ITEM 1: un-log the row this session wrote

    func testB1UnlogTodaysDoseFromCalendar() throws {
        try XCTSkipUnless(!unlogLabel.isEmpty,
                          "UNLOG_LABEL not set — refusing to delete a row this session "
                          + "cannot prove it wrote.")
        print("SWEEP3-LIVENESS: unlog target = \"\(unlogLabel)\"")

        goToTab("Calendar")
        _ = todaysAgendaLabels(waitingFor: 20)

        // "Today" re-selects the current UTC day, which is the day the row was written
        // for — cheaper and more deterministic than trusting whatever the grid restored.
        let today = app.buttons["Today"]
        if today.waitForExistence(timeout: 8) && today.isHittable { today.tap() }
        Thread.sleep(forTimeInterval: 2)

        let rows = app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minX >= 0 && $0.label.contains(unlogLabel) }
        print("SWEEP3 UNLOG CANDIDATES: \(rows.count) — "
              + rows.map { "\"\($0.label)\"" }.joined(separator: " | "))

        guard let row = rows.first(where: { $0.isHittable }) else {
            print("""

            ===== SWEEP3 ITEM 1 (unlogDose) =====
            RESULT: NOT OBSERVED — no hittable agenda row matching "\(unlogLabel)".
            On screen: \(visibleTextSummary())
            =====================================

            """)
            XCTFail("No agenda row to un-log; item 1 stays NOT OBSERVED.")
            return
        }

        let tapAt = Date()
        row.tap()
        // Long enough for the DELETE, its read-back, and any failure to surface.
        Thread.sleep(forTimeInterval: 6)
        let unlogError = firstVisibleErrorText(timeout: 3)

        print("""

        ===== SWEEP3 ITEM 1 (unlogDose — the delete half) =====
        target_label:   \(unlogLabel)
        tapped_at_utc:  \(Self.iso(tapAt))
        error_surfaced: \(unlogError ?? "none")
        NOTE: the tick on this screen is NOT readable from the accessibility tree —
              it is an SF Symbol plus a colour plus a strikethrough, none of which
              reaches the label — so the DATABASE is the observer for this item:
              count before, count after, and which row went.
        ======================================================

        """)

        XCTAssertNil(unlogError, "The un-log reported a failure: \(unlogError ?? "")")
    }

    // MARK: - Entry

    private func dismissDisclaimerIfPresent() {
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
    }

    /// Signs in only when actually signed out — the session lives in the Keychain, and
    /// repeated sign-ins against real Supabase auth rate-limit into a lockout. Nothing
    /// here logs the credential; assertions are on the outcome.
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

    /// The tab bar collides by LABEL — `MainShell` builds it as
    /// `.tabItem { Label(tab.title, …) }` with no identifier — and the off-canvas drawer
    /// carries the same words. The LOWEST hittable match is the tab item.
    private func goToTab(_ title: String) {
        let tabs = app.buttons.matching(identifier: title)
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10), "No \(title) tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// Settings is NOT a tab. `RouteContent` attaches a hamburger — `NavySquareButton`
    /// with `.accessibilityLabel("Menu")` — to every root screen, and the drawer is
    /// `.accessibilityHidden(!isDrawerOpen)` so its rows only resolve once it is open.
    ///
    /// **THE DRAWER MUST BE SCROLLED.** `DrawerList` renders two primary rows, THIRTEEN
    /// calculators and then Settings, inside its own `ScrollView`. The first attempt
    /// resolved the `Settings` button fine and found it not hittable, which is the row
    /// sitting below the fold — an absence that reads exactly like "the drawer never
    /// opened" if you only check `exists`.
    private func openSettingsViaDrawer() {
        let menu = app.buttons["Menu"]
        if menu.waitForExistence(timeout: 10) && menu.isHittable { menu.tap() }
        Thread.sleep(forTimeInterval: 1.5)

        let settings = app.buttons["Settings"]
        var attempts = 0
        while !(settings.exists && settings.isHittable) && attempts < 10 {
            // The drawer's own ScrollView, not the content behind it: the drawer is
            // ~290pt wide against a 402pt screen.
            guard let drawer = app.scrollViews.allElementsBoundByIndex
                .first(where: { $0.frame.minX >= 0 && $0.frame.width < 360 && $0.isHittable })
            else { break }
            drawer.swipeUp(velocity: XCUIGestureVelocity(rawValue: 600))
            attempts += 1
        }

        if settings.exists && settings.isHittable {
            settings.tap()
        } else {
            XCTFail("Could not reach Settings in the drawer after \(attempts) scrolls. "
                    + "Buttons on screen: "
                    + app.buttons.allElementsBoundByIndex
                        .filter { $0.frame.minX >= 0 }
                        .map { "\"\(redact($0.label))\"" }.prefix(25).joined(separator: ", "))
        }
        Thread.sleep(forTimeInterval: 2.5)
    }

    /// The Tools list is a `List`, so XCUITest surfaces it as a collectionView and its
    /// rows are lazy — `waitForExistence` reports "does not exist" for a row two swipes
    /// away. Re-query inside the loop, and treat absent and off-screen as one condition.
    private func openCalculator(named name: String) {
        goToTab("Tools")
        if let list = scrollContainer() {
            for _ in 0..<8 { list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 500)) }
        }
        for _ in 0..<12 {
            if let row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first(where: { $0.isHittable }) {
                row.tap()
                _ = app.descendants(matching: .any).matching(identifier: "screen_title")
                    .firstMatch.waitForExistence(timeout: 10)
                return
            }
            guard let list = scrollContainer() else { break }
            list.swipeUp(velocity: XCUIGestureVelocity(rawValue: 600))
        }
        XCTFail("Could not reach the '\(name)' row in the Tools list.")
    }

    /// Types the marker into `field_mgWeek`, saves, and leaves by "Set this later" —
    /// which keeps the start day at the save-time default of TODAY, and that default is
    /// the whole reason the new protocol lands on today's agenda for item 6.
    @discardableResult
    private func saveProtocolWithMarkerDose() -> Bool {
        let doseField = app.textFields["field_mgWeek"]
        guard doseField.waitForExistence(timeout: 10) else {
            XCTFail("No `field_mgWeek` on \(Self.calculatorName)."); return false
        }
        doseField.tap()
        // Clear first, or the marker APPENDS — typing into a populated `mgWeek` is the
        // exact input that produced the field-shows-100250 / engine-used-1000 defect.
        if let existing = doseField.value as? String, !existing.isEmpty {
            doseField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                      count: existing.count))
        }
        doseField.typeText(markerDose)
        guard doseField.value as? String == markerDose else {
            XCTFail("The weekly-dose field holds \(doseField.value as? String ?? "nil"), "
                    + "not the marker — this would save a protocol the run does not describe.")
            return false
        }
        // `kb_done` at `.button` — the ONE narrowing this suite makes. The keyboard
        // ToolbarItemGroup publishes the identifier on BOTH the bridged bar button and
        // the hosted SwiftUI content, so `.any` provably cannot resolve to one element.
        let done = app.descendants(matching: .button).matching(identifier: "kb_done").firstMatch
        if done.exists { done.tap() }

        let addCTA = app.descendants(matching: .any).matching(identifier: "cta_add").firstMatch
        guard addCTA.waitForExistence(timeout: 10), addCTA.isEnabled else {
            XCTFail("No enabled save control on \(Self.calculatorName)."); return false
        }
        addCTA.tap()

        // The confirm-start step is the row being READ BACK by id — the save landed.
        let confirmStart = app.buttons["Confirm start day"]
        let reached = confirmStart.waitForExistence(timeout: 20)
        let setLater = app.buttons["Set this later"]
        if setLater.exists && setLater.isHittable { setLater.tap() }
        Thread.sleep(forTimeInterval: 2)
        return reached
    }

    /// A real pull-to-refresh: a SLOW drag from near the top with a hold at the end.
    /// `swipeDown()` is a flick and frequently scrolls instead of arming the control.
    private func pullToRefresh() {
        guard let scroll = scrollContainer() else {
            print("SWEEP3: no scroll container to pull on"); return
        }
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        start.press(forDuration: 0.1, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.4)
    }

    private func scrollContainer() -> XCUIElement? {
        (app.collectionViews.allElementsBoundByIndex
         + app.tables.allElementsBoundByIndex
         + app.scrollViews.allElementsBoundByIndex)
            .first { $0.isHittable && $0.frame.minX >= 0 }
    }

    // MARK: - Reading the screen

    /// The agenda rows for the selected day, by label.
    ///
    /// `AgendaRow` is a `Button` whose subtree SwiftUI merges into one element, so the
    /// protocol label and the calculator short-title arrive as one string
    /// ("TB-500 … · 350mcg/inj, Peptide"). The tab bar, the month grid's day numbers and
    /// the paging chevrons are all buttons too, so they are excluded by shape: agenda
    /// labels are long and are not bare numbers.
    private func todaysAgendaLabels(waitingFor timeout: TimeInterval) -> [String] {
        let marker = app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'SELECTED ·' OR label BEGINSWITH 'Selected ·'"))
            .firstMatch
        _ = marker.waitForExistence(timeout: timeout)
        let chrome: Set<String> = ["Dashboard", "Calendar", "Log dose", "Tools", "Add", "Menu",
                                   "Edit protocols", "Back", "Today", "Forward", "Sign out"]
        return app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minX >= 0 }
            .map(\.label)
            .filter { !$0.isEmpty && !chrome.contains($0) && Int($0) == nil && $0.count > 8 }
    }

    private func loadingTextShowing() -> Bool {
        app.staticTexts["Loading…"].exists || app.staticTexts["Loading..."].exists
    }

    /// Both renderings of "this dose is logged": the header `Label("Taken", …)` and the
    /// `Text("Logged for \(dayKey)")` that replaces the button. Reading only one would
    /// make "the tick went" and "the card re-laid out" the same observation.
    private func tickIsShowing() -> Bool {
        if app.staticTexts["Taken"].exists { return true }
        return app.staticTexts
            .containing(NSPredicate(format: "label BEGINSWITH 'Logged for'")).firstMatch.exists
    }

    private func nextDoseCardTitle() -> String? {
        guard let marker = app.staticTexts.allElementsBoundByIndex
            .first(where: { $0.label == "Next dose" }) else { return nil }
        return app.staticTexts.allElementsBoundByIndex
            .filter { $0.frame.minY > marker.frame.maxY && !$0.label.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }?
            .label
    }

    /// The first user-visible error-ish string, or nil. The needles are the app's OWN
    /// copy: `DashboardViewModel.markTaken` writes "That dose was not logged. …",
    /// `CalendarViewModel.toggleTaken` writes "That dose was not un-logged. …", and
    /// `BackendWriteError.wroteNothing` reads "Nothing was saved. …" — none of which
    /// contains "failed", "error" or any spelling of "could not". A detector that cannot
    /// fire on the one message the screen can show turns `XCTAssertNil` into a green
    /// indistinguishable from an absence.
    ///
    /// **This has NO positive control inside a passing run**, so it is corroboration and
    /// never the load-bearing observation — the database is.
    private func firstVisibleErrorText(timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        let needles = [
            "could not", "couldn't", "couldn’t", "failed", "try again", "error", "unable",
            "was not logged", "was not un-logged", "nothing was saved", "no longer available",
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

    private func visibleTextSummary() -> String {
        app.staticTexts.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
            .prefix(25)
            .map { redact($0.count > 60 ? String($0.prefix(60)) + "…" : $0) }
            .joined(separator: " | ")
    }

    // MARK: - Helpers

    /// Never print a credential or an account identifier. Settings and the drawer header
    /// both render the QA account's real email, and an `.xcresult` is a place it leaks by
    /// accident.
    private func redact(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.contains("@") ? "[REDACTED-EMAIL]" : String($0) }
            .joined(separator: " ")
    }

    private func fmt(_ t: TimeInterval) -> String {
        t < 0 ? "NOT OBSERVED" : String(format: "%.3f", t)
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}
