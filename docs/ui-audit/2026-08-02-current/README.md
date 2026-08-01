# Current state — 2026-08-02, at `3b8b8b1`

iPhone 16 Pro, iOS 18.3, light, sRGB, unscaled. Numbering matches
`2026-08-01-current` so the two sets read side by side.

Every file verified distinct by md5 — a failed tap produces byte-identical
captures, and this project has been burned by that twice.

## What state the app is in

The `0x`/`1x` frames are the app **after** today's two calculator fixes
(`3b8b8b1`). The `9x` frames are **before** them, captured earlier the same day
at `6f7b0ef`, and are kept as the evidence for what was wrong.

| Defect | At `6f7b0ef` (`9x` frames) | At `3b8b8b1` (`0x`/`1x` frames) |
|---|---|---|
| Field displays a number the engine did not use | **live** | fixed |
| Quick-value row unreachable with the keypad up | **live** | fixed |
| `Tools` at AX5 reads as broken (hyphenation, orphaned `e`, clipped title, tiny icons) | live | **still live** — queued with the type-scale sweep |
| Screen-header rule (`DESIGN-PARITY §9`) | live | **still live** |

## Frames

| Serial | File | Screen |
|---|---|---|
| IB2245723 | `02-dashboard-IB2245723.png` | Dashboard |
| IB2245724 | `03-calendar-IB2245724.png` | Calendar |
| IB2245725 | `04-tools-IB2245725.png` | Tools |
| IB2245726 | `05-add-IB2245726.png` | Add |
| IB2245727 | `06-calculator-trt-IB2245727.png` | TRT Dose, at rest |
| IB2245728 | `07-calculator-barrel-row-IB2245728.png` | TRT Dose scrolled — segmented barrel row |
| IB2245729 | `08-logdose-sheet-IB2245729.png` | Log-dose sheet |
| IB2245730 | `09-dashboard-ax5-IB2245730.png` | Dashboard at AX5 |
| IB2245731 | `10-tools-ax5-IB2245731.png` | Tools at AX5 |
| IB2245732 | `11-calculator-keyboard-toolbar-IB2245732.png` | TRT Dose, weekly dose focused — **today's fix** |
| IB2245733 | `90-defect-before-typed-100250-IB2245733.png` | BEFORE — field reads `100250`, draw computed from 1000 |
| IB2245734 | `91-defect-before-chip-tap-no-effect-IB2245734.png` | BEFORE — after a chip tap that reported success and moved nothing |

## Read these two first

**`IB2245733` / `IB2245734` — the two defects, in one frame each.** The weekly
dose field reads `100250`. The result bar beside it reads `Draw per injection
2.500 mL`, which is 1000 ÷ 2 ÷ 200 — the engine used the clamped 1000 and the
screen never said so. The over-capacity warning underneath is correct, for a
number the user cannot see.

The same frame shows the second defect: the quick-value row is not on screen.
It is behind the pinned result bar, which starts immediately under the field.
`IB2245734` is the frame *after* tapping `quick_mgWeek_400`; nothing moved,
and the tap reported success.

**`IB2245732` — what it looks like now.** The focused field's quick values sit
in a keyboard toolbar with a Done button. Two things to note in that frame:

1. The selection handles on `100` are select-all-on-focus working — typing now
   replaces rather than appends, which is what stopped `100250` being reachable.
2. The software keyboard is **not** drawn, because the simulator has a hardware
   keyboard attached. The accessory bar therefore sits directly on the tab bar.
   On a device with the keypad up it sits above the keypad, as in `IB2245733`.
   Worth knowing before anyone reads that frame as a layout collision — though
   it is a real state for any user with a Bluetooth keyboard, and it is written
   down rather than fixed.

## Not captured, and why

- **`01-welcome-launch`** — the welcome screen is the signed-out path. Shooting
  it means signing out, which discards the Keychain session and costs a real
  Supabase sign-in to get back. Not done mid-block. Yesterday's frame is still
  representative; nothing on that screen changed today.
- **`12-calculator-trt-ax5`** — attempted, **discarded**. `openTRT()` could not
  find the TRT row at AX5, because the labels wrap so hard that only four rows
  fit and the list has to be scrolled. `continueAfterFailure` was true, so the
  capture ran anyway and photographed the Tools screen. It is a genuine frame of
  the wrong screen — exactly the silent-bad-evidence failure the serial rule
  exists to catch — so it was dropped rather than renamed. No serial was issued.
- **Drawer and Settings** — standing decision. Those carry the account's real
  email and avatar.
