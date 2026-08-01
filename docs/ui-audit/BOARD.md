# Board — UI audit & PWA parity

Single source of truth for what is done, what is open, and what is deliberately
not being done. Supersedes hunting through ten cycle READMEs.

**Mac owns this file.** Tick items as they land, in the same commit as the work.
Do not tick anything on inspection — every closed item below was closed by a
measurement or a screenshot, and that bar holds. If something can't be verified,
move it to §4 rather than ticking it.

**New session? Read `docs/START-HERE.md`, then
`docs/SESSION-HANDOVER-2026-08-01.md`, then `docs/HARNESS-AND-LOOSE-ENDS.md`**
— orientation, narrative, and the workshop-floor detail (why the three UI-test
assertions are red, and what has already been ruled out). Then this file for live
status.

**Also** — how the two
sides work, what broke and why, and the rig state. Then this file for live status.

**Current state is `docs/ui-audit/2026-08-02-current/`.** The per-cycle folders and
`2026-08-01-current` are the audit trail, not the app as it stands — don't open
`cycle3` and read it as now. Every frame from 2026-08-02 onward carries a serial
and a row in `docs/ui-audit/SCREENSHOT-LOG.md`; earlier frames are unserialised
and are not backfilled.

Decisions taken while the human was away are in `docs/DECISIONS-2026-08-02.md`.

Session of 2026-08-02. Branch `feature/tabview-shell`. Latest `3b8b8b1`.

---

## 0. RIG STATE — read this first if you are a fresh session

Things a cold session will hit within minutes and not understand:

- **Synthesized mouse clicks do not reach the Simulator.** Keyboard does
  (`Cmd-Shift-H` backgrounds the app). `AXIsProcessTrusted()` is true and the cursor
  physically moves, so `CGEvent` posts fine at OS level — the Simulator stopped
  accepting synthesized clicks after `simctl erase`, and it survives quit +
  `kill -9` + reopen. A host reboot is the standard fix and is **not required**: see
  the next bullet.
- **Drive the app with XCUITest, not clicks.**
  `xcodebuild test -only-testing:InjectBuddyUITests` works with the mouse dead,
  because it goes through the automation layer inside the runtime and never touches
  the host window server. Probe passes in ~47 s.
- **Screenshots still work** — `xcrun simctl io booted screenshot` reads the
  framebuffer and needs no window server. Every capture tonight was taken this way.
- **DEVICE STATE, corrected 2026-08-02 — the erased/first-boot description below
  is no longer true and a session planning around it will be wrong within
  minutes.** The booted device is iPhone 16 Pro / iOS 18.3. It has **not** been
  erased since 2026-08-01. Both `com.injectbuddy.ios` and
  `com.injectbuddy.ios.uitests.xctrunner` are still installed, the app launches
  straight past the disclaimer to the signed-in dashboard as `devtools` (Keychain
  session survived), and the permission prompts were consumed last session.
  Consequences: `addUIInterruptionMonitor` and `dismissDisclaimerIfPresent` get
  **no coverage** from runs on this device, and **first-boot is now only reachable
  via `simctl erase`, at the cost of the session and a real Supabase sign-in to
  get back.** That last sentence is the part worth remembering.
  *(Historical, for the erased state: the device sat in iOS first-boot with
  "Allow Maps to use your location" and a notifications screen, dismissable via
  `addUIInterruptionMonitor`.)*
- **The app's session lives in the KEYCHAIN, not the container** — `simctl uninstall`
  does NOT sign you out; `simctl erase` does. Established tonight.
- **QA credentials are now on the Mac** at `injectbuddy-ios/.env.local`
  (gitignored via `.env.local` and `.env*.local`, verified with `git check-ignore`
  before the file was written), as `DEVTOOLS_TEST_EMAIL` / `DEVTOOLS_TEST_PASSWORD`
  — the same names as the webapp's file. **Values live only in that file; no doc,
  commit or message carries them.** The runner reads `QA_EMAIL` / `QA_PASSWORD`,
  and `xcodebuild` only forwards host environment carrying the `TEST_RUNNER_`
  prefix — see `HARNESS-AND-LOOSE-ENDS §2`. Never assert on a credential, never let
  one into a failure message or an `.xcresult`, never shoot a login screen with the
  password field unmasked.

