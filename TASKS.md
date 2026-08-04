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

## T-05 — Calendar pull-to-refresh did nothing — **MEASURED 2026-08-04, candidate (A) is DEAD**
**Priority 3/10** · **Owner:** mac · **Status:** doing — the diagnosis is closed, the affordance is not back yet

**What it was:** the gesture armed but issued zero requests — confirmed against the database's own
API log — while the identical gesture on an identically-shaped Dashboard view re-read one minute
earlier in the same run. The affordance was removed rather than shipped as a lie.

**The leading candidate was (A):** `RouteContent` gives the Dashboard an inline title and every other
tab root a large one, and a large title owns the pull-down stretch above a plain ScrollView. It was
the strongest of three because it is one level up from either screen, which is why comparing the two
files showed nothing.

### ~~(A) the large title owns the pull-down stretch~~ — **DISPROVEN, on the device**

Apparatus: `T05PullToRefreshUITests` at `78dc507`. Two DEBUG flags — `T05_EXPERIMENT=1` arms the
pull and publishes a reload counter incremented BEFORE its await; `CALENDAR_INLINE_TITLE=1` flips
the Calendar to the Dashboard's title so the two roots differ by nothing. One build, two runs.

```
CONTROL   (large title)  T05 inline=false before=1 after=2   ← THE PULL FIRED
CANDIDATE (inline title) T05 inline=true  before=1 after=2
```

**The control refreshed.** The defect does not reproduce on this build under the shipping
configuration, so the inline title is not the mechanism and **(A) is not established by the
candidate run** — both conditions behave identically.

**The control test is RED and that red is the result, not a broken test.** It asserts "no increment"
because that is what the defect predicts; it got an increment. Written that way deliberately, and
the outcome table was written into the suite BEFORE the run so the result could not be read to suit
whatever came back.

**What most likely fixed it, and it is already in the tree:** `CalendarScreen`'s own note names it —
batch 4 item 1 stopped `CalendarViewModel.load` blanking to `.loading` on a refresh, so the
ScrollView that owns the refresh control is no longer destroyed underneath it mid-pull. That note
calls it "the cheapest thing to try first". It appears to have already happened, as a side effect of
an unrelated change, and nobody re-measured.

**The consequence that matters most is a fear cancelled.** The reason this stayed open with the
affordance already removed was: *"if that mechanism is real, any future screen with a large title
will silently not refresh."* **It is not real.** Large titles do not break `.refreshable` on this
app, so T-54's header work is not blocked by this and does not need to route around it.

**WHAT THIS DID NOT MEASURE, stated so the run is not over-read.** The counter proves the CLOSURE
ran — which is strictly narrower than the original evidence, and deliberately so: the API log could
not distinguish "the closure never fired" from "it fired and the request was suppressed downstream".
This separates them and answers the first. **It does not prove a request reached Supabase.**

**Done when** (the remaining half): `.refreshable` is restored unconditionally — not behind
`T05_EXPERIMENT` — and a pull is shown to produce an actual read in the API log, the same observer
that condemned it. Until that, the affordance stays off: this project removed it for lying once and
a closure count is not a re-read.

**Candidates (B) and (C) are moot rather than disproven** — (B) the harness's scroll target, (C)
`reload()` mutating @State before its await. Neither needs killing now that the behaviour is correct
under both titles, but both stay written down in `CalendarScreen` in case the defect returns.

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

## T-41 — Flipping the peptide dose unit multiplies the dose by 1000
**Priority 9/10** · **Owner:** mac · **Status:** open

**What it does now:** the Peptide calculator has a `Dose unit` picker (`doseUnitMcg`, 1 = mcg,
0 = mg) and a `dosePerInj` number field defaulting to **500** with range `0...10000` and quick chips
`250 · 500 · 750 · 1000 · 2000`. Flipping the picker from mcg to mg **changes nothing about the
number in the field**. 500 mcg becomes 500 mg. The engine then calculates for 500 mg, and every
number on the screen — draw volume, units, weekly total, doses per vial — is consistent with a dose
**1000× larger than the one the user entered**.

