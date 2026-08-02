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

- [ ] **SAFETY — AN INPUT IS SHEARED BY THE PINNED BAR AT DEFAULT SIZE, with `Add`
      enabled below it.** `IB2245770`, `BPC+TB500`. `TB-500 bac water` is cut through
      its own control by the plate's top edge; `Add` sits under it at full width,
      legible and enabled. **This is F-A's shape and D12 word for word** — except F-A
      is an AX5 finding on one screen and this is **the size everyone uses**, on a
      screen nobody had photographed until `9b4afcb`. It has been shipping the whole
      time.
      **WHY NOTHING CAUGHT IT, and this is worth more than the defect:**
      `PinnedBarReachabilityUITests` covers **three** calculators — TRT Dose,
      Reconstitution, Steroid Dosage. D12's assertion is aimed at **3 of 15 screens**.
      §5.33 a third time: the check is sound and its AIM is short. Fixing the aim
      (cover all 15) is the real item; the frame is only where it surfaced.

- [ ] **Result cards are sheared by the plate at default size too.** `BMI`
      (`IB2245771`) and `Free T Index` (`IB2245772`) are cut through the word
      `Normal`; `Semaglutide` (`IB2245766`) through `Units (U-100)`. The in-scroll
      card runs under the plate wherever it is tall enough, and **nothing watches
      result rows against the plate** — the reachability sweep reads `field_*` and
      `control_*` only. Same aim gap as the item above, so they are likely one fix.

- [ ] **SAFETY / DATA — `Add` WRITES A PROTOCOL ROW FROM A CALCULATOR THAT COMPUTES NO
      DOSE. Driven, not inferred.** `IB2245771`, `IB2245772`. `canSaveProtocol` is
      **false** for `bmi`, `freeTestIndex` and `cyclePlotter`, and its own comment says
      the flag exists so such a calculator does not "walk the user into a wall at the
      last step". `AddScreen` honours it. **`CalculatorScreen` never references it** —
      the CTA is gated on `vm.result.isValid && network.isOnline` — so both screens
      render a full-width, fully enabled `Add`.
      **WHAT THE BUTTON ACTUALLY DOES, measured on BMI:** it writes a row and advances
      to the start-day confirmation. The row landed in `saved_dosages` as
      `calculator_type: bmi`, `label: BMI`,
      `config: {heightCm:180, heightFt:5, heightIn:10, imperial:false, weightKg:80,
      weightLb:180}`, `start_date: 2026-08-02`, `status: draft`, `is_active: false`.
      The confirmation screen then reads **"ADDED TO YOUR PROTOCOLS"** over the height
      and weight, and asks the user to "Confirm the day this protocol begins so the
      calendar and dose reminders line up." **A body measurement is given a start date
      and wired into the calendar and dose reminders.**
      **`draft` IS NOT A MITIGATION.** `SupabaseBackendClient.savedDosages()` selects
      `id, calculator_type, label, config, created_at, start_date, is_active` ordered by
      `created_at` with **no filter on `status` or `is_active`** — so the row is in the
      user's protocol list the moment it is written.
      The test row was deleted (`2d9d1bc2…`); `bmi`/`freetest`/`plotter` rows back to 0.
      **The fix is not a new flag.** `canSaveProtocol` exists and `AddScreen` already
      honours it; the code that would honour it on the calculator screen is the code
      that is missing.
      Two smaller things measured on the way: the CTA reports `enabled=true` and
      **`hittable=false`** at (16, 687, 370, 72) with XCUITest unable to
      `AXScrollToVisible` it, though the frame is on screen and above the tab bar —
      unexplained, and it means the tap had to be driven by coordinate. Nothing here is
      concluded from the tap returning; the outcome was read from the app and from the
      database.

- [ ] **`Cycle Plotter` is absent from the screen whose job is listing calculators.**
      `CalculatorCategory.members` enumerates **14 of the 15 slugs** and
      `.cyclePlotter` is in none, so `ToolsScreen` cannot render it — while that
      screen's own comment says it "Shows ALL calculators including the ones that
      cannot save a protocol (BMI, Free T Index, **the plotter**)". A shipped
      calculator missing from the browse surface, with a comment asserting the
      opposite: T18's shape a third time — the source describing an intention rather
      than the behaviour.
      Found by the capture sweep **dying on it**: thirteen calculators were located on
      that list by the identical mechanism and this one never appeared after twelve
      scrolls. Its only route is the dashboard's `Add a protocol` dialog, which
      enumerates `allCases`, needs **eight drags** to bring the entry into the tree
      (16 actions on an 874pt display), and offers all three non-saving calculators
      under a title promising a protocol. Frame: `IB2245775`.

- [ ] **SAFETY — `Add` is enabled over a dose the user cannot read.** `IB2245752`,
      `Steroid Dosage` at AX5. `field_mgWeek` spans y 636.33…701.33 against a plate top
      of pt 651.67, so `Weekly dose` is sheared through its own digits — and `Add` sits
      below it at full width, perfectly legible, enabled, and **`Add` writes a
      protocol**. One complete input is usable on that screen at AX5 and it is not the
      dose.
      **This is `D12` word for word, and T24's finding on a different screen:** an
      action you can reach for a value you can't is worse than an action you can't
      reach, because the second one stops you. Filed as safety, not layout — the
      severity is what decides the order it gets fixed in.
      The pinning gate cannot fix it: at AX5 the bar is already at its FLOOR — the
      result card is stood down entirely and what remains is the committing action D12
      requires. The fix belongs to that screen's layout. Carried meanwhile as a named
      expected failure in `PinnedBarReachabilityUITests.expectedShears`, so every other
      screen stays asserted at AX5 and the run goes red the day this one starts
      passing (§5.30).

