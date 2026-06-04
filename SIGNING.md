# Signing & CI / TestFlight setup

This repo ships two GitHub Actions workflows and a fastlane setup:

- **`.github/workflows/ci.yml`** — the always-on quality gate. On every push / PR to
  `main` it regenerates the Xcode project with XcodeGen and runs the unit tests
  (`CalculatorEngine` golden tests + calendar projection) on an iOS simulator. No
  signing, no secrets beyond Supabase.
- **`.github/workflows/testflight.yml`** — manual (`workflow_dispatch`) or on a `v*`
  tag. Builds a signed archive and uploads it to TestFlight using an **App Store
  Connect API key** (no Apple ID password, no Match).

Everything sensitive comes from **GitHub repository secrets** / ENV. `Config/Secrets.xcconfig`
is gitignored and is reconstructed in CI from secrets on every run.

---

## 1. GitHub repository secrets to create

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Used by | What it is |
| --- | --- | --- |
| `SUPABASE_HOST` | ci + testflight | Supabase project host, e.g. `abcd1234.supabase.co` (no `https://`). |
| `SUPABASE_ANON_KEY` | ci + testflight | Supabase anon/publishable key (RLS-gated, safe in client). |
| `ASC_KEY_ID` | testflight | The App Store Connect API **Key ID** (e.g. `2X9R4HXF34`). |
| `ASC_ISSUER_ID` | testflight | The ASC API **Issuer ID** (a UUID, shown above the key list). |
| `ASC_KEY_P8` | testflight | The `AuthKey_XXXX.p8` file contents, **base64-encoded** (see below). |
| `DEVELOPMENT_TEAM` | testflight | Your Apple Developer **Team ID** (10 chars, e.g. `ABCDE12345`). |

> `SUPABASE_HOST` is the bare host because xcconfig treats `//` as a comment; the
> app prepends `https://` at runtime. This matches `Config/Secrets.example.xcconfig`.

### Base64-encoding the `.p8`

```bash
# macOS
base64 -i AuthKey_2X9R4HXF34.p8 | pbcopy
# Linux
base64 -w0 AuthKey_2X9R4HXF34.p8
```

Paste the result as the value of `ASC_KEY_P8`. The Fastfile decodes it
(`is_key_content_base64: true`).

---

## 2. Generate an App Store Connect API key (one-time, on the portal)

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com/) with an
   **Account Holder / Admin** account.
2. Go to **Users and Access → Integrations → App Store Connect API** (Team Keys).
3. Click **Generate API Key** (or **+**). Name it e.g. `injectbuddy-ci`, role
   **App Manager** (sufficient to upload builds).
4. Copy the **Issuer ID** (top of the page) → `ASC_ISSUER_ID`.
5. Note the new key's **Key ID** → `ASC_KEY_ID`.
6. **Download the `.p8` file** — Apple lets you download it **once**. Store it
   safely, then base64-encode it → `ASC_KEY_P8`.

---

## 3. Create the app record (one-time, a human must do this)

The pipeline uploads builds; it does **not** create the app listing. Before the
first TestFlight run:

1. In the [Apple Developer portal](https://developer.apple.com/account/resources/identifiers/list),
   register an **App ID / bundle identifier** = `com.injectbuddy.ios` (Explicit),
   enabling any capabilities the app needs.
2. In [App Store Connect](https://appstoreconnect.apple.com/apps) → **Apps → +
   → New App**: platform iOS, bundle ID `com.injectbuddy.ios`, set a name + SKU +
   primary language.
3. Make sure your account has accepted the latest **Apple Developer Program
   License Agreement** (uploads fail until it's accepted).

---

## 4. Signing model used by CI

The simplest reliable path, and the one wired up here, is **automatic signing
with the App Store Connect API key**:

- `build_app` runs with `-allowProvisioningUpdates` and `DEVELOPMENT_TEAM` set
  from the `DEVELOPMENT_TEAM` secret, `CODE_SIGN_STYLE=Automatic`.
- Because an ASC API key is provided, Xcode can create / fetch the App Store
  distribution provisioning profile and signing certificate on the fly — no Match
  repo and no manually uploaded `.p12`/`.mobileprovision`.

**What you must set up for this to work:**

- A **distribution signing certificate** must exist for the team. The first time
  automatic signing runs on a fresh runner it can create one via the API key, but
  Apple limits the number of distribution certs per account — if you already have
  one, that's fine; if creation is blocked, create an **Apple Distribution**
  certificate once in the portal.
- The `com.injectbuddy.ios` App ID and the App Store Connect app record (sections
  2–3) must already exist.

If automatic provisioning proves flaky on CI (it occasionally is), switch to
**manual signing**: create an *App Store* provisioning profile + distribution
certificate, store them as additional secrets, import them into a temporary
keychain in the workflow, and set `CODE_SIGN_STYLE=Manual` with explicit
`PROVISIONING_PROFILE_SPECIFIER` / `CODE_SIGN_IDENTITY` in `build_app`. That is
more moving parts; start with automatic and only switch if needed.

---

## 5. Running it

- **CI** runs automatically on push / PR to `main`.
- **TestFlight**: push a tag (`git tag v1.0.0 && git push origin v1.0.0`) or
  trigger **Actions → TestFlight → Run workflow**.
- The build number is set to `max(latest TestFlight build + 1, GitHub run number)`
  so it always moves forward.
