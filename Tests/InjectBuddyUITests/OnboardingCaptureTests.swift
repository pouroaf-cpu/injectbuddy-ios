import XCTest

/// ─── THE SIX-PATH ONBOARDING SWEEP ───────────────────────────────────────────
///
/// SPEC-ONBOARDING §7: *"code all of it, build once, then walk **six paths** in one
/// session"* — and §3.3: *"Motion is judged, not asserted; capture two frames per screen,
/// early and settled, and confirm the settled frame is the composed one."*
///
/// **Drives `OnboardingPreview`, not the app.** No auth, no session, no network — which is
/// the whole reason that target exists. `XCUIApplication(bundleIdentifier:)` launches it;
/// nothing had to be added to either app to make this drivable.
///
/// ─── WHY A WALK AND NOT A "JUMP TO SCREEN N" AFFORDANCE ──────────────────────────────
///
/// A frame shot by mounting a screen directly is a photograph of a view, **not evidence
/// that any path arrives at it.** That is one letter away from `03-calendar` — a frame
/// filed under a name the run never reached. The walk proves the route as a side effect of
/// photographing it.
///
/// ─── THE ARRIVAL PROOF IS THE PROGRESS BAR'S ACCESSIBILITY VALUE ─────────────────────
///
/// Every step has a **unique, exact** percentage (SPEC §3: 25/35/45/55/62/69/76/84/90/
/// 97/100), so the bar identifies the screen — and §7 already says the percentages are
/// *"the one thing worth asserting rather than eyeballing"*. Two birds.
///
/// **And it is read from `accessibilityValue`, not from rendered text.** This flow's
/// neighbourhood has bitten us twice with `.uppercased()` `Section` headers, where the
/// string in the source and the string in the tree differ. A value cannot be case-
/// transformed by a list style.
///
/// OPT-IN, like `CaptureCurrentState`:
///
///     TEST_RUNNER_CAPTURE=1 xcodebuild test … \
///       -only-testing:InjectBuddyUITests/OnboardingCaptureTests
final class OnboardingCaptureTests: XCTestCase {

    private var app: XCUIApplication!
    private var taken: [String: Data] = [:]

