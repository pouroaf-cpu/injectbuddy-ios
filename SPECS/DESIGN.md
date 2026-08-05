# UX / UI rules

> **Read-only to agents. Changes go through the owner.**

Written 2026-08-04. Draft — the values are as verified in `Theme.swift` and the palette work of
2026-08-01; the rules are what earned their place by catching something. Strike anything you
disagree with; nothing here is settled until you say so.

**This is a dosing app.** The user acts on the numbers it shows. Every rule below exists because a
number was hidden, clipped, unreachable or wrong-looking, not because of taste.

---

## 1. How these are checked — snapshot first

**Snapshot tests are the default. The device is the exception.**

A snapshot renders a view straight to a PNG inside the unit suite — no launch, no auth, no network,
no navigation. Fifteen calculators at three text sizes is one run of about a minute. The same
coverage on the device is hours.

- **Anything visual is a snapshot test.** Layout, truncation, spacing, colour, type, Dynamic Type.
- **The device answers only what a rendered view cannot:** does a row land in the database, does
  navigation reach the screen, is a control actually hittable under a pinned bar.
- **A recorded reference is looked at once, by a human, when it is recorded.** A snapshot recorded
  from a broken state passes forever — that is the same failure as a green that means nothing.
- **A diff is reviewed, never blessed.** If a reference changes, someone says why in the commit.

## 2. Numbers are never hidden

- **No `lineLimit` on a value+unit pair, or on a screen title.** Units vanishing at large text is
  the worst defect this rule set has caught.
- **Visible truncation beats silent clipping.** An ellipsis tells the user to go looking; a sheared
  glyph reads as the whole string. Never accept a clipped value, unit or title.
- **Nothing a user acts on may sit under pinned furniture.** A dose volume behind the result bar is
  the app lying about a number.

## 3. Reachability

- **The primary action must be reachable without scrolling at every supported text size — and so
  must the input it commits.** Binary. A CTA you can reach that commits a field you cannot is a
  failure, not a partial pass.
- **Minimum hit target 44pt** (`Theme.minTarget`). Note that `minHeight: 44` plus padding renders
  taller than 44 — measure the resulting frame, do not assume the floor is the height.
- **Hiding is not removing.** `opacity(0)`, off-screen offsets and `allowsHitTesting(false)` all
  leave an element in the accessibility tree. Anything conditionally shown needs
  `accessibilityHidden` as well.

## 4. Spacing and geometry

- **Every spacing value comes from `Theme.Spacing`:** `xs 4 · sm 8 · md 16 · lg 24 · xl 32`. A 4pt
  grid. No raw numbers in `.padding`. If the value you want is not on the scale, add a token — do
  not inline a number.
- **One screen margin** — `Spacing.md`, everywhere. Content never touches the edge.
- **One control height.** Any two controls stacking in the same flow are the same height, set once
  at the shared control.

### The gap rule — vertical is double horizontal

Two things beside each other and two things stacked are not the same relationship, and the spacing
should say so. At the same level of grouping:

| Relationship | Gap | Token |
|---|---|---|
| Side by side — a value and its unit, two buttons in a row | **8** | `sm` |
| Stacked — a label above its field, a row above the next row | **16** | `md` |
| Between groups — one section and the next | **32** | `xl` |

**Vertical gap is twice the horizontal gap at the same level.** 8 across, 16 down. A group break is
double again. Nothing between a screen's margin and its content but `md 16`.

**The same numbers everywhere on the device.** The gap between two stacked rows on the dashboard is
the gap between two stacked rows on a calculator. If a screen needs its own spacing, that is a
finding about the screen, not a licence.

## 5. Colour

The app is **light only**. `UIUserInterfaceStyle: Light` is locked; dark paths were removed
deliberately.

| Role | Token | Contrast |
|---|---|---|
| Primary CTAs, header icon buttons, the FAB | `navy` #001D5C, white on it | 15.79:1 |
| Teal text | `tealTextStrong` #075E56 on white | 7.65:1 |
| Large teal text only | `tealText` #0A9D90 | 3.37:1 |
| Tints, selected states | `accentSoft` #EAFAF8 | 7.12:1 |
| Accents, wordmark, decoration | `accent` #0FBCAD | **never text** — 2.38:1 |

