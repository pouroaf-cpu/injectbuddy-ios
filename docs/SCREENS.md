# Injectbuddy iOS — Screen Wireframes (detail)

Per-screen ASCII wireframes + SwiftUI specs. Companion to `WIREFRAME-PLAN.md` (shell + drawer).
All screens render inside `MainShell` (drawer + `NavigationStack`) unless marked pre-auth.
Conventions: teal `#0fbcad` accent, SF Symbols, light/dark via `@Environment(\.colorScheme)`.
Every data-backed screen has three states — **loading** (redacted/skeleton), **empty** (CTA),
**error** (message + Retry). Listed once here; assume on every networked screen.

---

## 1. Dashboard / Cycle-Planner  — `DashboardScreen` (start destination)

```
┌──────────────────────────────┐
│ ☰  injectbuddy           ◐   │  toolbar: leading hamburger, trailing theme
├──────────────────────────────┤
│  Good evening, Pouroa        │  greeting (display name)
│                              │
│  ┌── NEXT DOSE ───────────┐  │  prominent card
│  │ Test E · 0.25 mL       │  │   compound + volume
│  │ 50 mg  ·  due in 1d 4h │  │   dose + countdown
│  │ [ Mark taken ]         │  │   primary action
│  └────────────────────────┘  │
│                              │
│  THIS CYCLE                  │  section header
│  ┌── timeline ────────────┐  │  horizontal week strip
│  │ M T W T F S S          │  │   • = dose day (colored per protocol)
│  │ ● · ● · · ● ·          │  │   highlight = today
│  │ Day 12 of 84           │  │   progress caption
│  └────────────────────────┘  │
│                              │
│  PROTOCOLS            + Add   │  header + trailing add
│  ┌──────────┐ ┌──────────┐   │  cards (LazyVGrid, 2-col)
│  │ Test E   │ │ Sema     │   │   primary line (compound abbrev)
│  │ 50mg E3.5│ │ 0.5mg wk │   │   secondary (dose · frequency)
│  └──────────┘ └──────────┘   │   tap → edit / open source calc
│                              │
│  WEEK AT A GLANCE            │  StatsIsland
│  100mg test · 0.5mg sema     │   weekly totals
└──────────────────────────────┘
```

- **Layout:** `ScrollView { VStack(spacing) }`. Cards = rounded `.background(.regularMaterial)`.
- **Components:** `NextDoseCard`, `CycleTimelineStrip` (horizontal `ScrollView` of `DayCell`),
  `ProtocolGrid` (`LazyVGrid`, `ProtocolCard`), `StatsIsland`.
- **View-model:** `DashboardViewModel` (`@Observable`) → `load()` fetches profile + protocols +
  active cycle from `APIClient`. Derives next dose + weekly totals client-side.
- **Data:** `GET /api/me`, protocols (`lib/account.ts` shape), cycles (`lib/cycles.ts` shape).
- **States:** loading → skeleton cards. **empty (no protocols)** → illustration + "Add your first
  protocol" → opens a calculator. error → inline banner + Retry.
- **Nav:** `+ Add` → drawer-style calculator picker or push `CalculatorScreen`. Protocol card tap →
  edit sheet. "Mark taken" → optimistic update + POST.

---

## 2. Calculator screens — `CalculatorScreen(slug)`

### 2a. Generic template (all 14 share this skeleton)

```
┌──────────────────────────────┐
│ ‹ Back   TRT Dose        ◐   │  large-title nav bar; back to last screen
├──────────────────────────────┤
│  INPUTS                      │  Form section 1
│  ┌────────────────────────┐  │
│  │ Ester      [Test E ▾]  │  │  picker
│  │ Concentr.  [250] mg/mL │  │  numeric + unit
│  │ Weekly dose[100] mg    │  │  numeric
│  │ Frequency  [E3.5 ▾]    │  │  picker
│  └────────────────────────┘  │
│                              │
│  ┌── RESULT (live) ───────┐  │  sticky result card
│  │ 0.20 mL per injection  │  │   primary output (big)
│  │ ≈ 20 IU on U-100       │  │   secondary conversions
│  │ 2× / week · Mon, Thu   │  │   schedule line
│  └────────────────────────┘  │
│                              │
│  [ Save as protocol ]        │  primary button → links to dashboard
│                              │
│  ⓘ Maths only — not medical  │  disclaimer footnote
│    advice. References ›      │  expandable
└──────────────────────────────┘
```

- **Layout:** `Form` (or `ScrollView`+sections) with a pinned `ResultCard` (`.safeAreaInset(edge:.bottom)`).
- **Driven by config:** `CalculatorSpec` per slug = ordered fields (label, key, type:
  number/picker/toggle, unit, default) + an `evaluate(inputs) -> Result` from `CalculatorEngine`.
  One `CalculatorScreen` renders any slug from its spec — no 14 bespoke views.
- **Live result:** recompute on every input change (`onChange`); no network needed (offline).
- **Save:** `Save as protocol` → POST to backend, then pop to Dashboard with the new card present.
- **Units:** respect the user's unit preference (Settings) for syringe scale (U-100/U-40) + metric/imperial.

### 2b. Per-slug field notes (specs for `CalculatorSpec`)

