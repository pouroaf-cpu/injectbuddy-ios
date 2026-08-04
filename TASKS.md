# TASKS — the shared job list

**One list. Both sides read it, both sides write it.** If it is not here it is not tracked, and a
job carried in a message does not survive a context clear.

## How to use it

1. **Every task has an id, a priority, an owner, a status and a description.** A title alone is not
   a task — the next reader must be able to act on it without asking what it means.
2. **Say what is wrong, not just what to do.** For a defect: what it does now, and why that is
   wrong. For a job: what does not exist yet.
3. **Every task says what "done" looks like** — an observable condition, not "fixed".
4. **Sub-tasks only when the work genuinely splits.** Do not manufacture depth. Sub-tasks carry
   their own description.
5. **Check for a duplicate before adding.** This list once existed in four documents at the same
   time and re-surfaced the same item to the owner every session.
6. **A defect found while doing a task is added here immediately, by whoever found it** — as its own
   task, before it is forgotten. Do not carry it in a message.
7. **Nothing is deleted.** Done is struck through, with the commit SHA or the evidence that closed
   it, and stays.
8. **Done means measured.** A photograph, a query, a run. Not "it should work now".

**Priority** is out of 10 — 10 is a user is being harmed today, 1 is tidy-up.
**Status:** `open` · `doing` · `blocked` · `done` · `filed` (real, deliberately not being worked)
**Owner:** `mac` · `win` · `pouroa`

---

## T-01 — The web app leaves data behind when an account is deleted
**Priority 8/10** · **Owner:** pouroa · **Status:** filed

**What:** `app/api/account/delete/route.ts` clears the `avatars` bucket only. `blood-tests` and
`progress-photos` are cleared by nothing — storage is not in the foreign-key graph — and `feedback`
survives with its `email` column intact, because its foreign key is `SET NULL` rather than cascade.

**Measured 2026-08-03:** five blood-test documents belonging to three real users survive account
deletion on the live site today, along with every progress photo and every feedback email address.

**Why it matters:** a right-to-erasure gap on the shipped product. The only item on this list
affecting real users right now.

**Done when:** the web route clears three bucket prefixes and deletes `feedback` by uid. The iOS
edge function already does both and is the reference.

## T-02 — iOS never records the injection site
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** `dose_log.site` is NULL on every iOS-written row. All fourteen web-written rows carry it.
The web derives its whole site-rotation model from that column — eight IM sites, six SubQ, a
3.5-day rest convention and a body map.

**Why it matters:** not a missing feature — a column iOS silently declines to fill. The damage is to
data the user already has rather than to a screen they do not.

**Done when:** a dose logged from iOS carries its site, read back from the database.

**Not in scope:** the body map and rotation UI. Separate, much larger.

## T-03 — The dashboard's v1 scope is unresolved
**Priority 5/10** · **Owner:** win · **Status:** open

**What:** the old plan said "3 files against ~30 web components, build full parity". Thirty is a
count of files in a directory — the mobile web dashboard actually renders seven content elements.
The premise is withdrawn and the conclusion has not been replaced, so nothing downstream can be
sequenced.

**Real gaps against the web:** recommended injection site, "N injections today", the serum chart,
and the dashboard disclaimer line. The serum chart is the thing the onboarding paywall sells.

**Done when:** Windows reads the web dashboard from source and proposes a v1 set the owner accepts.

## T-04 — The dashboard's dose line never renders its volume
**Priority 3/10** · **Owner:** mac · **Status:** filed

**What:** `DashboardFormat.doseLine` is a second, dead derivation of the draw volume, reading config
keys no iOS row contains — so the "· 0.25 mL" half of the next-dose card has never appeared on any
build.

**Done when:** it reads the one correct source (`DoseVolume`). Fold in only if it is a one-line
repoint; otherwise it stays here.

## T-05 — Calendar pull-to-refresh did nothing, and the cause is unknown
**Priority 3/10** · **Owner:** mac · **Status:** filed

**What:** the gesture armed but issued zero requests — confirmed against the database's own API log
— while the identical gesture on an identically-shaped Dashboard view re-read one minute earlier in
the same run. The affordance was removed rather than shipped as a lie; the data path survives
because the screen still re-reads when the tab re-appears.

**Leading candidate:** `RouteContent` gives the Dashboard an inline title and every other tab root a
large one, and a large title owns the pull-down stretch above a plain ScrollView.

**Why it still matters with the affordance gone:** if that mechanism is real, **any future screen
with a large title will silently not refresh.**

**Done when:** the candidate is measured — flip the Calendar to an inline title and pull once.