- **#0FBCAD is never a text or glyph colour, and white is never placed on it.**
- **Contrast is symmetric** — swapping foreground and background changes nothing. Fix it by changing
  a colour, not by flipping the pair.
- **Both brand colours are load-bearing.** Navy is the action colour, teal is the brand hue. Do not
  drain one to make the other dominate.

## 6. Fix at the shared control

There is one `CalculatorScreen` driving all fifteen calculators, one result bar, one `FieldRow`, one
`SegmentedRow`. **A visual fix lands at the control, never at a screen.** If it cannot be expressed
at the control, say so — that is a finding about the architecture.

Verify at default size on `trt`, plus at least one screen outside the top five. A control-level fix
that is right on `trt` and wrong on `hcg` is a fact about the control.

## 7. Motion

- **Text arrives, it does not appear.** Per-line reveal, staggered, headline then body then action.
  Once on entry — never re-animated on a back-navigation.
- **Reduce Motion is honoured**: everything lands in its final state, no offset, no stagger, and the
  fade removed where it carries no state.
- **Motion is judged by eye, not asserted.** Screenshot comparison cannot measure it here — the
  arrival proof consumes the animation window, and the one screen where it does not has a blinking
  caret on it.

## 8. Everything responds

**Nothing a user can touch is inert.** If a control can be pressed, it must visibly change while
pressed, and confirm when it acts.

- **Pressed state on every control.** Fill, scale or tint — one of them, chosen once and used
  everywhere. A control that looks identical for half a second reads as broken and gets pressed
  twice. In a dosing app that means two logged doses.
- **Feedback within 400ms of the touch**, and before the work finishes. If a write is in flight, the
  control says so — a spinner, a disabled state, something. Never a button that looks untouched
  while the network runs.
- **Haptics on anything that commits.** Logging a dose, saving a protocol, confirming a start day,
  deleting an account. `.sensoryFeedback` — success on a confirmed write, warning on a refusal.
  Never on navigation; a haptic on every tap becomes noise and stops meaning anything.
- **Sound is optional and off by default.** iOS convention is haptics, not audio, and a dosing app
  should not chirp in public. If sound ships, it respects the silent switch and has a setting.
- **Hover is iPad and pointer only.** On iPhone the pressed state is the whole of it — do not build
  a hover affordance the phone can never show.
- **Selected state is visible without colour alone.** Fill plus weight, or fill plus a mark. Colour
  by itself fails for a colourblind user and fails in a screenshot.

## 9. Density — nothing fights for room

- **Text never overfills its container. The container grows, the text does not shrink or clip.**
  If a string cannot fit, the container is wrong. Never solve it by truncating a value, a unit or a
  title — see §2.
- **Fit the primary flow above the fold at default size.** Everything a user needs to complete the
  screen's job should be visible without scrolling on the standard device. If it does not fit, cut
  something rather than pushing it below.
- **At accessibility sizes, scrolling is acceptable** — but the primary action and the input it
  commits stay reachable (§3). That is the line between "long" and "broken".
- **Don't clutter.** One primary action per screen. Decorative chrome over roughly a fifth of the
  content area is a prompt to look again. If two things are competing to be the main thing, one of
  them is not.
- **Uniformity beats cleverness.** The same control looks and behaves the same on every screen. A
  screen that needs a bespoke variant is a finding, not a feature.

## 10. Standing decisions — do not re-file these as defects

- **Mid-word hyphenation is accepted.** `Semaglu-tide` is not a defect. Overlap, clipped titles and
  icons that stay small while text grows still are.
- **BMI and Free T Index are withdrawn.** No layout or styling work on either.
- **Default-size defects outrank accessibility-size defects.** Dynamic Type work is deferred; a
  defect that reproduces at default size is not.