- [ ] **APP-WIDE — every menu picker draws OUTSIDE its own control at large text once
      its selected string is long enough.** `IB2245752` (`Steroid Dosage` · `Compound`,
      `Oxandrolone (Anavar)`) and `IB2245753` (`TRT Dose` · `Ester`,
      `Testosterone Enanthate`). The selected value wraps to three lines that overflow
      the field chrome and render **on top of the label above it** — two strings in the
      same pixels, neither legible.
      **Not one screen, and the evidence is structural rather than inferred.**
      `FieldRow.content` is the only call site: `.picker` and `.stringPicker` both
      render `Picker(...).pickerStyle(.menu).fieldChrome()`, so **12 picker fields
      across 8 calculators** share it — TRT Dose (Frequency, Ester), TRT & EOD (Ester),
      Peptide (Dose unit), Semaglutide / Tirzepatide / Retatrutide (Concentration,
      Dose), Free T Index (TT unit), Steroid Dosage (Compound). This is the T1 shape:
      "the compound picker on Steroid Dosage" and "every picker in the app" are
      different findings and only the second is true.
      **The observed case is nowhere near the worst.** Longest strings the control is
      ever handed, from the catalog rather than from a screen:
      `Equipoise (Boldenone Undecylenate)` and `Primobolan (Methenolone Enanthate)` at
      **34 characters**, `Nandrolone Phenylpropionate (NPP)` at 33 and
      `Drostanolone Propionate (Mast-P)` at 32 — the last two on TRT's **Ester** picker,
      not Steroid Dosage's. `Oxandrolone (Anavar)`, which produced `IB2245752`, is 20.
      **Length-dependent, not universal:** `Frequency`'s `2×/week` sits cleanly inside
      its box in the same frame as the overflowing Ester.
      **No existing check can see this.** Nothing is truncated and nothing is clipped —
      the text gets the width it asks for and takes the height it wants — so the ratio
      sweep, T19's renderer probe and the reachability sweep are all blind to it. It is
      a fourth mechanism in the family that produced F1.
      Two more call sites are OUTSIDE this control and need checking separately:
      `CyclePlotterScreen` renders two `.menu` pickers of its own without `fieldChrome`.

