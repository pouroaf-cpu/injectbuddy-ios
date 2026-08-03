import XCTest

/// H6 on the running app — the half `CalculatorLinkWithdrawalTests` cannot see.
///
/// **WHY THIS FILE EXISTS, and it is a correction rather than an addition.** The unit
/// test asserts the MODEL that the browse surfaces read. Three of its four surfaces are
/// real model expressions the app genuinely enumerates — `CalculatorCategory.members`
/// (Tools), `savableMembers` (the Add funnel) and `NavItems.calculators` (the drawer).
/// **The fourth is circular.** `DashboardScreen`'s dialog builds its `ForEach` inline, so
/// there is no named expression to read, and the unit test names the filter itself as the
/// surface — which asks the filter whether the filter ran.
///
/// That was not a theory. The dashboard was pointed back at `CalculatorSlug.allCases` —
/// the exact defect H6 fixes, and the exact break the unit file claimed to have been
/// falsified against — and **all seven of its tests stayed green.** So the dashboard
/// dialog is covered here, against the screen, or it is not covered.
///
/// **EVERY ASSERTION HERE IS AN ABSENCE, WHICH IS THE DANGEROUS KIND.** A surface that
/// failed to load, a tab that never opened, a dialog that never appeared — all of them
/// contain no `BMI` too, and all of them would report success. So every check carries a
/// POSITIVE CONTROL in the same pass: a calculator that MUST be present is asserted
/// first, on the same query, against the same tree. Without it this file would go green
/// on a crashed app (§5.36, D4).
final class CalculatorLinkWithdrawalUITests: XCTestCase {

    /// Withdrawn by H6. Owner's words: *"leave them alone, and don't let the links to it
    /// go anywhere, we will work on later."*
    private static let withdrawn = ["BMI", "Free T Index"]

