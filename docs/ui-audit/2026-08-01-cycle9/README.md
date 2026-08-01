# Cycle 9 — the hero-overlap verification, finally run

Owed since cycle 6. It was blocked because the Mac's GUI session had gone; `simctl`
kept working (it talks to the CoreSimulator daemon, which needs no display) but
synthetic taps need a real window, so nothing could be scrolled. The session came
back and this is the result.

`00-bottom-bands-montage.png` stacks the bottom 174 pt of all eight screens, each
scrolled to the end of its content. Read top to bottom: tools, add, calendar,
dashboard, drawer, settings, calculator, log sheet.

| Screen | Scrolled to bottom | Result |
|---|---|---|
| Tools | yes | last row ("Steroid Dosage") sits clear above the bar |
| Add | yes | clear |
| Calendar | yes | clear |
| Dashboard | yes | last "week at a glance" row clear — this is the card the hero clipped in cycle 5 |
| Drawer | yes | footer clear; the drawer is a fixed overlay, not a scroll under the bar |
| Settings | yes | clear |
| Calculator (TRT) | yes | the navy **Add** CTA is fully above the hero and fully readable — this is finding F2's screen |
| Log-dose sheet | yes | clear; presented modally, so the hero is not drawn over it |

**No screen shows content occluded by the hero.** `MainShell.heroOverhang` holds.

## AX5 collision check

`10-tabbar-ax5-collision.png` — 2× crop of the bar at
`accessibility-extra-extra-extra-large`.

No collision. The bar grows and every label scales (Dashboard / Calendar / Log dose /
Tools / Add all legible), the hero stays proportionate and clear of both the bar's top
edge and the labels, and the last content row above it ("…Enanthate") stops short of
the hero rather than sliding under it. The centre slot still shows only the circle and
its label, so the cycle-8 fix holds at AX5 too.

## Which screens already reserved room

Honest answer: only partially knowable now, because proving it per-screen would mean
rebuilding the old binary.

- **Demonstrated overlap before the fix:** the dashboard (`cycle5/01` — hero clipping
  the fourth protocol card) and the calculator (original `03-` and `12-` — hero on the
  CTA, and rendering it as a blank bar with the keypad up).
- **Never demonstrated either way:** tools, add, calendar, settings, drawer, log sheet.
  Their content simply did not reach the hero in any capture we took. A `List` insets
  for the tab bar but knows nothing about the circle, so they were exposed to the same
  ~18 pt in principle; whether any user ever hit it is not something these captures
  can answer retroactively.

What is now true for all eight is that the room is reserved centrally rather than
per-screen, so a future screen inherits it without having to remember.