**Verified, not inferred.** `grep -rn 'doseUnitMcg' Sources/` returns six sites and every one is a
READ: the evaluate call, `configOmittedKeys`, `configExtras`, a comment, `values(fromConfig:)` and
the picker's own definition. Nothing writes `dosePerInj` when the unit changes, and the field's
`range` is a single fixed `0...10000` that does not move with the unit either.

**The web does convert.** `PeptidePage.handleUnitToggle` divides/multiplies `dosePerInj` by 1000 and
re-bounds the field on every flip. This is not a feature iOS lacks — it is a conversion iOS drops
silently on a field it is still willing to calculate from.

**Why this is a 9 and not a 6.** The screen looks completely normal in the wrong state: no warning,
no impossible-looking figure, and the quick chips are plausible in BOTH units. Peptides are the
second-largest cohort in production (`peptide 16`, plus `bpc157 4`). And unlike a layout defect this
one is on the maths path — it reaches the saved protocol and the logged dose.

**Found by:** the T-01b comparison pass, and verified directly rather than taken on report.

**Done when:** flipping the unit converts the value and re-bounds the field, matching
`handleUnitToggle`; a unit test pins mcg→mg→mcg round-tripping to the original number; and the
behaviour is shown on the device — set 500 mcg, flip to mg, photograph the field reading 0.5.

## T-42 — The plotter labels a fabricated number as a lab result
**Priority 9/10** · **Owner:** mac · **Status:** open

**What it does now:** `CyclePlotterViewModel.rebuild` multiplies the curve by
`CalculatorEngine.testoNgdlFactor = 13.5` whenever every selected compound is a testosterone, and
`CyclePlotterScreen:48` titles the axis **`Estimated level (ng/dL)`**. The frame peaks around
1,500 for 100 mg/week Test E — exactly the units and the range of a real serum testosterone result.

**What the web says, and it is addressed to us.** `spec/math-spec.md` §4.1 on
`feature/dosage-status-model`:

> **Units.** This yields **mg-equivalents of active drug, not ng/dL.** … the chart is labelled in mg
> and must never claim a lab number. **A port must not add a unit conversion here.**

Both halves verified in place rather than taken on report: `grep -rn 'testoNgdlFactor' Sources/`
and `git show FETCH_HEAD:spec/math-spec.md`. **iOS does the exact thing the shared spec forbids, in
a sentence written for ports.**

**Why it is a 9.** Every other parity item is the app showing less than the web. This one shows
something the web deliberately refuses to show, wearing the units of a measurement the user can go
and have taken. A number labelled ng/dL invites comparison against real bloodwork — and a user
whose lab result disagrees with this curve has been given a reason to change a dose.

**It is not the only divergence on this screen.** iOS derives `ka` by bisecting for a per-compound
`tmax` where the web uses `ka = ln2 / max(0.01, halfLife × 0.25)`, and it skips the web's
`SMOOTH_FRAC = 0.5` moving average entirely. Both stand.

**~~and its compound table — commented "verbatim from app.js `PLOTTER_COMPOUNDS`", a symbol that
does not exist in the web tree — disagrees with `spec/compounds.json` on 15 half-lives and 4
units.~~ WITHDRAWN 2026-08-04, and the withdrawal is more useful than the claim was.**

`PLOTTER_COMPOUNDS` **does** exist — `public/app.js:10713` on `feature/dosage-status-model` — and it
carries a `tmax` on every one of its 31 rows. iOS's first three entries (`test-e` 4.5/2.0, `test-c`
5.0/2.5, `test-p` 0.8/0.5) match it to the digit, so **the "verbatim from app.js" comment in
`CalculatorCatalog` is accurate and iOS's tmax values have a real web origin.** Checked directly
with `git show FETCH_HEAD:public/app.js`; I had repeated an agent's claim without verifying that
half, having verified only the ng/dL half above. Recorded rather than quietly deleted, because the
lesson is the transferable part: I checked the finding that sounded severe and passed on the one
that sounded incidental.

