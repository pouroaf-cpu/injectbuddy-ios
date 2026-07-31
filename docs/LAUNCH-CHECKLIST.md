# InjectBuddy iOS — Launch Checklist

> Internal ops doc — everything left to take the app from "code-complete on Windows" to "live on the
> App Store." Grouped by **where** the work happens. Code lives in the private repo
> `github.com/pouroaf-cpu/injectbuddy-ios` (`app/`). Drafted content is in `injectbuddy-ios/launch/`.
> Last updated 2026-06-05 by bison30. Status legend: ⬜ to do · 🔄 in progress · ✅ done.

---

## 🔴 P0 — blockers (do first)

### A. Supabase dashboard — project `injectbuddy` (ref `rktklvutvbombuajrvrv`)
- ⬜ **Add OAuth redirect:** Auth → URL Configuration → Redirect URLs → add
  `com.injectbuddy.ios://login-callback`. **Discord sign-in cannot complete without this.**
- ⬜ Enable **leaked-password protection** (Auth → Policies) — security advisor WARN, app does email/pw signup.
- ✅ RLS verified enabled on `saved_dosages`, `dose_log`, `cycles`, `cycle_items`, `profiles` (the tables
  the app writes directly). No action — recorded for confidence.

### B. First Mac build + verify (the gating proof — nothing is confirmed until this passes)
- ⬜ `brew install xcodegen`
- ⬜ `cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig` and fill `SUPABASE_HOST` + `SUPABASE_ANON_KEY`
- ⬜ `xcodegen generate && open InjectBuddy.xcodeproj`; let SPM resolve `supabase-swift`
- ⬜ Build + run in an iOS 16+ simulator; **fix-up pass** on the blind-authored external API surface:
  `supabase-swift` calls (`AuthStore`, `SupabaseBackendClient`), `Charts` (`CyclePlotterScreen`), `M_LN2`.
- ⬜ Run tests (`InjectBuddyTests`): confirm the 14 CalculatorEngine golden vectors + DoseProjection tests pass.
- ⬜ Confirm Definition of Done: unauthed→auth, authed→dashboard, drawer lists 14 calcs + Dashboard +
  Calendar, swipe/scrim dismiss, disclaimer gate shows once.
- ⬜ Sanity-check each calculator's saved `calculator_type` matches the web (cross-platform protocol parity).

---

## 🟠 P1 — before submission

### C. App Store Connect + signing  (see `app/SIGNING.md`)
- ⬜ Register App ID `com.injectbuddy.ios` (Apple Developer portal) + create the App Store Connect app record.
- ⬜ Generate an App Store Connect **API key** (role App Manager); keep Issuer ID / Key ID / `.p8`.
- ⬜ Add **GitHub repo secrets:** `SUPABASE_HOST`, `SUPABASE_ANON_KEY`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_KEY_P8` (base64 of the .p8), `DEVELOPMENT_TEAM`.
- ⬜ Run the CI workflow on a PR (smoke test) before tagging a `v*` TestFlight release.

### D. Submission content — finalize the drafts in `launch/`
- ⬜ Fill every `<<CONFIRM>>` placeholder: legal entity/individual name, support email
  (`support@injectbuddy.com` — confirm the inbox exists), jurisdiction/governing law, effective dates.
- ⬜ **Host the privacy policy** (`launch/PRIVACY-POLICY.md`) at a public URL (e.g. injectbuddy.com/app-privacy/)
  and set it as the App Privacy URL + a Support URL. (Note: the web `/privacy/` page says "no accounts/no
  data" — false for the app, so the app needs its own policy.)
- ⬜ Enter the App Privacy answers from `launch/APP-PRIVACY.md` (Email + User Content + User ID, linked,
  no tracking, App Functionality).
- ⬜ Pick final ASO title/subtitle/keywords/description from `launch/ASO.md`; run a live App Store
  competitor search first.
- ⬜ Paste the reviewer notes from `launch/APP-REVIEW-NOTES.md`; **create a seeded demo reviewer account**
  (email/password with sample protocols) and enter it in App Store Connect; verify the Discord OAuth email
  fallback so reviewers don't need Discord.
- ⬜ Complete the age-rating questionnaire (anticipate 17+ for a dosage/health tool).

### E. App icon
- ⬜ Produce a 1024×1024 PNG (no alpha) and drop it into `Assets.xcassets/AppIcon.appiconset/` (slot is
  ready and empty — see `Sources/InjectBuddy/Resources/ASSETS.md`).

---

## 🟡 P2 — nice to have / post-launch

- ⬜ **TASK 9** — first real TestFlight upload via `fastlane beta` once C is done.
- ⬜ **TASK 11** — CI guard so the Swift `CalculatorEngine` can't silently drift from the web `app.js`
  (re-derive golden vectors from a shared fixture).
- ⬜ Backend hygiene for the web team (out of scope for iOS, from the Supabase security advisor): lock down
  `SECURITY DEFINER` functions (`handle_new_user`, `confirm_blood_test`, `get_upload_quota`), tighten the
  public `avatars` bucket listing policy, set `search_path` on `set_updated_at`.

---

## Reference
- Code: `app/` · Build steps: `app/README.md` · Signing/CI: `app/SIGNING.md`
- Content drafts: `launch/ASO.md`, `launch/APP-PRIVACY.md`, `launch/PRIVACY-POLICY.md`, `launch/APP-REVIEW-NOTES.md`
- Math spec: `CALC-MATH.md` · Status snapshot: `STATUS.md` · Full backlog: `TASKS.md`
