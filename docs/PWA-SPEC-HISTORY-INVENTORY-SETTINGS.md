# PWA spec — dose history, inventory, and the Settings sub-tabs

Extracted 2026-08-02 from the PWA source (Windows box) **and the live Supabase project**,
neither of which the Mac can reach. Covers T12, T13, T16 and — most urgently — the
Personalisation contract that T9 is coupled to.

Every column shape below came from querying the running database, not from reading a doc.
Row counts and sample rows are real, with user ids and other identifying values replaced by
placeholders.

> **`FILE_MAP.md` in the PWA repo is stale.** It describes the old static marketing site and
> says the app lives in `public/app.js`. **None of these three features are in `app.js`.** The
> real dashboard is React/TSX under `components/account/`. Ignore that file.

> **`lib/account-schedule.ts:1-6` states the opposite of reality**: *"there is NO real dose
> history or inventory in the DB yet"*. Both tables exist and hold real rows. Do not trust
> that header when porting.

**Read §D before building anything here.** It lists eighteen places where the UI and the
database disagree — several are live bugs, and at least four would be inherited silently by a
faithful port.

---

## A. Dose history

### A1. `dose_log` — real shape

RLS enabled; policy `dose_log_owner_all` (ALL): `(SELECT auth.uid()) = user_id`, same
`WITH CHECK`.

| # | Column | Type | Null | Default |
|---|---|---|---|---|
| 1 | `id` | `uuid` | NO | `gen_random_uuid()` |
| 2 | `user_id` | `uuid` | NO | — |
| 3 | `protocol_id` | `uuid` | NO | — |
| 4 | `dosed_on` | `date` | NO | `CURRENT_DATE` |
| 5 | `draw_ml` | `numeric` | YES | — |
| 6 | `site` | `text` | YES | — |
| 7 | `created_at` | `timestamptz` | NO | `now()` |
| 8 | `scheduled_on` | `date` | YES | — |
| 9 | `protocol_label` | `text` | YES | — |
| 10 | `compound_label` | `text` | YES | — |
| 11 | `category` | `text` | YES | — |
| 12 | `dose_label` | `text` | YES | — |
| 13 | `updated_at` | `timestamptz` | NO | `now()` |
| 14 | `injection_time` | `time` | NO | `'12:00:00'` |
| 15 | `injection_timezone` | `text` | YES | — |
| 16 | `injected_at` | `timestamptz` | YES | — |

- PK on `id`; FK `user_id → auth.users(id)` CASCADE; FK `protocol_id → saved_dosages(id)` CASCADE.
- UNIQUE on **`(protocol_id, dosed_on)`** — note `user_id` is *not* in the key.
- No CHECK constraints beyond NOT NULLs. **`draw_ml` has no non-negative check.**

### A2. What the live data actually looks like

**14 rows across 4 users.** Five things in it that change how you build:

1. **`draw_ml` comes back from PostgREST as a string** (`"0.240"`), not a number — numerics
   always serialise as strings. Decode as `Decimal`/`String`, **not** `Double`, or you crash
   on parse. This applies to every numeric column in this document.
2. **`injection_timezone` and `injected_at` are `null` in all 14 rows.** They were added by
   migration `20260729094658_...` and in practice are only written by the *edit* path, never
   the create path. Do not assume they are present.
3. **`injection_time` is `'12:00:00'` on every row** — the default. No user has ever set one.
4. **`scheduled_on ≠ dosed_on` is common**, in both directions — doses taken late *and* early.
   The UI must not assume ordering.
5. One live `protocol_label` reads `"0mg/wk · Testosterone Acetate"` — snapshotted from a
   protocol whose config had `mgWeek = 0`. **Render it verbatim.** These labels are immutable
   snapshots by design; "fixing" one at render time would misreport what was actually taken.

### A3. How the web reads it

`app/api/dose-log/route.ts:20-45`:

