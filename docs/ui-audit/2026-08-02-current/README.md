# Current state — 2026-08-02, after the measured pinning gate

iPhone 16 Pro, iOS 18.3, light, sRGB, unscaled. Numbering matches
`2026-08-01-current` so the two read side by side. Every frame carries a serial
and a row in `../SCREENSHOT-LOG.md`.

Every file verified distinct by md5 — and the capture harness now fails a run when
two frames come back byte-identical, rather than leaving that to a checksum
someone remembers to take.

## What state the app is in

These frames are the app after three changes made today: the two calculator
defects (the field displaying a number the engine did not use, and the quick-value
row occluded with the keypad up), and the type-scale re-baseline that made
`Theme.Typeface` track Dynamic Type at all.

| Defect | Status in these frames |
|---|---|
| Field displays a number the engine did not use | fixed |
| Quick-value row unreachable with the keypad up | fixed |
| Type scale frozen against Dynamic Type | fixed — compare `IB2245746` against the superseded `IB2245730` |
| `Tools` at AX5 reads as broken | **still live** — `IB2245747` |
| Screen-header rule (`DESIGN-PARITY §9`) | **still live** |
| Greeting takes ~40% of the dashboard at AX5 | **new, open** — correct scaling behaviour, open product question |

The pre-fix evidence frames (`IB2245733`, `IB2245734`) and the whole pre-
type-scale set are superseded; their rows in `../SCREENSHOT-LOG.md` name the
commit each file can be retrieved from.

**Serials corrected 2026-08-02.** This table listed `IB2245743` and `IB2245744` for
the two AX5 frames after those files had been superseded by `IB2245746` and
`IB2245747`, and it never listed `IB2245748` at all. So the README named serials that
were not in the folder — the same class of problem as a filename that outlives its
content, and exactly what the log exists to make detectable. Caught by the directing
side reading the table against a checkout.

## Frames

| Serial | File | Screen |
|---|---|---|
| IB2245736 | `02-dashboard-IB2245736.png` | Dashboard |
| IB2245737 | `03-calendar-IB2245737.png` | Calendar |
| IB2245738 | `04-tools-IB2245738.png` | Tools |
| IB2245739 | `05-add-IB2245739.png` | Add |
| IB2245749 | `06-calculator-trt-IB2245749.png` | TRT Dose, at rest — **after the measured pinning gate** |
| IB2245750 | `07-calculator-barrel-row-IB2245750.png` | TRT Dose scrolled to the end |
| IB2245742 | `08-logdose-sheet-IB2245742.png` | Log-dose sheet |
| IB2245746 | `09-dashboard-ax5-IB2245746.png` | Dashboard at AX5, greeting capped |
| IB2245747 | `10-tools-ax5-IB2245747.png` | Tools at AX5 |
| IB2245748 | `12-calculator-trt-ax5-IB2245748.png` | TRT Dose at AX5 — the first capture of this screen at large text ever taken |
| IB2245752 | `13-calculator-steroid-ax5-IB2245752.png` | **Steroid Dosage at AX5 — first capture ever.** The BEFORE frame for the sheared dose field, and three defects nobody had seen |
| IB2245751 | `11-calculator-keyboard-toolbar-IB2245751.png` | TRT Dose, weekly dose focused, keypad up |

## What changed on 2026-08-02, second pass — taken at `369fbc5`

Three frames only, at DEFAULT type size. Dashboard, calendar, tools, add and the log
sheet are untouched by this work and were not reshot: a reshoot with no change spends
a serial saying nothing.

**`IB2245749` against the superseded `IB2245740` — the frame that matters.** Same
screen, same size, same values, so it is comparable by eye and by band profile.

| | IB2245740 | IB2245749 |
|---|---|---|
| plate top | pt 456.33 | pt 564.67 |
| plate height | 334.34pt | 226.00pt |
| **share of content area** (638.34pt) | **52.40%** | **35.40%** |
| share of full frame (874pt) | 38.25% | 25.85% |
| inputs complete without scrolling | 2 of 5 | 4 of 5 |
| `Frequency` | sheared through its control | whole |
| plate | `.bar`, #DBDBDB | `.regularMaterial`, #FEFEFE + 1px hairline |

The bar is no longer gated on a Dynamic Type category. It measures four candidate
states and takes the tallest that fits within 40% of the content area — so the same
mechanism produces `lead` here and stands the bar down entirely at AX5, where the
full bar would be 104% of the content area.

### The request the human made was NOT delivered

He asked for **transparent with a light blur, so the bar reads as floating over the
form rather than as furniture covering it.** What shipped is a **tone change**. The
grey slab is gone, which fixes the complaint; the blur is not there, because nothing
of the form renders behind the pinned bar for a material to be translucent over.

