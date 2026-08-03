# Build cycle 7 — navy is the action colour, teal keeps the FAB

`01-dashboard-navy-actions.png` — dashboard after the change.

## Measured off the built app

| Element | Pairing | Measured | Required | Was |
|---|---|---|---|---|
| Header squares | white on `#001D5C` | **15.79:1** | 3:1 (icon) | 3.37:1 (cycle 6) |
| Primary CTA fill | white on `#001D5C` | **15.79:1** | 4.5:1 | 7.65:1 |
| Hero glyph | `#001D5C` on `#0FBCAD` | **6.43:1** | 3:1 (icon) | **2.38:1 — failing** |

The hero figure is 6.43 in situ rather than the 6.63 calculated for the pure pair:
the fill samples `#0FB8A9` at that point, not a flat `#0FBCAD`, because of the
circle's shadow and glyph antialiasing. Either way it clears 3:1 with room.

**The hero was the last failing surface in the app** — white on brand teal at 2.38:1,
the exact failure fixed everywhere else, sitting on the most prominent control. It is
now the only one that was fixed by changing the *foreground* rather than the fill,
because the fill is brand identity.

## Also swept

Two filled buttons were still on brand teal and neither was on the list:

- `EmptyStateView`'s action — `.borderedProminent` draws white on the tint, so
  "Add your first protocol" was white on `#0FBCAD` at **2.38:1**. It is the empty
  state's only action and the first button a new user ever sees. Now navy.
- `ErrorBanner`'s "Retry" — `.bordered` tints the *label*, so it was `#0FBCAD` text at
  **2.38:1**. Secondary action, so `#075E56` at 7.65:1 rather than navy.

## Knock-on: the teal/navy balance on the dashboard

Requested inverted from cycle 6, and it comes out healthy — both brand colours are
load-bearing, in roughly the PWA's proportion:

**Navy** — the two header squares (the largest navy surface), the "Mark taken" CTA,
the three section eyebrows, the hero glyph, and the GLP-1 icon chips.

**Teal** — the hero FAB fill `#0FBCAD` (still the single most prominent colour block
on the screen), the `injectbuddy` wordmark, the greeting, the "Next dose" label, the
"+ Add" action, the selected tab item, and the protocol spines and icon chips for the
testosterone family.

So the cycle-6 loss is reversed: navy is back on the header *and* gained the CTAs,
while teal keeps the FAB, the wordmark and every accent. Nothing drained out.

Card titles remain `inkNavy` `#111A3A` rather than full navy — deliberate, so the
eyebrows and CTAs stay the navy that reads as navy.

## Still unverified — hero overlap

`MainShell.heroOverhang` has been in since 8922ada and is **still unverified**. The
Simulator has not recovered its device window this session: `System Events` reports 0
windows through an app restart, a device shutdown/boot, and the Window-menu device
entry. `simctl io screenshot` reads the framebuffer so stills work — every measurement
above is real — but synthetic taps need a window, so nothing can be scrolled.

Outstanding, unchanged:
- the eight screens scrolled to their bottoms
- which already reserved room and which did not
- whether the hero and tab bar collide at AX5

Not inferred from the code, deliberately.
