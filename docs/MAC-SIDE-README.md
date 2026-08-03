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

> **TEMPORARY HAZARD — 2026-08-03. Strike this block when `unlogDose` carries `user_id`.**
> **Do not tap a dose cell on the Calendar tab on the QA account.** The two halves of the log toggle
> have opposite outcomes: `logDose` fails on `dose_log.user_id` being `NOT NULL` with no default,
> while `unlogDose` deletes on `(protocol_id, dosed_on)` with no payload and **succeeds**, because
> RLS `USING` scopes it. Tapping a ticked dose permanently deletes a real row the app cannot
> re-create.
> **The dashboard card is safe** — `NextDoseCard` renders "Mark taken" only in the `!alreadyTaken`
> branch, and `markTaken` is insert-only and cannot reach `unlogDose`. Log from the dashboard
> freely and read the row back. Never toggle on Calendar.
> A hazard that outlives its cause is the `content_size` trap again — delete this block, do not
> leave it as history.

The full test invocation:

```
set -a; . ./.env.local; set +a
TEST_RUNNER_QA_EMAIL="$DEVTOOLS_TEST_EMAIL" \
TEST_RUNNER_QA_PASSWORD="$DEVTOOLS_TEST_PASSWORD" \
xcodebuild test -project InjectBuddy.xcodeproj -scheme InjectBuddy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:InjectBuddyUITests
```

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
