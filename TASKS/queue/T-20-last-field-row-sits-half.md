## T-20 — The last field row sits half under the pinned bar at rest
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** in `docs/ui-audit/2026-08-04-t01a/20-calculator-trt-default.png`, the `EVERY N DAYS` row
is cut across the middle by the top edge of the pinned result bar: the label and the value well are
readable, the row's own ruler is not. At rest, unscrolled, at default type size.

**What it is NOT:** a missing space reservation. The bar is a `safeAreaInset`, it does reserve its
height in the scroll, and the form scrolls clear of it — this is the at-rest position of a form
whose earlier fields already fill the viewport, which is the same behaviour recorded against
`control_syringeMl` before this change and is documented at length in `CalculatorScreen`.

**What IS new, and why it is filed rather than waved through:** T-01a made every numeric row TALLER
— label, value and a ruler where there was previously a label above a field. So more of the form is
below the fold than before, and the row that lands on the boundary now has a control in its lower
half rather than whitespace. A half-visible ruler reads as a full ruler whose range stops at the
plate.

**Done when:** measured, not adjusted by eye — the straddle re-checked at default and AX5 against
`PinnedBarReachabilityUITests`, and either shown to leave every control reachable, or the form's
bottom inset increased by the drum's own measured height.
