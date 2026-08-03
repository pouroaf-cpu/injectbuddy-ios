# TASKS — the shared job list

**One list. Both sides read it, both sides write it.** If it is not here it is not tracked, and a
job carried in a message does not survive a context clear.

## How to use it

1. **Every task has an id, an owner, a status and a description.** A title alone is not a task —
   the next reader must be able to act on it without asking what it means.
2. **Say what is wrong, not just what to do.** For a defect: what it does now, and why that is
   wrong. For a job: what does not exist yet.
3. **Every task says what "done" looks like** — an observable condition, not "fixed".
4. **Sub-tasks only when the work genuinely splits.** Do not manufacture depth. Sub-tasks carry
   their own description.
5. **Check for a duplicate before adding.** This list once existed in four documents at the same
   time and re-surfaced the same item to the owner every session.
6. **A defect found while doing a task is added here immediately, by whoever found it** — as its
   own task, before it is forgotten. Do not carry it in a message.
7. **Nothing is deleted.** Done is struck through, with the commit SHA or the evidence that closed
   it, and stays.
8. **Done means measured.** A photograph, a query, a run. Not "it should work now".

**Status:** `open` · `doing` · `blocked` · `done` · `filed` (real, deliberately not being worked)
**Owner:** `mac` · `win` · `pouroa`

---

## T-01 — Snapshot testing is not set up
**Owner:** mac · **Status:** open
**What:** `UX-UI-RULES.md` §1 makes snapshot tests the default way anything visual is checked.
Nothing in this project has ever run one. The library is not added, the target has no reference
images, and no assertion exists.
**Why it matters:** it is the whole plan for staying off Xcode. Until it runs, every visual check
still costs a two-to-three minute device round trip.
**Done when:** a snapshot test renders one calculator, is shown to FAIL against a deliberately wrong
reference, and passes against a correct one.

- [ ] **T-01a — add `pointfreeco/swift-snapshot-testing`** to the unit test target via `project.yml`,
      then `xcodegen generate`. A new file is not in the target until the generator runs.
- [ ] **T-01b — first assertion on `CalculatorScreen`** at default size, reference recorded and
      looked at by a human before it is trusted.
- [ ] **T-01c — the matrix**: fifteen calculators × default / large / AX5. One run, under a minute.

## T-02 — The Mac cannot see the web app
**Owner:** mac · **Status:** open
**What:** the PWA source lives only on the Windows machine. The Mac has twice inferred the web's
behaviour from a doc in its own repo and been wrong both times — once about the start-date payload,
once about a config key that would have written a plausible wrong dose volume.
**Done when:** `github.com/pouroaf-cpu/injectbuddy` is cloned beside the iOS repo and the Mac reads
the source, never a doc about the source.

## T-03 — The Mac has no entry document
**Owner:** win · **Status:** open
**What:** `CLAUDE.md` was deleted with every other markdown file on 2026-08-04. A cold Mac session
now starts with nothing — no role, no rig facts, no traps.
**Done when:** one short file exists that a cold session can read in two minutes and be correct.
Not a rewrite of what was deleted.

## T-04 — Onboarding is waiting on the owner's words
**Owner:** pouroa · **Status:** blocked
**What:** the flow is built and walks six paths, but four things in it are placeholders and none can
be written by anyone else.
**Done when:** all four are supplied and the placeholders are gone.

- [ ] **T-04a — the congratulation line** on screen 1. Currently a visibly-fake placeholder so
      nobody mistakes it for the owner's writing.
- [ ] **T-04b — nine named personalisation strings**, marked ⚠️ PROPOSED in the copy file. The
      nameless forms are the owner's existing copy and are already correct.
- [ ] **T-04c — the price.** `$X/mo` is a literal token on the paywall.
- [ ] **T-04d — fifteen illustrations.** None exist; every benefit screen and the paywall render a
      dashed placeholder. Placeholders may ship in a build. They may not ship to the store.

## T-05 — The web app leaves data behind when an account is deleted
**Owner:** pouroa · **Status:** filed
**What:** `app/api/account/delete/route.ts` clears the `avatars` bucket only. `blood-tests` and
`progress-photos` are cleared by nothing — storage is not in the foreign-key graph — and `feedback`
survives with its `email` column intact because its FK is `SET NULL` rather than cascade. Measured
2026-08-03: five blood-test documents belonging to three real users survive deletion today.
**Why it matters:** it is a right-to-erasure gap on the live product, not a tidiness issue.
**Done when:** the web route clears three bucket prefixes and deletes `feedback` by uid. The iOS
edge function already does both — it is the reference.

