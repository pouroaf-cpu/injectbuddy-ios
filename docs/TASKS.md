# Injectbuddy iOS — Tasks

Build backlog for the native iOS app. See `WIREFRAME-PLAN.md`. Claim a task (`🔄` + your agent-id)
and a row in `ACTIVE.md`. When done + pushed, move the block to the Done archive.

> **Where things live (2026-08-01).** These 10 planning docs used to sit one directory ABOVE the git
> root, so they were never in the repo and never reached a clone. They now live in `docs/` and are
> tracked. If you cloned before this landed, that is why `TASKS.md` and `CALC-MATH.md` appeared to be
> missing — they were not lost, just outside the repo.
>
> **The design/maths reference is a separate repo:** `github.com/pouroaf-cpu/injectbuddy-design-refs`
> — DESIGN-SPEC.md, ANIMATIONS.md, 71 screen captures, and the 599-case maths contract
> (`spec/` 299 + `fixtures/` 300). Clone it beside this one. Read its README first.
>
> **Check your branch.** `main` does NOT have the shell rewrite. `feature/tabview-shell` is 4 commits
> ahead and carries TASK 14/15 (`b0eabbf` bottom tab bar, Tools/Add funnel, confirm-start-day).

Status legend: ⬜ To do · 🔄 In progress · ✅ Done (archived)

> **2026-06-05 (bison30):** TASKS 1–8 are **code-complete on Windows** but kept `🔄` (not `✅`)
> because their Definition of Done requires an Xcode build + simulator run, which is impossible on
> this Windows box. They flip to `✅` after the Mac build/verify pass (see STATUS.md). Code is in the
> local repo `app/` (commit `646f115`).

---

## Phase 0 — scaffold

## TASK 1 — Scaffold the Xcode project   🔴 P0   🔄 (bison30) code-complete, needs Mac build
- **Issue:** No Swift project exists.
- **Fix:** Create SwiftUI app (iOS 16+), SPM, app target + unit/UI test targets. Add `supabase-swift`.
  Set bundle id, signing, `.xcconfig` for the Supabase anon key (gitignored). Create the iOS Git repo.
- **Affected:** new project root, `Package.swift`/Xcode project, `.xcconfig`
- **Status:** ⬜ To do

## TASK 2 — Auth + RootView gate   🔴 P0   🔄 (bison30) code-complete, needs Mac build
- **Issue:** App must require sign-in before the dashboard.
- **Fix:** `AuthStore` (Supabase session), `AuthFlow` (login/signup/reset), `RootView` switching on
  auth. Persist session in Keychain. Discord-link parity if feasible.
- **Affected:** `AuthStore`, `AuthFlow`, `RootView`
- **Status:** ⬜ To do

---

## Phase 1 — shell & dashboard

## TASK 3 — MainShell + side drawer   🔴 P0   🔄 (bison30) code-complete, needs Mac build
- **Issue:** Need the off-canvas drawer (the "sidebar") over a NavigationStack.
- **Fix:** `MainShell` with hamburger + `DrawerView` (scrim, swipe-to-open/close, spring anim).
  Sections: Profile, Dashboard, Calendar, all 14 Calculators, Settings/Sign out/Theme. Items from a
  single `NavItems.swift`. iPad → `NavigationSplitView`.
- **Affected:** `MainShell`, `DrawerView`, `NavItems.swift`
- **Status:** ⬜ To do

## TASK 4 — DashboardScreen (cycle-planner, default)   🔴 P0   🔄 (bison30) code-complete, needs Mac build
- **Issue:** App must open into the cycle-planner.
- **Fix:** Build the dashboard: next-dose summary, cycle timeline, saved-protocol cards. Load from
  `/api/me` + protocols/cycles. This is the default content screen.
- **Affected:** `DashboardScreen`, `DashboardViewModel`, `APIClient`, models
- **Status:** ⬜ To do

---

## Phase 2 — calculators & rest

## TASK 5 — CalculatorEngine (ported math)   🔴 P0   🔄 (bison30) code-complete + golden tests, needs Mac run
- **Issue:** Calculator math must match the web exactly.
- **Fix:** Port formulas from `Injectbuddy/public/app.js` into a pure-Swift `CalculatorEngine`. Add
  golden unit tests comparing against known web outputs for all 14 calculators.
- **Affected:** `CalculatorEngine`, tests
- **Status:** ⬜ To do

