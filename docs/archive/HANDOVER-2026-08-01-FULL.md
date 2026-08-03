# InjectBuddy iOS — full session handover, 2026-08-01

**One self-contained document.** Everything a fresh session needs: what was done,
where things stand, what is still open, every error found and how it was solved, and
how the two paired Claude instances communicate.

Branch `feature/tabview-shell` · 48 commits this session · 149 files · +4630/−284
Session start `48992c9` → head at time of writing `bc7199a` · tree clean, all pushed.

Consolidates `docs/SESSION-HANDOVER-2026-08-01.md` and
`docs/HARNESS-AND-LOOSE-ENDS.md`. Live status stays in `docs/ui-audit/BOARD.md`;
what the app currently looks like is `docs/ui-audit/2026-08-01-current/`.

---

Written at the end of a ~12-hour paired session so the next one starts informed
rather than cold. **Read `docs/ui-audit/BOARD.md` first** — that is the live state.
This file is the narrative: what happened, what broke, and how we work.

Branch `feature/tabview-shell`, 47 commits, 149 files, +4630/−284.
Start `48992c9` → head `95702e0`. Working tree clean, everything pushed.

---

## 1. How the two sides communicate

There are **two Claude instances** on a cross-claude message bus, channel
`#win-mac-20260801-1633`.

- **Windows = TEACHER.** Sets direction, makes final calls, holds the PWA source
  (`C:\Users\PFrew\Projects\Injectbuddy`) and **database access**. The Mac has
  neither.
- **Mac = STUDENT (this side).** Has the macOS toolchain — Xcode, simulator,
  screenshots, measurement. The teacher cannot see anything render.

**The working discipline, which is why the session went well:**

- The teacher decides; once decided, follow it. But **push back once, with
  evidence, when you can see something they can't.** That happened repeatedly and
  changed what shipped every time.
- **Never send agreement-only messages.** Silence is the correct reply to "good
  work". Don't reply to a `done`.
- Messages cross constantly — check the channel before sending; drop anything
  superseded.
- **Everything important goes in git, not in chat.** The teacher pulls; the next
  session reads. Conversation is lost, commits aren't.

**Pushing back was right more often than not.** Corrections the Mac made that the
teacher accepted: contrast is symmetric (a filled teal button fixes nothing); the
PWA dashboards differ in *content* not just styling; `.upsert` would silently
corrupt `start_date`; the protocol icons were never emoji; `.principal` *does* wrap
to two lines; a 12.7pt overlap isn't "grazing". The teacher corrected the Mac too —
most usefully on prioritisation, where "the human has flagged this class of thing
twice unprompted" beat an abstract severity argument.

---

## 2. What was done

**Audit → 17 findings, measured.** Every colour figure comes from sampling the
composited framebuffer at exact device points and computing WCAG ratios, calibrated
first against known Apple values. Not from a GUI eyedropper — that isn't scriptable,
and screenshots already carry resolved material values.

**Then eight-plus build cycles.** The headline fixes:

| Area | What |
|---|---|
| Safety | AX5 result rows truncated the **unit** off dose values — `0.250 mL` rendered `0.25…`. Rows now stack or reflow; no value+unit pair carries a `lineLimit`. |
| Data | **iOS protocol saving had never worked** — every insert refused by RLS because `user_id` was omitted. |
| Data | No dedup on saves. Fixed with a DB unique index on `(user_id, calculator_type, config)`; insert-then-recover on 23505, deliberately **not** `.upsert`. |
| Data | Three config shapes diverged from what the web actually writes (`hcg`, `tirzepatide`, `retatrutide`). |
| Contrast | Every failing surface: dose readout and CTAs 2.38 → 15.79:1; hero glyph 2.38 → 6.43:1; `danger` 3.11 → 7.90:1. |
| Parity | Brand palette + type scale (the theme had **no typography at all**), navy header squares, wordmark, density, per-compound spine. |
| Chrome | Dark mode removed and locked via `project.yml`. Centre tab slot drew a second syringe under the hero. Hero overlapped content app-wide. |
| New | Welcome screen with drifting serum curves; barrel segmented picker; quick-value dose buttons; log-dose sheet rebuilt. |
| Test | **XCUITest harness** — the thing that makes the rest verifiable. |

---

## 3. Errors found, and how they were solved

The valuable part. Every one of these was found by **running the app**, not by
reading it.

1. **AX5 unit truncation.** `HStack { label; Spacer(); value }` has no fallback
   axis, so SwiftUI truncated both children. → primary rows stack
   label-above-value; secondary use `ViewThatFits`.
2. **RLS refusal on insert.** Reads omit `user_id` because RLS scopes SELECTs; that
   assumption was copied into the write, where `WITH CHECK` made it fatal. → take
   the id from the live session inside the data layer.
3. **`.upsert` would have corrupted schedules.** PostgREST resolves it to
   `ON CONFLICT DO UPDATE`, overwriting `start_date` with today and shifting every
   projected dose. → insert, catch 23505, return the existing row untouched.
4. **NumberField desync.** A quick-value chip wrote the binding but not the field's
   local text: **the field showed 100 while the engine computed 300 mg/week.** →
   sync text on external change, skipped while focused.
