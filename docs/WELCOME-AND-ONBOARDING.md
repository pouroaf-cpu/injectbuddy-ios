# Welcome screen + onboarding — spec

Requested 2026-08-01. Three pieces of work, not one.

**Scope correction first.** iOS already has a complete auth flow —
`Features/Auth/AuthFlowView.swift`, 227 lines, with `login / signUp / reset /
verify` modes, email + password, Discord OAuth, a resend cooldown, and validation
(`password.count >= 6 && password == confirm`). Sign-in/sign-up is **not** being
built from scratch. What is missing is the welcome screen before it, the
onboarding after it, and a restyle of the screen that already exists.

| # | Work | State |
|---|---|---|
| 1 | Animated welcome screen | does not exist |
| 2 | Restyle `AuthFlowView` | exists, unstyled |
| 3 | 5-step onboarding after sign-up | does not exist |

`grep -c "Theme.Typeface" AuthFlowView.swift` returns **0**. It is the second
screen found in this state, after the log-dose sheet — and it is the *first
screen a new user ever sees*. Same defect, higher stakes.

---

## 1. Welcome screen

### Behaviour before aesthetics

`AuthStore.Phase` is already `.loading / .signedOut / .signedIn`, and `RootView`
switches on it. The welcome screen occupies `.loading` and fronts `.signedOut`.

**A returning signed-in user must never wait on an animation.** If the session
resolves in 200 ms, the welcome screen leaves in 200 ms. Animation duration is a
*ceiling on how long it may remain*, never a floor. Anything else means the app
gets slower the more polished it looks, and a daily-use dosing app is the wrong
place to spend a user's time on branding.

- `.loading` → welcome, sized to however long auth actually takes
- `.signedOut` → welcome animates in fully, then presents `AuthFlowView`
- `.signedIn` + onboarding incomplete → onboarding (§3)
- `.signedIn` + onboarding complete → straight to the dashboard

### Composition

Canvas `#FAFAFB`. Navy and teal only — the palette in `DESIGN-PARITY.md §8`.

1. The syringe mark draws or scales in, teal `#0FBCAD`
2. `injectbuddy` wordmark, teal, settling beside it
3. A single line of supporting copy, navy `#001D5C`
4. CTAs: **Create account** (navy fill, white text, 15.79:1) and **Sign in**
   (bordered, navy label)

### Animated text — the constraints that matter

- **Staggered fade + rise per line**, ~60 ms apart, 400–500 ms each, ease-out.
  Restraint reads as professional; bounce and spring read as consumer-toy.
- **No multi-stop gradient on text. Measured, not stylistic** — SwiftUI
  desaturates any multi-colour gradient regardless of stop spacing
  (`#075E56` → `#4B5557`, and 25 pre-blended stops changed nothing). Solid fills
  only. See `BOARD.md §3`.
- **Honour `accessibilityReduceMotion`** — final state immediately, no motion.
  Non-negotiable; it is the rule the PWA already follows at
  `DashStyles.tsx:965`.
- Every text colour passes at its final value **and throughout the transition**.
  A line that fades in through a low-contrast midpoint fails while it animates.
- No text in the animation that isn't also in the accessibility tree.

## 2. Restyle `AuthFlowView`

Apply `Theme.Typeface` and the palette. Field treatment matches the calculator
family — **44.0 pt**, r10, 1 pt `#8E8E93`, white — verified as the app-wide
standard by the control inventory. Primary CTA navy, white text.

Check `Cancel`-style secondary actions for the teal-as-text failure: `#0FBCAD`
text is 2.13–2.38:1 and fails. Secondary labels take `#075E56`.

Do not change auth *behaviour*. Validation, the cooldown, Discord OAuth and the
verify flow work; this is typography and colour only.

## 3. Onboarding — 5 steps

Mirror the PWA exactly: `components/account/PersonalisationForm.tsx`,
`STEP_META` at line 27. Runs once after sign-up, when
`profiles.onboarding_completed_at` is null.

| # | Eyebrow | Title | Collects |
|---|---|---|---|
| 1 | How should we greet you? | Make the dashboard yours | `nickname` |
| 2 | Your defaults | Choose how numbers are shown | `preferred_weight_unit` (kg/lb), `preferred_height_unit` (cm/ft), `preferred_dose_unit` (auto/mg/mcg/units) |
| 3 | Optional baseline | Add your current measurements | `weight_kg`, `height_cm` |
| 4 | Local time | Keep every dose on the right day | `timezone` |
| 5 | Your focus | What are you most interested in logging? | `logging_interests[]` |

Step 5 options, copy verbatim from `INTEREST_LABELS`:

- **Hormones** — TRT, HRT and supporting protocols
- **Steroids** — Cycles, compounds and injection schedules
- **Peptides** — Reconstituted peptides and site rotation
- **GLP-1** — Weekly dosing and titration tracking

### Target — `public.profiles`, confirmed against the live schema

`nickname` text · `weight_kg` numeric · `height_cm` numeric · `timezone` text ·
`preferred_weight_unit` text NOT NULL · `preferred_height_unit` text NOT NULL ·
`preferred_dose_unit` text NOT NULL · `logging_interests` array NOT NULL ·
`onboarding_completed_at` timestamptz

Defaults from `lib/personalisation.ts:19` — nickname/weight/height/timezone
null, units `kg` / `cm` / `auto`, interests `[]`.

**The three NOT NULL columns and the array must never be written null.** Step 3
is optional and steps can be skipped, so a skipped step writes the default, not
a null. Set `onboarding_completed_at` only on completion — it is the flag that
stops the flow reappearing.

Conversions live at `lib/personalisation.ts:31-33`: `lbToKg = v / 2.2046226218`,
`inchesToCm = v * 2.54`. Store metric always; the unit preference is display
only. **Do not round on the way in** — a user entering 180 lb must get 180 lb
back, not 179.9.

### Styling, from the PWA's own CSS

Step icon 40×40, r12, `rgba(15,188,173,.1)` fill, `#087f76` glyph. Eyebrow 11 px,
weight 700, uppercase, `.07em` tracking, muted. Title 21 px navy, `-.025em`.
Field labels navy, weight 750, 13 px. Progress dots, one per step, done /
active / upcoming.

CTA copy: **Continue →** on steps 1–4, **Open my dashboard →** on step 5.

## Non-negotiables

Everything already earned applies. 44 pt targets. 4.5:1 body, 3:1 icons and
borders, 7:1 preferred. No state by colour alone. Every value+unit pair reflows
at AX5 — step 3 collects weight and height *with units*, which is exactly the
shape that truncated before. Reduce Motion honoured. Light-only.

## Verify

Screenshot every welcome frame, every auth mode, and all five steps, at default
**and** AX5. Measure the animated text mid-transition, not only at rest. Confirm
a returning signed-in user reaches the dashboard without waiting on the
animation. Confirm a completed onboarding does not reappear on next launch.

Do not write test rows to `profiles` against the real account without saying so
— the Windows side has database access and can verify and clean up.
