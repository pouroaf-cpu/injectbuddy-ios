// ─── delete-account ──────────────────────────────────────────────────────────
//
// SPEC: docs/SPEC-ACCOUNT-DELETION.md.
//
// THE COUNTERPART FILE IS THE WEB'S `lib/account/user-data.ts` +
// `app/api/account/delete/route.ts` ON THE WINDOWS MACHINE. They do the same job
// against the same database. **A user-scoped table or bucket added to one and not
// the other leaves data behind after a deletion, which is a privacy failure
// rather than a bug.** docs/DATA-CONTRACT.md records the same obligation.
//
// ─── WHY THIS EXISTS AT ALL ──────────────────────────────────────────────────
//
// The web route is cookie-authenticated and holds a service-role key server-side.
// iOS is a bearer-token PostgREST client and **must never hold a service-role
// key** — a key in the app binary is a key in every user's hands. So the
// privileged work happens here and the caller proves who it is with its own JWT.
//
// ─── THE TWO THINGS THAT MAKE THIS SAFE ──────────────────────────────────────
//
//  1. `uid` IS DERIVED FROM THE VERIFIED TOKEN AND NEVER FROM THE REQUEST BODY.
//     A uid read out of the body is an any-user delete endpoint. This function
//     does not read the body at all.
//  2. `{ ok: true }` IS RETURNED ONLY WHEN EVERY DATABASE STEP SUCCEEDED. Any
//     error aborts. D9's sharpest case: a failed deletion that reads as success
//     leaves a user believing their health data is gone when it is not.
//
// ─── THE FK COMMENT IN THE WEB SOURCE IS WRONG, AND INVERTED ─────────────────
//
// The web's own comment — and, until 2026-08-03, SPEC §1 quoting it — says there
// are NO foreign keys from these tables to `auth.users`, so deleting the auth
// user does not cascade.
//
// **Measured against `pg_constraint` on 2026-08-03: there are 22, and almost
// everything cascades.** Twenty tables are `ON DELETE CASCADE`; exactly two are
// `ON DELETE SET NULL` (`feedback.user_id`, `chat_messages.sender_id`).
//
// THIS IS WHY THE GAP SURVIVED SO LONG: web deletions have looked correct
// precisely BECAUSE the cascade clears twenty tables on its own. The only things
// it cannot reach are the two SET NULLs — and STORAGE, which is not in the FK
// graph at all and was never going to be cleared by anything.
//
// **The explicit deletes below stay anyway, and the mechanism is named next to
// each one.** A cascade is a property of a constraint that someone can drop in a
// migration; a deletion that silently depends on an FK nobody restated is a
// deletion that breaks without a failing test. Enumerate, never predicate (D7).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

// ─── Tables keyed by a plain `user_id` column ────────────────────────────────
//
// Derived from `information_schema` on the live database, NOT transcribed from
// the web's `USER_ID_TABLES` — that list is sixteen and the live schema has
// nineteen. Copying it would have given the omission a second home and made it
// look corroborated.
//
// `fk` records what the constraint to `auth.users` does on delete, so a reader
// can see which of these deletes are load-bearing and which are insurance.

