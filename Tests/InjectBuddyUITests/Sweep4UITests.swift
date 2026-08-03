import XCTest

/// SWEEP-4 — `BATCH.md` batch 4, all three items. Every one of them is coded, compiling
/// and NEVER OBSERVED, so nothing here asserts its way to a pass: each method prints a
/// grep-able block containing the raw values it read, and a method that could not be
/// driven prints `NOT OBSERVED`, which is the answer rather than a placeholder for one.
///
/// ## THE INSTRUMENT THIS SUITE MAY NOT USE
///
/// `DashboardViewModel.load` no longer sets `.loading` when data is already loaded, so
/// **"Loading…" does not appear after a pull on a loaded screen and its absence is not
/// evidence the refresh did not fire.** `Sweep3UITests.loadingTextShowing()` is blind
/// here by design. The observer is instead an **external database write**: the host
/// patches every active protocol's `label` while the test is parked, and the dashboard
/// card title / agenda labels changing is a re-read that happened, from outside the app
/// and outside this suite.
///
/// ## HOW THE HOST AND THE TEST MEET
///
/// A test that needs an external change prints `SWEEP4-PARK-START <marker> <iso>` and
/// then sleeps. The host watches the run log for that line, issues the PostgREST PATCH
/// as the QA user, and the test wakes up and reads. **The reading immediately before the
/// gesture is the CONTROL and is not optional**: without it, "the label changed" cannot
/// be told apart from "the label was already there".
final class Sweep4UITests: XCTestCase {

    private var app: XCUIApplication!

    /// Seconds parked while the host applies the external change. Generous on purpose —
    /// the cost of a park that is too short is an unobservable item, and the cost of one
    /// that is too long is 30 seconds.
    private var parkSeconds: TimeInterval {
        TimeInterval(ProcessInfo.processInfo.environment["PARK_SECONDS"] ?? "") ?? 90
    }

    /// How many DOUBLE pulls item 1 performs. An intermittent defect needs a stated
    /// sample, so this number is printed in the result block, never assumed.
    private var doublePullRounds: Int {
        Int(ProcessInfo.processInfo.environment["PULL_ROUNDS"] ?? "") ?? 12
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

        // LIVENESS MARKER — the one line a skipped run cannot print.
        print("SWEEP4-LIVENESS: credentials arrived, launching. \(Self.iso(Date()))")

        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()

        dismissDisclaimerIfPresent()
        signInIfNeeded(email: email, password: password)
    }

    // MARK: - C1 — ITEM 1: a cancelled load must not render as a full-screen error

    /// **CRITERION 1.** Previously, pulling to refresh the dashboard produced
    /// *"The operation couldn't be completed. (Swift.CancellationError error 1.)"* with
    /// the next-dose card gone, intermittently, and the reproducer was **two fast pulls**.
    ///
    /// PASS = previous state stays, the dose card never disappears, nothing is surfaced.
    /// FAIL = any full-screen error, or the card vanishing.
    ///
    /// ### The two probes, and which one carries the weight
    ///
    ///   • `buttons["Retry"]` — the only control on `ErrorBanner`, which is what
    ///     `DashboardScreen` renders INSTEAD of the ScrollView when `state == .failed`.
    ///     One element, unambiguous, no needle list to get wrong.
    ///   • `staticTexts["Next dose"]` — the card's own header. **This is the
    ///     load-bearing one**, because `.failed` removes the card BY CONSTRUCTION: the
    ///     `switch` has one branch on screen at a time. And it is the probe with a real
    ///     two-way control — it reads FALSE on the launch screen while `LoadingView` is
    ///     up and TRUE once loaded, both recorded below, so a green from this probe is
    ///     not a green from a probe that can only ever say yes.
    func testC1DashboardDoublePullDoesNotSurfaceCancellation() {
        // POSITIVE CONTROL for the card probe, taken before anything else: on a cold
        // launch the dashboard is `.loading`, so the marker must be ABSENT and then
        // become present. A probe that has never been seen going both ways is not an
        // instrument.
        let cardBeforeLoad = app.staticTexts["Next dose"].exists
        let cardAppeared = app.staticTexts["Next dose"].waitForExistence(timeout: 30)
        let retryAtStart = app.buttons["Retry"].exists

        guard cardAppeared else {
            print("""

            ===== SWEEP4 ITEM 1 =====
            RESULT: NOT OBSERVED — no next-dose card within 30s of launch, so there was
                    nothing to watch disappear. visible: \(visibleTextSummary())
            =========================

            """)
            XCTFail("No next-dose card to observe; item 1 stays NOT OBSERVED.")
            return
        }

        let baselineTitle = nextDoseCardTitle() ?? "<none>"

        // ── The external observer. Parked, nothing tapped, no pull. ────────────────
        print("SWEEP4-PARK-START C1 \(Self.iso(Date()))")
        Thread.sleep(forTimeInterval: parkSeconds)

        // CONTROL: the label changed in the database while this screen sat still. If the
        // card already shows it, no pull is being measured and the run says so.
        let controlTitle = nextDoseCardTitle() ?? "<none>"

        // ── Round 0: the pull that proves a pull re-reads at all. ──────────────────
        doublePull(round: 0)
        var titleAfterFirstPull = controlTitle
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            let t = nextDoseCardTitle() ?? "<none>"
            if t != controlTitle { titleAfterFirstPull = t; break }
            titleAfterFirstPull = t
        }
        let refreshProven = titleAfterFirstPull != controlTitle