    /// The positive control. `TRT Dose` is on every browse surface, is the most-used
    /// calculator in production, and is not withdrawn — so if a surface renders at all,
    /// this is on it.
    private static let mustBePresent = "TRT Dose"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        addUIInterruptionMonitor(withDescription: "system prompts") { alert in
            for label in ["Allow While Using App", "Don’t Allow", "Don't Allow", "Continue", "OK"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }

        app = XCUIApplication()

        // A machine without credentials SKIPS rather than fails — a red test for a
        // missing secret trains people to ignore red tests.
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "QA_EMAIL / QA_PASSWORD not set — skipping signed-in UI tests.")

        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()

        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
        signInIfNeeded(email: email, password: password)
    }

    private func signInIfNeeded(email: String, password: String) {
        let field = app.textFields.firstMatch
        guard field.waitForExistence(timeout: 6) else { return }   // already signed in
        field.tap(); field.typeText(email)
        let secure = app.secureTextFields.firstMatch
        if secure.exists { secure.tap(); secure.typeText(password) }
        // Never print, assert on, or attach either value. §credentials in CLAUDE.md.
        let signIn = app.buttons.matching(identifier: "Sign in").firstMatch
        if signIn.exists { signIn.tap() }
        _ = app.buttons["Tools"].waitForExistence(timeout: 20)
    }

    // MARK: - Reading a surface

    /// Every label visible on screen right now, from the element types a row can be.
    private func labelsOnScreen() -> Set<String> {
        var out: Set<String> = []
        for element in app.staticTexts.allElementsBoundByIndex
            + app.buttons.allElementsBoundByIndex {
            // Off-canvas elements are in the tree at negative x — the drawer sits there
            // and carries the same labels. Reading them would report the drawer's
            // contents as the visible screen's.
            guard element.frame.minX >= 0, element.exists else { continue }
            let label = element.label.isEmpty ? element.identifier : element.label
            if !label.isEmpty { out.insert(label) }
        }
        return out
    }

    /// Scrolls a surface end to end, accumulating what it offers.
    ///
    /// Accumulates rather than snapshots because the Tools list is LAZY: a row two
    /// swipes down does not exist in the tree yet, so a single read of the top of the
    /// list finds no `BMI` on a build where `BMI` is present and simply below the fold.
    /// That is the false pass this whole file is guarding against.
    private func scrollAndCollect(maxSwipes: Int = 12) -> Set<String> {
        var seen = labelsOnScreen()
        guard let list = (app.collectionViews.allElementsBoundByIndex
                          + app.tables.allElementsBoundByIndex
                          + app.scrollViews.allElementsBoundByIndex)
            .first(where: { $0.isHittable && $0.frame.minX >= 0 }) else { return seen }

        var unchanged = 0
        for _ in 0..<maxSwipes {
            let before = seen.count
            list.swipeUp()
            seen.formUnion(labelsOnScreen())
            unchanged = seen.count == before ? unchanged + 1 : 0
            if unchanged >= 2 { break }        // bottom reached, twice over
        }
        return seen
    }

    private func openToolsRoot() {
        let back = app.navigationBars.buttons.matching(identifier: "Tools").firstMatch
        if back.exists && back.isHittable { back.tap() }

        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10), "No Tools tab.")
        // The LOWEST hittable match is the tab item; the Tools list itself carries a row
        // with the same label once the drawer is in the tree (§5.38).
        tabs.allElementsBoundByIndex.filter(\.isHittable)
            .max { $0.frame.midY < $1.frame.midY }?.tap()
    }

    // MARK: - The assertions

    /// The browse tab. Reads `CalculatorCategory.members`, which the unit test also
    /// covers — so this is the photograph half: it fails if the SCREEN stops reading the
    /// model, which no unit test can observe.
    func testToolsListDoesNotOfferAWithdrawnCalculator() {
        openToolsRoot()
        let offered = scrollAndCollect()

        // POSITIVE CONTROL FIRST. Everything below is an absence, and an empty screen
        // satisfies every absence there is.
        XCTAssertTrue(offered.contains(Self.mustBePresent),
                      "Tools does not list `\(Self.mustBePresent)`, so this run never read "
                      + "the Tools list and every absence below it means nothing. Saw "
                      + "\(offered.count) labels: \(offered.sorted().prefix(25).joined(separator: ", "))")

        for name in Self.withdrawn {
            XCTAssertFalse(offered.contains(name),
                           "Tools still offers `\(name)`. H6 REMOVES the row — it does not "
                           + "disable it — because a row that renders and goes nowhere is "
                           + "the chevron defect already on the board.")
        }
    }

    /// The dashboard's `Add a protocol` dialog — **the surface the unit test cannot see.**
    ///
    /// Its `ForEach` is inline in the view, so there is no model expression to assert
    /// against; the unit test names `CalculatorSlug.listedCases` as the surface, which is
    /// the filter under test. Pointing this dialog back at `allCases` leaves that file
    /// entirely green. This is the only check that goes red on it.
    func testAddProtocolDialogDoesNotOfferAWithdrawnCalculator() {
        // Dashboard is the first tab; get there without assuming where the run started.
        let dashboard = app.buttons.matching(identifier: "Dashboard")
        if dashboard.firstMatch.waitForExistence(timeout: 10) {
            dashboard.allElementsBoundByIndex.filter(\.isHittable)
                .max { $0.frame.midY < $1.frame.midY }?.tap()
        }

        // BY IDENTIFIER AND COUNTED, never by the label. The control reads `Add`, and so
        // does the tab bar's middle slot — resolving this by text is the §5.38 defect
        // that spent a week measuring the tab bar. The dashboard renders one of two
        // entry points depending on whether the account has protocols, so both are named
        // and exactly one must resolve.
        let byIdentifier = app.buttons.matching(identifier: "cta_add_protocol")
        let emptyState = app.buttons.matching(identifier: "Add your first protocol")
        _ = byIdentifier.firstMatch.waitForExistence(timeout: 10)
        _ = emptyState.firstMatch.waitForExistence(timeout: 2)

        let candidates = byIdentifier.allElementsBoundByIndex + emptyState.allElementsBoundByIndex
        let hittable = candidates.filter { $0.isHittable && $0.frame.minX >= 0 }
        XCTAssertEqual(hittable.count, 1,
                       "Expected exactly ONE way into the Add-a-protocol dialog and found "
                       + "\(hittable.count). Zero means the dashboard never loaded and every "
                       + "absence below is meaningless; more than one means the query is "
                       + "ambiguous and cannot tell you which control it opened (§5.38).")
        hittable.first?.tap()

        // The dialog is a confirmationDialog. **IT SCROLLS**, and that was found the hard
        // way: thirteen calculators plus Cancel do not fit an iPhone 16 Pro, so a single
        // read of it returns the top of the sheet. The first version of this test read it
        // once and passed — with both withdrawn calculators absent because they were
        // BELOW THE FOLD on a build where they might equally have been present. The
        // positive control caught nothing, because `TRT Dose` is near the top.
        //
        // An absence assertion is only as good as the completeness of the read (§5.36).
        XCTAssertTrue(app.buttons[Self.mustBePresent].waitForExistence(timeout: 8),
                      "The dialog did not offer `\(Self.mustBePresent)` — it either never "
                      + "opened or opened empty, and an empty dialog contains no withdrawn "
                      + "calculator either.")

        // SCOPED TO THE SHEET, not to the app. The first version swiped the first
        // hittable scroll view in the tree — which is the DASHBOARD behind the dialog.
        // It came back with `Mark taken`, `Edit protocols` and the account's protocol
        // names in the "dialog contents", i.e. it was reading the wrong surface while
        // reporting on this one. That is §5.38 in a different costume: the query was
        // ambiguous and answered a question nobody asked.
        let sheet = app.sheets.firstMatch.exists ? app.sheets.firstMatch : app.alerts.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 8),
                      "No sheet or alert on screen after tapping the add control — the "
                      + "dialog never opened, and an unopened dialog offers no withdrawn "
                      + "calculator either.")

        func readSheet() -> Set<String> {
            Set(sheet.buttons.allElementsBoundByIndex
                .filter { $0.frame.minX >= 0 }
                .map(\.label)
                .filter { !$0.isEmpty })
        }

        var offered = readSheet()
        var unchanged = 0
        for _ in 0..<10 {
            let before = offered.count
            sheet.swipeUp()
            offered.formUnion(readSheet())
            unchanged = offered.count == before ? unchanged + 1 : 0
            if unchanged >= 2 { break }
        }

        // COMPLETENESS, not a feature assertion. `Cycle Plotter` is last in canonical
        // order, so reading it is the proof the whole sheet was seen — without which
        // every absence below is a statement about the top of a list. It doubles as the
        // guard against broadening the withdrawal to `!canSaveProtocol`, which would
        // sweep the plotter in.
        XCTAssertTrue(offered.contains("Cycle Plotter"),
                      "Never reached the bottom of the dialog — `Cycle Plotter` is last and "
                      + "was not read, so the absences below describe a partial sheet. "
                      + "Saw \(offered.count): \(offered.sorted().joined(separator: ", "))")

        for name in Self.withdrawn {
            XCTAssertFalse(offered.contains(name),
                           "The `Add a protocol` dialog still offers `\(name)`. This is the "
                           + "surface that enumerates `CalculatorSlug` inline, so the unit "
                           + "suite stays green while this is broken.")
        }

        // Cycle Plotter cannot save either and is DELIBERATELY still here — it is the
        // plotter's only route into the app and six of the twelve queued items build on
        // it. The assertion for it is the completeness check above: it doubles as the
        // proof the whole sheet was read AND as the guard against a later broadening of
        // the withdrawal to `!canSaveProtocol`, which would sweep it in.

        app.buttons["Cancel"].tap()
    }
}
