# Result sheet + the syringe — spec

**Owner's decision, 2026-08-03.** It changes the calculator screen's architecture and it **reverses
`RESULT-PANEL-SPEC.md` §4**, which said not to draw a syringe. Recorded as his so a later session
does not re-file it as an oversight.

> *"i want people to be able to see the realistic needle we have made on injectbuddy pwa, its a real
> draw card… not just an image with lines on it, people get confidence in seeing a needle like
> theirs… honestly the bar should show nothing but we need somewhere where it says click here to see
> your result, page slides out with injection, Mg ## ml ## and unit number, ability to zoom on the
> needle."*

**Why the previous objection does not survive.** `RESULT-PANEL-SPEC` §4 gave three reasons not to
draw a syringe. The PWA implementation already answers two of them, in code, today:

1. *"A drawing with a 100-unit scale would teach the user to read a barrel they do not own."* — It
   does not. `isInsulin = syringeMl <= 1.0` switches the entire scale: ≤1 mL draws units (×100,
   ticks 2/5/10), 3 mL draws mL (ticks 0.1/0.5/1.0). The scale is **derived from the selected
   barrel**, which is exactly what the objection asked for.
2. *"U-100 is an assumption a drawing states silently."* — It does not. The panel prints
   `Insulin U-100` or `Standard luer` from the same branch.
3. *"A fill level approximately right is worse than a number."* — The numbers are on the same
   surface, at 48pt. The strip never has to carry precision it does not have.

**What survives from that spec:** the barrel-fit proportion strip is **cancelled**. It existed to
answer "does this fit the barrel and how close to the edge", and a drawn barrel with a fill front
answers that better. Do not build both. The separate `Units (U-100)` finding (T27) is **closed by
construction** here, provided the port keeps the barrel-derived scaling and does not hardcode U-100.

---

## 1. The architecture change

**Today:** iOS pins the whole `ResultCard`. It measures ~52% of the content area at default text
size and ~58% at AX5. That single fact is the direct cause of F-H (an input sheared with a live
`Add` beneath it), the four buried barrel buttons on TRT Dose and Steroid Dosage, F-I (result cards
clipped on BMI / Free T Index / Semaglutide), and the frequency control unreachable with the keypad
up — where the occluder was never the keyboard, it was this panel above it. **Six findings, one
architectural difference.**

**The PWA does not do this.** `CalcStickyBar` (app.js L3052) renders a frosted bar containing a
single `Show result` button and nothing else. Its data card was removed deliberately — the source
comment reads *"Mobile results data card removed (operator: redundant with the on-screen result
panel)"*. Save was removed too; the bottom nav's Add slot owns saving.

**iOS adopts the open/close model, with two deliberate divergences:**

| | PWA | iOS | Why |
|---|---|---|---|
| Results | press `Show result` to compute | **stay live** | The PWA's press exists to meter a usage quota for logged-out visitors. iOS is signed-in only. Do not import a paywall gate as an interaction. |
| Pinned bar content | one button | **one button** | Owner: *"the bar should show nothing but… click here to see your result."* |

So: **the pinned bar becomes a single row carrying one control.** No dose, no numbers, no `Add`.
It says something on the order of `See your result`. It is one row tall, so it shears nothing.

`Add` does **not** move into the sheet as a second CTA. It stays where the app already puts it —
gated on `canSaveProtocol`, per H6 — and the sheet is for reading, not committing. One commit path,
not two.

## 2. The sheet

`DrawerResult` (app.js L5135) is the PWA's own mobile version of this and is the parity target:
the **vertical** syringe at 44% width, beside a stack of `Amount to Draw` (units, 48px), `Volume`
(mL, 3 dp, 19px) and `Dose` (mg, 1 dp, 19px).

Port that layout. A SwiftUI `.sheet` with detents, not a full-screen cover — the user is comparing
the sheet against the inputs behind it, so the inputs should not vanish.

Required content, in this order:
1. The syringe (§3), sized to the sheet.
2. **Amount to draw** — the units figure, largest element.
3. **Volume** — mL, 3 dp.
4. **Dose** — mg, 1 dp.
5. The barrel line — `Insulin U-100` or `Standard luer`, from `syringeMl <= 1.0`.
6. The existing `CapacityWarning`, unchanged, when `drawMl > barrelMl`. **See §5.**

**Every value+unit pair here is subject to the standing rule: no `lineLimit`, and it reflows at
AX5.** The 48pt figure is the single most likely thing in this app to truncate.

## 3. The syringe — exact geometry

Ported from `HorizSyringe` (app.js L1263–1519) and `VertSyringe` (L4941–5130). Values are exact;
do not round them into "about right".

