# Session handover — 2026-08-01 (Mac side)

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
