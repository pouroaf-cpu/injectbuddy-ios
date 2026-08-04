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

9. **This file is edited in the checkout, and you pull before you write it.** On 2026-08-04 Windows
   spent a session editing an untracked copy at `Projects\injectbuddy-ios\TASKS.md`; it showed T-03
   open three days after it was closed with evidence, and mac was sent to re-do finished work. The
   only copy that counts is the one in the repo.
10. **Take IDs from your own block so a crossing write cannot collide.** Both sides push instantly.
    **mac allocates upward from T-14; win allocates from T-50.** On the same day T-06, T-07 and T-08
    each meant two different things at once — a merge conflict is recoverable, two tasks silently
    sharing an ID is not.

**Priority** is out of 10 — 10 is a user is being harmed today, 1 is tidy-up.
**Status:** `open` · `doing` · `blocked` · `done` · `filed` (real, deliberately not being worked)
**Owner:** `mac` · `win` · `pouroa`

---

## T-01 — iOS does not look like the web app
**Priority 9/10** · **Owner:** win + mac · **Status:** doing

**What:** the iOS app was built as a functional port of the web app's *inputs*. Everything that
gives the web its character and most of what makes it useful was never built, and was never written
down as something that should be. The design reference repo — 72 captures at mobile width — was used
for colour and spacing tokens only, never for composition.

**The standing decision (owner, 2026-08-04):** **iOS matches the web in every way it can.** Nothing
is dropped because it is hard. Where something genuinely cannot exist on iOS, that is written down
with the reason, not silently skipped.

**Method:** one screen at a time. Take the iOS frame, find its partner in
`github.com/pouroaf-cpu/injectbuddy-design-refs/screens`, list every difference, and add it here as
a sub-task. Do not fix anything until the screen's differences are listed.

**Reference caveat:** the 72 captures were taken 2026-07-31 from the web's
`feature/dosage-status-model` branch, which was unmerged at the time. Where a capture and the live
site disagree, the live site wins.

**And where the captures are SILENT, the source still rules** (widened 2026-08-04). The frames
disagree with the live app by omission as well as by contradiction, and the omissions are the
dangerous half because nothing on the page announces them. The EOD business is the worked example:
the reference set has no TRT EOD screen and iOS ships a TRT EOD calculator, which reads as "the web
dropped it" until you look at the source and find that EOD was never a page — it is a *frequency
inside the TRT calculator*, and iOS grew a second screen because it had no mode switcher. No frame
could have told you that.

**Ordering of truth, best to worst:** the web working tree → `https://www.injectbuddy.com`
(deployed `8a51aa5a`) → the source on branch `feature/dosage-status-model` → the 2026-07-31
captures. **Both sides now have the web repo cloned** — mac at `~/injectbuddy`, and the branch to
read is `feature/dosage-status-model`, NOT `master`. `public/app.js` differs between them by 1038
insertions and 514 deletions, so reading `master` is reading a different app.

**Done when:** every screen has been compared, every difference is either built or recorded with a
reason it cannot be.

---

### T-01a — TRT calculator (compared 2026-08-04) — **12 differences · 9 BUILT, 3 parked**

**Status: doing.** Nine built and photographed at `29a8ede`; three parked with the owner. The nine
are struck through individually below. **Frame: `docs/ui-audit/2026-08-04-t01a/20-calculator-trt-default.png`**,
captured by `CaptureCurrentState.testCaptureCalculatorAtRest` at default type size, gate probe
reporting `ax=false size=large area=690.67 bar=200.00 share=0.2896`.

**Two corrections to this list, found by reading the web source rather than the captures. The
difference each corrects is struck through with the correction beside it, per rule 7 — a wrong
description that gets quietly fixed is a description nobody can tell was ever wrong.**

**A capture the frame does NOT prove, stated so a green run is not over-read:** #2, #3 and #4 render
below the fold on this screen and are not visible in it. They are built and the build is green; they
are not photographed. Closing them needs a scrolled frame, which is the next capture and is
**T-14**.