**Use the vertical syringe in the sheet** — that is what `DrawerResult` uses and it suits a portrait
sheet. `viewBox 180 × 680`. `BA = 130` (barrel start along Y), `BLEN = 420`, `BXL = 55` (barrel
left), `BWID = 44`, `CX = 77`.

Derived per render:

```
isInsulin = syringeMl <= 1.0
maxVal    = isInsulin ? syringeMl * 100 : syringeMl
activeVal = isInsulin ? volumeMl  * 100 : volumeMl
unitLabel = isInsulin ? "UNITS" : "mL"
fillPct   = clamp(volumeMl / syringeMl, 0, 1)
pistonY   = BA + fillPct * BLEN
liquidH   = fillPct * BLEN
rodStart  = pistonY + 10
rodLen    = max(0, 582 - rodStart)
```

### Body, in paint order

| Part | Geometry (vertical) | Fill / stroke |
|---|---|---|
| plunger rod | x 72, y `rodStart`, w 10, h `rodLen`, rx 1 | `#C8CDD5`, stroke `#ADB3BA` 0.4 |
| needle shaft | x 76, y 17, w 2, h 74 | `#9CA3AF` |
| bevel tip | polygon `77,13 76,17 78,17` | `#9CA3AF` |
| shaft highlight | x 76, w 0.8 | `#C8CDD5` |
| shaft shadow | x 77.2, w 0.8 | `#7A828C` |
| barrel | x 55, y 130, w 44, h 420, rx 3 | `#CDD1D8` |
| fluid | x 55, y 130, w 44, h `liquidH`, clipped | **`accent`** |
| fluid shine | x 57, y 130, w 5, h `liquidH`, rx 1 | `rgba(255,255,255,0.22)` |
| bubbles | 5 circles, only when `liquidH > 30` | `rgba(255,255,255,0.22)` |
| glass sheen | x 55, y 130, w 8, h 420, rx 2 | `rgba(255,255,255,0.18)` |
| depth | x 91, y 130, w 8, h 420 | `rgba(0,0,0,0.07)` |
| ticks | §3.1 | §3.1 |
| piston | x 56, y `pistonY`, w 42, h 2, rx 1 | `rgba(0,0,0,0.45)` |
| hub cone | polygon `55,130 66,90 88,90 99,130` | `#E0E4EA`, stroke `#9CA3AF` 0.5 |
| hub highlight | line (66,91) → (55,130) | `#F0F2F5`, sw 1.2 |
| hub fluid | polygon `56.5,131 67,91 87,91 97.5,131`, when `fillPct > 0` | `accent` @ 0.92 |
| bore | line (77,13) → (77,91), when `fillPct > 0` | `accent`, sw 0.7, round cap |
| barrel border | x 55, y 130, w 44, h 420, rx 3 | none, stroke `#9CA3AF` 0.6 |
| finger flange | x 37, y 550, w 84, h 12, rx 5 | `#D4D8DE`, stroke `#B8BBC0` 0.6 |
| flange highlight | line (42,553) → (116,553) | `#EBEEF1`, sw 1, opacity 0.7 |
| thumb rest | ellipse cx 77, cy 587, rx 32, ry 7 | `#D4D8DE`, stroke `#B8BBC0` 0.6 |
| thumb highlight | ellipse cx 77, cy 585, rx 26, ry 2.4 | `#EBEEF1`, opacity 0.6 |

**The 3D is stacked flat rects at fixed alpha — no gradients and no filters anywhere.** That is why
it renders crisply and why it will port cleanly. Light direction for the vertical syringe is **from
the left**: highlight on the left edge, shadow on the right. (The horizontal one is top-lit. Do not
mix them.)

Bubbles: fractions along the fill with cross-axis offset and radius —
`{0.18, 12, r2.4} {0.38, 28, r1.8} {0.55, 18, r3} {0.73, 32, r1.8} {0.87, 15, r2.4}`;
`cx = 55 + offset`, `cy = BA + f * liquidH`. Each drifts 3.5px with period `2.4 + i*0.3`s and delay
`i*0.35`s. **Suppress entirely under Reduce Motion.**

### 3.1 Graduations

```
smallStep = isInsulin ? 2   : (syringeMl <= 3 ? 0.1 : 0.2)
midStep   = isInsulin ? 5   : 0.5
longStep  = isInsulin ? 10  : 1.0
```

**Compute tier membership in integer thousandths, not floating point.** The source does
`round(v*1000) % round(step*1000) == 0` precisely to dodge float error; `truncatingRemainder` on
`Double` will produce wrong tiers. Port the integer form.

Tick lengths `long 14 · mid 9 · short 5`. Stroke `long rgba(0,0,0,0.50) @1.2 · mid rgba(0,0,0,0.33)
@0.8 · short rgba(0,0,0,0.18) @0.6`.

