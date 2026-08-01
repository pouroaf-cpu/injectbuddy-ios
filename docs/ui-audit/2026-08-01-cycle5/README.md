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

## Slug config shapes — diffed against the live table, no saves

The sweep was cancelled in favour of diffing every iOS slug's key set against the
shapes the **web** actually wrote across 99 rows. Stronger than the sweep would have
been: the sweep compared iOS against `CalculatorCatalog`, which is the thing under
test. This compares iOS against production data.

| Slug | Result |
|---|---|
| `trt` `microdose` `peptide` `semaglutide` `bpc157` `steroid` | **MATCH** as shipped |
| `hcg` | **DIFF, fixed** — emitted `mode`/`nDays`/`injPerWeek`; web rows carry none |
| `tirzepatide` `retatrutide` | **DIFF, fixed** — same three keys, inherited from a shared `case` |
| `eod` `reconstitution` `bpc157blend` | **Cannot validate** — no web rows exist for these |

**Both flagged suspicions came back clean.** `steroid`, the widest surface at 13 keys
and one of the two `configOmittedKeys` cases, matches exactly — the `compound` → `slug`
translation works. `peptide` matches too, and its `doseUnitMcg` → `doseUnit` translation
emits a **string** `'mcg'`/`'mg'`, not the picker's Double.

**The real bug was elsewhere:** the three GLP-1 slugs share one `configExtras` case in
iOS, but do **not** share a config shape on the web — semaglutide rows carry the mode
pair, tirzepatide and retatrutide rows do not. Grouping them is what made two of three
mismatch. HCG had the same fault: it inherited the injectable family's mode pair, which
the web never writes for it.

Caveat carried forward: `retatrutide`'s 3-key shape was described as *dominant*, so a
minority of rows may differ. The fix targets the dominant shape.

Not applicable to iOS at all: `bioavailability`, `femalehrt`, `oilblend` have no iOS
calculator, so their shapes were not checked. That is a feature gap, not a config bug.

## The general lesson — three times in one session

Three bugs this session shared a shape, and it is the shape worth remembering:

| Bug | Correct by inspection | Wrong against reality |
|---|---|---|
| **RLS on insert** | `saveDosage` read cleanly; every other call on the table omits `user_id` for good reason | The INSERT policy's `WITH CHECK` rejected every save. Protocol saving from iOS had **never worked** |
| **`/api/dosages` dedup** | Five source comments described the endpoint's fingerprinting as iOS's dedup | iOS never calls it. It writes direct via PostgREST; the endpoint is cookie-authenticated and unreachable |
| **GLP-1 grouping** | One `configExtras` case for semaglutide, tirzepatide and retatrutide — same drug class, reads as tidy | The web does not group them. Two of three emitted three keys it never writes |

All three were **internally consistent code**. `CalculatorCatalog` agrees with itself;
that is exactly why staring at it could not surface the grouping error. Each was
settled in minutes by looking at the running system instead of the source describing
it — a screenshot of the real error, a `grep` for the call site that did not exist, a
query of the rows the other platform actually wrote.

Corollary that cost real time here: **the age of code is not evidence it works.** The
save path had been wrong for months without a single failure being noticed, because
nobody had pressed the button on a device.

## Open, logged not assigned

1. **The FAB overlaps the fourth protocol card.** Same class as finding F2 but on the
   dashboard: the scroll's bottom inset clears the tab bar row (49 pt) but not the
   hero circle, which is lifted 22 pt above it.
2. **Tab bar glyphs are off-palette.** `#5C5C66` is accessible at ~6:1 and was chosen
   to fix F14, but the PWA's are brand-coloured. Needs a tone that is on-palette *and*
   clears 3:1 — the previous `#929299` cleared neither.
3. **`bioavailability`, `femalehrt`, `oilblend`** exist on the web with no iOS screen.
   Feature gap for a product decision, not a config bug.
