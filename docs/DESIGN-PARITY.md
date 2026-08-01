# Design parity — iOS ↔ PWA dashboard

Extracted from the live PWA source on the Windows box
(`C:\Users\PFrew\Projects\Injectbuddy`, Next.js) on 2026-08-01. The Mac has no
copy of that repo, which is why the iOS app has been built without these values.

**Source files these numbers come from** — cite them, don't guess:

- `tailwind.config.ts` — brand teal scale
- `app/globals.css` — `:root` token block, `--ib-cta-*`
- `components/account/dashboard/DashStyles.tsx` — dashboard-scoped tokens, all
  component CSS (line numbers noted below)
- `components/account/dashboard/DashHeader.tsx` — greeting treatment

---

## 1. Why this file exists

`Sources/InjectBuddy/Core/Theme/Theme.swift` currently says, in its header:

> Mirrors the web look (Inter-ish system font, frosted cards) **without forcing
> exact hexes — system materials read better natively.**

That instruction is the reason the two dashboards don't look alike. It is hereby
**revoked for brand colour and typography.** Those are brand identity, not
platform convention, and they must match the PWA.

It is **retained for platform behaviour**: sheets, blur materials, haptics,
scroll physics, nav transitions, and the Dynamic Type / accessibility stack stay
native. We are matching the *brand*, not reimplementing the web layout engine.

## 2. Palette

Usage counts are occurrences across the PWA dashboard components — they show
which colours actually carry the design, not which are declared.

| Token | Hex | Uses | Role | In Theme.swift today |
|---|---|---|---|---|
| `teal` | `#0FBCAD` | 38 | Primary accent, CTA fill, FAB | ✅ `Theme.accent` |
| `navy` | `#001D5C` | 33 | **Second brand colour** — icon buttons, section labels, numerals | ❌ **absent** |
| `tealDeep` | `#075E56` | 27 | Text on teal tints; high-contrast teal text | ❌ absent |
| `tealDark` | `#0A9D90` | 15 | Greeting gradient base, active tab text | ❌ absent |
| `inkNavy` | `#111A3A` | 14 | Heading ink where navy is too saturated | ❌ absent |
| `tealMist` | `#EAFAF8` | 7 | Selected-state fill (week strip, dose pill) | ❌ absent |
| `tealMist2` | `#F0FBFA` | 2 | Alternate tint | ❌ absent |
| `ink` | `#101018` | — | `--ib-dash-ink`, body ink | ❌ uses `.label` |
| `canvas` | `#FAFAFB` | 12 | `--ib-bg`, page canvas | ❌ uses `.systemBackground` |
| `surface` | `#F8F8FB` | 5 | Raised tile fill | ❌ uses `.secondarySystemBackground` |
| `line` | `rgba(0,0,0,0.12)` | — | `--ib-dash-line`, hairlines | ❌ uses `.separator` |
| `tealShimmer` | `#5FE8DA` | — | Greeting gradient highlight | ❌ absent |
| `danger` | `#A31313` | 4 | Error text | ⚠️ ships `#FF5757` — wrong |

**The navy is the single biggest gap.** It is the second most-used colour in the
PWA and does not exist in the iOS theme at all. It is what the navy icon
buttons, the "Today" label and the dose numerals are made of. Its absence is
most of why the iOS build reads as a generic SwiftUI app.

Keep `Color(.label)` / `.systemBackground` **only** where a surface must invert
for dark mode and has no brand equivalent. Brand-coloured elements take the
hexes above.

## 3. Typography

Theme.swift currently has **no typography at all** — only `Spacing` and
`Radius`. Every screen therefore inherits SwiftUI defaults, which is the second
reason for the mismatch.

The PWA is **Inter** site-wide (`tailwind.config.ts` `fontFamily.sans`), with
`tabular-nums` on all dose numerals (`.ib-dash-mono`,
`font-variant-numeric:tabular-nums`).

| Element | PWA | SwiftUI target |
|---|---|---|
| Greeting (`DashHeader.tsx:25`) | 24px, weight **800**, `letter-spacing:-0.03em`, teal gradient | 24pt, `.heavy`, `.tracking(-0.72)`, gradient fill |
| Section label ("PROTOCOLS") | 13.5px, weight 600, uppercase | 13.5pt `.semibold`, `.textCase(.uppercase)` |
| Dose numeral | large, weight 800, tabular | `.monospacedDigit()`, `.heavy` |
| Tab label | 13.5px, weight 600 (700 active) | 13.5pt `.semibold` / `.bold` |

