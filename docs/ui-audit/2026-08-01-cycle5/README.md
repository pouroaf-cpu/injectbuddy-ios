# Build cycle 5 — PWA header, density, spine. And a failed sweep, reported as failed.

| File | Shows |
|---|---|
| `01-dashboard-parity.png` | The dashboard to compare against `../pwa-reference/pwa-01-dashboard.png` |
| `02-tools-list.png` | Tools list with the new header |

## Shipped

- **Navy flanking squares + centred teal wordmark.** `NavySquareButton` is a 44×44
  filled `Theme.navy` square with a white glyph, one leading (menu) and one trailing
  (edit → Add tab), with `BrandWordmark` — the syringe glyph plus "inject**buddy**"
  in `tealTextStrong` — as the principal toolbar item. This was the biggest remaining
  parity gap and it is what makes the side-by-side read as one product. It also fixes
  the one target I had listed as unverifiable: the old bare `Image` in the toolbar is
  now an explicit 44×44 pt control.
- **Density.** Card padding 16 → 20 pt, section spacing 24 → 32 pt, section header
  gap 8 → 16 pt, toward the PWA's ~1.6× vertical room.
- **Per-compound spine.** A 4 pt colour edge down the leading side of each protocol
  row, matching the PWA's primary tile. Decorative and redundant with the icon chip
  by design — it never carries meaning alone.

## Greeting: three attempts, still solid — and my own theory is now dead too

| Attempt | Measured ink | Expected |
|---|---|---|
| `.overlay { LinearGradient }.mask(Text)` | `#5F6B6D` | `#075E56` |
| `.foregroundStyle(LinearGradient)` | `#4B5557` | `#075E56` |
| **25 stops pre-blended in sRGB** (`Theme.srgbStops`) | **`#4A5456`** | `#075E56` |
| Solid fill, same colour, same screen | `#095F57` ✓ | |

Route (a) was checked and is unavailable: `LinearGradient` takes no colour space in
the iOS 18.2 SDK — grepping the `SwiftUICore` interface, only `MeshGradient` has a
`colorSpace:` parameter. So route (b), pre-blending, was the fix. **It did not work.**

That result also refutes my own linear-light explanation. If the fault were the
*width* of each interpolation, splitting the ramp into 24 near-zero segments would
have all but eliminated it. It changed nothing. What the three measurements support
is narrower and stranger: **the fault triggers on the presence of more than one
distinct stop, not on the distance between stops.** A single-colour gradient is
exact; any multi-colour gradient is desaturated, however finely subdivided.

Both available fixes are therefore exhausted. Solid ships, per the brief's own
"solid stays otherwise, and that's an acceptable outcome". `Theme.srgbStops` is kept
— it is correct code and useful for fills, where this is not visible — but it is not
a fix for text.

## The 10-slug config sweep FAILED. No data from it. Nothing to verify.

I automated it and the automation was wrong. The script located each calculator's
Add button by scanning for the `#075E56` CTA fill — but `#075E56` is also the tint
of the new bordered pickers, so the scan matched the **Syringe barrel** picker and
every "Add" tap opened that picker's menu instead. Subsequent taps compounded from
there; all six runs ended on the Semaglutide screen with a menu open.

**The six "saved" lines the script printed were wrong.** I have deleted those
screenshots rather than leave misleading evidence in the repo.

What this means:
- **No slug was verified.** Only `trt` has ever been round-tripped (cycle 3).
- Most likely **no rows were created** — Add was probably never pressed — but I
  cannot assert that, so treat it as unknown and check server-side before assuming
  the table is clean.
- The sweep needs redoing one slug at a time with the confirm-start-day screen
  verified per step, not a colour scan. That is slow but it is the only way it is
  worth anything.
