# START HERE — session log, 2026-08-01

Written at the end of a ~14-hour paired session (Windows Claude directing, Mac
Claude building) so a cold session can pick up without re-deriving anything.

**Read in this order:**

1. This file — what happened, what broke, how it was fixed
2. `ui-audit/BOARD.md` — current open/closed state, and the rules
3. `DESIGN-PARITY.md` — the colour, type and header rules
4. `ui-audit/2026-08-01-current/` — **what the app actually looks like now.**
   The per-cycle folders are an audit trail, not current state.

Branch `feature/tabview-shell`. Everything below is committed; nothing important
lives only in a conversation.

---

## 1. What this session was

It started as "audit the UI against mobile rules" and became four things:

1. **An accessibility and safety audit** — 17 findings, all measured, all closed
2. **Brand parity with the PWA** — the iOS app looked nothing like the web app
3. **Three real data bugs**, none of which were visible in the code
4. **A UI test harness**, built because verification kept being the bottleneck

The app went from a generic SwiftUI build with one brand colour and no type
scale, to something that reads as the same product as the web app.

---

## 2. Issues encountered, and how they were fixed

Grouped by kind. Every one of these actually happened.

### 2.1 Safety — the ones that mattered most

**Units disappeared at large text.** At the largest accessibility size the TRT
calculator rendered `Draw… 0.25…` / `Weekly… 100.0…` — the unit was inside the
ellipsis on every row. `0.25` reads as 0.25 mL or 25 units depending on what you
assume, in an app whose whole job is telling you what to draw. Users on large
text are disproportionately those least able to catch the error.
→ **Fixed** by stacking label above value on primary rows and `ViewThatFits`
with a stacked fallback on secondary rows. No `lineLimit` anywhere in that card.

**The field showed a different number from the one being calculated.** Tapping a
quick-dose chip wrote the binding but `NumberField`'s local text state didn't
follow — the field displayed **100 while the engine computed 300 mg/week**. All
27 unit tests passed throughout, because the engine was correct; the UI lied.
→ **Fixed** by syncing text on external value changes, skipped while focused so
it can't fight typing.
→ **This is why the UI test harness exists.**

**The primary CTA rendered as a blank bar.** With the keypad up, the floating
log-dose button sat on the calculator's Add button and covered its label
entirely — an unlabelled coloured rectangle as the primary action.
→ **Fixed** by hiding the hero while the keyboard is visible.

### 2.2 Accessibility

**Brand teal as text failed everywhere.** `#0FBCAD` on white is **2.38:1**. It
was the dose readout, every CTA, `Cancel`, the empty-state action, the Retry
button — and the log-dose hero's glyph, the most prominent control in the app.
→ **Fixed** by splitting the palette: `#0FBCAD` is a fill colour only,
`#075E56` / `#0A9D90` for teal text. Every surface now passes.

**Two sub-44pt tap targets.** A bare `Toggle` in a `VStack` — `maxWidth:
.infinity` widens the layout frame but not the hit area, so only the ~31pt switch
was tappable, proven by tapping the row and getting nothing. And the log-dose
date chip at 34.3pt.
→ **Toggle fixed** with a 44pt `contentShape`, keeping the native switch.
→ **Date chip accepted** as a documented deviation — it's Apple's own control,
it's 52.7pt at accessibility sizes, and it's ~120pt wide so it fails in one
dimension only. Recorded with reasoning in `BOARD.md §4`, not silently dropped.

**A CTA that didn't scale.** `PrimaryButton` rendered 91.3pt on the calculator
and 71.7pt in the log sheet at AX5 — from the same component. A `List` row was
pinning it at default size, so accessibility users got a default-sized button.
→ **Fixed** by moving it out of the `List`.
→ **Lesson: a component verified in one container is not verified.**

**A closed drawer stayed in the accessibility tree.** `allowsHitTesting(false)`
stops touches but does not remove an element. VoiceOver users could swipe into
fourteen calculator rows sitting at x = −290, off-canvas.
→ **Fixed** with `accessibilityHidden`. Found by the test harness on its first
real run — a screenshot cannot show an element at x = −290.