```ts
const PIN_COLUMNS = 'id, protocol_id, dosed_on, scheduled_on, injection_time, injection_timezone, injected_at, draw_ml, site, protocol_label, compound_label, category, dose_label, created_at, updated_at'

let query = supabase.from('dose_log').select(PIN_COLUMNS)
  .eq('user_id', user.id)
  .order('dosed_on', { ascending: false })
if (protocolId) query = query.eq('protocol_id', protocolId)
if (since)      query = query.gte('dosed_on', since)
```

- Optional `?protocol_id=uuid`, optional `?since=YYYY-MM-DD` (inclusive).
- Sort `dosed_on DESC`, **no tiebreaker** — same-day rows return in arbitrary order. Add one
  on iOS (`created_at`) or the list reshuffles between loads.
- **No pagination at all** — no `.range()`, no `.limit()`. Every row fetched on dashboard
  mount. Fine at 14 rows; **iOS should page**, because this does not scale.
- **No date grouping.** The web renders a flat table.
- All filtering, sorting and searching happens **in memory** over the full array.

Sortable keys: `dosed_on | scheduled_on | protocol_label | compound_label | category |
dose_label | draw_ml | site`. Default `dosed_on` desc; a new column defaults to `asc` except
`dosed_on`, which defaults to `desc`.

Writes: `POST` upserts on `(protocol_id, dosed_on)` — idempotent per protocol-day.
`PATCH` by `id` + `user_id`. `DELETE ?protocol_id=&dosed_on=`.

### A4. What renders

Rows are **resolved** before render — DB values backfilled from the live protocol, and the raw
slug mapped to a display name:

```ts
const CATEGORY: Record<string, string> = {
  trt: 'Hormone', eod: 'Hormone', hcg: 'Hormone',
  semaglutide: 'GLP-1', tirzepatide: 'GLP-1', retatrutide: 'GLP-1',
  steroid: 'Steroid', peptide: 'Peptide', bpc157: 'Peptide', bpc157blend: 'Peptide', blend: 'Peptide',
}
protocol_label: row.protocol_label || p?.label || 'Unknown protocol',
compound_label: row.compound_label || p?.compound || '—',
category:       CATEGORY[row.category || p?.calc || ''] || row.category || p?.calc || 'Other',
dose_label:     row.dose_label || p?.doseLabel || '—',
```

Header: `Dose history` + `{n} logged dose(s)` + `Clear filters`.

**Future/History toggle.** "Future" does **not** query the DB — it synthesises rows from the
derived schedule for tomorrow through +2 months, `id = "future-<protocolId>-<YYYY-MM-DD>"`,
`future: true`. Future rows are read-only except "move to another date", which is
**session-only and never persisted**. Decide deliberately whether iOS reproduces that; a move
that silently evaporates is a poor fit for a phone.

Desktop table, 9 sortable columns: Date taken (`dosed_on`, raw `YYYY-MM-DD`, **not
localised**), Scheduled, Protocol, Compound, Category, Dose, Draw volume
(`draw_ml == null ? '—' : "{draw_ml} mL"`), Injection site, Action.
`const clean = v => v?.trim() || '—'`.

Inline edit: dates → `type="date"`; `draw_ml` → `number min=0 step=0.001`; `site` → select
restricted to the protocol's rotation track — `SITES_IM` = L/R Glute, L/R VG, L/R Quad, L/R
Delt; `SITES_SUBQ` = Abdomen L/R, L/R Love handle, L/R Thigh — with `No sites available` for
orals.

Mobile card list: `dose_label` bold, then `"{dosed_on} · {injection_time.slice(0,5)}"`, a tick
for logged rows, chevron to a detail sheet. The sheet's Save appears **only when dirty**, and
on save also computes `injection_timezone` and a zoned `injected_at`.

**Empty state — fix this on iOS.** Both table and mobile show *"No {future|logged} doses match
these filters."* There is **no distinct never-logged-anything state**, so a brand-new user is
told their nonexistent data doesn't match filters they never set. Add a true zero-state.

---

## B. Inventory

Tab renders `<SupplyAlert />` then `<MySupply />`, in that order.

### B1. `vial_inventory` — real shape

**2 rows, 2 users.** RLS enabled; `vial_inventory_owner_all` (ALL) on `user_id`.

