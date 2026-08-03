# Harness notes and loose ends

Tacit knowledge that isn't obvious from reading the code — the things that would
otherwise cost a fresh session an hour to rediscover. Written at the close of
2026-08-01.

State lives in `docs/ui-audit/BOARD.md`; the narrative is in
`docs/archive/SESSION-HANDOVER-2026-08-01.md` (archived 2026-08-02; the consolidated
version is `docs/archive/HANDOVER-2026-08-01-FULL.md`). This is the workshop floor.

---

## 1. The three red assertions — CLOSED 2026-08-02, and the diagnosis below was wrong

All three are green, plus a fourth. `3b8b8b1`. The original analysis is kept
underneath because **two of its three "test bugs" were app defects**, and how it
got that wrong is more useful than the fact that it did.

| Was diagnosed as | Actually was |
|---|---|
| `testQuickChip` — identifier missing from the `ViewThatFits` stacked branch | An **ambiguous** identifier. `result_<label>` matched the pinned bar AND the in-scroll copy; an ambiguous `XCUIElement` fails at resolution before printing any assertion message, which is why it "failed without surfacing its message". The `ViewThatFits` gap was real too, but it was never the first failure. |
| `testStep_movesByTen` — test bug, `firstMatch` hits vial strength | Correct. Fixed with `step_up_<key>` / `step_down_<key>`. |
| `testTypeThenChip` — test bug, clear the field before typing; keyboard probably covers the chips | **Two app defects.** Typing appended because focusing a populated field did not select it, and that fed a silent `clamp` — field `100250`, engine `1000`. And the chip row was occluded by the **pinned result bar**, not the keyboard; `tap()` reported success and moved nothing. |

Three things worth carrying forward:

1. **An XCUITest tap can pass against an occluded element.** Assert the
   consequence, never the tap.
2. **The specced test fix would have hidden the worse bug.** "Clear the field
   before typing" was correct and would have gone green — and nothing in the suite
   would ever have gone out of range again, so the clamp defect would have been
   tidied out of reach. Before making a test better behaved, ask what it stops
   reaching.
3. **`result_<label>` now names the pinned bar**; the in-scroll copy is
   `detail_result_<label>`. Identifiers name a surface.

### Original diagnosis, 2026-08-01 — kept as the record of what reading the source got you

`Tests/InjectBuddyUITests/CalculatorWiringUITests.swift`. All three **run**; sign-in
and navigation both work, so failures are at the assertion layer, not the plumbing.

### `testQuickChip_fieldAndResultBothFollow`
Fails at ~29 s without surfacing its assertion message.

**Strong suspicion, verified in the source but not yet by a run:**
`SecondaryResultRow` is a `ViewThatFits` with **two branches**, and only the
`HStack` one carries `.accessibilityIdentifier("result_\(label)")`. The `VStack`
fallback does not. So when the row stacks — which is exactly what it is *for* —
`result_Weekly total` **does not exist** and the query fails before the comparison.

→ Put the identifier on **both** branches. Better: hoist it onto the `ViewThatFits`
itself so it cannot drift again.

Ruled out: navigation (it reaches the calculator), sign-in, and the chip tap
(the other two tests tap chips successfully).

### `testStep_movesByTen`
Field stayed `"300"` after tapping Increase; expected `"310"`.

**This is a test bug, not an app bug.** `app.buttons["Increase"].firstMatch` matches
**vial strength's** stepper — it is first in the view tree. The test incremented the
wrong field, then asserted on the right one.

→ The ± buttons need per-field identifiers, e.g. `step_up_<key>` / `step_down_<key>`,
the same treatment `field_<key>` and `quick_<key>_<value>` already have. Do **not**
"fix" this by loosening the query.

### `testTypeThenChip_neverDesyncs`
Field read `"100250"`; expected `"400"`.

Two separate things:
1. `typeText` **appends** to the existing `"100"` rather than replacing it. Clear the
   field first — select-all then delete, since a plain `TextField` has no clear
   button.
2. The chip tap then had no effect, most likely because **the keyboard covers the
   quick-value row**. That is an app problem as much as a test one: a user who types
   a dose and reaches for a chip hits the same wall. Worth fixing in the app, not
   worked around in the test.

**None of the three is yet evidence of an app defect. None is evidence of
correctness either.** Green them for the right reason before trusting any of it.

---

## 2. The harness — things not obvious from reading it

