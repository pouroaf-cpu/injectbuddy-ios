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
  Without it `xcodebuild` does not forward them, **the suite skips every test and reports success.**
- **`simctl ui content_size` is device state, not run state.** Set it and reset it *in the same
  command*. A left-over accessibility size has already read as "the app broke" once when nothing was
  wrong.
- **The simulator has never been erased**, so nothing here has tested a genuine first run. A green
  suite is not evidence that first-run works.
- **`Tools` is a `List`** — XCUITest surfaces it as a collectionView, not a scrollView, and its rows
  are lazy at accessibility sizes, so `waitForExistence` reports "does not exist" for a row two
  swipes away.
- **You cannot spawn subagents.** Everything on this side is serial. Windows has agents, a browser,
  the PWA source and the database — ask it rather than working around not having them.
- **Never put credentials in an assertion, a failure message, an `.xcresult`, a screenshot or a
  commit.**

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