Decide and record: ship Inter as a bundled font for true parity, or use SF with
matched weights and tracking. **Do not leave it at SwiftUI defaults** — that is
the current state and it is what's wrong. If SF is chosen, the weights and
tracking above are still mandatory.

`-0.03em` at 24px = **-0.72pt** of tracking. SwiftUI `.tracking()` takes points.

## 4. Signature treatments

These are what make the PWA dashboard recognisable. Ranked by visual payoff.

1. **Greeting shimmer** — `DashStyles.tsx:664`. Text-clipped linear gradient,
   `100deg`, stops `#0A9D90 0%, #0A9D90 40%, #5FE8DA 50%, #0A9D90 60%, #0A9D90
   100%`, `background-size:230%`, animating `150% → -50%` over **4.5s linear
   infinite**. In SwiftUI: `LinearGradient` + `.mask(Text(...))` + a repeating
   `.linear(duration: 4.5)` offset animation.
   **Must honour Reduce Motion** — the PWA disables it at
   `DashStyles.tsx:965` under `prefers-reduced-motion`. Mirror that with
   `@Environment(\.accessibilityReduceMotion)`.
2. **Card left accent bar** — the coloured spine on the "TEST P / 28.6 mg" card.
   Per-compound colour. Currently absent on iOS.
3. **Two-tone greeting** — name renders in a lighter teal than the salutation.
4. **Week strip** — 7 day cells, selected cell gets `#EAFAF8` fill + teal border,
   each cell carries a dot when a dose falls that day.
5. **Tile hover/press** — border → `rgba(15,188,173,0.4)`, `translateY(-1px)`,
   `box-shadow 0 6px 18px -12px rgba(0,0,0,0.25)` (`DashStyles.tsx:674`). Map to
   a press state on iOS; there is no hover.

## 5. Geometry

Radii in `Theme.Radius` (card 16 / control 10) are close to the PWA's
`--radius: 0.5rem` = 8px and the tabs' `10px 10px 0 0`. **Verify before
changing** — do not churn these on assumption.

The PWA's density is looser than the current iOS build: the iOS dashboard packs
the greeting, next-dose card, CTA, a 2-column protocol grid and a week section
into one viewport, where the PWA gives the same content roughly 1.6× the
vertical room. Larger type will force this correction naturally; don't fight it
by shrinking type back down.

## 6. Out of scope

Not everything should match. Keep native: sheet presentation, blur materials,
scroll bounce, nav push transitions, tab bar behaviour, haptics, Dynamic Type
scaling, and every accessibility affordance. Brand ≠ layout engine.

## 7. Non-negotiable

Whatever is built here must still pass the audit already in flight: 44×44pt
touch targets, 4.5:1 body text contrast (7:1 target), 3:1 for icons and
borders, and **no state signalled by colour alone** — this is a dosing app.

Note `#075E56` and `#001D5C` are both very dark and will pass contrast on light
fills easily; the risk is the reverse — teal `#0FBCAD` as *text* on white is
only ~2.4:1 and **fails**. The PWA uses `#075E56` / `#0A9D90` for teal text and
reserves `#0FBCAD` for fills and large display type. Follow that split.


---

## 8. Colour roles (settled 2026-08-01, cycle 7)

Both brand colours are load-bearing. Navy is the ACTION colour; teal is the brand's
primary hue and keeps the FAB. This is taken from the PWA's actual usage — navy 33
uses spanning header buttons, NavyCard CTAs and section labels; teal 38 uses spanning
the FAB, wordmark, accents and selected states — not from a hierarchy principle. An
earlier pass made navy scarce "so it dominates" and drained the brand; brand wins.

| Role | Token | Pairing | Measured |
|---|---|---|---|
| Actions — primary CTAs, header icon buttons | `navy` #001D5C | white on it | **15.79:1** |
| The FAB | `navy` #001D5C fill, **white glyph** | #FFFFFF on #001D5C | **15.79:1** |
| Teal text anywhere | `tealTextStrong` #075E56 | on white/canvas | 7.65:1 |
| Large teal text only | `tealText` #0A9D90 | on white | 3.37:1 |
| Tints, selected states | `accentSoft` #EAFAF8 | #075E56 on it | 7.12:1 |
| Accents, wordmark, decoration | `accent` #0FBCAD | — | never as text (2.38:1) |

**#0FBCAD is never a text or glyph colour, and white is never placed on it.** Both are
2.38:1. The FAB is the one place brand teal is a large fill, and its glyph is navy for
exactly that reason.

Superseded, do not reinstate: "teal is accents only" — it would drain the primary
brand colour out of the app.

