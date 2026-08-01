# InjectBuddy iOS

Native iOS app (Swift / SwiftUI, iOS 16+) for InjectBuddy — opens straight into the cycle-planner
dashboard, with all 14 dosage calculators in a side drawer. Thin client over the existing InjectBuddy
Supabase backend; calculator math is ported to a local, offline `CalculatorEngine`.

## Requirements

- macOS 13+ with **Xcode 15+**
- [XcodeGen](https://github.com/yonwoo9/XcodeGen) (`brew install xcodegen`) — the Xcode project is
  generated from `project.yml`, so it is never checked in.

## First build (on a Mac)

```bash
# 1. Provide Supabase credentials (gitignored)
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
#    edit Config/Secrets.xcconfig and fill in SUPABASE_URL + SUPABASE_ANON_KEY

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open InjectBuddy.xcodeproj
#    select the InjectBuddy scheme → an iOS 16+ simulator → ⌘R
```

Swift Package dependencies (`supabase-swift`) resolve automatically on first open.

> **`Sources/InjectBuddy/Resources/Info.plist` is GENERATED — never hand-edit it.**
> `project.yml` declares an `info:` block, so `xcodegen generate` rewrites that file
> from scratch and silently discards anything you added directly. On 2026-07-31 this
> ate `CFBundleURLTypes`, which registers the `com.injectbuddy.ios` scheme — with it
> gone, the signup confirmation email and the Discord OAuth callback both had nowhere
> to land, while the verify screen still told users to click the link. It took
> `UIApplicationSceneManifest` and `ITSAppUsesNonExemptEncryption` with it. Add plist
> keys under `targets.InjectBuddy.info.properties` in `project.yml` instead, then
> re-run `xcodegen generate` and confirm the key survives.

## Layout

```
Sources/InjectBuddy/
  App/        app entry + RootView (auth gate)
  Core/
    Theme/      colors, teal accent, light/dark tokens
    Models/     Codable mirrors of the Supabase tables
    Nav/        NavItems — the single source for drawer items (Dashboard, Calendar, 14 calcs, Settings)
    Backend/    BackendClient protocol + Supabase (PostgREST/RLS) implementation
    Auth/       AuthStore (Supabase session), Keychain persistence
    Calculator/ CalculatorEngine (ported math) + per-slug specs
  Features/
    Auth/       login / signup / reset
    Shell/      MainShell + off-canvas DrawerView
    Dashboard/  cycle-planner (default screen)
    Calculators/ generic CalculatorScreen(slug) + Cycle Plotter
    Calendar/   30-day injection calendar
    Settings/   profile, theme, units, sign out
Tests/InjectBuddyTests/  CalculatorEngine golden tests + calendar projection tests
```

## Backend

Reuses `Injectbuddy` (Next.js + Supabase). The app authenticates with `supabase-swift` and reads/writes
the user's own rows (`saved_dosages`, `cycles`, `cycle_items`, `dose_log`, `profiles`) directly through
PostgREST under row-level security — no backend changes. Calculator formulas are ported verbatim from
the web `public/app.js` and locked with golden unit tests.

## Notes

- **No secrets in source.** The Supabase anon key lives only in `Config/Secrets.xcconfig` (gitignored)
  and is surfaced to the app via the build setting / Info.plist.
- Any handoff to a web page uses `SFSafariViewController` (shared cookies + correct referrer), never a
  bare `WKWebView`.
