## T-11 — The cycle plotter ships and the Tools tab cannot reach it
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** `.cyclePlotter` is in no `CalculatorCategory`'s member list, and `ToolsScreen` renders only
those members — so the plotter has no row on the browse surface. The calculator itself ships (frame
`27-calculator-plotter`).

**Confirmed on mac's tree 2026-08-04**, not read off the stale Windows copy. Two details that sharpen
it: `isListed` is **true** for the plotter — only `bmi` and `freeTestIndex` are deliberately withdrawn
— so this is a slug that is *meant* to be browsable and was left out of the only list that browses.
And `ToolsScreen`'s own header comment says `members` "had never enumerated the plotter at all", so
the file already knows and no task existed.

**Renumbered from T-06**, which was already taken by the microdose finding.

**Done when:** the plotter is reachable from Tools and photographed there.
