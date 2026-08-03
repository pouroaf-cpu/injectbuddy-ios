# Result panel spec — what a calculated result should look like

Win, 2026-08-02. Derived from the PWA source on the Windows box, `ui-audit/calculator-reference/`,
and a survey of what has shipped in this category.

**Look at `ui-audit/result-panel/RESULT-PANEL-SPEC.png` first.** It shows all four states at the
shipped values from `IB2245740` — 200 mg/mL vial, 2×/week — with only the weekly dose and barrel
changing. This document is the reasoning behind that image; the image is the target.

## 0. The one-line version

The result card is text-only, and the single question it answers worst is the one the user
actually has in their hand: **does this dose fit the barrel, and how close to the edge is it.**
Add a proportion strip that answers exactly that. Do **not** add a drawn syringe.

## 1. What ships today

`CalculatorScreen.swift` → `ResultCard`. Every row is `PrimaryResultRow` (label above value,
`Theme.Typeface.display`, `tealTextStrong` #075E56, `monospacedDigit`) or `SecondaryResultRow`
(`ViewThatFits`, side-by-side falling back to stacked). Over-capacity is `CapacityWarning` —
icon + text + shape, `Theme.danger` — and it fires only once `drawMl > barrelMl`.

There is no graphic anywhere in the result path.

## 2. Why this is worth building, and it is not aesthetics

**2.1 The ambiguity is named in our own source.** The comment above the result rows says: *"in a
dosing calculator 0.25 with no unit has two plausible readings — 0.25 mL vs 25 units on a U-100
barrel — and nothing on screen disambiguates."* F1 fixed that by never letting the unit truncate.
But the shipped card now shows **both** readings as two separate numbers — `0.250 mL` and `25.0` —
and the user still has to know which scale their barrel carries. Two correct numbers, one
unanswered question.

**2.2 Capacity is only reachable after the fact.** `CapacityWarning` fires when the draw already
exceeds the barrel. Nothing says *"you are at 88% of this barrel"*. The user meets the constraint
by breaching it. That is the third column of the image and it is the case that justifies the
element.

**2.3 The category has converged on this.** Every peptide/TRT calculator shipped in the last two
years pairs the figure with a syringe graphic — Peptide Calculator (SVG fill to the exact mark),
Peptide Clock, Medplore (redraws for barrel size), Regimen (U-100/U-50/U-40 explicit), Shotlee
(calculator + logging, closest to our shape). The consistent reasoning: the calculated number is
not the output the user needs, the plunger position is.

**2.4 The clinical failure mode is ours.** The two documented syringe-reading errors are parallax
and **confusing a barrel graduated in units with a dose prescribed in mL**. The second is the exact
pair of numbers on our card.

## 3. Build this — the barrel-fit strip

A proportion bar. **Not** a picture of a syringe. It is deliberately unitless, which is what makes
it safe across all four barrels we offer.

**Placement: the in-scroll `ResultCard` only. Not the pinned bar** — and this is not a style
preference. Cap 0.40 leaves 4.6pt of headroom above the `lead` rung; a new element in the pinned
candidate spends that immediately and flips the gate to `compact`, which demotes the dose. If it is
ever wanted in the pinned bar it goes in as a fourth candidate rung and gets measured, never
appended to an existing one.

Position within the card: after the emphasised values, before the weekly total.

Geometry — every value scaling with Dynamic Type via `@ScaledMetric`, no frozen points (T18):

| Part | Spec |
|---|---|
| Track | Capsule, **14pt** height at default, full content width. Wash fill, 1pt `Theme.separator` border. |
| Fill | Leading-anchored, `clamp(drawMl / barrelMl, 0...1)`. `#0FBCAD` normal, `#A31313` over. |
| Marks | Three only, at 25 / 50 / 75%. Hairline, 55% opacity. They let the eye judge "about half" — they are **not** a scale. |
| Labels | `Theme.Typeface.cardMeta`, `monospacedDigit`. Leading = share or fills count; trailing = `draw / barrel mL`. |
| Reflow | The label pair is a value+unit family. **No `lineLimit`.** Stacks above AX1 the same way `SecondaryResultRow` does — do not invent a third mechanism. |
| Copy | Under: `{pct}% of a {barrel} mL barrel`. Over: `{n} fills of a {barrel} mL barrel`. |

Behaviour at the extremes, both reachable, both handled explicitly:

- **Over capacity** — fill pegs at 100%, label switches to the fills count, both take
  `Theme.danger`. The existing `CapacityWarning` still renders: the strip **precedes** it and
  never replaces it.
- **Very small draws** — at 0.03 mL in a 1 mL barrel the fill is 3% and two nearby doses look
  identical. That is fine **because** the numbers carry the precision and the strip never claims
  to. It is why this is a proportion bar and not a graduated barrel — see §4.

## 4. Do not build a drawn syringe — three reasons, all reachable today

1. **3 mL is not an insulin syringe.** Our barrel picker offers 0.3 / 0.5 / 1 / 3 mL. The first
   three are U-100 and graduated in units; 3 mL is graduated in mL. A drawing with a 100-unit
   scale on it would teach the user to read a barrel they do not own. Any graduated drawing must
   derive its scale from the selected barrel — real work, and a standing correctness risk. The
   proportion strip sidesteps it entirely.
2. **U-100 is an assumption.** Our card labels it honestly — `Units (U-100)`. A drawing states it
   silently. On a U-40 barrel the same plunger position is a different dose.
3. **A fill level that is approximately right is worse than a number.** The number is exact at
   every value; a drawing degrades quietly at the small end, which is precisely where peptide
   doses live. A channel that cannot report its own uncertainty is indistinguishable from a
   correct answer — the same shape as every check deleted this week.

## 5. Accessibility — the part most likely to be got wrong

The strip is `.accessibilityHidden(true)`. Full stop.

The numbers already carry the meaning, and a decorative duplicate in the accessibility tree is a
**second place for the two figures to disagree** — which is T2 and T14 arriving from a new
direction. If VoiceOver needs the capacity relationship it belongs in the accessibility *label* of
the existing rows, not in a parallel element with its own identifier.

Corollary: do not give the strip an `accessibilityIdentifier` and do not assert on it. Assert on
the numbers, which is where the truth is.

## 6. Gates before this is ticked

- Measured at default **and** AX5 on the TRT calculator — the screen the last two truncation bugs
  both lived on. Judgment pass first (D2).
- The label pair **shown** reflowing above AX1, not assumed to.
- Re-run the T20 numbers after: a new element in the scroll changes what is above the fold even
  though it is not in the bar.
- Serial + log row per D3.

## 7. Separate finding — file it, do not bundle it

On a 3 mL barrel the card still shows `Units (U-100)` — a units figure for a barrel that has no
units scale, presented exactly like one the user can act on. Either the row is suppressed for
non-U-100 barrels, or the label says which barrel it assumes. Not decided; it needs the numbers on
screen. Not part of the strip work.

## 8. Sources

- <https://calculator-peptide.com/>
- <https://peptideclock.com/tools/peptide-calculator>
- <https://medplore.com/health-tools/mg-to-ml-syringe-calculator/>
- <https://helloregimen.com/tools/units-to-ml-calculator>
- <https://www.shotlee.app/syringe-calculator>
- <https://www.peptidedosage.org/guides/syringe-measurement-guide>
- <https://www.air-tite-shop.com/Articles/syringe-graduation-marks>
- <https://biologyinsights.com/how-to-read-a-syringe-ml-markings-and-insulin-units/>
