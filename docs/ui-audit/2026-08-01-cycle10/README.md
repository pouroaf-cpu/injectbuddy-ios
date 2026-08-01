# Cycle 10 — the hero no longer rests on the calculator's CTA

| File | Shows |
|---|---|
| `01-calculator-gap-fixed.png` | TRT Dose, default type |
| `02-gap-crop-default.png` | 4× crop of the CTA/hero boundary — the daylight |
| `03-calculator-ax5.png` | TRT Dose at AX5, for the two regression checks |

## The gap, as a positive number

| | Before | After |
|---|---|---|
| Add button bottom edge (x=60 pt, clear of the circle) | pt 774.7 | pt **758.7** |
| Hero white ring top (x=201 pt) | pt 762.0 | pt 762.0 |
| **Gap** | **−12.7 pt** (overlap) | **+3.3 pt** |

Same +3.3 pt at AX5. `02-` at 4× shows the boundary: navy ends, bar background, then
the ring — the shadow falls away softly and nothing touches.

## Why the fix is here and not on the shell constant

`MainShell.heroOverhang` **cannot** reach this, and that was established by experiment
rather than argument: raising it 22 → 38, rebuilding and re-measuring produced
identical pixels — button bottom still 774.7, ring still 762.0.

> **General rule, worth more than this one screen:** an outer `.safeAreaInset` reaches
> **scrolled** content, but it cannot lift a *sibling* inset pinned further in. That is
> exactly why all eight screens verified clean in cycle 9 while this one still
> overlapped — the shell fix was correct for scroll content and structurally could
> never reach a nested pin. If something pinned needs clearance, add it where the pin
> is placed.

So the clearance is 16 pt of bottom padding on `resultBar` itself — the measured
12.7 pt plus ~3 pt of daylight. Padding rather than a frame, so it grows the `.bar`
background with the content and cannot affect how the rows inside lay out.

## Regression checks, both requested, both clean

**F1 — AX5 unit truncation.** Intact. The collapsed bar at AX5 renders
`Draw per injection` / `0.250 mL` with the label complete, the value complete and the
unit present. Padding was added *outside* the rows, so nothing re-acquired a
`lineLimit` and the reflow path is untouched.

**F12 — pinned bar eating the screen.** Improved, not regressed. At AX5 the page
background now runs to pt 588.7, so the bar occupies pt 589 → 874 = **285 pt of 874,
32.6%**. The figure this finding was raised against was **64%**, and the threshold set
was 60%. Three input fields remain visible and usable above it.

## Correction to the record

The overlap was described as the ring "grazing" the button, read off a downscaled
4272 px montage. It was not grazing — it was a **12.7 pt overlap**, visible in the
full-resolution crop that already existed. Recorded so the montage is not trusted for
sub-pixel judgements again; it is a survey instrument, not a measuring one.
