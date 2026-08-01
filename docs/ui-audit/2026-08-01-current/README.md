# Current state — refreshed at `f13fbc8`

A full re-capture, replacing the piecemeal per-cycle folders as the single "what
the app looks like right now" set. iPhone 16 Pro, iOS 18.3, light, sRGB, unscaled.

Every file verified distinct by md5 — a failed tap produces byte-identical
captures, which is exactly how the previous attempt at this went wrong.

| File | Screen |
|---|---|
| `01-welcome-launch.png` | Welcome, launch frame — serum curves, mark, wordmark |
| `02-dashboard.png` | Dashboard |
| `03-calendar.png` | Calendar |
| `04-tools.png` | Tools |
| `05-add.png` | Add |
| `06-calculator-trt.png` | TRT Dose — quick-value row under Weekly dose |
| `07-calculator-barrel-row.png` | TRT Dose scrolled — segmented barrel row |
| `08-logdose-sheet.png` | Log-dose sheet, after the type-scale pass |
| `09-dashboard-ax5.png` | Dashboard at AX5 |
| `10-tools-ax5.png` | Tools at AX5 |

Not re-shot: the drawer and Settings. Those captures contain the account's real
email and avatar, and the standing decision is not to take more of them.

## Quick row vs the pinned result bar — measured

Reported as the result card cutting through the quick-button row. Confirmed, with
one correction to the severity:

| | Measured |
|---|---|
| Selected pill at rest (`06-`) | pt 325.7 → 352.7 — **27.3 pt visible** |
| Same pill once scrolled (`07-`) | pt 230.0 → 273.7 — **44.0 pt, full height** |
| Result bar top | ~pt 353–355 in both |

So the row is **bisected at the default scroll position**, not clipped
permanently — it reaches full height as soon as the form is scrolled. That makes
it a "reads as broken at rest" problem rather than F11, where the field being
actively edited was covered and the CTA was rendered unlabelled.

The cause is not missing padding: the ScrollView already reserves the bar via
`safeAreaInset`, and content scrolls clear of it. It is that the pinned bar takes
~45% of the screen at default size, so the visible form window is short enough
that the third control lands on the boundary. Fixing it means shortening the bar
at default size — which costs result-card information density — so it is a call to
make, not a padding tweak to slip in.
