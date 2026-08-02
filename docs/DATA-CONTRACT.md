# Data contract — what we ask of a person, and what the database will accept

**Authoritative for all three clients: the web app, iOS and Android.** Where this document and a
client disagree, this document is right and the client is a bug.

Owner's instruction, 2026-08-03: *"we need clear database rules, that the webapp ios and android
will talk to… what are the universal things we will ask of people that goes into the database…
just set it so no one will ever have a failure."*

The enforcement point is **the database**, not any client. That is deliberate. iOS writes straight
to PostgREST and never calls the web API, so a rule that lives only in an API route is a rule iOS
does not have. Fix it once at the database and no client can be the one that gets it wrong — the
same reasoning that put the protocol dedup in a unique index rather than in either client.

---

## 1. The two rules everything else follows from

**1. Storage is always metric.** `weight_kg` and `height_cm` hold the truth, in kilograms and
centimetres, always, for every user, regardless of what they are looking at.

**2. `preferred_*_unit` is display only.** Switching to pounds converts on the way out and back. It
changes what the user sees. It never changes what is stored, and it never changes what the range
constraints mean — 20–500 always means kilograms.

Conversions, and these exact constants:

```
lbToKg     = v / 2.2046226218
kgToLb     = v * 2.2046226218
inchesToCm = v * 2.54
cmToInches = v / 2.54
```

**Do not round on the way in.** A user who enters 180 lb must get 180 lb back, not 179.9. Round for
display, never for storage.

## 2. `public.profiles` — the personalisation columns

| Column | Type | Null | Default | Allowed |
|---|---|---|---|---|
| `nickname` | text | yes | null | any |
| `weight_kg` | numeric | yes | null | **null, or 20–500** |
| `height_cm` | numeric | yes | null | **null, or 80–250** |
| `timezone` | text | yes | null | IANA name, or null — **see §4** |
| `preferred_weight_unit` | text | **no** | `kg` | `kg` \| `lb` |
| `preferred_height_unit` | text | **no** | `cm` | `cm` \| `ft` |
| `preferred_dose_unit` | text | **no** | `auto` | `auto` \| `mg` \| `mcg` \| `units` |
| `logging_interests` | text[] | **no** | `{}` | `hormones` \| `steroids` \| `peptides` \| `glp1` |
| `onboarding_completed_at` | timestamptz | yes | null | set **once**, on completion only |
| `subscription_tier` | text | **no** | `free` | `free` \| `pro` |
| `biological_sex` | text | yes | null | `male` \| `female` |
| `role` | text | **no** | `user` | `user` \| `admin` |

**The four NOT NULL columns must never be written null.** Steps in a wizard can be skipped; a
skipped step writes the **default**, not a null.

**`onboarding_completed_at` is stamped only by the onboarding wizard, never by a settings save.**
That is what makes it safe to build a settings surface before a wizard exists — the settings page
cannot accidentally mark someone as onboarded.

### Constraints as they now exist in production

Applied 2026-08-03. Verified against all 91 live rows first: **zero violated any of them**, so this
was additive and nothing was rewritten. Nothing was dropped.

| Constraint | Definition |
|---|---|
| `profiles_weight_kg_range_check` | `weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 500)` |
| `profiles_height_cm_range_check` | `height_cm IS NULL OR (height_cm >= 80 AND height_cm <= 250)` |
| `profiles_preferred_weight_unit_check` | `IN ('kg','lb')` |
| `profiles_preferred_height_unit_check` | `IN ('cm','ft')` |
| `profiles_preferred_dose_unit_check` | `IN ('auto','mg','mcg','units')` |
| `profiles_biological_sex_check` | `IN ('male','female')` — pre-existing |
| `profiles_subscription_tier_check` | `IN ('free','pro')` — pre-existing |
| `profiles_role_check` | `IN ('user','admin')` — pre-existing |
| `profiles_height_cm_check` | `height_cm IS NULL OR (> 0 AND < 300)` — pre-existing, **left in place deliberately** |

The pre-existing `profiles_height_cm_check` allows 0–300 and is now subsumed by the stricter 80–250
range. It was kept rather than replaced because dropping it was not authorised and it costs nothing
— the narrower constraint governs.