**One thing that changed behaviour and is not merely visual — read this before assuming it is safe.**
#1 makes `mode` a real field. It was a hardcoded `configExtras` value of `"perweek"`, and the web's
default is `ndays` (`app.js:8779`, verified on `feature/dosage-status-model`, not `master`). So the
default an untouched TRT save writes has moved. The config KEY SET is unchanged — `mode`, `nDays`
and `mlDrawn` moved from extras to fields under the same names and types — so the unique index still
sees eight keys. What moved is one VALUE, and it moved toward the web: an untouched iOS save and an
untouched web save now agree where they previously disagreed.
**Priority 9/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-03-current/06-calculator-trt-IB2245780.png` · web
`screens/30-calc-trt-result.png`.

**Functional — the app cannot do things the web can:**

1. ~~**No mode switcher.** The web leads with a three-way segmented control — `Every N Days` ·
   `Per Week` · `mL → mg`. iOS has no visible mode control at all, though the engine stores a
   `mode` in the saved config. A user cannot switch how they think about the dose.~~
   **BUILT `29a8ede`, photographed.** `ModeTab` in `CalculatorWebParity.swift`; the frame shows all
   three segments with `Every N Days` active. The engine needed no new cases —
   `CalculatorEngine.TrtMode` already had all three and `evaluate` hardcoded `.perweek`, so two of
   its three branches were unreachable from the phone. `shouldShow` now drives which fields the
   mode asks for, mirroring the engine branch for branch: the frame shows `EVERY N DAYS` rendered,
   which is the `ndays`-only field. **Not yet closed:** a saved config read back out of the database
   showing the chosen `mode` — that is **T-15**.
2. ~~**No compound search.** The web has a searchable, typeahead compound field with a magnifier icon
   over the full compound list. iOS has an `Ester` picker — a plain menu, fewer entries, no search.~~
   **BUILT `29a8ede`** — `CompoundCombobox`, a `.searchable` list in a sheet, replacing
   `.pickerStyle(.menu)` on every `stringPicker` in the app. **CORRECTION — "over the full compound
   list … fewer entries" IS FALSE.** `app.js:81` defines `ESTER_TYPE_OPTIONS` as seven strings and
   `CalcConst.esterTypes` is the same seven in the same order. Verified on
   `feature/dosage-status-model`, not just `master`. The real gap was search, the magnifier and a
   keyboard-operable listbox — never the contents. The replacement also removes the measured
   menu-picker overlap defect from these call sites; the numeric `.picker` sites still have it
   (**T-16**).
3. ~~**No link to the levels chart.** The web has a tinted card — `📊 See your levels over time →` —
   taking you from the calculator straight into the plotter with this protocol loaded. iOS has
   nothing connecting the two.~~
   **BUILT `29a8ede`** — `PlotLevelsCTA`. The calculator SET and the wording split are copied from
   `PLOT_CTA_CALC_IDS` verbatim, so BMI and free-T index do not get it. **Partial, and the shortfall
   is "with this protocol loaded":** the web's href carries `?from=<calcId>`; `AppRoute.calculator`
   takes a slug and nothing else, so this pushes the plotter EMPTY. Tracked as **T-17**, not
   silently absorbed.
4. ~~**No formula card.** The web shows `units = (per-shot dose ÷ vial strength) × 100` and then
   defines each term underneath — `per-shot dose`, `vial strength`, `× 100` — colour-coded. It is
   the thing that makes the number trustworthy rather than magic. Absent on iOS.~~
   **BUILT `29a8ede`** — `FormulaCard`, content transcribed from `IB_CALC_FORMULA` for seven slugs.
   The remaining slugs render no card rather than an invented one: the card exists to be checkable,
   so a wrong formula is worse than none.
5. **No FAQ.** The web carries an accordion of real questions — how to calculate the volume, which
   vial concentration to pick, the difference between the two modes. Absent on iOS.
6. **No related calculators.** The web ends with a horizontal card carousel — TRT EOD, TRT Microdose
   — with a one-line description each. Absent on iOS.

**Visual — the same information rendered differently:**

7. ~~**Number fields have no scale.** Every web numeric field carries a **tick ruler** beside the
   value showing the plausible range (`20 30 40 50 60 70` for vial strength, `10 15 20 25 30 35` for
   the dose). iOS has `−`/`+` steppers instead. The ruler tells you where your number sits; the
   stepper does not.~~
   **BUILT `29a8ede`, photographed** — `TickDrum`, visible on both `VIAL STRENGTH` and `WEEKLY DOSE`
   in the frame. **CORRECTION — "a tick ruler beside the value" understates the control.**
   `DrumPicker.tsx` calls it "the signature tactile control: a horizontal barrel of tick marks you
   drag, fling or click" and says every numeric input on the web is one. It is the PRIMARY INPUT,
   not an ornament next to one — so it is built as a draggable, snapping drum and the `−`/`+`
   steppers are REMOVED rather than left beside it. `step_up_<key>` / `step_down_<key>` are retired;
   `CalculatorWiringUITests.testStep_movesByTen` is re-pointed to `testRuler_tracksItsOwnField` in
   the same commit rather than left addressing dead identifiers. Values are the web's own arrays,
   not derived from the iOS field's range — those are what the field ACCEPTS, which is wider (iOS
   strength accepts 1…500 by 1; the web's ruler shows 10…400 by 10). Left-anchored selection matches
   the web's own maths, checked rather than assumed: `app.js:3404`, `return -idx * itemWidth`.
   **Not covered: the drag.** XCUITest cannot invoke an accessibility adjustable action, so
   drag-to-select is unproven — **T-18**.
8. ~~**Label placement.** Web puts the label in a grey pill to the **left** of the value, on the same
   row. iOS stacks the label above the field. The web row is denser and reads as one control.~~
   **BUILT `29a8ede`, photographed.** **CORRECTION — there is no grey pill.** Sampled per-pixel from
   `30-calc-trt-result.png`: the label area and the row both measure `#F1F1F4` at y=545 across
   x=70…500, so the "pill" is the ROW's own fill and not a separate one. The placement half of the
   difference (label left, same row) is right and is what was built; the pill half is not, and
   building it would have added a fill the web does not draw.