const USER_ID_TABLES: ReadonlyArray<{ table: string; fk: "CASCADE" | "SET NULL" }> = [
  // The web's sixteen.
  { table: "saved_dosages", fk: "CASCADE" },
  { table: "protocols", fk: "CASCADE" },
  { table: "peptide_protocols", fk: "CASCADE" },
  { table: "cycles", fk: "CASCADE" },
  { table: "cycle_items", fk: "CASCADE" },
  { table: "vial_inventory", fk: "CASCADE" },
  { table: "dose_log", fk: "CASCADE" },
  { table: "dose_history", fk: "CASCADE" },
  { table: "injection_schedules", fk: "CASCADE" },
  { table: "blood_tests", fk: "CASCADE" },
  { table: "marker_values", fk: "CASCADE" },
  { table: "user_preferences", fk: "CASCADE" },
  { table: "user_badges", fk: "CASCADE" },
  { table: "user_active_days", fk: "CASCADE" },
  { table: "notifications", fk: "CASCADE" },
  { table: "chat_conversations", fk: "CASCADE" },

  // ⚠️ NOT ON THE WEB'S LIST. All three carry `user_id uuid`.
  //
  // Body measurements, AI body-fat estimates and a photo path. Cascades, so the
  // rows do go — but `photo_path` points into `progress-photos`, and STORAGE
  // DOES NOT CASCADE. The file is the part that survives.
  { table: "body_metrics", fk: "CASCADE" },
  // ***THE ONE THAT IS A REAL, LIVE RETENTION GAP.*** `SET NULL`, not cascade:
  // the row SURVIVES the auth-user delete with its `email` column intact. A
  // deleted user's email address persists indefinitely — PII independent of the
  // uid, by the design of that FK rather than by oversight. This explicit delete
  // is the only thing that removes it.
  { table: "feedback", fk: "SET NULL" },
  // A live reminder ladder keyed by user. Cascades, so the row goes; listed so
  // that dropping the constraint cannot quietly leave a deleted account inside a
  // state machine that sends email.
  { table: "email_verification_reminders", fk: "CASCADE" },
];

// ─── Tables keyed by `author_id` rather than `user_id` ───────────────────────
// Children first: comments reference posts. Both CASCADE.
const AUTHOR_ID_TABLES = ["suggestion_comments", "suggestion_posts"] as const;

// ─── Tables keyed by EMAIL, because the rows predate the account ─────────────
//
// `pending_dosages` is a calculator result saved before signing up, so it is
// keyed by `email` and has no `user_id` at all — no FK, no cascade, nothing
// reaches it from a uid. It is the user's own data and leaving a table
// addressable by a deleted person's email address is the `feedback` problem with
// a different key.
const EMAIL_TABLES = ["pending_dosages"] as const;

// ─── Storage buckets holding per-user files under a `<uid>/` prefix ──────────
//
// ***STORAGE IS NOT IN THE FK GRAPH. NOTHING CASCADES HERE.*** These deletes are
// the only mechanism that exists.
//
// The spec named only `avatars`, and the web route clears only `avatars`.
// Verified on 2026-08-03: every object in `avatars` and `blood-tests` has a UUID
// as its first path segment, so one `<uid>/` prefix delete works on all three.
//
// ⚠️ `blood-tests` and `progress-photos` are cleared by nothing on the shipped
// web product. Blood test documents and progress photos are the two most
// sensitive file types in this system.
const USER_PREFIX_BUCKETS = ["avatars", "blood-tests", "progress-photos"] as const;

