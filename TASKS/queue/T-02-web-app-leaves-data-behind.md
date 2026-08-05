## T-02 — The web app leaves data behind when an account is deleted
**Priority 8/10** · **Owner:** win · **Status:** doing — built, awaiting an end-to-end run

**What:** `app/api/account/delete/route.ts` clears the `avatars` bucket only. `blood-tests` and
`progress-photos` are cleared by nothing — storage is not in the foreign-key graph — and `feedback`
survives with its `email` column intact, because its foreign key is `SET NULL` rather than cascade.

**Measured 2026-08-03:** five blood-test documents belonging to three real users survive account
deletion on the live site today, along with every progress photo and every feedback email address.

**Re-measured against the live database 2026-08-04, and the severity is different from the sentence
above — corrected rather than removed, per rule 7.** Queried `storage.objects` left-joined to
`auth.users` on the first path segment:

| bucket | objects | orphaned files | orphaned users |
|---|---|---|---|
| `avatars` | 1 | **0** | 0 |
| `blood-tests` | 5 | **0** | 0 |
| `progress-photos` | 0 | 0 | 0 |

`feedback`, `pending_dosages` and `body_metrics` are all **empty**. 91 auth users.

**So nothing has leaked yet.** Those five blood-test documents belong to users who are still live —
they would survive if those users deleted, which is what the 2026-08-03 measurement meant. It is a
**latent** right-to-erasure gap, not an active retention breach: no deleted user's data is sitting in
this database today. It is still worth fixing before anyone deletes, because blood-test documents and
progress photos are the two most sensitive file types in the system, and it stops being latent the
first time one of those 91 people taps delete.

**BUILT 2026-08-04 (web side, unverified end-to-end — see below).** `lib/account/user-data.ts` is now
the shared list and names what was missing:

- **Storage:** the route looped `avatars` alone; it now loops all three buckets. Storage is not in
  the FK graph, so this loop is the only mechanism that clears it. Still best-effort per bucket so a
  storage failure cannot abort the deletion and half-erase the account — but **no longer silent**: a
  failed bucket is reported to error tracking and returned as `storageFailed`, because an erasure
  step that fails invisibly is the one failure mode that matters.
- **Tables:** `body_metrics`, `feedback` and `email_verification_reminders` were absent from the
  web's sixteen while present in the live schema and in the iOS function.
- **`pending_dosages`:** keyed by `email`, no `user_id`, no FK — nothing reached it from a uid. Now
  cleared by email, and also **exported**, since right-of-access covers it for the same reason.
- **The comment that hid this for so long is corrected.** The file used to state "There are NO
  foreign keys from these tables to auth.users". Inverted: there are 22, twenty of them CASCADE. Web
  deletions looked correct *because* the cascade was clearing twenty tables unaided, so the short
  list never showed a symptom. What a cascade cannot reach is the two SET NULLs and storage.

`npx tsc --noEmit` clean.

**NOT done, and this is the honest part.** Rule 8 says done means measured, and this has not been
measured end to end. What exists is: the code, a clean typecheck, and confirmation that every object
in those buckets really does sit under a `<uid>/` first path segment, which is the shape the route's
`list(uid)` + `remove(\`${uid}/${name}\`)` depends on. What does not exist is a run.

**Done when:** a throwaway account with a file in each of the three buckets is deleted through the
route, and `storage.objects` and every table above return zero rows for that uid. Deleting from
**iOS** must leave the same zero — one account, two front doors — which is the check that stops the
two implementations drifting again.