## 0b. Rig — mouse dead, XCUITest alive

- [x] **"The DisclaimerGate cannot be dismissed" was WRONG — it was the input path.**
      Keyboard works (`Cmd-Shift-H` backgrounds the app); clicking an app icon or a
      system alert does nothing; `AXIsProcessTrusted()` is true and the cursor moves,
      so `CGEvent` posts fine and the Simulator simply stopped accepting synthesized
      clicks after `simctl erase`. Survives quit + `kill -9` + reopen, twice.
      Claiming a first-run lockout from that was attributing a rig failure to the
      app — §5.1, made twice in one session.

- [x] **XCUITest harness — PROBE PASSES with the mouse still dead.** It drives the
      app through the automation layer inside the runtime, never touching the host
      window server, so it is immune to exactly the failure above. This is the
      infrastructure flagged as missing when the slug sweep failed and again when
      clicks died — two stoppages, now closed.
      `Tests/InjectBuddyUITests`, target in `project.yml`, wired into the scheme.

- [x] **Closed drawer stayed in the accessibility tree — FOUND BY THE HARNESS.**
      First real catch. With the drawer shut, `TRT Dose` resolved at **x = -290**,
      off-canvas, and the tap failed with `kAXErrorCannotComplete`.
      `allowsHitTesting(false)` stops touches; it does **not** remove an element from
      the accessibility tree, so a VoiceOver user could swipe into fourteen
      calculator rows that are not visibly on screen. Fixed with
      `accessibilityHidden(!isDrawerOpen)` alongside the existing hit-testing guard.
      Worth noting how it was found: not by review, and not by a screenshot — a
      screenshot cannot show an element at x = -290. It took something driving the
      accessibility layer.

- [x] **Wiring assertions — FOUR GREEN, at `3b8b8b1`, and two of the three
      "test bugs" were app defects.** Run:
      `TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… xcodebuild test
      -only-testing:InjectBuddyUITests` → `Executed 4 tests, with 0 failures`.
      What each one now proves, rather than that it passed:
      - `testQuickChip_fieldAndResultBothFollow` — a chip moves the field, the
        engine and the result row together, and `result_Weekly total` addresses
        exactly one element while it does so.
      - `testStep_movesByTen` — the ± pair belonging to `mgWeek` moves `mgWeek` by
        its configured step of 10, and vial strength does **not** move. The old
        version incremented vial strength (`buttons["Increase"].firstMatch`) and
        asserted on weekly dose.
      - `testTypeThenChip_neverDesyncs` — with the keypad up the quick values are
        REACHABLE and the field follows them.
      - `testOverRange_fieldNeverShowsANumberTheEngineRejected` — new. Asserts the
        field and the engine agree after any input, not the literal "1000".
      The diagnosis in the previous version of this item was wrong in two places
      and it is worth saying how: `testQuickChip` was not failing on a missing
      element but on an **ambiguous** one — `result_<label>` matched the pinned bar
      and the in-scroll copy, and an ambiguous `XCUIElement` fails at resolution
      before printing any assertion message. And `testTypeThenChip` was not a
      test-side clear-and-type problem; both halves were real app defects (§3).

## 1. Open — assigned