**What is actually true is worse for the web than for us.** There are TWO compound tables and they
disagree: `PLOTTER_COMPOUNDS` (31 rows, has `tmax`, what the live plotter runs on) and
`spec/compounds.json` (31 rows, no `tmax`, whose own `$comment` claims it is *"the single source of
truth for compound half-lives across web, iOS and Android"*). Of 19 name-comparable rows, 13
disagree — Tren A 1.5 vs 3.0 (**2×**), PT-141 0.113 vs 0.5 (**4.4×**). The remaining 12 do not match
by name at all because the tables use different id vocabularies (`eq` vs `boldenone`), which is why
nothing has ever flagged it. Filed by win as **T-60**.

**Consequence for this task: DO NOT reconcile iOS's table to `spec/compounds.json`.** Doing so would
move iOS away from what the live plotter actually does, on the authority of a file the live plotter
ignores. T-60 closes first.

**Done when:** the axis is labelled in the units the model actually produces and the ng/dL factor is
gone, OR the owner rules that iOS keeps a calibrated estimate — in which case it says on the screen
that it is not a lab value. The half-life and unit table is reconciled against `spec/compounds.json`
and the "verbatim from app.js" comment is corrected, since it cites a symbol that does not exist.

## T-43 — Flipping the Free T Index unit does not convert the value either
**Priority 8/10** · **Owner:** mac · **Status:** open

**What it does now:** the same defect as T-41 on a second screen. The total-testosterone unit picker
changes the unit and leaves the number, so the shipped default turns **FAI 40.0 "Normal" into 1.4
"Low"** with no blood value changed.

**The web converts, and its own source names the exact consequence** — `changeTtUnit` carries a
comment about "a 28.84× wrong FAI/band". So this is a known, annotated hazard on the web that the
port dropped.

**Why it is filed separately from T-41:** same shape, different screen, different conversion factor,
and Free T Index is currently WITHDRAWN from Tools — so it cannot be photographed (T-55) and a user
cannot reach it today. That is the only reason this is an 8 and T-41 is a 9.

**Done when:** flipping the unit converts the value; a unit test pins the round trip; and the FAI
band is shown not to move when only the unit changes.

## T-44 — The steroid calculator offers injectable inputs for oral-only compounds
**Priority 7/10** · **Owner:** mac · **Status:** open

**What it does now:** `28-calculator-steroid.png` opens on **Oxandrolone (Anavar)** — `cls:'oral'`
in the web's `IB_STEROIDS`, `canInject: false` in iOS's own `SteroidCatalog` — showing a vial
strength of 200 mg/mL and a syringe barrel, and `evaluate` returns **0.75 mL / 75 units for a
tablet**. The picker enumerates `SteroidCatalog.all` unfiltered; five of the twelve are oral-only
and the web has no injectable path to any of them.

**iOS already holds the flag it needs.** `canInject` exists and is correct; nothing consults it.

**A second wrong number on the same screen:** the ester is unpickable. The web expands esters into
the compound dropdown as separate entries ("Trenbolone Enanthate"); iOS forces `esters.first`, so
300 mg/week Tren E reports **261 mg active instead of 213 mg — 22.5% high**.

**Done when:** an oral compound renders no injectable inputs and no draw volume, the ester is
selectable, and the Tren E case is shown returning 213 mg.

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

## T-54 — Every shell screen's header says the brand where the web says the screen
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** on the web, the top bar names the screen you are on — `Dashboard`, `Injection Calendar`,
`Add a protocol` — often with a breadcrumb back to where you came from (`‹ Dashboard`). On iOS every
tab root shows the same brand lockup, `injectbuddy`, and the screen name appears below it as a large
title, or not at all.

**Why it is one task and not four:** it was written up separately in `SHELL-PARITY.md` §S-01 #9,
§S-02 #8 and §S-05 before it was obvious that all three are the same decision applied five times.
Fixing it screen by screen would produce five slightly different headers.

**Second recurring item, folded in here for the same reason:** the raised centre `Log dose` hero is
**teal** on the web and **navy** on iOS, on every screen that shows the tab bar. Teal is the web's
primary-action colour and navy is its icon/label colour; iOS has the pair inverted. Same inversion
appears on the log-dose sheet's own CTA (S-04 #6).

**Careful — this one interacts with T-05.** `RouteContent` gives the Dashboard an inline title and
every other tab root a large one, and that difference is T-05's leading candidate for the dead
pull-to-refresh. **Whatever is done here changes the thing T-05 is trying to measure**, so measure
T-05 first or the experiment is spoiled.

**Done when:** one header treatment names the screen on every shell root, photographed across all
five, and the hero matches the web's colour.

## T-55 — Two screens cannot be photographed, so nothing about them can be verified
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** three surfaces have no current frame, for two different reasons.

**a) `bmi` and `freetest` are unphotographable while withdrawn.** `isListed` is false for both, so
Tools cannot reach them — and the capture harness navigates by tapping a Tools row. Their only frames
predate T-01a. **Found by mac during the 2026-08-04 sweep and reported in the channel; filing it,
because rule 6 says a defect found while doing a task is added here immediately and this one was
carried in a message.** It is a hole in the harness, not in the sweep: any calculator that is
withdrawn from Tools becomes unverifiable by the same mechanism, so this recurs the next time
something is withdrawn.