**Each tick is two marks, drawn inward from both barrel edges** — not one line across. Clip the
whole tick group to the barrel interior.

Labels: **long ticks only, and never zero.** Navy `#001D5C`, 11pt, weight 600, on a
`rgba(255,255,255,0.92)` backing pill `width = count*6.6 + 8`, height 15, rx 3.5, so they stay
legible over any background. Vertical places them in a column to the **left** of the barrel.

Resulting sets: 0.3 mL → 16 ticks, labels 10/20/30. 0.5 mL → 26 ticks, labels 10–50. 1 mL → 51
ticks, labels 10–100. 3 mL → 31 ticks, labels 1/2/3.

**The drawing is schematic, not to physical scale** — a 3 mL barrel draws the same length as a
0.3 mL one; only the graduations change. That is correct and intended: it is a reading aid for the
barrel the user selected, not a size comparison between barrels.

### 3.2 The value that rides the fill front

A caret plus a pill that tracks the piston. Vertical: caret polygon `99,0 107,-6 107,6` pointing
left at the barrel edge; pill at `x 107, y -9, w frontBW, h 18, rx 4.5`,
`fill rgba(255,255,255,0.92)`; text at `x = 107 + frontBW/2, y 4.5`.

```
frontNum  = isInsulin ? dispVal(1dp) : dispVal(2dp)
frontUnit = isInsulin ? "U" : "mL"
frontBW   = (frontNum.count + frontUnit.count) * 8 + 20
```

Number 15.5pt weight 800 in `accent`; unit 10pt weight 600, offset 2.5.

**`frontBW` is a hand-rolled text metric and it is a porting hazard.** It assumes 8 units per
character. In SwiftUI, measure the text and size the pill to it — do not port the arithmetic. This
is exactly the shape of bug that produced F1.

### 3.3 Motion

- **Fill, piston and front marker:** 300 ms, `cubic-bezier(0.4, 0, 0.2, 1)`.
- **The number counts up:** 300 ms, and **linear** — deliberately the same duration as the fill but
  not the same curve. Tween from the currently displayed value so an interrupted change resumes
  rather than jumping, and counts down as readily as up.
- **Reduce Motion:** value snaps, every transition becomes none, bubbles stop. Non-negotiable.

### 3.4 The flash — port it deliberately or not at all

The PWA broadcasts a flash to **every** mounted syringe after each Calculate press and after a
successful save: a 650 ms outer glow peaking at 40% with blur 32 / spread 12.

Two facts before porting it: **the glow is hardcoded teal `rgba(15,188,173,…)` regardless of the
accent colour**, so an amber TRT syringe flashes teal; and it is **not** suppressed under Reduce
Motion. iOS has one syringe on screen and live results, so a per-press flash has no press to attach
to. **Recommendation: do not port the flash.** If it is wanted, it fires on the sheet opening, takes
the accent colour, and honours Reduce Motion.

## 4. Zoom

Owner asked for it explicitly. Both PWA mechanisms are documented; **port the loupe, not the hover
lens** — there is no cursor on a phone.

Click-to-zoom, vertical: `ZH = 340`, so magnification is `680/340 = 2×`. The crop is **centred on
the fill front**, not on the barrel centre — comment: *"so a small dose zooms onto the dose, never
the plunger end"* — and clamped to stay inside the syringe:

```
Lw = ZH * 180/680 = 90
Lx = clamp(CX - Lw/2, 0, 180 - Lw)      // = 32
Ly = clamp(pistonY - ZH/2, 0, 680 - ZH)
```

The zoomed view renders **the same body**, only cropped. Build the syringe as one view that takes a
crop rectangle, exactly as the PWA factored it into `renderBody(cid)`.

Interaction: tap to open, tap or × to close. Fade 0.18s + scale 0.97→1.0 over 0.2s, or instant
under Reduce Motion.

**Zoom must be reachable without a tap.** See §6 — in the PWA it is not, and that is a defect we are
not porting.

## 5. Over-capacity — the one real defect in the PWA graphic

`fillPct` is **clamped to 1**. There is no red state, no overflow indicator, no warning anywhere in
either syringe component. **A 1.4 mL dose in a 1 mL barrel renders as a completely full barrel** —
visually identical to a correct 1.0 mL dose. The numeric readout is not clamped, so the figure keeps
climbing while the drawing says "full".

On a dosing app, a graphic that cannot distinguish "exactly full" from "40% over" is the failure
mode the whole result-panel argument was about.

**Required on iOS, and not optional:**

- Keep the existing `CapacityWarning` — icon, text and shape, `Theme.danger` — in the sheet.
- When `drawMl > barrelMl`, the fluid takes the danger colour rather than the accent, so the drawing
  and the warning agree.
