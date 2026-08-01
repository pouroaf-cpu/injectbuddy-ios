# PWA reference captures — the target we are matching

Ground truth for `docs/DESIGN-PARITY.md`. The Mac has no copy of the PWA repo
and cannot run it, so these images are the only way that side of the wire can
see what the app is supposed to look like.

| File | What |
|---|---|
| `pwa-01-dashboard.png` | The PWA dashboard on iPhone Safari (`192.168.0.230`) — **this is the target** |
| `ios-01-dashboard-sameday.jpg` | The iOS build's dashboard, same account, same day — the current state |

Open those two side by side before doing any parity work.

## Still needed

The PWA calculator and log-dose screens have no capture here yet. Until they
do, parity work on those two screens is **structural only** — fix what is
demonstrably wrong (below) and do not invent a target.

---

## Dashboard — what the pair actually shows

**Correction (2026-08-01).** An earlier version of this file said "structure
already matches; every difference below is appearance." That was wrong, and the
Mac caught it. The two dashboards differ in **content and information
architecture**, not only in styling.

Verified in `app/account/page.tsx:117-190`: the PWA dashboard is **tabbed**
(`DashTabs`, panels `upcoming` / `history` / `inventory` / `saved` /
`calculators` / `settings`). The capture here shows the **`upcoming` panel
only**, and that panel scrolls well past the fold.

- Present in the PWA, absent from iOS: `SiteRotation` ("Recommended site"),
  `MobileInjectionCount` ("1 injection today"), `InjectionDayPicker` (the date
  strip), `SerumChart`, `LabHighlights`, and two navy `NavyCard` CTAs
  (Injection Calendar, Blood Test Analyser) below the fold.
- Present on iOS, absent from the PWA's `upcoming` panel: the protocol grid —
  which on the PWA lives in the **`saved`** tab (`SavedProtocolsPanel` →
  `ProtocolList`), not the default view — plus "Mark taken" and the whole
  "next dose" framing.

So iOS and the PWA make genuinely different IA choices about what the dashboard
*is*. **That gap is a product decision and is out of scope for styling parity.**
It is tracked separately; do not absorb it into a restyle. The styling table
below still stands on its own.

| | PWA | iOS today |
|---|---|---|
| Greeting | 24px, weight 800, `-0.03em`, animated teal gradient, own line | default weight, `.label` ink, small |
| Second brand colour | navy `#001D5C` on icon buttons, "Today", numerals | **absent entirely** |
| Primary metric | `28.6 mg` at display size with a coloured left spine | `105mg/wk · Testosterone Acetate` as a text row |
| Cards | white on `#FAFAFB`, hairline border, generous padding | pale fills, tight padding |
| Week strip | 7 day cells, `#EAFAF8` fill + teal border on today, per-day dots | "WEEK AT A GLANCE" text section |
| Density | ~1.6× the vertical room for the same content | packed into one viewport |

## Log-dose sheet — `../2026-08-01/10-logdose-sheet.png`

This is a stock SwiftUI `.insetGrouped` list. It carries no brand at all beyond
a teal checkmark. Three things are wrong independent of any PWA capture:

1. **The primary CTA is teal text on white, not a filled button.** `#0FBCAD` as
   text measures **2.38:1** and fails WCAG at any size.

   **Correction (2026-08-01).** This entry originally said the fix was "a filled
   teal surface with white text (~3.5:1 and passing as large text)". That is
   wrong — **contrast is symmetric.** Swapping foreground and background does
   not change the ratio: white on `#0FBCAD` is *also* 2.38:1. Filling the button
   fixes the parity bug and leaves the accessibility bug untouched.

   Passing options, verified both sides:

   | Treatment | Ratio |
   |---|---|
   | white on `#075E56` | **7.65:1** ← chosen |
   | ink `#101018` on `#0FBCAD` | 7.95:1 |
   | navy `#001D5C` on `#0FBCAD` | 6.63:1 |
   | white on `#0FBCAD` | 2.38:1 ✗ |

   **Decision: `#075E56` fill with white text.** White-on-dark reads as a CTA,
   and it keeps `#0FBCAD` reserved for the FAB and large display type — the
   split `DESIGN-PARITY.md` §7 already sets out.
2. **Roughly 40% of the sheet is dead space** below the CTA, while the protocol
   list above is a cramped scroller.
3. **Protocol rows are plain text plus a checkmark.** They are the same objects
   the dashboard renders as cards; they should share that treatment, including
   the per-compound colour spine.

## Calculator — `../2026-08-01/11-`, `12-`, `15-`

1. **Result values are the lowest-contrast text on the screen.** `0.250 mL` and
   `25.0` are teal at ~2.34:1; the secondary rows beside them are near-black at
   15:1+. The contrast hierarchy is inverted against the information hierarchy.
   Use the PWA's split — `#075E56` / `#0A9D90` for teal *text*, `#0FBCAD` for
   fills and large display type only.
2. **`12-`: the floating hero circle renders the primary CTA as a blank teal
   bar** while the keypad is up, and the result card clips the input row being
   edited.
3. **`15-`: at AX5 the result rows truncate the units off the values.** Highest
   severity item in the audit — see the findings report.
4. The result card is a flat label/value list. The PWA leads with the primary
   number at display size and demotes the rest; that hierarchy is the point of
   the screen and it is currently flat.

## Rule

Where these captures and `docs/SCREENS.md` disagree on anything visual, **these
win** and `SCREENS.md` is stale. Flag the conflict rather than silently
choosing.