- [ ] **Tools at AX5 reads as broken.** `IB2245731`, and unchanged from
      `2026-08-01-current/10-tools-ax5.png`. Six things in one frame:
      `Semaglu-tide` hyphenated mid-word, `Tirzepatide` wrapping to an orphaned
      `e` on line two, `Retatru-tide`, the `Tools` title clipped against the
      header row above it, icons that stayed small while the text went huge, and
      four rows filling the entire screen. **This frame passed the audit, and
      passed correctly** — that is what §5.15 exists for.
      Constraints on the fix: **no `dynamicTypeSize(...up to:)` cap** on
      calculator names (navigation labels in a dosing app; AX5 users are exactly
      who needs them legible) and **no `lineLimit`**. Direction to try first: fix
      the icon at a sensible size instead of letting the layout starve the label,
      let the row grow vertically since the list scrolls and vertical space is
      cheap, and stop the hyphenation. The title collision is the screen-header
      rule (`DESIGN-PARITY §9`) and probably resolves with it.
      Then re-check the other nine screens at AX5 with the judgment pass, not the
      metric pass — the expectation is that this is not the only one.

- [ ] **The in-scroll `ResultCard` renders unconditionally, so at default type
      size the same rows exist twice.** `result_Weekly total` measured as two
      elements, y=641 (pinned, hittable) and y=896 (in-scroll, not).
      `CalculatorScreen.swift`'s F12 comment says the breakdown renders in the
      scroll *instead* when the bar collapses; the code does not do that. Code and
      comment disagree and the code is what shipped, so the comment is what is
      wrong until someone decides otherwise.
      **Not a divergence risk:** both cards are handed the same `CalculatorResult`
      value and cannot disagree. Addressing was the only problem and it is fixed
      (`result_` / `detail_result_`). What is left is a product question — whether
      a user scrolling to the bottom should meet the same three dose figures twice.

Welcome + onboarding — spec in `docs/WELCOME-AND-ONBOARDING.md`. Three pieces, not
one: the auth flow already exists and is not being rebuilt.

- [~] **2. Restyle `AuthFlowView` — CODE DONE, VISUALLY UNVERIFIED.** Builds, tests
      green. Not screenshotted: the simulator holds a signed-in session and
      `AuthFlowView` only renders when signed out. Signing out to photograph it
      would end the session and there is no password on this side to sign back in
      with — it would cost every authenticated screen for the rest of the work.
      Needs either the account password entered by the human, or a throwaway
      account. **Not ticked until measured**, same bar as everything else. `grep -c "Theme.Typeface"` returns **0** — the
      second screen found in that state after the log sheet, and the first screen a
      new user ever sees. Type scale + palette + the 44 pt field family. Secondary
      labels off `#0FBCAD` (2.13–2.38:1) onto `#075E56`. **Behaviour unchanged** —
      validation, cooldown, Discord OAuth and verify all work.
- [~] **1. Animated welcome screen — BUILT, launch frame verified.** Occupies
      `.loading`, fronts `.signedOut` with the two CTAs. Drifting serum-concentration
      curves in a single `Canvas` inside `TimelineView(.animation)`; the mark draws
      via `Path.trim`; staggered fade+rise 60ms apart, 450ms, ease-out; solid fills
      only. Measured: wordmark **7.34:1**, and the band behind the copy samples pure
      `#FAFAFB` on both sides — **the curves do not cross the text block**, which was
      the rule that outranks the aesthetics. Still to verify: the signed-out CTA
      path and the mid-transition text measurement.
      <details><summary>original brief</summary>
- [x] **1. Animated welcome screen.** Occupies `.loading`, fronts `.signedOut`.
      **Animation duration is a ceiling, never a floor** — a returning signed-in
      user must never wait on it. Solid fills only, no multi-stop gradient on text
      (measured, §3). Reduce Motion → final state immediately. Text measured
      **mid-transition**, not only at rest.</details>
