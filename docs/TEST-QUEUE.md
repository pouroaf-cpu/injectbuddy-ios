# TEST-QUEUE

One simulator, one runner. **No agent other than the test-runner touches the device.**

Every other agent, when its change is ready, appends an entry below by **shell append**
(`cat >> docs/TEST-QUEUE.md <<'EOF' ... EOF`) — never by rewriting the whole file, because
several agents append concurrently.

The runner takes entries in order, **batches everything sharing a build** (the build is the cost,
not the run), executes, writes the result into the entry, and reports back to the filing agent.

Runner rules:
- Set **and reset** `content_size` in the same command, every time. A left-over large-text setting
  has already been misread once as "the app broke".
- `xcodegen generate` runs **only** when a file is added to or removed from the project definition.
- Re-run only what decides a board item, and only once.

## Entry format

```
### Q<n> — <title>            [filed by: <agent>] [status: QUEUED|RUNNING|PASS|FAIL]
- Changed: <what changed, files>
- Must answer: <the question the run decides>
- Invocation: <exact command>
- Report to: <agent>
- Result: <filled in by runner>
```

## Queue

<!-- append entries below this line -->

### Q1 — does the app TELL the user when a dose log fails to save?   [filed by: mac] [status: QUEUED]
- Changed: nothing. This is a diagnostic run against existing behaviour, and it decides a SAFETY finding.
- Background, measured against production 2026-08-03 (not inferred from source):
  `dose_log.user_id` is `uuid NOT NULL`, `column_default` NULL, and there are **zero triggers** on the
  table. RLS `dose_log_owner_all` is ALL with `WITH CHECK ((SELECT auth.uid()) = user_id)`.
  iOS's `NewDoseLogPin` (Models.swift) carries `protocol_id, dosed_on, draw_ml, site` and **no
  `user_id`**. All 14 live rows carry `scheduled_on`, `protocol_label` and a non-null `draw_ml` —
  none of which any iOS call site writes — and the newest is 2026-07-29. **No iOS-written row has
  ever landed in `dose_log`.**
- Must answer: when the user taps to log a dose in the running app, does the UI report failure, or
  does it show the dose as logged? Three call sites: LogDoseSheet, DashboardViewModel,
  CalendarViewModel. A NOT NULL violation should throw — but every call site discards the result
  with `_ =` and at least one is a tap toggle. **If the tap reads as success, this is a dosing app
  telling a user an injection is recorded when nothing was written.**
- Do NOT fix it in this run. Observe and report only; the fix is the directing side's call.
- Invocation: drive the log-dose path on device with the QA account (TEST_RUNNER_ prefix — without
  it the UI suite skips and reports success), watch for an error surface, then query
  `select count(*) from dose_log where site is not null and scheduled_on is null;` — an iOS-written
  row is the one shape that has never existed.
- Report to: mac
- Result:

### Q2 — result bar as one control + content-area screen title   [filed by: calc-screen] [status: QUEUED]
- Changed: `Sources/InjectBuddy/Features/Calculators/CalculatorScreen.swift` only.
  **B** — `SPEC-RESULT-SHEET-AND-SYRINGE §1/§2` build steps 1–2. The five-rung pinning
  gate, its hidden candidates and its 0.40 cap are DELETED. The pinned bar is now one
  definition: `See your result` (`cta_see_result`, opens a `.sheet` with `.medium`/`.large`
  detents carrying the numbers) beside `Add` (`cta_add`, unchanged), with `ViewThatFits`
  choosing row-vs-stacked by layout rather than by type size. No result card is pinned.
  The in-scroll `ResultCard` stays and now renders EVERY row, so `result_<label>` is one
  element on one surface again; the sheet's copy uses `sheet_result_`.
  Also `SegmentedRow` (the syringe barrel, **11 calculators**): `.lineLimit(2)` REMOVED —
  the labels are value+unit pairs (`0.3 mL (30u)` …) and the ban is absolute — replaced
  with a `ViewThatFits` row/column fallback; each option now carries
  `control_syringeMl_<label>`, so the barrel enters `inputControls()` in the existing
  reachability sweep with no change to that suite. `.minimumScaleFactor(0.8)` deliberately
  LEFT in place (H1, deferred).
  **C** — H5 built as `DESIGN-PARITY §9` OPTION (a): a content-area `ScreenHeader`
  (`screen_title`, mark + title, no `lineLimit`, wraps freely). **Not `.principal`** —
  §9's addendum measured `.principal` clipping a third line silently. The inherited
  `RouteContent` large title is demoted with `.navigationBarTitleDisplayMode(.inline)`
  as an interim; the shared fix belongs in `RouteContent` and is reported, not written.