9. ~~**Value emphasis.** The web wraps the value in a heavy navy-outlined box — the number is the
   focus of the row. iOS renders it as ordinary text inside a bordered container.~~
   **BUILT `29a8ede`, photographed.** A RECESSED well, which the sampling settled and the wording
   did not: `#E6E6E9` inside a `#F1F1F4` row — the well is darker than the row, not a raised white
   box — with a `#243C73` border at 2pt. This is the one place in the app that does not use
   `fieldChrome`, and the reason is written at the call site: white-on-grey reads as raised and the
   web's is recessed.
10. ~~**Section labels.** The web uses small caps section headers — `SYRINGE SIZE` — above grouped
    controls. iOS uses sentence-case field labels throughout, so nothing groups.~~
    **BUILT `29a8ede`, photographed** — `CalcSectionHeader`, and the row labels went small-caps with
    it. `VIAL STRENGTH`, `WEEKLY DOSE`, `EVERY N DAYS` in the frame. `.textCase(.uppercase)` rather
    than pre-uppercased strings, so VoiceOver says the words instead of spelling them.
11. ~~**The result affordance.** Web: a full-bleed **bright cyan** sticky bar, `👁 Show result`,
    unmistakably the primary action. iOS: a pale teal `See your result` button sharing a row with a
    navy `Add`, so the two compete.~~
    **BUILT `29a8ede`, photographed.** `#00FFEE`, sampled at (300,2505). Navy label, because #00FFEE
    is 1.35:1 on white and cannot carry text; navy on it is 12.7:1. **The layout change is the point
    and it is bigger than the colour:** `Add` is no longer beside it. It stacks underneath, so the
    two stop competing — `Add` does not move into the sheet, because D5 requires the committing
    action wholly visible and the spec refuses a second commit path.
12. **Header.** Web: a breadcrumb — `InjectBuddy / Testosterone (TRT) Dose`. iOS: a back button plus
    a centred emoji-and-title. Different shape, and iOS's gives no sense of where you are in the
    product.

**Questionable — raise before building, do not silently drop:** the FAQ, the related-calculators
carousel and the breadcrumb exist partly to make the web rank in search. They may be worth less
inside an app. **That is the owner's call, not ours** — the standing decision is that nothing is
dropped for being hard, and "it's for SEO" is a reason to ask, not to skip.

**Done when:** each of the twelve is built, or recorded here with the reason it cannot be.

---

### T-01b … — every other screen, not yet compared
**Priority 9/10** · **Owner:** win · **Status:** open

**What:** twelve of the twenty iOS frames have no partner comparison yet. The reference set covers
dashboard (empty and populated), calendar, log-dose sheet, tools hub, add and confirm-start,
settings, and every calculator in both empty and result states.

**Note:** the reference set also has screens iOS has **no version of at all** — progress, cycle
planner, blood tests, chat, suggestions, peptide tracker. Those are features, not layouts, and they
subsume the old "what is the dashboard's v1 scope" question: **the answer is what the web does.**

**Done when:** each screen has its own `T-01x` entry with its difference list.

**Split, agreed 2026-08-04:** mac took the thirteen calculator screens — T-01a's twelve differences
are mostly chrome the web wraps around *every* calculator, so splitting them would have had both
sides derive the same list. Win took the shell: dashboard, calendar, tools hub, add/confirm,
log-dose, settings. Win's half is written up in `SHELL-PARITY.md`, which inlines the current iOS
layout and cites the web target by file so a builder needs nothing else open.

---

### T-01c — Dashboard (compared 2026-08-04) — **9 differences**
**Priority 9/10** · **Owner:** mac · **Status:** open

**What:** the iOS dashboard is the web's `saved` panel — the protocol grid — put on the front page,
while the web's actual default view was never built. `app/account/page.tsx:78-97` composes the
`upcoming` panel from `InjectionDayPicker`, `UpcomingDoses`, `MobileInjectionCount`, `SerumChart`,
`SiteRotation` and `LabHighlights`. **iOS built none of those six.** Plus: the primary metric is set
as a text row rather than at display size, the disclaimer is absent, and the header shows the brand
lockup where the web shows the screen name.

**Full list with the current iOS layout inlined: `SHELL-PARITY.md` §S-01.** Not restated here, so
there is one place to edit it.

**Sequencing:** difference #1 (site rotation) needed T-03, which is now done — the site vocabulary
and the web's own `nextSiteIdx` rotation already exist in `Core/Models/InjectionSite.swift`. Build
the card on top of that rather than deriving a second rotation.

**Done when:** each of the nine is built, or recorded in `SHELL-PARITY.md` with the reason it cannot
be.

---

### T-01d — Calendar (compared 2026-08-04) — **8 differences**
**Priority 9/10** · **Owner:** mac · **Status:** open

**What:** one paged month against the web's seven continuous (`CalendarView.tsx:311-312`, one back
and five forward); the week starts Monday against the web's Sunday (`CalendarView.tsx:48`); day cells
carry colour dots where the web carries compound names; no add affordance; the day sheet gives the
dose but not the draw volume or the site, where the web gives all three; no "How it works" and no
references; the month is stated twice and the screen name once.

**Full list with sources: `SHELL-PARITY.md` §S-02.**

