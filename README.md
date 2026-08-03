# InjectBuddy iOS

Native iOS app (Swift / SwiftUI, iOS 16+) for InjectBuddy — opens straight into the cycle-planner
dashboard, with all 14 dosage calculators in a side drawer. Thin client over the existing InjectBuddy
Supabase backend; calculator math is ported to a local, offline `CalculatorEngine`.

Working branch: **`feature/tabview-shell`**. The app is **light-only** — dark mode was removed
deliberately and locked in `project.yml`; don't reintroduce it.

---

## Starting a fresh session? Read these, in this order

1. **[`docs/START-HERE.md`](docs/START-HERE.md)** — the session log. Two days of findings, what broke,
   how it was fixed, and where to pick up. Written so you don't re-derive a day's work.
2. **[`CLAUDE.md`](CLAUDE.md)** — how work is verified here, and the facts that aren't obvious from
   the code.
3. **[`docs/ui-audit/BOARD.md`](docs/ui-audit/BOARD.md)** — authoritative state. Open, closed-with-
   evidence, not-knowable, and the rules.
4. **[`docs/HARNESS-AND-LOOSE-ENDS.md`](docs/HARNESS-AND-LOOSE-ENDS.md)** — the workshop floor. Rig
   state, credentials, and the guards in the test harness.

**Current state (2026-08-02):** working tree clean, 27 unit tests + 4 wiring assertions + the
truncation sweep green at default and AX5.

**Next up, and the order matters:** onboarding + Settings Personalisation, building the **Settings
surface first and the wizard second**. Built the other way round, an unfinished feature writes units
and timezone once at signup with no screen that can edit them — a one-way door. `onboarding_completed_at`
is stamped only by the wizard, never by a Settings save, which is what makes Settings-first safe.
Full field-by-field contract in [`docs/PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md`](docs/PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md) §C2.

---

## This is a dosing app — how work is verified

The bar is measurement, not review. Four things earned that bar the hard way:

- **A displayed number that disagrees with the computed one has now appeared three times.** A field
  read `100250` while the engine used `1000`. A dose truncated to `1…`. A result panel showed a
  correct answer for a dose hidden off screen. All three passed every check that existed at the time.
- **Internally consistent code is not evidence.** Query the running system.
- **The unit tests do not cover UI wiring.** All 27 passed while a field displayed 100 and the engine
  computed 300.
- **A check that cannot fail is worse than no check.** Four were removed in one day — a
  test-continuation flag that photographed the wrong screen, a suppressed keyboard that flattered a
  fix, byte-identical frames passing as fresh, and an assertion reading the accessibility layer's
  model text instead of the rendered glyphs. **None of them were wrong about anything. They were
  silent about everything**, and their green was indistinguishable from their absence.

Practical rules that follow:

- **Never tick a finding on inspection.** If it can't be verified it goes in `BOARD §4`, not a tick.
- **No `lineLimit` on a value+unit pair or a screen title** — and note that banning `lineLimit` was
  necessary and *not sufficient*: layout reached the same truncation without it.
- **Every audit opens with a judgment pass, at every text size**, before anything is measured.
  Metrics are a floor, not a verdict.
- **Measure layout as a share of the visible screen, not in lines.** "58% of the content area"
  compares across screens and sizes; "three lines" compares to nothing.
- **The primary action must be reachable without scrolling at every text size — and so must the input
  it commits.** An action you can reach for a value you can't is worse than one you can't reach,
  because the second one stops you.
- **The least-surveyed screen is the highest-prior defect, not the lowest.** The one screen never
  captured at large text held the worst finding on the board, and the bug turned out to span eight
  calculators.

---

## Requirements