- The front readout continues to show the **true** value, not the clamped one.
- The barrel line states how many fills it takes.

This is a deliberate divergence from the PWA and it should be reported back to the web side.

## 6. Accessibility — a gap to close, not a spec to copy

Stated plainly because it would otherwise be inherited silently. In the PWA:

- The syringe SVG has **no `role`, no `aria-label`, no `<title>`, no `<desc>`, no `aria-hidden`.**
  It is an unlabelled graphic.
- No `role="meter"` or `progressbar`, no `aria-valuenow` / `valuemin` / `valuemax`.
- The zoom wrapper has **no `role="button"`, no `tabIndex` and no key handler — the zoom is mouse
  and touch only and is completely unreachable by keyboard.**
- The loupe has no dialog role, no focus trap and no Escape handler.
- The only affordances present are `aria-label="Close zoom"` on the close button and `aria-hidden`
  on the hover lens.

**On iOS:**

- The syringe is **one** accessibility element with a label of the form
  `"Syringe, 37.5 of 100 units"`, plus `.accessibilityValue`. Not thirty child elements, and not
  hidden — the drawing carries information a blind user is otherwise denied.
- **Do not publish the tick labels or the front pill as separate elements.** That is a second place
  for the figures to disagree, which is the shape of T2 and T14.
- Zoom is an `.accessibilityAction`, reachable without a tap gesture.
- The sheet gets a proper accessibility container; VoiceOver focus lands on the dose figure when it
  opens, and returns to the invoking control when it closes.

## 7. Colours

| Value | Use |
|---|---|
| `#CDD1D8` | barrel base |
| `#9CA3AF` | needle, barrel border 0.6, hub stroke 0.5, rotated unit label |
| `#C8CDD5` | plunger rod, lit-edge highlight |
| `#ADB3BA` | rod stroke |
| `#7A828C` | dark-edge shadow |
| `#E0E4EA` | hub cone |
| `#F0F2F5` | hub highlight |
| `#D4D8DE` | flange, thumb rest |
| `#B8BBC0` | flange / thumb stroke |
| `#EBEEF1` | flange + thumb highlights |
| `#001D5C` | graduation labels — **this is the app's navy, already in `DESIGN-PARITY.md §8`** |
| `rgba(255,255,255,0.92)` | label pills, front pill |
| `rgba(255,255,255,0.22)` | fluid shine, bubbles |
| `rgba(255,255,255,0.18)` | glass sheen |
| `rgba(0,0,0,0.07)` | depth |
| `rgba(0,0,0,0.45)` | piston |
| `rgba(0,0,0,0.50 / 0.33 / 0.18)` | long / mid / short ticks |

`accent` is the fluid. The PWA passes teal `#0FBCAD` by default, amber `#D97706` on TRT, and a
per-compound colour on peptide calculators. **On iOS use the settled palette** — teal `#0FBCAD` is a
fill colour and is legitimate here; it is only banned as *text*. Check any accent chosen for a
per-compound scheme against the fill rules in `DESIGN-PARITY.md §8`, not against the web's values.

## 8. Build order and pass conditions

Build in a **git worktree on its own branch**, merge when measured. Owner's instruction: this work
is isolated from the working branch.

1. **The bar first.** Reduce the pinned bar to one control. **Re-run the widened reachability
   measurement immediately.** That before/after pair is the evidence this change worked — the
   before is the list produced by the current measurement pass, and it is the reason that pass is
   still being finished rather than abandoned.
2. **The sheet, with numbers only.** No syringe yet. Confirm the dose figures reflow at AX5 with no
   `lineLimit`, and that the sheet's presence does not re-introduce a shear.
3. **The syringe body**, static, at each of the four barrels. Screenshot all four at default and
   AX5. The `Insulin U-100` / `Standard luer` line must match the graduations in the same frame.
4. **Fill, front marker and motion.** Reduce Motion verified by observation, not by reading the code.
5. **Over-capacity (§5).** Drive a dose beyond the barrel and photograph it. This must be visibly
   distinguishable from a full barrel.
6. **Zoom**, including the accessibility action.

**Pass conditions, all measured, none inspected:**

- The pinned bar occupies **no more than one row**, reported as a percentage of the content area at
  default and AX5.
- The reachability check that currently fails on the buried barrel buttons and the sheared BPC+TB500
  input is **shown red before, green after.** A green with no prior red proves nothing here.
- Four barrels × two text sizes photographed, with the graduation count verifiable in the frame.
- An over-capacity dose photographed and visibly distinct from a full barrel.
- The syringe reads as one element under VoiceOver with the correct value, and zoom is reachable
  without a tap.
