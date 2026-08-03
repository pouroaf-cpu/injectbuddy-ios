# InjectBuddy iOS — App Store App Privacy ("Nutrition Label")

How to fill in the **App Privacy** section in App Store Connect (App Store Connect →
your app → App Privacy → Get Started). Answers are derived from what the app actually
handles, per `Core/Models/Models.swift` and `Core/Backend/BackendClient.swift`.

## What the app actually handles (ground truth)

| Source | Data |
|--------|------|
| Supabase Auth session | **Email address** (sign-in identity), **user id** (UUID) |
| `profiles` table | `display_name` (optional, user-entered) |
| `saved_dosages` table | `calculator_type`, `label`, **`config` (the dose/compound/concentration the user saved)**, `start_date`, `is_active` |
| `cycles` / `cycle_items` | cycle name, goal, compounds, doses, frequency, dates |
| `dose_log` table | `dosed_on` date, `draw_ml`, injection `site` — a log of doses marked taken |
| Discord OAuth (optional) | email (used as the account identity; same as above) |

Key facts that drive the answers below:
- **No advertising or third-party analytics SDK is bundled in the iOS app.** (The *website* uses
  PostHog/Clarity/GA4; the app does not. Do not declare those for the app.)
- Everything stored is **linked to the user's identity** (Supabase user id / email) via row-level
  security — it is the user's own account data.
- **Nothing is used for tracking** (no cross-app/website tracking, no data brokers, no ad networks).
- Calculator math runs **on-device**; dose inputs are only transmitted if the user chooses to *save*
  a protocol/cycle/dose to their account.

---

## Data types to declare

For each: **Collected? / Linked to identity? / Used for tracking? / Purpose.**
Tracking is **No** for every type. Linked is **Yes** for every type (account-bound). Purpose is
**App Functionality** for every type (no analytics, no ads).

### 1. Contact Info → Email Address
- Collected: **Yes**
- Linked to user's identity: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** (account creation, authentication, sync)

### 2. Health & Fitness → Health
- Collected: **Yes** (conservative classification)
- Linked to user's identity: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality**
- Note: the app does **not** use Apple HealthKit. The "health" classification is because saved
  dosage protocols, cycles and the dose log are health-adjacent user content. Declaring it here is
  the conservative, defensible choice. (If App Store Connect's wording makes "Health" imply HealthKit
  in a way that misrepresents the app, the fallback is to declare these items solely under **User
  Content → Other User Content** below and footnote the health-adjacency. <<CONFIRM: choose one
  approach and keep it consistent with PRIVACY-POLICY.md.>>)

### 3. User Content → Other User Content
- Collected: **Yes**
- Linked to user's identity: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality**
- Covers: saved protocols (`saved_dosages.config` + label), cycles/cycle items, the dose log,
  and `display_name`.

### 4. Identifiers → User ID
- Collected: **Yes**
- Linked to user's identity: **Yes**
- Used for tracking: **No**
- Purpose: **App Functionality** (the Supabase account UUID that owns the rows)

### NOT collected (declare as not collected)
- Device ID / advertising identifier — **No** (no ad/analytics SDK)
- Usage Data, Diagnostics, Crash data — **No** (no analytics/crash SDK bundled) <<CONFIRM: if you
  later add a crash/diagnostics SDK, e.g. Sentry or Apple's own crash reporting opt-in, update this.>>
- Precise/Coarse Location — **No**
- Name, Phone Number, Physical Address, Payment Info — **No**
- Contacts, Photos, Browsing/Search History, Purchases, Financial Info, Sensitive Info — **No**

---

## "Data Used to Track You"
**None.** Set the tracking question to **No** for all data. Do not request App Tracking Transparency
(ATT) — the app does not track.

## "Data Linked to You"
- Email Address
- Health (dosage protocols / cycles / dose log, as user content)
- Other User Content
- User ID

## "Data Not Linked to You"
**None.**

---

## Copy-paste checklist for App Store Connect

```
[ ] App Privacy → "Do you or your third-party partners collect data?" → YES

[ ] Contact Info → Email Address
      Collected: YES | Linked: YES | Tracking: NO | Purpose: App Functionality

[ ] Health & Fitness → Health        (see note #2 — conservative; or move to User Content)
      Collected: YES | Linked: YES | Tracking: NO | Purpose: App Functionality

[ ] User Content → Other User Content   (saved protocols, cycles, dose log, display name)
      Collected: YES | Linked: YES | Tracking: NO | Purpose: App Functionality

[ ] Identifiers → User ID
      Collected: YES | Linked: YES | Tracking: NO | Purpose: App Functionality

[ ] Tracking question → NO data used for tracking (no ATT prompt)

[ ] Confirm NO declaration for: Device ID, Usage Data, Diagnostics, Location, Name,
    Phone, Payment, Crash data  (no analytics/ads/crash SDK in the iOS build)

[ ] Privacy Policy URL set (see PRIVACY-POLICY.md — must be live before submission)

[ ] Account deletion path present in-app (Settings → Delete account) — required by
    Guideline 5.1.1(v) for apps that support account creation
```

> Verify against the shipped build before submitting: confirm the iOS target links **no** analytics,
> ads, attribution or crash-reporting SDK. If any third-party SDK is added later, re-open App Privacy
> and update the relevant types/purposes — Apple treats stale privacy labels as a violation.
