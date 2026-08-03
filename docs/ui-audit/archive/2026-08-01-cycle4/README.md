# Build cycle 4 — gradient cause isolated, config round-trip validated, parity gap list

## 1. Gradient: interpolation IS the mechanism

The same-colour test, run exactly as specified — `LinearGradient` with both stops
set to `tealTextStrong`, nothing else changed:

| Sample | Rendered |
|---|---|
| Same-colour gradient, x = 20 / 120 / 200 / 300 / 385 pt | **`#075E56` at every point** |
| Two-colour gradient (cycle 3), x = 20 / 200 / 385 pt | `#4B5557` / `#798A8D` / `#4B5557` |
| `Theme.tealTextStrong` solid | `#075E56` |

Uniform, exact, correct across the full width. A gradient with nothing to blend
renders its stop colour perfectly; the *same* gradient with two distinct stops
desaturates everywhere, endpoints included.

**Interpolation is the mechanism. The linear-light hypothesis stands.** The
expectation that this would come back `#4B5557` is disproven — worth stating,
because it was the more likely-looking of the two branches.

That the endpoints are wrong too is consistent rather than contradictory: the error
is in how the ramp is resolved as a whole, not only at its midpoint. `#075E56` has a
red channel of 7, and interpolating in linear-light lifts the darkest channel hardest
— R 7 → 75 while G and B barely move, which is exactly the measured shift.

**Fix direction, not yet attempted:** control the interpolation space, or pre-blend
the stops in sRGB and hand the gradient many closely-spaced stops so each segment
interpolates across a range too small to drift. No fix in this cycle, per the brief.
The greeting stays solid.

## 2. Config round-trip — validated, from the cycle-3 save

No new save was run: the evidence already exists in
`../2026-08-01-cycle3/02-save-first.png`, and re-running would have written another
row to the live account for someone else to delete.

`CalculatorCatalog` says a TRT protocol must carry **8 keys** — 5 from the form
(`strength`, `mgWeek`, `injPerWeek`, `esterType`, `syringeMl`) and 3 from
`configExtras` (`mode`, `nDays`, `mlDrawn`).

The confirm-start-day screen after the save listed exactly those 8, no more and no
fewer: Ester Type, Inj Per Week, Mg Week, Ml Drawn, Mode, N Days, Strength,
Syringe Ml. Independently confirmed server-side: `config->>'syringeMl' = "1"` on the
saved row.

So the whole `configExtras` / `configOmittedKeys` design has now had its first real
end-to-end validation — the three keys the phone has no field for are present, and
`syringeMl` comes from the picker rather than a hardcoded extra, without the
double-write clobbering it.

**Still unvalidated by observation:** the other 10 slugs. Their key sets are correct
by code inspection, but only `trt` has been round-tripped through a real save.

## 3. What is still short of the PWA

Honest read, styling only — the content/IA gap is tracked separately and excluded.

**Genuinely still short:**

1. **Navy is barely used.** It is the PWA's second brand colour with 33 uses; iOS
   uses it for section eyebrows and primary result labels and nothing else. The PWA
   spends it on the two filled icon buttons flanking the header — that pair is the
   single most recognisable thing about the PWA dashboard and iOS has no equivalent.
   Highest-value remaining item.
2. **Header treatment.** PWA centres a teal wordmark with a logo glyph between two
   navy squares. iOS shows a plain system nav title and a bare teal hamburger, with
   nothing in the trailing corner.
3. **Density.** The PWA gives the same content roughly 1.6× the vertical room. iOS
   is tighter everywhere; card padding and inter-section spacing are the levers.
4. **Greeting gradient** — blocked on the interpolation fix above.
5. **Per-compound colour spine.** The PWA's primary tile carries a coloured left
   edge. iOS puts the compound colour in a small icon chip instead — recognisable,
   but a weaker signal than a full-height spine.

**Already matched, for the avoidance of re-work:** brand palette and the fill/text
split, type scale and weights, canvas and card surfaces, hairline borders, the
primary CTA, tab bar treatment, protocol rows leading with the compound.

**My estimate: ~80% on the dashboard.** Items 1 and 2 are most of the remaining gap
and are both small, contained work — an afternoon, not a cycle.