    /// How long the entrance reveal needs to finish: 350ms duration + the largest stagger
    /// in the flow. Generous rather than tight — this is a settle wait for a frame that is
    /// then JUDGED, not a timing assertion.
    private let settle: TimeInterval = 1.2

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE"] == "1",
                          "TEST_RUNNER_CAPTURE=1 not set — skipping the onboarding sweep.")
        // FALSE. A walk that cannot fail loudly keeps producing frames that lie — the
        // lesson `12-calculator-trt-ax5` and `03-calendar` both taught.
        continueAfterFailure = false

        // The runner's Documents directory SURVIVES between runs, so a skipped frame is
        // otherwise copied out as this run's evidence.
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for url in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        where url.pathExtension == "png" {
            try? FileManager.default.removeItem(at: url)
        }

        app = XCUIApplication(bundleIdentifier: "com.injectbuddy.ios.onboardingpreview")
        app.launch()
    }

    // MARK: - The six paths

    private struct Path {
        let name: String
        let segment: String        // OnboardingSegment.rawValue
        let experience: String     // OnboardingExperience.rawValue
        let skipsReminders: Bool
        let skipsInventory: Bool
        let declinesPaywall: Bool
    }

    /// SPEC §7 names these exactly. The sixth is the one that skips **both** optionals, so
    /// the paywall opener variant (rule 6) and the dashboard's *"set a reminder?"* card
    /// (rule 7) both render.
    private static let paths: [Path] = [
        Path(name: "1-trt-adv",   segment: "trt",   experience: "adv",   skipsReminders: false, skipsInventory: false, declinesPaywall: false),
        Path(name: "2-trt-first", segment: "trt",   experience: "first", skipsReminders: false, skipsInventory: false, declinesPaywall: false),
        Path(name: "3-glp-some",  segment: "glp",   experience: "some",  skipsReminders: false, skipsInventory: false, declinesPaywall: false),
        Path(name: "4-aas-some",  segment: "aas",   experience: "some",  skipsReminders: false, skipsInventory: false, declinesPaywall: false),
        Path(name: "5-other-some", segment: "other", experience: "some", skipsReminders: false, skipsInventory: false, declinesPaywall: false),
        Path(name: "6-skip-both", segment: "trt",   experience: "some",  skipsReminders: true,  skipsInventory: true,  declinesPaywall: true),
    ]

    func testWalkSixPaths() {
        announceCoverage()
        for path in Self.paths {
            walk(path)
        }
    }

    private func walk(_ path: Path) {
        let p = path.name

        // ── 1 · welcome, 25% ──────────────────────────────────────────────────────
        arrive(at: 25, screen: "welcome", path: p)
        // A NAME IS TYPED ON EVERY PATH, so the five personalisation placements are
        // exercised rather than only their nameless fallbacks. The nameless side is
        // covered by the preview's own no-session default before this is typed.
        let nameField = app.textFields["onboarding.welcome.name"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 8), "\(p): no name field on screen 1.")
        nameField.tap()
        nameField.typeText(Self.typedName)
        shootPair("01-welcome", path: p)
        tapPrimary(p)

        // ── 2 · pathway, 35% — PLACEMENT 1, end of title ───────────────────────────
        arrive(at: 35, screen: "pathway", path: p)
        shootPair("02-pathway", path: p)
        tap("onboarding.pathway.\(path.segment)", p)

        // ── 3 · experience, 45% — PLACEMENT 2, mid-sentence ────────────────────────
        arrive(at: 45, screen: "experience", path: p)
        shootPair("03-experience", path: p)
        tap("onboarding.experience.\(path.experience)", p)

        // ── 4 · benefits. `.adv` sees ONE (rule 1); everyone else sees three. ──────
        let benefitBars = path.experience == "adv" ? [55] : [55, 62, 69]
        for (i, bar) in benefitBars.enumerated() {
            arrive(at: bar, screen: "benefit\(i + 1)", path: p)
            shootPair("04\(["a", "b", "c"][i])-benefit\(i + 1)", path: p)
            tapPrimary(p)
        }

        // ── 5 · setup, 76% — PLACEMENT 3, late-sentence ────────────────────────────
        arrive(at: 76, screen: "setup", path: p)
        shootPair("05-setup", path: p)
        // Rule 3: the reassurance line exists only on `.first`. Rule 4: the extra
        // compound row only on `.adv`. **Both asserted from BOTH ends** — present where
        // it should be, ABSENT where it should not (D7's rescued clause).
        let reassurance = app.staticTexts["onboarding.setup.reassurance"].firstMatch
        XCTAssertEqual(reassurance.exists, path.experience == "first",
                       "\(p): setup reassurance line (rule 3) is on the wrong branch.")
        let addCompound = app.buttons["onboarding.setup.addCompound"].firstMatch
        XCTAssertEqual(addCompound.exists, path.experience == "adv",
                       "\(p): '＋ Add another compound' (rule 4) is on the wrong branch.")
        tapPrimary(p)

        // ── 6 · reminders, 84% ────────────────────────────────────────────────────
        arrive(at: 84, screen: "reminders", path: p)
        shootPair("06-reminders", path: p)
        path.skipsReminders ? tap("onboarding.reminders.skip", p) : tapPrimary(p)

        // ── 7 · inventory, 90% ────────────────────────────────────────────────────
        arrive(at: 90, screen: "inventory", path: p)
        shootPair("07-inventory", path: p)
        path.skipsInventory ? tap("onboarding.inventory.skip", p) : tapPrimary(p)

        // ── 8 · firstDose, 97% — PLACEMENT 4, opening ─────────────────────────────
        arrive(at: 97, screen: "firstDose", path: p)
        shootPair("08-firstDose", path: p)
        tapPrimary(p)

        // ── 9 · paywall, 100% — PLACEMENT 5, mid-sentence ─────────────────────────
        arrive(at: 100, screen: "paywall", path: p)
        shootPair("09-paywall", path: p)

        // ── 10 · an end state, and then the LOOP back to screen 1 ─────────────────
        if path.declinesPaywall {
            tap("onboarding.paywall.decline", p)
            let seePlans = app.buttons["onboarding.locked.seePlans"].firstMatch
            XCTAssertTrue(seePlans.waitForExistence(timeout: 8), "\(p): never reached `locked`.")
            shootPair("10b-locked", path: p)
            // `See plans again` goes BACK to the paywall — it is not the loop.
            seePlans.tap()
            _ = app.staticTexts["onboarding.paywall.thisApp"].firstMatch.waitForExistence(timeout: 8)
            tap("onboarding.paywall.decline", p)
            _ = seePlans.waitForExistence(timeout: 8)
        } else {
            tap("onboarding.paywall.trial", p)
            let nextDose = app.staticTexts["onboarding.dashboard.nextDose"].firstMatch
            XCTAssertTrue(nextDose.waitForExistence(timeout: 8), "\(p): never reached `dashboard`.")
            shootPair("10a-dashboard", path: p)
        }

        // THE LOOP IS THE END STATE (SPEC §1). Back to screen 1 with state cleared —
        // which is what makes six paths cost one build and no relaunches.
        tap("onboarding.finish", p)
        arrive(at: 25, screen: "welcome-after-loop", path: p)
        // **The reset is verified, not assumed.** A leaked name would show the wrong
        // personalisation on the next pass and read as a copy bug — a defect in the thing
        // being tested, blamed on the thing that is correct (SPEC §1).
        let loopedField = app.textFields["onboarding.welcome.name"].firstMatch
        XCTAssertTrue(loopedField.waitForExistence(timeout: 8), "\(p): loop did not land on screen 1.")
        // ─── "EMPTY" HAS TWO READINGS AND I GUESSED THE WRONG ONE ──────────────────
        //
        // I asserted the field would report its PLACEHOLDER as its value when empty —
        // true of UIKit `UITextField`, and stated confidently. **Measured here: this
        // SwiftUI `TextField` reports `""`.** The assertion failed on a field that was
        // correctly cleared, which is precisely the error I claimed I was avoiding.
        //
        // So: accept **either** reading, because both mean empty and which one you get is
        // not stable across UIKit/SwiftUI versions. **This is not a loosened assertion** —
        // a surviving name reads back as `"Pou"`, which is neither `""` nor the
        // placeholder, so the disjunction still catches the thing it exists to catch.
        let looped = (loopedField.value as? String) ?? ""

        // ***THE ASSERTION THAT MUST NOT FAIL IS THE NEGATIVE ONE.*** What `reset()` has to
        // guarantee is that **the typed name is not there** — and that is true regardless
        // of which framework hands back which flavour of "empty".
        //
        // The two-reading version below is correct today and **carries an assumption about
        // the set of possible empties**; this one carries none. Decide on the PROPERTY
        // that matters, not the representation you happened to observe — the same shape as
        // the barrel-fit fix.
        XCTAssertNotEqual(looped, Self.typedName,
                          "\(p): the typed name survived the loop — `OnboardingState.reset()` "
                          + "did not clear it.")

        // Kept as documentation of what empty looked like on 2026-08-03, not as the guard.
        // If a future OS changes which flavour it returns, this is the line to update and
        // the one above still protects the thing that matters.
        XCTAssertTrue(looped.isEmpty || looped == Self.emptyFieldValue,
                      "\(p): field reads \(looped) — neither empty nor the placeholder. Not a "
                      + "leak (the negative check above passed), but the empty representation "
                      + "has changed and this line needs re-measuring.")
    }

    /// A `TextField` with no text reports its PLACEHOLDER as its value, not `""`. Asserting
    /// against `""` would fail on a correctly-cleared field.
    private static let emptyFieldValue = "What should InjectBuddy call you?"

    /// The name typed on every path. The loop's reset is asserted against THIS — the
    /// property that matters — rather than against whichever representation of "empty"
    /// the framework happens to return.
    private static let typedName = "Pou"

    // MARK: - Reduce Motion
    //
    // ***THERE IS NO REDUCE MOTION TEST, AND THAT IS A MEASUREMENT RATHER THAN AN
    // OMISSION.*** One was written: same instrument, opposite expectation — the two frames
    // must be IDENTICAL under Reduce Motion, where they must DIFFER without it. Neither
    // reading would then be ambiguous.
    //
    // **It failed, and the discriminator showed the failure was the caret, not the app.**
    // `welcome` focuses its field on appear; a blinking cursor makes any two frames of that
    // screen differ, with or without Reduce Motion. The test would have gone red on a
    // correct build and — worse — the NORMAL check would have gone green on a build that
    // ignored Reduce Motion entirely.
    //
    // **Reduce Motion is implemented** (`OnboardingReveal` returns the settled state
    // immediately and applies no offset, no stagger and no fade) **and it is unverified by
    // instrument.** Verify it by eye with the setting on, and set and reset it in the same
    // command:
    //
    //     xcrun simctl spawn <dev> defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES ; \
    //     … look … ; \
    //     xcrun simctl spawn <dev> defaults write com.apple.Accessibility ReduceMotionEnabled -bool NO

    // MARK: - Arrival

    /// SPEC §3's percentages are exact and unique per step, so this is both the arrival
    /// proof and the §7 measurement.
    private func arrive(at percent: Int, screen: String, path: String) {
        let bar = app.descendants(matching: .any).matching(identifier: "onboarding.progress").firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10),
                      "\(path)/\(screen): no progress bar — did the flow leave the route?")
        let want = "\(percent)%"
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline, (bar.value as? String) != want { usleep(100_000) }
        XCTAssertEqual(bar.value as? String, want,
                       "\(path)/\(screen): the bar says \(String(describing: bar.value)), not \(want). "
                       + "Either the route is wrong or SPEC §3's table moved — and any frame "
                       + "shot here would be filed under a screen the run never reached.")
    }

    // MARK: - Taps

    private func tap(_ identifier: String, _ path: String) {
        let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 8), "\(path): no control `\(identifier)`.")
        control.tap()
    }

    private func tapPrimary(_ path: String) { tap("onboarding.cta.primary", path) }

    // MARK: - Two frames per screen: early and settled

    /// SPEC §3.3: *"capture two frames per screen, early and settled, and confirm the
    /// settled frame is the composed one."*
    ///
    /// **The two frames DIFFERING is the evidence the reveal ran.** If they are identical
    /// the text did not arrive — it appeared — and the whole motion brief is unmet. That
    /// is asserted rather than left to the eye, because "did it animate" is exactly the
    /// question a still frame cannot answer.
    ///
    /// **Motion is JUDGED, not asserted, beyond that.** This says the reveal happened; it
    /// does not say it looked right. The settled frame is the one to look at.
    private func shootPair(_ name: String, path: String) {
        let early = XCUIScreen.main.screenshot().pngRepresentation
        write(early, "\(path)-\(name)-early.png", path: path)
        Thread.sleep(forTimeInterval: settle)
        let settled = XCUIScreen.main.screenshot().pngRepresentation
        // Written WITHOUT the byte-identical guard: on every screen but `welcome` the two
        // frames are EXPECTED to match, for the reason below, and the guard would fail the
        // run on the instrument's limitation rather than on a defect.
        writeAllowingIdentical(settled, "\(path)-\(name)-settled.png")

        // ─── MOTION IS NOT ASSERTED ANYWHERE. BOTH FRAMES ARE ARTEFACTS. ─────────────
        //
        // **MEASURED 2026-08-03, and it killed the one check that looked like it worked.**
        //
        // Two problems, and together they leave no screen where a screenshot comparison
        // can see an entrance animation:
        //
        //   1. **On every screen reached by a tap, the early frame is not early.**
        //      `arrive()` polls the progress bar to prove which screen this is, and that
        //      round-trip takes LONGER than the reveal's 350ms + stagger. Proving the
        //      screen consumes the window. `pathway`'s two frames are byte-identical.
        //
        //   2. **On `welcome` — the one screen reached by launch, where the early frame IS
        //      early — a THIRD frame taken after the reveal still differs from the second.**
        //      181635 vs 181585 bytes. Something animates continuously: the name field is
        //      focused on appear and **the caret blinks.** So early-vs-settled differing
        //      there proves nothing; it would differ whether or not the reveal ran.
        //
        // > ***The only screen where the early frame is provably early is the only screen
        // > with a caret on it.***
        //
        // **So the honest position is that motion is NOT MEASURABLE BY SCREENSHOT
        // COMPARISON ANYWHERE IN THIS FLOW**, and that is a true statement about our
        // evidence rather than a check that passes for the wrong reason. Same call as the
        // 400ms press-feedback clause: *"not observable with the instruments we have; do
        // not build a harness to close it."*
        //
        // **THE MOTION BRIEF'S STATUS: built, judged by eye, NOT verified by instrument.**
        //
        // > **TWO OPTIONS THAT EXIST AND ARE DELIBERATELY NOT BUILT**, so nobody
        // > re-derives them:
        // > 1. The third frame gives a steady-state noise floor, so an entrance could be
        // >    asserted as *early-vs-settled differs by MUCH MORE than settled-vs-settled2*.
        // >    **It needs a "much more", which is a threshold, and thresholds get tuned
        // >    until they stop failing** — the thing banned on the barrel fit.
        // > 2. Retroactive early-frame identification by three-way comparison against the
        // >    previous screen's settled frame. A harness; same precedent.
    }

    /// Prints the sweep's own coverage limits **into the run's output**.
    ///
    /// **A limitation recorded only in a doc can be mistaken for coverage by someone
    /// skimming a green.** This is read where the result is read.
    private func announceCoverage() {
        print("""
        ONBOARDING-SWEEP COVERAGE
          • MOTION IS NOT VERIFIED BY THIS SWEEP, ON ANY SCREEN. Early frames are not
            early on tapped screens (the arrival proof consumes the 350ms window), and
            on `welcome` — where the early frame IS early — a blinking caret makes any
            two frames differ, so the comparison proves nothing. Both frames per screen
            are ARTEFACTS, not evidence of an animation.
          • Motion status: BUILT, JUDGED BY EYE, NOT VERIFIED BY INSTRUMENT.
          • Reduce Motion is implemented and likewise unverified by instrument.
          • WHAT *IS* ASSERTED, on every path: the route (each arrival proved against
            SPEC §3's exact bar percentage), branch rules 1/3/4 from BOTH ends, the five
            personalisation placements rendering, and the loop clearing the typed name.
        """)
    }

    /// For frames that are EXPECTED to match another — the settled frames on the twelve
    /// screens where the early frame is not early. The dedup guard would otherwise fail the
    /// run on the instrument's limitation rather than on a defect.
    private func writeAllowingIdentical(_ png: Data, _ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(name)
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
    }

    private func write(_ png: Data, _ name: String, path: String) {
        if let clash = taken.first(where: { $0.value == png })?.key {
            return XCTFail("\(name) is byte-identical to \(clash) — the navigation between "
                           + "them did nothing.")
        }
        taken[name] = png
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(name)
        do { try png.write(to: url) } catch { return XCTFail("Could not write \(name): \(error)") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "\(name) reported written and is not on disk.")
    }
}