**Do T-05 first.** `CalendarScreen` has no `.refreshable` at all where `DashboardScreen` has one, and
T-05's unmeasured cause — a large title owning the pull-down stretch — is inherited by anything added
here.

**Done when:** each of the eight is built, or recorded with the reason it cannot be.

---

### T-01e — Tools hub (compared 2026-08-04) — **7 differences**
**Priority 8/10** · **Owner:** mac · **Status:** open

**What:** a stock `.insetGrouped` list of titles against the web's cards, each with a category tag
and two or three lines saying what the calculator is for. No search, no count, no category jump.
**No brand token appears on the screen at all.** One of the seven is nearly free: `CalculatorCategory`
already defines a `subtitle` per category and `ToolsScreen` never references it.

**Full list with sources: `SHELL-PARITY.md` §S-03.**

**Done when:** each of the seven is built, or recorded with the reason it cannot be.

---

## T-02 — The web app leaves data behind when an account is deleted
**Priority 8/10** · **Owner:** pouroa · **Status:** filed

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

## ~~T-03 — iOS never records the injection site~~ — **DONE 2026-08-03**
**Priority 6/10** · **Owner:** mac · **Status:** done

**What:** `dose_log.site` is NULL on every iOS-written row. All fourteen web-written rows carry it.
The web derives its whole site-rotation model from that column — eight IM sites, six SubQ, a
3.5-day rest convention and a body map.

**Why it matters:** not a missing feature — a column iOS silently declines to fill. The damage is to
data the user already has rather than to a screen they do not.

**Root cause — (a), never collected in the UI.** Nothing was broken. `NewDoseLogPin.site`,
`OwnedDoseLogPin.site` and the `select` on the way back all existed and all carried the right key;
`LogDoseSheet` simply never passed one, by a decision written into its own header comment
("Deliberately the LEAN version … No body-site picker — `site` stays nil"). Every caller used the
`site: String? = nil` default, so the column was NULL by choice at the one place a human could have
answered it.

**Built:** `Core/Models/InjectionSite.swift` — the fourteen labels transcribed from the web's
`lib/account-schedule.ts` (`SITES_IM` / `SITES_SUBQ`), the per-calculator route mapping copied
branch-for-branch from its `deriveDose`, and the web's `nextSiteIdx` rotation. A picker in
`LogDoseSheet` showing only the selected protocol's track, opening on the next site in rotation and
saying so. 14 unit tests pin the vocabulary; a UI test drives the sheet on the device.

**The vocabulary is the whole risk, not the plumbing.** The web resolves a pin with
`p.sites.indexOf(pin.site)` and DISCARDS anything it cannot find — so "Left glute" would look
perfectly correct in the table and be exactly as useless to the rotation as the NULL was.

**Done — measured, not asserted.** `LogDoseSiteRoundTripUITests` tapped `R Delt` (the last row of
the IM track, deliberately NOT the `L Glute` the rotation suggested, so a decorative picker could
not pass) and logged. Row `92c3af8f` read NULL before the run and after it:

```sql
select d.id, s.calculator_type, d.dosed_on, d.draw_ml, d.site
from public.dose_log d join public.saved_dosages s on s.id = d.protocol_id
where d.user_id = 'c8926abc-52b0-41f3-8968-bc44f56e1dd1' and d.dosed_on = '2026-08-03';
```
```
92c3af8f-7dfb-4698-acc0-84ed62d76c73 | trt     | 2026-08-03 | 0.373 | R Delt
d5a4f448-81b6-433c-bd1f-65d15361f930 | peptide | 2026-08-03 | null  | null
```

The second row is the other protocol, untouched — the write went to the selected protocol only.

**Where the code is: `29a8ede`.** Not its own commit — that SHA is T-01a's, and it swept up the
five T-03 files (`InjectionSite.swift`, `LogDoseSheet.swift`, `InjectionSiteTests.swift`,
`LogDoseSiteRoundTripUITests.swift`, this file) because both sides were working the same tree at the
same time and the calculator commit staged everything dirty. Nothing is lost and nothing is wrong in
the tree — but the commit message describes only the calculator, so the SHA is written down here
rather than left to be found. **Two agents in one working tree cannot both use `git commit -a`;**
stage by path, or the other side's half-finished work ships under your message.

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

## T-06 — The web drops every `microdose` protocol on the floor
**Priority 5/10** · **Owner:** win · **Status:** open

**What:** `lib/account-schedule.ts`'s `deriveDose` has branches for `trt`, `eod`, `steroid`,
`peptide`, `semaglutide`, `tirzepatide`, `retatrutide`, `bpc157`, `bpc157blend`/`blend` and `hcg`,
and returns `null` for anything else. iOS ships a **TRT Microdose** calculator that saves
`calculator_type = 'microdose'`, and `deriveProtocols` discards a null — so the row is saved, is
`is_active`, and then does not exist as far as the web is concerned.

**Why it matters:** a microdose protocol saved on iOS gets no dashboard card, no schedule, no site
track, no inventory and no place in the rotation on the web. It is not a rendering difference; the
protocol is absent. Found while mapping calculator types to injection routes for T-03 — iOS now
routes `microdose` to the IM track locally so it at least logs a site the web could read if the row
ever reached it.

