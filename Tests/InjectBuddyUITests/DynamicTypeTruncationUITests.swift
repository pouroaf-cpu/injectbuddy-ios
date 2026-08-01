import XCTest

/// Asserts the OUTCOME — a dose value stays readable — rather than banning the
/// mechanisms that have broken it so far.
///
/// ## Why this is geometric and not textual
///
/// The obvious test is "the displayed string contains no ellipsis". It cannot
/// work. The accessibility layer returns the **model text**, not the rendered
/// glyphs. Measured on the real defect, at AX5, with the pre-fix layout restored:
///
///     field.value = "100"      <- the full string
///     field.frame = w 28.7pt
///     unit.frame  = w 197.7pt
///
/// The screen rendered `1…`. A string assertion passes on that frame. It is not a
/// weaker test, it is a test that cannot fail — the category this harness has
/// spent a day removing.
///
/// ## The invariant
///
/// **A value cell is never narrower than its own unit label.**
///
/// | | field w | unit w | |
/// |---|---|---|---|
/// | AX5, pre-fix inline row | 28.7 | 197.7 | RED |
/// | AX5, after the reflow | 338.3 | 197.7 | green |
/// | Default | 162.3 | 63.7 | green |
///
/// It goes red on all three mechanisms that have actually produced this bug —
/// `lineLimit` on a value+unit pair (finding F1), a `.fixedSize()` sibling taking
/// the row (2026-08-02), and a frozen font at the call site that stops growing
/// while the unit does — without naming any of them.
///
/// ## WHAT IT DOES NOT CATCH. Read this before treating green as "no truncation".
///
/// It is a **ratio**, so it is blind wherever both sides shrink together or where
/// the unit is short:
///
/// 1. **A container that squeezes the whole row proportionally.** Value and unit
///    both shrink, the ratio holds, both truncate.
/// 2. **A long value beside a short unit.** `1000` truncated to `10…` next to `mg`
///    is still wider than `mg` and passes. That is not hypothetical — it is the TRT
///    weekly field with a four-digit dose.
///
/// So this bans the mechanisms we know, exactly as F1's `lineLimit` ban did, and it
/// will be insufficient in the same way. Do not read a green run as "truncation is
/// impossible here" — that belief is what let `1…` ship. The thing that would close
/// the class is the renderer publishing its own truncation state; until that
/// exists, this is a floor.
///
/// ## Proving it fails
///
/// `FORCE_INLINE_FIELD=1` (DEBUG only) restores the pre-fix layout. Run this suite
/// at AX5 with it set and the assertion goes red on the real defect. A test that
/// has never failed has not been shown to work.
///
///     xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
///     TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… TEST_RUNNER_FORCE_INLINE_FIELD=1 \
///       xcodebuild test … -only-testing:InjectBuddyUITests/DynamicTypeTruncationUITests
///     xcrun simctl ui booted content_size large     # ALWAYS reset
final class DynamicTypeTruncationUITests: XCTestCase {

    /// Every calculator that renders numeric fields. `cyclePlotter` is excluded —
    /// it routes to a bespoke chart screen with no `NumberField` on it.
    private static let calculators = [
        "TRT Dose", "TRT & EOD", "TRT Microdose", "HCG", "Free T Index",
        "Semaglutide", "Tirzepatide", "Retatrutide", "BMI",
        "Peptide", "Reconstitution", "BPC-157", "BPC+TB500",
        "Steroid Dosage",
    ]

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true   // report EVERY offending field, not the first

        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "QA_EMAIL / QA_PASSWORD not set — skipping signed-in UI tests.")

        app = XCUIApplication()
        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        if env["FORCE_INLINE_FIELD"] == "1" {
            app.launchEnvironment["FORCE_INLINE_FIELD"] = "1"
        }
        app.launch()

        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 8) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 20),
                      "Not signed in — this suite needs the signed-in app.")
    }

    /// Runs at whatever content size the DEVICE is set to. The size is device
    /// state, not run state, so the matrix is driven from the host:
    ///
    ///     for s in small large extra-extra-extra-large accessibility-medium \
    ///              accessibility-extra-large accessibility-extra-extra-extra-large; do
    ///       xcrun simctl ui booted content_size $s
    ///       xcodebuild test … -only-testing:InjectBuddyUITests/DynamicTypeTruncationUITests
    ///     done
    ///     xcrun simctl ui booted content_size large
    ///
    /// Do not shrink the matrix to make it fast. Run default + AX5 per commit and
    /// the whole thing nightly if it has to be split — shrinking it is how the gap
    /// comes back.
    func testEveryValueCellIsWiderThanItsUnit() {
        for name in Self.calculators {
            guard openCalculator(named: name) else { continue }
            checkFields(on: name)
            back()
        }
    }

    // MARK: - Assertions

    private func checkFields(on screen: String) {
        let fields = app.textFields.allElementsBoundByIndex
            .filter { $0.identifier.hasPrefix("field_") }

        // Not a failure. The GLP-1 calculators are pickers and segmented controls
        // with no `NumberField` on them, so there is nothing here to measure. Said
        // out loud rather than silently skipped: a suite that quietly covers eight
        // of fourteen screens while reporting green is the thing this file exists
        // to stop.
        guard !fields.isEmpty else {
            print("TRUNCATION-SWEEP: \(screen) has no numeric fields — nothing measured.")
            return
        }

        for field in fields {
            let key = String(field.identifier.dropFirst("field_".count))
            let unit = app.staticTexts["unit_\(key)"]
            guard unit.exists else { continue }   // unitless field, nothing to compare

            XCTAssertGreaterThanOrEqual(
                field.frame.width, unit.frame.width,
                """
                \(screen) · \(key): the value cell is NARROWER than its own unit \
                (\(String(format: "%.1f", field.frame.width))pt vs \
                \(String(format: "%.1f", unit.frame.width))pt). The number the user \
                acts on is being squeezed out by its own label. Note the string is \
                intact — value is "\(String(describing: field.value))" — which is why \
                this is measured geometrically.
                """)
        }
    }

    // MARK: - Navigation

    private func openCalculator(named name: String) -> Bool {
        app.buttons.matching(identifier: "Tools").allElementsBoundByIndex
            .filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?
            .tap()

        // Scroll until hittable, re-querying each pass: at accessibility sizes the
        // list is lazy, so `waitForExistence` reports "does not exist" for a row two
        // swipes away, and `Tools` is a `List` — a collectionView to XCUITest, not a
        // scrollView.
        for _ in 0..<15 {
            if let row = app.staticTexts.matching(identifier: name)
                .allElementsBoundByIndex.first(where: { $0.isHittable }) {
                row.tap()
                return app.textFields.allElementsBoundByIndex
                    .contains { $0.identifier.hasPrefix("field_") }
                    || app.staticTexts[name].waitForExistence(timeout: 5)
            }
            guard let list = (app.collectionViews.allElementsBoundByIndex
                              + app.tables.allElementsBoundByIndex
                              + app.scrollViews.allElementsBoundByIndex)
                .first(where: { $0.isHittable && $0.frame.minX >= 0 }) else { break }
            list.swipeUp()
        }

        XCTFail("Could not reach \(name) in Tools.")
        return false
    }

    private func back() {
        let backButton = app.buttons.matching(identifier: "Tools").allElementsBoundByIndex
            .filter { $0.isHittable }
            .min { $0.frame.midY < $1.frame.midY }
        backButton?.tap()
    }
}