- **Credentials live at `injectbuddy-ios/.env.local`** (gitignored via
  `.env.local` and `.env*.local`, verified with `git check-ignore` *before* the
  file was written), as `DEVTOOLS_TEST_EMAIL` / `DEVTOOLS_TEST_PASSWORD` — the
  same names the webapp uses, so both boxes refer to one thing. **The values are
  in that file and nowhere else**: not in a doc, not in a commit, not in a message.
- **`TEST_RUNNER_` prefix is mandatory.** `xcodebuild` does not pass shell
  environment into the runner process. `QA_EMAIL=…` silently yields a *skipped*
  suite that looks like a pass; `TEST_RUNNER_QA_EMAIL=…` works. The first run of
  these tests reported `** TEST SUCCEEDED **` while executing nothing. The whole
  invocation:

      set -a; . ./.env.local; set +a
      TEST_RUNNER_QA_EMAIL="$DEVTOOLS_TEST_EMAIL" \
      TEST_RUNNER_QA_PASSWORD="$DEVTOOLS_TEST_PASSWORD" \
      xcodebuild test -project InjectBuddy.xcodeproj -scheme InjectBuddy \
        -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
        -only-testing:InjectBuddyUITests
- **`FORCE_INLINE_FIELD=1` (DEBUG only) reproduces the `1…` truncation defect** so
  `DynamicTypeTruncationUITests` can be *shown* to go red on the real bug rather
  than trusted because it was red once. At AX5 with the flag set it reports 12
  failures across 8 calculators; without it, green. Keep the hook.
- **The truncation sweep's coverage, stated so a green run is not over-read.** It
  runs at whatever content size the DEVICE is set to, so the matrix is driven from
  the host loop in that file's header. Landed coverage is **default + AX5 across
  all 14 calculators**; the intermediate sizes are not run per commit. Three
  calculators (Semaglutide, Tirzepatide, Retatrutide) have **no numeric fields at
  all** and are measured by nothing — the suite prints that rather than skipping
  silently. And the assertion is a **ratio**, so it is blind to a container that
  squeezes value and unit together, and to a long value beside a short unit
  (`1000` -> `10…` next to `mg` still passes). It bans the mechanisms we know,
  exactly as F1's `lineLimit` ban did.
- **A capture run MUTATES GLOBAL DEVICE STATE, and the next suite inherits it.**
  `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` is
  set on the *device*, not the run. Leaving it set made all four wiring assertions
  fail on the next invocation — at AX5 the calculator reflows and the tests are
  addressing a different layout. It looked like the app had broken; nothing had.
  **Always reset with `content_size large` after an AX5 sweep**, in the same shell
  command, so a crash cannot leave the device dressed for the wrong test.
- **An append-only log is a record of capture EVENTS, not a promise that every
  file is still on disk.** Superseded frames are removed from the working tree so
  that a folder called "current" contains only current frames — the row plus its
  commit is the durable artifact, and `git show <sha>:<path>` retrieves any of
  them. A folder holding two full sets is a folder nobody trusts.
- **The capture sweep is opt-in and separate.** `CaptureCurrentState` skips
  unless `TEST_RUNNER_CAPTURE=1`, so a normal run is not two minutes of
  screenshots. It sets `continueAfterFailure = false` deliberately: with it true,
  a failed navigation produced a genuine photograph of the Tools screen under a
  filename claiming the TRT calculator. A sweep that cannot fail loudly will keep
  producing frames that lie.
- **`XCTSkipUnless` lives in `setUpWithError`** so a machine without credentials
  reports *skipped*, never *failed*. Deliberate: a red test for a missing secret
  trains people to ignore red tests.
- **Sign-in happens at most once per run.** The Supabase session is in the
  **Keychain**, so it survives app relaunch between test methods; `signInIfNeeded`
  short-circuits on seeing the Dashboard. Do not "simplify" it into a per-test
  sign-in — repeated auth against real Supabase will rate-limit, and the suite will
  start failing on lockout in a way that looks like a product bug.
- **Interruption monitors fire on the *next* interaction**, not when the alert
  appears. If a prompt blocks the very first tap, add a deliberate no-op interaction.
- Each test costs ~25–60 s because it relaunches and re-navigates. That is the price
  of testing the real wiring; don't optimise it away by sharing state between tests.
- **Never assert on a credential**, and never let one into a failure message — the
  `.xcresult` bundle is a place a password leaks by accident.