| # | Column | Type | Null | Default |
|---|---|---|---|---|
| 1 | `id` | `uuid` | NO | `gen_random_uuid()` |
| 2 | `user_id` | `uuid` | NO | — |
| 3 | `protocol_id` | `uuid` | NO | — |
| 4 | `vial_count` | `integer` | NO | `1` |
| 5 | `vial_ml` | `numeric` | NO | — |
| 6 | `concentration` | `numeric` | YES | — |
| 7 | `unit` | `text` | YES | — |
| 8 | `stocked_on` | `date` | NO | `CURRENT_DATE` |
| 9 | `created_at` | `timestamptz` | NO | `now()` |
| 10 | `updated_at` | `timestamptz` | NO | `now()` |
| 11 | `color` | `text` | YES | — |

- UNIQUE on **`(user_id, protocol_id)`** — one stock row per protocol.
- CHECK `vial_count > 0`, CHECK `vial_ml > 0`. None on `concentration` or `unit`.
- `color` is null on both live rows.

Read endpoint has **no sort and no pagination**. `POST` upserts on `(user_id, protocol_id)`.

### B2. Depletion logic

**Remaining supply is never stored.** It is always `stock − consumed`.

```ts
export const LOW_DOSES = 3      // a vial is "low" at 3 or fewer doses left
export const BUD_DAYS = 28      // beyond-use period for a punctured multi-dose vial —
                                // a CONVENTION, not a universal rule. UI copy must never
                                // state it as a medical instruction.
export const BUD_WARN_DAYS = 7
```

```ts
remainingMl(inv) = max(0, round(inv.count * inv.vialMl - inv.usedMl))
totalMl(inv)     = round(inv.count * inv.vialMl)
dosesLeft(inv,v) = v > 0 ? floor(remainingMl(inv) / v) : 0
daysOfSupply(p,inv) = p.vol > 0 ? round(dosesLeft(inv, p.vol) * (p.freqDays || 1)) : 0

// Consumed mL = (count of logged dose-days on/after stockedOn) × draw volume.
// A dose logged BEFORE the stock date belongs to an earlier supply and is not counted.
usedMlFromDoneDays(doneDayIsos, stockedOn, drawVol)
```

Puncture date = the **earliest** dose logged on/after `stocked_on`.
`budDaysLeft = 28 − days since that date`, or `null` until a dose has been logged.

**The alert fires when `dosesLeft <= 3` OR `budDaysLeft <= 7`.**
Sort is worst-first: an expired vial outranks an empty one.

Protocols with `vol == null || vol <= 0` are **skipped entirely** — orals and blends are
unmeterable and simply absent.

### B3. What renders

**`SupplyAlert`** returns `null` when nothing is low, so the banner vanishes entirely.
Heading: `Discard and replace` if any vial is expired → else `Out of supply` if any severe →
else `Needs attention`. Red when severe, gold otherwise. Per vial: label, status text, and a
5px `role="progressbar"` with `aria-valuenow={pctLeft}` and
`aria-label="{label}: {pctLeft}% of the vial remaining"`.

> The component's header comment states the accessibility contract explicitly: **every state
> must be stated in text; colour is reinforcement only.** That matches the iOS rule already in
> `BOARD.md` (over-capacity uses icon *and* text). Keep it.

Footer copy, verbatim:
> Counted from your logged doses. A vial is flagged at 3 doses or fewer, and 28 days after the
> first dose drawn from it — a common discard convention for punctured multi-dose vials, not
> medical advice. Update stock in Saved vials.

**`MySupply`** — section "Saved vials" with a count pill, then a card deck. Duplicate titles
de-duped (`Test E`, `Test E (1)`). Per card: `"{left} dose(s)"`, then
`"~{days}d left · {rem}/{total} mL"`. Badge precedence: BUD (`discard` red at `<= 0`,
`{n}d to discard` gold at `<= 7`) → `low` gold at `<= 3` → `in stock` green. Trailing CTA card
`Add vials` / `Track a vial`.

> **`MySupply` returns `null` when nothing is meterable.** Combined with `SupplyAlert` also
> returning null, **the entire inventory tab can render completely blank** — with no empty
> state and no way to add a first vial — for any user whose protocols are all oral or blends.
> Fix this on iOS; do not port it.