Measured: `.ultraThinMaterial` — the most transparent material — sampled **#767676 at
four different scroll positions, identical**. A material over a moving backdrop cannot
return the same value four times. The full ladder runs opposite to the names:
`ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB · regular #FEFEFE · thick #FFFFFF`.

Contrast never failed and is not why: worst composite `#075E56` **7.14–7.59:1**, navy
eyebrow 14.60–15.65:1, `Add` white-on-navy **15.79:1 exactly** at every position,
because the navy fill is opaque. Filed as **T25** with the evidence.

### What these frames show that is still wrong

- **`IB2245750`** — `Draw per injection · 0.250 mL` appears **twice** at full display
  treatment, once in the scroll and once in the pinned bar, about 500px apart. The
  duplication predates this work but the `lead` rung makes it conspicuous: both copies
  are now the same single headline figure rather than two differently-sized lists.
  Open finding.
- **`IB2245751`** — with the keypad up, `Frequency` is sheared by the plate edge. The
  reachability sweep asserts at rest, where the content area is the whole screen; with
  the keypad up it is a fraction of it. Recorded rather than cropped out.

## IB2245752 — Steroid Dosage at AX5, and it is worse than the finding that prompted it

Shot because the highest-severity open item on the board existed only as coordinates —
`field_mgWeek` spanning y 636.33…701.33 against a plate top of pt 651.67 — and nobody
can look at a pair of numbers. The capture **asserts the shear is present before it
writes the file**, so this frame cannot be a photograph of a screen where the defect is
absent.

§5.15 held again. This screen had never been captured at large text, and it carries
three defects beyond the one it was shot for:

1. **The `Compound` picker draws OUTSIDE its own control.** `Oxandrolone (Anavar)` wraps
   to three lines that overflow the field chrome and render on top of the `Compound`
   label above it and the `Vial strength` label below. Two strings occupy the same
   pixels and neither is legible. This is not truncation — nothing is hidden, it is
   **overlap**, and it is the worst thing in the frame.
2. **The screen title truncates — `Steroid Dos…`.** §5.7 bans exactly this: never accept
   silent clipping on a title, a value or a unit.
3. **`Oxan-drolone`, hyphenated mid-word.** Same family as `Semaglu-tide` on the Tools
   screen (`IB2245747`), so it is a shared cause rather than two screen-specific bugs.
4. **The sheared dose field** — the finding this was taken for. `Weekly dose` is cut
   through its digits by the plate's top edge, and it is the only other input on screen.

One complete input is usable on this screen at AX5, and it is not the dose.

## Read these first

**`IB2245746` vs the superseded `IB2245730` — the type scale.** Same screen, same
accessibility size. In `IB2245730` the greeting is rendered at exactly its
default-size dimensions, because every token in `Theme.Typeface` was a frozen
point size; in `IB2245746` it scales. The second frame is also the open question:
the greeting now takes roughly 40% of the dashboard at AX5. That is Dynamic Type
working, and it is still worth a decision.

**`IB2245751` — the keyboard toolbar with the keypad actually up.** The focused
field's quick values and Done sit above the keypad and clear of the pinned result
bar, and the inline quick row is hidden while that field is being edited. The
earlier version of this frame was taken with a hardware keyboard attached, so iOS
suppressed the keypad and the accessory bar was photographed on the tab bar — a
position it never occupies in front of a user. The capture now types a character
and asserts the keyboard is on screen before shooting.

**`IB2245747` — Tools at AX5, unchanged and still the open finding.**
`Semaglu-tide` hyphenated mid-word, `Tirzepatide` wrapping to an orphaned `e`,
`Retatru-tide`, the title clipped against the header, icons that stayed small
while the text went huge. Worth knowing *why* it looks like this and the dashboard
did not: `ToolsScreen` uses system text styles, so it has always scaled correctly
and the layout cannot take it. The dashboard looked fine because it was not
scaling at all. Opposite problems.

## Not captured, and why

- **`01-welcome-launch`** — the welcome screen is the signed-out path. Shooting it
  means signing out, which discards the Keychain session and costs a real Supabase
  sign-in to get back. Nothing on that screen changed today.
- **`12-calculator-trt-ax5`** — attempted twice, then captured on the third attempt as
  `IB2245748`; the note below is the record of the two failures. At AX5 the
  Tools list needs more scrolling than the harness does to bring the TRT row into
  view. The first attempt produced a genuine photograph of the **Tools** screen
  under a filename claiming the calculator, because `continueAfterFailure` was
  true; the second attempt **failed the run**, which is the fix working. No serial
  was issued either time. The AX5 calculator is the gap in this survey.
- **Drawer and Settings** — standing decision. Those carry the account's real email
  and avatar.