- macOS 13+ with **Xcode 15+**
- [XcodeGen](https://github.com/yonwoo9/XcodeGen) (`brew install xcodegen`) — the Xcode project is
  generated from `project.yml`, so it is never checked in.

## First build (on a Mac)

```bash
# 1. Provide Supabase credentials (gitignored)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
#    edit Config/Secrets.xcconfig and fill in SUPABASE_URL + SUPABASE_ANON_KEY

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open InjectBuddy.xcodeproj
#    select the InjectBuddy scheme → an iOS 16+ simulator → ⌘R
```

Swift Package dependencies (`supabase-swift`) resolve automatically on first open.

> **`Sources/InjectBuddy/Resources/Info.plist` is GENERATED — never hand-edit it.**
> `project.yml` declares an `info:` block, so `xcodegen generate` rewrites that file
> from scratch and silently discards anything you added directly. On 2026-07-31 this
> ate `CFBundleURLTypes`, which registers the `com.injectbuddy.ios` scheme — with it
> gone, the signup confirmation email and the Discord OAuth callback both had nowhere
> to land, while the verify screen still told users to click the link. It took
> `UIApplicationSceneManifest` and `ITSAppUsesNonExemptEncryption` with it. Add plist
> keys under `targets.InjectBuddy.info.properties` in `project.yml` instead, then
> re-run `xcodegen generate` and confirm the key survives.

## Running the tests

```bash
# Unit tests — CalculatorEngine + DoseProjection
xcodebuild test -only-testing:InjectBuddyTests

# UI wiring + truncation sweep. The TEST_RUNNER_ prefix is MANDATORY.
TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… \
  xcodebuild test -only-testing:InjectBuddyUITests
```

> **Without the `TEST_RUNNER_` prefix the suite skips and reports `** TEST SUCCEEDED **`.**
> `xcodebuild` does not pass shell environment into the runner process. The first run of these
> tests reported success while executing nothing. Credentials live in a gitignored `.env.local`
> — variable names and path are in `HARNESS-AND-LOOSE-ENDS §2`.

Never let a credential into an assertion, a failure message, an `.xcresult`, a screenshot or a
commit. The `.xcresult` bundle is the easy one to forget — it captures the screen at each failure.

**Set and reset the Dynamic Type size in the same command.** `simctl ui content_size` is device
state, not run state; a capture run left at AX5 makes the next wiring run fail all four assertions
against a reflowed layout, which reads exactly like "the app broke".

## Screenshots

Every capture gets a serial — `IB` + 7 digits, sequential, never reused — in the filename, plus a row
in [`docs/ui-audit/SCREENSHOT-LOG.md`](docs/ui-audit/SCREENSHOT-LOG.md) recording what it shows, when
it was taken, the commit, and which defects were live at that commit. A re-shoot gets a **new**
serial; that is the point. No visible stamp inside the image — these frames get measured, and a stamp
would mean the file is no longer what the device rendered.

`docs/ui-audit/2026-08-02-current/` is the current state. Per-cycle folders are an audit trail, not
the app as it stands.

## Layout

```
Sources/InjectBuddy/
  App/        app entry + RootView (auth gate)
  Core/
    Theme/      palette + type scale (text-style based, so it tracks Dynamic Type)
    Models/     Codable mirrors of the Supabase tables
    Nav/        NavItems — the single source for drawer items (Dashboard, Calendar, 14 calcs, Settings)
    Backend/    BackendClient protocol + Supabase (PostgREST/RLS) implementation
    Auth/       AuthStore (Supabase session), Keychain persistence
    Calculator/ CalculatorEngine (ported math) + per-slug specs
  Features/
    Auth/       login / signup / reset
    Shell/      MainShell + off-canvas DrawerView
    Dashboard/  cycle-planner (default screen)
    Calculators/ generic CalculatorScreen(slug) + Cycle Plotter
    Calendar/   30-day injection calendar
    Onboarding/ DisclaimerGate + WelcomeView
    Settings/   profile, units, Discord, sign out
Tests/InjectBuddyTests/    CalculatorEngine golden tests + calendar projection tests
Tests/InjectBuddyUITests/  wiring assertions + geometric truncation sweep
```

## Backend

Reuses `Injectbuddy` (Next.js + Supabase). The app authenticates with `supabase-swift` and reads/writes
the user's own rows (`saved_dosages`, `cycles`, `cycle_items`, `dose_log`, `profiles`) directly through
PostgREST under row-level security — no backend changes. Calculator formulas are ported verbatim from
the web `public/app.js` and locked with golden unit tests.

**iOS never calls `/api/dosages`.** It writes straight to PostgREST, so nothing server-side validates
the payload. Dedup is a unique index on `(user_id, calculator_type, config)` — deliberately *not*
`.upsert`, which PostgREST resolves to `ON CONFLICT DO UPDATE` and would overwrite `start_date`,
shifting every projected dose.

`user_id` must be set explicitly on inserts. Reads omit it because RLS scopes SELECTs; carrying that
assumption into the write path made every insert fail the `WITH CHECK` — iOS protocol saving had never
worked until this was found.

## The PWA is not in this repo

It lives on the Windows machine at `Projects\Injectbuddy`. Anything derived from it has to be written
into a doc here or the building side cannot see it. Two are already written, from the web source and
the live database rather than from memory:

- [`docs/PWA-SPEC-MISSING-CALCULATORS.md`](docs/PWA-SPEC-MISSING-CALCULATORS.md) — `bioavailability`,
  `femalehrt`, `oilblend`. Formulas, lookup tables, ranges, and the exact saved `config` shape.
- [`docs/PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md`](docs/PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md) — real
  column shapes for `dose_log`, `vial_inventory` and `profiles`, the Personalisation contract, and
  eighteen places the web UI and the database disagree.

Three traps from those documents, repeated here because they fail silently:

- **The server does not validate `bioavailability`, `femalehrt` or `oilblend`** — a wrong config shape
  is accepted without error, and iOS has no server in the path at all.
- **`femalehrt` saves `doseIdx`, an array index, not the dose.** Reordering a dose array silently
  changes what every saved row means. Those arrays are append-only.
- **88 of 89 live profiles have `timezone = NULL`** while the personalisation API rejects null.
  Design for the null case as the norm, not the edge.

## Notes

- **No secrets in source.** The Supabase anon key lives only in `Config/Secrets.xcconfig` (gitignored)
  and is surfaced to the app via the build setting / Info.plist.
- Any handoff to a web page uses `SFSafariViewController` (shared cookies + correct referrer), never a
  bare `WKWebView`.
- **The auth session lives in the Keychain**, so uninstalling the app does not sign you out —
  `simctl erase` does.
- Two screenshots from 2026-08-01 contain the owner's real email and avatar. The repo is private;
  that is a blocker on ever making it public.