## T-06 — Account deletion's offline path has never been run
**Owner:** mac · **Status:** open
**What:** the guard is written — the call returns before any network work when offline — but
simulating offline means taking the Mac's network down, which drops the bridge mid-run.
**Done when:** attempted with no network, the app says so, and nothing is deleted. Run it last in a
session, or drive it from the UI suite.

## T-07 — Calendar pull-to-refresh did nothing, and the cause is unknown
**Owner:** mac · **Status:** filed
**What:** the gesture armed but issued zero requests — confirmed against the database's own API log —
while the identical gesture on an identically-shaped Dashboard view re-read one minute earlier in
the same run. The affordance was removed rather than shipped as a lie; the data path survives
because the screen still re-reads when the tab re-appears.
**Leading candidate:** `RouteContent` gives the Dashboard an inline title and every other tab root a
large one, and a large title owns the pull-down stretch above a plain ScrollView.
**Why it still matters with the affordance gone:** if that mechanism is real, **any future screen
with a large title will silently not refresh.**
**Done when:** the candidate is measured — flip the Calendar to an inline title and pull once.

## T-08 — The disclaimer is invisible on most calculators
**Owner:** win · **Status:** filed
**What:** measured 2026-08-03 — of the calculators where the disclaimer is on screen at all, only
Reconstitution is legible, clearing the pinned bar by 16pt. Three GLP-1 screens have it entirely
behind the result bar; BPC-157 has it entirely behind the tab bar; seven others put it below the
window at rest. Two different mechanisms, same symptom.
**History:** struck as won't-fix by the owner, who was shown a measurement that named the hero
circle as the occluder. The hero circle occludes nothing — the finding was wrong about its own
mechanism and understated its scope.
**Why it is back:** `UX-UI-RULES.md` §9 now says text is never hidden and the primary flow fits
above the fold. The rule and the strike disagree.
**Done when:** the owner decides which of the two stands.

## T-09 — iOS never records the injection site
**Owner:** mac · **Status:** open
**What:** `dose_log.site` is NULL on every iOS-written row. All fourteen web-written rows carry it.
The web derives its whole site-rotation model from that column — eight IM sites, six SubQ, a
3.5-day rest convention, a body map.
**Why it matters:** this is not a missing feature, it is a column iOS silently declines to fill, so
the damage is to data the user already has rather than to a screen they do not.
**Done when:** a dose logged from iOS carries its site, read back from the database.
**Not in scope:** the body map and the rotation UI. That is a separate, much larger job.

## T-10 — The dashboard's dose line never renders its volume
**Owner:** mac · **Status:** filed
**What:** `DashboardFormat.doseLine` is a second, dead derivation of the draw volume, reading config
keys no iOS row contains — so the "· 0.25 mL" half of the next-dose card has never appeared.
**Done when:** it reads the one correct source (`DoseVolume`) instead. Fold in only if it is a
one-line repoint; otherwise it stays here.

## T-11 — Large text is unusable on two known screens
**Owner:** mac · **Status:** filed
**What:** at the largest accessibility size, onboarding's setup screen has a reachable CTA and four
unreachable inputs, and the calculator result bar takes 43.5% of the content area.
**Why it is filed rather than open:** Dynamic Type is the deferred axis and default-size defects
outrank it. This is the first thing to fix when that axis reopens.
**Done when:** the owner reopens Dynamic Type work.

## T-12 — The dashboard's v1 scope is unresolved
**Owner:** win · **Status:** open
**What:** the old plan said "3 files against ~30 web components, build full parity". Thirty is a
count of files in a directory — the mobile web dashboard actually renders seven content elements.
The premise is withdrawn; the conclusion is not yet replaced.
**Real gaps against the web:** recommended injection site, "N injections today", the serum chart,
and the dashboard disclaimer line. The serum chart is what the onboarding paywall sells.
**Done when:** Windows reads the web dashboard from source and proposes a v1 set the owner accepts.

## T-13 — The rig lock cries wolf
**Owner:** mac · **Status:** filed
**What:** `scripts/rig-lock.sh` warns that something is touching the device without the lock when
its own `pgrep` matches any shell whose command line merely contains the word `xcodebuild` —
including the shell running the check.
**Why it matters:** it failed safe, but a warning that is wrong gets ignored on the day it is right.
**Done when:** the match is narrowed to real processes. Do it when something next touches that
script, not before.