## TASK 6 — CalculatorScreen × 14   🟠 P1   🔄 (bison30) code-complete, needs Mac build
- **Issue:** Each calculator needs a native form.
- **Fix:** Generic `CalculatorScreen(slug)` driven by per-calculator field configs; live results from
  `CalculatorEngine`; "Save protocol" → backend. Wire all 14 into the drawer.
- **Affected:** `CalculatorScreen`, field configs
- **Status:** ⬜ To do

## TASK 7 — CalendarScreen   🟠 P1   🔄 (bison30) code-complete, needs Mac build
- **Issue:** 30-day injection calendar.
- **Fix:** Project due dates from protocol frequency over a rolling 30-day window (match the web logic).
- **Affected:** `CalendarScreen`, projection util
- **Status:** ⬜ To do

## TASK 8 — SettingsScreen + theming   🟡 P2   🔄 (bison30) code-complete, needs Mac build
- **Issue:** Settings, theme toggle, account, sign out.
- **Fix:** Settings list; light/dark theme override (teal accent); Discord link; sign out.
- **Affected:** `SettingsScreen`, theme store
- **Status:** ⬜ To do

## TASK 9 — TestFlight pipeline   🟡 P2   🔄 (bison30) fastlane + GH Actions written; needs GitHub secrets + ASC setup (app/SIGNING.md) + first CI run on Mac
- **Issue:** Need distribution.
- **Fix:** Archive + TestFlight upload (fastlane optional). Document signing.
- **Affected:** CI/signing
- **Status:** ⬜ To do

## TASK 10 — App Store Optimisation (ASO) metadata   🟡 P2   🔄 (bison30) drafted, needs human finalize
- **Issue:** Review panel (SEO, 2026-06-05): the App Store is a search engine; title/subtitle/keyword
  field are harder to change post-launch than code, and ASO installs feed brand search → E-E-A-T.
- **Fix:** ✏️ Drafted in `launch/ASO.md` (title/subtitle/keywords/description/promo + competitor note).
  Remaining: human pick final variants, run a live App Store competitor search, paste into App Store Connect.
- **Affected:** store metadata (not code)
- **Status:** 🔄 In progress (content drafted)

## TASK 12 — Submission content + App Review readiness   🟠 P1   🔄 (bison30) drafted, needs human finalize
- **Issue:** A dosage/health app needs a hosted privacy policy, App Privacy answers, and a review-safe
  posture (Apple 1.4.1) before it can be submitted.
- **Fix:** ✏️ Drafted in `launch/` (APP-PRIVACY.md, PRIVACY-POLICY.md, APP-REVIEW-NOTES.md) and a first-run
  disclaimer gate shipped in-app. Remaining: fill the `<<CONFIRM>>` items (entity, support email,
  jurisdiction, dates), host the privacy policy at a public URL, create a seeded demo reviewer account.
- **Affected:** `launch/*`, App Store Connect
- **Status:** 🔄 In progress (content drafted)

## TASK 13 — Supabase prod config for the iOS client   🔴 P0 (blocks OAuth)   ⬜
- **Issue:** Discord OAuth from the app won't complete until the redirect is allow-listed, and signup
  should use leaked-password protection (security advisor WARN, 2026-06-05).
