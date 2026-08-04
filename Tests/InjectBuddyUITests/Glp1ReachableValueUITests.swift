import XCTest

/// ─── Glp1ReachableValueUITests  (T-45) ───────────────────────────────────────
///
/// The one thing a unit test cannot answer about T-45: **can a user actually reach a
/// concentration that was not on the old list, on the real app, with the keyboard.**
///
/// `Glp1OptionParityTests` proves the arrays are whole, the warnings fire and the
/// field's model carries a range. All of that would still be true if the screen
/// rendered a control that refused typing — the defect being fixed here is precisely
/// a control whose model looked reasonable (an option array, correct as far as it
/// went) while the rendered thing was a closed `Menu` with no way in. So this suite
/// types into the shipped screen and reads the dose back off the result card.
///
/// **25 mg/mL is the case.** The old ladder stopped at 20, so a 25 mg/mL compounded
/// vial had no correct option; picking the nearest returned a draw 25 % larger than
/// the true one. Here the number goes in through the keyboard and the card must read
/// **0.020 mL / 2 u**, not 0.025 mL / 3 u.
///
/// **ARRIVAL IS ASSERTED BEFORE EVERY SCREENSHOT**, and the frames are self-verifying
/// besides: the Semaglutide screen renders its own name, so a mistimed capture is
/// visibly wrong rather than quietly wrong. Both, because repetition-detection cannot
/// detect wrongness — see the long note in `CaptureCurrentState`.
final class Glp1ReachableValueUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        // Skipped, never failed, when the secret is absent — a red test for a missing
        // credential trains people to ignore red tests. NOTE the host must set
        // `TEST_RUNNER_QA_EMAIL`: `xcodebuild` strips the prefix, and without it this
        // suite SKIPS and exits 0, which shares an exit code with a pass.
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "TEST_RUNNER_QA_EMAIL / TEST_RUNNER_QA_PASSWORD not set.")

        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this suite needs the signed-in app.")
    }

    /// The headline: a value that had no representation in the app before T-45.
    func testTwentyFiveMgPerMlCanBeTypedAndProducesTheCorrectDraw() throws {
        try openCalculator("Semaglutide")

        setNumber("conc", to: "25")
        setNumber("dose", to: "0.5")

        // Read the RESULT, not the field. The field showing 25 proves the keyboard
        // worked; the card showing 0.020 proves the engine was handed 25.
        let draw = resultValue("Draw")
        let units = resultValue("Units (U-100)")
        XCTAssertEqual(draw, "0.020 mL",
                       "conc 25 / dose 0.5 must draw 0.020 mL. 0.025 mL is the old "
                       + "20 mg/mL answer — 25 % over — which means the typed value "
                       + "did not reach the engine.")
        XCTAssertEqual(units, "2", "Expected 2 units, got \(units ?? "nothing").")

        shot("t45-01-semaglutide-conc-25-typed")
    }

    /// The other half of T-45: the dose above the web's threshold is now SELECTABLE,
    /// and selecting it raises the sentence the truncated list used to delete.
    func testADoseAboveTheWeeklyMaximumIsReachableAndWarns() throws {
        try openCalculator("Semaglutide")

        setNumber("conc", to: "5")
        // 2.5 mg — one ladder step above the 2.4 mg Wegovy ceiling, and a value the
        // old 11-entry list could not express at all.
        setNumber("dose", to: "2.5")

        XCTAssertEqual(resultValue("Draw"), "0.500 mL")

        let note = app.descendants(matching: .any)
            .matching(identifier: "result_note_0").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5),
                      "No advisory rendered at 2.5 mg. Before T-45 this dose was not "
                      + "on the list at all, so the warning branch was unreachable.")
        XCTAssertTrue(note.label.contains("Exceeds typical weekly maximum of 2.4 mg"),
                      "Advisory read: \(note.label)")

        shot("t45-02-semaglutide-over-maximum-warning")
    }

    /// The threshold value itself is NOT a warning. `dose > 2.4`, strictly — 2.4 mg is
    /// the label dose, and warning on it would be the app crying wolf on the single
    /// commonest maintenance dose in the production mix.
    func testTheThresholdDoseItselfDoesNotWarn() throws {
        try openCalculator("Semaglutide")
        setNumber("conc", to: "5")
        setNumber("dose", to: "2.4")

        XCTAssertEqual(resultValue("Draw"), "0.480 mL")
        let note = app.descendants(matching: .any)
            .matching(identifier: "result_note_0").firstMatch
        XCTAssertFalse(note.exists,
                       "Warned AT the maximum: \(note.exists ? note.label : "")")
    }

    // MARK: - Helpers

    /// Clears the field and types the value. Focusing a populated field selects its
    /// contents, so typing replaces rather than appends — asserted by reading the
    /// field back, because "typing 25 into a field showing 5" has produced `525` on
    /// this control before.
    private func setNumber(_ key: String, to value: String) {
        let field = app.textFields["field_\(key)"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8),
                      "No `field_\(key)` — is it still a closed picker?")
        field.tap()
        field.typeText(value)
        // Dismiss the keyboard so the result card is not occluded in the frame.
        app.staticTexts.firstMatch.tap()
        XCTAssertEqual(field.value as? String, value,
                       "`field_\(key)` reads \(String(describing: field.value)) after "
                       + "typing \(value).")
    }

    /// The value cell of one result row, addressed by the card's own identifier scheme.
    private func resultValue(_ label: String) -> String? {
        let row = app.descendants(matching: .any)
            .matching(identifier: "result_\(label)").allElementsBoundByIndex
            .first { $0.frame.minX >= 0 }
        return row?.value as? String ?? row?.label
    }

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

        // ARRIVAL. A row tap is not arrival: the calculator's own concentration field
        // is something only this destination renders, and it cannot resolve on the
        // Tools list at any timing.
        XCTAssertTrue(app.textFields["field_conc"].firstMatch.waitForExistence(timeout: 10),
                      "Never arrived on \(name) — `field_conc` never resolved.")
    }

    /// Writes to the app's Documents directory, the same place `CaptureCurrentState`
    /// puts its frames, AND attaches it to the result bundle so a run that cannot be
    /// reached with `simctl get_app_container` still carries its evidence.
    private func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot()
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? png.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: png)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("T45-FRAME: \(dir.appendingPathComponent("\(name).png").path)")
    }
}