### 2.3 Data — none of these were visible in the code

**Saving a protocol from iOS had never worked.** Every insert was refused by row
level security because `user_id` was omitted. The *read* path omits it
deliberately (RLS scopes SELECTs) and that correct assumption was carried into
the write path, where the `WITH CHECK` made it fatal. Every row in the table was
web-created.
→ **Fixed** by sourcing the id from the session inside the data layer.

**No deduplication on protocol saves.** iOS writes straight to PostgREST and
never calls `/api/dosages`, where the dedup logic lives. Every mention of that
endpoint in the iOS source is a comment.
→ **Fixed at the database**: `UNIQUE (user_id, calculator_type, config)` on
jsonb, so both platforms get identical behaviour and neither client has to
reproduce the other's normalisation. Verified by count — 99 rows, two identical
saves, still 100 rows, zero duplicate groups.
→ `.upsert` was **rejected**: PostgREST resolves it to `ON CONFLICT DO UPDATE`,
which would overwrite `start_date` with today and shift every calendar
occurrence. Insert-then-recover-on-23505 leaves the existing row untouched.

**Three calculators wrote the wrong config shape.** iOS grouped semaglutide,
tirzepatide and retatrutide into one config case — sensible, same drug class —
but the web writes semaglutide differently. Plus `hcg` had inherited the
injectable mode pair.
→ **Found** by querying the 99 real web-created rows for their actual key sets
and diffing, rather than reviewing the catalog against itself.
→ Nine of twelve slugs are now verified against real data. Three have no web
rows and are recorded as **not knowable**.

### 2.4 Design — why the app looked wrong

`Theme.swift`'s own header said *"Mirrors the web look without forcing exact
hexes — system materials read better natively."* That instruction was the
divergence, written into the code as policy. The theme carried **one** brand
colour and **no typography at all**.

Across 14 tracked markdown files there was exactly **one** colour value —
`#0fbcad`, four times. `SCREENS.md` was ASCII wireframes: structure, not
appearance. The design had never been written down anywhere an implementer could
act on.
→ **Fixed** by extracting the real palette and type scale from the PWA source
(which only exists on the Windows box) into `DESIGN-PARITY.md`, then applying it.

**The type scale was applied only where anyone looked.** Late in the session:
ten screens still have none. That is not a straggler, it is the default state.
`DisclaimerGate` — the first screen a new user ever sees — is one of them.

### 2.5 Rig failures that cost real time

**macOS logged out.** Symptom: taps dead, screenshots fine. Diagnosed by
noticing System Events reported 0 windows for **Finder** too, and a full-display
screencapture came back uniform grey.
→ **`simctl` keeps working because CoreSimulator is a daemon with no display
dependency**, which is why the symptom points at the Simulator and isn't.

**Synthesized mouse clicks stopped working** after `simctl erase` and never came
back. Keyboard shortcuts worked; the cursor moved; accessibility trust was
granted.
→ **Solved permanently** by XCUITest, which drives through the automation layer
inside the runtime and never touches the host window server.

**Silent bad evidence, twice.** A screenshot "refresh" came back byte-identical
with matching checksums because the taps had failed, and one frame was the iOS
home screen with the app backgrounded. Separately, an automated slug sweep found
its target by scanning for a colour that also matched a picker, so six "saves"
were menu-opens.
→ Both caught by checking rather than trusting. Both deleted rather than
committed.

**The session lives in the Keychain**, so `uninstall` does not sign you out and
`erase` does. Costly to learn, useful afterwards — it means a test suite can
sign in once rather than per test.

### 2.6 Errors made by the directing side, and corrected

Recorded because the corrections are the useful part.