- [ ] **3. Five-step onboarding — AND the Settings surface that edits the same data.
      One feature, not two.** `DashSettings`' Personalisation tab collects exactly
      what onboarding collects: nickname, units, measurements, timezone, interests.
      **Ship onboarding alone and a user sets those once at signup and can never
      change them** — wrong unit, wrong timezone, changed their mind about what they
      track, no way back. That is a one-way door and it would be ours.
      So: onboarding writes the profile, Settings edits it, same fields, same
      validation, same NOT NULL discipline, field components built once and used in
      both. Mirrors the PWA's `STEP_META`. Three NOT NULL
      columns plus a NOT NULL array — **a skipped step writes the DEFAULT, never a
      null**. `onboarding_completed_at` set only on completion. Store metric, don't
      round on the way in (180 lb must return 180 lb). Step 3 collects value+unit
      pairs, the exact shape that truncated before, so it reflows at AX5.

- [x] **Calculator quick buttons — VERIFIED.** Tapping 400 sets the field to 400
      and the result to 400.0 mg/week; the barrel row renders four buttons with the
      selection navy-filled. Caught a real bug doing it: the quick button wrote the
      binding but `NumberField`'s local text state did not follow, so the field
      displayed **100 while the calculator computed 300**. A dosing field showing a
      different number from the one being used is not a styling defect. Fixed by
      syncing text on external value changes, skipped while focused so it cannot
      fight live typing. `2026-08-01-quickbuttons/`.
      <details><summary>original</summary>
- [x] **Calculator quick buttons — code done.** Builds, tests
      green. Barrel is now a 4-button segmented row instead of a menu; dose fields
      carry one-tap values (TRT weekly 100/200/300/400/500, and per-calculator sets
      for EOD, microdose, HCG, peptide, BPC-157, steroid); the TRT and steroid
      weekly-dose steppers step in **10s** rather than 1s. Vial strength
      deliberately has no quick values — it is set once per vial, not per dose.
      Typing still works everywhere. Not screenshotted: the Mac's GUI session
      dropped again mid-verification (Finder also reports 0 windows), so taps are
      dead and the calculator cannot be navigated to.</details>

- [ ] **Type scale missing on TEN screens, not two.** `AddScreen`,
      `ConfirmStartScreen`, `CyclePlotterScreen`, `CalendarScreen`, `DisclaimerGate`,
      `SettingsScreen`, `DrawerView`, `ToolsScreen`, `MainShell`, `RouteContent`.
      Only Dashboard, `CalculatorScreen`, `LogDoseSheet` and `AuthFlowView` have it —
      and two of those four only because they were fixed today.
      So the log sheet was never an outlier; it was the first one anyone looked at.
      This is §5.7 — attention follows complaints rather than risk — with a number
      attached, and the number is **10**.
      Two worth calling out: **`DisclaimerGate` is the first screen any new user
      sees**, before welcome and before auth, and it is stock system type. And
      `CyclePlotterScreen` is Swift Charts, whose axis marks, legends and
      annotations carry their own default typography that will NOT follow `Theme`
      after a pass — they need explicit styling or the chart stays system-default
      while the screen around it changes.
      **One item, not ten. Do not start it** — it is a sweep, and sweeps done in a
      hurry are where regressions come from. Scope it with the human after
      onboarding.

- [ ] **Measure Settings and the confirm-start-day screen.** The only two screens
      the control inventory did not reach (a drawer mis-tap landed on BMI). Both
      are stock `Form`/`List` and are *probably* the same 44 pt list-row treatment
      as the log sheet, but that is a guess and guesses do not get ticked.

## 2. Open — unassigned, needs a human decision

- [ ] **Whole sections of the PWA have no iOS screen at all.** The PWA dashboard is
      six tabs; iOS covers three.
      | PWA | iOS |
      |---|---|
      | `upcoming` | Dashboard — have |
      | `history` (`DoseHistory`) | **missing entirely** — no route, no screen |
      | `inventory` (`SupplyAlert`/`MySupply`) | **missing entirely**, and `vial_inventory` is a live table with rows |
      | `saved` (`ProtocolList`) | folded into the dashboard grid |
      | `calculators` (`CalcGrid`) | Tools tab |
      | `settings` (`DashSettings`) | partial |
      `DashSettings` has six sub-tabs — Account, Profile, Personalisation, Badges,
      Metrics, Billing & Plan. iOS Settings has Preferences, Discord, Account and
      display name, so **four of six don't exist**.