## 3. Why the unit columns needed this

Their allowed values were previously enforced **only** inside the web API route, which iOS bypasses
entirely. Three spellings of one value already exist in the web codebase: the database and API
accept `'lb'`, but `PersonalisationForm` writes `'lbs'` into localStorage and `MetricsPanel` uses
`'lbs'` internally and translates at both boundaries. Any surface that forgets one translation
writes `'lbs'` into the column, and until now nothing stopped it.

Nothing is corrupt today — all 91 rows hold `kg` / `cm` / `auto`. This closes the door before
anyone walks through it, which matters because the iOS personalisation surface that writes these
columns is about to be built.

---

## 4. Open defects on the WEB side — documented here, not fixed here

These are live defects in the shipped web app. They are recorded so iOS and Android do not inherit
them and so whoever owns the web app can fix them. **None are iOS work.**

### 4.1 Saving personalisation silently fails for almost every user

**90 of 91 profiles have `timezone = NULL`, and `/api/profile/personalisation` rejects null
timezone.** Every save is a read-modify-write that re-posts the whole profile, so it returns 400 on
a field the user never touched. **The UI shows "✓ Saved" because the response is never inspected.**

This is the single biggest "failure" in the system and no constraint fixes it — it is the API being
stricter than reality. Two options, and the first is better:

1. **Accept null timezone**, treat it as "not set", and resolve it lazily from the browser or device
   when one is needed. Null is the norm here, not an error state.
2. Backfill every profile with a resolved timezone and keep the API strict. Riskier — it guesses on
   behalf of 90 users.

**Until this is fixed, iOS must not route personalisation writes through the web API.** Write direct
to PostgREST, where the constraints in §2 now hold the line.

### 4.2 Height had three different valid ranges

Database allowed 0–300. `/api/profile` allowed 0–300. `/api/profile/personalisation` allowed 80–250.
A height of 70 cm saved through the first route was legal — and then that user **could never save
personalisation or metrics again**, permanently, because every read-modify-write POST failed
validation on a field they had not touched.

**The database side is now closed** (80–250, §2). The web routes should be aligned to the same
numbers so all three layers agree.

### 4.3 Metrics destroys `preferred_dose_unit = 'auto'`

The column's default *is* `auto`, but `MetricsPanel` types its state as `mg | mcg | units`, falls
back to `mg`, ignores `auto` on load and posts whatever it holds. **A user who chose "Automatic"
during personalisation and later saves Metrics is silently switched to `mg`.**

The database now rejects values outside the four-value set, but it cannot tell an intentional `mg`
from a destroyed `auto`. This one needs the client fixed.

### 4.4 Billing ignores `subscription_tier`

The column exists, is NOT NULL, and *is* read elsewhere — the `vip` badge checks `=== 'pro'`. But
`BillingPanel` hardcodes `"Free"`. **A paying user is shown "Free".** iOS should read the column,
not copy the panel.

### 4.5 Inline `category` editing corrupts the column

The database stores the slug (`'trt'`); the table maps it for display (`'Hormone'`); the inline
editor is bound to the **mapped display string** and PATCHes that back. After one edit the column
holds `'Hormone'`, and on reload the lookup misses and falls through to the raw value — so it still
renders, masking the corruption while breaking the category filter and every slug-based consumer.

---

## 5. iOS today — where it diverges from this contract

**The iOS Settings screen does not implement personalisation at all.** `SettingsScreen.swift` has a
Preferences section with `Units` and `Syringe scale`, and both persist to **`UserDefaults` on the
phone**. Neither touches `profiles`.

It is also a different shape from the contract. iOS models units as a single `UnitSystem` enum —
`metric | imperial` — while the contract has three independent columns. They cannot represent each
other: a user who set `kg` + `ft` + `mcg` on the web has a combination iOS cannot display, and a
user who picks "Imperial" on iOS changes nothing in the database.

**When the personalisation surface is built**, `UnitSystem` is replaced by the three columns, not
mapped onto them. A one-toggle model is not a lossy version of the contract — it is a different
contract.

`SyringeScale` (`u100 | u40`) is genuinely local and has no database column. It stays in
`UserDefaults`.