- Must answer:
  1. **Bar proportion at DEFAULT size on `trt`.** Read `bar_gate` — it now publishes
     `area=`, `bar=` and `share=` from the renderer. Expected: `share` well under the
     0.5240 the finding recorded and under the retired 0.40 cap. Report the number, and
     cross-check `bar_plate.frame` against it (the two must agree).
  2. **Are the barrel buttons reachable?** `control_syringeMl_*` are new and are picked up
     by `PinnedBarReachabilityUITests.inputControls()` automatically. Expected: none
     straddles the plate, all four scroll fully into view.
  3. **Do the barrel labels show their units at large text?** Same control, at AX5 — the
     full string (`0.3 mL (30u)`, not `0.3 mL (…`) must be visible on a calculator using
     `syringeMl`. Screenshot; the accessibility layer returns model text and cannot
     answer this.
  4. **Is the calculator name shown as a content-area header, and does it wrap?**
     `screen_title` exists, is `.isHeader`, and at AX5 on `Steroid Dosage` the whole
     string is visible — the open `Steroid Dos…` finding is what this closes. Confirm
     there is exactly ONE title on screen (the interim `.inline` demotion is what makes
     that true; if two are visible, say so — that is the `RouteContent` change).
  5. **Same four on ONE calculator outside the top five: `Retatrutide`.** Deliberately not
     TRT/Reconstitution/Steroid — those are the three screens every prior sweep aimed at,
     and the least-surveyed screen is the highest-prior defect.
  6. **RED FIRST, then green.** `TEST_RUNNER_BAR_SHARE_CAP=0.55` no longer drives a gate;
     it is honoured as a legacy alias for `FORCE_PINNED_RESULT=1`, which restores the
     pinned result card and reproduces the 52% panel. The reachability sweep must go RED
     with it set (sheared `Frequency` on TRT at default) and GREEN without it. A green
     with no prior red proves nothing here — `SPEC §8` names this as a pass condition.
  7. Known expected-failure entry `Steroid Dosage / field_mgWeek / AX5` — report whether it
     still shears. If it has stopped, the suite says to delete the entry; if the stacked
     branch of the bar made AX5 taller than the old Add-only floor, say so, because that
     is the one place this change could regress.
- Invocation:
    xcodegen generate   # NOT needed — no files added to or removed from the project
    # red first
    TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… TEST_RUNNER_BAR_SHARE_CAP=0.55 \
      xcodebuild test -project InjectBuddy.xcodeproj -scheme InjectBuddy \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      -only-testing:InjectBuddyUITests/PinnedBarReachabilityUITests
    # then green, plus the frames
    xcrun simctl ui booted content_size large
    TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… \
      xcodebuild test -project InjectBuddy.xcodeproj -scheme InjectBuddy \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      -only-testing:InjectBuddyUITests/PinnedBarReachabilityUITests \
      -only-testing:InjectBuddyUITests/ProbeAttachmentUITests \
      -only-testing:InjectBuddyUITests/CalculatorWiringUITests
    xcrun simctl ui booted content_size accessibility-extra-extra-extra-large
    # …re-run for the AX5 frames on Steroid Dosage and Retatrutide, then RESET:
    xcrun simctl ui booted content_size large
- Report to: calc-screen (via the directing side)
- Result:
