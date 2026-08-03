# Mac side — read this first, then start

You are the **Mac half of a paired Claude session** on InjectBuddy iOS. A Claude Code session on a
Windows box is the other half. It directs and makes the final call. **You have the toolchain it does
not** — Xcode, the simulator, XCUITest, the framebuffer — so you see things it cannot. Say so when
you do; four of its calls have been wrong and all four were caught here, by measurement.

InjectBuddy is an **injection-dosing app**. A layout bug that hides a number is a dosing error, not
a cosmetic complaint. That is the whole reason the bar here is measurement rather than review.

---

## 1. Startup — four files, in this order

1. **`WHERE-WE-ARE-<latest date>.md`** — current state in plain language. Start here.
2. **`ui-audit/BOARD.md` §1 and §5** — what is open, and the numbered rules. §5 is the only part
   you need cold; the rest is reference you read when you touch it.
3. **`SPEC-2026-08-03-HUMAN-TASKS.md`** — the live queue, H1–H12, from the owner.
4. **`DATA-CONTRACT.md`** — if you are touching anything that reads or writes the database.

**`TASKLIST` on the cross-claude bus** is the live queue state. Read it before claiming work.

Everything else in `docs/` is reference. Do not read it on startup. `START-HERE.md` is the long
session log behind these — go there when you need the story of *why*, not to begin.

**Retired, do not read:** `INSTRUCTIONS.md`, `AGENT-WORKFLOW.md`, `ACTIVE.md`. They describe a
multi-agent arrangement that no longer exists and a project that no longer needs scaffolding.

## 2. Talking to Windows — keep it short

**Message volume is a cost, not a free channel.** Both sides push instantly and context clears eat
messages. The rules:

- **Report at item boundaries only.** Not while working, not on starting, not on progress. One
  message when an item is finished or genuinely blocked.
- **Never send a message whose only content is agreement, acknowledgement, or a restatement of what
  the other side just said.** Silence is the correct reply to those.
- **Do not reply to a `done`.** It closes a thread. Exception: it explicitly asked you to check
  something, or you have a real correction.
- **Anything longer than a message goes into git as a spec or a doc, not onto the bus.** Commits
  survive context clears; messages do not.
- **Messages cross.** Check the channel before sending; if something newer has superseded what you
  were about to say, drop it.
- One message carrying three findings beats three messages. Batch at the boundary.

## 3. How work is verified here

- **Nothing is ticked on inspection.** Everything closed in `BOARD.md` was closed by a measurement
  or a photograph. Unverifiable goes to "not knowable", never to a tick.
- **Internally consistent code is not evidence.** Repeatedly, code has been correct by inspection
  and wrong against reality. Query the running system.
- **Reproduce the defect and watch the assertion go red before trusting it green.** Ask which layer
  actually observes the thing being asserted.
- **A green indistinguishable from an absence is not evidence.** Eight checks have now been caught
  reporting success while observing nothing.
- **Confirm a check measures the right element at its current aim before widening it.** An aim gap
  and an addressing gap look identical from outside and the remedies are opposite.
- Report layout as a **percentage of the content area**, never in lines.
- **The primary action must be reachable without scrolling at every text size — and so must the
  input it commits.**

## 4. The rig, and the traps

iPhone 16 Pro simulator, iOS 18.3.1, booted, signed in as the QA account.

- **Credentials** come from `.env.local` (gitignored) and **must** carry the `TEST_RUNNER_` prefix.
  **Corrected 2026-08-03 — the mechanism is the reverse of how it reads.** `xcodebuild` forwards
  host variables carrying `TEST_RUNNER_` **and strips the prefix on the way through**. The host sets
  `TEST_RUNNER_QA_EMAIL`; the test reads `env["QA_EMAIL"]`. Getting that pairing backwards is
  indistinguishable from having no credentials at all.
  Proved by paired run, same test, same build: **without** the prefix — `Executed 1 test, with 1
  test skipped`, **RC=0, TEST SUCCEEDED**, 42s. **With** it — `Executed 1 test, with 0 failures`,
  126s of real execution. A skip and a pass are the same exit code, so **a UI run made without the
  prefix proves nothing while appearing green.**
  **Audited 2026-08-03 — there is NO broad suspect window, so do not launch a re-verification
  sweep on the strength of this note.** The read side (`env["QA_EMAIL"]`) has been byte-identical
  since the credential gate was introduced, and the first gated run produced output only an
  executing run can emit. What was corrected here was the *doc's explanation* of the mechanism, not
  the practice. Two sub-claims are genuinely undecidable — both are "and nothing else broke"
  regression clauses recorded as a bare `Executed N tests, with 0 failures` — which is the lesson:
  **record the invocation and per-test output, not the summary line.** A summary line differs from
  a skip by one word in a transcription nobody can re-check.
- **ANY RUN GATED ON AN ENVIRONMENT LEVER CAN REPORT SUCCESS BY NEVER RUNNING. Assert that the
  lever ARRIVED — never that the run returned zero.** Two known levers, and two instances make it a
  class rather than a pair of quirks:
  - `TEST_RUNNER_QA_EMAIL` / `_PASSWORD` (above) — without them: 1 test skipped, **RC=0**, 42s.
  - **`TEST_RUNNER_CAPTURE=1`** — without it the capture suite **skips and exits 0 in 0.25 s**.
    Found 2026-08-03; a 0.25 s green is the tell, and nothing else about the output distinguishes it.
  The pattern that works is already in the tree: have the **app publish its resolved value** and
  assert on that, the way the pinning gate publishes `GATE ax=… size=… cap=…`. A lever the run
  never saw and a lever the run saw and satisfied are indistinguishable from the exit code alone.
- **NEVER READ A RUN LOG OR AN `.xcresult` END TO END TO FIND ONE THING IN IT. Extract first, hand
  over the extract.** `grep -A/-B` around the marker takes seconds; `xcresulttool` the specific
  object rather than opening the bundle. This applies to agents as much as to you.
- **AN AGENT'S PROGRESS LABEL IS NOT ITS PROGRESS.** Recorded 2026-08-03: a label read
  *"Reading ADD-FLOW OBSERVATION block in p1.log"* for forty minutes and was watched from outside as
  a stall. It was not one. `p1.log` was **31K** — a second's read — last written **an hour earlier**,
  and the agent had produced a fresh 35K measurement log **one minute** before the check. **The
  label was stale; the work was not.** Diagnose from artefacts — file mtimes, sizes, `pgrep` for
  `xcodebuild`/`simctl`, and whether anything was committed — **never from the label**, and never
  restart on the strength of one. The label is the only signal a watcher outside the session has,
  which is exactly why it must not be trusted as evidence.
- **`simctl ui content_size` is device state, not run state.** Set it and reset it *in the same
  command*. A left-over accessibility size has already read as "the app broke" once when nothing was
  wrong.
- **The simulator has never been erased**, so nothing here has tested a genuine first run. A green
  suite is not evidence that first-run works.
- **`Tools` is a `List`** — XCUITest surfaces it as a collectionView, not a scrollView, and its rows
  are lazy at accessibility sizes, so `waitForExistence` reports "does not exist" for a row two
  swipes away.
- **You CAN spawn subagents, and you can query the database directly.** Both halves of the old note
  here were wrong and were corrected 2026-08-03 after a session ran a dozen concurrent agents and
  read production Postgres over MCP. Windows still owns the **PWA source** — that is not in this
  repo and cannot be inferred from a doc in it; ask, do not guess. What is genuinely serial is the
  **rig**: one simulator, one framebuffer, one `content_size`.
- **"UNCOMMITTED" IS NOT ONE STATE. Work at risk and work in progress are opposite conditions that
  look identical from outside the tree.** Before committing an agent's working tree, **ask the agent
  whether it is done.** If it cannot answer, commit to a **scratch branch**, never to the line of
  history that reads as a decision.
  Recorded against `a4e60db`, 2026-08-03: uncommitted lines on a shared control had already been
  eaten twice that day, so the instruction was to commit them — sound about the risk being looked
  at. But the author was mid-thought. The commit captured `CalculatorScreen.swift` between two
  edits — **2 references to types with 0 definitions — and left HEAD unbuildable**, on top of
  freezing a mechanism its own author had already determined was wrong. **A SHA reads as a
  decision** whatever the message says.
- **TAKE THE RIG LOCK: `scripts/rig-lock.sh acquire "what you are doing"`, and `trap … EXIT` to
  release it.** It refuses loudly and names the PID holding the device. Discipline failed twice
  before this existed; a point-in-time `pgrep` cannot prove exclusivity because something can start
  a second later — one did, 28 seconds after a clean check.
- **NOTHING STARTS A DEVICE-TOUCHING TASK WHILE ANOTHER DEVICE-TOUCHING TASK IS ALIVE — INCLUDING
  ANYTHING *YOU* SPAWN.** The rule used to say "one runner owns the device" and had an unstated
  actor: it bound the workers and exempted the person spawning them. Recorded 2026-08-03, because
  that is exactly how it failed — two agents were each told they were sole owner of the rig, ran UI
  tests against one simulator, and edited one test file with no commit between them. The numbers
  survived (55 minutes disjoint, same instrument both ends, size read from the app's probe), but
  **the code that produced them was a mixture nobody could reconstruct**, and a green you cannot
  attribute is not evidence.
  **Before spawning anything that touches the device: `pgrep -fl 'xcodebuild|simctl|XCTest'` and
  `xcrun simctl ui booted content_size`. Observe exclusivity, never assert it** — and check the
  artefacts, not the roster, because a label is not progress.
- **A worker can only ever vouch for its OWN invocations.** If you are told the rig is exclusive,
  **check it yourself first** — that check is the worker's job before it measures anything, and it
  is what caught the failure above. Being told you are the sole owner is not evidence that you are.
- **One runner owns the device for a whole session; nobody else touches it.** Everyone else files an
  entry in `docs/TEST-QUEUE.md` and the runner batches them. **Batch by SIGN-IN, not by build** —
  measured 2026-08-03: cold build 258s, **no-op rebuild 11s**, unit suite 45s wall / 1.2s execution,
  one real signed-in UI test 159s wall. Harness overhead is ~41s per run regardless of content, so
  the build is not the bottleneck once DerivedData is warm — sign-in is, at ~20–25 signed-in
  checks/hour.
- **A batch does not go to the runner until it compiles locally.** A runner burned 349s discovering
  a tree left mid-rewrite by a concurrent agent. A failing build that belongs to someone else's
  half-finished file is not information.
- **Padding is additive to `minHeight`.** A control that sets `minHeight: 44` and then adds vertical
  padding renders taller than 44 — measure the resulting frame rather than assuming the floor is the
  height. (The tokens themselves are `DESIGN-PARITY.md` §11.)
- **One serial and one log row per frame.** A capture without its serial cannot be matched to the
  run that produced it, and a montage or downscaled composite is not a frame you may take a number
  off.
- **Never put credentials in an assertion, a failure message, an `.xcresult`, a screenshot or a
  commit.**

**RETIRED 2026-08-03 — the Calendar dose-tap hazard is struck, on evidence.**
It is recorded here only so nobody reinstates it from an older doc. Both conditions the
hazard named were met in one run: a build carrying `user_id` on the `dose_log` insert and in
the `unlogDose` predicate was installed, **and** a dose was written and read back —
`dose_log` 14 → 15, `user_id=c8926abc…`, `created_at=2026-08-03 06:20:47.108362+00`,
confirmed by a second reader querying production directly. `logDose` and `unlogDose` no longer
have opposite outcomes. **Struck because it was measured, not because the commit landed.**

## 5. Facts that are not obvious from the code

- **`project.yml` generates `Info.plist`.** Hand edits die at `xcodegen generate`. Plist keys go in
  `info.properties`.
- **The app is light-only.** `UIUserInterfaceStyle: Light` is locked and every dark path was removed
  deliberately. Do not reintroduce one.
- **iOS writes to Supabase directly via PostgREST** and never calls `/api/dosages`. Dedup is a
  unique index on `(user_id, calculator_type, config)`. **`user_id` must be present on every write**
  — omitting it is how "saving a protocol from iOS had never worked" happened, every insert refused
  by RLS.
- **The auth session lives in the Keychain.** Uninstalling does not sign you out; `simctl erase`
  does.
- **The PWA source and the database are on the Windows box.** Anything derived from them must be
  written into a doc here or this side cannot see it.
- **No `lineLimit` on a value+unit pair or a screen title.** Units vanishing at large text was the
  worst finding of the original audit.

## 6. Where state lives

| What | Where |
|---|---|
| Live queue | `TASKLIST` on the cross-claude bus. **Ephemeral.** |
| Durable record | git — `BOARD.md`, `DECISIONS-*.md`, `SCREENSHOT-LOG.md`, the specs |
| Cold-start doc | `WHERE-WE-ARE-<latest date>.md` |
| Current screenshots | `ui-audit/2026-08-02-current/` — per-cycle folders are an audit trail, not current state |
| Database contract | `DATA-CONTRACT.md` |
