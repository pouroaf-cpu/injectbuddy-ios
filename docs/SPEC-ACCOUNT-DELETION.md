# SPEC — Real account deletion on iOS

**Owner-directed, 2026-08-03:** *"build the real account deletion, that's on the PWA app as well so why not?"*
He is right — it exists and it works on the web. This spec is the web implementation read from source on
the Windows machine, plus the one architectural change iOS forces.

Ship-blocker. Apple requires an in-app deletion path for any app that creates accounts, and the current
dialog says deletion is unavailable. When this lands, that copy goes back to promising deletion — and the
promise becomes true, not before.

---

## 1. What the web actually does

`app/api/account/delete/route.ts`, `lib/account/user-data.ts`. Read them as the contract; this is a summary,
not a replacement.

> ### ⚠️ CORRECTED 2026-08-03 — THE SENTENCE BELOW USED TO SAY THE OPPOSITE, AND IT WAS WRONG IN THE DIRECTION THAT MADE IT INVISIBLE.
>
> **Provenance, because it explains how this survived into a second document.** The sentence was
> **transcribed from a comment in the web source**, not measured. It was true of nothing, but it read
> as authoritative — it was the *implementation's own* description of itself — so it was carried into
> this spec unexamined and became a second, corroborating-looking home for the same error. **That is
> the mechanism to watch for, not the fact.** §5.1: internally consistent code is not evidence; query
> the running system.
>
> This section quoted the web's own comment: *"there are no foreign keys from these tables to
> `auth.users`, so deleting the auth user does not cascade."*
>
> **Measured against `pg_constraint` on 2026-08-03: there are 22 foreign keys from `public` to
> `auth.users`, and almost everything cascades.** Twenty are `ON DELETE CASCADE`. Exactly two are
> `ON DELETE SET NULL` — `feedback.user_id` and `chat_messages.sender_id`.
>
> **This is why the gap survived for years.** Web deletions have looked correct *because* twenty
> tables clear themselves. Nobody had cause to doubt the comment, so nobody checked the only two
> things a cascade cannot reach:
>
> 1. **`feedback`** — `SET NULL`, so the row survives the auth-user delete **with its `email`
>    column intact**. A deleted user's email address persists indefinitely.
> 2. **STORAGE — not in the FK graph at all.** Nothing has ever cleared it but the explicit
>    `avatars` delete, and `blood-tests` and `progress-photos` are cleared by nothing.
>
> **The explicit deletes stay regardless.** A cascade is a property of a constraint someone can drop
> in a migration; a deletion that silently depends on an FK nobody restated breaks without a failing
> test. Enumerate, and name the mechanism against each entry (D7).

Some tables also lack a self-DELETE RLS policy, which is why the web uses the **service-role** client
with every delete filtered strictly to the caller's own id.

**Order, and it matters — children before parents:**

1. **Chat children.** Select the user's `chat_conversations` ids, then delete `chat_telegram_links` and
   `chat_messages` by `conversation_id`.
2. **Every plain `user_id` table**, and **any error throws** rather than being swallowed.
   **The web's `USER_ID_TABLES` is SIXTEEN; the live schema has NINETEEN.** Derive this list from
   `information_schema`, never transcribe it — copying a list that is already wrong gives the
   omission a second home and makes it look corroborated.
   `saved_dosages · protocols · peptide_protocols · cycles · cycle_items · vial_inventory · dose_log ·
   dose_history · injection_schedules · blood_tests · marker_values · user_preferences · user_badges ·
   user_active_days · notifications · chat_conversations`
   **⚠️ plus the three the web omits:** `body_metrics` · **`feedback`** · `email_verification_reminders`
3. **Suggestions**, keyed by `author_id` not `user_id`: `suggestion_comments`, then `suggestion_posts`.
4. **⚠️ `pending_dosages`, keyed by `email`** — a calculator result saved *before* signing up, so it
   has no `user_id` at all and nothing reaches it from a uid. The email comes from the verified
   token. Leaving it is the `feedback` problem with a different key.
5. **Files under `<uid>/` in THREE buckets — `avatars`, `blood-tests`, `progress-photos`.** The web
   route clears **`avatars` only**. **Best-effort — never block deletion on storage** — but the
   failures are reported, not swallowed, and logged server-side, because the client is about to lose
   its account and cannot be the durable record.
6. **`profiles`**, keyed by **`id`**, not `user_id`.
7. **The auth user itself.** This is what makes the login go away. If it fails, the whole thing fails.
8. Sign out, best-effort.

**Storage runs BEFORE `profiles` and before the auth user, deliberately.** The ordering decides which
failure is possible: files-first leaves a failure with the files gone and the account alive —
visible and retryable; account-first leaves the files orphaned with no authenticated caller left to
retry, which is the state the shipped web product is in today.

**`community_survey` is anonymous, is not linked to a user, and is never touched.** Nor is
`community_survey_throttle`, which is keyed by `submitter_hash`.

> **`lts_*` is excluded, with evidence, so it is not re-opened as an oversight.** Thirteen tables of
> a separate product (Last Tahi Standing) share this Postgres instance. Sharing a project looked like
> sharing an auth store; **it is not**. Measured 2026-08-03: `lts_profiles` has **no FK to
> `auth.users`**, **zero** of its 19 ids match an auth user, and all 19 carry a `pin_hash` — its own
> PIN identity. Deleting an InjectBuddy account does not touch an LTS account.

---

## 2. The one thing iOS cannot copy

**The web route is cookie-authenticated and holds a service-role key on the server.** iOS is a bearer-token
PostgREST client and **must never hold a service-role key** — a key in the binary is a key in every user's
hands.

**So: a Supabase Edge Function, `delete-account`, in the same project.**