- [ ] **Tapping a protocol card goes nowhere.** The cards render a chevron, which
      promises navigation, and there is no protocol detail route — `SCREENS.md`
      specced an edit sheet and even that isn't wired. Worth fixing regardless of
      the bigger IA question: a chevron that promises and doesn't deliver is a
      defect on its own.
- [ ] **Dashboard information architecture.** The PWA dashboard is tabbed
      (`upcoming` / `history` / `inventory` / `saved` / `calculators` /
      `settings`); iOS is one scroll with next-dose plus all protocols. The iOS
      protocol grid corresponds to the PWA's `saved` tab. Adopt the tabbed IA, or
      keep the single scroll and match only the visual language? Out of scope for
      styling parity either way — see `pwa-reference/README.md`.
- [ ] **Three calculators exist on the web with no iOS screen at all:**
      `bioavailability`, `femalehrt`, `oilblend`. Feature gap, not a config bug.
- [ ] **Greeting shimmer.** Solid `#075E56` ships. SwiftUI desaturates *any*
      multi-stop gradient — measured, see §3 — and both fix routes failed. Filed
      approach if it's wanted back: solid text with a **single-colour**
      translucent band swept as a mask, since single-colour gradients measure
      exact. Not started.
      **Mac's read: feasible, with one constraint that decides it.** A translucent
      *white* band would lighten the ink where it passes and drop contrast below
      threshold mid-sweep — the same failure mode as `#5FE8DA`, arrived at from a
      different direction. The band must be `#0A9D90`, so the worst composite is
      3.37:1 and still legal for the 24 pt heavy greeting. Measurable before
      building. Worth one cycle only if the human actually wants the shimmer; the
      screen reads correct without it and every prior attempt cost a cycle.
- [ ] **Inter vs SF.** Deferred, not rejected. SF was chosen because bundled Inter
      costs the Dynamic Type metrics that protect against the truncation class of
      bug. Revisit only with that trade understood.
- [ ] **Tab bar glyphs** are accessible grey (~6:1) rather than brand-coloured.
      **Mac's read: leave it, it reads as deliberate.** iOS convention is a neutral
      unselected item; the brand is already present in the bar via the selected
      item (`#075E56` + bold). Colouring the unselected ones would weaken a
      selected/unselected distinction that was only just fixed from 2.77:1.

### From the control inventory (`2026-08-01-controls/`) — scope before building

The calculator family is universal: numeric ± fields and every menu picker,
including the barrel picker, are **44.0 pt** at default and **77.35 pt** at AX5.
Four things sit outside it.

- [x] **Log-sheet rows** now carry the calculator's bordered language.
- [x] **Log sheet type scale, contrast and rows — all done in one pass.** Eyebrow
      `#85858B` grey → **navy `#001D5C`** semibold (measured). `Cancel`
      **2.13:1 → 6.86:1** (`#0FBCAD` → `#075E56`), the worst number that was left
      in the app. Rows now compound-first with no `lineLimit`, using a shared
      `ProtocolLabel.split` so the dashboard and the sheet cannot drift — the
      latent form of the truncation bug that hit seven dashboard cards is gone
      before it triggered. `2026-08-01-logsheet/`.

## 3. Closed — with the evidence that closed it

Safety and accessibility
- [x] **AX5 unit truncation.** `Draw… 0.25…` → `Draw per injection / 0.250 mL`.
      Primary rows stack label-above-value; no value+unit pair carries a
      `lineLimit`. cycle1/04.
- [x] **Hero blanking the primary CTA** while the keypad is up. cycle2/03.
- [x] **Result card clipping the field being edited.** cycle2/03.
- [x] **Result bar ate ~64% at AX5** → 32.6%, collapses to primary + CTA.
- [x] **Input borders 1.3:1** → `#8E8E93` at 3.26:1. Mac reopened this against
      its own prematurely-closed finding.
