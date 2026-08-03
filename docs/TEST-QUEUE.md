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