        // ── The sample. Each round is TWO pulls back to back; the shape is varied so
        //    the sample is not twelve repetitions of one timing that may never race. ──
        var samples = 0
        var cardMissingSamples = 0
        var retrySamples = 0
        var errorTexts: [String] = []
        var worstRound = "none"

        for round in 1...doublePullRounds {
            doublePull(round: round)

            // Watch for ~5s after each double pull. `.exists` on a single addressed
            // element is the cheapest query there is, which is what makes a sample
            // dense enough to catch a state that lasts under a second.
            let watchUntil = Date().addingTimeInterval(5)
            repeat {
                samples += 1
                if !app.staticTexts["Next dose"].exists {
                    cardMissingSamples += 1
                    if worstRound == "none" { worstRound = "round \(round) — card gone" }
                }
                if app.buttons["Retry"].exists {
                    retrySamples += 1
                    if worstRound == "none" { worstRound = "round \(round) — ErrorBanner" }
                }
            } while Date() < watchUntil

            // Corroboration only, and it has no positive control inside a passing run:
            // the DATABASE-backed title change above is the load-bearing observation.
            if let text = visibleErrorText() { errorTexts.append("round \(round): \(text)") }
        }

        let finalTitle = nextDoseCardTitle() ?? "<none>"
        let cardAtEnd = app.staticTexts["Next dose"].exists
        let retryAtEnd = app.buttons["Retry"].exists

        let verdict: String
        if cardMissingSamples > 0 || retrySamples > 0 || !errorTexts.isEmpty {
            verdict = "FAIL — the defect reproduced"
        } else if !refreshProven {
            verdict = "NOT OBSERVED — no pull was proven to have driven a re-read, so a clean "
                    + "screen cannot be told apart from a gesture that did nothing"
        } else {
            verdict = "PASS — \(doublePullRounds) double pulls, refresh proven by an external "
                    + "database change, no error surfaced, card present in every sample"
        }

        print("""

        ===== SWEEP4 ITEM 1 (cancelled load must not render as a full-screen error) =====
        verdict: \(verdict)

        PROBE CONTROL (card marker, both ways)
          card_present_before_load: \(cardBeforeLoad)      <- expected FALSE (LoadingView)
          card_present_after_load:  \(cardAppeared)        <- expected TRUE
          retry_button_at_start:    \(retryAtStart)

        REFRESH REALLY FIRED? (external database write, not "Loading…")
          baseline_card_title: \(redact(baselineTitle))
          control_card_title:  \(redact(controlTitle))     <- read after the park, BEFORE any pull
          after_first_pull:    \(redact(titleAfterFirstPull))
          refresh_proven:      \(refreshProven)

        THE SAMPLE
          double_pull_rounds:   \(doublePullRounds)
          total_screen_samples: \(samples)
          samples_card_missing: \(cardMissingSamples)
          samples_retry_shown:  \(retrySamples)
          error_texts_seen:     \(errorTexts.isEmpty ? "none" : errorTexts.joined(separator: " || "))
          first_bad_round:      \(worstRound)

        AT THE END
          card_present: \(cardAtEnd)   retry_present: \(retryAtEnd)
          final_card_title: \(redact(finalTitle))
        ================================================================================

        """)

        XCTAssertEqual(cardMissingSamples, 0, "The next-dose card disappeared during a refresh.")
        XCTAssertEqual(retrySamples, 0, "A full-screen ErrorBanner was rendered during a refresh.")
        XCTAssertTrue(errorTexts.isEmpty, "Error copy was surfaced: \(errorTexts.joined(separator: " || "))")
    }

    // MARK: - C2 — ITEM 2: the Calendar pull is gone, and `.task` still re-reads

    /// Two separate questions, and they are not the same question:
    ///
    ///   (a) **Is there no pull-to-refresh on the Calendar?** Absence is the hard half.
    ///       The Dashboard is the POSITIVE CONTROL — it still has `.refreshable` — so the
    ///       element hierarchies of the two screens are dumped and the refresh control is
    ///       counted on each. A method that finds nothing on both screens has found
    ///       nothing about the Calendar; it has to find it on the Dashboard first.
    ///   (b) **Does `.task` still re-read on tab re-appearance?** Same external-write
    ///       observer as C1: park on the Calendar, host patches the labels, read WITHOUT
    ///       leaving (the control), leave to the Dashboard and come back, read again.
    func testC2CalendarHasNoPullAndTaskStillRereads() {
        // ── (a) the affordance ────────────────────────────────────────────────────
        _ = app.staticTexts["Next dose"].waitForExistence(timeout: 30)
        let dashboardRefreshHits = refreshControlHits(screen: "dashboard")

        // TWO-WAY CONTROL FOR C1'S CARD PROBE, taken here because C1 could not take it:
        // C1 relaunched onto an already-warm dashboard, so `staticTexts["Next dose"]`
        // was TRUE on its very first read and that run never saw the probe say FALSE.
        // A probe only ever observed returning one value is not an instrument. Same
        // query, same build, same session — TRUE on the Dashboard, FALSE on the
        // Calendar, which is a screen that genuinely has no next-dose card.
        let cardProbeOnDashboard = app.staticTexts["Next dose"].exists

        goToTab("Calendar")
        _ = todaysAgendaLabels(waitingFor: 25)
        let cardProbeOnCalendar = app.staticTexts["Next dose"].exists
        let calendarRefreshHits = refreshControlHits(screen: "calendar")

        // A pull is also performed on the Calendar and the screen watched: if the
        // affordance were still there it would spin, and if the removal broke the screen
        // the agenda would go.
        let agendaBeforeGesture = todaysAgendaLabels(waitingFor: 5)
        pull(hold: 0.4, velocity: .slow)
        Thread.sleep(forTimeInterval: 3)
        let agendaAfterGesture = todaysAgendaLabels(waitingFor: 5)
        let errorAfterGesture = visibleErrorText() ?? "none"

        // ── (b) `.task` on tab re-appearance ──────────────────────────────────────
        let baselineAgenda = todaysAgendaLabels(waitingFor: 20)

        print("SWEEP4-PARK-START C2 \(Self.iso(Date()))")
        Thread.sleep(forTimeInterval: parkSeconds)

        // CONTROL: still parked on the Calendar, nothing tapped, no tab switch.
        let agendaParked = todaysAgendaLabels(waitingFor: 5)

        goToTab("Dashboard")
        Thread.sleep(forTimeInterval: 2)
        goToTab("Calendar")
        let agendaAfterReturn = todaysAgendaLabels(waitingFor: 25)

        let changedWithoutReturning = Set(agendaParked) != Set(baselineAgenda)
        let changedAfterReturning = Set(agendaAfterReturn) != Set(agendaParked)

        let taskVerdict: String
        if changedWithoutReturning {
            taskVerdict = "NOT OBSERVED BY THIS METHOD — the agenda changed while parked, so a "
                        + "re-read on re-appearance cannot be separated from whatever did that"
        } else if changedAfterReturning {
            taskVerdict = "OBSERVED — the agenda picked up an external change ONLY after leaving "
                        + "the tab and coming back; `.task` re-read"
        } else {
            taskVerdict = "NOT OBSERVED — the agenda did not change after re-appearance"
        }

        print("""

        ===== SWEEP4 ITEM 2 (Calendar `.refreshable` removed; `.task` survives) =====
        (0) TWO-WAY CONTROL for the card probe C1 leaned on
          card_probe_on_dashboard: \(cardProbeOnDashboard)   <- expected TRUE
          card_probe_on_calendar:  \(cardProbeOnCalendar)    <- expected FALSE

        (a) THE AFFORDANCE — dashboard is the positive control, it still has one
          dashboard_refresh_control_hits: \(dashboardRefreshHits.count)
            \(dashboardRefreshHits.isEmpty ? "<none>" : dashboardRefreshHits.joined(separator: "\n    "))
          calendar_refresh_control_hits:  \(calendarRefreshHits.count)
            \(calendarRefreshHits.isEmpty ? "<none>" : calendarRefreshHits.joined(separator: "\n    "))

          pull gesture performed on the Calendar anyway:
            agenda_before(\(agendaBeforeGesture.count)): \(redact(agendaBeforeGesture.joined(separator: " | ")))
            agenda_after(\(agendaAfterGesture.count)):  \(redact(agendaAfterGesture.joined(separator: " | ")))
            error_after_gesture: \(redact(errorAfterGesture))

        (b) `.task` ON TAB RE-APPEARANCE — external database write as the observer
          verdict: \(taskVerdict)
          baseline_agenda(\(baselineAgenda.count)):      \(redact(baselineAgenda.joined(separator: " | ")))
          parked_agenda(\(agendaParked.count)):        \(redact(agendaParked.joined(separator: " | ")))   <- CONTROL, no tab switch
          after_return_agenda(\(agendaAfterReturn.count)):  \(redact(agendaAfterReturn.joined(separator: " | ")))
        =============================================================================

        """)

        XCTAssertFalse(agendaAfterGesture.isEmpty,
                       "The Calendar agenda emptied after a pull gesture — removal broke the screen.")
    }

    // MARK: - C3 — ITEM 3: the taken-tick is in the accessibility tree

    /// PASS = this run reads taken-vs-untaken from `XCUIElement.value` **without
    /// querying the database**, BOTH ways. So the row it flips is one it writes itself:
    /// an UNTAKEN row is found, its value read, tapped to LOG (never to un-log — nothing
    /// this session did not write is touched), and the value read again.
    func testC3AgendaRowExposesTakenState() {
        goToTab("Calendar")
        _ = todaysAgendaLabels(waitingFor: 25)

        var rows = agendaRowsWithValue()
        if rows.isEmpty {
            // Today may have no occurrence. Walk the month for a day that does.
            for _ in 0..<8 {
                guard let day = app.buttons.allElementsBoundByIndex.first(where: {
                    $0.isHittable && $0.frame.minX >= 0 && Int($0.label) != nil
                }) else { break }
                day.tap()
                Thread.sleep(forTimeInterval: 1.2)
                rows = agendaRowsWithValue()
                if !rows.isEmpty { break }
            }
        }

        guard !rows.isEmpty else {
            print("""

            ===== SWEEP4 ITEM 3 (AgendaRow accessibilityValue) =====
            RESULT: NOT OBSERVED — no agenda row carried a value of Taken / Not taken /
                    Saving. Buttons on screen: \(redact(buttonSummary()))
            =======================================================

            """)
            XCTFail("No agenda row exposed an accessibility value; item 3 stays NOT OBSERVED.")
            return
        }

        let beforeAll = rows.map { "\(redact($0.0)) = \"\($0.1)\"" }
        let untakenLabel = rows.first(where: { $0.1 == "Not taken" })?.0
        let takenLabel = rows.first(where: { $0.1 == "Taken" })?.0

        var readNotTaken: String?
        var readTakenAfterOwnWrite: String?
        var flippedLabel = "<none>"
        var writeError = "none"

        if let target = untakenLabel {
            flippedLabel = target
            readNotTaken = value(ofRowLabelled: target)

            guard let button = agendaButton(labelled: target) else {
                XCTFail("Lost the row \"\(redact(target))\" between reading and tapping."); return
            }
            button.tap()

            // Poll the VALUE, not the database. `Saving` in between is itself part of
            // what this item claims, so it is recorded if it is caught.
            var sawSaving = false
            let deadline = Date().addingTimeInterval(25)
            while Date() < deadline {
                let v = value(ofRowLabelled: target)
                if v == "Saving" { sawSaving = true }
                if v == "Taken" { readTakenAfterOwnWrite = "Taken"; break }
                readTakenAfterOwnWrite = v
            }
            if sawSaving { writeError = "none (transient \"Saving\" was caught)" }
            if let e = visibleErrorText() { writeError = e }
        }

        // A pre-existing taken row is corroboration for the "Taken" string only; it is
        // NOT the observation, because this session did not write it and must not touch
        // it. The read above, on a row this run logged itself, is the observation.
        let corroboratingTaken = takenLabel.map { "\(redact($0)) = \"Taken\" (pre-existing, NOT touched)" }
            ?? "<no pre-existing taken row on this day>"

        let afterAll = agendaRowsWithValue().map { "\(redact($0.0)) = \"\($0.1)\"" }

        let bothWays = readNotTaken == "Not taken" && readTakenAfterOwnWrite == "Taken"
        let verdict = bothWays
            ? "PASS — read \"Not taken\" and then \"Taken\" off XCUIElement.value on a row this run logged, with no database query"
            : "NOT OBSERVED — did not read both strings off the accessibility tree "
              + "(not_taken=\(readNotTaken ?? "nil"), taken=\(readTakenAfterOwnWrite ?? "nil"))"

        print("""

        ===== SWEEP4 ITEM 3 (AgendaRow accessibilityValue) =====
        verdict: \(verdict)

        rows_before(\(beforeAll.count)):
          \(beforeAll.joined(separator: "\n  "))

        the row this run flipped: \(redact(flippedLabel))
          value_before_tap: \(readNotTaken ?? "<not read>")
          value_after_tap:  \(readTakenAfterOwnWrite ?? "<not read>")
          write_error:      \(redact(writeError))

        corroboration: \(corroboratingTaken)

        rows_after(\(afterAll.count)):
          \(afterAll.joined(separator: "\n  "))

        NOTE FOR THE HOST: the flipped row is a dose_log row THIS RUN WROTE. Nothing
        pre-existing was un-logged.
        =======================================================

        """)

        XCTAssertEqual(readNotTaken, "Not taken", "Could not read \"Not taken\" from XCUIElement.value.")
        XCTAssertEqual(readTakenAfterOwnWrite, "Taken", "Could not read \"Taken\" from XCUIElement.value.")
    }

    // MARK: - C4 — ITEM 2 (a), measured on the framebuffer instead of the tree

    /// **WHY THIS EXISTS: `testC2`'s affordance probe failed its own positive control.**
    /// It searched the element tree for anything naming a refresh control and found
    /// exactly zero on the Calendar — and zero on the DASHBOARD, which demonstrably still
    /// has `.refreshable` and re-read on a pull in `testC1`. A probe that reads the same
    /// on a screen that has the thing and a screen that does not is not measuring the
    /// thing. SwiftUI's refresh control simply is not in the accessibility tree.
    ///
    /// So the instrument moves to the one this rig has and Windows does not: **the
    /// framebuffer.** The pull is held at the bottom of the drag for a long beat, and the
    /// host screenshots the device during the hold. A screen with `.refreshable` renders a
    /// spinner in the gap it opens; a screen without one renders an empty rubber band.
    ///
    /// **THE DASHBOARD IS SHOT FIRST AND IS NOT OPTIONAL** — it is what makes an empty
    /// Calendar gap mean "no affordance" rather than "the screenshots missed the window".
    /// The first attempt is why that sentence is here: the host's first
    /// `simctl io screenshot` of a session took **9.0s**, every Dashboard frame landed
    /// after the gesture had settled, and ten byte-identical Calendar frames looked like
    /// a result while proving nothing. The hold is 12s rather than 5s for the same
    /// reason — the window has to be wider than the instrument's jitter.
    func testC4PullHeldOnBothScreensForTheFramebuffer() {
        _ = app.staticTexts["Next dose"].waitForExistence(timeout: 30)

        // Resolve the scroll container BEFORE the marker: that query cost ~1s on the
        // first attempt and it sat between the marker and the press, so the host started
        // shooting a second early and the frames drifted out of the gesture.
        _ = scrollContainer()

        // POSITIVE CONTROL FIRST.
        print("SWEEP4-SHOOT dashboard \(Self.iso(Date()))")
        pull(hold: 12.0, velocity: .slow)
        Thread.sleep(forTimeInterval: 3)

        goToTab("Calendar")
        _ = todaysAgendaLabels(waitingFor: 25)
        print("SWEEP4-SHOOT calendar \(Self.iso(Date()))")
        pull(hold: 12.0, velocity: .slow)
        Thread.sleep(forTimeInterval: 3)

        let agendaAfter = todaysAgendaLabels(waitingFor: 10)

        print("""

        ===== SWEEP4 ITEM 2 (a) — pull held, framebuffer =====
        Two markers were printed, `SWEEP4-SHOOT dashboard` and `SWEEP4-SHOOT calendar`,
        each immediately before a drag of ~2.7s followed by a 5.0s hold. The frames the
        host captured in those windows are the measurement; this block only records that
        the windows happened and that the screens survived.
        agenda_after_calendar_pull(\(agendaAfter.count)): \(redact(agendaAfter.joined(separator: " | ")))
        =====================================================

        """)

        XCTAssertFalse(agendaAfter.isEmpty, "The Calendar agenda emptied after a held pull.")
    }

    // MARK: - Gestures

    /// TWO pulls back to back — the reproducer for item 1. The shape is varied by round
    /// because a single timing that never actually overlaps two loads would produce a
    /// clean run that proves nothing about a race.
    private func doublePull(round: Int) {
        switch round % 3 {
        case 0:
            pull(hold: 0.4, velocity: .slow)
            pull(hold: 0.4, velocity: .slow)
        case 1:
            pull(hold: 0.05, velocity: .fast)
            pull(hold: 0.05, velocity: .fast)
        default:
            pull(hold: 0.4, velocity: .slow)
            pull(hold: 0.05, velocity: .fast)
        }
    }

    /// A real pull-to-refresh: a drag from near the top with a hold at the end.
    /// `swipeDown()` is a flick and frequently scrolls instead of arming the control.
    private func pull(hold: TimeInterval, velocity: XCUIGestureVelocity) {
        guard let scroll = scrollContainer() else {
            print("SWEEP4: no scroll container to pull on"); return
        }
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: velocity, thenHoldForDuration: hold)
    }

    private func scrollContainer() -> XCUIElement? {
        (app.collectionViews.allElementsBoundByIndex
         + app.tables.allElementsBoundByIndex
         + app.scrollViews.allElementsBoundByIndex)
            .first { $0.isHittable && $0.frame.minX >= 0 }
    }

    // MARK: - Reading the screen

    /// Every element in the tree whose type, identifier or label names a refresh control,
    /// with the screen's total element count so an empty result can be told apart from an
    /// empty tree. Printed for BOTH screens — the Dashboard's hits are what make the
    /// Calendar's absence mean anything.
    private func refreshControlHits(screen: String) -> [String] {
        let dump = app.debugDescription
        let lines = dump.split(separator: "\n").map(String.init)
        var hits = lines.filter { $0.range(of: "refresh", options: .caseInsensitive) != nil }
            .map { redact($0.trimmingCharacters(in: .whitespaces)) }
        hits.append("(tree lines on \(screen): \(lines.count); activityIndicators: \(app.activityIndicators.count))")
        return hits
    }

    /// The agenda rows for the selected day, as (label, value). `AgendaRow` is a `Button`
    /// whose subtree SwiftUI merges into one element, so the protocol label and the
    /// calculator short-title arrive as one string. The VALUE is what item 3 added, and a
    /// row is identified here BY having one — the tab bar, the month grid's day numbers
    /// and the paging chevrons are buttons too and carry no such value.
    private func agendaRowsWithValue() -> [(String, String)] {
        let wanted: Set<String> = ["Taken", "Not taken", "Saving"]
        return app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minX >= 0 }
            .compactMap { element in
                guard let v = element.value as? String, wanted.contains(v) else { return nil }
                return (element.label, v)
            }
    }

    private func agendaButton(labelled label: String) -> XCUIElement? {
        app.buttons.allElementsBoundByIndex
            .first { $0.frame.minX >= 0 && $0.label == label && $0.isHittable }
    }

    private func value(ofRowLabelled label: String) -> String? {
        agendaButton(labelled: label)?.value as? String
    }

    /// The agenda rows for the selected day, by label. Shape-filtered the same way
    /// `Sweep3UITests` does it, so the two runs' numbers are comparable.
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

    private func nextDoseCardTitle() -> String? {
        guard let marker = app.staticTexts.allElementsBoundByIndex
            .first(where: { $0.label == "Next dose" }) else { return nil }
        return app.staticTexts.allElementsBoundByIndex
            .filter { $0.frame.minY > marker.frame.maxY && !$0.label.isEmpty }
            .min { $0.frame.minY < $1.frame.minY }?
            .label
    }

    /// The first user-visible error-ish string, or nil. The needles include the exact
    /// words of the defect being looked for — `error.localizedDescription` for a
    /// `CancellationError` reads "The operation couldn't be completed. (Swift.Cancellation
    /// Error error 1.)" — plus the app's own copy, none of which contains "error".
    ///
    /// **No positive control inside a passing run**, so this is corroboration and never
    /// the load-bearing observation; the card marker and the external write are.
    private func visibleErrorText() -> String? {
        let needles = [
            "cancellationerror", "operation couldn", "could not", "couldn't", "couldn’t",
            "failed", "try again", "unable", "was not logged", "was not un-logged",
            "nothing was saved", "no longer available",
        ]
        for text in app.staticTexts.allElementsBoundByIndex where text.exists {
            let lower = text.label.lowercased()
            if needles.contains(where: { lower.contains($0) }) { return text.label }
        }
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

    private func buttonSummary() -> String {
        app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minX >= 0 && !$0.label.isEmpty }
            .prefix(25)
            .map { "\"\(redact($0.label))\"=\(($0.value as? String) ?? "nil")" }
            .joined(separator: ", ")
    }

    // MARK: - Entry

    private func dismissDisclaimerIfPresent() {
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
    }

    /// Signs in only when actually signed out — the session lives in the Keychain, and
    /// repeated sign-ins against real Supabase auth rate-limit into a lockout.
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

    /// The tab bar collides by LABEL and the off-canvas drawer carries the same words.
    /// The LOWEST hittable match is the tab item.
    private func goToTab(_ title: String) {
        let tabs = app.buttons.matching(identifier: title)
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10), "No \(title) tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()
        Thread.sleep(forTimeInterval: 1.5)
    }

    // MARK: - Helpers

    /// Never print a credential or an account identifier. An `.xcresult` is a place one
    /// leaks by accident, and this suite prints whole element-tree lines.
    private func redact(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.contains("@") ? "[REDACTED-EMAIL]" : String($0) }
            .joined(separator: " ")
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}
