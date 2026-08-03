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

**The critical fact, stated in the web's own comment:** there are **no foreign keys from these tables to
`auth.users`**, so deleting the auth user **does not cascade**. Every table is cleared explicitly. Some of
them also lack a self-DELETE RLS policy, which is why the web uses the **service-role** client with every
delete filtered strictly to the caller's own id.

**Order, and it matters — children before parents:**

1. **Chat children.** Select the user's `chat_conversations` ids, then delete `chat_telegram_links` and
   `chat_messages` by `conversation_id`.
2. **Every plain `user_id` table**, in this list (`USER_ID_TABLES`), and **any error throws** rather than
   being swallowed:
   `saved_dosages · protocols · peptide_protocols · cycles · cycle_items · vial_inventory · dose_log ·
   dose_history · injection_schedules · blood_tests · marker_values · user_preferences · user_badges ·
   user_active_days · notifications · chat_conversations`
3. **Suggestions**, keyed by `author_id` not `user_id`: `suggestion_comments`, then `suggestion_posts`.
4. **Avatar files** under the `avatars/<uid>/` storage prefix. **Best-effort — never block deletion on
   storage.**
5. **`profiles`**, keyed by **`id`**, not `user_id`.
6. **The auth user itself.** This is what makes the login go away. If it fails, the whole thing fails.
7. Sign out, best-effort.

**`community_survey` is anonymous, is not linked to a user, and is never touched.**

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
- **Record its uid before deleting.** Then, after: query every one of the sixteen tables plus `profiles`,
  `suggestion_*` and the avatar prefix for that uid and confirm **zero rows in each** — table by table,
  printed, not summarised. A count over one table is not evidence about sixteen.
- **Confirm the auth user is gone** and that its credentials no longer sign in.
- **Confirm the QA account still has its rows** — same before/after id-set comparison used for `unlogDose`.
  That is the control, and it is the one that catches a filter that was not filtering.
- **One failure path:** attempt with no network, confirm the app says so and nothing is deleted.

**Take the device lease. Nothing else touches the rig during this.**

---

## 5. When it lands

- `SettingsScreen`'s dialog copy goes back to promising deletion, because the promise becomes true.
- `TASK 12`'s deletion item closes with the run's evidence.
- The pre-ship Release launch still happens afterwards and is unaffected by this.
