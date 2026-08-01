# Harness notes and loose ends

Tacit knowledge that isn't obvious from reading the code — the things that would
otherwise cost a fresh session an hour to rediscover. Written at the close of
2026-08-01.

State lives in `docs/ui-audit/BOARD.md`; the narrative is in
`docs/SESSION-HANDOVER-2026-08-01.md`. This is the workshop floor.

---

## 1. The three red assertions — exact state, and what is already ruled out

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

- **`TEST_RUNNER_` prefix is mandatory.** `xcodebuild` does not pass shell
  environment into the runner process. `QA_EMAIL=…` silently yields a *skipped*
  suite that looks like a pass; `TEST_RUNNER_QA_EMAIL=…` works. The first run of
  these tests reported `** TEST SUCCEEDED **` while executing nothing.
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

Identifiers already in place: `field_<key>`, `quick_<key>_<value>`,
`result_<label>`. Missing: the ± steppers (see above).

**Prefer the *hittable* match over `firstMatch` when a label may appear twice.** The
off-canvas drawer duplicates every calculator name; before the accessibility fix
those resolved at x = −290. `firstMatch` is a coin toss in that situation.

## 4. Device state

Erased and **signed out**, sitting in iOS first-boot with:
- an "Allow *Maps* to use your location" alert, and
- a notifications opt-in screen.

Neither was dismissed — clicks were dead. The harness clears them via
`addUIInterruptionMonitor` (subject to the "next interaction" caveat above), or a
human can click them once in the Simulator window.

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
- **The keyboard covering the quick-value row** (see 1.3) is unresolved and probably
  deserves the same treatment the pinned result bar got.
- **The disclaimer gate is still unverified end-to-end by a human.** The harness taps
  through it, but nobody has watched a genuine first run since the app was erased.