| Slug | Inputs | Primary result |
|---|---|---|
| `trt-dose` | ester, conc mg/mL, weekly dose mg, frequency | mL per injection + IU + schedule |
| `trt-eod` | conc, weekly dose, EOD frequency | mL per EOD shot |
| `trt-microdose` | conc, daily/EOD dose | mL per micro-shot |
| `hcg` | vial IU, BAC water mL, dose IU | IU/units to draw |
| `peptide` / `reconstitution` | vial mg, BAC water mL, dose mcg | units on U-100 syringe |
| `bpc-157` | vial mg, BAC water mL, dose mcg | units to draw |
| `bpc-157-tb500` | two compounds mg, BAC water, doses | units (blend) |
| `semaglutide` | vial mg, BAC water mL, dose mg | units/week |
| `tirzepatide` | vial mg, BAC water mL, dose mg | units/week |
| `retatrutide` | vial mg, BAC water mL, dose mg | units/week |
| `bmi` | height, weight (metric/imperial) | BMI value + WHO category |
| `free-t-index` | total T, SHBG (units) | FTI / free-T estimate |
| `cycle-plotter` | multiple compounds + durations | multi-week plotted timeline (full-screen chart, not the compact form) |

> `cycle-plotter` is the one exception to the generic form: it's a timeline editor (add compounds →
> rendered Gantt-style strip). Wireframe it separately under TASK 6 when reached.

---

## 3. Auth screens (pre-auth — no drawer) — `AuthFlow`

```
 Login                          Sign up                       Reset
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│   injectbuddy    │          │   injectbuddy    │          │  Reset password  │
│                  │          │  Create account  │          │                  │
│ Email   [______] │          │ Email   [______] │          │ Email   [______] │
│ Pass    [______] │          │ Pass    [______] │          │                  │
│                  │          │ Confirm [______] │          │ [ Send reset ]   │
│ [   Sign in   ]  │          │ [  Sign up    ]  │          │                  │
│  ──── or ────    │          │  ──── or ────    │          │ ‹ Back to login  │
│ [ Continue with  │          │ [ Continue with  │          └──────────────────┘
│   Discord ]      │          │   Discord ]      │
│ Forgot? · Sign up│          │ Have an account? │
└──────────────────┘          └──────────────────┘
```

- **Components:** `AuthField` (validated), `PrimaryButton`, `OAuthButton(.discord)`.
- **Flow:** `RootView` shows `AuthFlow` when `AuthStore.session == nil`. On success → session set →
  `RootView` swaps to `MainShell` (Dashboard). Session persisted in Keychain.
- **Validation:** inline errors; disable submit until valid; show spinner + disable on submit.
- **OAuth:** Supabase OAuth (Discord) — parity with the web's Discord link.

---

## 4. Settings — `SettingsScreen`

```
┌──────────────────────────────┐
│ ‹  Settings                  │
├──────────────────────────────┤
│  ┌─ profile ──────────────┐  │
│  │ [pfp] Pouroa Frew      │  │  tap → edit name/avatar
│  │       pouroaf@…        │  │
│  └────────────────────────┘  │
│  PREFERENCES                 │
│  Theme            System ▾   │  light / dark / system
│  Units            Metric ▾   │  metric / imperial
│  Syringe scale    U-100 ▾    │  U-100 / U-40
│  CONNECTIONS                 │
│  Discord          Link ›     │  link / unlink (status)
│  ACCOUNT                     │
│  Change password        ›    │
│  Notifications          ›    │  dose reminders (later)
│  Sign out               ⏻    │  destructive
│  Delete account         ⚠︎   │  destructive, confirm
└──────────────────────────────┘
```

- **Layout:** SwiftUI `List` with grouped sections; `Picker`/`Toggle`/`NavigationLink` rows.
- **Theme/units** persist to `@AppStorage` + sync to backend prefs; theme drives the app color scheme override.
- **Discord** mirrors `/discord-link`. **Sign out** clears session → `RootView` → `AuthFlow`.
  **Delete** → confirm dialog → backend → sign out.
- **Reachable** from the drawer (Settings) and the dashboard profile tap.

---

## 5. Calendar — `CalendarScreen`

```
┌──────────────────────────────┐
│ ☰  Calendar          ◐       │
├──────────────────────────────┤
│  June 2026         ‹  Today › │  month label + paging
│  Mo Tu We Th Fr Sa Su        │
│   1  2  3  4  5  6  7         │  grid; dot(s) under days with doses
│   .  ●  .  ●  .  .  ●         │  dots colored per protocol
│   8  9 10 11 12 13 14         │
│   ● [14]●  .  ●  .  ●         │  [today] ring
│  …                           │
│  ── SELECTED: Wed 11 ──────  │  agenda for tapped day
│  • Test E   50mg  · 0.25 mL  │
│  • Sema     0.5mg            │
│  (tap a dose → mark taken)   │
└──────────────────────────────┘
```

- **Projection:** for each saved protocol, project due dates from `startDate` + `frequency` across a
  rolling 30-day window (match the web calendar logic exactly). Pure function, unit-tested.
- **Components:** `MonthGrid` (`LazyVGrid`, `DayCell` with dose dots), `DayAgenda` list below.
- **Interactions:** tap day → agenda updates; tap dose → mark taken (optimistic). Swipe month paging.
- **States:** empty (no protocols) → "Add a protocol to see your schedule" CTA → calculator/dashboard.

---

## Build order note
These five map to TASKS 3–8 in `TASKS.md`. `cycle-plotter` (calculator #14) gets its own detailed
wireframe when TASK 6 reaches it — it's a timeline editor, not the generic input form.