5. **Gradient text renders desaturated.** SwiftUI desaturates *any* multi-stop
   gradient — `#075E56` came out `#4B5557`. Proved by a same-colour gradient
   rendering exactly right, and pre-blending 25 stops changing nothing. → solid
   fills; the shimmer is filed, not built.
6. **`.principal` caps at two lines and clips the third silently.** Probed rather
   than assumed. → branded header lives in the content area.
7. **Closed drawer stayed in the accessibility tree** at x = −290.
   `allowsHitTesting(false)` stops touches but not VoiceOver. → `accessibilityHidden`.
   **Found by the XCUITest harness on its first real run** — a screenshot cannot
   show an element at x = −290.
8. **Two rig failures I wrongly blamed on the app.** The GUI session logged out, and
   later the Simulator stopped accepting synthesized clicks. Both times I reported an
   app defect and had to retract it. The second became "first run is broken", which
   would have been a launch-blocking claim carried forward by someone with no reason
   to doubt it.

---

## 4. Where we are

**Working and verified:** everything in `BOARD.md §3`. Build green, 27/27 unit tests,
XCUITest probe passing.

**In flight:**
- **Three wiring assertions are RED** for documented, legible reasons — per-field
  stepper identifiers missing, `typeText` appends rather than replaces. **Not
  evidence of an app bug, and not evidence of correctness.** Get them green *for the
  right reason* before trusting them.
- Auth restyle is code-complete but **never seen** — ticked `[~]`.
- Welcome curves have **never been judged in motion**.

**Not started, queued in priority order:** calculator parity rebuild
(`docs/ui-audit/calculator-reference/`), the `Other` mode-switch, the plotter link
card, onboarding **coupled with the Settings Personalisation surface**.

**Needs a human decision (`BOARD §2`):** whole PWA sections with no iOS screen —
`history`, `inventory` (and `vial_inventory` is a live table with rows), four of six
settings sub-tabs. Type scale missing on **ten** screens. Protocol cards render a
chevron that navigates nowhere.

---

## 5. Rig state — read before touching the simulator

- **Synthesized mouse clicks do not reach the Simulator.** Keyboard does.
  `AXIsProcessTrusted()` is true and the cursor moves, so it is the Simulator
  refusing them. Survives quit + `kill -9` + reopen. A host reboot is the standard
  fix and was **declined** as unnecessary.
- **Drive the app with XCUITest instead** — it never touches the host window server:
  `TEST_RUNNER_QA_EMAIL=… TEST_RUNNER_QA_PASSWORD=… xcodebuild test -only-testing:InjectBuddyUITests`
  (note the `TEST_RUNNER_` prefix — plain env vars do **not** reach the runner).
- **Screenshots still work** — `xcrun simctl io booted screenshot` reads the
  framebuffer.
- **The device was erased and is signed out**, sitting in iOS first-boot with
  permission prompts. The harness clears them via `addUIInterruptionMonitor`.
- **The session lives in the Keychain**, so `simctl uninstall` does *not* sign out;
  `simctl erase` does.
- **QA credentials** exist for `devtools@injectbuddy.com`, held by the Windows side.
  **Never commit them**, never screenshot an unmasked password field, never sign in
  as the human's own account.

---

## 6. The rules this session earned

In `BOARD.md §5`, and they were all paid for:

1. **Internally consistent code is not evidence.** Three bugs were correct by
   inspection and wrong against reality.
2. **Measure before changing a constant.**
3. **Contrast is symmetric.**
4. An outer `safeAreaInset` cannot lift a sibling inset pinned further in.
5. A montage is a survey instrument, not a measuring one.
6. **Hiding is not removing** — `accessibilityHidden` as well as the visual guard.
7. Prefer a container that truncates visibly over one that clips silently.
8. Closing a finding protects only the code that existed when you closed it.
9. **The screens nobody complains about are where defects accumulate.**
10. A component verified in one container is not verified.
11. If taps die but `simctl` still screenshots, **check the login session** before
    blaming the Simulator.

---

# Part B — harness notes and loose ends

Tacit knowledge that isn't obvious from reading the code: the things that would
otherwise cost a fresh session an hour to rediscover.

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

---

## Where to pick up, in order

1. **Green the three assertions — for the right reason.** The `ViewThatFits`
   identifier gap is the likely cause of the first; the other two are test-authoring.
   A test that passes because it asserted the wrong element is worse than no test.
2. **One calculator fully asserted end to end**, then show it before scaling to the
   rest. A wrong assertion pattern replicated twelve times looks like coverage.
3. **Calculator parity rebuild** — `docs/ui-audit/calculator-reference/`. Five-control
   stepper row, per-field quick strips with the PWA's own numbers, `Other` as an
   in-place mode switch.
4. **The plotter link card** — small, and it opens `CyclePlotterScreen`, which exists
   and nothing currently links to.
5. **Onboarding *with* the Settings Personalisation surface.** Not onboarding alone —
   that is a one-way door.

Needing a human decision before anyone builds: the missing PWA sections (`history`,
`inventory`, four of six settings sub-tabs), the type scale absent on ten screens,
and protocol cards whose chevron navigates nowhere.
