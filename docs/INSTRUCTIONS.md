# Build Instructions — Injectbuddy iOS

Read this before coding. Design is in `WIREFRAME-PLAN.md`; backlog in `TASKS.md`.

## Where things are

- **This app: greenfield.** No Swift project exists yet — TASK 1 scaffolds it. Decide its home repo
  (e.g. a new `injectbuddy-ios` Git repo); keep this planning folder separate from the code.
- **Backend (reuse, don't fork):** `C:\Users\PFrew\Projects\Injectbuddy` — Next.js `/api/*` + Supabase.
  - Auth + session: Supabase (see `Injectbuddy/supabase/`, `lib/supabase/`).
  - Profile: `GET /api/me`. Protocols/cycles: see `lib/account.ts`, `lib/cycles.ts` for shapes.
  - **Calculator formulas:** `Injectbuddy/public/app.js` — port the math verbatim into Swift.
  - Calculator list + labels: `Injectbuddy/components/nav/SharedNav.tsx` (`CALC_ITEMS`).

> Note: iOS development requires **macOS + Xcode**. This planning folder lives on the Windows box;
> the actual build runs on a Mac. Document the toolchain in TASK 1.

## Stack & conventions

- Swift 5.9+, SwiftUI, iOS 16+ (`NavigationStack`). MVVM + async/await. Swift Package Manager.
- Dependencies: `supabase-swift` (auth/data). Avoid heavy frameworks; prefer URLSession + Codable.
- **One source for nav items** (`NavItems.swift`) — never duplicate the calculator list.
- Theme: **light only** — no dark mode, no theme control. Locked by `UIUserInterfaceStyle: Light`
  in `project.yml`. Brand colour and typography come from `docs/DESIGN-PARITY.md`, which is
  authoritative over this file on anything visual.
- **CalculatorEngine must match the web math** — add golden unit tests comparing against `app.js` outputs.
- Root cause over band-aid. Only build what's asked; park extras in `TASKS.md`.

## Privacy / security

- No secrets in source — Supabase anon key via config/`.xcconfig` (gitignored), never hard-coded.
- This planning folder is internal — never commit or deploy it.

## Definition of done (per task)

1. App builds in Xcode; runs in simulator.
2. Unauthed launch → auth screen; authed launch → **dashboard / cycle-planner**.
3. Drawer lists all 14 calculators + Dashboard + Calendar and navigates to each; swipe + scrim dismiss work.
4. New/changed unit tests pass (incl. CalculatorEngine golden tests).
5. Task moved to Done in `TASKS.md`; your row removed from `ACTIVE.md` (see `AGENT-WORKFLOW.md`).
