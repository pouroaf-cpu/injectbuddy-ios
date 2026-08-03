# 2026-08-03 — current state, default size

**Twenty frames, one run, `testCaptureFullDefaultSweep`, `** TEST SUCCEEDED **` in 806s.**

App built from `Sources/` at **`3fe7302`** (the last commit touching `Sources/`; everything after it
is docs and test harness). Harness at **`f506c4e`**.
Capture window **2026-08-03 05:49–06:03 PDT / 2026-08-04 00:49–01:03 NZ** — the run's start and end,
not per-frame times. The frames' own status bars carry the minute; the window is what the log can be
checked against.

> ## THIS IS THE FIRST SET IN WHICH THE SHELL FRAMES ARE PHOTOGRAPHS OF THE SCREENS THEY ARE NAMED FOR.
>
> In `2026-08-02-current` — and in `2026-08-01-current` before it — **three shell frames were
> misfiled**: `03-calendar` was the Dashboard, `04-tools` was the Calendar, `05-add` was Tools.
> `shot()` fired during the cross-fade after `tab()`, so every shell frame landed one screen behind.
>
> **The outgoing screen is sharp and the destination ghosts in**, so each was a good, well-rendered
> photograph of a real screen under the next screen's name. ***It was not blurry, it was misfiled***
> — which is the harder failure, because nothing about the image looks wrong. That is why it survived
> two capture cycles and only one of the three was ever noticed.
>
> **`tab()` now asserts arrival** against something only the destination renders, enumerated per tab
> with no `default`. It caught two defects on its first two runs — a proof string that could not match
> because `.insetGrouped` uppercases `Section` headers, and `Log dose` having **no proof at all**
> while being captured twice per sweep on trust. Neither cost a frame.
>
> **Nothing in this project had ever photographed the Calendar until this set.**

## What changed since `2026-08-02-current`

Five things were expected to look different. All five are accounted for.

| | Evidence |
|---|---|
| **Result bar at 17%** | `GATE … area=690.67 bar=120.00 share=0.1737` — **17.37%**, from the renderer's own probe, not measured off a picture |
| **One title per calculator** | Single content-area header on every calculator frame; no nav-bar duplicate |
| **Barrel row keeps its units** | `0.3 mL (30u)` · `0.5 mL (50u)` · `1 mL (100u)` · `3 mL (IM)`, none sheared |
| **GLP-1 draw value not sheared** | `Draw 0.100 mL` complete with its unit; `Units (U-100) 10` |
| **BMI and Free T Index gone from Tools** | `04-tools-IB2245778.png` — **and this is the first Tools frame that can answer it.** `TESTOSTERONE & HORMONES` shows TRT Dose · TRT & EOD · TRT Microdose · HCG and nothing else. **Sample: the frame is cut off after `BPC+TB500`, so it speaks for GLP-1, Testosterone & hormones and Peptides, and not for anything below them.** |

## The disclaimer, measured against the whole pinned region

`B1-11` / `F-F` is **struck won't-fix by the owner (H4)** and none of this re-opens it. Recorded
because the old probe measured the **hero circle alone** while the finding names three occluders, so
`overlap=none` never meant "readable".

| | margin | occluder |
|---|---|---|
| Reconstitution | **+16.00pt** | **none — the only one genuinely clear** |
| Semaglutide · Tirzepatide · Retatrutide | −83.00pt | **`bar_plate`** — the intersection rect *is* the disclaimer's own rect; entirely inside the result bar |
| BPC-157 | −188.00pt | **`tabBar`** — never on F-F's list of six |
| 7 others | n/a | below an 874pt window at rest (y 913–1136) |

**The hero occludes nothing.** Corroborated two ways: the geometry above, and the pixels — legible in
`18-calculator-reconstitution-IB2245787.png`, absent from the other four.

## Frames

| Serial | File | Screen |
|---|---|---|
| IB2245776 | `02-dashboard-IB2245776.png` | Dashboard |
| IB2245777 | `03-calendar-IB2245777.png` | **Calendar — the first true Calendar frame in this project** |
| IB2245778 | `04-tools-IB2245778.png` | **Tools — asserted by a `Reconstitution` row before the shutter** |
| IB2245779 | `05-add-IB2245779.png` | Add |
| IB2245780 | `06-calculator-trt-IB2245780.png` | TRT Dose, at rest |
| IB2245781 | `07-calculator-barrel-row-IB2245781.png` | TRT Dose scrolled to the barrel row |
| IB2245782 | `08-logdose-sheet-IB2245782.png` | Log-dose sheet |
| IB2245783 | `11-calculator-keyboard-toolbar-IB2245783.png` | TRT Dose, weekly dose focused, keypad up |
| IB2245784 | `15-calculator-eod-IB2245784.png` | TRT & EOD |
| IB2245785 | `16-calculator-hcg-IB2245785.png` | HCG |
| IB2245786 | `17-calculator-peptide-IB2245786.png` | Peptide |
| IB2245787 | `18-calculator-reconstitution-IB2245787.png` | Reconstitution — **the disclaimer is legible in this frame** |
| IB2245788 | `19-calculator-semaglutide-IB2245788.png` | Semaglutide |
| IB2245789 | `20-calculator-tirzepatide-IB2245789.png` | Tirzepatide |
| IB2245790 | `21-calculator-retatrutide-IB2245790.png` | Retatrutide |
| IB2245791 | `22-calculator-bpc157-IB2245791.png` | BPC-157 |
| IB2245792 | `23-calculator-bpc157blend-IB2245792.png` | BPC+TB500 |
| IB2245793 | `26-calculator-microdose-IB2245793.png` | TRT Microdose |
| IB2245794 | `27-calculator-plotter-IB2245794.png` | Cycle Plotter |
| IB2245795 | `28-calculator-steroid-IB2245795.png` | Steroid Dosage |

## Not in this set, and both are decisions rather than omissions

- **The drawer and Settings.** They render the account's real email and avatar, and these frames go
  into a chat window. Standing decision. **This means the new account-deletion UI is not here** — a
  separate, deliberately masked capture is owed to `launch/APP-REVIEW-NOTES.md`, because App Review
  has to be shown where the deletion path lives.
- **The signed-out path.** It costs the Keychain session and a real sign-in to recover.
- **AX5.** This is the default-size set only. `2026-08-02-current`'s five AX5 frames are **not
  superseded** — they are a different type size and remain the only large-text evidence there is.
