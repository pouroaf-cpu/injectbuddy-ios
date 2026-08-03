# Mobile UI / HIG audit — findings

**Build** `48992c9` · iPhone 16 Pro simulator (402 × 874 pt, 3×) · iOS 18.3 · Xcode 16.2
· light appearance · sRGB. Evidence: the PNGs in this folder, indexed in [README.md](README.md).

Audit only — nothing in this report has been fixed.

> **Status: stopped early, by decision, not finished.** On 2026-08-01 the contrast sweep was
> cut short in favour of the design-parity rebuild, on the grounds that measuring screens
> that are about to be rewritten is waste. What is here was measured and stands as the
> before-state record. What was never reached is listed in §5. The screens most likely to
> hold unmeasured failures are Calendar, Add, Cycle Plotter and the auth flow — only
> Dashboard, Tools, the drawer, Settings, the log-dose sheet and two calculators were swept.

---

## 0. Method and calibration

Contrast is computed from the composited framebuffer, not from a GUI eyedropper.
`simctl io booted screenshot` writes the same pixels the screen is showing: translucency
and materials are already resolved by the compositor before the PNG exists. Demonstrated
on `03-calculator-semaglutide-default.png` — the `.regularMaterial` result card interior
reads **#FDFDFD** while the page behind it reads **#F2F2F7**. Had the screenshot flattened
the material, both points would read the same value.

**Colour space.** `sips -g space -g profile` reports `RGB / sRGB IEC61966-2.1` on these
captures — not Display P3, so the WCAG luminance formula applies directly. The sampler
also draws through an sRGB `CGContext`, so a P3-tagged source would be converted rather
than misread.

**Scale.** Coordinates in this report are device **points**; the sampler multiplies by 3
before indexing the 1206 × 2622 buffer.

**Calibration against known Apple values** (from `06-drawer-open.png`):