---

## 9. Screen headers (settled 2026-08-01)

Every screen wears the brand. Today only the tab roots do — `RouteContent.swift:35`
puts `BrandWordmark` in `.principal`, while pushed screens fall back to a stock
`.navigationTitle` in system black ("TRT Dose", "Semaglutide", "Log a dose"). That
inconsistency is what this rule closes.

### The rule

A pushed screen's title is set in the **logo's treatment**, not the system's:

1. **The syringe mark appears beside the title**, sized to it, in brand colour —
   `Theme.accent` `#0FBCAD`, matching `BrandWordmark`.
2. **The title uses the wordmark's typeface and weight**, coloured
   `Theme.tealTextStrong` `#075E56` (7.65:1). Same family as the logo, so a screen
   title reads as the product naming itself rather than iOS labelling a view.
3. **Mark + title are optically centred as one unit**, and stay centred whatever
   the line count.
4. **A long title WRAPS. It never truncates.** "Testosterone Dosage Calculator"
   goes to two or three lines rather than becoming "Testosterone Dosage…".
5. **The back control stays put** — 44×44 pt, leading, vertically anchored so it
   does not drift when the title grows to two lines.

### Why wrap, not truncate — this is not a preference

This app has already shipped truncation twice: seven dashboard protocol cards
losing their compound name (two rendered identically), and the AX5 result rows
losing their units. Both were found by looking, not by review. A screen title is
the same failure with less excuse — there is no space pressure that a second line
does not solve.

No `lineLimit` on a screen title. Ever.

### The constraint that decides the implementation

**A UIKit navigation bar DOES grow to fit a wrapped title — to exactly two lines.** A multi-line view
in `.principal` gets clipped by the bar's fixed height, so "wraps to multiple
lines" and "lives in the nav bar" cannot both be true.

Pick one and record which:

- **(a) Branded header in the content area.** Replaces the stock large title;
  the nav bar keeps only the back control. Wraps freely, centres cleanly, scales
  with Dynamic Type. Costs a little vertical space and scrolls away with content
  unless pinned.
- **(b) Compact branded title in `.principal`.** Stays fixed and matches the tab
  roots exactly, but cannot wrap — so it only works if every title fits on one
  line at every type size, which "Testosterone Dosage Calculator" does not.

**(a) is the one that satisfies the brief.** Confirm against the SDK before
building; the Mac can see what `.principal` tolerates and this side cannot.

### Verify

Longest real title, default size and AX5. Confirm: wraps rather than truncates,
stays centred at two and three lines, the back control does not move between
them, the mark scales with the title, and the whole header is one accessibility
element with `.isHeader` — the mark decorative, not announced separately.


### §9 addendum — measured, 2026-08-01

The constraint originally written here ("a UIKit navigation bar does not grow to fit
a wrapped title") was an assumption, and it is **false**. Probed on device with a
wrapping `Text` in `.principal`, at default and AX5:

| Lines | Result |
|---|---|
| 2 | **Renders fully.** The bar grows. No clipping. Back control does not move. |
| 3 | **Clipped at both ends** — top of line 1 sheared, line 3 half-rendered. |
| AX5 | Identical. The bar does not grow further. |

So `.principal` caps at **two lines** and fails **silently** beyond — there is no
ellipsis, so nothing on screen says content is missing. A sheared third line reads
as a rendering glitch, or worse, as the whole title.

That is why the branded header goes in the **content area** (option a) — not because
the bar cannot wrap, but because it caps at two and clips invisibly at three, and
Rule 4 says a title never truncates. "Testosterone Dosage Calculator" does not fit
two lines at AX5.

**Onboarding does not use this header.** Checked against the reference: their step
screens carry a back chevron, a progress rail and the question — no mark, no
wordmark, no centred title. Repeating the brand above every question competes with
the one thing the screen exists to ask. So the two headers share the *behaviour*
(44 pt back control that doesn't drift, wrap-never-truncate, centring at any line
count) and not the composition.


### §8 amendment — the FAB is navy (2026-08-01)

Reverses the earlier reasoning on this row, deliberately. The fill was kept teal to
avoid draining the last large teal surface; the PWA has since moved its FAB to navy,
so navy **is** the brand rule here rather than a departure from it. White on
`#001D5C` is 15.79:1, against 6.43:1 for the navy-on-teal it replaces — so the most
prominent control in the app also became its highest-contrast one.

Teal is not diminished: it keeps the wordmark, the greeting, "Next dose", "+ Add",
the selected tab item, the protocol spines, the tints and the welcome curves.
