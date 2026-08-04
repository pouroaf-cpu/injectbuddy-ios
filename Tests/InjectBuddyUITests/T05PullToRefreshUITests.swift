import XCTest

// ─── T-05 — why a pull on the Calendar fires nothing ─────────────────────────
//
// THE OPEN QUESTION. `.refreshable { await reload() }` stood on `CalendarScreen`
// and fired nothing: Supabase's API log — an observer outside the app and outside
// the suite — showed ZERO requests after the initial read, while the identical
// gesture on the identically-shaped Dashboard re-read within 3s one minute later
// in the same run. The affordance was removed rather than shipped as a lie. The
// cause was never found, and `CalendarScreen` lists three candidates with the
// instruction to kill one on the device rather than in a source read.
//
// THIS SUITE KILLS CANDIDATE (A): `RouteContent.titleDisplayMode` gives the
// dashboard `.inline` and every other tab root a LARGE navigation title, and a
// large title owns the pull-down stretch above a plain ScrollView. The dashboard
// is the only root without one, and it is the only root whose pull works.
//
// WHY IT MEASURES THE CLOSURE AND NOT THE NETWORK. The original measurement could
// only see requests that reached Supabase, so "the closure never ran" and "it ran
// and the request was suppressed downstream" were indistinguishable. `reload()`
// now increments a counter BEFORE its await and `t05_probe` publishes it, so this
// asks the narrower question directly: did the refresh action run at all.
//
// ── RUN IT, BOTH WAYS, AND THE RED ONE FIRST ─────────────────────────────────
//
//   scripts/rig-lock.sh acquire t05 "T-05 pull experiment" || exit 1
//   trap 'scripts/rig-lock.sh release t05' EXIT
//
//   # (1) CONTROL — large title, the shipping condition. Expects NO increment.
//   TEST_RUNNER_T05_EXPERIMENT=1 \
//     xcodebuild test … -only-testing:InjectBuddyUITests/T05PullToRefreshUITests/testPullUnderLargeTitle
//
//   # (2) CANDIDATE — inline title, the dashboard's setting. Expects +1.
//   TEST_RUNNER_T05_EXPERIMENT=1 TEST_RUNNER_CALENDAR_INLINE_TITLE=1 \
//     xcodebuild test … -only-testing:InjectBuddyUITests/T05PullToRefreshUITests/testPullUnderInlineTitle
//
// `xcodebuild` STRIPS the `TEST_RUNNER_` prefix — the host sets
// `TEST_RUNNER_T05_EXPERIMENT`, the app reads `T05_EXPERIMENT`. Both tests assert
// the flags ARRIVED before asserting anything about behaviour, because a run under
// a flag the app never saw is green either way and this project has already filed
// evidence gathered exactly that way.
//
// WHAT EACH OUTCOME MEANS, written down before the run so the result cannot be
// read to suit whatever comes back:
//   • control 0, candidate +1  → candidate (A) CONFIRMED. The large title is the
//     mechanism, and every future screen with a large title silently will not
//     refresh — which is why this matters with the affordance already removed.
//   • control +1               → the defect no longer reproduces. Something since
//     2026-08-03 fixed it (batch 4 stopped `load` blanking to `.loading`, which is
//     named as the cheapest candidate). The affordance can come back, and (A) is
//     NOT established — do not claim it.
//   • control 0, candidate 0   → (A) is dead. Move to (B) the harness's scroll
//     target, or (C) `reload()` mutating @State before its await.
final class T05PullToRefreshUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // ── THE FORWARDING STEP, AND IT IS TWO HOPS, NOT ONE ────────────────────
        //
        // The first run of this suite went red on its own "did the flag arrive?"
        // guard, and the guard was right. `xcodebuild` copies host variables
        // prefixed `TEST_RUNNER_` into the TEST RUNNER's environment with the prefix
        // stripped — that is the trap CLAUDE.md records. What CLAUDE.md does not say,
        // because nothing had needed it before, is that the runner and the APP UNDER
        // TEST are different processes. `ProcessInfo.processInfo.environment` read
        // inside `CalendarScreen` is the APP's environment, and nothing puts the
        // runner's variables there.
        //
        // So the chain is: host sets `TEST_RUNNER_T05_EXPERIMENT` → runner sees
        // `T05_EXPERIMENT` → THIS LINE puts it in `launchEnvironment` → app sees it.
        // `CaptureCurrentState` already does exactly this for `BAR_SHARE_CAP` and
        // `PLATE_MATERIAL`; this suite simply did not, and would have run the app in
        // its default configuration while the filenames and assertions claimed
        // otherwise.
        //
        // WORTH SAYING PLAINLY: without the arrival assertion this would have been a
        // FALSE CONFIRMATION, not a failure. The app would have launched with the pull
        // unarmed, the probe would have read zero reloads in BOTH conditions, and the
        // control would have "reproduced the defect" perfectly while the candidate
        // showed no improvement — which reads as "candidate (A) is dead" and would
        // have sent the next person to chase (B) and (C) for nothing.
        for key in ["T05_EXPERIMENT", "CALENDAR_INLINE_TITLE"] {
            if let value = ProcessInfo.processInfo.environment[key] {
                app.launchEnvironment[key] = value
            }
        }

        app.launch()
    }

    func testPullUnderLargeTitle() throws {
        let reloads = try runPull(expectingInline: false)
        XCTAssertEqual(reloads.after, reloads.before,
                       "CONTROL CONDITION REFRESHED. The defect does not reproduce on this "
                       + "build, so candidate (A) is not established by the other test — "
                       + "something since 2026-08-03 fixed the pull. Read T-05's outcome "
                       + "table before recording anything.")
    }

    func testPullUnderInlineTitle() throws {
        let reloads = try runPull(expectingInline: true)
        XCTAssertGreaterThan(reloads.after, reloads.before,
                             "Inline title did NOT restore the pull — candidate (A) is dead. "
                             + "Next candidates are (B) the harness's scroll target and "
                             + "(C) reload() mutating @State before its await.")
    }

    // MARK: - The one shared body

    private func runPull(expectingInline: Bool) throws -> (before: Int, after: Int) {
        tab("Calendar")

        let probe = app.descendants(matching: .any).matching(identifier: "t05_probe").firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 10),
                      "t05_probe absent — DEBUG build?")

        // THE FLAGS ARRIVED, asserted before anything else is believed.
        XCTAssertTrue(probe.label.contains("experiment=true"),
                      "T05_EXPERIMENT=1 never reached the app — the pull is not even "
                      + "armed, so a zero increment would mean nothing. Probe: \(probe.label)")
        XCTAssertTrue(probe.label.contains("inline=\(expectingInline)"),
                      "CALENDAR_INLINE_TITLE did not arrive as \(expectingInline). This run "
                      + "would be filed under a condition the app never saw. "
                      + "Probe: \(probe.label)")

        // Wait for the initial load to settle, so the count is stable before the pull.
        let before = try count(from: probe)
        var settled = before
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.5)
            let now = try count(from: probe)
            if now == settled { break }
            settled = now
        }

        // ── THE WINDOW, IN UTC, PRINTED FOR AN OBSERVER THIS SIDE CANNOT SEE ──────
        //
        // Closing T-05 needs the half a reload counter cannot reach: did a REQUEST
        // leave the device. Windows has read access to the database's API log — the
        // same observer that condemned the affordance originally — and cannot touch
        // the device; this side drives the device and cannot see the log. So the pull
        // is timestamped and the window handed over.
        //
        // NEITHER SIDE CAN FAKE IT, and that is the point of doing it this way: a
        // closure that fires without a request looks identical, from here, to a
        // closure that fires with one.
        //
        // The quiet gap matters as much as the timestamps. The screen's own initial
        // load also hits the API, so without separation the pull's read and the
        // arrival read are one indistinguishable burst in the log — and "a request
        // arrived" would prove only that the app launched.
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime]
        stamp.timeZone = TimeZone(identifier: "UTC")

        // STAMPED BEFORE THE SLEEP, AND THE FIRST VERSION WAS NOT.
        //
        // It stamped `quietFrom` AFTER the 8 seconds, so the printed value was where
        // the quiet period ENDED — identical to `pull-at`, which reads as a zero-length
        // gap and makes the whole discriminator look absent. The silence was really
        // there; the label pointed at the wrong boundary.
        //
        // Small, and it is the same failure as the rest of today in miniature: an
        // instrument reporting something adjacent to what it claims. The handoff of
        // this window to an observer who CANNOT see the device is exactly where a
        // mislabelled boundary does damage — they would have had eight seconds of
        // arrival traffic and a gap they were told was empty.
        let quietFrom = stamp.string(from: Date())
        Thread.sleep(forTimeInterval: 8)

        let pullAt = stamp.string(from: Date())
        print("T05-WINDOW quiet-from=\(quietFrom)")
        pullDown()
        // Generous: the assertion is about whether the closure ran at all, and a slow
        // reload must not read as "never fired".
        Thread.sleep(forTimeInterval: 5)
        let pullEnd = stamp.string(from: Date())

        let after = try count(from: probe)
        print("T05 inline=\(expectingInline) before=\(settled) after=\(after) probe=\(probe.label)")
        print("T05-WINDOW pull-at=\(pullAt) pull-end=\(pullEnd) "
              + "reloads=\(settled)->\(after) inline=\(expectingInline)")
        return (settled, after)
    }

    /// The gesture. Deliberately NOT `scrollContainer()`-style "first hittable
    /// scroll-ish element" — that ambiguity is candidate (B), and an experiment must
    /// not contain the mechanism it is testing for. This drags from a point inside
    /// the calendar content downward, which is what a user does.
    private func pullDown() {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    private func count(from probe: XCUIElement) throws -> Int {
        // `reloads=<n> experiment=<bool> inline=<bool>`
        let label = probe.label
        guard let range = label.range(of: "reloads="),
              let value = Int(label[range.upperBound...].prefix(while: \.isNumber))
        else {
            throw XCTSkip("t05_probe label not parseable: \(label)")
        }
        return value
    }

    /// WAITS FIRST, and that is the whole of the fix. The first run of this suite failed
    /// `No hittable Calendar tab` at 57s — not because the tab is unreachable but
    /// because this asked for it before the app had finished launching and
    /// authenticating over the network. The shipped `CaptureCurrentState.tab` waits 8s
    /// for existence before filtering for hittable, and this now does the same.
    ///
    /// `max(by: midY)` picks the LOWEST match: `Calendar` is both a tab-bar item and a
    /// word that appears in screen content, so `.firstMatch` is a coin toss that
    /// resolves to whichever the tree happens to yield first.
    private func tab(_ name: String) {
        let matches = app.buttons.matching(identifier: name)
        XCTAssertTrue(matches.firstMatch.waitForExistence(timeout: 15),
                      "No \(name) tab appeared within 15s — did the app finish launching?")
        let lowest = matches.allElementsBoundByIndex
            .filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }
        XCTAssertNotNil(lowest, "\(name) exists but nothing hittable.")
        lowest?.tap()
        _ = app.wait(for: .runningForeground, timeout: 2)
    }
}
