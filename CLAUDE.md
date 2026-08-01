# InjectBuddy iOS — read before working

**Read `docs/START-HERE.md` first.** It is the session log: what was built, every
issue hit and how it was fixed, and where to pick up. It will save you rediscovering
a day's worth of findings.

Then, as needed:

| File | What it is |
|---|---|
| `docs/ui-audit/BOARD.md` | **Authoritative state.** Open, closed-with-evidence, not-knowable, and the rules. |
| `docs/DESIGN-PARITY.md` | Colour roles, type scale, screen-header rule. §8 is the settled palette. |
| `docs/ui-audit/2026-08-01-current/` | **What the app looks like now.** Per-cycle folders are an audit trail, not current state. |
| `docs/WELCOME-AND-ONBOARDING.md` | Spec for the welcome screen and onboarding. |
| `docs/ui-audit/calculator-reference/` | The PWA calculator, which is the parity target. |

## How work is verified here

This is a dosing app. The bar is measurement, not review.

- **Never tick a finding on inspection.** Everything closed in `BOARD.md` was
  closed by a measurement or a screenshot. If it can't be verified, it goes in
  §4 (not knowable) rather than getting a tick.
- **Internally consistent code is not evidence.** Three separate bugs this
  session were correct by inspection and wrong against reality. Query the
  running system.
- **The unit test suite does not cover UI wiring.** All 27 tests passed while a
  dose field displayed 100 and the engine computed 300. That's what the XCUITest
  target exists for.
- **No `lineLimit` on a value+unit pair, or on a screen title.** Units vanishing
  at large text was the worst finding of the audit.

## Facts that are not obvious from the code

- **`project.yml` generates `Info.plist`.** Hand edits are destroyed by
  `xcodegen generate`. Put plist keys in `info.properties`.
- **The app is light-only.** `UIUserInterfaceStyle: Light` is locked; all dark
  paths were removed deliberately. Don't reintroduce one.
- **iOS writes to Supabase directly via PostgREST** and never calls
  `/api/dosages`. Dedup is a unique index on `(user_id, calculator_type,
  config)`. Some source comments still describe the old assumption.
- **The auth session lives in the Keychain**, so uninstalling the app does not
  sign you out — `simctl erase` does.
- **The PWA source is not in this repo.** It lives on the Windows machine at
  `Projects\Injectbuddy`. Anything derived from it must be written into a doc
  here or the building side cannot see it.
- **QA credentials** are in the webapp's `.env.local` as `DEVTOOLS_TEST_EMAIL` /
  `DEVTOOLS_TEST_PASSWORD`. Never commit them; never screenshot an unmasked
  login form. Use that account, never the owner's.