- [x] **Every failing contrast surface.** Dose readout and CTAs 2.38 → 15.79:1;
      hero glyph 2.38 → 6.43:1 (the last one, on the most prominent control);
      empty-state action and error-banner Retry, both found unprompted;
      danger `#FF5757` 3.11 → `#A31313` 7.90:1.
- [x] **Over-capacity barrel warning** uses icon **and** text, never colour alone.
- [x] **The field displayed a number the engine did not use — SECOND breach of
      that invariant.** `mgWeek` is `0...1000`; focusing a populated field did not
      select it, so typing 250 onto 100 gave `100250`, and `clamp` then handed the
      engine 1000 in silence. The screen showed `100250 mg/week` beside a
      `2.500 mL` draw computed from 1000, with a correct over-capacity warning for
      a number the user could not see. Evidence: `IB2245733` / `IB2245734`.
      Fixed on BOTH edges of `NumberField` — clamping now rewrites the text, and
      focusing selects — because one breach on one path is a patch and two is an
      invariant. **App-wide**: `NumberField` is the only numeric input and
      `FieldRow` its only call site, so every ranged numeric field in every
      calculator had this, not just the TRT dose. Pinned by
      `testOverRange_fieldNeverShowsANumberTheEngineRejected`, which asserts the
      agreement rather than the string.
- [x] **Quick-value row unreachable with the keypad up.** The occluder is the
      **pinned result bar**, not the keyboard — it sits above the keyboard and
      covers the strip the chips are in, and weekly dose is only the second field
      on the screen. `quick_mgWeek_400.tap()` reported success and moved nothing.
      The focused field's quick values now ride in a keyboard toolbar with a Done
      button, which also supplies the only exit from a `.decimalPad`. Evidence:
      `IB2245734` before, `IB2245732` after.

Data integrity
- [x] **iOS protocol saving never worked** — every insert refused by RLS because
      `user_id` was omitted. The read path omits it deliberately (RLS scopes
      SELECTs) and that assumption was carried into the write path, where the
      `WITH CHECK` made it fatal. Sourced from the session inside the data layer.
- [x] **No dedup on protocol saves.** iOS bypasses `/api/dosages` entirely
      (direct PostgREST). Fixed at the database: `UNIQUE (user_id,
      calculator_type, config)` on jsonb. Verified by count — 99 rows, two
      identical saves, 100 rows, 0 duplicate groups.
- [x] **`.upsert` rejected** in favour of insert-then-recover-on-23505.
      PostgREST resolves upsert to `ON CONFLICT DO UPDATE`, which would overwrite
      `start_date` with today and shift every calendar occurrence.
- [x] **Config shapes vs ground truth.** 9 web-backed slugs verified against the
      real rows. Three bugs fixed: the GLP-1 family was grouped in one
      `configExtras` case but the web writes semaglutide differently from
      tirzepatide/retatrutide; `hcg` had inherited the injectable mode pair.
- [x] **Five stale `/api/dosages` comments** corrected — they described a write
      path iOS has never used.

Parity and chrome
- [x] **Input control inventory** — every distinct control measured at default and
      AX5. Verdict: not universal; the calculator family is, four things outside
      it are not (now itemised in §2). Killed the suspicion that pickers differ
      from ± fields — both are exactly 44.0 / 77.35 pt, because cycle 2 floored
      pickers with the same `Theme.minTarget`. Confirmed the log sheet as the
      off-family screen. `2026-08-01-controls/`.
- [x] Palette + type scale into `Theme.swift` (it had neither).
- [x] Dark mode removed; `UIUserInterfaceStyle` via `project.yml` (not the
      generated plist), verified surviving `xcodegen generate`. Docs swept,
      including the `SCREENS.md:15` toggle that specified it.
- [x] Protocol cards no longer truncate the compound name — seven were, two were
      indistinguishable.