| Claim | Reality |
|---|---|
| "Filled teal + white text fixes the contrast" | **Contrast is symmetric.** White on `#0FBCAD` is also 2.38:1. |
| "The structure already matches, only styling differs" | The dashboards differ in **information architecture**. |
| "The protocol icons are emoji" | SF Symbols with a bad tint palette. Diagnosed from a PNG without checking. |
| "A nav bar can't grow for a wrapped title" | It grows to **two** lines, then shears the third silently. |
| "The hero is grazing the CTA" | A **12.7pt overlap**, read off a downscaled montage. |
| "`RootView:29` is the hero's z-index" | It's the medical disclaimer gate. |
| Specced the PWA's shimmer gradient verbatim | Its bright stop is **1.50:1**. The defect was propagated, not caught. |
| Specced a full-screen decorative `Canvas` | It swallowed taps on first run and made the disclaimer button look disabled. |

**The pattern: every one was settled by measuring, and several were caught by the
building side pushing back.** That only worked because pushing back was expected.

---

## 3. Rules earned the hard way

Full list in `BOARD.md §5`. The ones that paid out repeatedly:

1. **Internally consistent code is not evidence.** Three separate bugs — the RLS
   refusal, the `/api/dosages` assumption, the GLP-1 grouping — were correct by
   inspection and wrong against reality. Each took minutes to settle by querying
   the running system instead of reading the source describing it.
2. **Measure before changing a constant.** `heroOverhang` 22→38 was rebuilt and
   re-measured to *identical pixels* before being reverted.
3. **Prefer visible truncation over silent clipping.** Truncation announces
   itself; a clipped line reads as a glitch or as the whole string.
4. **Hiding is not removing.** `allowsHitTesting`, `opacity(0)` and offscreen
   offsets all leave the element in the accessibility tree.
5. **A component verified in one container is not verified.**
6. **Closing a finding protects the code that existed when you closed it.** New
   controls land underneath old bugs.
7. **Attention follows complaints, not risk.** The least-examined screen held a
   touch-target violation, the worst contrast in the app, no type scale, and a
   latent truncation bug.
8. **If taps die but `simctl` still screenshots, check the login session** before
   touching the Simulator.

---

## 4. Where to pick up

`BOARD.md` is authoritative. In short:

**In flight** — three red assertions in the XCUITest harness, all test-side
(per-field identifiers needed instead of `firstMatch`; `typeText` appends rather
than replaces). Get those green, assert one calculator end to end, review, then
scale.

**Queued, specced, not started**
- Calculator parity — `ui-audit/calculator-reference/`
- Onboarding — `WELCOME-AND-ONBOARDING.md`. **Must ship with the Settings
  Personalisation surface**, or a user sets units and timezone once at signup and
  can never change them.
- Screen header rule — `DESIGN-PARITY.md §9`
- Type scale on ten screens — one item, a sweep, not started

**Missing entirely** — dose history, inventory, four of six Settings sub-tabs,
protocol detail (the dashboard chevron currently promises navigation and
delivers none), and three calculators that exist on the web with no iOS screen.

**Needs a human decision** — dashboard information architecture (tabbed like the
PWA, or single-scroll), the greeting shimmer, Inter vs SF.

**Never verified** — the auth restyle and the welcome screen's signed-out path.
Both were blocked all session and are unblocked now.

---

## 5. Working notes

- **QA credentials** are in the webapp's `.env.local` on the Windows box as
  `DEVTOOLS_TEST_EMAIL` / `DEVTOOLS_TEST_PASSWORD`. Never commit them, and never
  screenshot a filled login form without masking. Use that account, never the
  owner's — their real email and avatar are the PII kept out of this repo all
  session.
- **The PWA source only exists on the Windows box** (`Projects\Injectbuddy`).
  The Mac cannot read it. Anything derived from it has to be written into a doc
  here or it is invisible to the building side.
- **The database is reachable from the Windows side.** Ground truth for config
  shapes, dedup and profile columns lives there — query it rather than reasoning
  about it.
- **Two screenshots contain the owner's real email and avatar.** The repo is
  private; that is a blocker on ever making it public.
