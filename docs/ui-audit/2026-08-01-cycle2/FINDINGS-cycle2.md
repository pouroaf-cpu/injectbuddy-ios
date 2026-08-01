> **Superseded, 2026-08-01 (cycle 3–4).** Resolved by a unique index on
> `(user_id, calculator_type, config)` plus insert-then-recover in `saveDosage`.
> Confirmed by row count: 99 → 100 after two saves of the same config, 0 duplicate
> groups.
>
> **And read this before trusting anything upstream of it.** While testing that fix
> we found protocol saving from iOS had *never worked* — `saveDosage` sent no
> `user_id`, and the INSERT policy's `WITH CHECK (user_id = auth.uid())` rejected
> every attempt. So all the config-shape reasoning that led here — `configExtras`,
> `configOmittedKeys`, the fingerprint discussion, the `syringeMl` double-write trap —
> was correct in itself but was never validated by anything, because the writes it
> describes were being refused by the database. It got its first real validation in
> cycle 3, when a save finally reached the table and round-tripped all 8 TRT keys.
> Do not read the age of that code as evidence it was working.

# Cycle 2 — blocker: iOS never reaches the `/api/dosages` dedup

The barrel-picker acceptance test was specified as: save the same protocol twice
from iOS, expect the second POST to return `duplicate: true`; then save the same
config from web and iOS and expect the iOS response to carry the web row's id.

**That test cannot run, and not because of anything the barrel picker changed.**

## Evidence

`SupabaseBackendClient.saveDosage` (`Core/Backend/SupabaseBackendClient.swift:54`):

```swift
let row: InsertedID = try await client
    .from("saved_dosages")
    .insert(dosage, returning: .representation)
    .select("id")
    .single()
    .execute()
    .value
return row.id
```

A direct PostgREST insert. Supporting checks across the whole iOS source:

- `grep -rn "api/dosages" Sources/` → **5 hits, every one a comment.** No call site.
- `grep -rln "URLSession" Sources/` → **no matches.** There is no HTTP client in the
  app other than `supabase-swift`.
- `README.md:66` states the design intent: the app "reads/writes the user's own rows
  … **directly through PostgREST** under row-level security — no backend changes."

So the fingerprint-and-dedup logic in `app/api/dosages/route.ts:103-120` is never
executed by an iOS save. There is no response body to inspect: `saveDosage` returns
the id of a row it just inserted, and `duplicate` is not a field that exists on that
path.

## What this means, in order of consequence

1. **iOS saving the same protocol twice already inserts two rows**, and always has.
   This predates the barrel picker and is not caused by it.
2. **An iOS save can never match a web row**, because matching is the endpoint's job
   and the endpoint is bypassed. Config-shape parity cannot fix this on its own.
3. The config-shape work still matters for the *other* reason the catalog note gives —
   the web restores a protocol by key, so a short or wrongly-typed config breaks
   read-back. That part is unaffected and still correct.
4. `dose_log` writes are **not** affected: `logDose` uses
   `.upsert(onConflict: "protocol_id,dosed_on")`, so dose logging is genuinely
   idempotent. It is only protocol saving that has no dedup.

## What I did not do

I did not run a save against production to demonstrate the duplicate. It would have
written real rows to the account's protocol list to prove something the source
already settles, and the fix is a design decision that has not been made yet.

## Decision needed

Three options, and this is a call for the human, not for me:

- **Route iOS saves through `/api/dosages`.** Gets dedup and cross-platform matching
  for free, but adds an HTTP path and an auth-header concern to an app that currently
  speaks only PostgREST, and contradicts the stated "no backend changes" architecture.
- **Client-side pre-check.** Fetch the user's rows for that `calculator_type`, apply
  the same key-sorted stringify, and skip the insert on a match. Keeps the PostgREST
  architecture; duplicates the fingerprint logic in a second language, where it can
  drift from the server's.
- **Accept duplicates on iOS** and dedup elsewhere (or not at all).

Until one is chosen, the barrel picker is correct in every respect I *can* verify —
field renders, default preserves the previous saved value, `configExtras` no longer
double-writes, over-capacity warning fires with icon and text — but "no duplicate
protocol across platforms" is not a property this app currently has, with or without it.
