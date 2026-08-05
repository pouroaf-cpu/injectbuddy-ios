import XCTest

/// **T-44, on the device.** `SteroidFormParityTests` pins the arithmetic and the form
/// split; this pins that an oral compound RENDERS as one — which is the half of the
/// done-when a unit test cannot answer.
///
/// The audit frame this replaces, `28-calculator-steroid.png`, opened on Oxandrolone
/// (Anavar) showing a vial strength of 200 mg/mL, a syringe barrel, and a result of
/// 0.75 mL / 75 units **for a tablet**. Oxandrolone is `cls:'oral'` on the web and
/// `canInject: false` in iOS's own catalogue — the flag existed and nothing read it.
///
/// FRAME: `t44-01-steroid-oxandrolone-oral.png` — the shipped default, rendering tablet
/// inputs and no syringe.
///
/// THE ASSERTIONS ARE THE PROOF. A screenshot showing tablet fields proves it to a
/// reader; the assertions prove it to the run. Both, because this project has shipped a
/// capture set that was byte-identical to the previous one.
final class T44SteroidOralFormUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15),
                      "Not signed in — this needs the signed-in app.")
    }

    /// Staleness closed per NAME immediately before the rewrite — never a directory
    /// sweep in `setUp`, which XCTest runs before every test method.
    private func shot(_ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
        print("T44-FRAME: \(url.path)")
    }

    func testAnOralCompoundRendersTabletInputsAndNoSyringe() {
        let tools = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tools.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tools.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "Tools exists but nothing hittable.")
        lowest?.tap()
        XCTAssertTrue(app.staticTexts["Reconstitution"].firstMatch.waitForExistence(timeout: 8),
                      "Tapped Tools and never arrived.")

        // Scroll to Steroid Dosage — it is the last group on the list.
        var row: XCUIElement?
        for _ in 0..<12 {
            let candidate = app.staticTexts.matching(identifier: "Steroid Dosage")
                .allElementsBoundByIndex.first { $0.isHittable }
            if let candidate { row = candidate; break }
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else { break }
            list.swipeUp()
        }
        guard let hit = row else { return XCTFail("Steroid Dosage never became hittable.") }
        hit.tap()

        // ARRIVAL ASSERTED before anything is claimed about the screen. `field_oralDose`
        // is the oral form's own field, so its presence proves BOTH that we landed on the
        // steroid calculator AND that it opened on the oral form.
        let oralDose = app.textFields["field_oralDose"]
        XCTAssertTrue(oralDose.waitForExistence(timeout: 8),
                      "Tapped Steroid Dosage and no `field_oralDose` appeared. Either the "
                      + "screen did not load, or the shipped default (Oxandrolone, an "
                      + "oral) is still rendering the injectable form — which is T-44.")

        // The tablet trio is present…
        XCTAssertTrue(app.textFields["field_tabMg"].exists,
                      "no tablet-strength field on an oral compound")
        XCTAssertTrue(app.textFields["field_oralSplit"].exists,
                      "no doses-per-day field on an oral compound")

        // …and the injectable inputs are NOT. This is the assertion the task is about:
        // the old frame showed a 200 mg/mL vial strength and a syringe barrel on a
        // tablet, and `evaluate` returned 0.75 mL / 75 units for it.
        XCTAssertFalse(app.textFields["field_strength"].exists,
                       "A vial strength is still offered for a TABLET. `canInject` is "
                       + "false for this compound and something is not reading it.")
        XCTAssertFalse(app.textFields["field_mgWeek"].exists,
                       "A weekly injectable dose is still offered for a tablet.")

        shot("t44-01-steroid-oxandrolone-oral.png")
    }

    /// **T-96 — picking Anadrol must seed a 50 mg tablet strength.**
    ///
    /// Anadrol ships 50 mg tablets and iOS seeded 10 for every compound, so
    /// tablets-per-dose read **5× too high** until the user noticed and edited it. The
    /// unit tests pin the seeding; this pins that it reaches the field the user reads.
    ///
    /// Driven by LABEL, not by identifier, and with a tree dump on failure — earlier in
    /// this session a mode control was reported absent twice while on screen, because
    /// the identifier being queried had been overwritten by its container. Labels are
    /// what the tree actually showed.
    func testPickingAnadrolSeedsAFiftyMilligramTabletStrength() {
        openSteroidCalculator()

        let tabMg = app.textFields["field_tabMg"]
        XCTAssertTrue(tabMg.waitForExistence(timeout: 8), "no tablet-strength field")
        XCTAssertEqual(tabMg.value as? String, "10",
                       "Oxandrolone should open on 10 mg/tab — if this is not 10 the "
                       + "starting point of the comparison has moved.")

        // Open the compound picker by its currently-displayed value.
        let combo = app.descendants(matching: .any)
            .containing(NSPredicate(format: "label CONTAINS[c] %@", "Oxandrolone"))
            .firstMatch
        let direct = app.staticTexts["Oxandrolone (Anavar)"].firstMatch
        if direct.waitForExistence(timeout: 4), direct.isHittable { direct.tap() }
        else if combo.exists { combo.tap() }
        else {
            print("T96-TREE-DUMP:\n\(app.debugDescription)")
            return XCTFail("Could not find the compound control. See T96-TREE-DUMP.")
        }

        let anadrol = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Anadrol"))
            .firstMatch
        if !anadrol.waitForExistence(timeout: 6) {
            print("T96-TREE-DUMP:\n\(app.debugDescription)")
            return XCTFail("Anadrol is not offered in the compound picker. See T96-TREE-DUMP.")
        }
        anadrol.tap()

        // THE ASSERTION T-96 EXISTS FOR.
        let seeded = app.textFields["field_tabMg"]
        XCTAssertTrue(seeded.waitForExistence(timeout: 6))
        var value = seeded.value as? String
        for _ in 0..<10 where value != "50" {
            usleep(300_000)
            value = seeded.value as? String
        }
        XCTAssertEqual(value, "50",
                       "Picking Anadrol left the tablet strength at \(value ?? "nil"). "
                       + "Anadrol ships 50 mg tablets, so a 10 makes tablets-per-dose "
                       + "read 5× too high.")

        shot("t96-01-steroid-anadrol-50mg-tab.png")
    }

    /// Shared navigation, arrival asserted.
    private func openSteroidCalculator() {
        let tools = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tools.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        let lowest = tools.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        lowest?.tap()
        XCTAssertTrue(app.staticTexts["Reconstitution"].firstMatch.waitForExistence(timeout: 8),
                      "Tapped Tools and never arrived.")
        var row: XCUIElement?
        for _ in 0..<12 {
            let candidate = app.staticTexts.matching(identifier: "Steroid Dosage")
                .allElementsBoundByIndex.first { $0.isHittable }
            if let candidate { row = candidate; break }
            let scrollable = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }
            guard let list = scrollable else { break }
            list.swipeUp()
        }
        guard let hit = row else { return XCTFail("Steroid Dosage never became hittable.") }
        hit.tap()
    }
}
