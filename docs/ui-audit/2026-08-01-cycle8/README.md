# Build cycle 8 — the centre tab slot drew two syringes

Still-image verification only. No taps, no scrolling — the Simulator still has no
device window, and none was needed for this.

| File | Shows |
|---|---|
| `01-dashboard.png` | Full dashboard after the fix |
| `02-tabbar-centre-default.png` | Centre slot, 3× crop, default type — **the fix** |
| `03-tabbar-full-default.png` | All five slots, 2× crop, default type |
| `04-dashboard-ax5.png` | Full dashboard at AX5 |
| `05-tabbar-centre-ax5.png` | Centre slot, 3× crop, AX5 |
| `06-tabbar-full-ax5.png` | All five slots, 2× crop, AX5 |

## Confirmed, then fixed

The report reproduces exactly. In every dashboard capture up to `cycle7/01`, a dark
diagonal sliver — the plunger end of the tab item's own `syringe` glyph — protrudes
below the hero circle's bottom edge, directly above the "Log dose" label. Read as two
buttons because it *was* two glyphs: the tab item's, and the circle drawn on top of it.

`.tabItem { Label(tab.title, systemImage: tab.icon) }` applied to all five slots,
`.log` included, and `heroButton` is an overlay — it covers most of that glyph, not
all of it.

**Fix:** the `.log` slot now gets `Text(tab.title)` alone; the other four keep their
`Label`. The second glyph is *removed*, not hidden.

Not fixed by enlarging the circle. That tunes a collision rather than deleting one and
re-breaks at any type size that moves either piece — the same class of mistake as
fixing an overlap with z-order.

Unchanged and deliberate: the tab item is still the real tap target (`tabSelection`
bounces `.log` into the sheet), the text label stays so the slot matches its four
neighbours, and VoiceOver still sees one control because the circle remains
`accessibilityHidden`.

## Verified at both type sizes

**Default** (`02-`): only the circle and "Log dose". No sliver. The label sits on the
same baseline as its neighbours — dropping the icon did not shift it.

**AX5** (`05-`): also clean. The bar grows and the label reflows, and no fragment
appears from behind the circle at either size.

## The other four slots

From `03-` and `06-`, all correct and none occluded:

| Slot | Symbol | State |
|---|---|---|
| Dashboard | `house` | selected — `#075E56`, bold label |
| Calendar | `calendar` | `#5C5C66` |
| Log dose | *(none, by design)* | circle + label |
| Tools | `flask` | `#5C5C66` |
| Add | `plus` | `#5C5C66` |

Selection is carried by weight as well as colour, so it does not depend on hue alone.

## One thing to note in `05-`

The large teal `+` at the top right of that crop is **not** a tab icon — it is the
"+ Add" action from the PROTOCOLS section header, which at AX5 happens to sit behind
the translucent bar at that scroll position. Content passing under a translucent bar
is expected; the reserved inset is what guarantees you can scroll past it. Flagging it
so it is not mistaken for a second overflow bug.

## Still outstanding from cycle 6

The hero-overlap verification — eight screens scrolled to their bottoms, which already
reserved room, and the AX5 hero/tab-bar collision check. Still blocked: `System Events`
reports 0 windows for the Simulator. Not displaced by this cycle, just still blocked.