**b) Settings has not been photographed since 2026-08-01.** Absent from `2026-08-02-current`,
`2026-08-03-current` and `2026-08-04-post-t01a`. The one frame,
`archive/2026-08-01/08-settings-default.png`, predates everything built since, so `SHELL-PARITY.md`
§S-06 cannot be written.

**c) Confirm-start has no iOS frame in any sweep**, while the web reference
`screens/05-add-confirm-default.png` exists. Same consequence: uncomparable.

**Why it matters beyond the three:** this project's whole standard is that nothing closes without a
photograph or a query. A screen the harness cannot reach is a screen that can never be closed — so
the gap is not "three missing images", it is three surfaces permanently exempt from the bar
everything else is held to.

**Done when:** the harness can reach a calculator that is not listed in Tools, and Settings and
confirm-start appear in the sweep.

## T-56 — The rig's lock does not survive a killed capture run
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** the full sweep takes **972 seconds**. Mac's first attempt on 2026-08-04 hit a 10-minute
command timeout; the process was SIGKILLed and **the lock trap did not run**, leaving the rig locked
with nothing holding it. It was released by hand.

**Why it matters:** the rig is the one serialised resource in this project — every device check goes
through it. A lock that leaks whenever a run is killed will strand it again, and the next person to
hit it has no way to tell a leaked lock from a live run. **Carried in a message; filed here per rule
6.**

**Done when:** a killed sweep leaves no lock — demonstrated by killing one — or the lock records its
owning pid so a stale one is recognisable.

## T-57 — The web silently drops two protocol types, and three ACTIVE protocols are invisible today
**Priority 7/10** · **Owner:** win · **Status:** open

**What:** `lib/account-schedule.ts`'s `deriveDose` returns `null` for any `calculator_type` it has no
branch for, and `deriveProtocols` discards a null — `if (!dose) return`, with **no `console.warn`, no
Sentry or PostHog capture, and no user-facing message**. The row simply vanishes.

T-06 filed this for `microdose`. **The measurement says microdose is the least of it.** Queried
`public.saved_dosages` 2026-08-04:

| type | rows | active | active users |
|---|---|---|---|
| `femalehrt` | 3 | **2** | 1 |
| `oilblend` | 1 | **1** | 1 |
| `microdose` | 2 | **0** | 0 |
| `bioavailability` | 1 | 0 | 0 |

**So T-06's type has no live victim and these two do: three active protocols belonging to two real
users are missing from their own dashboards right now.** These are *web-created* types — iOS has no
femalehrt or oilblend calculator — so this is not a cross-platform gap at all. It is the web dropping
its own data.

**Blast radius:** `DashboardContext.tsx:169` calls `deriveProtocols` once and all sixteen dashboard
sub-components read the result from context — TodayCard, MySupply, SiteRotation, SerumChart,
ScheduleCalendar, DoseHistory, UpcomingDoses. `CalendarView.tsx:234` calls it independently.
`ProtocolList.tsx` and the rail read raw rows, so a dropped protocol is still listed and editable
there — which is why this has gone unnoticed: it looks saved everywhere except where it matters.

**Do not just add two branches — classify first.** The live configs say why:
`femalehrt` is `{prog, test, proto, route, doseIdx}` with `route` values of `patch`, `cream` and
`oral`; `oilblend` is `{comps:[…], injVol, injPerWeek}`. **A patch is not an injection**, so returning
no injection schedule for it may be semantically correct — but the file already has an explicit
`NON_SCHEDULABLE` list (`reconstitution` is on it, line 80) and neither type is. They are falling
through the *unknown-type* path, not the *deliberately-not-scheduled* path, and those must not look
the same. `oilblend` genuinely is injectable and genuinely should schedule.

**Done when:** every `calculator_type` present in `saved_dosages` either derives or is on
`NON_SCHEDULABLE` with a reason; a non-schedulable protocol is still visible to its owner rather than
vanishing; and an unrecognised type is reported instead of discarded silently. Verified by the two
affected users' protocols appearing on the dashboard.

## T-58 — Every bpc157 protocol shows "Draw volume unknown", from a config-key mismatch
**Priority 6/10** · **Owner:** win · **Status:** open

**What:** `deriveDose`'s `bpc157` branch reads `cfg.concMcgMl` / `cfg.vialMcg` — the **legacy** config
shape. Both the current web calculator (`public/app.js:10602-10620`, with an explicit comment about
the old→new change) and iOS (`CalculatorCatalog.swift:454-468`) now save
`{vialMg, bawMl, dose, syringeMl}`.

**Measured, all five production rows:** every one uses the new shape; **none** carries `vialMcg` or
`concMcgMl`. The live active row is `{dose:250, bawMl:2, vialMg:5, syringeMl:0.5}`. So `vol` computes
`null` and `inv.conc` computes `0`, and `InventoryPanel` renders "Draw volume unknown" for the one
user who has this protocol active.

**The same legacy-key read is duplicated independently** in `ProtocolList.tsx:120-121`'s detail-chip
renderer, so fixing one place will not fix the other.

**Why it is a 6 and not higher — stated because it was checked for specifically:** this degrades to a
visible "unknown" with a fallback message, **not** to a confidently wrong number. Every other branch
was cross-checked key-by-key against what iOS saves — including the `doseUnitMcg`→`doseUnit` and
`compound`→`slug` translations iOS performs before saving — and they match. **No branch was found
that produces a plausible wrong dose.** That was the failure mode worth fearing and it is not present.

**Done when:** `deriveDose` reads `vialMg`/`bawMl` and falls back to the legacy keys — the pattern
already implemented correctly in `lib/edit-schema.json:186` — the duplicate in `ProtocolList.tsx` is
repointed at the same helper, and the active bpc157 protocol shows a draw volume.

## T-59 — iOS-logged history rewrites itself when a protocol is renamed; web-logged history does not
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** `dose_log` carries five display-snapshot columns — `protocol_label`, `compound_label`,
`category`, `dose_label`, `scheduled_on` — whose stated purpose (`app/api/dose-log/route.ts:47-48`)
is to freeze what a dose looked like when it was logged. The web writes all five on every log. iOS
writes **none** of them: `NewDoseLogPin` has four fields and no snapshot columns.