**Done when:** `deriveDose` handles `microdose` (it is TRT's math), or the web states why it will
not and iOS stops offering the calculator.

## T-07 — Two of the three iOS log paths still write a NULL site
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** T-03 fixed `LogDoseSheet`, which is the only path that asks the user anything. The
dashboard's "Mark taken" (`DashboardViewModel.markTaken`) and the calendar's day toggle
(`CalendarViewModel.toggleTaken`) are one-tap affordances holding a `DoseOccurrence` and no site,
and both still send `NewDoseLogPin(for: occurrence)` with the `site: nil` default.

**Why it was left:** the web's equivalent one-tap "done" DOES write a site — but it renders the
suggested site next to the button first (`TodayCard.tsx`), so the user can see and change what is
about to be recorded. iOS shows nothing there. Writing an unseen suggestion would put body
locations the user never chose into the rotation model, which is worse than the NULL: a NULL is
absent data, an invented site is wrong data that the web's heat map will colour a muscle with.

**Done when:** those two surfaces show the suggested site and let it be changed, as the web's card
does — then they write it. Not before.

## T-08 — iOS never touches `dose_log.updated_at`
**Priority 2/10** · **Owner:** mac · **Status:** open

**What:** `dose_log.updated_at` is `NOT NULL DEFAULT now()`, and the web's `/api/dose-log` sets it
explicitly on every upsert and patch. iOS's upsert sends only the dose columns, so on a
conflict-update the column keeps its INSERT value.

**Measured 2026-08-03:** row `92c3af8f` was updated with a site at 05:47 UTC and still reports
`updated_at = 2026-08-03 09:22:44` — its creation time on the previous day's row.

**Why it matters:** small, but it is a column that exists to answer "when did this last change" and
it answers wrongly for exactly the rows iOS touches. Anything syncing or auditing on it will skip
them.

**Done when:** `OwnedDoseLogPin` carries `updated_at` and a re-logged dose shows a moved timestamp.

## T-09 — The Calendar tells the user nothing is due when it has simply not looked
**Priority 7/10** · **Owner:** mac · **Status:** open

**What:** the projection window is 30 days while the grid renders whole months
(`CalendarScreen.swift` header). A day past the window draws **with no dots — pixel-identical to a
day with nothing scheduled.** The web projects one month back and five forward
(`CalendarView.tsx:311-312`), so five of the seven months a web user can see are blank on iOS.

**Why this is not just another line in T-01d:** every other calendar difference is the app showing
*less*. This one is the app showing something *false* — a dosing screen answering "is anything due"
with "no" when the honest answer is "not calculated". A user planning a month ahead is told their
schedule is empty.

**Done when:** either the window covers what the grid renders, or unprojected days are visibly
distinct from empty ones — photographed, at a date past the window.

## ~~T-10 — Windows had no checkout of the iOS app~~ — **RESOLVED 2026-08-04**
**Priority 7/10** · **Owner:** win · **Status:** done

**What:** `Projects\injectbuddy-ios` on Windows has no `.git`; git commands there resolve up to
`C:\Users\PFrew\.git` (origin `_agent-system`) and the whole iOS tree is untracked in it. Newest file
in its `Sources/` was **2026-08-02 07:01** against mac's `3fe7302` — a two-day-old copy.

**What it cost, before it was found:** the stale copy still listed `.bmi` and `.freeTestIndex` in
Tools after mac had removed and photographed them. That is the concrete damage from an untracked
copy, recorded so the fix is not undone later.

**CORRECTED BY MAC, 2026-08-04 — the T-03 half of this entry was wrong and is withdrawn.** It read:
*"it showed T-03 as open after it had been closed with evidence — on the strength of which win sent
mac to spawn a subagent on finished work."* T-03 was **genuinely open** when that instruction was
given, and the subagent was correctly dispatched. Proof, from this repo rather than from either
side's recollection:

```
$ git show 0727e83:TASKS.md | grep -A 2 '^## T-03'
## T-03 — iOS never records the injection site
**Priority 6/10** · **Owner:** mac · **Status:** open

$ git log -S'~~T-03' --format='%h %ad %s' --date=format:'%Y-%m-%d %H:%M' -- TASKS.md
29a8ede 2026-08-03 22:51 T-01a: nine of the twelve TRT calculator differences, built
```

`0727e83` is the tip this session started from; the strike-through first appears in `29a8ede`, which
is **mac's own commit from today** and carries the subagent's work. What happened is the reverse of
what was recorded: win cloned at `29a8ede`, which already contained the closure, and read a
same-session strike-through as a pre-existing one. The subagent produced `InjectionSite.swift`, the
picker, 14 unit tests, a device round-trip proving `R Delt` on row `92c3af8f`, and T-06/T-07/T-08.
None of it was wasted.

**Left standing deliberately:** everything else in this entry, and the rule it produced. The stale
tree was real and the clone was the right fix. This correction narrows what it cost; it does not
excuse it — and per rule 7 the wrong version stays visible above rather than being deleted.

**Resolved:** cloned to `C:\Users\PFrew\Projects\injectbuddy-ios-repo`, branch
`feature/tabview-shell` at `29a8ede`. Windows can now cite a SHA, so rule 7 is satisfiable from both
sides.

**Still open, and it is the dangerous half:** `Projects\injectbuddy-ios` still exists as an untracked
copy holding an older `TASKS.md`. **Two files named TASKS.md, one of them a decoy.** It must be
deleted or made a symlink to the checkout — owner's call, since it also holds `mac-docs/` and some
Windows-only notes. Tracked as **T-50**.

## T-11 — The cycle plotter ships and the Tools tab cannot reach it
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** `.cyclePlotter` is in no `CalculatorCategory`'s member list, and `ToolsScreen` renders only
those members — so the plotter has no row on the browse surface. The calculator itself ships (frame
`27-calculator-plotter`).

**Confirmed on mac's tree 2026-08-04**, not read off the stale Windows copy. Two details that sharpen
it: `isListed` is **true** for the plotter — only `bmi` and `freeTestIndex` are deliberately withdrawn
— so this is a slug that is *meant* to be browsable and was left out of the only list that browses.
And `ToolsScreen`'s own header comment says `members` "had never enumerated the plotter at all", so
the file already knows and no task existed.

**Renumbered from T-06**, which was already taken by the microdose finding.

**Done when:** the plotter is reachable from Tools and photographed there.

## T-12 — TRT EOD is the missing mode switcher wearing a second screen
**Priority 6/10** · **Owner:** pouroa decides, mac builds · **Status:** open

**What:** there is no TRT EOD calculator on the web and there never was one. `public/legacy/` holds
21 calculator directories and the only TRT ones are `trt-calculator` and
`trt-microdosing-calculator`. EOD is a *frequency inside* the TRT calculator —
`trt-calculator/index.html:296`, "Supports weekly, E3.5D, and EOD dosing", and the live site serves
the switcher today (`Every N Days` / `Per Week` / `mL → mg` on
`https://www.injectbuddy.com/trt-calculator/`). iOS's `.eod` spec is the TRT spec with the help text
"Hardcoded every-other-day interval (3.5 injections/week)".

**So T-01a difference #1 and this screen are one defect seen from two ends:** iOS has no mode
switcher, so it grew a screen to hold the mode. Building the switcher while leaving the screen up
ships the mode twice.

**Why it is the owner's call:** it is a shipping screen. It does not get deleted on the strength of a
source reading.

**Done when:** the owner has decided whether EOD collapses into the TRT calculator once the switcher
exists, and the decision is written here.

## T-13 — Four items exist partly to rank in search; decide them together
**Priority 4/10** · **Owner:** pouroa · **Status:** open

**What:** T-01a parked three — the calculator FAQ, the related-calculators carousel, the breadcrumb.
`SHELL-PARITY.md` §S-03 adds the Tools hub's per-card guide links and its "How calculators work"
FAQ. Those pages are public and indexed, so "it is for SEO" is a real argument there.

**It is not a real argument on the calendar.** `app/calendar/page.tsx:8` sets
`robots: { index: false, follow: false }`. Its "How it works" text and three citations — the 2018
Endocrine Society guideline, the WEGOVY label, a 2016 ester-pharmacology paper — cannot be for
search, because search never sees them. **That one is for the user and is being built** (T-01d #7).

**Correction to T-01a #6 while this is parked:** the carousel's contents are not "TRT EOD, TRT
Microdose". The web's own calculator navigation is TRT Dose · TRT Microdose · Semaglutide ·
Tirzepatide · HCG, then Peptide Reconstitution · Peptide Dosage · BPC-157 · BPC-157 + TB-500 Blend ·
BMI · Cycle Plotter. Take the target from the source.

**Why together:** deciding them screen by screen is how a product ends up explaining itself in three
places and nowhere.

**Done when:** each of the four is marked build or won't-build, with the reason, here.

## T-14 — T-01a's three below-the-fold differences are built but unphotographed
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** the T-01a capture is an at-rest frame, so it proves #1, #7, #8, #9, #10 and #11 and says
nothing about #2 (compound search), #3 (levels link) and #4 (formula card), all of which render
below the fold. They are built and the build is green.

**Why it is its own task and not a footnote:** "built, green, and photographed six of nine" is a
partial, and a partial that is not written down reads as done to the next person. This project has
already filed a frame that was a photograph of the previous screen.

**Done when:** a scrolled frame shows the combobox, the tinted plotter link and the formula card,
and the combobox is shown OPEN with its search field — a closed combobox is indistinguishable from
the menu picker it replaced.

## T-15 — No saved config has been read back since `mode` became a real field
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** T-01a #1 moved `mode`, `nDays` and `mlDrawn` out of `configExtras` and into real fields,
and moved the default from `perweek` to the web's `ndays`. `configJSON()` and
`values(fromConfig:)` were both updated. **None of that has been observed against the database.**

**Why it matters more than it looks:** the unique index covers the WHOLE config, so the key set and
the types are what decide whether an iOS save is the same protocol as the equivalent web row or a
different one. A `mode` that serialised as a number, or a `nDays` that went missing because it is
now mode-gated in the form, would not fail a build and would not fail the unit suite — it would
quietly write a protocol the web reads as new. Exactly the shape of the config defects already
closed on this file (hcg, tirzepatide, retatrutide).

**Done when:** a TRT protocol is saved from the device in each of the three modes and the rows are
SELECTed back, showing eight keys with `mode` as the chosen string. Paste the rows.

## T-16 — The numeric menu pickers still draw outside their own chrome
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** the measured overlap defect — a picker's selected value drawing over the label above it at
large text, `Oxandrolone (Anavar)` overlapping `Compound` by 148.6 x 49.3pt on `IB2245752` — was
recorded against "12 picker fields across 8 calculators". T-01a #2 removed it from the
`stringPicker` sites by replacing them with `CompoundCombobox`. **The `.picker` (numeric) sites are
untouched and still have it** — TRT's own `Frequency` is one.

**Why it is now easier, not harder:** the note said the fix was "replacing the style with a `Menu`
whose label we lay out ourselves… a change to a control on 12 call sites". `CompoundCombobox` is
that control, built and shipping. What remains is pointing the numeric sites at an equivalent that
carries a `Double` instead of a `String`.

**Done when:** a frame at AX5 of a numeric picker showing the value inside its own chrome, and
`LeafOverlapUITests` green on the call sites it names.

## T-17 — The levels link opens the plotter empty
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** T-01a #3's difference says the web link takes you "into the plotter with this protocol
loaded". The web href is `/cycle-plotter/?from=<calcId>`. iOS pushes `.calculator(.cyclePlotter)`
and nothing else, so the user arrives at an empty plotter and re-enters the compound, dose and
interval they just typed.

**Why it was shipped anyway rather than held:** the link with no context is still the only route
from a calculator to the plotter, and — see T-11 — currently the only route to the plotter at all.
Empty beats absent. It is recorded so "with this protocol loaded" is not quietly treated as done.

**Done when:** `AppRoute` can carry the calculator's values to the plotter, and a frame shows the
plotter opening on the compound and dose the calculator held.

## T-18 — Nothing tests that the tick drum can be dragged
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** `TickDrum` replaced the `−`/`+` steppers as the primary numeric input on every calculator.
`testRuler_tracksItsOwnField` proves the ruler reports its own field's value and that two drums are
not crossed. **It does not touch the drag.** `TickDrum` publishes one `.adjustable` element and
XCUITest has no direct way to invoke an accessibility adjustable action.

**Why it matters:** the control the user actually operates is the one with no coverage. The retired
steppers had a real behavioural test (`step_up_mgWeek` moves `mgWeek` by 10 and does not move
`strength`); trading that for a value-tracking assertion is a net loss in coverage on a dosing
input, and saying so is cheaper than discovering it.

**Done when:** either a swipe on `drum_mgWeek` is shown to change the field by a known number of
gradations, or — better — the drag maths is extracted into a testable pure function and unit-tested,
with the UI test keeping only the wiring assertion. Whichever, it must be shown RED first: a drag
test that passes against a drum that ignores drags is the failure mode this project keeps finding.

## T-19 — Eight calculators the web has and iOS does not
**Priority 5/10** · **Owner:** pouroa · **Status:** open

**What:** the reference set and the live site carry eight calculators with no iOS counterpart —
**ftv** (42), **reverse** (43), **blend** (44), **glp1titration** (45), **femalehrt** (46),
**nootropic** (47), **bioavailability** (49), **e2estimator** (50). `public/legacy/` confirms them
as real pages: 21 calculator directories against the 15 slugs `CalculatorSlug` defines.

**Why it is filed separately from T-01b rather than inside it:** T-01b is "compare each screen and
list its differences". These have no iOS screen to compare — they are absent features, the same
category as progress, cycle planner, blood tests, chat, suggestions and the peptide tracker. Putting
them in a difference list would make eight missing products look like eight layout notes.

**The standing decision points one way and the effort points the other**, which is why this is the
owner's: *iOS matches the web in every way it can, nothing dropped for being hard.* Eight new
calculators is not a parity pass, it is a roadmap.

**Done when:** the owner rules on each — built, or recorded here with the reason it will not be.

## T-20 — The last field row sits half under the pinned bar at rest
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** in `docs/ui-audit/2026-08-04-t01a/20-calculator-trt-default.png`, the `EVERY N DAYS` row
is cut across the middle by the top edge of the pinned result bar: the label and the value well are
readable, the row's own ruler is not. At rest, unscrolled, at default type size.

**What it is NOT:** a missing space reservation. The bar is a `safeAreaInset`, it does reserve its
height in the scroll, and the form scrolls clear of it — this is the at-rest position of a form
whose earlier fields already fill the viewport, which is the same behaviour recorded against
`control_syringeMl` before this change and is documented at length in `CalculatorScreen`.

**What IS new, and why it is filed rather than waved through:** T-01a made every numeric row TALLER
— label, value and a ruler where there was previously a label above a field. So more of the form is
below the fold than before, and the row that lands on the boundary now has a control in its lower
half rather than whitespace. A half-visible ruler reads as a full ruler whose range stops at the
plate.

**Done when:** measured, not adjusted by eye — the straddle re-checked at default and AX5 against
`PinnedBarReachabilityUITests`, and either shown to leave every control reachable, or the form's
bottom inset increased by the drum's own measured height.

## ~~T-50 — Two files named TASKS.md, one of them a decoy~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** win · **Status:** done

**What:** `Projects\injectbuddy-ios` (untracked copy) and `Projects\injectbuddy-ios-repo` (the real
checkout) both carry a `TASKS.md`, a `CLAUDE.md` and a `Sources/`. The untracked one is the older.

**Why it matters:** it has already caused one wasted subagent run and one wrong instruction from
Windows to mac — see T-10. A stale copy that *looks* authoritative is worse than no copy, because
nothing about opening it says which one you have.

**Complication:** the untracked tree is not pure duplication — it also holds `mac-docs/` and some
Windows-only notes that are not in the repo. So this is not a blind delete.

**Done when:** the untracked tree is gone, or reduced to only the files that exist nowhere else, with
its `TASKS.md` and `Sources/` removed either way.

**Done — measured before deleting, not after.** All **324** files in the tree were content-hashed
with `git hash-object` and each hash tested against every object in this repo. **320 were already
preserved** — the docs markdown on the `docs/*` branches (`docs/account-deletion-spec` alone carries
63 `.md`), the capture PNGs on this branch. Four were not, and two of those were superseded copies of
`TASKS.md` and `SHELL-PARITY.md`. The other two were rescued to this repo in `ba6dfd5`:

- `WIN-SIDE-README.md` — the Windows orientation. Carries things written down nowhere else: the `M:`
  SSHFS mount to the Mac's home (read-only; git operations fail over it), the owner's ship-the-MVP
  instruction and its three ship-blockers, and the usage split showing **BMI and Free T Index at zero
  users**.
- `tools/verify-math.js` — an independent recompute of the 14 golden vectors in a different language
  from the Swift engine, so a transcription error in the EXPECTED values cannot hide. Run before the
  delete: `ALL VECTORS PASS`.

The directory itself could not be removed — it is this session's working directory and the OS holds
it — so it is **emptied, zero entries**. The decoy `TASKS.md` is gone, which was the point. The empty
folder disappears on the next session.

## T-51 — iOS logs no injection time, so the web plots its doses at an assumed noon
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** `NewDoseLogPin` (`Core/Models/Models.swift:208-219`) encodes four columns — `protocol_id`,
`dosed_on`, `draw_ml`, `site`. The web also writes `injected_at`, `injection_time` and
`injection_timezone` (`DashboardContext.tsx:352`, `DoseHistory.tsx:287`).
`grep -rn "injected_at" Sources/` returns nothing.

**What it actually costs — checked, not assumed.** It does **not** break the serum chart.
`SerumChart.tsx:169-178` falls back to ``new Date(`${row.dosed_on}T${row.injection_time || '12:00'}:00`)``
so the point still plots. But every iOS-logged dose sits at **noon** on a curve whose own comment
says it exists so that "logging one adds the time, so the curve jumps the moment it lands" — and that
fallback string carries no zone, so it is parsed in **the viewer's** local time. The same iOS row
lands at a different absolute moment for a reader in Auckland than in New York. `observedIntervalFor`
then derives observed cadence from those timestamps, quantised to whole days.

**Same shape as T-03** — a column iOS declines to fill that a web feature reads — but this degrades a
curve rather than leaving a hole, which is why it is a 5 and T-03 was a 6.

**Done when:** a dose logged from iOS carries a time and a zone, read back from the database, and the
web chart plots it at that time rather than at noon.

## T-52 — The log-dose sheet cannot record a dose that was not the planned one
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** the web's sheet has an editable `DOSE AMOUNT` field. iOS has none: `draw_ml` is derived
from the selected protocol's config by `DoseVolume.perInjectionMl` and the user is asked nothing.

**Why it matters:** a partial, split or adjusted dose gets recorded **as if it were the full one**.
This is the write path of a dosing tracker, so it is the user's own history being rounded to the
plan — and every downstream surface that reads it, including the serum chart, then models a dose
that was not taken.

**Not the same as the volume picker that "lean" deliberately dropped.** That decision was about not
asking for a number the app can derive. This is about being unable to correct it when the derivation
is wrong.

**Done when:** the sheet accepts an amount, defaulted to the derived one, and a dose logged with a
changed amount reads back with that amount.

## T-53 — The log-dose sheet offers two protocols the user cannot tell apart
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** `docs/ui-audit/2026-08-03-current/08-logdose-sheet-IB2245782.png` lists **`TRT Dose`
twice**, both with no supporting line, above cards that do carry one. They are legitimately distinct
rows — the dedup index is `(user_id, calculator_type, config)`, so two TRT protocols with different
configs are allowed — but nothing rendered distinguishes them.

**Why it matters:** the user chooses which dose to log by guessing. It is the most serious item on
S-04 for that reason, and it is not a styling difference.

**Second, smaller, same screen:** the cards that do have meta mix conventions inside one list —
`TB-500 · 350mcg/inj` is per injection, `Masteron · 300 mg/wk` and `Testosterone Cypionate · 0mg/wk`
are per week, `TRT Dose` has none. Three conventions and a blank, stacked.

**Done when:** every card in that list carries a line that distinguishes it from every other card, in
one unit convention — photographed against an account holding two protocols of the same type.