---

## C. Settings — the six sub-tabs

`SUB_TABS = account | profile | personalisation | badges | metrics | billing`, default
`account`, deep-linkable by hash.

### C1. `profiles` — real shape

RLS enabled: `profiles_self_read` (SELECT), `profiles_self_update` (UPDATE),
`profiles_self_insert` (INSERT). **No DELETE policy** — deletion goes through a service-role
admin route, so a direct client delete fails silently.

| # | Column | Type | Null | Default | CHECK |
|---|---|---|---|---|---|
| 1 | `id` | `uuid` | NO | — | PK, FK → `auth.users(id)` CASCADE |
| 2 | `display_name` | `text` | YES | — | |
| 3 | `created_at` | `timestamptz` | NO | `now()` | |
| 4 | `date_of_birth` | `date` | YES | — | |
| 5 | `biological_sex` | `text` | YES | — | `IN ('male','female')` |
| 6 | `subscription_tier` | `text` | NO | `'free'` | `IN ('free','pro')` |
| 7 | `upload_limit_override` | `integer` | YES | — | `NULL OR >= 0` |
| 8 | `role` | `text` | NO | `'user'` | `IN ('user','admin')` |
| 9 | `is_founder` | `boolean` | NO | `false` | |
| 10 | `showcase_badges` | `text[]` | NO | `'{}'` | |
| 11 | `height_cm` | `numeric` | YES | — | `NULL OR (> 0 AND < 300)` |
| 12 | `timezone` | `text` | YES | — | |
| 13 | `nickname` | `text` | YES | — | |
| 14 | `weight_kg` | `numeric` | YES | — | **none** |
| 15 | `preferred_weight_unit` | `text` | NO | `'kg'` | **none** |
| 16 | `preferred_height_unit` | `text` | NO | `'cm'` | **none** |
| 17 | `preferred_dose_unit` | `text` | NO | `'auto'` | **none** |
| 18 | `logging_interests` | `text[]` | NO | `'{}'` | **none** |
| 19 | `onboarding_completed_at` | `timestamptz` | YES | — | |

**A profile row always exists.** Trigger `handle_new_user()` (SECURITY DEFINER) inserts one at
signup with `display_name` from metadata or the email local-part. So **every NOT NULL
personalisation column is already populated by its DB default before onboarding runs** — iOS
never needs to insert a profile row, only update one.

**Live distribution across 89 profiles:** `display_name` 89/89 · `onboarding_completed_at`
**1** · `nickname` 1 · `timezone` **1** · `logging_interests` non-empty 1 · `weight_kg` 1 ·
`height_cm` 1.

> Personalisation is effectively greenfield — exactly one user has ever completed it.
> **Design for the null case everywhere.** It is not an edge case here, it is the norm.

### C2. Personalisation — the contract T9 must mirror

`components/account/PersonalisationForm.tsx`, two modes from one component:
- **Settings mode** — all five steps stacked in cards, one `Save changes`.
- **Onboarding mode** — one step at a time, Back/Continue, 5-segment progress bar, final
  button `Open my dashboard`.

```ts
export const LOGGING_INTERESTS = ['hormones', 'steroids', 'peptides', 'glp1'] as const
export const DEFAULT_PERSONALISATION = {
  nickname: null, weight_kg: null, height_cm: null, timezone: null,
  preferred_weight_unit: 'kg', preferred_height_unit: 'cm', preferred_dose_unit: 'auto',
  logging_interests: [], onboarding_completed_at: null,
}
export const lbToKg     = (v) => v / 2.2046226218
export const kgToLb     = (v) => v * 2.2046226218
export const inchesToCm = (v) => v * 2.54
export const cmToInches = (v) => v / 2.54
```

#### Step 0 — "Make the dashboard yours" · eyebrow "How should we greet you?"

| Field | Control | Default | Validation | Column |
|---|---|---|---|---|
| Nickname *(optional)* | text, `maxLength 60` | `''` | server: trimmed, `> 60` → 400 "Nickname must be 60 characters or fewer" | `nickname` (nullable) |

