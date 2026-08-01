# Injectbuddy iOS — Wireframe Plan

Native iOS app (Swift / SwiftUI) mirroring the Injectbuddy app-first web experience.

---

## 1. Goal & principles

- **Open into the work.** After auth, the app launches into the **Cycle Planner dashboard** — no
  marketing, no guides.
- **One side drawer holds everything.** A hamburger-triggered off-canvas **drawer** lists profile,
  Dashboard, Calendar, **all 14 calculators**, Settings, sign-out — the native twin of the
  web `.ib-calc-rail`.
- **Thin client over the existing backend.** Auth + saved protocols + cycles come from the existing
  Supabase / `/api/*` backend. Calculator math is ported from `public/app.js` into a local Swift
  `CalculatorEngine` (offline-capable), kept formula-identical to the web.
- **Sign-in required.** No guest mode.

---

## 2. Navigation model

```
App
└─ RootView
   ├─ if !authenticated → AuthFlow  (Login / Sign up / Reset)
   └─ if authenticated  → MainShell
        ├─ Drawer (off-canvas, hamburger)        ← the "sidebar"
        └─ NavigationStack(content)
             ├─ DashboardScreen   (default / cycle-planner)
             ├─ CalendarScreen
             ├─ CalculatorScreen(slug)   × 14
             └─ SettingsScreen
```

iPad: replace the off-canvas drawer with `NavigationSplitView` (persistent sidebar column).

## 3. Wireframe — iPhone

```
 Dashboard (default)                    Drawer (☰):
┌──────────────────────────────┐      ┌────────────────────┐
│ ☰  injectbuddy               │      │ ✕  injectbuddy      │
├──────────────────────────────┤      │ [pfp] Name          │
│  Next dose  ·  2 protocols   │      │       email         │
│  ┌─ Cycle timeline ───────┐  │      │ ──────────────────  │
│  │  week strip / chart     │  │      │ ▸ Dashboard    ●    │
│  └─────────────────────────┘  │      │ ▸ Calendar          │
│  Saved protocols             │  ☰ → │ CALCULATORS         │
│  ┌────────┐ ┌────────┐       │      │  TRT Dose           │
│  │Test E  │ │Sema    │  …    │      │  TRT & EOD          │
│  └────────┘ └────────┘       │      │  HCG · Peptide …    │
│                              │      │  …(all 14)…         │
│                              │      │ ──────────────────  │
│                              │      │ ⚙ Settings          │
│                              │      │ ⏻ Sign out          │
└──────────────────────────────┘      └────────────────────┘
```

Tapping a drawer item pushes/replaces the content screen and closes the drawer (spring animation,
~0.26s, matching the web drawer feel). Swipe-from-left-edge also opens the drawer.

## 4. Screens

| Screen | Content | Backend |
|---|---|---|
| `AuthFlow` | Login, Sign up, password reset. Supabase email + OAuth (incl. Discord link parity). | `supabase-swift` / `/auth/*` |
| `DashboardScreen` | Cycle-planner: next-dose summary, cycle timeline, saved-protocol cards. Port of the web dashboard. | `/api/me`, cycles/protocols endpoints |
| `CalendarScreen` | 30-day injection calendar projected from protocol frequency. | protocols + client projection |
| `CalculatorScreen(slug)` | One form per calculator; live result. Math from local `CalculatorEngine`. | local; save protocol → backend |
| `SettingsScreen` | Profile, account, Discord link, sign out. No theme control — light only. | `/api/me`, settings endpoints |

### Calculator slugs (14)
`trt-dose` · `trt-eod` · `hcg` · `peptide` · `reconstitution` · `semaglutide` · `tirzepatide` ·
`retatrutide` · `bpc-157` · `bpc-157-tb500` · `bmi` · `free-t-index` · `trt-microdose` · `cycle-plotter`

## 5. Drawer spec (core deliverable)

| Aspect | Spec |
|---|---|
| Component | `DrawerView` overlaying `MainShell`; bound to `@State isDrawerOpen`. Dim/scrim behind; tap-scrim or swipe to dismiss. |
| Sections | Brand, Profile header, **Primary** (Dashboard, Calendar), **Calculators** (14), **Footer** (Settings, Sign out). |
| Source of items | One `NavItems.swift` enum/list (slug, title, SF Symbol). Single source — no duplication. |
| Style | Brand palette per `docs/DESIGN-PARITY.md` (teal `#0fbcad` is a FILL only — never text). SF with matched weights/tracking; Inter deferred. **Light only** — no colour-scheme branching. Active item highlighted. |
| iPad | `NavigationSplitView` persistent column instead of overlay. |

## 6. Architecture & reuse

- **MVVM:** each screen has a `@Observable` view-model; networking via an `APIClient` actor (async/await).
- **Auth:** `AuthStore` (Supabase session); `RootView` switches on it.
- **CalculatorEngine:** pure Swift, unit-tested, **formula-identical to `public/app.js`** — port and
  cross-check against the web outputs (golden tests).
- **Models** mirror the backend (SavedDosage/Protocol, Cycle). Decode from the same JSON the web uses.
- Reuse the backend as-is; do **not** fork backend logic into the app beyond the calculator math.

## 7. Out of scope

- No new calculators/formulas; no backend changes (coordinate separately if an endpoint is missing).
- No guest mode; no marketing/guides screens.
- Android is a separate folder (`injectbuddy-android`).

## 8. Open questions

1. Min iOS version — 16 (NavigationStack) vs 17 (`@Observable` macro)? Default: 16, use `ObservableObject` if needed.
2. Calculator math: port to Swift (offline) vs call a backend calc endpoint? Default: **port** (offline-first).
3. Distribution: TestFlight first; bundle id + signing to be set in TASK 1.