- Caller sends its own user JWT. The function verifies it and derives `uid` **from the verified token,
  never from the request body.** A uid taken from the body is an any-user delete endpoint.
- The function then does exactly §1 with the service-role key, every delete filtered to that `uid`.
- Returns `{ ok: true }`, or a real error. **Never returns ok on partial failure.**

**Why not call the existing web route:** it is cookie-auth, which is the same reason `Core/Backend` talks to
PostgREST directly rather than to `/api/*`. Making iOS depend on the Next.js host would add a second
runtime dependency to the one flow that must not half-succeed.

**Drift is the hazard.** The table list now exists in two places. **Both files carry a comment naming the
other**, and `DATA-CONTRACT.md` records that adding a user-scoped table means updating both. If a table is
added to one and not the other, a deleted account leaves rows behind — which is a privacy failure, not a
bug.

---

## 3. The iOS surface

`SettingsScreen`. Replace the current sign-out-only path.

- **Two steps, not one.** The row opens a confirm sheet that says plainly what will be deleted — protocols,
  dose log, cycles, blood tests, preferences — and that it cannot be undone. The destructive action is the
  second tap, and it is not the default button.
- **Do not obstruct it.** Apple requires deletion to be reachable, not buried behind support contact or a
  survey. Two taps and a clear label is the limit.
- **Offline:** gated like every other write, per the existing `NetworkMonitor` handling. A deletion attempted
  offline says so and changes nothing.
- **D9 applies and this is the sharpest case of it in the app.** Never show "deleted" on anything but a
  confirmed `ok`. A failed deletion that reads as success leaves a user believing their health data is gone
  when it is not.
- **On success:** clear the Keychain session and all local state, then return to the auth gate.
- The debug auth bypass makes one sign-in attempt per launch, deliberately, so signing out stays real and
  this flow stays testable.

---

## 4. Verification — and the one hazard that outranks everything else here

**DO NOT TEST THIS ON THE QA ACCOUNT.** It holds every row this project's evidence rests on, including the
first iOS-written `dose_log` row. Deleting it is unrecoverable and it would take the day's evidence with it.

- **Create a throwaway account** and seed it: one saved protocol, one logged dose, at minimum. Better if it
  also has a cycle and a preference row, so more than one table is proven.
- **Record its uid before deleting.** Then, after: query **every surface — 19 tables + `profiles` +
  both `suggestion_*` + `pending_dosages` by email + both chat children + all THREE bucket prefixes**
  — for that uid and confirm **zero rows in each**, table by table, printed, not summarised. A count
  over one table is not evidence about nineteen.
- **⚠️ QUERY `feedback` BY EMAIL, NOT ONLY BY UID.** Its FK is `SET NULL`, so **by uid it reads zero
  whether the row was deleted or merely nulled** — the uid is the thing the constraint nulls. The
  email query is the only check that can tell those two states apart, and telling them apart is the
  whole point. A verification that cannot distinguish them passes identically over the bug.
- **Confirm the auth user is gone** and that its credentials no longer sign in. Replay its
  pre-deletion access token too.
- **Confirm the QA account still has its rows** — same before/after id-set comparison used for `unlogDose`.
  That is the control, and it is the one that catches a filter that was not filtering.
- **Check the GLOBAL row counts return to their pre-test values.** Per-surface zeros prove the
  throwaway is gone; **the globals are what prove nothing else went with it.** A delete missing its
  `WHERE` shows here and nowhere else.
- **Send a decoy uid in the request body** and confirm the token's owner is deleted instead. Do not
  assert that the body is ignored — demonstrate it. Use a **nonexistent** uid, never the QA
  account's: same conclusion, without staking the evidence on the code being what you think it is.
- **Negative tests:** no `Authorization` header, the **anon key as the bearer** (a validly-signed JWT
  with no `sub` — this is the one that matters), a malformed bearer, and a wrong HTTP method.
- **One failure path:** attempt with no network, confirm the app says so and nothing is deleted.

**Take the device lease. Nothing else touches the rig during this.**

---

## 5. Status — landed 2026-08-03

**Built, deployed and verified.** Edge Function `delete-account`, **version 1, ACTIVE,
`verify_jwt: true`**.

- Throwaway `88b9fe93-9e25-4d95-a313-e2c67fdeba38`, seeded across **29 surfaces at exactly 1** each,
  including a real uploaded file in all three buckets. **After deletion: 30 queried surfaces, all
  zero** — including `feedback` by email and all three bucket prefixes.
- **Control held to the checksum.** QA `saved_dosages` 5 / `dose_log` 2 / `notifications` 1 with
  identical id-set md5s before and after. Globals returned exactly: `auth.users` 91 → 92 → **91**,
  `saved_dosages` **104**, `dose_log` **16**, `storage/blood-tests` **5**.
- **Decoy uid in the body ignored**; the token's owner was deleted. All four negative tests 401/405.
- Deleted credentials no longer sign in; the pre-deletion token 401s.

**`SettingsScreen`'s copy now promises deletion, and the promise is true.** `TASK 12`'s deletion item
closes on this run. The `BATCH.md` pre-ship line for deletion is struck.

**STILL OPEN — the offline failure path has NOT been run.** The guard is written (`guard
network.isOnline` returns before any call) but it is iOS-side and needs the app on the device;
simulating offline for `NWPathMonitor` means taking the Mac's network down, which drops the paired
session mid-run. **It belongs in the UI suite, or as the last act of a session with nothing after
it. Filed, not ticked.**

> **NOT OURS TO FIX — the shipped web product still leaks.** `blood-tests` files, `progress-photos`
> and `feedback` email addresses survive account deletion on the web today; its route clears
> `avatars` only and `feedback` is `SET NULL`. **Five live blood-test documents across three real
> users.** This is with the owner. **Do not act on it from this repo.**
