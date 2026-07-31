# injectbuddy-ios — planning workspace

> **PRIVACY:** Internal planning folder. Do not commit to a public repo or deploy.

Wireframe plan + build instructions for a **native iOS app** (Swift / SwiftUI) that mirrors the
Injectbuddy web app's **app-first** experience:

- Opens straight into the **dashboard / cycle-planner** after sign-in.
- **All 14 calculators** reachable from a single **side drawer** — the native equivalent of the
  web/mobile `.ib-calc-rail` sidebar.
- **Sign-in required** — guests see the auth screen first.
- **No guides, no marketing pages.**

This is a **greenfield native app** (no Swift code exists yet). It is a **client of the existing
Injectbuddy backend** (`C:\Users\PFrew\Projects\Injectbuddy` — Next.js `/api/*` + Supabase). Reuse
the backend and the calculator math/formulas; build the UI natively.

## Files

| File | Purpose |
|------|---------|
| `WIREFRAME-PLAN.md` | Shell, navigation (side drawer), nav model, architecture, reuse map. Read first. |
| `SCREENS.md` | Detailed per-screen wireframes (ASCII + SwiftUI spec): dashboard, calculators, auth, settings, calendar. |
| `INSTRUCTIONS.md` | How to execute — stack, where the backend is, conventions, what to reuse. |
| `AGENT-WORKFLOW.md` | Session lifecycle: claim an ACTIVE row at start, remove it at end. Mandatory. |
| `ACTIVE.md` | The live board. |
| `TASKS.md` | Build backlog, phased. |

## Stack (locked)

- **Language:** Swift 5.9+ (Swift 6 ready)  ·  **UI:** SwiftUI  ·  **Min target:** iOS 16 (`NavigationStack`)
- **Architecture:** MVVM, async/await  ·  **Auth/data:** Supabase (`supabase-swift`) + existing `/api/*`
- **Side menu:** custom SwiftUI off-canvas drawer (iPhone) / `NavigationSplitView` (iPad)
