import XCTest

/// §5.39, made into something that can go red: **an instrument that alters the thing it
/// measures is a class, not an incident.**
///
/// `bar_plate` was added so the reachability check could read the plate's RENDERED top
/// edge instead of trusting the pinning gate's arithmetic. Right instinct, right design.
/// It was attached with `.overlay`, so its `Color.clear` — carrying
/// `.accessibilityElement()` — sat on top of the entire result bar in the accessibility
/// tree, `Add` included, and made the primary CTA of every calculator report
/// `hittable=false` with `AXScrollToVisible` failing. Nobody was looking for it; it
/// surfaced only because that button was given an identifier for an unrelated reason.
///
/// This app ships THREE probes that publish accessibility elements:
///
///   | probe | attachment | size |
///   |---|---|---|
///   | `bar_plate` | `.background` (was `.overlay`) | spans the whole result bar |
///   | `bar_gate` | `.overlay` | `.frame(width: 0, height: 0)` |
///   | `trunc_<id>` | `.overlayPreferenceValue` | `.frame(width: 0, height: 0)` |
///
/// Two of the three are overlays. The argument that they are harmless is that a 0×0
/// element cannot stand in front of anything — which is almost certainly true and is
/// exactly the kind of "correct by inspection" reasoning that has been wrong three times
/// on this project. So it is measured instead.
///
/// THE ASSERTION IS DELIBERATELY NOT "the probes are attached correctly". A check written
/// against the three probes we know about cannot see the fourth one somebody adds next
/// month. It asserts the PROPERTY those attachments are supposed to preserve:
///
///   **every enabled control wholly on screen can be reached through the accessibility
///   layer.**
///
/// That is the invariant VoiceOver and Switch Control users actually depend on — they
/// reach controls through this layer and nothing else — and it is blind to which probe,
/// or which overlay, or whether the culprit is a probe at all.
///
/// SHOWN RED BEFORE IT WAS TRUSTED (§5.24): with `bar_plate` reverted to `.overlay`, this
/// reports `Add` unreachable on every calculator it visits. Restored, green. The failure
/// message names the control and its frame, because "something is unreachable" sends you
/// back to the simulator and a name does not.
final class ProbeAttachmentUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
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

    /// The screens that carry probes. `TRT Dose` and `Reconstitution` render `bar_plate`,
    /// `bar_gate` and a `trunc_` probe per field; `Steroid Dosage` adds a menu picker.
    ///
    /// AIMED AT THREE OF FIFTEEN (§5.33), and that is stated rather than implied — this
    /// is the same aim the reachability suite has, and widening it is a queued item. What
    /// this establishes is that the probe mechanism is clean on the screens measured, not
    /// that it is clean everywhere.
    func testEveryEnabledControlOnScreenIsReachableThroughAccessibility() throws {
        var unreachable: [String] = []
        for screen in ["TRT Dose", "Reconstitution", "Steroid Dosage"] {
            try openCalculator(screen)
            reportProbeFrames(on: screen)
            unreachable += occludedControls(on: screen)
        }
        let fresh = unreachable.filter { line in
            !Self.knownOccluded.contains { line.contains($0.screen) && line.contains($0.label) }
        }
        XCTAssertTrue(fresh.isEmpty,
                      "Controls that are enabled and wholly on screen but cannot be "
                      + "reached through the accessibility layer — which is how VoiceOver "
                      + "and Switch Control reach every control they reach:\n  "
                      + fresh.joined(separator: "\n  "))

        // BOTH ENDS (§5.30). A named debt that stops failing must say so, or the list
        // outlives the defect and becomes a narrowed assertion with extra steps.
        for known in Self.knownOccluded {
            XCTAssertTrue(unreachable.contains { $0.contains(known.screen) && $0.contains(known.label) },
                          "`\(known.screen)` / `\(known.label)` is reachable now. It is a "
                          + "named failure (\(known.finding)) and it is clean — delete its "
                          + "entry from `knownOccluded`.")
        }
    }

    /// FOUND BY THIS SUITE ON ITS FIRST RUN, and it is not a probe defect — it is the
    /// finding the probe audit walked into.
    ///
    /// The four barrel-size buttons on `TRT Dose` and `Steroid Dosage` are enabled, are
    /// 44pt tall, are wholly inside the window at y 590.67…634.67 — and the result
    /// plate's top edge is at **564.67**. They are UNDERNEATH THE PINNED BAR at DEFAULT
    /// SIZE, so no user reaches them without scrolling and no VoiceOver user reaches them
    /// at all from that position.
    ///
    /// WHY NOTHING CAUGHT IT, which is the part worth keeping: `PinnedBarReachability`
    /// measures `field_*` and `control_*` only, and says so in its own coverage note —
    /// segmented rows carry no per-control identifier. **These buttons are addressed by
    /// LABEL because they have no identifier**, so the suite that owns this invariant has
    /// never been able to see them. §5.33 again: the aim is short, and this time the gap
    /// was documented and still cost a finding.
    ///
    /// Filed as a debt rather than fixed here: this run was stopped at an item boundary,
    /// and the fix is a layout change that belongs with the other default-size shears.
    struct OccludedControl {
        let screen: String
        let label: String
        let finding: String
    }

    static let knownOccluded: [OccludedControl] = [
        .init(screen: "TRT Dose", label: "0.3 mL (30u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "TRT Dose", label: "0.5 mL (50u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "TRT Dose", label: "1 mL (100u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "TRT Dose", label: "3 mL (IM)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "Steroid Dosage", label: "0.3 mL (30u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "Steroid Dosage", label: "0.5 mL (50u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "Steroid Dosage", label: "1 mL (100u)", finding: "BOARD §1 — barrel row under the plate at default"),
        .init(screen: "Steroid Dosage", label: "3 mL (IM)", finding: "BOARD §1 — barrel row under the plate at default"),
    ]

    // MARK: - The measurement

    /// Enabled controls that are wholly inside the window and still report
    /// `isHittable == false`.
    ///
    /// FILTERED THREE WAYS, and each exclusion is a false positive this would otherwise
    /// produce rather than a narrowing (§5.32):
    ///   - DISABLED controls. A disabled control is legitimately not hittable, and after
    ///     the `canSaveProtocol` gate two calculators ship one on purpose.
    ///   - Controls NOT WHOLLY ON SCREEN. Something below the fold is a scroll away, not
    ///     occluded; that is the reachability suite's question, not this one.
    ///   - Zero-area frames. That is what a correctly attached probe looks like, and it
    ///     is the thing being audited, not a control.
    private func occludedControls(on screen: String) -> [String] {
        let window = app.windows.firstMatch.frame
        let candidates = app.buttons.allElementsBoundByIndex
            + app.textFields.allElementsBoundByIndex

        return candidates.compactMap { element in
            guard element.exists, element.isEnabled else { return nil }
            let frame = element.frame
            guard frame.width > 0, frame.height > 0 else { return nil }
            guard window.contains(frame) else { return nil }
            guard !element.isHittable else { return nil }
            let name = element.identifier.isEmpty ? "\"\(element.label)\"" : element.identifier
            return "\(screen): \(name) enabled, wholly on screen at \(frame), NOT hittable"
        }
    }

    /// Prints what each probe's accessibility element actually measures, so the audit is
    /// a set of numbers rather than a reading of the source.
    ///
    /// `bar_gate` and `trunc_*` are declared `.frame(width: 0, height: 0)`; this is where
    /// that stops being a declaration and becomes an observation. A probe that reports a
    /// non-zero frame is standing in front of something whether or not anything has
    /// noticed yet.
    private func reportProbeFrames(on screen: String) {
        for prefix in ["bar_plate", "bar_gate", "trunc_"] {
            let matches = app.descendants(matching: .any).allElementsBoundByIndex
                .filter { $0.identifier.hasPrefix(prefix) }
            let described = matches
                .map { "\($0.identifier)=\($0.frame.width)x\($0.frame.height)" }
                .joined(separator: " ")
            print("PROBE \(screen) \(prefix): count=\(matches.count) \(described)")
        }
    }

    // MARK: - Navigation

    private func openCalculator(_ name: String) throws {
        let back = app.navigationBars.buttons.matching(identifier: "Tools").firstMatch
        if back.exists && back.isHittable { back.tap() }

        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()

        if let list = scrollable() {
            for _ in 0..<8 { list.swipeDown(velocity: XCUIGestureVelocity(rawValue: 500)) }
        }

        var row: XCUIElement?
        for attempt in 0..<12 {
            row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            guard let list = scrollable() else {
                return XCTFail("Nothing scrollable after \(attempt) attempts looking for \(name).")
            }
            list.swipeUp()
        }
        guard let hit = row else {
            return XCTFail("\(name) never became hittable after 12 scrolls.")
        }
        hit.tap()
        // Arrival asserted, never assumed. Measuring the wrong screen is quieter than
        // photographing one — the run goes green about a screen nobody asked about.
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 8),
                      "Tapped `\(name)` and did not land on it.")
    }

    private func scrollable() -> XCUIElement? {
        (app.collectionViews.allElementsBoundByIndex
         + app.tables.allElementsBoundByIndex
         + app.scrollViews.allElementsBoundByIndex)
            .first { $0.isHittable && $0.frame.minX >= 0 }
    }
}