**What that costs:** `DoseHistory.tsx:80-93` falls back to a **live** protocol lookup when the
snapshot is NULL. So if a user renames or deletes a protocol after logging a dose from the phone,
that history row's label and category **change retroactively**, or degrade to "Unknown protocol" /
"—" / "Other" — while a web-logged row for the same protocol stays frozen at its original values.
Two rows in production are affected today.

**Why it is a 5:** narrow trigger — it only surfaces on a later rename or delete — but it is the
snapshot column doing the opposite of its purpose for exactly the rows iOS wrote, and the fourth
instance of the same pattern after T-03, T-51 and T-08.

**Done when:** an iOS-logged dose carries all five, and renaming its protocol afterwards leaves the
history row unchanged — verified by a rename and a re-read, not by inspection.

## T-60 — The web has TWO compound tables that disagree on 13 half-lives, and one falsely claims to be the only one
**Priority 8/10** · **Owner:** win · **Status:** open

**What:** the web tree carries two independent pharmacokinetic tables.

- `public/app.js:10949` — `PLOTTER_COMPOUNDS`, 31 entries, **with a `tmax` on every row**. This is
  what the live cycle plotter runs on.
- `spec/compounds.json`, 31 entries, **no `tmax` on any row**. Its own `$comment` reads: *"Generated
  from public/legacy/cycle-plotter/pk.js by spec/generate-vectors.mjs. Do not hand-edit. **This file
  is the single source of truth for compound half-lives across web, iOS and Android.**"*

**They are not generated from each other, and they do not agree.** Matched 19 compounds by name;
**13 disagree on half-life**:

| compound | `app.js` | `spec/compounds.json` | ratio |
|---|---|---|---|
| Trenbolone Acetate | 1.5 | 3 | **2.0×** |
| PT-141 | 0.113 | 0.5 | **4.4×** |
| Melanotan II | 3.7 | 1.5 | **2.5×** |
| CJC-1295 (no DAC) | 0.021 | 0.08 | **3.8×** |
| BPC-157 | 0.17 | 0.25 | 1.5× |
| Trenbolone Enanthate | 5.5 | 7 | 1.3× |
| Testosterone Cypionate | 5 | 6 | 1.2× |
| Testosterone Undecanoate | 20 | 21 | — |
| CJC-1295 + DAC | 8 | 7 | — |
| Ipamorelin · HGH · IGF-1 LR3 · Retatrutide | minor | | |

The remaining 12 do not match by name at all — the two tables use different id and label
vocabularies (`eq` vs `boldenone`, `reta` vs `retatrutide`), so nothing would ever have flagged the
divergence automatically.

**Why this is 8 and why it is the web's problem, not the port's.** A half-life drives the whole
accumulation curve. Two tables that disagree by 2–4× produce materially different pictures of the
same protocol, and the file asserting sole authority is **not** the one the live plotter uses. So:

- **Any port is guaranteed to be "wrong" against one of them**, whichever it copies, through no fault
  of its own.
- **It invalidates a finding in mac's T-42 that would otherwise have sent work the wrong way.** T-42
  reports iOS's compound table disagreeing with `spec/compounds.json` on 15 half-lives, and reports
  its `tmax` values as having no web origin. Corrected: `PLOTTER_COMPOUNDS` **does exist** — mac's
  message said it does not — it **does** carry `tmax`, and iOS's comment citing it is accurate. iOS
  is faithfully mirroring the table the live web actually runs. **Do not "fix" iOS to match
  `spec/compounds.json` until the web decides which table is real.**

**T-42's core is untouched and still stands.** `spec/math-spec.md:204-206` verbatim: *"This yields
**mg-equivalents of active drug, not ng/dL.** … the chart is labelled in mg and must never claim a
lab number. **A port must not add a unit conversion here.**"* That is a separate defect from this
one and does not depend on which table wins.

