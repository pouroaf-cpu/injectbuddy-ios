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

        pullDown()
        // Generous: the assertion is about whether the closure ran at all, and a slow
        // reload must not read as "never fired".
        Thread.sleep(forTimeInterval: 5)

        let after = try count(from: probe)
        print("T05 inline=\(expectingInline) before=\(settled) after=\(after) probe=\(probe.label)")
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

    private func tab(_ name: String) {
        let button = app.buttons.matching(identifier: name)
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(button, "No hittable \(name) tab.")
        button?.tap()
    }
}