// ─── Deliberate exclusions ───────────────────────────────────────────────────
//
// Stated with reasons rather than simply absent. An exclusion with a reason is
// auditable; an absence is indistinguishable from an oversight — which is the
// exact failure this file exists to correct.
//
//   community_survey            — anonymous, no user link.
//   community_survey_throttle   — keyed by `submitter_hash`, also anonymous.
//   marker_definitions, guides  — global reference data, not user rows.
//   seo_*, analytics_snapshots  — operational, not user rows.
//   hp_subscribers, hp_clicks   — homepage marketing. `hp_subscribers` is keyed by
//                                 email with no uid; it is a mailing list rather
//                                 than account data. Left, deliberately.
//   chat_messages.sender_id     — `SET NULL`, and CLOSED, not carried. Raised as a
//                                 possible leak (a message sent into someone
//                                 else's conversation would survive with its
//                                 author nulled) and answered from the migration:
//                                 `chat_conversations.user_id` is UNIQUE, so
//                                 conversations are strictly 1:1 with a user, and
//                                 the message-insert policy requires BOTH
//                                 `sender_id = auth.uid()` AND
//                                 `c.user_id = auth.uid()`. A user can only post
//                                 into their own conversation, which cascades with
//                                 them. The SET NULL is for the other direction:
//                                 when an ADMIN is deleted their support replies
//                                 stay in the recipient's conversation with the
//                                 author nulled — correct behaviour, not a leak.
//                                 Evidence: `20260622000000_support_chat.sql`
//                                 lines 18, 28, 159–166.
//
//   lts_*  (13 tables + the      — A SEPARATE PRODUCT (Last Tahi Standing) that
//   lts-selfies/faces/tts          shares this Postgres instance and NOTHING ELSE.
//   buckets)                       MEASURED 2026-08-03, because sharing a project
//                                  looked like sharing an auth store and it is
//                                  not: `lts_profiles` has NO foreign key to
//                                  `auth.users`, ZERO of its 19 ids match an auth
//                                  user, and all 19 carry a `pin_hash` — it has
//                                  its own PIN identity. Deleting an InjectBuddy
//                                  auth user does not touch an LTS account.
//                                  Recorded with the evidence so this is not
//                                  re-opened as an oversight.

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ error: "function is misconfigured" }, 500);

  // ── Identity. From the token, and only from the token. ────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.slice(7).trim()
    : "";
  if (!jwt) return json({ error: "missing bearer token" }, 401);

  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Verifies signature and expiry server-side. The request body is never read —
  // there is no code path here that could take a uid from a caller.
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const uid = userData?.user?.id;
  if (userError || !uid) return json({ error: "invalid or expired token" }, 401);

  // Also from the verified token, for the email-keyed tables. Never from a body.
  const email = userData?.user?.email ?? null;

  try {
    // 1 · Chat children, resolved through the conversations they hang off.
    const { data: conversations, error: convError } = await admin
      .from("chat_conversations")
      .select("id")
      .eq("user_id", uid);
    if (convError) throw new Error(`chat_conversations select: ${convError.message}`);

    const conversationIds = (conversations ?? []).map((c: { id: string }) => c.id);
    if (conversationIds.length > 0) {
      for (const table of ["chat_telegram_links", "chat_messages"]) {
        const { error } = await admin
          .from(table)
          .delete()
          .in("conversation_id", conversationIds);
        if (error) throw new Error(`${table} delete: ${error.message}`);
      }
    }

    // 2 · Every plain `user_id` table. Nothing swallowed.
    for (const { table } of USER_ID_TABLES) {
      const { error } = await admin.from(table).delete().eq("user_id", uid);
      if (error) throw new Error(`${table} delete: ${error.message}`);
    }

    // 3 · Suggestions, keyed by `author_id`.
    for (const table of AUTHOR_ID_TABLES) {
      const { error } = await admin.from(table).delete().eq("author_id", uid);
      if (error) throw new Error(`${table} delete: ${error.message}`);
    }

    // 4 · Email-keyed pre-signup rows. Skipped only if the token carries no
    //     email at all, which would make the rows unaddressable rather than
    //     spared — reported, not silent.
    const emailTablesSkipped: string[] = [];
    for (const table of EMAIL_TABLES) {
      if (!email) {
        emailTablesSkipped.push(table);
        continue;
      }
      const { error } = await admin.from(table).delete().eq("email", email);
      if (error) throw new Error(`${table} delete: ${error.message}`);
    }

    // 5 · Storage. BEST-EFFORT — a storage failure must never block deletion of
    //     the account itself (SPEC §1.4). Failures are collected and returned so
    //     a partial file cleanup is VISIBLE rather than silent.
    //
    // ─── WHY STORAGE RUNS HERE, BEFORE `profiles` AND BEFORE THE AUTH USER ───
    //
    // This ordering decides WHICH failure is possible, and only one of the two is
    // recoverable:
    //
    //   • Files first (this order): a later failure leaves the files deleted and
    //     the account still alive. Annoying, visible, and the user can retry.
    //   • Account first: a failure leaves the account gone and the files orphaned,
    //     with NO authenticated caller left who could ever retry. That is exactly
    //     the state the shipped web product is in today.
    //
    // So the order is chosen so that the recoverable failure is the one that can
    // happen. It is not incidental and it should not be "tidied".
    //
    // ─── PAGINATION, AND WHY A BARE `list()` WAS WRONG ──────────────────────────
    //
    // `list` caps at 1000 and a truncated page is INDISTINGUISHABLE from a bucket
    // that happens to hold exactly that many files. A single call would hand back a
    // partial cleanup reported as a success — a green that is really an absence, in
    // the one function whose entire job is to leave nothing behind. So: page until
    // a page comes back short.
    //
    // ─── FLATNESS IS A MEASURED ASSUMPTION, NOT A PROPERTY OF STORAGE ───────────
    //
    // `list` is NOT recursive, so this code assumes objects live at `<uid>/<file>`.
    // MEASURED against `storage.objects` on 2026-08-03: six objects across the three
    // buckets, every one at depth 2 — `avatars` 1, `blood-tests` 5,
    // `progress-photos` 0. So the assumption holds today. **`progress-photos` is
    // empty, so its flatness is unproven rather than verified**, and the first
    // nested write would break this silently.
    //
    // Supabase returns a folder placeholder as an entry with a NULL `id`. Removing
    // `<uid>/<folder>` is a no-op that reports success, so any null-`id` entry is
    // pushed to `storageFailures` instead — turning a future silent leak into a
    // visible one.
    const storageFailures: string[] = [];
    const PAGE = 1000;
    for (const bucket of USER_PREFIX_BUCKETS) {
      try {
        let offset = 0;
        for (;;) {
          const { data: files, error: listError } = await admin.storage
            .from(bucket)
            .list(uid, { limit: PAGE, offset });
          if (listError) {
            storageFailures.push(`${bucket}: ${listError.message}`);
            break;
          }

          const page = files ?? [];
          if (page.length === 0) break;

          const paths: string[] = [];
          for (const f of page as Array<{ name: string; id: string | null }>) {
            if (f.id === null) {
              // A folder placeholder. `remove()` on it would silently do nothing.
              storageFailures.push(
                `${bucket}: unexpected nested path "${uid}/${f.name}" — not removed. ` +
                  `This function assumes flat <uid>/<file> objects; that assumption ` +
                  `no longer holds for this bucket.`,
              );
              continue;
            }
            paths.push(`${uid}/${f.name}`);
          }

          if (paths.length > 0) {
            const { error: removeError } = await admin.storage.from(bucket).remove(paths);
            if (removeError) storageFailures.push(`${bucket}: ${removeError.message}`);
          }

          // A short page is the only reliable end-of-list signal.
          if (page.length < PAGE) break;
          offset += page.length;
        }
      } catch (e) {
        storageFailures.push(`${bucket}: ${e instanceof Error ? e.message : String(e)}`);
      }
    }

    // ─── THE DURABLE RECORD OF A STORAGE FAILURE LIVES HERE, NOT ON THE DEVICE ──
    //
    // The caller is about to lose its account. Anything iOS records locally dies
    // with the app's data or with the user's next reinstall, and there is no
    // session left to upload it with — the client cannot be the record for an
    // event that happens as the client ceases to exist.
    //
    // This is server-side and Supabase retains function logs, so one structured
    // line here is the durable trace: which user, which prefixes, still holding
    // files after their account was deleted. iOS's `print` is a developer
    // convenience and nothing more.
    if (storageFailures.length > 0) {
      console.error(
        JSON.stringify({
          event: "account_deletion_storage_incomplete",
          uid,
          failures: storageFailures,
        }),
      );
    }

    // 6 · profiles, keyed by `id` — NOT by `user_id`.
    const { error: profileError } = await admin.from("profiles").delete().eq("id", uid);
    if (profileError) throw new Error(`profiles delete: ${profileError.message}`);

    // 7 · The auth user. This is what makes the login go away. If it fails the
    //     whole thing fails — a caller must never be told their account is gone
    //     while they can still sign in.
    const { error: authError } = await admin.auth.admin.deleteUser(uid);
    if (authError) throw new Error(`auth user delete: ${authError.message}`);

    return json({ ok: true, storageFailures, emailTablesSkipped }, 200);
  } catch (e) {
    // Never `ok` on a partial failure.
    return json({ ok: false, error: e instanceof Error ? e.message : String(e) }, 500);
  }
});