## 3. Addressing elements

Identifiers in place, and what each one *names*:

| Identifier | Addresses |
|---|---|
| `field_<key>` | the numeric text field |
| `step_up_<key>` / `step_down_<key>` | that field's ± pair — added 2026-08-02 |
| `quick_<key>_<value>` | the quick-value chip **under the field** |
| `kb_quick_<key>_<value>` | the same chip **in the keyboard toolbar** |
| `kb_done` | the keyboard toolbar's Done |
| `result_<label>` | the row in the **pinned result bar** |
| `detail_result_<label>` | the same row in the **in-scroll card** |

**An identifier names a surface, not a value.** Both quick rows and both result
cards are in the tree at once, so a single name for either pair is ambiguous — and
an ambiguous `XCUIElement` **fails at resolution, before your assertion runs**.
That failure has no message of its own, which is how "the element is missing" was
believed for a session. `CalculatorWiringUITests.unique(_:type:)` counts first and
names the duplicates when it finds them.

**`kb_done` is the one exception, and it is not fixable from the app side.** A
keyboard `ToolbarItemGroup` bridges its items to UIKit and publishes the
identifier on both the bridged bar button and the hosted SwiftUI label — measured
as two elements at (348, 539, 38, 44) and (345, 539, 44, 44). Reordering the
modifiers changed nothing; `accessibilityElement(children: .ignore)` changed
nothing, to the pixel. The test narrows to `.button` for that one control only.

**An XCUITest tap can PASS against an occluded element.** `quick_mgWeek_400.tap()`
reported success while the model never moved, because the chip was behind the
pinned result bar. A passing tap is not evidence of an interaction; only a state
change is.

**Prefer the *hittable* match over `firstMatch` when a label may appear twice.** The
off-canvas drawer duplicates every calculator name; before the accessibility fix
those resolved at x = −290. `firstMatch` is a coin toss in that situation.

## 4. Device state — corrected 2026-08-02

**The previous text here said erased and signed out at iOS first-boot. That is no
longer true, and a cold session planning around it is wrong within minutes.**

Observed on 2026-08-02: iPhone 16 Pro / iOS 18.3, booted, **not erased** since the
previous session. Both `com.injectbuddy.ios` and
`com.injectbuddy.ios.uitests.xctrunner` are still installed. Launching the app
goes straight past the disclaimer to the signed-in dashboard as `devtools` — the
Keychain session survived — and the location alert and notifications opt-in were
consumed last session.

Two consequences:

- `addUIInterruptionMonitor` and `dismissDisclaimerIfPresent` get **no coverage**
  from runs on this device. They are still in `setUp`, still correct, and
  currently unexercised. Do not read a green suite as evidence that first-run
  works.
- **First-boot is now only reachable via `simctl erase`, and that costs the
  session** — the Keychain goes with it and the next run does a real Supabase
  sign-in. Worth doing deliberately, once, when first-run is the thing under test.
  Not worth doing in the middle of a block.

## 5. Mid-thoughts, left open deliberately

- **The welcome curves have never been seen in motion.** The stills under-read a slow
  drift, so the real question — does it register at all in the two or three seconds a
  signed-out user is there? — is unanswered. If it doesn't register, `Canvas` +
  `TimelineView` is cost for nothing and solid curves would do. The lever is stroke
  width or opacity, **never** extending them upward into the text.
- **`Theme.srgbStops` is kept even though it did not fix the gradient.** It is
  correct code and useful for fills, where the desaturation isn't visible. It is not
  a fix for text and the comment says so — don't delete it, and don't reach for it on
  text.
- ~~The keyboard covering the quick-value row deserves the same treatment the
  pinned result bar got.~~ **Resolved 2026-08-02, and the premise was wrong: the
  pinned result bar IS the occluder.** It sits above the keyboard and covers the
  strip the chips are in. The focused field's quick values now ride in a keyboard
  toolbar, reachable by construction rather than by where a field happens to sit
  in the form, with a Done button — the `.decimalPad` had no dismiss affordance at
  all. Left open: with a hardware keyboard attached the software keypad is
  suppressed and that accessory bar sits directly on the tab bar (visible in
  `IB2245732`). Real for anyone on a Bluetooth keyboard. Written down, not fixed.
- **The disclaimer gate is still unverified end-to-end by a human.** The harness taps
  through it, but nobody has watched a genuine first run since the app was erased.