- [x] Navy header squares, centred teal wordmark, density, per-compound spine.
- [x] **Colour roles settled** — navy = actions, teal keeps the FAB. Taken from
      the PWA's real usage, not a hierarchy principle. `DESIGN-PARITY.md §8`.
- [x] **Centre tab slot drew its own syringe glyph** under the hero circle —
      removed the glyph rather than covering it. cycle8/02.
- [x] **Hero overlap**, all eight screens scrolled to content end, plus the AX5
      collision check. cycle9.
- [x] **Calculator's pinned CTA** −12.7pt → +3.3pt. `heroOverhang` was *not* the
      fix and 22→38 moved it zero pixels: an outer `safeAreaInset` reaches
      scrolled content but cannot lift a sibling inset pinned further in.

## 4. Known and not knowable

- **Which screens already reserved room for the hero before the fix.** Overlap
  was only ever demonstrated on the dashboard and calculator; the other six were
  never shown either way. Reconstructing it means rebuilding the old binary to
  answer a question that changes nothing.
- **`eod`, `reconstitution`, `bpc157blend` config shapes.** No web rows exist, so
  there is no ground truth to compare against. Internally consistent; that is all
  anyone can say.
- **No PWA capture for the calculator or log-dose screens.** Parity on those two
  is structural-only. Do not invent a target.
- **The log-dose date chip is 34.0 pt tall at default size — ACCEPTED, not missed.**
  Hit area measured behaviourally, not inferred: tapping 4 pt above the chip's drawn
  top did nothing, 4 pt below did nothing, and the chip's centre opened the picker.
  So the effective target equals the drawn size — UIKit is *not* padding it, and the
  "may be moot" hypothesis is dead.
  Accepted anyway, for four reasons taken together: it is Apple's own compact
  `DatePicker`, shipped in Settings, Calendar and Reminders; it already measures
  **52.7 pt at AX5**, so the shortfall exists only at default size and never for the
  larger-text users who most need a big target; it is short but ~120 pt **wide**, so
  it fails in one dimension only, unlike the toggle which was small in both; and
  `DESIGN-PARITY §6` keeps native controls native — the same trade already made for
  `UISwitch`, which it would be incoherent to apply to one and not the other.
  The row around it *is* now 44 pt with the calculator's field treatment, so the
  visual complaint that started this is fixed. Revisit only if a custom row
  presenting a graphical picker becomes worth the platform cost.
- **PII** — the drawer and Settings captures contain a real email and avatar.
  Repo is private. Blocker on ever making it public.

## 5. Rules earned the hard way

1. **Internally consistent code is not evidence.** Three times this session code
   that was correct by inspection was wrong against reality: the RLS refusal, the
   `/api/dosages` assumption, the GLP-1 grouping. Each took minutes to settle by
   looking at the running system instead of the source describing it.
2. **Measure before changing a constant.** `heroOverhang` 22→38 was rebuilt and
   re-measured to *identical pixels* before being reverted. Shipped on suspicion
   it would have looked fixed on the dashboard while costing every screen 16pt.
3. **Contrast is symmetric.** Swapping foreground and background changes nothing.
4. **An outer `safeAreaInset` cannot lift a sibling inset pinned further in.**
   Anything pinned needs clearance where it is pinned.
5. **A montage is a survey instrument, not a measuring one.** A 12.7pt overlap
   read as "grazing" off a downscaled 4272px image.
6. **Hiding is not removing.** `allowsHitTesting(false)`, `opacity(0)` and
   off-screen offsets all stop a user *seeing or touching* an element and leave it
   in the **accessibility tree**. Anything conditionally shown needs
   `accessibilityHidden` as well as its visual guard. Found on the closed drawer,
   where fourteen calculator rows sat at x = -290 and were still swipeable.
   **Swept the rest** — hero circle, welcome Canvas, calculator toggle switch all
   already carry `accessibilityHidden(true)`; the offline banners are
   `allowsHitTesting(false)` but deliberately stay announced, because "You're
   offline" is meaningful status rather than decoration. No further instances.
