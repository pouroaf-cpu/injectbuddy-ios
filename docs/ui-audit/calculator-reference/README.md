# Calculator parity — the PWA is the target

Two captures of the live PWA TRT calculator (`192.168.0.230`), supplied
2026-08-01. Instruction: **make the majority of our calculators match this.**

This is the first PWA capture of a calculator screen. Until now calculator work
was structural-only because there was no target — see
`pwa-reference/README.md`. That constraint is lifted for the calculators.

| File | Shows |
|---|---|
| `pwa-calc-01-top.png` | Header, breadcrumb, mode selector, compound row, vial strength |
| `pwa-calc-02-scrolled.png` | Weekly dose, every-N-days, syringe size, plotter link, FAQ |

---

## 1. The field pattern — the biggest single difference

The PWA gives every numeric input **five controls in a row**, not three:

```
[ −− ] [ − ] [   0      mg/mL  ] [ + ] [ ++ ]
 coarse  fine   value + unit      fine  coarse
```

iOS today is `[ value  unit ] [ − ] [ + ]` — one step size, steppers trailing.

Then, on the row **below**, a per-field quick-value strip:

| Field | Quick values |
|---|---|
| Vial strength | 100 · 150 · 200 · 250 · 300 |
| Weekly dose | 50 · 100 · 150 · 200 · 250 · 450 |
| Every N days | 1 · 2 · 3 · 3.5 · 7 |

Note these are **per field**, not one shared set. iOS currently ships a single
100/200/300/400/500 strip on weekly dose only. The PWA's weekly set starts at 50
and tops at 450; ours starts at 100 and tops at 500. **Take the PWA's numbers** —
they are the ones the user base already reaches for.

The centre value cell carries the unit as a small suffix under the number
(`0` large, `mg/mL` small), and shows a navy border when active while the
stepper cells stay light-bordered white.

## 2. Section labels

`VIAL STRENGTH` · `WEEKLY DOSE` · `EVERY N DAYS` · `SYRINGE SIZE` — uppercase,
navy, bold, letterspaced. iOS uses sentence-case grey ("Vial strength"). Match
the PWA.

## 3. Controls above the fields

- **Mode selector** — full-width segmented: `Every N Days` · `Per Week` ·
  `mL → mg`. Selected is a white pill on a grey track. iOS has no equivalent;
  the dosing mode is currently implied and written to config as an extra.
- **Compound quick-select** — `Test E` · `Test C` · `Test P` · `Other`, white
  cards with navy bold labels. **`Other` uses a dashed border** to signal
  "custom", which is a shape difference, not a colour one — it survives
  greyscale. Worth keeping.

## 3b. `Other` opens a compound search — build this

Confirmed in the PWA source, `public/app.js:4320-4345`. The compound row has two
modes:

- **quick** — a 4-column grid of chips (`ESTER_QUICK`) plus `Other`
- **search** — `Other` calls `setMode('search')`, which swaps the row for a
  **back arrow on the left** (`←`, returns to quick) and a **search combobox**
  filling the rest (`.ib-esq-search` is `display:flex` with the combo at
  `flex: 1 1 auto`)

So `Other` is not a value — it is a mode switch into search. Build it that way:
tapping `Other` replaces the chip row in place with `[←] [ search field ]`, and
the back arrow restores the chips. Not a pushed screen, not a sheet — an in-place
swap, which is why the PWA animates it (`ib-esq-in`, 220 ms, translateY -5px +
scale 0.985).

The back arrow must be a 44 pt target. The PWA's is a bare `←` glyph and ours
should not be.

> **Known PWA bug, reported by the human:** on the live site, tapping `Other`
> lands on the account status page instead of opening the search. The handler
> above is correct — `setMode('search')` with `type: 'button'` and no `href` —
> so something outside this component is intercepting the tap. **iOS should
> build the behaviour the code describes, not the behaviour the site currently
> shows.** Chasing the web bug is separate work in the webapp repo.

## 4. Syringe size — we already match

Four-option segmented: `0.3 mL` · `0.5 mL` · `1 mL` · `3 mL`. Our barrel picker
already ships exactly this, same four values. Nothing to do.

## 5. The plotter link

`📊 See your levels over time →` — a full-width teal-tint card with a bar-chart
glyph, sitting under the inputs.

**We have the destination and no door.** `CyclePlotterScreen.swift` exists (151
lines, Swift Charts) and is routed as a bespoke case from
`CalculatorScreen.swift:29`, but nothing on a calculator screen links to it.
Adding this card is small and connects a feature that is already built.

## 6. Deliberate divergences — do NOT copy these

**`Show result`.** The PWA hides the result behind a pinned teal CTA. Ours
computes live into a pinned bar. **Keep ours.** The web page is long and
SEO-bearing, so deferring the result makes sense there; on a phone the whole
point is watching the number move as you type. Reversing that would undo F12 and
the collapsible result bar with it.

**The truncating title.** `pwa-calc-01-top.png` shows *"Testosterone Dosage C…"*
— the PWA truncates its own header. `DESIGN-PARITY.md §9` says a title never
truncates. **iOS is deliberately better here.** Do not "fix" iOS to match, and
do not read the PWA as the authority on this one line.

**FAQ block.** SEO content for the web. No place in the app.

## 7. Something changed — the FAB is navy now

In `pwa-reference/pwa-01-dashboard.png` (earlier the same day) the PWA's
log-dose FAB is **teal**. In both of these captures it is **navy with a white
glyph**.

So the PWA moved to a navy FAB, which is what the human asked for on iOS and
what `DESIGN-PARITY §8` records as `#0FBCAD` fill with a navy glyph. **Our fill
and theirs now disagree.** Flag it, do not silently change it — the iOS
treatment was chosen because navy-on-teal measures 6.43:1 and keeps brand teal
present at the app's most prominent control. Human's call.

## 8. Scope

"The majority of our calculators" — the field pattern, quick strips and section
labels are in the shared `CalculatorScreen`, so they land everywhere at once.
The mode selector and compound row are per-slug and only apply where the web has
them. Do not invent a compound row for calculators that have no compounds.
