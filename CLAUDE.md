# InjectBuddy iOS

**Building on the Mac? Read `docs/MAC-SIDE-README.md` and nothing else to start.** It is one file:
your role, the four docs worth reading cold, how work is verified here, the rig and its traps, and
the message discipline for the paired session.

**Directing from Windows? Read `docs/WIN-SIDE-README.md`.**

InjectBuddy is an **injection-dosing app**. A layout bug that hides a number is a dosing error, not
a cosmetic complaint. That is why the bar here is measurement, not review.

## The four rules that catch the most

**The rules live in `docs/RULES.md`** — all of them, numbered. These four are the ones that catch
the most; each line below is a pointer, and the entry is where the evidence is.

- **Never tick a finding on inspection.** A measurement or a screenshot closes it; unverifiable
  goes to §4 (not knowable), not to a tick. → `RULES.md` rule 41.
- **Internally consistent code is not evidence.** Bugs here have repeatedly been correct by
  inspection and wrong against reality. Query the running system. → `RULES.md` §5.1.
- **A green indistinguishable from an absence is not evidence.** Make a check fail on purpose before
  trusting it green, and ask which layer actually observes the thing being asserted.
  → `RULES.md` §5.24.
- **The unit test suite does not cover UI wiring.** All 27 passed while a dose field displayed 100
  and the engine computed 300; that gap is what the XCUITest target exists for.
  → `RULES.md` rule 42.

Rules 41 and 42 have no `§5.` form yet — `BoardRuleCitationTests` still resolves `§5.NN` against
`BOARD.md`, which stops at 39. Cite them by name until that test is repointed.

And the corollary that keeps paying out: **the least-surveyed screen is the highest-prior defect,
not the lowest.** The one screen never captured at large text held the worst finding on the board.

## Reference, when you need it

| File | What it is |
|---|---|
| `docs/MAC-SIDE-README.md` | **Mac startup. Start here.** |
| `docs/WIN-SIDE-README.md` | Windows startup. |
| `docs/WHERE-WE-ARE-2026-08-03.md` | Current state, plain language, for a cold reader. |
| `docs/SPEC-2026-08-03-HUMAN-TASKS.md` | The live queue — H1–H12, from the owner. |
| `docs/DATA-CONTRACT.md` | **What the database accepts. Authoritative for web, iOS and Android.** |
| `docs/RULES.md` | **The numbered rules — project law.** 1–39 lifted from BOARD §5, 40–43 authored since. |
| `docs/ui-audit/BOARD.md` | Open, closed-with-evidence, not-knowable. Still carries a copy of §5's rules 1–39. |
| `docs/DESIGN-PARITY.md` | Colour roles, type scale, screen-header rule. §8 is the settled palette. |
| `docs/ui-audit/2026-08-02-current/` | What the app looks like now. |
| `docs/ui-audit/archive/` | The 2026-08-01 per-cycle folders. An audit trail, not current state — don't read `cycle3` as now. |
| `docs/WELCOME-AND-ONBOARDING.md` | Welcome screen and onboarding spec. |
| `docs/START-HERE.md` | The long session log — the story of *why*. Not a startup doc. |

**Retired — do not read, do not follow:** `docs/archive/INSTRUCTIONS.md`,
`docs/archive/AGENT-WORKFLOW.md`, `docs/archive/ACTIVE.md`. They describe a multi-agent
claim-a-row arrangement that no longer exists and a greenfield project that has since been built.
They moved into `docs/archive/` on 2026-08-02 — see `docs/archive/README.md` for what else is in
there and why.

## Facts that are not obvious from the code

- **`project.yml` generates `Info.plist`.** Hand edits are destroyed by `xcodegen generate`. Put
  plist keys in `info.properties`.
- **The app is light-only.** `UIUserInterfaceStyle: Light` is locked; all dark paths were removed
  deliberately. Don't reintroduce one.
- **iOS writes to Supabase directly via PostgREST** and never calls `/api/dosages`. Dedup is a
  unique index on `(user_id, calculator_type, config)`. `user_id` must be present on every write or
  RLS refuses it silently.
- **The auth session lives in the Keychain**, so uninstalling the app does not sign you out —
  `simctl erase` does.
- **The PWA source is not in this repo.** It lives on the Windows machine at `Projects\Injectbuddy`.
  Anything derived from it must be written into a doc here or the building side cannot see it.
- **No `lineLimit` on a value+unit pair, or on a screen title.** Units vanishing at large text was
  the worst finding of the audit.
- **QA credentials** are in `.env.local` (gitignored) as `DEVTOOLS_TEST_EMAIL` /
  `DEVTOOLS_TEST_PASSWORD`, and `xcodebuild` only forwards host environment carrying the
  **`TEST_RUNNER_`** prefix — without it the UI suite *skips and reports success*. Never commit
  them; never screenshot an unmasked login form. Use that account, never the owner's.