7. **Prefer a container that truncates visibly over one that clips silently.**
   Truncation announces itself — "Testosterone Dosage…" tells you to go looking. A
   clipped container has no ellipsis, so a sheared line reads as a glitch or as the
   whole string. Measured: `.principal` renders two lines and shears the third with
   no visual signal, at every type size. Never accept silent clipping on a title, a
   value, or a unit — the same reason `lineLimit` on a value+unit pair is banned.
8. **Closing a finding protects the code that existed when you closed it.** New
   controls land underneath old bugs. The quick-value row arrived after F11 was
   closed and immediately sat under the pinned result bar — not a regression of the
   fix, a new surface arriving under an old problem. Anything added below the fold
   on the calculator gets checked against the pinned bar as a matter of course.
9. **The screens nobody complains about are where defects accumulate**, because
   attention follows complaints rather than risk. The log-dose sheet was a stock
   `.insetGrouped` list at audit time and got the least work of any screen. It then
   turned out to hold a touch-target violation, the app's worst contrast failure
   (2.13:1), no type scale at all, and a latent copy of the truncation bug — four
   for four, on the screen nobody was looking at.
10. **A component verified in one container is not verified.** `PrimaryButton` was
   measured on the calculator, scaled correctly, and was trusted. The same component
   in a `List` row did not scale at all.
11. **If taps die but `simctl` still screenshots, check the login session** before
   touching the Simulator — CoreSimulator is a daemon with no display dependency,
   so the symptom points the wrong way.
12. **An XCUITest tap can PASS against an occluded element.**
   `quick_mgWeek_400.tap()` reported success while the model never moved, because
   the chip was behind the pinned result bar. A passing tap is not evidence of an
   interaction; only a state change is. Assert the consequence, never the tap.
13. **An ambiguous element fails before your assertion runs.** `result_<label>`
   matched two elements — the pinned bar and the in-scroll copy — and the test
   died without ever printing its own message, which was then read as "the element
   is missing" for a whole session. Resolve identifiers through a helper that
   asserts exactly one match first, and name the surface in the identifier.
14. **A test cleaned up to be well-behaved stops exercising the path the bug lives
   on.** The specced fix for `testTypeThenChip` was "clear the field before
   typing". It would have worked — and nothing in the suite would ever have gone
   out of range again, so the clamp defect would have been tidied out of reach
   rather than found. Before making a test better behaved, ask what it stops
   reaching.
15. **Every audit gets a judgment pass, before any measuring.** Look at each frame
   and ask "would I ship this?", and write down anything that reads as wrong even
   when no number attaches to it. `2026-08-01-current/10-tools-ax5.png` passed the
   audit, and passed *correctly* — nothing truncated, nothing under 44pt, contrast
   fine — while showing `Semaglu-tide` hyphenated mid-word, `Tirzepatide` wrapping
   to an orphaned `e`, a clipped `Tools` title and icons that stayed small while the
   text went huge. Metrics are a floor, not a verdict: they were chosen to catch the
   last set of bugs, not the next one. This is rule 9 one level up — not which
   screens we looked at, but what we were capable of seeing when we looked.
16. **Every screenshot carries a serial and a log row** — `SCREENSHOT-LOG.md`,
   append-only, one row per capture event, with the capture time and the commit it
   was taken at. This project has twice shipped evidence that looked fine and was
   not. A serial plus a timestamp plus a SHA makes a stale or mislabelled frame
   detectable instead of plausible. No stamp inside the image: these frames get
   measured, and marking the pixels to label them means the file is no longer what
   the device rendered.
17. **A capture sweep must fail loudly.** With `continueAfterFailure = true`, a
   failed navigation produced a genuine photograph of the Tools screen under a
   filename claiming the TRT calculator. Assert the destination before shooting.
