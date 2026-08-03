# Build cycle 6 — hero overlap reserved app-wide; header squares recoloured

| File | Shows |
|---|---|
| `01-dashboard-teal-header.png` | Dashboard with the teal header squares |

## 2. Header squares — done and measured

Recoloured navy → `Theme.tealText` **#0A9D90**, white glyphs. Measured off the built
app, not calculated: fill sampled **#0A9D90**, white glyph on it **3.37:1**. That
clears the 3:1 WCAG 1.4.11 asks of an icon.

This is the lightest teal in the palette white can legally sit on. White on the brand
`accent` #0FBCAD is 2.38:1 and fails; white on #5FE8DA is ~1.2:1. If a lighter square
is wanted later, the glyphs must become dark ink (#101018 on #0FBCAD is 7.95:1) —
lighter *and* white is not an available combination.

### Knock-on: what navy is left

The squares were the largest navy surface in the app. After the recolour, every
remaining use of `Theme.navy` is text:

- `DashboardScreen:131,146` — section eyebrows (PROTOCOLS, THIS CYCLE, WEEK AT A GLANCE)
- `CalculatorScreen:269` — the primary result row's label
- `DashboardComponents:355` — the GLP-1 family's icon-chip tint

Plus `Theme.inkNavy` (#111A3A) on protocol card titles. So on the dashboard
specifically, navy is now **three small uppercase eyebrows and one icon chip**.

`DESIGN-PARITY.md` has navy as the PWA's second brand colour at 33 uses, most of them
those two squares. **We have traded a chunk of the parity win for the colour request.**
That is the human's call to make and it is now visible rather than discovered in a
screenshot — but it should be made knowingly.

## 1. Hero overlap — fixed structurally, NOT verified. Read this.

`MainShell.heroOverhang = 22` is now applied as a `.safeAreaInset(edge: .bottom)` on
every tab's `NavigationStack`, so every ScrollView, List and nested `safeAreaInset`
inside any tab — pushed screens included — reserves room for the hero. The dashboard's
ad-hoc `.padding(.bottom, 49 + 16)` was removed as double-counting.

22 pt is measured, not derived: on the previous build the tab bar's top hairline sits
at pt 771.3 and the hero assembly (circle + 4 pt ring + shadow) starts at pt ~753 — an
overhang of ~18 pt. 22 matches the `offset(y: -22)` lift and leaves margin.

**Verification could not be completed.** Partway through this cycle the Simulator lost
its device window and would not restore it — `System Events` reports 0 windows through
an app restart, a device shutdown/boot, and the Window-menu entry. `simctl io
screenshot` still works because it reads the framebuffer, which is why the header shot
above exists, but synthetic taps need a window, so **nothing can be scrolled**.

That leaves unverified, and they are exactly what was asked for:
- every screen scrolled to its bottom (dashboard, each calculator family, log-dose
  sheet, tools, add, calendar, settings, drawer)
- which screens already had room reserved and which did not
- whether the hero and the tab bar collide at AX5

The fix is in and is structural, but **treat it as unverified until someone scrolls it.**

## Correction

The brief cites `RootView.swift:29` as doing `zIndex(1)` on the hero. That line is
`zIndex(1)` on **`DisclaimerGate`**, the first-run medical disclaimer — unrelated. The
hero's z-order comes from `.overlay(alignment: .bottom)` in `MainShell`. The underlying
point stands and is why this was fixed with a reserved inset rather than a z-order
change: stacking only decides who wins a collision, reserving space prevents one.