Helper: *"Leave it blank and we'll use the name already on your account."*
**Skipped writes SQL `NULL`**, not `''` — the server does `nickname || null`.

#### Step 1 — "Choose how numbers are shown" · eyebrow "Your defaults"

| Field | Control | Options | Default | Column(s) |
|---|---|---|---|---|
| Measurements | 2-up segmented, composite value `` `${weight}/${height}` `` | `kg/cm` → Metric · `kg · cm`; `lb/ft` → Imperial · `lb · ft/in` | `kg/cm` | writes **two** columns: `preferred_weight_unit`, `preferred_height_unit` |
| Dose display | 4-up segmented | `auto` Automatic · *Best unit for each dose*; `mg` · *Milligrams*; `mcg` · *Micrograms*; `units` · *Syringe units* | `auto` | `preferred_dose_unit` |

> **There is no way to choose kg + ft, or lb + cm.** The columns are independent and the DB
> would accept the mix; the UI cannot produce it. Build iOS the same way unless the API
> changes too — a mixed pair from iOS would be a shape the web can't render.

All three are NOT NULL. **A skipped step still writes** — the form always posts current state.
Effective skip values: `kg`, `cm`, `auto`.

#### Step 2 — "Add your current measurements" · eyebrow "Optional baseline"

| Field | Control | Range (client) | Range (server) | Column |
|---|---|---|---|---|
| Weight *(optional)* | number, decimal, unit suffix, `step 0.1` | 20–500 kg / 44–1102 lb | `< 20 \|\| > 500` kg → 400 | `weight_kg` (nullable, **no DB CHECK**) |
| Height — cm | number, `min 80 max 250 step 0.1` | 80–250 | `< 80 \|\| > 250` → 400 | `height_cm` |
| Height — ft/in | two numbers: feet `min 2 max 8`, inches `min 0 max 11.9 step 0.1` | — | as above, post-conversion | `height_cm` |

**Storage is always canonical metric**; imperial is a display transform only.

> `round(value, 1)` is applied to the **displayed** imperial value, so a kg→lb→kg round trip is
> lossy. **Store the metric value you received; never re-derive it from the displayed
> imperial number.** This is how a weight silently drifts every time a user opens the screen.

Skipped → NULL for both. Safe; they are nullable.

#### Step 3 — "Keep every dose on the right day" · eyebrow "Local time"

| Field | Control | Default | Validation | Column |
|---|---|---|---|---|
| Default timezone | select of IANA ids, `_` rendered as space | stored value, else browser zone | non-empty, `<= 100` chars, must be accepted by `Intl.DateTimeFormat` | `timezone` (nullable) |

The current zone is **prepended** if the platform list lacks it, so a stored selection is never
silently lost. On iOS use `TimeZone.knownTimeZoneIdentifiers` and apply the same rule.

Helper: *"Detected from this device. It keeps injection times and dose days accurate when you
backdate a log."*

> **Effectively mandatory despite being nullable** — the API returns 400 on a null or absent
> timezone, so any save without one fails outright. See mismatch #10, and #2 which it causes.

#### Step 4 — "What are you most interested in logging?" · eyebrow "Your focus"

| Field | Control | Options | Default | Column |
|---|---|---|---|---|
| Logging interests | multi-select toggle grid, `aria-pressed` | `hormones` **Hormones** · *TRT, HRT and supporting protocols* · `steroids` **Steroids** · *Cycles, compounds and injection schedules* · `peptides` **Peptides** · *Reconstituted peptides and site rotation* · `glp1` **GLP-1** · *Weekly dosing and titration tracking* | `[]` | `logging_interests` `text[]` NOT NULL |

Order is preserved as tapped, not canonicalised.

> **This is the only mandatory field in the entire flow.** Blocking client-side:
> *"Choose at least one thing you want to log."* It blocks the settings-mode save too.

#### Submit

```ts
POST /api/profile/personalisation
{ nickname, weight_kg, height_cm, timezone,
  preferred_weight_unit, preferred_height_unit, preferred_dose_unit,
  logging_interests, complete: onboarding }
```