| Pair | Expected | Measured |
|---|---|---|
| `systemBackground` | #FFFFFF | **#FFFFFF** exact |
| `.label` on `systemBackground` | 21:1 (#000000 on #FFFFFF) | **21.00:1** exact |
| `.secondaryLabel` on `systemBackground` | 3.44:1 (#3C3C43 @60% → #8A8A8E) | 3.69:1 by darkest-pixel |

Flat surfaces reproduce exactly. The third row is the one that matters: sampling the
darkest pixel of an antialiased glyph read **+0.25 optimistic**, because iOS stem-darkening
renders thin strokes *darker* than the nominal colour. So throughout this report,
**text foregrounds are taken from the source colour** (`Theme.swift` or the UIKit semantic
value) and **only backgrounds are sampled from the PNG**. Where a foreground is quoted from
pixels it is a solid fill several points thick, and is marked as such.

Independent confirmation the pipeline tracks reality: with Increase Contrast enabled,
`.secondaryLabel` measured **#000000 / 20.47:1**, up from #8A8A8E / 3.44:1 — the exact
behaviour Apple documents for that setting.

**Thresholds used.** 4.5:1 body text; 3:1 only for genuine 18pt+ regular or 14pt+ bold;
3:1 for icons, glyphs, input boundaries and selection indicators (WCAG 1.4.11); 7:1 treated
as the target, so anything between 4.5 and 7 is called out as "passes, below target".
Disabled controls and decorative art are exempt — the exemptions I applied are listed in §4.

---

## 1. Critical and high

### F1 — CRITICAL — At AX5 the calculator truncates dose values *and their units*

`15-calculator-trtdose-dynamictype-ax5.png`. At `accessibility-extra-extra-extra-large`
the result card renders:

```
Draw…          0.25…
Units (…       25.0
Dose p…      50.00…
Injections /…  2.00
Weekly…      100.0…
```

The unit is inside the ellipsis on three of five rows. `0.250 mL` displays as `0.25…` —
and 0.25 mL on a U-100 syringe is 25 units, so the same visible glyphs have two plausible
readings with nothing on screen to disambiguate them. `100.0…` could be 100.0 mg or
100.00 mg. The labels truncate too, so `Draw…` no longer says *which* quantity it is.

**Structurally incapable of reflowing.** `CalculatorScreen.swift:117-128` — each row is

```swift
HStack {
    Text(row.label) …
    Spacer()
    Text(row.value) …
}
```

A single-line `HStack` with a `Spacer` between two `Text`s has no fallback axis: when the
proposed width is insufficient SwiftUI truncates both children rather than stacking them.
There is no `ViewThatFits`, no `@Environment(\.dynamicTypeSize)` branch, no
`.allowsTightening`, no minimum scale factor. **Every row in `result.rows` is affected.**
The one element on that card that *does* reflow is `result.scheduleLine`
(`CalculatorScreen.swift:129-133`), because it is a standalone `Text` with no sibling
competing for width.

The population most likely to be running AX5 is the population least able to catch a
misread dose.

### F2 — HIGH — With the keyboard up, the raised hero circle hides the Add button's label entirely

`12-calculator-keyboard-decimalpad.png`. The primary action renders as a **blank teal
rectangle** — no visible text at all.

`MainShell.swift:124-141`: `heroButton` is an `.overlay(alignment: .bottom)` on the
`TabView`, lifted with `.offset(y: -22)`. When the keyboard raises, the tab bar is covered
and the overlay repositions to the new bottom edge — which is now the calculator's
`resultBar`, landing the 54 × 54 pt circle plus its 4pt stroke dead centre on the
`PrimaryButton` label.

The tap still works (`.allowsHitTesting(false)` passes it through) and VoiceOver still
reads the button, so this fails only for sighted users — the kind of defect that survives
an accessibility sweep. A user entering a dose sees an unlabelled coloured rectangle as
the primary action.

### F3 — HIGH — The primary dose readout is the lowest-contrast text on the screen

`Theme.accent` = **#0FBCAD** (`Theme.swift:10`), used for `row.emphasis` values in
`ResultCard` (`CalculatorScreen.swift:125`).

| Foreground | Background | Measured | Required | Verdict |
|---|---|---|---|---|
| #0FBCAD | #FDFDFD (result card) | **2.34:1** | 3:1 large / 4.5:1 body | FAIL |
| #0FBCAD | #FFFFFF | **2.38:1** | 4.5:1 | FAIL |
| #0FBCAD | #F2F2F7 (grouped bg) | **2.13:1** | 4.5:1 | FAIL |

`0.250 mL` is `.title3.weight(.bold)` — 20pt bold, which does qualify for the relaxed
3:1 large-text threshold. It still fails it.

**The contrast hierarchy is inverted against the information hierarchy.** On
`11-calculator-trtdose-default.png` the two teal values — `0.250 mL` and `25.0` — are the
primary results, the numbers a user acts on. Every secondary row (`50.00 mg`, `2.00`,
`100.0 mg`) is `Theme.label` = #000000 on #FDFDFD ≈ **20:1**. The app renders its most
safety-critical numbers at 2.34:1 and its least important ones at 20:1.

The PWA already solves this and the values are in `docs/DESIGN-PARITY.md`: #0A9D90
(**3.37:1**) and #075E56 (**7.65:1**) for teal *text*, reserving #0FBCAD for fills and
large display type. #075E56 is the only one of the three that clears the 7:1 target.

### F4 — HIGH — Hardcoded brand colours do not respond to Increase Contrast

Measured on the same point in `16-` (off) and `17-` (on), identical scroll position:

| Colour | Increase Contrast OFF | ON | Responds? |
|---|---|---|---|
| `Theme.accent` #0FBCAD, teal text on card | #0FBCAD — **2.28:1** | #0FBCAD — **2.28:1** | **No** |
| `.secondaryLabel` (semantic) | #8A8A8E — 3.44:1 | #000000 — **20.47:1** | Yes |

Semantic colours earn their accessibility behaviour for free; the five hardcoded hexes do
not, and a user who has explicitly asked the system for more contrast gets none from them.

Every hardcoded hex in the codebase (`Theme.swift:10,11,21,22,23` — these are the only
literal colours in the source; the asset catalog carries only `AccentColor`):

| Token | Hex | On #FFFFFF | Verdict |
|---|---|---|---|
| `accent` | #0FBCAD | 2.38:1 | FAIL as text |
| `accentSoft` | #0FBCAD @14% | — | tint fill only, exempt |
| `danger` | #FF5757 | **3.11:1** | FAIL body text (used as text, `CalculatorScreen.swift:101`) |
| `warning` | #F59E0B | **2.15:1** | FAIL as glyph (3:1), `Components.swift:165` |
| `success` | #34D399 | **1.92:1** | FAIL as glyph (3:1), `DashboardComponents.swift:25` |

---

## 2. Medium

### F5 — Input fields have no visible boundary at all

`NumberField` and both `Picker` variants set `.background(Theme.secondaryBackground)`
(`CalculatorScreen.swift:184, 196, 245`) = `secondarySystemBackground`. The calculator page
sets `.background(Theme.groupedBackground)` (`:50`) = `systemGroupedBackground`. In light
mode those are **the same colour**: sampled #F2F2F7 inside the field at pt(100,213) and
#F2F2F7 outside it at pt(200,255) on `11-`.

Boundary contrast **1.00:1** against a required 3:1 (WCAG 1.4.11). Nothing marks where a
field begins or ends; the only cue that a value is editable is that it happens to be a
number. Visible in `11-calculator-trtdose-default.png` — the two stepper pills read as the
only controls on the screen.

Note this was previously masked: in dark mode the two tokens differ (#1C1C1E vs #000000)
and the field is visible. With the light-only decision this is now permanent, not a
mode-specific artifact.

### F6 — Steppers are 32 pt tall, and the two halves are flush against each other

Measured from `11-` by edge scan: the pill spans pt y **198.0 → 229.7** (**32.0 pt**) and
x **276.0 → 369.7** (**93.7 pt**), split by a 1pt divider into halves of **46.0** and
**46.4** pt.

Each half is **46 × 32 pt** against a 44 × 44 pt minimum — 12 pt short vertically. The two
halves are adjacent with **0 pt** separation and perform opposite operations on a dose
value, which is the pairing the spacing rule exists for.

### F7 — The number field's tap target is ~20 pt tall

`NumberField` (`CalculatorScreen.swift:224-247`) puts `.padding(.vertical, 10)` on the
`HStack`, giving a 52 pt container — but the padding belongs to the container, not the
`TextField`, and there is no `.contentShape(Rectangle())` to extend the hit area. Only the
`TextField`'s own frame focuses it: body text, **≈20.3 pt** tall against 44.

Observed in practice — a tap at the vertical centre of the row focused the field, a tap
16 pt higher (still inside the visible container) did not.

### F8 / F9 / F10 — Sub-minimum targets elsewhere (source-derived)

| Control | Source | Height | vs 44 pt |
|---|---|---|---|
| Menu picker rows (`Frequency`, `Ester`) | `CalculatorScreen.swift:179-185` — `.padding(.vertical, 10)` + body 20.3 | **40.3 pt** | −3.7 |
| Drawer nav rows | `DrawerView.swift:117-127` — `.padding(.vertical, 10)` + body 20.3 | **40.3 pt** | −3.7 |
| Drawer footer: theme toggle, **Sign out** | `DrawerView.swift:47-65` — `Label(...).font(.subheadline)`, no padding | **≈20 pt** | −24 |

The drawer footer is the worst of these: **Sign out is a destructive action with a ~20 pt
target and no confirmation** (`DrawerView.swift:56-64` calls `auth.signOut()` directly).
The teal theme glyph next to it measures 10.6 pt tall by pixel scan on `06-`, consistent
with a label-sized hit box rather than a control-sized one.

### F11 — While the keyboard is up, the result bar clips the adjacent input row

`12-`, vertical edge scan at x=8pt: the page background ends at pt **306**, the result bar
runs **306 → 583** (277 pt), the keyboard runs **583 → 874** (291 pt). Combined,
**568 pt of 874 — 65% of the screen — is obstructed**, leaving ~151 pt of form below the
navigation bar.

The consequence is visible: the `Weekly dose / 100 mg/week` row is cut in half by the
result card's top edge. With the decimal pad open the user can neither fully see the input
they are editing nor read the button they are about to press (F2).

This gets worse with longer specs — `peptide` has 5 fields and `bpc157blend` has 6
(`CalculatorCatalog.swift:241-297`) against TRT Dose's 4.

### F12 — At AX5 the result bar takes 64% of the screen with no keyboard involved

`15-`, same scan: page background ends at pt **228.7**; the result bar runs **229 → 790**
= **561 pt of 874 (64%)**. Above it sit the back button, the large title and one field
label. The scrollable form viewport is roughly **29 pt** until the large title collapses,
after which it is still under ~90 pt — less than two AX5 field rows. The form is navigable
only one field at a time.

### F13 — The numeric keyboard has no dismissal path

`.keyboardType(.decimalPad)` (`CalculatorScreen.swift:226`) is the correct choice for dose
entry, but the decimal pad has no return key, and the screen adds nothing:
no `.toolbar { ToolbarItemGroup(placement: .keyboard) }`, no `.scrollDismissesKeyboard`,
no tap-to-dismiss gesture, no focus-clearing affordance anywhere in the file.

Once the keypad is up the only way out is to tap another control or leave the screen. I hit
this while capturing: a tap aimed at the tab bar landed on the keypad instead, because the
tab bar was behind it.

### F14 — Unselected tab bar items fail non-text contrast

Pixel-sampled from a 5 pt solid run through the icon stroke (not a glyph edge):

| Capture | Foreground | Background | Ratio | Required |
|---|---|---|---|---|
| `16-` (content scrolled under the bar) | #929299 | #F2F2F7 | **2.77:1** | 3:1 |
| `01-` (bar over card content) | #868586 | #DADADA | **2.63:1** | 3:1 |

The labels are the same colour at roughly 10 pt, so they are measured against 4.5:1 and
fail by a wider margin. This is the classic 1.4.11 miss and it fails in both backdrops the
app can produce. The app ships no imagery, so `16-` is the worst realistic backdrop.

Selected state is the teal from F3 — colour is the only differentiator between selected and
unselected items (`MainShell.swift:46` uses the same `systemImage` for both states), at
2.28:1 against the bar.

### F15 / F16 — Placeholder and separator

| Element | Composited fg | Background | Ratio | Required |
|---|---|---|---|---|
| `TextField("0")` placeholder | #BBBBC1 (#3C3C43 @30%) | #F2F2F7 | **1.71:1** | 4.5:1 |
| `Theme.separator` | #B9B9BB (#3C3C43 @36%) | #FFFFFF | **1.96:1** | 3:1 |

The placeholder only shows when a field is empty — which is exactly the invalid state
(`13-calculator-empty-invalid.png`), so it is the hint shown to a user who has already got
it wrong.

### F17 — Destructive actions stacked against routine ones in Settings

`SettingsScreen.swift:131-154`, three `Button`s in one `Section` with standard list spacing
(0 pt between rows, ~44 pt row height):

```
Change password   (routine)
Sign out          (destructive, no confirmation)
Delete account    (destructive, confirmation dialog ✓)
```

`Delete account` correctly gates behind a `confirmationDialog` with an explicit
"can't be undone" message (`:43-50`). `Sign out` has none, in either location. One row's
travel separates "reset my password" from "sign out" and "sign out" from "delete account".

---

## 3. Passes worth recording

So these are not re-audited later:

- **Colour-alone encoding (WCAG 1.4.1) — deliberately hunted, none found in calculator
  output or validation.** The volume verdict is a *string* from
  `CalculatorEngine.volumeMeta` — "Too small to measure" / "Ideal" / "Unrealistic volume"
  (`CalculatorEngine.swift:30-38`) — never a colour. BMI bands likewise return text.
  Calendar taken/untaken switches the SF Symbol (`checkmark.circle.fill` vs `circle`) *and*
  applies a strikethrough, so shape and typography both carry it
  (`CalendarScreen.swift:287-295`). The dashboard "Taken" badge pairs an icon with the word
  (`DashboardComponents.swift:23-26`). The invalid calculator state prints
  "Enter values to calculate" rather than colouring anything.
- **`keyboardType`** is `.decimalPad` on every numeric input — correct for dose entry.
- **Safe areas** are clean in every capture. The tab bar is a real `TabView` so insets come
  from the system, and the offline banner explicitly pads by
  `geo.safeAreaInsets.bottom + tabBarRowHeight` rather than a device guess
  (`MainShell.swift:70-89`). No content sits under the Dynamic Island or the home indicator.
- **Tab bar item count is 5** — at the HIG limit, not over.
- **`PrimaryButton` is ~50 pt tall** (`Components.swift:23`, padding 14 + headline) and
  spans the content width. Comfortably over 44, and in the lower third for thumb reach.
- **Semantic colours respond to Increase Contrast** (3.44:1 → 20.47:1).
- **Destructive confirmation** exists on `Delete account`.

## 4. Exemptions applied

Stated so they are visibly excluded rather than missed:

- The **disabled** `Add` button (`Theme.accent.opacity(0.4)`, `Components.swift:24`) —
  disabled control, exempt from contrast.
- The **8 pt compound dots** in agenda rows (`CalendarScreen.swift:289`) — colour-only, but
  purely redundant: the compound name is in the adjacent label. Decorative.
- The **hero circle glyph** — `.accessibilityHidden(true)` and `.allowsHitTesting(false)`
  (`MainShell.swift:139-140`); decoration over a real tab item.
- **Dark mode** — not audited. The app is light-only as of 2026-08-01.

## 5. Not verified

- **The hamburger's hit rectangle.** `RouteContent.swift:25-30` puts a bare
  `Image(systemName: "line.3.horizontal")` in a `ToolbarItem`. The glyph is ~20 × 13 pt, but
  the system expands toolbar item targets and I cannot measure a hit rect from a screenshot.
  Not counted as a finding; needs a hit-test check, not a pixel one.
- **iPad layout** (`NavigationSplitView`, `MainShell.swift:189-217`) — not captured. Every
  finding here is the iPhone compact layout.
- **Auth, onboarding and disclaimer screens** — the simulator holds a persisted session and
  signing out to reach them would have cost access to the populated account, so they were
  left alone deliberately.