- [ ] **A NEW CHECK, AND IT IS CURRENTLY RED: no two content leaves may share pixels.**
      `LeafOverlapUITests`. Overlap is the fourth mechanism in the F1 family and the
      first one **no existing check could see** — nothing truncates and nothing clips, so
      the ratio sweep, T19's renderer probe and the reachability sweep are all blind by
      construction. The invariant names no mechanism: two frames sharing pixels.
      **Leaves, not siblings.** The sibling formulation was specified and would have gone
      GREEN on the frame it was written for: on `IB2245752` the two strings that collide
      are `Oxandrolone (Anavar)` (a child of the picker button) and `Compound` (the
      button's sibling) — an uncle and a nephew. Leaves get it for free, and a container
      is never a leaf so a child drawn inside its own parent is not a violation.
      **Shown red on the target defect** — `Compound` × `Oxandrolone (Anavar)`, sharing
      148.6 × 49.3pt — before being trusted anywhere.
      **STATE: AX5 green with 8 named debts; DEFAULT still red.** Not claimed as green.
      What it has found so far, each a real defect:
      | where | pair | size |
      |---|---|---|
      | Steroid Dosage | `Compound` × `Oxandrolone (Anavar)` | AX5 |
      | Steroid Dosage | `Oxandrolone (Anavar)` × `Vial strength` | AX5 |
      | TRT Dose | `Ester` × `Testosterone Enanthate` | AX5 |
      | TRT Dose | `2×/week` × tab bar | AX5 |
      | TRT Dose | `2×/week` × hero glyph | AX5 |
      | Reconstitution | `result_Add bac water` × tab bar | AX5 |
      | Reconstitution | `result_Add bac water` × hero glyph | AX5 |
      | Reconstitution | `Add bac water` × hero glyph | AX5 |
      | **all three** | `Maths only — not medical advice.` × hero glyph | **default** |
      | Reconstitution | `result_Units (U-100)` × tab bar | **default** |
      Two of those are at DEFAULT size and neither was on the board — §5.22 again, the
      default frames are the half nobody looks at.

- [ ] **THE DISCLAIMER IS UNREADABLE AT REST ON EVERY CALCULATOR — and that is not
      what this finding used to say.** Measured at rest on all fourteen at `9b4afcb`.
      **Superseding the original wording** ("the raised hero covers the tail of the
      disclaimer on every calculator … the last ~19pt is behind it"), which was right
      that something is wrong and wrong about what, where and how many.
      **The hero/disclaimer intersection is SIX calculators, not every one, and it is
      identical on all six** — Reconstitution, Semaglutide, Tirzepatide, Retatrutide,
      BMI, Free T Index, each `(172, 762, 19.33 × 13.0)` = 251.3pt². The hero never
      moves: fixed at `(172, 762, 58, 58)` on every screen at every scroll offset,
      which is F-G from another angle. What varies is where each form's content ends.
      The other eight put the disclaimer below an 874pt display (y 909.67–1120.67),
      except `BPC-157` at y 841.67 — on screen, clear of the hero, and **inside the
      tab bar's region, which starts at y 792**.
      **AND ON THE SIX, THE DISCLAIMER IS NOT DRAWN AT ALL.** `IB2245765` is the
      proof, cropped and read off the pixels rather than trusted from the number: the
      tree reports `Maths only — not medical advice.` at y 761.67, on screen; the
      pixels at y 720–820 are the navy `Add` plate, the hero circle and the tab bar;
      and the string appears **nowhere in the frame**. The plate is opaque
      (`.regularMaterial`, measured #FEFEFE) and T25 established nothing renders behind
      it.
      **So the finding as filed describes an ACCESSIBILITY-TREE INTERSECTION BETWEEN
      TWO ELEMENTS, ONE OF WHICH IS NOT DRAWN.** See §5.34 — the overlap suite reads a
      tree with no z-order and no clipping. The real state is worse and simpler: at
      rest, on every calculator measured, the "not medical advice" line is unreadable
      — below the display, behind the tab bar, or under the pinned bar. On a dosing
      app it is never legible without going looking for it.
      **It is DETERMINISTIC, not intermittent.** The same 19.33 × 13.0 came back
      byte-identical from a standalone walk probe and from the sweep. Two of the three
      `isIntermittent` entries for this pair — `TRT Dose` and `Steroid Dosage` — name a
      collision that **cannot occur at rest at all** and should be DELETED rather than
      flagged; and because `isIntermittent` switches off the both-ends assertion, the
      check that would have caught those dead entries is the one the flag disabled.

- [ ] **Content draws into the tab bar and past the bottom of the display at AX5.**
      A picker value on TRT and a result row on Reconstitution both reach into the tab
      bar; `Testosterone Enanthate` extends to y 915 on an 874pt display. `heroOverhang`
      is 22pt and reserves for the circle, not for this.

- [ ] **`accessibilityHidden(true)` DOES NOT REMOVE THE HERO GLYPH, and §5.6 was wrong
      rather than incomplete.** `Image 'syringe'` sits in the tree as a leaf at
      (172, 762, 58, 58) on every calculator — the circle's own frame, centred at x = 201
      on a 402pt window, ancestors all generic full-window containers rather than the
      TabBar, so it IS the raised hero and not a second glyph. **Measured twice:** present
      with the flag on the composed hero, and still present with the flag applied directly
      to the `Image`. Byte-identical frame both times.
      A decorative glyph is therefore a VoiceOver stop on every screen in the app, and
      §5.6's sweep — which recorded the hero as "already carries
      `accessibilityHidden(true)`" — was reading the source rather than the tree. That is
      §5.1 on our own audit.
      **This invalidates an assumption in `RESULT-PANEL-SPEC §5`**, which specs the
      barrel-fit strip as `.accessibilityHidden(true)` and relies on that to keep a
      decorative duplicate of the dose figures out of the tree. It must not ship on that
      assumption: the absence has to be asserted on the strip itself, red first with the
      modifier removed. A working mechanism is not yet identified.

- [ ] **`Steroid Dosage`'s screen title truncates to `Steroid Dos…` at AX5.**
      `IB2245752`. §5.7 bans this outright — never accept silent clipping on a title, a
      value or a unit. Probably resolves with the screen-header rule
      (`DESIGN-PARITY §9`), which is already open.

- [ ] **`Oxan-drolone`, hyphenated mid-word.** `IB2245752`. Same family as
      `Semaglu-tide` on Tools (`IB2245747`), so one shared cause rather than two
      screen-specific bugs — worth fixing once, on whatever sets the hyphenation policy
      for these labels.

- [x] **The result bar owns 52.40% of the content area at DEFAULT size — CLOSED,
      measured.** Gated on a **measured share**, not a Dynamic Type category. The bar
      now lays out four candidate states hidden, at their own ideal heights, and takes
      the tallest that fits within 40% of the content area.
      Measured at default (content area 638.67pt, cross-checked against a band profile
      of the same frame at 638.34pt — header bottom pt 152.33, tab bar top pt 790.67):

      | rung | height | share | |
      |---|---|---|---|
      | `full` | 334.67pt | **52.40%** | the finding |
      | `lead` | 226.33pt | **35.44%** | ships at default |
      | `compact` | 186.00pt | 29.12% | keypad-up form |
      | `unpinned` | 120.00pt | 18.79% | the floor |

      At AX5 (content area 617.67pt) `full` measures **642.33pt — 104% of the content
      area**, `lead` 59.20%, `compact` 58.88% (which independently reproduces the ~58%
      recorded when this was closed by size category), `unpinned` 22.56%. So the gate
      stands the bar down at AX5 by measurement, and T24's outcome is preserved without
      the size gate that produced it.
      Each candidate was checked against the framebuffer: predicted 334.67 / 226.33 /
      186.00 against band-profiled 334.34 / 226.00 / 185.67. Within 0.33pt every time.
      **The cap is 0.40 and it is measured, not chosen.** There is an irreducible floor
      — `Add` plus hero clearance plus padding is 18.79% at default and 22.56% at AX5,
      and `D12` makes it mandatory — so the gate chooses inside `[18.79%, 52.40%]`, not
      `[0, 1]`. A one-third cap leaves 14.54 points of real budget and `lead` needs
      16.65: it misses by 2.11 points, and what pays is the dose, because the rung
      below renders `0.250 mL` as a small ink secondary row instead of the 7.65:1 teal
      display face. 0.40 is chosen for margin rather than fit — 0.36 would sit 0.6
      points from a measured value and change rung on a font-metric revision.
      **The cross-check was measured, not conceded.** Keeping the weekly total as one
      secondary line under the lead figure — the `leadPlusTotal` rung — measures
      **260.33pt = 40.76%**, over the cap by **4.86pt**. So the trade was forced, not
      chosen: `lead` is what fits. The rung stays in the ladder because on a screen or a
      device where it does fit the gate takes it and the cross-check stays pinned, which
      is the point of measuring rather than ruling. Its branch was driven and observed
      at `BAR_SHARE_CAP=0.45` rather than left as a path nobody has seen render.

- [x] **A dose field is sheared at AX5 on `Steroid Dosage` — FOUND BY THE NEW
      REACHABILITY SWEEP, on its first run at that size.** `field_mgWeek` spans
      y 636.33…701.33 with the plate top at 651.67, so the weekly dose is cut through
      its own glyphs. **The gate cannot fix this one**: at AX5 the bar is already at
      its floor — the result card is stood down entirely and what is left is the
      committing action, which `D12` requires. The fix is in that screen's layout, not
      in the bar, so it is filed rather than folded in. Listed here as open, below.

- [ ] **The same headline dose figure now renders twice, conspicuously.** `IB2245750`:
      scrolled to the end of the TRT form, `Draw per injection · 0.250 mL` appears in
      the in-scroll card AND in the pinned `lead` bar, both at full display treatment,
      about 500px apart. The duplication predates T20 — the in-scroll card has always
      rendered unconditionally — but the `lead` rung **made it worse to look at**: the
      two copies are now the same single headline figure rather than two lists of
      different lengths. Found by the judgment pass on this session's own change, which
      is the only reason it is here. Not a divergence risk (one `CalculatorResult`), so
      it is a product question: whether the pinned copy should suppress itself when the
      in-scroll card is on screen.

- [ ] **`Frequency` is sheared by the plate edge with the keypad up.** `IB2245751`.
      The reachability sweep asserts **at rest**, where the content area is the whole
      screen; with the keypad up it is a fraction of it and the bar is in its `compact`
      rung. Recorded rather than cropped out of the evidence. Whether the invariant
      should extend to the keypad-up state is undecided — extending it naively would
      assert something the keyboard makes unsatisfiable, which is the same trap as
      asserting the straddle rule at AX5.

- [ ] **`Steroid Dosage` shears `field_mgWeek` at AX5.** See above. The bar is at its
      floor and cannot move; this needs the form to stop leaving a control across the
      plate edge, or the plate edge to stop being opaque to it. Open, and carried as a
      **named expected failure** in `PinnedBarReachabilityUITests.expectedShears` — so
      the suite still asserts the rule on every other screen at AX5, and goes red the
      day this one starts passing. §5.30.

- [ ] **T25 — nothing renders behind the pinned bar, so a translucent plate has
      nothing to be translucent over.** Filed out of T21, and it is a **hypothesis, not
      a finding**. Evidence: `.ultraThinMaterial` — the most transparent material —
      sampled `#767676` at four different scroll positions, identical. A material over
      a moving backdrop cannot return the same value four times; a number that cannot
      vary is telling you the thing you think you are measuring is not in the picture,
      which is the same shape of evidence as two byte-identical frames.
      The read to start with: **a material getting darker as it gets thinner is the
      signature of compositing over an undefined backdrop, not over form content.**
      Thinner shows more of what is behind; the ladder says what is behind is dark; the
      app is light-only on `#FAFAFB`, so there should be nothing dark anywhere near it.
      **Ruled out, and worth as much as the finding:** the `.safeAreaInset` was moved
      from the `GeometryReader` onto the `ScrollView` inside it — the composition that
      should have let the form scroll under the bar. Byte-identical measurements, all
      four positions. It bought nothing and is not banked as a fix.

- [~] **The pinned bar's plate — TONE CHANGED, REQUEST NOT DELIVERED.** The human asked
      for *transparent with a light blur, so the bar reads as floating over the form
      rather than as furniture covering it*. What shipped is `.regularMaterial` plus a
      1px hairline: it **fixes the complaint** — the flat grey slab is gone — and it
      **does not deliver the request**, because there is nothing for translucency to be
      translucent over (T25). This line says so in those words deliberately; "plate →
      material, done" would be true about the code and false about the ask.
      Measured ladder, same screen, same scroll position, one run:
      `ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB (shipped) · regular #FEFEFE ·
      thick #FFFFFF`. `.thinMaterial` is 8 values from `.bar` — a change nobody can
      see, which is why it was not taken.
      The result card gained a hairline stroke in the same pass: card and plate both
      measure `#FEFEFE`, and two surfaces within one value of each other are not a
      boundary. A half-step tone was rejected by the same measurement that rejected
      `.thinMaterial`.
      **Contrast does not fail anywhere.** Worst composite across four scroll positions
      and five materials: `#075E56` dose value **7.14–7.59:1**, navy eyebrow
      **14.60–15.65:1**, `Add` white-on-navy **15.79:1 exactly at every position**,
      because `Theme.navy` is opaque and the plate cannot reach it. Not covered: the
      disabled CTA is `navy.opacity(0.4)` and *would* composite; WCAG exempts disabled
      controls and it is not claimed here.

- [x] **The pinning gate is a proxy, so the assertion is not the gate.**
      `PinnedBarReachabilityUITests`. 40% of the content area is a fact about area, not
      about whether you can see the dose you are committing — a screen with three tall
      fields can sit under the cap and still shear an input. So the invariant asserted
      is `D12` itself, in two passes, against the plate's **rendered** frame rather than
      against the gate's own arithmetic:
      1. the committing action is wholly on screen and hittable, at every size;
      2. at rest no input control straddles the plate's top edge, and at every size
         every input can be brought to **full** visibility.
      **Shown to fail before being trusted (§5.24).** `BAR_SHARE_CAP=0.55` forces the
      gate to approve the full-height bar and the sweep goes red on
      `control_injPerWeek` — the `Frequency` picker, the exact control the finding
      names. Green at 0.40.
      Coverage, stated so a green run is not over-read: numeric fields and menu pickers
      on three calculators. Segmented rows, toggles and day steppers are **not**
      measured — they carry no per-field identifier and naming their container would
      propagate it to every button inside, which is the ambiguity that cost a session.
      The straddle half is not asserted at accessibility sizes, because there the bar is
      already at its floor and the assertion would be unsatisfiable; the real AX5 case
      it found is filed above rather than hidden by the scoping.

- [x] **The pinned result bar leaves one field visible at AX5 — CLOSED.** `IB2245748`.
      Closed first by a Dynamic Type gate (T24) and now by the measured gate, which
      reaches the same outcome without guessing where the problem starts: at AX5 the
      `lead` rung measures 59.20% of the content area and the cap stands it down.

- [ ] **Dashboard at AX5 fails the reachability test.** Not the greeting
      percentage — the greeting is the diagnosis. The bug is that the Next dose
      card's `Mark taken` CTA was off the bottom of the screen at AX5, so the
      action for today's dose needed a scroll on the home screen. Capping the
      greeting (`DESIGN-PARITY §10`) fixed this instance; the rule it produces is
      in §5.19 and every screen still needs checking against it.

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

- [x] **The in-scroll `ResultCard` renders unconditionally, so at default type
      size the same rows exist twice — LARGELY DISSOLVED by the measured gate.** At
      default the pinned bar now shows ONE row (`lead`), so the duplication is a single
      figure rather than a whole card, and at AX5 there is no pinned copy at all. The
      addressing rule changed with it: `result_<label>` now follows the ROW to whichever
      surface is displaying it, because the old rule ("`result_` names the pinned bar")
      assumed a bar whose contents never varied. It stopped being true the moment the
      gate could choose a rung, and two wiring assertions went red on
      `result_Weekly total` resolving to zero elements. They were red about something
      true. Historical detail below.
      `result_Weekly total` measured as two
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

- [x] **T19 — the RENDERER publishes whether it truncated, and it found that the
      result rows were never covered at all.** `truncationProbe` lays each value view
      out twice — once as it renders, once free of any width constraint — and publishes
      whether the second is wider. Layout answering a question about layout, rather than
      the accessibility layer answering a question it cannot see (§5.23). DEBUG only.
      **Shown red before being trusted.** Reproduced with `FORCE_INLINE_FIELD=1` at AX5:
      13 probes fire. Green at default — 93 probes clean across 11 calculators.
      **It does NOT supersede T4b's ratio, and the diff is the interesting part.** On the
      same reproduced defect, ratio 9 failures, renderer 13. Caught by the renderer and
      **not** by the ratio:

      | | rendered | ideal |
      |---|---|---|
      | `BPC+TB500 · field_bpcVial` | 131.67pt | 138.67pt |
      | `BPC+TB500 · field_tbDose` | 131.67pt | 137.67pt |
      | `BPC+TB500 · field_tbVial` | 131.67pt | 138.67pt |
      | `BPC+TB500 · result_BPC-157 draw` | 247.33pt | 347.67pt |
      | `BPC+TB500 · result_TB-500 draw` | 247.33pt | 347.67pt |
      | `Peptide · result_Volume` | 319.00pt | 525.00pt |

      The three fields are the documented blind spot — a long value beside a short unit
      keeps the ratio and passes green. **The three `result_` rows are worse than that:
      the ratio compares `field_<key>` against `unit_<key>`, so it never looked at the
      result card at all.** That is the surface F1 was found on — `Draw… 0.25…`, the
      unit-loss that was the worst finding of the original audit — and it has had no
      truncation check since. Not a gap in the ratio's logic; a gap in what it was ever
      pointed at.
      And one case the ratio catches that the renderer does not: `Free T Index · shbg`,
      value cell 79.0pt against a 147.0pt unit, where the string still fits. That is a
      squeezed layout without truncation. **Both checks stay** — they answer different
      questions, and neither is a superset of the other.
      Coverage: numeric fields and result rows. The probe on a `TextField` compares a
      `Text` of the same string against the field's whole frame, so it is CONSERVATIVE —
      UIKit's internal inset means a value clipped by only that inset can still pass.

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
- [x] **F1 AGAIN, through layout instead of `lineLimit` — a dose truncated to
      `1…` at AX5.** `NumberField` laid out `[ value ][ unit ][ − ][ + ]` on one
      line. The unit carries `.fixedSize()` (correct — a unit must never truncate)
      and the steppers are 44pt each, so at AX5 the unit took the row and **the
      value** was squeezed. `1…` on a weekly dose could be 100, 150 or 1000
      mg/week. Compounding it, the field's font was a frozen
      `.system(size: 17)` at the call site, which the `Theme` re-baseline could not
      reach — so the dose number stayed 17pt while `mg/mL` grew past it and the
      value became the smallest text on the screen. Fixed by reflowing above AX1
      (value on its own full-width line, unit and steppers beneath) and moving the
      field to a scaling token. Evidence: `IB2245748`, the first capture of this
      screen at AX5 ever taken.
      **The lesson is about the old fix, not the new one:** F1 banned `lineLimit`
      on a value+unit pair and that ban was necessary and not sufficient. Layout
      reached the same place without it.
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
18. **A screenshot taken under a non-default rig configuration is not evidence
   about the default configuration.** `IB2245732` was shot with a hardware
   keyboard attached, so iOS suppressed the software keypad and the keyboard
   toolbar was photographed sitting on the tab bar — a position it never occupies
   in front of a user, and the pinned bar's relationship to it untested. Nothing
   in the image says so. Same family as the byte-identical "refresh" and the
   backgrounded home screen, except that this one flattered the fix, which is why
   it was easy to miss. Hardware keyboard, Reduce Motion, a non-standard device
   scale — none of them announce themselves. Re-shot as `IB2245735`.
19. **Report layout as a percentage of the viewport, never in lines.** "The
   greeting takes three lines" is comparable to nothing. "The greeting takes 31% of
   the content area at AX5" is comparable across screens, across type sizes, and
   against the same screen next week. Measure it off the framebuffer — a vertical
   band profile of the PNG — rather than from the view hierarchy, because that
   measures what the user sees rather than what the layout claims. Two denominators:
   full frame height (how the screen feels) and the content area between fixed
   header and tab bar (what you can actually change). Put the numbers in the
   screenshot log next to the serial, so drift is a diff rather than a re-derivation.
20. **The primary action must be reachable without scrolling at every supported
   type size.** Binary, not negotiable, and it is the rule with teeth: a percentage
   tells you *why* a screen is wrong, reachability tells you *that* it is. The AX5
   dashboard failed this today while every metric we had said it was fine — we had
   been arguing the percentage and missing the reachability all day. Decorative
   chrome over ~20% of the content area is a softer companion finding: it prompts a
   look, it does not force a fix.
21. **A capture run leaves the device dressed for the wrong test.** `simctl ui
   content_size` is device state, not run state. An AX5 sweep left it set and the
   next wiring run failed all four assertions against a reflowed layout — it read
   as "the app broke" and nothing had. Reset it in the same command that sets it.
22. **The judgment pass applies to every frame at every size, not just the
   accessibility ones.** Every finding today came out of AX5 frames — not because
   the default screens are clean, but because those were the frames anyone looked
   at. Applying the viewport method to a *default*-size frame we had captured and
   never judged immediately found the result bar taking 52% of the content area and
   two of five inputs above the fold. §5.7 again, one level up: the AX5 frames are
   not the audit, they are the half that is easier to see.
23. **A test that cannot fail is worse than no test, and it is easy to spec one by
   accident.** "Assert the displayed string contains no ellipsis" was specced as
   the fix for the truncation class. It passes on the exact frame that renders
   `1…`, because the accessibility layer returns model text and not rendered
   glyphs — measured: `field.value == "100"` while the screen showed `1…`. Before
   writing an assertion, ask which layer actually observes the thing being
   asserted. Then reproduce the defect and watch the test go red; a test that has
   never failed has not been shown to work.
24. **The checks that fail us are the ones that cannot fail.** Four came out on
   2026-08-02 alone, from four unrelated directions, and every one of them reported
   success:
   - `continueAfterFailure = true` turned a failed navigation into a photograph of
     the wrong screen, filed under the right screen's name.
   - A suppressed software keyboard produced a frame that *flattered* the fix it was
     taken to prove.
   - Two "different" captures came back byte-identical because the gesture between
     them never landed.
   - "Assert the displayed string contains no ellipsis" reads the accessibility
     model, not the render, so it passes on the exact frame showing `1…`.
   Note what they have in common: none of them were wrong about something, they were
   silent about everything. A check that has never been observed to fail has not been
   shown to work, and its green is indistinguishable from its absence. So: reproduce
   the defect and watch the assertion go red before trusting it, ask which layer
   actually observes the thing being asserted, and make the harness able to fail —
   `continueAfterFailure = false`, assert the precondition, assert frames differ,
   count matches before resolving. Every guard added today came from a check that
   had been quietly passing.
25. **A view measured under a compressing proposal reports a height it will never
   render at.** SwiftUI proposes a `.background` the size of the view it decorates, so
   a candidate laid out there is SQUEEZED to fit rather than reporting its own ideal
   height. The pinning gate measures four candidate bars this way, and at AX5 the full
   bar measures **642.33pt against a 617.67pt content area — 104%**. Without
   `.fixedSize(horizontal: false, vertical: true)` that candidate would have come back
   clamped to the container, the gate would have approved **exactly the bar it exists
   to stand down**, and every number downstream would have been arithmetically perfect
   and about a layout that does not exist. Anything measured to make a decision must be
   measured free of the proposal, or the measurement is of the constraint and not of
   the thing.
26. **`TEST_RUNNER_` reaches the RUNNER, not the app under test.** `xcodebuild` forwards
   prefixed host environment into the test process; the app is a separate process and
   sees nothing unless the test copies it into `app.launchEnvironment`. A DEBUG override
   that drives the pinning gate was set for a whole run, changed nothing, and the run
   reported **success** — while photographing the default gate under a filename claiming
   the override. That is the fifth check in two days that reported success while
   observing nothing, and this one was observing the override that PROVES the gate
   works. The app now publishes the value it actually resolved and the test asserts the
   override arrived; forwarding without asserting arrival is the same bug one step
   later.
27. **Never select a material by its name.** The names describe THICKNESS, and thickness
   is how much backdrop shows through — not how light the result is. Measured on the
   calculator's pinned plate, one run, same screen and scroll position:
   `ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB · regular #FEFEFE · thick #FFFFFF`.
   `.ultraThinMaterial`, the obvious reading of "transparent with a light blur", came
   out **101 values darker** than the near-opaque `.bar` it was meant to lighten. That
   is not an anomaly, it is the general case over a dark or absent backdrop. Measure the
   ladder on the actual screen, every time.
28. **A gesture that registers as the wrong gesture moves nothing and reports
   success.** `coordinate.press(forDuration: 0.4, thenDragTo:)` was used to walk a form
   in small steps; 0.4s registers as a PRESS and scrolled **zero pixels**, so six
   capture positions would have been one frame under six names. Caught only because the
   sweep asserts the FIRST gesture changed something before letting later no-ops end the
   loop. `swipeUp(velocity:)` is a swipe at any velocity; a long press is not a drag.
29. **A test process's Documents directory SURVIVES between runs.** When a frame is
   skipped — a guard returning early, a run failing partway — the previous run's file is
   still sitting under the name this run meant to write, and the host copies it out as
   this run's evidence. It gets measured, serialised and cited while being a photograph
   of different code. Nearly happened. Fixed rather than written down (D8): the
   directory is emptied at run start, and a frame that is not on disk afterwards fails
   the run instead of resolving to whatever is there.
30. **When an assertion is unsatisfiable, name what makes it unsatisfiable — do not
   narrow the condition until it passes.** The reachability sweep found a real shear on
   `Steroid Dosage` at AX5 that no pinning gate can fix, because the bar is already at
   its floor there. The first response was to stop asserting the straddle rule at
   accessibility sizes. That bought silence on ONE known screen and paid for it with the
   assertion on EVERY screen at AX5 — including the ten not yet surveyed, at the size
   every finding this week came out of. It was a size gate on a test, which is the same
   mistake as a size gate on the bar and wrong for the same reason: a size is a guess at
   where the problem lives.
   The replacement is a NAMED EXPECTED-FAILURE LIST, asserted from both ends: a listed
   case must still fail, and the run goes red the moment it starts passing, telling you
   to delete the entry. An entry naming a control that is not on screen fails too, so a
   stale entry cannot sit there suppressing nothing. Both directions were reproduced
   before being trusted.
   The difference is not cosmetic. **A narrowed check stays narrow forever and nobody
   remembers why; a listed one has to shrink.** And a filed finding plus a green suite
   still reads as green — the list puts the debt in the place people actually look,
   which is the run.
   Corollary, from applying the same rule to the folder check below: scoping by a
   DOCUMENTED, DATED boundary is legitimate where scoping by "which ones fail" is not.
   `2026-08-01-current` is exempt because the serial rule starts on 2026-08-02 and says
   so in writing — and even that exemption is asserted from the other end, so a
   pre-serial folder that gains serials rejoins the rule instead of falling in a gap.
33. **When a finding is closed by a check, record WHAT SURFACE THE CHECK WAS AIMED AT.**
   The finding gets remembered as closed and the aim gets forgotten. F1 — unit truncation,
   `Draw… 0.25…`, the worst finding of the original audit — was closed by a check pointed
   at `field_<key>` / `unit_<key>` pairs. That logic was correct everywhere it looked, and
   it never looked at the result card, **which is the surface F1 was found on**. Anyone
   reading a green tick over that surface was reading a tick over something nothing was
   watching, for two days, until T19's renderer probe measured three result rows
   truncating.
   The failure was not in the logic. It was in the AIM, and aim is invisible in a tick.
   So every closed item owes an answer to: what does the check that closed it actually
   observe, and what does it not? Cheap to ask, and the answer belongs next to the tick.
   Do not run it as a sweep — sweeps done in a hurry are where regressions come from
   (§D9). Add the line as each area is touched; T11 is the natural first pass, and it
   should treat result cards as an UNSURVEYED SURFACE rather than a re-check.
32. **An exemption is safe when the exempted set CANNOT GROW.** Two scoping decisions
   came up an hour apart and only one of them was legitimate, so the test that separates
   them is worth having. Switching the straddle assertion off at accessibility sizes was
   a NARROWING: the exempted set was open — every screen at AX5, forever, including the
   ten not yet surveyed and every screen not yet written — so it silenced cases nobody
   had looked at. Grandfathering `2026-08-01-current` out of the serial rule is a
   GRANDFATHER CLAUSE: the set is folders that already existed when the rule landed, and
   nothing can join it because time only moves one way. Same word, opposite structure.
   Ask what could join the set tomorrow. If the answer is "nothing", it is a grandfather
   clause. If it is "anything of that kind, including things not built yet", it is a
   narrowing and the debt needs naming instead (§5.30).
   And write the closed set as an ENUMERATED LIST, not a predicate. "Folders dated
   before 2026-08-02" is evaluated at runtime, so it is closed only by convention — a
   folder named `2026-07-30-something` created next week satisfies it and walks out of
   the rule, and the innocent version (someone reorganising an old capture) is likelier
   than the adversarial one. A literal list is closed by construction.
   The alternative that looks obvious and is worse: backfilling serials onto those
   frames. That manufactures a provenance which never existed — §5.16's reasoning with
   the sign flipped, since an in-image stamp was refused for mutating evidence in order
   to label it. A documented gap is honest; an invented serial is a number that looks
   issued and was not.
31. **A name that outlives its content is the failure mode this project keeps
   rediscovering, and nothing was checking the names.** The `2026-08-02-current` README
   listed `IB2245743` and `IB2245744` after those files had been superseded, and never
   listed `IB2245748` at all — a table naming frames that were not there, and a folder
   holding a frame the table did not know about. **Neither harness ran that check; a
   human caught it by reading the table against a checkout.** Now
   `AuditFolderConsistencyTests` asserts it in BOTH directions, because the failure that
   happened was one direction and the other is just as reachable. Shown red both ways
   before being trusted. The whole evidence chain — serial, log row, commit SHA — is
   worth exactly what the link between a name and a file is worth.

32. **An exemption is safe when the exempted set CANNOT GROW — enumerate it, do not
   predicate it.** `AuditFolderConsistencyTests` grandfathers the pre-serial capture
   folders out of the serial rule. Written as a date predicate — "folders dated before
   2026-08-02" — the set is evaluated at runtime and closed only by CONVENTION: a folder
   named `2026-07-30-something` created next week satisfies it and walks straight out of
   the rule, and the innocent version (someone reorganising an old capture) is likelier
   than the adversarial one. Written as a literal list it is closed by construction.
   **The general test:** ask what could join the exempted set tomorrow. If the answer is
   "nothing", it is a grandfather clause. If it is "anything of that kind, including
   things not built yet", it is a NARROWING and the debt needs naming instead (§5.30).
   And assert the exemption FROM THE OTHER END: an entry that never matches anything is
   exempting nothing and hiding that it exempts nothing.

33. **When a finding is closed by a check, RECORD WHAT SURFACE THE CHECK WAS AIMED AT.**
   The finding gets remembered as closed and the AIM gets forgotten — and the aim is the
   whole of what was actually established.
   **F-D is why it is a rule.** F1 was a truncation finding FOUND ON A RESULT CARD. The
   check that closed it compares `field_<key>` against `unit_<key>`, so it never looked
   at a result row in its life. Its logic was not wrong; its AIM was. A green tick sat
   over the surface the finding was found on for two days, and a closed item does not
   get re-examined.
   **It has now paid out twice more, on the same day it was written.**
   `PinnedBarReachabilityUITests` implements D12 and is aimed at 3 of 15 calculators —
   `IB2245770` is an input sheared by the plate AT DEFAULT SIZE on one of the twelve it
   never looks at. And nothing at all is aimed at result rows against the plate, which
   is three more sheared frames in the same sweep.
   So a closure reads "closed by X, **aimed at Y**", and when Y is not the surface the
   finding was found on, that is a second finding rather than a footnote.

34. **THE ACCESSIBILITY TREE HAS NO Z-ORDER AND NO CLIPPING, so a geometric check
   cannot tell "these share pixels" from "one of these is behind an opaque plate".**
   `LeafOverlapUITests` is the newest check here and this is its blind spot, found the
   day after it landed. It reported the hero overlapping
   `Maths only — not medical advice.` by 19.33 × 13.0pt on six calculators. Cropping
   `IB2245765` and reading the pixels: at y 720–820 there is the navy `Add` plate, the
   hero circle and the tab bar, and **the disclaimer string is nowhere in the frame at
   all**. Both elements are in the tree, the geometry is correct, and one of them is not
   drawn.
   The suite is still right that something is wrong — it is wrong about what. **Never
   read a red overlap as proof of a VISIBLE defect without looking at the frame**, and
   never read a green one as proof the content is legible: an element hidden under an
   opaque surface produces no overlap with anything and no complaint from any check we
   own. Caught only because the frame was cropped instead of the number being trusted.

35. **An assertion can observe the wrong MOMENT rather than the wrong thing, and it
   fails in a way that reads like a finding.** Two in one afternoon, same shape:
   "`Cycle Plotter` is not in the dialog either — it would be unreachable from anywhere
   in the app" was reported about a dialog **that had never opened**, because the tap
   landed on the tab bar's `Add` rather than the section's. And "No dashboard scroll
   view" came from a single query issued straight after a tab switch, which cannot
   distinguish *not there* from *not there yet* — it passed in a standalone probe
   precisely because the app had settled there and the real run had not.
   **A probe that is greener than the run it models is not a simpler version of it.**
   So: assert the PRECONDITION before drawing a conclusion from its contents, and retry
   anything read across a transition. A failing assertion is evidence about the app only
   once you know it was looking at the app you think it was.

36. **A CHECK MUST BE ABLE TO OBSERVE THE CONDITION ITS OUTPUT ASSERTS.** The capture
   harness names every frame in a default-size sweep `…-default…` and files them in a
   folder documented as default size — and until `9b4afcb` nothing in it could see the
   device's type size. `bar_gate` published `ax=true/false`, which reads **identically
   at `large`, `xLarge` and `xxxLarge`**, so a sweep run at the wrong size produced a
   full set of frames whose names asserted something the run had no way to check, and
   reported success.
   That is the **seventh** check found reporting success while observing nothing, and it
   is the one that would have quietly invalidated every "at default size" claim made in
   this audit. The probe now publishes `size=<category>` and the run fails before
   writing a single frame unless it reads `size=large`.
   **Generalised:** whenever output — a filename, a folder, a log row, a commit message
   — asserts the conditions a run happened under, something in the run must MEASURE
   those conditions. Otherwise the assertion is a label applied by intention, and
   intention is exactly what the rig does not preserve.