**Done when:** one table is the source and the other is generated from it or deleted; the id
vocabularies are reconciled so a mismatch is detectable; and `spec/compounds.json`'s claim to be the
single source of truth is either made true or removed. Verified by a script that fails when the two
disagree — **the check has to outlive the fix**, because nothing detected this for however long it
has been true.

## T-61 — The web's dashboard greeting paints its own text at 1.50:1
**Priority 6/10** · **Owner:** win · **Status:** open

**What:** `components/account/dashboard/DashStyles.tsx:691-693`:

```css
.ib-dash-shimmer{background:linear-gradient(100deg,#0a9d90 0%,#0a9d90 40%,#5fe8da 50%,#0a9d90 60%,#0a9d90 100%);
  background-size:230% 100%;-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent;
  color:transparent;animation:ibDashShimmer 4.5s linear infinite;}
```

**`background-clip:text` with `text-fill-color:transparent` means the gradient IS the text**, not a
panel behind it. So at the sweep's midpoint the greeting — the largest type on the dashboard — is
painted in `#5FE8DA`, which measures **1.50:1 on white**. The 3:1 floor for large text is missed by
half; 4.5:1 is not in sight. And it animates, so the failure is intermittent, which is worse than a
static one: it will pass any spot check taken at the wrong moment.

**This was checked before being filed, because it would have been wrong as a background.** It is not
a background.

**Why it is the web's task and not a parity item:** iOS already refuses this colour and says why —
`Theme.swift:45-51` cuts `#5FE8DA` from the greeting gradient and builds the sweep from legal stops
only (`#075E56 → #0A9D90 → #075E56`, 7.65:1 and 3.37:1). **The port is right and the original is
wrong**, so there is nothing for mac to do here and iOS must not be "corrected" toward the web.

**Credit where the web is already right:** `DashStyles.tsx:987` disables the animation under
`prefers-reduced-motion`. iOS honours `accessibilityReduceMotion` too, but only in `WelcomeView` —
worth a look at whether anything else animates unguarded.

**Done when:** the midpoint stop is a colour that clears 3:1 on white, measured, with the sweep still
reading as a sweep. iOS's three-stop ramp is the working reference.

## T-62 — iOS corner radii are roughly double the web's, everywhere
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** the web's radius scale is one token with two derivations — `app/globals.css:34` sets
`--radius: 0.5rem` (**8px**), and `tailwind.config.ts` derives `lg: var(--radius)` (8px),
`md: calc(--radius - 2px)` (6px), `sm: calc(--radius - 4px)` (4px). iOS uses
`Theme.Radius.card = 16` and `.control = 10`.

**So every card is twice as round as the web's and every control is not far off it.** It is the kind
of difference that reads as "a different app" without any single element looking wrong, which is why
it survived a token-level parity pass that got the colours right.

**Priority 4 deliberately:** nothing is unreadable and no number is wrong. It is a systematic visual
divergence, so it belongs with T-54's header treatment rather than ahead of any dosing item — but it
is one line to change and it touches every screen.

**Recorded alongside, not filed as tasks — two web mechanics iOS has no concept of:** a **grid-beam
wayfinder** background (`public/app.js:4347+`) — a static teal SVG grid with six animated beams that
travel along the grid lines toward the next unanswered calculator field — and a **chrome-shimmer
border sweep** (`public/ib-calc.css:1642-1830`) marking that field. Both are recent, both are
wayfinding rather than decoration, and **both postdate `DESIGN.md`, which still says the grid
backdrop was removed.** They are the visual half of the same idea as T-01a's mode switcher: the web
tells you where you are in the form. Whether iOS should have an equivalent is a product question, not
a parity defect — raised here so it is a decision rather than an oversight.

**Done when:** the radius scale matches the web's, or the divergence is recorded here as deliberate
with a reason.