- **Fix:** In the Supabase dashboard (project `injectbuddy` / rktklvutvbombuajrvrv): add
  `com.injectbuddy.ios://login-callback` to Auth → URL Configuration → Redirect URLs; enable
  Auth → leaked-password protection. (RLS already verified enabled on saved_dosages/dose_log/cycles/
  cycle_items/profiles — the app's direct writes are scoped.)
- **Affected:** Supabase dashboard (no code)
- **Status:** ⬜ To do

## TASK 11 — Guard CalculatorEngine against web drift   🟡 P2   ⬜
- **Issue:** Review panel (SEO/Engineer, 2026-06-05): the Swift port and web `app.js` can silently
  diverge over time; a wrong result in a health niche is an E-E-A-T wound.
- **Fix:** Add a CI/test step that re-derives the golden vectors from the current `public/app.js` (or a
  shared fixtures file) so a web math change breaks the iOS suite and forces a re-sync. Keep `CALC-MATH.md`
  as the spec of record.
- **Affected:** `Tests/InjectBuddyTests/CalculatorEngineTests.swift`, CI
- **Status:** ⬜ To do

---

## Phase 3 — parity rewrite against the current mobile web

> **2026-07-30 (lemur87), operator-directed.** The `Features/` UI layer was written 2026-06-05 and
> targets a version of the product that no longer exists. Measured against the web app today
> (`Injectbuddy`, branch `feature/dosage-status-model`):
>
> | | iOS now | mobile web now |
> |---|---|---|
> | Dashboard | 3 files | ~30 components (vial ledger, supply alerts, site rotation, serum chart, dose history, badges, cycle progress, lab highlights, tabs, log flow) |
> | Routes | 4 (dashboard/calendar/calculator/settings) | 12+ account surfaces + calendar, community, peptide-tracker |
> | Primary nav | off-canvas drawer only | 5-slot bottom nav (Dashboard · Calendar · Log-dose hero · Tools · Add) **plus** the drawer |
> | Saving | inline "Save as protocol" on the calculator | Save removed; the Add slot owns it, ending on a confirm-start-day step |
>
> Operator's call: treat `Features/` as **rewrite, not port**. Building the current screens first would
> only verify the wrong app, so the Mac pass moves to the END of this phase (TASK 19).
>
> **Do NOT rewrite these — they are current, correct, and expensive to re-derive:**
> `Core/Calculator/*` (engine + 14 golden vectors, pinned by the web repo's `spec/`),
> `Core/Calendar/DoseProjection.swift`, `Core/Backend/*` (PostgREST + RLS — deliberate, the web
> `/api/*` is cookie-auth and unusable from a bearer-token client), `Core/Models`, `Core/Auth`,
> `Core/Theme`, `Features/Onboarding/DisclaimerGate.swift`, `launch/`, fastlane + CI.
>
> **Sequencing risk to accept knowingly:** the web design is on an UNMERGED branch (production is
> `1ce88c21`). Every hour spent porting before that branch is promoted is chasing a moving target.

## TASK 14 — Shell: TabView + raised Log-dose hero   🔴 P0   🔄 (lemur87) lean pass done, needs Mac build
- **Issue:** iOS's primary navigation is the off-canvas drawer. The web moved to a 5-slot fixed bottom
  bar; the drawer survives there but is no longer how people move around.
- **Fix:** Rewrite `MainShell` as a SwiftUI `TabView` (operator's choice: native, not a hand-rolled copy
  of the web bar — system safe-area and accessibility behaviour comes free) with a custom overlaid
  centre Log-dose button. Slots: Dashboard · Calendar · **Log dose** · Tools · Add. **Keep the drawer**
  behind Tools, as on web, so all 14 calculators + Settings stay reachable and the edge-swipe survives.
  Add `.tools`, `.add`, `.addConfirm(id:)` to `AppRoute`.
- **Affected:** `Features/Shell/*`, `Core/Nav/NavItems.swift`
- **Status:** ⬜ To do

## TASK 15 — Add flow + the start_date gap   🔴 P0   🔄 (lemur87) lean pass done, needs Mac build
- **Correction (lemur87, 2026-07-30):** an earlier draft of this task said "nothing ever writes
  `start_date`". **That was wrong** — `CalculatorViewModel.save` does write it via
  `NewSavedDosage.startDate`. The real gap is that it is hardcoded to **today**, silently: add a
  protocol you actually began three weeks ago and every occurrence `DoseProjection` places is shifted
  by three weeks, with nothing on screen saying so. Smaller than "unprojectable", still worth fixing.
- **Issue:** (a) Saving lives on the calculator (`CalculatorScreen`), which the web has removed in
  favour of the Add slot. (b) The start day is assumed, never confirmed.
- **Fix:** Mirror the web. Remove the inline Save. Add becomes contextual: on a calculator with a valid
  result it saves and goes to confirm-start-day; anywhere else it opens the funnel at "what are you
  adding?" → category (`hormone` / `glp1` / `peptide` / `steroid`) → calculator. Exclude the 4
  calculators that cannot save (bmi, plotter, freetest, ftv) — the picker should offer exactly 19.
  Confirm screen: read the saved row back, show `label` + config, take a start day (default today,
  built from LOCAL date parts), PATCH `start_date`, return to Dashboard.
- **Affected:** `Features/Calculators/*`, new `Features/Add/*`, `Core/Backend/BackendClient.swift`
- **Reference:** web `components/account/add/AddFlow.tsx`, `ConfirmStart.tsx`, `public/ib-bottomnav.js`
- **Status:** ⬜ To do

## TASK 16 — Dashboard rewrite   🔴 P0   ⬜  ← scope DECIDED 2026-08-01: FULL PARITY
- **Issue:** The iOS dashboard is 3 files against ~30 web components. It is the app's home screen and
  the widest single gap.
- **Fix:** Rewrite to **full parity — all ~30 components**. Operator's call, 2026-08-01: no reduced
  v1 set.
- **Sequencing this forces:** some components have no iOS surface behind them, so **TASK 18 becomes a
  hard prerequisite for that subset** rather than a P2 nice-to-have. Blood-test lab highlights need the
  blood-tests surface (5 web routes + the Anthropic extraction pipeline); badges need the badge system.
  Build the independent components first — vial ledger, supply alerts, site rotation, serum chart, dose
  history, cycle progress, tabs, log flow — then land TASK 18's surfaces, then the components that read
  from them.
- **Affected:** `Features/Dashboard/*`
- **Reference:** web `components/account/dashboard/` (30 components); design-refs
  `screens/01-dashboard-*.png`. NOTE: the serum chart is a blank band on `01-dashboard-populated.png`
  because the web tree had uncommitted edits at capture time — treat it as "chart goes here", not as
  the intended design.
- **Status:** ⬜ To do

## TASK 17 — Calendar rewrite   🟠 P1   ⬜
- **Issue:** Built against the old dashboard model; the web calendar and the dose-log/pin model have
  moved on. `DoseProjection` itself stays — this is the screen, not the maths.
- **Affected:** `Features/Calendar/*`
- **Status:** ⬜ To do

## TASK 18 — Account surfaces iOS has never had   🟠 P1 (was P2 — raised by the TASK 16 decision)   ⬜
- **Issue:** Missing entirely: blood tests (5 web routes incl. AI extraction), progress/body metrics,
  cycle planner, chat, suggestions, community. Each is a feature, not a screen.
- **Fix:** Decide per surface whether v1 ships it, defers it, or links out to the web. Blood tests in
  particular is a sub-app with an Anthropic extraction pipeline behind it.
- **Why it moved:** TASK 16 is now full parity, and the lab-highlights and badge components cannot be
  built until their surfaces exist. This is no longer optional for the dashboard to complete.
- **Status:** ⬜ To do

## TASK 19 — Mac build + verify the REWRITTEN app   🔴 P0   ⬜
- **Issue:** Nothing in this phase is compilable on Windows, and the app has never been built at all —
  so the first build will surface pre-existing errors and rewrite errors together.
- **Fix:** Runs LAST, after 14–17. `brew install xcodegen`; fill `Config/Secrets.xcconfig`;
  `xcodegen generate`; build; simulator run. Confirm the 15 golden tests + projection tests still pass
  (they should — the engine is untouched). Then the old TASK 1–8 DoD items flip to ✅ or are retired as
  superseded by this phase.
- **Caveat (2026-08-01):** "the golden tests pass" is a much weaker guarantee than it reads as — see
  TASK 20. Treat a green TASK 19 as "it compiles and runs", NOT as "the maths is right".
- **Status:** ⬜ To do

## TASK 20 — Fixture-driven conformance runner (replaces the golden tests)   🔴 P0   ⬜
- **Issue:** `CalculatorEngineTests.swift` asserts 15 spot values against a GOLDEN TEST VECTORS table
  in `CALC-MATH.md` — a hand-derived table. `testBmiImperial` already documents a disagreement with it
  (the table says 25.81, the JS formula gives 25.8245) and asserts the formula instead. Meanwhile the
  real contract is 599 machine-derived cases. 15 hand-picked values is not conformance.
- **Fix:** Build a Swift conformance runner over the design-refs package:
  - Load `spec/vectors/*.json` (10 corpora, 299 cases) **first** — it is the primary contract — then
    `fixtures/*.json` (21 corpora, 300 cases).
  - **Assert `specVersion` matches what the port implements and fail loudly on mismatch.** That is the
    mechanism that stops a stale app computing last month's answer.
  - Port the `compare()` in `spec/verify-vectors.mjs` — it is the NORMATIVE implementation. Relative
    tolerance `1e-9` for intermediate floats; **exact** equality for displayed/rounded values, strings,
    integers, booleans and `null`. Do not invent a local notion of "close enough".
  - Decode `{"$nonFinite": "NaN"|"Infinity"|"-Infinity"}`. **A port returning `null` or `0` where the
    reference returns `NaN`/`Infinity` must FAIL, not be flattened.**
  - Evaluate every date-dependent case in `America/New_York`; set the test `Calendar`'s timeZone
    explicitly, never rely on the device or CI default.
  - Retire the 15 golden tests and the dangling `CALC-MATH.md` GOLDEN TEST VECTORS reference once green.
- **Two engine defects this will surface** (both already visible by inspection, neither fixed):
  1. **Rounding.** `CalculatorEngine.swift` uses bare `.rounded()` at lines 174, 238, 254, 276, 279,
     plus `CalculatorEvaluate.swift:19` on the DISPLAY path (which fixtures compare *exactly*). Swift
     rounds half away from zero; JS `Math.round` rounds half up. Implement
     `roundHalfUp(x) = floor(x + 0.5)` and `roundTo(x, dp)` as named helpers and use them everywhere.
     No such helper exists in `Core/Calculator/` today.
  2. **The guarded/unguarded split is probably not modelled.** `trt`/`eod`/`steroid` return `Infinity`
     and `NaN` by design on empty input; `hcg`/the GLP-1s/`bpc157`/`peptide`/`reconstitution`
     short-circuit to `0`. Same product, opposite behaviour, deliberate. Also `bpc157blend` rounds each
     leg *then* sums (so `totalUnits != round(totalMl * 100)`), `glp1titration.vials` uses `ceil` while
     `hcg.dosesPerVial` uses `floor`, and `glp1titration` does NOT round its unit counts while the
     standalone GLP-1 pages do. Reproduce each exactly; do not harmonise them.
- **Affected:** `Tests/InjectBuddyTests/*` (new runner), `Core/Calculator/*` (rounding helpers + the
  null/NaN contract). NOTE `Core/Calculator` is otherwise on the do-not-rewrite list — this task is the
  sanctioned exception, and it is a correctness change, not a cleanup.
- **Reference:** `injectbuddy-design-refs` — `spec/math-spec.md` §2.1/§2.2/§2.4/§3.2/§5/§6,
  `spec/verify-vectors.mjs`, `fixtures/README.md` (coverage map + the two day-one traps).
- **Supersedes:** the "confirm the golden tests still pass" clause in TASK 19.
- **Status:** ⬜ To do

## TASK 21 — Plotter: adopt the compound bible, drop the local tmax table   🔴 P0   ⬜
- **Issue:** The iOS plotter diverges from the web plotter in TWO independent ways, so the same
  protocol draws a different curve on phone and website:
  1. **Different model.** `pk.js:91-97` derives `ka = ln2 / max(0.01, halfLife*0.25)` — `tmax`
     appears nowhere in it. `CalculatorEngine.swift:313-314` instead solves `ka` from a per-compound
     `tmax` via `pkSolveKa`. **No `tmax` value in `CalculatorCatalog.swift:42-55` has a citation** —
     they were typed in.
  2. **Different numbers.** `CalculatorCatalog` is a FOURTH half-life table and disagrees with
     `spec/compounds.json`: Test C `5.0` vs `6.0` days, Test U `20` vs `21`.
- **Decision (operator, 2026-08-01):** one bible in Supabase (`public.compounds`), exported at build
  time to `spec/compounds.json`, bundled by both platforms. Neither reads it at runtime — offline
  must keep working and the conformance suite must stay provable. Full rationale and the migration:
  web repo `spec/COMPOUND-BIBLE.md`.
- **Fix (iOS side):**
  - Delete the `tmax` column and the hardcoded compound list from `CalculatorCatalog.swift`; load the
    exported `compounds.json` from the vendored corpus bundle instead.
  - Replace `pkSolveKa` usage with the two-branch rule: use a sourced `tmax` when present and tiered
    above `unverified`, else fall back to `ka = ln2 / max(0.01, halfLife*0.25)`. **Every compound is
    on the fallback on day one** — no `tmax` is cited yet — so this must reproduce `pk.js` exactly.
  - Honour the null contract: `half_life_days == nil` means not established. Do not render a number,
    do not plot a curve. Currently unenforced on both platforms.
  - Conformance against `pk-kernel.json` (84 cases) and `pk-series.json` must pass. Those corpora
    move when the web side regenerates — **do not start until `SPEC_VERSION` has been bumped**, or
    you will port to a corpus that is about to change.
- **Sequencing:** web steps 4-6 in `spec/COMPOUND-BIBLE.md` land together, THEN this. Blocking on the
  web change is correct here — porting first means chasing a moving target.
- **Affected:** `Core/Calculator/CalculatorCatalog.swift`, `Core/Calculator/CalculatorEngine.swift`
  (`pkSolveKa`, `pkBuildEntries`), `Features/Calculators/CyclePlotterViewModel.swift`
- **Relationship to TASK 20:** TASK 20 builds the conformance runner; this is the first real defect
  it will catch. Do TASK 20 first — without it there is nothing to prove this fix by.
- **Status:** ⬜ To do

---

## ✅ Done (last 10)
_(none yet — TASKS 1–8 stay 🔄 until the Mac build/verify pass; see the note at top.)_
