# Build cycle 2 — after shots

Same rig: iPhone 16 Pro simulator, iOS 18.3, Xcode 16.2, light, sRGB, unscaled.

| File | Screen / state | Shows |
|---|---|---|
| `01-dashboard-greeting-solid.png` | Dashboard | Greeting regression fixed — glyph core measures **#095F57**, true teal |
| `02-calculator-trtdose-with-barrel.png` | TRT Dose | New **Syringe barrel** picker; field borders now 3:1; "Volume / Ideal" is a labelled row |
| `03-calculator-barrel-overcapacity-keyboard.png` | TRT Dose, over capacity | Icon **and** text warning: draw 2.500 mL vs a 1 mL barrel |
| `04-calculator-ax5-compact-bar.png` | Calculator at AX5 | F12 — pinned bar collapsed to one line + CTA, form usable |
| `05-calculator-glp1-inputs.png` | GLP-1 calculator | Picker fields carry the same bordered treatment as TRT |

## The greeting: why it is solid and not a gradient

The cycle-1 greeting rendered as washed grey. Fixing the ramp was not enough — the
problem was the gradient itself, measured at the glyph core off the running app:

| Implementation | Measured ink | Expected |
|---|---|---|
| `.overlay { LinearGradient }.mask(Text(...))` | **#5F6B6D** | #075E56 |
| `.foregroundStyle(LinearGradient(...))` | **#4B5557** | #075E56 |
| `.foregroundStyle(Theme.tealTextStrong)` | **#095F57** ✓ | #075E56 |

#4B5557 is (75, 85, 87) — almost no green-blue separation, i.e. grey with a cyan
cast. Contrast was fine (~7:1) but the hue was wrong, which was the actual
complaint. Two different gradient approaches produced two different wrong greys;
a solid fill produced the exact ramp colour. Shipped solid rather than guess a
third time. **The sweep is still wanted and is not refused — it needs a diagnosis,
not another attempt.**

`#5FE8DA` is deleted from the theme regardless: 1.50:1 on white, and because a
highlight travels, that stop becomes the text's actual ink as it passes.

## Barrel picker — what it does and what is NOT verified

`syringeMl` is now a real `.picker` field on all 11 specs that previously
hardcoded it, defaulting per slug to exactly the value `configExtras` used to
write (0.3 microdose/EOD, 0.5 HCG, 1 elsewhere), so an untouched save is
byte-identical to the previous build's.

The double-write trap is closed: `syringeMl` is removed from every `configExtras`
entry. This mattered — `configJSON()` applies extras **after** field values and
lets them win, so leaving it in would have silently overwritten the user's choice.

**The acceptance test could not be run — see FINDINGS-cycle2.md.** iOS does not
POST to `/api/dosages`; it inserts straight into `saved_dosages` through
PostgREST, so the server-side dedup never executes for an iOS save and no
`duplicate: true` can ever come back.