Server upserts on `id`, and stamps `onboarding_completed_at` **only when `complete === true`**.
Settings-mode and Metrics saves never set it — so it is a true "did onboarding" flag and is
safe for iOS to gate the onboarding sheet on.

Device-local mirrors written on success: `ib_unit_weight` (**`'lbs'`**, see mismatch #4),
`ib_unit_height`, and `ib_unit_dose` (removed when `auto`).

### C3. The other five tabs

**Account** — display name (**writes twice**: `auth.updateUser({data:{full_name}})` *and*
`profiles.display_name`), email change via auth, password (new + confirm; `< 8` chars
rejected; no current-password field despite dead state for one), data export, delete account
(type `DELETE`, then a service-role route). OAuth-only accounts show *"Your account uses Google
sign-in. Password change is not available."* No loading state — the password form flashes
before the OAuth check resolves.

**Profile** — accent colour (12 presets stored **without** `#`, native picker, hex field
validated `/^[0-9a-fA-F]{0,6}$/` committing at 6 chars) → `user_preferences` upsert, plus
localStorage and an `ib_theme` cookie, then **reloads the page 800 ms after save**. Avatar:
jpeg/png/webp, max 5 MB, storage bucket `avatars` at `{userId}/avatar.{ext}`, URL written
**only** to auth `user_metadata.avatar_url` — there is no `profiles.avatar_url`. Removal does
not delete the storage object. Theme is still persisted but the selector was removed when dark
mode was retired; **iOS is light-only and must stay that way**. Accent save has **no error
path at all**.

**Badges** — `GET /api/badges` → progress ladders in family order `tenure, streak, consistency,
doses, protocols, cycles, bloodwork`, plus a Special grid. Pin up to 5, optimistic and
fire-and-forget; failures are swallowed. Dates format `2 Aug 2026`.

**Metrics** — three segmented rows (weight unit, height unit, dose unit) that overlap
Personalisation step 1. **Read-modify-write**: GET the whole profile, override three fields,
POST with `complete: false`. See mismatches #2 and #3 — this panel is currently broken for
essentially every user.

**Billing & Plan** — entirely static. Hardcoded "Free", hardcoded "Active" pill, hardcoded
inclusions, a permanently disabled "Notify me when available". No fetch, no writes, no Stripe.
See mismatch #1.

---

## D. UI ↔ database mismatches

Ordered by how likely each is to produce a bug in the iOS build. **Items 1–4, 6 and 8 are live
defects in the shipped web app**, not just porting hazards — worth raising with the web side
separately.

1. **Billing ignores `subscription_tier` entirely.** The column exists, is NOT NULL, and *is*
   read elsewhere (the `vip` badge checks `=== 'pro'`). `BillingPanel` hardcodes `"Free"`.
   **A paying user is shown "Free".** iOS should read the column.

2. **Metrics silently no-ops for almost every user — and still reports success.** The panel
   spreads the fetched profile into its POST. The API **requires a valid `timezone`**, and
   **88 of 89 live profiles have `timezone = NULL`**. So the save returns 400, nothing is
   written, and the UI shows "✓ Saved" because the response is never inspected.

3. **Metrics cannot express `preferred_dose_unit = 'auto'`, and destroys it.** The column's
   default *is* `'auto'`, but Metrics types its state as `mg | mcg | units`, falls back to
   `mg`, ignores `auto` on load, and posts whatever it holds. **A user who chose "Automatic"
   in Personalisation and later saves Metrics is silently switched to `mg`.**

4. **`'lb'` vs `'lbs'` — three spellings of one value.** DB and API accept only `'lb'`.
   `PersonalisationForm` writes `localStorage.ib_unit_weight = 'lbs'`. `MetricsPanel` uses
   `'lbs'` internally and translates at both boundaries. Any surface that forgets a
   translation writes `'lbs'` into the column — **and there is no CHECK constraint to stop
   it.**

5. **The unit-preference columns have no CHECK constraints.** The enum is enforced *only* in
   the API route. iOS writing directly to PostgREST (which RLS permits) can store an arbitrary
   string and every consumer misbehaves. **Either route iOS through the API for these fields,
   or add the CHECKs.** Recommend adding the CHECKs — same reasoning as the dedup unique
   index: fix it once at the database and neither client can get it wrong.

6. **`height_cm` has three different valid ranges.** DB: `> 0 AND < 300`. `/api/profile`:
   `> 0 && < 300`. `/api/profile/personalisation`: `>= 80 && <= 250`. A height of 70 cm saved
   via the first is legal — and then the user **can never save Personalisation or Metrics
   again**, because every read-modify-write POST fails validation on a field they didn't
   touch. Live footgun.

7. **`weight_kg` has no DB constraint at all** while the API enforces 20–500 kg.

8. **Inline `category` editing corrupts the column.** The DB stores the slug (`'trt'`); the
   table maps it for display (`'Hormone'`); the inline editor is bound to the **mapped display
   string** and PATCHes that back. After one edit the column holds `'Hormone'`, and on reload
   the lookup misses and falls through to the raw value — so it still *renders*, masking the
   corruption while breaking the category filter and every slug-based consumer. Same latent
   issue for `protocol_label` / `compound_label` / `dose_label`, edited against
   resolved-with-fallback values rather than stored ones.

9. **Editing `dosed_on` can violate the unique key with no useful error.** `(protocol_id,
   dosed_on)` is UNIQUE; moving a dose onto an occupied day raises `23505`, caught by a generic
   handler and surfaced as "Could not save dose". iOS should pre-check or map the constraint
   name to real copy.

10. **`profiles.timezone` is nullable but the API treats it as required.** The default is
    `null`, the column is nullable, and POST 400s on null. The form papers over it with a
    browser default; a stricter client that sends the stored `null` back gets a 400. Root
    cause of #2.

11. **`dose_log`'s unique key omits `user_id`** while `vial_inventory`'s includes it. Safe
    today because `protocol_id` is owner-scoped through `saved_dosages`, but the two conflict
    targets are inconsistent.

12. **Depletion uses *derived* volume, not the stored `draw_ml`.** `usedMlFromDoneDays`
    multiplies the count of done days by the protocol's *current* `p.vol`, ignoring the
    `draw_ml` actually recorded per row. If a user edited a draw volume, or the protocol config
    changed, remaining supply and the low-supply alert are **wrong**.
    **Recommendation: iOS should prefer the stored per-row `draw_ml`.** This deliberately
    diverges from the web — flag it in `BOARD.md` when it ships so nobody "corrects" it back.

13. **`LOW_DOSES` is duplicated as a literal.** `SupplyAlert` imports the constant;
    `MySupply.tsx:59` hardcodes `<= 3`. Change one and the banner desyncs from the badges.

14. **`injection_timezone` / `injected_at` are written only on edit, never on create.** All 14
    live rows are null for both. Any iOS feature keyed on a real injection instant has no data
    to work with today.

15. **`lib/account-schedule.ts`'s header comment asserts the opposite of reality** — claims no
    real dose history or inventory exists in the DB. Both tables hold real rows.

16. **The inventory tab can render completely blank** — both components return `null` when
    nothing is meterable, with no empty state and no way to add a first vial.

17. **Two identity stores for name and avatar.** `display_name` is written to both
    `auth.user_metadata.full_name` and `profiles.display_name` and can drift. `avatar_url`
    lives *only* in `user_metadata`. `nickname` and `display_name` are separate columns with no
    reconciliation — **decide which one iOS greets the user with** and write it down.

18. **No DELETE policy on `profiles`.** Deletion works only via the service-role route.

---

## E. Not determinable — ask, don't infer

Per `CLAUDE.md`: these go here rather than getting a guess.

- **Whether `injection_timezone` / `injected_at` are meant to be written on create.** The API
  accepts them, the client never sends them, and no test or comment states the intent.
- **Whether `category` should hold the slug or the display name.** Live data says slug; the
  edit path writes display names. The intended contract is written down nowhere.
- **What a pro user should see in Billing.** The tier exists and gates a badge, but there is no
  billing integration in the repo at all.
- **Whether the absence of pagination on `/api/dose-log` is deliberate** (small data) or an
  oversight.
