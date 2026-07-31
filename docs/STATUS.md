# Injectbuddy iOS — Status   (snapshot, ≤50 lines, prune don't append)

## 🎯 Now
Native app is **code-complete + launch-prepped on Windows** but **not yet compiled** (no SwiftUI/
supabase-swift toolchain on Windows). Next step is a Mac: `xcodegen generate` → build → fix-up.
App in its own **private** repo: github.com/pouroaf-cpu/injectbuddy-ios (`app/`, `main`, head `f3d6e0b`).
Launch-prep pass added OAuth redirect wiring, a first-run medical-disclaimer gate, asset catalog
(empty icon slot + teal accent), CI/TestFlight (fastlane + GH Actions), and submission content (in
the internal `launch/` folder). Supabase RLS verified on all 5 tables the app writes.

## 📝 Last 3 changes
- Pre-Mac verification pass (`994f65d`): verified supabase-swift 2.5.1 + PostgREST API vs docs (fixed a
  build-breaker — `auth.session(from:)` → `auth.handle(url)`); 2 read-only review agents over all 35
  files (Core/Shell/Auth clean; fixed a twice-weekly projection rounding bug); all 14 golden vectors
  independently re-passed in Node (`tools/verify-math.js`).
- Launch-prep (`f3d6e0b`): OAuth redirect wiring (URL scheme + onOpenURL), first-run disclaimer gate,
  asset catalog (icon slot + AccentColor), CI/TestFlight (fastlane + GH Actions), submission content
  in `launch/` (ASO, App Privacy map, privacy policy, review notes). RLS verified on the app's tables.
- Built the whole app (`646f115`): scaffold + Core + Shell + Auth + Dashboard + Calendar + Settings +
  CalculatorEngine (ported from web app.js) + 14 calculator screens + Cycle Plotter + golden tests.
- Math ported verbatim from `Injectbuddy/public/app.js` (see `CALC-MATH.md`); 14 golden vectors asserted.

## ⏭️ Next priorities  (all require a Mac — none verifiable on Windows)
- [ ] On a Mac: `brew install xcodegen`; `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig`
      (fill SUPABASE_HOST + SUPABASE_ANON_KEY); `xcodegen generate`; build in Xcode; run in simulator.
- [ ] Fix-up pass is now SMALL: supabase-swift/PostgREST verified vs 2.5.1 docs + adversarial review done.
      Still confirm on Mac: **Charts** modifiers in CyclePlotterScreen and `M_LN2` (both expected fine).
- [ ] Verify the 14 golden tests + projection tests pass; confirm DoD (unauthed→auth, authed→dashboard,
      drawer lists 14 calcs + Dashboard + Calendar, swipe/scrim dismiss).
- [ ] TASK 9 — fastlane + CI are written; needs the GitHub secrets + App Store Connect setup in
      `app/SIGNING.md`, then a first CI smoke run.
- [ ] Human finalize of `launch/` content: fill the `<<CONFIRM>>` items (entity name, support email,
      jurisdiction, hosted privacy URL, demo reviewer account), add the 1024 app-icon art, run an App
      Store competitor search.
- [ ] Supabase prod config (dashboard): add `com.injectbuddy.ios://login-callback` to Auth → Redirect
      URLs (Discord OAuth won't complete without it); enable leaked-password protection (advisor WARN).

## ⚠️ Known issues / don't-touch
- `saved_dosages.calculator_type` MUST stay = `CalculatorSlug.rawValue` (trt/eod/bpc157/…) so protocols
  match the web. Verify each calc's saved type against app.js during the Mac pass if any look off.
- Web `/api/*` use cookie auth → unusable from a native bearer-token client. App talks to Supabase
  PostgREST directly (RLS) instead — this is intentional, not a gap.
- Internal docs (this file, CALC-MATH.md, planning *.md) stay out of the public `app/` repo.
