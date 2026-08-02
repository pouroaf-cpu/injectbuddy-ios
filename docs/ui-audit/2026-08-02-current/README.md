# Current state — 2026-08-02, after the type-scale re-baseline

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

## Frames

| Serial | File | Screen |
|---|---|---|
| IB2245736 | `02-dashboard-IB2245736.png` | Dashboard |
| IB2245737 | `03-calendar-IB2245737.png` | Calendar |
| IB2245738 | `04-tools-IB2245738.png` | Tools |
| IB2245739 | `05-add-IB2245739.png` | Add |
| IB2245740 | `06-calculator-trt-IB2245740.png` | TRT Dose, at rest |
| IB2245741 | `07-calculator-barrel-row-IB2245741.png` | TRT Dose scrolled — segmented barrel row |
| IB2245742 | `08-logdose-sheet-IB2245742.png` | Log-dose sheet |
| IB2245746 | `09-dashboard-ax5-IB2245746.png` | Dashboard at AX5, greeting capped |
| IB2245747 | `10-tools-ax5-IB2245747.png` | Tools at AX5 |
| IB2245748 | `12-calculator-trt-ax5-IB2245748.png` | TRT Dose at AX5 — the first capture of this screen at large text ever taken |
| IB2245745 | `11-calculator-keyboard-toolbar-IB2245745.png` | TRT Dose, weekly dose focused, keypad up |

## Read these first

**`IB2245746` vs the superseded `IB2245730` — the type scale.** Same screen, same
accessibility size. In `IB2245730` the greeting is rendered at exactly its
default-size dimensions, because every token in `Theme.Typeface` was a frozen
point size; in `IB2245746` it scales. The second frame is also the open question:
the greeting now takes roughly 40% of the dashboard at AX5. That is Dynamic Type
working, and it is still worth a decision.

**`IB2245745` — the keyboard toolbar with the keypad actually up.** The focused
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
**Serials corrected 2026-08-02.** This table listed `IB2245743` and `IB2245744` for
the two AX5 frames after those files had been superseded by `IB2245746` and
`IB2245747`, and it never listed `IB2245748` at all. So the README named serials that
were not in the folder — the same class of problem as a filename that outlives its
content, and exactly what the log exists to make detectable. Caught by the directing
side reading the table against a checkout.

- **`12-calculator-trt-ax5`** — attempted twice, then captured on the third attempt as
  `IB2245748`; the note below is the record of the two failures. At AX5 the
  Tools list needs more scrolling than the harness does to bring the TRT row into
  view. The first attempt produced a genuine photograph of the **Tools** screen
  under a filename claiming the calculator, because `continueAfterFailure` was
  true; the second attempt **failed the run**, which is the fix working. No serial
  was issued either time. The AX5 calculator is the gap in this survey.
- **Drawer and Settings** — standing decision. Those carry the account's real email
  and avatar.
