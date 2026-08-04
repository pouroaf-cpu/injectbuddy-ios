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

11. **A task whose cause is UNKNOWN gets re-measured before it is reasoned about.** T-05 sat open for
    three days on the theory that a large title owns the pull-down stretch. Measured 2026-08-04 with
    a control: **the defect no longer reproduces at all** — it had been fixed days earlier as a side
    effect of an unrelated change, while the task went on describing a defect that did not exist.
    Everything reasoned on top of it, including "any future screen with a large title will silently
    not refresh", was reasoning about a ghost.
12. **A measurement must assert its own preconditions, not only its result.** Three instruments in
    one day reported success while measuring nothing: a skip sharing an exit code with a pass, a
    capture run reporting success with zero frames, and an environment flag that never reached the
    app. The third would have produced a **false confirmation** — the control reproducing the defect
    perfectly because the feature under test was never armed — and sent the next person chasing
    causes that had already been cleared.

13. **An agent in a worktree must rebase before writing to a SHARED FILE, not only before committing
    code.** On 2026-08-04 a T-45 worktree cut from a tip that predated T-51's closure merged cleanly
    and **resurrected the open version of T-51 beside the struck-through one** — two headings, one
    id, one of them stale. Rules 9 and 10 did not cover it: the write was to the right file, from the
    right block, by the right owner, and still wrong, because the branch point was old. Git cannot
    help here — both versions are legitimate text.
    **And a silent tidy-up is indistinguishable from quietly dropping a task**, so a duplicate
    removed this way leaves a note saying what happened.

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
   (**T-16** — now CLOSED, and with it the last `.pickerStyle(.menu)` in the app).
3. ~~**No link to the levels chart.** The web has a tinted card — `📊 See your levels over time →` —
   taking you from the calculator straight into the plotter with this protocol loaded. iOS has
   nothing connecting the two.~~
   **BUILT `29a8ede`** — `PlotLevelsCTA`. The calculator SET and the wording split are copied from
   `PLOT_CTA_CALC_IDS` verbatim, so BMI and free-T index do not get it. **CORRECTION — "with this
   protocol loaded" IS FALSE OF THE WEB.** The href does carry `?from=<calcId>`, and the plotter
   reads that parameter in exactly one place: `cycle-plotter/app.jsx:366`,
   `get('from') === 'planner'`. `from=trt` fails it and the plotter opens on the user's saved
   protocols or on ghost curves — never on the calculator. iOS's empty plotter was parity, not a
   gap. **Closed anyway as T-17**, by porting the web's own `mapDosage` so iOS carries the compound,
   dose and interval across; the reading is on `PlotterSeed` and under T-17.
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

### ~~T-01b … — every other screen, not yet compared~~ — **DONE 2026-08-04**
**Priority 9/10** · **Owner:** win + mac · **Status:** done

**What:** twelve of the twenty iOS frames have no partner comparison yet. The reference set covers
dashboard (empty and populated), calendar, log-dose sheet, tools hub, add and confirm-start,
settings, and every calculator in both empty and result states.

**Note:** the reference set also has screens iOS has **no version of at all** — progress, cycle
planner, blood tests, chat, suggestions, peptide tracker. Those are features, not layouts, and they
subsume the old "what is the dashboard's v1 scope" question: **the answer is what the web does.**

**Done when:** each screen has its own `T-01x` entry with its difference list.

**DONE — every screen now has one. Nineteen screens, two documents, both halves complete.**

| | screens | where |
|---|---|---|
| calculators (mac) | 13 — `T-01b-i` … `T-01b-vi`, `T-01b-1` … `T-01b-7` | `CALC-PARITY.md` |
| shell (win) | 6 — `S-01` … `S-06` | `SHELL-PARITY.md` |

**What the comparison produced is not what it was set up to find.** T-01b was written as a layout
exercise. It returned **T-41** (a unit flip that multiplies a dose by 1000), **T-42** (a fabricated
number labelled as a lab result), **T-43** (the same unit bug on a second screen), **T-44**
(injectable inputs for oral-only compounds), **T-45** (a vial concentration with no correct option,
drawing 25% over) and **T-81** (a protocol that silently ages out of the dashboard). **Every one came
from comparing maths and write paths, not pictures.** The method is the finding: the frames said
where to look, the source said what was wrong.

**Two screens were compared from source alone** — settings and confirm-start — because the harness
cannot photograph them (**T-55**). Their entries say so rather than pretending to a frame.

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

### T-01e — Tools hub (compared 2026-08-04) — **7 differences** — **2 of 7 BUILT**
**Priority 8/10** · **Owner:** mac · **Status:** doing — two built and pushed, five standing

**What:** a stock `.insetGrouped` list of titles against the web's cards, each with a category tag
and two or three lines saying what the calculator is for. No search, no count, no category jump.
**No brand token appears on the screen at all.** One of the seven is nearly free: `CalculatorCategory`
already defines a `subtitle` per category and `ToolsScreen` never references it.

**Full list with sources: `SHELL-PARITY.md` §S-03.**

**Done when:** each of the seven is built, or recorded with the reason it cannot be.

---

**BUILT 2026-08-04, unphotographed.** Two of the seven, both in `9e792b4`/`f021f70`:

1. ~~**Rows carry no description.**~~ Each Tools row now carries the web's own one-liner, transcribed
   **verbatim** from `CALC_DESC` (`app.js`) rather than paraphrased — it is user-facing copy the web
   has already settled, and rewording it means two products describing the same tool differently to
   the same person. It lives in `Features/Tools/CalculatorDescriptions.swift` **only because
   `NavItems.swift` was held by another agent at the time**; it is an extension on `CalculatorSlug`
   and belongs beside `title`/`icon` — **fold it in, the move is a cut and paste with no call-site
   change.**
2. ~~**Category subtitles never rendered.**~~ `CalculatorCategory.subtitle` defined all four strings
   and `ToolsScreen` referenced none of them. Now rendered under each section title.

**Why the descriptions matter more than they look:** on a list where `TRT Dose`, `TRT & EOD` and
`TRT Microdose` differ by one word, a bare title makes the user pick by opening three of them.

**Deliberately NOT transcribed:** the eight `CALC_DESC` entries for calculators iOS does not have
(T-19). A description for a screen that does not exist is a promise this app cannot keep.

**One accessibility element per row**, combining title and description, so browsing fifteen
calculators is fifteen VoiceOver stops rather than thirty.

**Still standing — five of seven**, and they are the layout half rather than the content half. Not
started; see `SHELL-PARITY.md` §S-03 for the list.

**Evidence owed:** BUILD SUCCEEDED and 115 unit tests green, but **no frame**. Tools goes into the
batched capture run with T-14/T-20/T-53.

**A pattern this task fed, worth more than the task:** `subtitle` written and never called is the
THIRD case found in one day of correct code nothing reaches — with `SteroidCatalog.canInject`
(T-44) and the plotter's missing `members` entry (T-11). Three in a day is a pattern, not three
tasks.

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

### The request half — **MEASURED 2026-08-04. NULL RESULT: the closure fires and no query executes.**

Two observers, neither able to fake the other's half: mac drove the device and cannot see the
database; win read the database and cannot touch the device.

```
BASELINE   11:12:04Z   dose_log 4790   saved_dosages 14223   total 2118254   entries 615
           11:12:42Z   dose_log 4790   saved_dosages 14223   total 2118254
           11:12:56Z   dose_log 4790   saved_dosages 14223   total 2118254
PULL       11:15:20Z -> 11:15:30Z        reloads 1 -> 2      (large title, shipping config)
AFTER      11:16:06Z   dose_log 4790   saved_dosages 14223   total 2118254   entries 615
```

**Not one call on any counter, and no new entry**, read 36s after pull-end — ample, since
`pg_stat_statements` records at statement end.

**THE AMBIENT RATE IS THE DISCRIMINATOR AND IT IS WHY A NULL IS EVIDENCE HERE.** Record it beside
the result, because a future reader needs the instrument and not just the conclusion: three
readings across **52 seconds showed zero drift** on a LIVE production database whose counters
demonstrably do move (2.1M historical calls). Without that, "nothing moved" is unreadable — it is
indistinguishable from a stats table that is not counting what we think it counts. The quiet period
exists to measure exactly this, and it did.

**The escape hatch was checked too**, because "the counter did not move" and "the request went
somewhere nobody is looking" are different claims: **zero new query shapes created inside
11:15:15–11:15:40Z** (a shape the `WITH pgrst_source%` filter missed would have created an entry
with `stats_since` in the window), and the newest PostgREST entry of any kind predates the pull by
54 minutes.

**So T-05's original observation was right about the symptom and WRONG ABOUT THE LAYER.** The
gesture arms, `.refreshable` runs, the closure executes and the counter increments — and
`CalendarViewModel.load` does not reach the network. A cache, a guard, or an early return.

**WHAT IS NOT YET PROVEN, and it decides where to look next.** The database instrument sees
**queries executed in Postgres**. It cannot separate:

- **(a)** the app never made an HTTP request — a logic bug in `load`;
- **(b)** the app made one that failed or was cancelled before PostgREST ran a statement — auth
  refresh, cancelled task, dropped connection.

Both produce exactly this reading, and **(b) is the worse of the two**: a request path that fails
silently would also explain the original behaviour better than a logic bug does. Only the device
side can tell them apart.

**Done when:** the device says which. A `URLProtocol` log or an `os_log` at the point
`SupabaseBackendClient` is actually called, driven through one pull, distinguishes (a) from (b) in a
single cheap run — no database access needed. **Do not close this on the null alone: it proves
nothing ARRIVED, not that nothing was SENT.**

**Candidate (A) remains disproven** — see above; the large title is not the mechanism and header
work is not blocked by it. Candidates (B) and (C) are now the live ones again, alongside the new
network-layer question, and (C) — `reload()` mutating `@State` before its await — looks better than
it did, because a `Task` cancelled by a view update would produce exactly this null.

### The last question — instrument BUILT, and it has answered NOTHING yet

**What is still unknown.** The null above proves no statement executed in Postgres. It cannot
separate **(a)** the app never made an HTTP request — a logic bug in `load` — from **(b)** a request
was made and died before PostgREST ran a statement. **(b) is the worse of the two** and explains the
original behaviour better than a logic bug does.

**Built `2026-08-04`, committed, UNPROVEN.** Four DEBUG counters on `CalendarViewModel.load` —
`entered`, `requested`, `returned`, `threw` — plus the error string, surfaced through the existing
`t05_probe`. They sit exactly between the two measurements already taken: `reloads` proved the
closure runs, the database proved no statement executed, and these say whether the backend call was
reached and what it did. **If `threw` moves while `returned` does not, the pull reaches the network
layer and is cancelled.**

**IT HAS NOT RUN.** The attempt died in `setUp` — *"No Calendar tab appeared within 15s"* — on a
cold isolated `DerivedData` where launch is slower than the helper's timeout. **No data was
produced.** The instrument is committed so the next session does not rebuild it, NOT because it has
shown anything. Raise the tab timeout or warm the build before re-running.

**THE PRIME SUSPECT, and its own comment convicts it.** The `catch` in `CalendarViewModel.load`
says: *"A cancelled load surfaces NOTHING and touches NO state."* A cancelled `Task` makes the
`async let` pair throw `CancellationError`, `LoadFailure.message` returns nil for it **by design**,
and the whole failure is swallowed — no state change, no banner, nothing on screen. **That is the
exact shape of every observation so far:** the gesture arms, the closure runs, the counter
increments, no statement executes, and the user sees a spinner return with stale data and no error.

That is **candidate (C)** — `reload()` mutates `visibleMonth` (`@State`) **before** its await, which
`DashboardScreen.reload()` does not do. It was the weakest of the three candidates when they were
written and it is now the strongest, purely because (A) is dead and the null rules out the layers
above it.

**Next measurement, cheap and device-only:** one pull with the counters read. No database access, no
coordination with the other side.

**WHAT CANDIDATE (C) PREDICTS, AND WHY THE EXISTING COUNTERS ALREADY SETTLE IT.** A cancellation is
not just consistent with the evidence — it makes a specific prediction the other candidates do not:
**`threw` increments while `returned` does not** (or `requested` fires and `returned` never
follows). A logic bug that never reaches the network gives the opposite signature — `entered` moves
and `requested` does not. The four counters separate those two in **one run**, with no database
access and no coordination with the other side. That is the whole remaining question, and the
instrument for it is already built and committed; it has simply never executed.

## ~~T-06 — The web drops every `microdose` protocol on the floor~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** win · **Status:** done

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

**DONE `c07a1bf5`.** `lib/account-schedule.ts:122` — `if (calc === 'trt' || calc === 'eod' || calc ===
'microdose')`. **One word, because the config turned out to be key-for-key identical to trt's**,
checked against production before the change rather than assumed:
`{mode, nDays, mgWeek, mlDrawn, strength, esterType, syringeMl, injPerWeek}`.

**Measured, not inspected** — `deriveProtocols` run over the real production config:
`microdose · dose=10 mg · vol=0.05 · freqDays=3.5 · route=IM · conc=200`.

Closed alongside **T-57**, which is the same defect's general case: this task named the one type
anybody had noticed, and the sweep found that `femalehrt` and `oilblend` were being dropped too —
those had live users and `microdose` had none.

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
**Priority 6/10** · **Owner:** mac · **Status:** open — **DECIDED 2026-08-05: EOD COLLAPSES. Remove the whole calculator.**

**⚠ THE PREMISE BELOW IS WRONG AND IS LEFT STANDING PER RULE 7. Correction first — mac caught it,
from win's own source.**

**There IS a TRT EOD calculator on the web. It is live, user-reachable, and it can still create `eod`
rows today.** Verified in `public/app.js` on `feature/dosage-status-model`: `EODPage` is defined
(`:6274`) and rendered on `page === 'eod'` (`:11708`); `PAGES` carries `id: 'eod'` (`:9235`); and
`:6166` POSTs `{calculator_type: 'eod', label, config}` to `/api/dosages/`. `public/nav-items.js:23`
exposes it as **"Testosterone (TRT) & EOD"** and `:79` lists it in the Hormone Tools group, so a user
can navigate to it.

**How win got it wrong, recorded because the method matters more than the fact:** win searched
`public/legacy/` — the static calculator directories — found no `eod` folder, and concluded the
calculator did not exist. **The web's calculators are a single-page app in `public/app.js`; the
legacy directories are only some of them.** That is "it is not in the place I looked, therefore it
does not exist" — the identical inference win had warned mac against hours earlier over a
`pg_stat_statements` table. Same error, from the person who named it, on their own source.

**The decision survives the correction, and is actually better supported by it.**
`nav-items.js:23,59` point `eod` at **`/trt-calculator/` — the same URL as `trt`.** The web's own
navigation already treats EOD as a way into the TRT calculator. So the owner's *"that option is
inside the TRT calc anyway"* is not merely true of iOS; it is what the web's nav says. Removing the
iOS EOD screen moves iOS **toward** the web's intent.

---

**What (as originally filed, now known to be wrong about the SPA):** there is no TRT EOD calculator on
the web and there never was one. `public/legacy/` holds 21 calculator directories and the only TRT
ones are `trt-calculator` and `trt-microdosing-calculator`. EOD is a *frequency inside* the TRT calculator —
`trt-calculator/index.html:296`, "Supports weekly, E3.5D, and EOD dosing", and the live site serves
the switcher today (`Every N Days` / `Per Week` / `mL → mg` on
`https://www.injectbuddy.com/trt-calculator/`). iOS's `.eod` spec is the TRT spec with the help text
"Hardcoded every-other-day interval (3.5 injections/week)".

**So T-01a difference #1 and this screen are one defect seen from two ends:** iOS has no mode
switcher, so it grew a screen to hold the mode. Building the switcher while leaving the screen up
ships the mode twice.

**Why it is the owner's call:** it is a shipping screen. It does not get deleted on the strength of a
source reading.

**THE OWNER'S DECISION, 2026-08-05:** *"T-12 does collapse — just remove the whole EOD completely,
that option is inside the TRT calc anyway."* Remove the calculator, not merely hide it.

**Checked before this was actioned, because deleting a shipping screen can strand data:**

```
saved_dosages where calculator_type = 'eod'  →  0 rows, 0 active
dose_log joined to those rows                →  0
```

**Nothing is stranded.** No user has ever saved an EOD protocol, which is itself the strongest
argument for the decision: the screen existed for a mode the TRT calculator now offers directly.

**Scope, so this does not overshoot:**
- ~~Remove `.eod` from `CalculatorSlug`~~ — **overruled by mac, correctly.** `CalculatorSlug.rawValue`
  IS the decoder for `saved_dosages.calculator_type`. Deleting the case means a **web-created EOD
  protocol stops decoding on iOS** — no error, no empty state, simply absent. That is T-57's shape and
  T-81's shape, and the web can still create those rows (see the correction above). The enum case
  stays. **This is win's own "a branch for a type no row uses is insurance" argument, applied
  symmetrically to the decoder — mac spotted that win had not applied it to their own instruction.**
- So: **removed as a CALCULATOR, retained as a PROTOCOL TYPE.** No Tools entry, no `allMembers`
  membership, no spec, no engine, no create path. Decoding, title, icon, dashboard colour and
  `DoseProjection`'s every-2-days interval all stay.
- The engine's `TrtMode` is untouched — EOD lives on there as a *mode*, which is the whole point.
- **Leave the web's `deriveDose` `eod` branch alone.** It costs nothing, and a branch that handles a
  type no row uses is insurance; removing it would be the reverse of T-57, where a missing branch
  silently dropped live protocols.
- Confirm the TRT calculator's `Every N Days` mode reaches an every-other-day interval before the
  screen goes, so the capability genuinely survives the removal rather than being assumed to.

**Done when:** the EOD screen is gone, `Every N Days` is photographed producing an EOD interval, and
the app still builds with no `.eod` references.

## T-13 — Four items exist partly to rank in search; decide them together
**Priority 4/10** · **Owner:** win · **Status:** DECIDED 2026-08-05 — three ditched, one kept in filtered form

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

**THE OWNER DELEGATED THIS: *"SEO is irrelevant on mobile, so you make the call — if it's not needed, ditch."* Decision below, item by item, with the reason each way.**

**1 · Breadcrumb (`T-01a #12`) — DITCH.** A breadcrumb exists on the web because a web page has no
inherent back affordance. iOS has a navigation stack and a system back button that users already
trust. It would be a second, worse back button that says the same thing.

**2 · Related-calculators carousel (`T-01a #6`) — DITCH.** Every calculator is one tap away in Tools,
which is a permanent tab. A carousel is a worse version of a surface the app already has, at the
bottom of a screen the user reached because they already knew what they wanted.

**3 · Tools guide links and "How calculators work" (`S-03 #6, #7`) — DITCH.** The guide links point at
`/guides/`, which has no iOS existence — porting them means either shipping dead links or opening a
browser out of the app. The prose is a landing-page explainer for someone deciding whether to use the
product; an app user has already decided.

**4 · Calculator FAQ (`T-01a #5`) — KEEP, FILTERED. This one is not SEO furniture and today proved
it.** The evidence is `app.js:10264`, the semaglutide FAQ, which the web itself uses to carry safety
content:

> *"…some compounders produce 2 mg/mL, 7.5 mg/mL, or 12 mg/mL formulations. … **Selecting the wrong
> concentration is the most common dosing error — it can mean you draw two or three times the
> intended dose.** … Use the Custom option if your vial doesn't match a preset."*

That paragraph was **the decisive evidence for T-45**, a real dosing defect. It names a vial the
web's own picker cannot select, states the harm in the product's own voice, and documents the escape
hatch. Deleting the FAQ as "SEO" would have deleted that.

**So the rule is not keep-or-ditch, it is a filter:** an FAQ entry survives if it states a **hazard**,
explains a **number the screen shows**, or documents **how to enter something unusual**. It goes if it
answers a question only a search engine asks — "what is a TRT calculator", "is it free", "do I need an
account".

**Same filter already applied and already correct elsewhere:** the calendar's "How it works" plus its
three citations (T-01d #7) are kept, on a `robots: noindex` page where the SEO argument never applied
— they are the only place the app explains why the schedule looks the way it does.

**Done — the four are decided. Remaining work is execution, not a decision:** mac drops items 1–3 from
T-01a and S-03, and ports the FAQ under the filter above rather than wholesale.

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

**This prediction came true on the READ side (T-24, 2026-08-04)** before anyone checked the write
side. `DoseVolume.modeIsEvaluatedAsSaved` still said "trt means `perweek`" — the rule from before
`mode` was a field — and was silently refusing 21 of 39 TRT rows. No build failed, no test failed,
and the symptom was a NULL that looked like "this protocol has no volume". The write side is still
unobserved and this task still stands.

## ~~T-16 — The numeric menu pickers still draw outside their own chrome~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** mac · **Status:** done

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

**THE TWELVE, ACCOUNTED FOR.** The count was never itemised anywhere and it turns out to be exact:
ten `.picker` fields across seven calculators — TRT `injPerWeek`, peptide `doseUnitMcg`,
semaglutide / tirzepatide / retatrutide `conc` + `dose`, free-T `ttUnitNgdl`, steroid `compound` —
plus the cycle plotter's own two menus, `Compound` and `Frequency`. Eight screens. All twelve are
gone; nothing renders `.pickerStyle(.menu)` in this app any more.

**HOW IT WAS FIXED, and it is not what the old note in `CalculatorScreen` proposed.** That note said
"a `Menu` whose label we lay out ourselves". It is a `Combobox` instead — `CompoundCombobox` split
into a face and a searchable sheet, with two thin wrappers over it: the existing string one, and a
new `ValueCombobox` carrying a `Double`. ONE control on all twelve sites (UX-UI-RULES §6), and the
numeric sites gain the search the web has and the menu never had. The plotter's two menus also lost
`.tint(Theme.accent)` on the way through, which was #0FBCAD as VALUE TEXT at 2.38:1 — see T-31.

**THE RULED-OUT MODIFIER STAYS RULED OUT** and is now recorded in the code rather than in a task, so
the next person does not re-run it: `.fixedSize(horizontal: false, vertical: true)` on the menu
picker changed the geometry by NOTHING, re-measured identical to the byte.

**MEASURED — first run, and it was RED, which is the useful part.** At the size the rig was actually
at, `control_compound` measured `(15.5, 191.5, 371.0, 61.0)` with its value published at
`(16.0, 192.0, 370.0, 60.0)` — **half a point inside its own chrome on every edge**, against the
`{{83.3, 192.7}, {193.0, 183.3}}` in a `{{15.5, 245.5}, {371.3, 78.3}}` button the defect was
recorded as. The value is inside the control. But the run also found two things worth having:

- **the first assertion was the wrong one.** It asserted the value no longer appears as a
  `StaticText` at all. It does — `accessibilityElement(children: .ignore)` did not collapse it.
  "The element is gone" and "the element is where it belongs" are different claims and only the
  second was ever true. Corrected rather than relaxed.
- **the magnifier survived as a leaf INSIDE the collapsed value**, and `LeafOverlapUITests` reported
  the two as sharing pixels. They do not — the glyph sits left of the text; what overlapped was a
  child and the husk its own siblings had collapsed into. Fixed by hiding the combobox face at its
  ROOT rather than per-glyph, so the control is genuinely one element. Per-child
  `accessibilityHidden` was not enough and that is now written into the control.

**MEASURED — `15-calculator-steroid-compound-ax5.png`**, at AX5 with the size set on an explicitly
booted device and read back (the first run's `simctl ui booted content_size` printed *"No devices
are booted"* and silently measured DEFAULT size under an `ax5` filename — the exact trap CLAUDE.md
names, inverted). The frame is written only if the control resolves with the compound as its
`accessibilityValue`, does not intersect `section_Compound` above it, sits wholly inside the
window, and publishes nothing inside its own frame.

**`LeafOverlapUITests/testSteroidDosage` green at AX5** — the screen the defect was measured on, and
the check that found it. **Five entries DELETED** from `expectedOverlaps` rather than suppressed:
`Compound` × `Oxandrolone (Anavar)`, `Oxandrolone (Anavar)` × `Vial strength`, `Ester` ×
`Testosterone Enanthate`, and both `2×/week` pairs. The suite asserts from both ends, so a listed
overlap that stops overlapping goes RED; these had to go. **Two were already stale before this
pass** — T-01a #1 moved TRT's default mode to `ndays` and `injPerWeek` only renders under
`perweek`, so `2×/week` has not been on that screen since.

Final AX5 run: `OVERLAP Steroid Dosage: 18 leaves, no intersections` — the capture test and the
overlap test both green, with the picker entries deleted and the nine unrelated pairs T-34 exposed
declared against **T-35** and **T-36**.

**`testTRTDose` IS STILL RED, and not for this.** It reports `unit_nDays` × a `TickDrum` gradation
labelled `3` sharing 6.4 x 8.1pt at default size — a ruler tick printed through a unit label, from
T-01a #7, on a row eleven calculators share. Filed as **T-33**, not folded in here.

## ~~T-17 — The levels link opens the plotter empty~~ — **DONE 2026-08-04**
**Priority 4/10** · **Owner:** mac · **Status:** done

**What:** T-01a #3's difference says the web link takes you "into the plotter with this protocol
loaded". The web href is `/cycle-plotter/?from=<calcId>`. iOS pushes `.calculator(.cyclePlotter)`
and nothing else, so the user arrives at an empty plotter and re-enters the compound, dose and
interval they just typed.

**Why it was shipped anyway rather than held:** the link with no context is still the only route
from a calculator to the plotter, and — see T-11 — currently the only route to the plotter at all.
Empty beats absent. It is recorded so "with this protocol loaded" is not quietly treated as done.

**Done when:** `AppRoute` can carry the calculator's values to the plotter, and a frame shows the
plotter opening on the compound and dose the calculator held.

**FIRST, A CORRECTION TO T-01a #3, AND IT IS THE INTERESTING PART.** *"The web link takes you into
the plotter with this protocol loaded"* — **it does not.** Read on `feature/dosage-status-model`:

- `public/app.js:2400` builds the href as `'/cycle-plotter/?from=' + calcId`. The click handler's
  ONLY side effect is a PostHog `cycle_plotter_cta_click`. It writes nothing to any store, and no
  calculator state travels with the link. Every `localStorage`/`sessionStorage` write in that file
  was checked; the only handoff-shaped one is `ib_steroid_ester`, read back by the steroid
  calculator itself.
- `/cycle-plotter/` is a separate legacy bundle. The one place it reads that parameter is
  `public/legacy/cycle-plotter/app.jsx:366` —
  `new URLSearchParams(window.location.search).get('from') === 'planner'`. **`from=trt` fails that
  equality**, `loadCyclePreset()` returns `null` on the next line, and the plotter proceeds exactly
  as if there were no query string. Verified identical in the shipped `app.compiled.js:347`.
- What a user actually gets: signed out, an empty chart with grey ghost curves; signed in, a list
  of their SAVED protocols, all disabled, or eight hardcoded demo rows if they have none. `?from=`
  is a dead parameter for prefill and an analytics tag in practice.

So iOS's empty plotter was **parity with the web, not a gap against it**. This is the third time a
behaviour was inferred from a document about the web rather than the web (CLAUDE.md records the
other two); the correction is written into `PlotterSeed`'s header so the next reader of that
difference list meets it.

**BUILT ANYWAY, because it is the right behaviour and the derivation is not invented.** The web's
own `mapDosage(type, d)` (`cycle-plotter/app.jsx:127-215`) is its authoritative "this protocol's
config → a plottable line", used for every saved dosage the plotter lists. `PlotterSeed.from` is
that function, per branch, with each formula's provenance on it. The only thing that changes is the
SOURCE of the config — the calculator's live values instead of a saved row.

**AND IT REFUSES.** `mapDosage` ends `if (!cid || !(dose > 0) || !COMPOUNDS[cid]) return null;` and
its steroid map spells out why: *"a dosing tool does not get to guess."* Peptide (no named
molecule in the iOS spec), reconstitution, the BPC+TB500 blend and HCG seed NOTHING and open the
plotter unseeded — which is the behaviour that shipped, and better than a curve drawn for the wrong
compound. Asserted as behaviour in `PlotterSeedTests`, not left as a fallthrough.

**MEASURED, two ways, because a photograph cannot answer the half that matters:**

- **`28-plotter-seeded-from-trt-default.png`** — walked the link the user walks. TRT at its
  defaults (100 mg/week, every 3.5 days, Testosterone Enanthate) → `cta_plot_levels` → the plotter
  opens on `Testosterone Enanthate`, `50`, `Twice per week (2x/wk)`. Arrival asserted before the
  shot; every value read off the control, not off the pixels.
- **`PlotterSeedTests`** — the arithmetic, across every calculator, with no launch. **50, not 100,
  is the whole point:** `pkBuildEntries` applies the line's dose at EVERY injection time, so a
  plotter handed the weekly total draws a curve twice as high as the protocol the user typed, and
  the two curves are indistinguishable by eye on a screen whose entire output is a serum level.
  That is the same class of defect as the config key that would have written a plausible wrong dose
  volume to every logged dose.

`AppRoute` gained `case plotter(seed: PlotterSeed)` and stayed `Hashable` — asserted, including
that two seeds differing only by dose are two distinct destinations, or a push from a re-edited
calculator would be a silent no-op. `.calculator(.cyclePlotter)` is untouched and is still the
drawer's and the Add dialog's route: nothing has been calculated there, so empty is correct.

**ONE REGRESSION, CAUGHT OFF THE FRAME AND FIXED IN THE SAME PASS.** The first
`28-plotter-seeded-from-trt-default.png` showed `Twice per week (2x/wk)` wrapped to **five lines**
at DEFAULT size beside a one-line `Dose` field. Cause: T-16 replaced that menu picker with a
combobox, and a menu picker draws its value on one line at any width while the combobox obeys §9 —
the container grows, the text does not shrink. In a half-width column that is five lines. `Dose` and
`Frequency` are stacked now, each full width, and the re-shot frame shows the label on one line.
This is the reason a frame is taken and looked at rather than a test being read: nothing was hidden,
clipped or truncated, so no assertion in this repo would have said a word.

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

## T-21 — Two of five cards state no dose, because the engine refuses two whole shapes of config
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** T-53 gave every protocol card a per-injection dose derived from its config. Two of the QA
account's five state none, for two different reasons, and both are real config shapes in production:

1. **A steroid row saved in `perweek` or `ml2mg`.** `CalculatorEvaluate` hardcodes `mode: .ndays`
   for `.steroid` (`injPerWeek: 0, mlDrawn: 0`), so `DoseVolume.modeIsEvaluatedAsSaved` refuses the
   row rather than evaluate it in a mode it was not saved in. The QA `Masteron` row is
   `mode: perweek`, and production holds **9 steroid rows across 5 users**. This is the same defect
   T-01a #1 fixed for TRT — `mode` became a real field there and never did here.
2. **A weekly dose of 0.** `Testosterone Cypionate · 0mg/wk` evaluates to `mlPerInj = 0`, which the
   engine calls invalid, so no dose and no volume. The web renders it as `0 mg`.

**Why it matters:** it is not only the card. The same gate feeds `draw_ml` (so these protocols log a
NULL volume and consume nothing from the vial — see the `NewDoseLogPin` header) and it now feeds
T-52's amount field, so **a Masteron user cannot record a partial dose at all**: no derived amount
means no field to correct.

**Done when:** a steroid protocol saved `perweek` states a dose per injection on its card and logs a
non-NULL `draw_ml`, verified by a `select` on a row logged from the sheet.

## ~~T-22 — The web's `DOSE AMOUNT` field is discarded, so iOS and web now disagree~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** win · **Status:** done

**What:** found while reading the web's own source for T-52, on `feature/dosage-status-model`.
`DashLogFlow.tsx:23` holds `amount` in state and seeds it from `p.doseLabel` (line 38), the input
writes it back (line 188) — **and nothing ever reads it.** `logIt` → `finishLog` calls
`d.markDone(p, chosenDay, siteIdx, day, injectionTime)`; `markDone` → `persistPin` sends
`dose_label: ev.doseLabel` — the PROTOCOL's planned dose. Type the amount you actually injected on
the web and the plan is stored instead.

**Why it matters:** this is T-52's defect on the other side of the app, and worse in one respect —
iOS had no field, so nothing lied; the web has a field that accepts a correction and drops it. As of
this commit iOS writes what was typed, so **the same edit produces different rows depending on which
client made it.**

**Done when:** the web sends the edited amount, or the field is removed. Either way the two clients
agree about what `dose_label` means.

## T-23 — `protocol_label`, `compound_label` and `category` are NULL on every iOS-written dose
**Priority 3/10** · **Owner:** mac · **Status:** open

**What:** the web writes four display-snapshot columns on every pin (`/api/dose-log` POST).
T-52 filled `dose_label`, which is the one of the four that can differ from the plan. The other
three are still absent from `NewDoseLogPin`.

**Why nothing is visibly broken today:** `DoseHistory.tsx:85-90` falls back to the live protocol for
all three. **Why it is still a hole:** they exist to be a snapshot — the history is meant to keep
describing what was taken after the protocol is edited or deleted. Web-written rows survive that,
iOS-written rows do not.

**Done when:** the three columns are on the iOS write and a logged row carries them, or it is
recorded here that iOS deliberately relies on the fallback.

## T-25 — The new DOSE AMOUNT field straddles the pinned CTA bar at rest
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** in the T-53 evidence frame (`docs/ui-audit/2026-08-04-logdose/01-logdose-sheet-t5352.png`)
the `DOSE AMOUNT` header is fully visible and the field under it is cut across the middle by the top
edge of the `Log dose` bar — `74.5` and its `mg` are both legible, the bottom of the field is not.
Default text size, unscrolled, five protocols in the list.

**Why it matters:** UX-UI-RULES §3 is explicit — "A CTA you can reach that commits a field you
cannot is a failure, not a partial pass." This is the field T-52 added, and it is the number the
user is being asked to confirm.

**Say what it is NOT.** Not clipping: the bar is a `safeAreaInset`, it reserves its height, and the
form scrolls clear of it. This is the at-rest position of a form whose protocol list already fills
the viewport — the same shape as T-20 on the calculator, and it gets worse with every protocol the
account holds. **And the site picker and the day row were already below the fold before this
change**, so the sheet as a whole has been failing §3 since T-03; the amount is the newest and the
most consequential of the three, not a new class of problem.

**The far worse half of this WAS fixed, in the same pass.** The second frame from that run
(`02-logdose-keypad-before.png`) shows the sheet with the keypad up and **the amount field entirely
off-screen** — the user typing a dose they cannot see, behind the keyboard and the pinned bar
together. That is not a straddle, it is a blind entry on the write path, and the round-trip test had
gone GREEN through it because `typeText` does not care whether a field is visible. The CTA is now
withdrawn while the keyboard is up (the treatment `MainShell` already gives the raised hero), the
keypad carries a `Done` (a `.decimalPad` has no return key, so without one the sheet would be a
one-way door), and the UI test asserts `isHittable` on the field WHILE it is focused.

**Not fixed by eye.** Re-ordering the sections so the amount leads would put "how much" above "of
what", and that trade needs measuring at default and AX5 rather than guessing.

**Done when:** measured against the amount field the way `PinnedBarReachabilityUITests` measures the
calculator's, and either shown reachable at default and AX5, or the sheet re-ordered with a frame
showing the field clear of the bar at both sizes.

## ~~T-24 — A stale mode gate was refusing 21 of 39 TRT protocols~~ — **DONE 2026-08-04**
**Priority 7/10** · **Owner:** mac · **Status:** done

**What:** `DoseVolume.modeIsEvaluatedAsSaved` decides whether a saved config may be re-evaluated. It
read `case .trt: return mode == "perweek"`. That was true when `CalculatorEvaluate` hard-coded
`.perweek` for TRT — **T-01a #1 made `mode` a real field and `evaluate` has honoured all three
branches ever since, and the gate was never updated.**

**Why it matters, in production rows:**

```sql
select calculator_type, coalesce(config->>'mode','(none)') mode, count(*) rows,
       count(distinct user_id) users
from saved_dosages where calculator_type = 'trt' group by 1,2 order by rows desc;
```
```
trt | ndays   | 21 | 13
trt | perweek | 15 | 10
trt | (none)  |  2 |  2
trt | ml2mg   |  1 |  1
```

`ndays` is the **web's own default**, so the majority of the largest family (TRT is 22 of 39 users
with protocols) was being refused: every dose logged against one of those protocols wrote a NULL
`draw_ml` — the supply ledger's "never run dry" promise failing in the direction of running dry —
and, once T-53 landed, the card showed no dose and T-52 showed no amount field to correct.

**Refusing on a rule that is no longer true is not caution.** It is the same wrong answer given
confidently, and it was invisible because a NULL looks like "this protocol has no volume".

**Fixed:** `.trt` now accepts `ndays` and `perweek`. `ml2mg` stays refused **because of the web, not
iOS** — `evaluate` runs it correctly (`mlDrawn × strength`) but `lib/account-schedule.ts` has no
`ml2mg` branch for `trt` and computes the dose from `mgWeek` like `perweek`, so the two clients
disagree about what the row means. One row in production. `.microdose` and `.steroid` are unchanged:
`evaluate` really does still hard-code `.ndays` for both (that half is T-21).

**Done — red first, and the red was not written for it.** The gate was found because two T-53 tests
went red against the build that still had it. `ndays` TRT rows came out with **no dose at all**:

```
ProtocolSummaryTests.swift:68: XCTAssertEqual failed:
  ("every 3.5 days · 230 mg/mL") is not equal to ("50 mg · every 3.5 days · 230 mg/mL")
ProtocolSummaryTests.swift:87: XCTAssertEqual failed:
  ("50 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate")
  is not equal to ("every 3.5 days · 200 mg/mL · Testosterone Enanthate")
Executed 62 tests, with 4 failures (0 unexpected)
```

The second one is the defect stated plainly: the same protocol saved `perweek` states `50 mg` and
saved `ndays` states nothing. `testATrtProtocolSavedInNdaysIsEvaluated` pins it directly (50 mg /
0.25 mL from `100 mg/wk, every 3.5 days, 200 mg/mL`), and
`testATrtProtocolSavedInMl2mgIsStillRefused` pins the one mode that stays refused.

Green after: `Executed 64 tests, with 0 failures (0 unexpected)`.
## ~~T-31 — The cycle plotter painted three strings in the 2.38:1 accent~~ — **DONE 2026-08-04**
**Priority 4/10** · **Owner:** mac · **Status:** done

**What:** `CyclePlotterScreen` used `Theme.accent` (#0FBCAD) as a FOREGROUND on three things: the
cycle-length readout `Text("\(vm.cycleWeeks) weeks")`, the `Add compound` label, and — via
`.tint(Theme.accent)` on the two menu pickers — the selected COMPOUND and FREQUENCY values.

**Why it is a defect and not a preference:** UX-UI-RULES §5 makes #0FBCAD **fill only, never a text
or glyph colour** — it is 2.38:1 on white and fails at every size. Teal text is `tealTextStrong`,
7.65:1. `\(cycleWeeks) weeks` is also a **value+unit pair**, which is the category §2 exists for.

**Found:** while replacing the plotter's menu pickers for T-16. Filed under rule 6 rather than
folded silently into that commit.

**Done:** all three now use `Theme.tealTextStrong`; `.tint` went with the pickers. Visible in
`28-plotter-seeded-from-trt-default.png`. The cycle-length readout also gained
`.fixedSize(horizontal: false, vertical: true)` — it is a value+unit pair and must wrap, not shear.

**NOT AUDITED BEYOND THIS SCREEN.** `Theme.accent` is used as a foreground elsewhere in the app
(`BrandWordmark`'s glyph is one, deliberately — it is a decorative mark, not text). A sweep for
`foregroundStyle(Theme.accent)` on anything carrying a NUMBER has not been done and is not claimed
here.

## T-32 — Protocols the iOS plotter has no compound for
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** `PlotterCompound.all` is transcribed verbatim from `PLOTTER_COMPOUNDS` in `app.js` — 27
entries. The web plotter's own `COMPOUNDS` table has since grown past it, and T-17's handoff is
where the gap becomes visible: a protocol the user can build in an iOS calculator, and which the
web would plot, cannot be plotted on iOS at all. Measured against `mapDosage`'s tables:

- **Two of the seven esters.** `Testosterone Acetate` → `test-a` and `Sustanon 250` → `sustanon`
  are in `ESTER_TO_CID` and in neither iOS list. A TRT protocol on either seeds nothing and opens
  the plotter empty. Asserted from both ends in `PlotterSeedTests.test_theTwoUnplottableEsters` —
  the two named must NOT seed, the other five MUST.
- **HCG.** The web maps it to a compound id `hcg`; iOS has no such entry. `hcg` is one of the
  eleven calculators that shows the levels link.
- **The whole steroid set.** `STEROID_TO_CID` names `masteron-p/e`, `nandrolone-d`, `boldenone`,
  `methenolone-e`, `anavar`, `dianabol`, `winstrol-o` — none of which iOS has, though iOS's list
  does carry `mast-p`/`mast-e`/`deca`/`eq` under DIFFERENT ids. The steroid calculator does not
  show the levels link today, so this is latent rather than live.

**Why it is filed rather than fixed here:** a compound is a HALF-LIFE and a tmax, and the web's own
note refuses to invent them — *"a PK curve IS a half-life; with no credible one there is no honest
curve to draw"*. Adding entries means sourcing those numbers, and a wrong one draws a confident
wrong curve. It is also not a blocker: T-17 refuses cleanly, so the affected protocols open the
plotter unseeded rather than plotting the wrong molecule.

**Done when:** each gap is either given a compound with a sourced half-life and tmax, or recorded
here as deliberately unplottable with the reason — and `test_theTwoUnplottableEsters` /
`test_theEsterTableNamesRealCompounds` updated to match, since both are written to go RED the day
the catalogue changes under them.

## T-33 — A ruler gradation draws on top of the unit label on TRT, at DEFAULT size
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** measured on `TRT Dose`, default text size, at rest, by `LeafOverlapUITests/testTRTDose`:

```
StaticText 'unit_nDays'  (217.3, 573.3, 33.3, 18.0)
StaticText '3'           (244.2, 583.2,  7.0, 13.3)
shared region            (244.2, 583.2,  6.4,  8.1)
```

The `3` is a `TickDrum` gradation label. It is drawn ON the `days` unit of the `Every N days` row —
**a value+unit pair with a number from a different control printed through it**, 6.4 x 8.1pt of
shared pixels. A reader sees `days` with a stray digit in it, on the field that decides how often
they inject.

**Why it is filed and not fixed in this pass:** it is not the picker defect and not caused by the
combobox — it is `TickDrum` from T-01a #7 sitting too close to the numeric row's unit, and it has
been there since that commit. Fixing it means changing the numeric row's layout, which is the same
control T-20 is already open against and eleven calculators render through. One change, one pass.

**Why it was not seen before:** this run is the first time `testTRTDose` has been run since T-01a
landed, and at the time the suite reported only ONE pair per screen (T-34, now fixed). **There may
be more behind it — the count of one is not claimed**, and `testTRTDose` has not been re-run since
T-34; when it is, expect the same shape of result `Steroid Dosage` gave (one reported, ten actual).

**Done when:** the drum and the unit label do not share pixels at default size or AX5 on TRT, shown
by `LeafOverlapUITests/testTRTDose` green with no new `expectedOverlaps` entry — and re-checked on
one calculator outside the top five, since eleven render this row.

## ~~T-34 — `LeafOverlapUITests` reported one pair per screen and then stopped~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Status:** done

**What:** the suite sets `continueAfterFailure = false`, and its reporting loop was written to
collect up to six pairs (`if reported >= 6 { return }`). The first `XCTFail` ends the test, so the
loop never reached the second. **Every run this suite has ever had reported exactly one overlap per
screen.**

**Why it matters, and it is not a tidy-up:** one pair reads as "one problem" when it means "at least
one problem". **`Steroid Dosage` at AX5 has TEN, and nine of them had never been seen.** Two
consecutive T-16 runs each came back with a single pair, and each cost a full rig acquisition on a
shared simulator to learn one fact.

**Done:** the pairs are collected and failed ONCE at the end with all of them.
`continueAfterFailure` stays `false` — a failed navigation must still stop the run before it
measures the wrong screen; what changed is the reporting, not the check. Measured: the same screen
that reported `1` now reports `10 PAIR(S) OF ELEMENTS DRAW IN THE SAME PIXELS` with every frame
listed. **Shown red before it was trusted** — it produced the ten against a build whose only
declared overlaps were the old picker entries.

## T-35 — A collapsed control publishes its own glyphs as overlapping leaves
**Priority 3/10** · **Owner:** mac · **Status:** open

**What:** `Combobox` and the pinned result bar both publish an accessibility element that is a
`StaticText` spanning the WHOLE control, **and** their child glyphs as separate leaves inside it.
Measured on `Steroid Dosage` at AX5:

```
StaticText 'Oxandrolone (Anavar)' (16.0, 337.7, 370.0, 265.3)   ← the whole combobox face
Image     'magnifyingglass'       (38.0, 444.7,  50.7,  51.3)
Image     'chevron.down'         (326.0, 459.0,  38.7,  22.7)
StaticText 'Show result'          (16.0, 506.3, 370.0, 153.3)   ← the whole pinned bar
Image     'mark_see_result'       (89.3, 560.7,  71.0,  45.0)
```

`LeafOverlapUITests` calls those three pairs overlaps. **Nothing draws on anything** — the magnifier
sits left of the value, the chevron right of it, both inside the chrome.

**What was tried and did not work,** so nobody repeats it: `accessibilityHidden(true)` on each
glyph; `accessibilityHidden(true)` on the whole face; `accessibilityElement(children: .ignore)` on
the button above them. All three are in place and all three leave the glyphs in the snapshot — they
even carry SF Symbol default labels (`Search`, `Go Down`). **The automation snapshot is not the
VoiceOver tree.** VoiceOver reads one element; XCUITest sees four.

**Why it is not "just delete the magnifier":** it is the web's, it is half of what makes the field
read as searchable (T-01a #2), and it is not what is wrong. The suite's own reasoning — *"a
container is never a leaf"* — is what does not hold here: the container collapsed INTO a leaf.

**Done when:** either the suite stops counting a leaf against the husk its own siblings collapsed
into (probably: a leaf wholly inside another leaf that carries no text of its own is not a second
thing), or SwiftUI is made to publish one element — with the fix shown to work on a real frame, not
assumed. The three entries in `expectedOverlaps` naming T-35 go with it; they are asserted from both
ends, so they will go red the day this is fixed.

## T-36 — Four elements run under the pinned result bar on Steroid Dosage at AX5
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** measured by `LeafOverlapUITests/testSteroidDosage` at AX5, at rest, once T-34 stopped
hiding it. The pinned bar's own frame is `(16.0, 506.3, 370.0, 153.3)`, and running under it:

```
StaticText 'Oxandrolone (Anavar)' (16.0, 337.7, 370.0, 265.3)  shares 370.0 x  96.7
StaticText 'Vial strength'        (24.0, 644.3, 140.3, 156.7)  shares 140.3 x  15.3
TextField  'field_strength'      (196.3, 635.0, 173.7,  65.0)  shares 173.7 x  24.6
```

and `Vial strength` carries on down into the tab bar (`house.fill`, `calendar`), while
`unit_strength` grazes the raised hero by 0.7pt.

**Why it matters:** `field_strength` is the vial concentration — the number every dose on this
screen is divided by. UX-UI-RULES §2: *"Nothing a user acts on may sit under pinned furniture."*
§3 makes reachability at every supported text size binary.

**How it relates to T-20:** same family, different size and different depth. T-20 is one row
straddling the plate's edge at DEFAULT size; this is four elements deep at AX5, including the input
itself and its unit. They should be fixed together at the shared control, and T-20's "done when"
already asks for the form's bottom inset to be measured rather than guessed.

**Why it is only now visible:** T-34. This suite has run on this screen before and reported one pair
each time.

**Done when:** at AX5 on `Steroid Dosage`, no input, unit or label shares pixels with the pinned
bar, the tab bar or the hero — with the five `expectedOverlaps` entries naming T-36 deleted, not
suppressed. Re-checked on one calculator outside the top five, since the bar is shared.

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

## ~~T-41 — Flipping the peptide dose unit multiplies the dose by 1000~~ — **DONE 2026-08-04**
**Priority 9/10** · **Owner:** mac · **Status:** done

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

**CLOSED by `6f40464`** (rebased onto `df98e60`).

**Built — the mechanism, not a special case.** The bounds here are a function of another field's
value, and `CalculatorInput.number` bakes ONE `range`/`step`/`quick` into the spec. So `UnitScaling`
is declared **per field** in `CalculatorModels.swift` and the peptide dose carries one;
`CalculatorScreen` stays generic across all fifteen calculators and is touched in exactly two places
(`vm.spec.fields` → `vm.fields`), to keep the T-16/T-17 merge manageable. Two operations, kept
separate on purpose:

- the **spec scales** — `CalculatorInput.resolved(against:)`, pure, safe on every render, moving the
  unit suffix, range, step, quick chips and drum together;
- the **value converts** — `CalculatorSpec.convertingUnits(from:to:)`, applied once by the ViewModel
  on the transition, re-entrancy guarded.

A resolver that also converted would rescale the number on every layout pass — which is how a field
comes to display a number the engine never used, the invariant on `NumberField.field`.

**Converting alone would have been wrong,** and this is the half worth remembering. iOS held
`0...10000` in BOTH units, so its own default of 500 in mg was **25× the web's entire allowable
maximum**. mcg is now `0...20000`; mg resolves to `0...20`, step `1`/`0.001`, chips
`250 · 500 · 750 · 1000 · 2000` / `0.25 · 0.5 · 0.75 · 1 · 2`.

**Read from the web's SOURCE.** `public/app.js` on `feature/dosage-status-model`:
`handleUnitToggle` at 6237-6245 and the four unit-derived bounds at 6232-6235.

**The saved config is unchanged, and it was checked rather than assumed.** `app.js:6335` writes
`{peptideType, peptideMg, bawMl, dosePerInj, doseUnit, injPerWeek, syringeMl}` — `dosePerInj` is the
**displayed value in the current unit**, never canonicalised to mg. That is what iOS already did.
`testSavedConfigCarriesTheDisplayedValueAndItsUnit` pins the exact seven-key set in both units,
because the DB de-duplicates on the whole config.

**One deliberate divergence, recorded rather than slipped in.** The web's floor is `1 mcg` / `0.001
mg`; iOS keeps `0`. The web clamps on **blur**, iOS clamps on **every keystroke**, so a `0.001` floor
rewrites the leading `0` of `0.5` and the remaining digits land on it — `0.0015`. A non-zero floor is
safe on blur and hostile per keystroke.

**Shown RED before trusted green, both mechanisms independently:** conversion disabled → 6 of 10
tests fail (24 assertions); resolver disabled → the bounds test fails (4 assertions); both restored →
**58/58 unit tests pass**. The bounds test stays green under the first and the round trips stay green
under the second, which is the two mechanisms being covered separately rather than one test passing
for both.

**Round trip pinned in BOTH directions** — `mcg→mg→mcg` and `mg→mcg→mg` return the original — because
a one-way test passes on an implementation that CLAMPS: 500 mcg into a `0...20` mg range gives 20,
which is smaller and plausible. `testConversionIsNotAClamp` asserts that explicitly.

**Device evidence:** `docs/ui-audit/t41-peptide-dose-unit/` — `t41-01-peptide-500-mcg.png` and
`t41-02-peptide-0.5-mg.png`, both self-identifying (Peptide title, field label, unit suffix), plus a
UI test that drives the picker and asserts the round trip on the device.

**A trap caught in the harness itself, worth the next person's time:** the first version of the UI
test wiped every `t41-*.png` in `setUp` — which XCTest runs before **every** test method — so the
second test deleted the first's frames. The run reported `Executed 2 tests, with 0 failures`, printed
both frame paths, and left **nothing on disk**. Staleness is now closed per name in `shot()`. Check
the artefact, not the exit code.

**T-43 gets this for free:** it is the same defect on the Free T Index total-testosterone picker
with a factor of 28.84, and it now needs a `unitScaling:` declaration rather than a new mechanism.

## T-46 — `step` is declared on every numeric field and read by nothing

**RENUMBERED from T-45 by mac, 2026-08-04.** T-45 was already handed to the GLP-1
truncation job before this was filed — my allocation error, not the filer's. Two tasks under one
ID is the exact failure rule 10 exists to prevent, and it recurred inside my own block because I
handed out IDs from it without recording them. Worth noting the block scheme only protects
BETWEEN the two sides; WITHIN a block it protects nothing unless issued IDs are written down as
they are issued.
**Priority 3/10** · **Owner:** mac · **Status:** open

**What it does now:** `CalculatorInput.Kind.number` carries a `step`, fifteen calculators declare one
(`0.5` days, `0.05` mL, `10` mg/week…), `FieldRow` passes it into `NumberField`, and `NumberField`
stores it in a `let` that nothing reads. It became inert when the hand-rolled `−`/`+` pair was
replaced by `TickDrum`, which moves in `drum` values instead. **The web snaps to its step on blur**
(`commitDose`: `Math.round((clamped - min) / step) * step + min`); iOS does not snap at all, so a
peptide dose of `0.4567 mg` is accepted where the web would settle it to `0.457`.

**Why this is a 3 and not higher.** No wrong number is displayed and no wrong number is saved — the
field shows exactly what the engine uses, which is the invariant that matters. What is lost is
tidiness of entry, and the value is the user's own typing rather than something the app invented.

**Why it is filed at all:** a spec field that states a number nobody honours is a trap for whoever
wires it up next. It was found during T-41, where the step had to be made unit-dependent to be
correct — and it is correct now, and still unread. Either snap on blur like the web, or delete
`step` from the model.

**Done when:** either iOS snaps to `step` on blur and a test pins `0.4567 mg → 0.457`, or `step` is
gone from `CalculatorInput.Kind.number` and its fifteen call sites.

**Found by:** T-41, 2026-08-04.

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

## ~~T-51 — iOS logs no injection time, so the web plots its doses at an assumed noon~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** mac · **Status:** done
## ~~T-45 — The GLP-1 option lists were truncated at the web's warning thresholds, and the warnings were gone with them~~
**Priority 9/10** · **Owner:** mac · **Status: done** — `42dfb42` (the change) + `996a9b3` (the
measurement, and two harness defects it found). Unit 19/19 in a target of 67/67, UI 3/3, two frames.

**What it did:** `CalcConst` held PREFIXES of four `app.js` arrays. Counted on both sides
2026-08-04, and the truncation claim in T-01b-3/4/5 is confirmed to the value:

| list | iOS was | web is | iOS stopped at | web runs to |
|---|---|---|---|---|
| `glp1Concs` / `GLP1_CONC_VALUES` | 12 | **17** | 20 mg/mL | 60 mg/mL |
| `semaDoses` / `SEMA_DOSE_VALUES` | 11 | **22** | 2.4 mg | 7.5 mg |
| `tirzDoses` / `TIRZ_DOSE_VALUES` | 7 | **17** | 15 mg | 40 mg |
| `retaDoses` / `RETA_DOSE_VALUES` | 16 | **22** | 12 mg | 24 mg |

**Why it was worse than a short list, and both halves are in the fix:**

1. **Every dose list was cut at EXACTLY the web's warning threshold** — 2.4 / 15 / 12, the values
   behind `isValid && dose > N` on the three pages. iOS therefore enforced the ceiling by deleting
   the option instead of warning about it, and the sentence went with the option: a user prescribed
   above the Wegovy or SURMOUNT ceiling got **nothing**, where the web gives them
   *"Exceeds typical weekly maximum of N mg — verify with your prescriber."* Neither of the web's two
   GLP-1 `InfoBox`es existed on iOS; the second is
   *"Draw is less than 1 unit — accuracy may be limited at this scale."* (`isValid && volumeMl < 0.01`).
2. **The control was a closed SwiftUI `Menu`, so the list WAS the reachable set.** A 25 mg/mL
   compounded vial had no correct option; the nearest was 20, and `glp1(conc: 20, dose: 0.5)` returns
   **0.025 mL / 3 u instead of 0.020 mL / 2 u — a draw 25 % larger than the true one**, on a screen
   that looks entirely normal.

**What was built:** all four arrays restored verbatim; both `InfoBox`es ported as
`CalculatorResult.notes` and rendered as an amber `AdvisoryNote` (amber not red — a dose over the
typical maximum may well be the prescribed one, and red here would teach the user to ignore red on
this screen); `conc` and `dose` on all three calculators changed from `.picker` to `.number`, so they
take **typed entry** clamped to the array's own bounds with the full array spent as the `TickDrum`
ruler beside the field.

**Typed entry was required, not a nicety.** Lengthening the list does not fix #2 on its own — any
value BETWEEN two entries stays unreachable, and compounded vials do not come on a preset ladder.
The web accepts a typed value off the list on **both** builds: deployed/`master` `ConcDrumField`
takes any positive number rounded to 2 dp, and `feature/dosage-status-model`'s `QuickPickerField`
clamps to the array bounds and snaps to half its first gap. The page's own FAQ names **12 mg/mL** as
a strength compounders produce and 12 is **not** in `GLP1_CONC_VALUES` — so the web's own copy
describes a value only typed entry can reach.

**The config shape did not move, deliberately.** `.picker` and `.number` both encode through
`case .number` in `configJSON()`, so the key sets are unchanged — semaglutide 6, tirzepatide and
retatrutide 3 — and a test asserts it. Defaults are unchanged too (5/7.5/5 and 0.5/5/1); moving them
is SH-5's job. **The wrong comment in `configExtras` is corrected in the same file:** it claimed the
three GLP-1 slugs do not share a config shape and that *grouping* them caused the mismatch. All three
`handleSave`s write the same six keys on `master`, on the branch and in the deployed bundle, so
**splitting** them caused it. The keys themselves are NOT changed here — see T-01b-4 #2 / T-01b-5 #2,
which must close with a row read back out of the database.

**Evidence — measured 2026-08-04 on iPhone 16 Pro / iOS 18.3, not inspected.**

**1 · `Tests/InjectBuddyTests/Glp1OptionParityTests.swift` — 19 tests, 0 failures**, inside a whole
unit target of **67 tests, 0 failures**. Pins each array's length and every value against literals
transcribed from `app.js`; the thresholds; the warning strings to the character including the U+2014
em dash; the warnings firing one ladder step above the threshold and silent AT it; the 25 mg/mL case
as arithmetic (`0.025 / 0.020 = 1.25`); and the config key sets.

**2 · The suite was SHOWN TO FAIL before it was trusted.** `glp1Concs` was reverted to the shipped
12-entry prefix, rebuilt and rerun: **7 of the 19 went red**, naming the defect in the words of the
finding — *"glp1Concs: 12 values, web has 17"*, *"glp1Concs stops at 20.0, web runs to 60.0"*, and
the 25 mg/mL reachability assertion. Restored, rebuilt, green again. A reference recorded from a
broken state passes forever; this one demonstrably does not.

**3 · `Tests/InjectBuddyUITests/Glp1ReachableValueUITests.swift` — 3 tests, 0 failures**, on the
signed-in app. `25` goes in through the KEYBOARD and the card reads back `0.020 mL` / `2 u` — not the
old 20 mg/mL answer of `0.025 mL` / `3 u`. 2.5 mg (off the old 11-entry list entirely) raises the
advisory; 2.4 mg does not.

**4 · Frames**, both self-naming (the screen renders "Semaglutide"), arrival asserted before each:
- `frames/t45-01-semaglutide-conc-25-typed.png` — **conc 25 mg/mL, typed, previously unreachable**,
  dose 0.5 mg, card reading `Draw 0.020 mL`.
- `frames/t45-02-semaglutide-over-maximum-warning.png` — dose 2.5 mg, `Draw 0.500 mL`, and the amber
  advisory **"Exceeds typical weekly maximum of 2.4 mg — verify with your prescriber."** on the glass.

Sources cross-checked: the working tree (`master`), `feature/dosage-status-model` re-read this session
via `git show FETCH_HEAD:public/app.js` (arrays at `:3916–3919`, warnings at `:10075`, `:10191`,
`:10306`) and the deployed `https://www.injectbuddy.com/app.js?v=e10ca869` — **all three agree on the
four arrays and on all six warning strings.**

**Two test-harness defects were found and fixed here, because both produced a green beside no
evidence.** The suite's keyboard-dismiss tapped `app.staticTexts.firstMatch`, which resolves offscreen
at x = −313, so all three tests died on `kAXErrorCannotComplete` before asserting anything; it uses
the app's own `kb_done` now. And the warning frame was first shot where the assertions ran, which
photographed the note scrolled under the pinned bar — then a swipe loop that overshot and photographed
the FAQ while still passing. The frame is now taken on the result sheet, with the sentence asserted to
be inside the window before the shutter.

**Left open, filed on:** T-91 (the typed value is not snapped to the web's grid), T-92 (`conc` clamps
at 60 where the deployed build has no upper bound), T-93 (no preset chips under the two fields).

**STRENGTHENED 2026-08-04 — the web's own FAQ settles this better than either side's argument did.**
`app.js:10264`, semaglutide:

> *"Compounded semaglutide vials vary — the most common concentrations are 2.5 mg/mL, 5 mg/mL, and
> 10 mg/mL, but some compounders produce 2 mg/mL, 7.5 mg/mL, or **12 mg/mL** formulations. …
> **Selecting the wrong concentration is the most common dosing error — it can mean you draw two or
> three times the intended dose.** … **Use the Custom option if your vial doesn't match a preset.**"*

Three things, all in the product's own voice:

1. It names **12 mg/mL** as a real vial, and `GLP1_CONC_VALUES` contains 12.5, **not 12**. *The web's
   own list does not cover the web's own documented example.* That is the proof that no array is
   long enough, and it is why the fix is typed entry rather than a longer list.
2. It names the harm, and it is worse than the 25% this task was filed with: **wrong concentration is
   the most common dosing error, worth two or three times the intended dose.**
3. **"Use the Custom option if your vial doesn't match a preset."** The web documents an escape
   hatch. On iOS's closed `Menu` that sentence was **advice the user could not follow** — so iOS was
   not merely stricter than the web, it made the web's own printed instruction impossible.

The sub-unit-draw note ported alongside the ceilings matters for the same reason: high concentration
means small volume, which is the real risk once the ceiling is gone.

## Note — a stale T-51 was removed here by a merge cleanup, 2026-08-04

The T-45 worktree branched from a `feature/tabview-shell` that predated T-51 being closed, so the
merge resurrected the OPEN version of the entry alongside the struck-through one above. Both
described the same task; the open copy was the older text.

**This is not a rule-7 deletion.** Nothing was struck and nothing was lost — the closed entry, with
its evidence, is intact further up. What was removed is a duplicate heading a merge reintroduced.
Recorded because "T-51 appears twice" is exactly the two-tasks-one-ID confusion rules 9 and 10 were
written for, and a silent tidy-up would look identical to one of us quietly dropping a task.

**The general hazard, worth more than this instance:** an agent working in a worktree cut from an
older tip will re-add anything closed since it branched. Long-running agents need to rebase before
they write to a shared file, not only before they commit code.

## ~~T-52 — The log-dose sheet cannot record a dose that was not the planned one~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Status:** done

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

**Root cause: the amount was never a value, only a derivation.** `NewDoseLogPin.init(for:dosedOn:)`
computed `draw_ml` from the protocol and there was no parameter a caller could use to say otherwise
— the same shape as T-03's site, one layer down.

**The column, read from the web's source and not from a doc about it.** `feature/dosage-status-model`
→ `app/api/dose-log/route.ts` POST writes **`dose_label`** (text, e.g. `37.5 mg`), and
`DoseHistory.tsx:509,594` renders and edits it as the history's "Dose" column. `draw_ml` is the
separate numeric volume. **`DoseHistory.tsx:89` falls back to the protocol's planned dose when
`dose_label` is null** — which is exactly why iOS leaving it null was invisible: a half dose read
back as a full one because the plan was the only thing left to read.

**Built:** `CalculatorResult.dosePerInjection` (structured, beside `drawMl`, for the same reason —
a dosing number must not be parsed back out of a formatted row); `DoseVolume.perInjection`, one
gated re-evaluation returning volume and dose together; a `DOSE AMOUNT` field in `LogDoseSheet`
seeded with the derived dose, unit shown beside the value and not editable; `dose_label` on
`NewDoseLogPin`, `OwnedDoseLogPin`, `DoseLogPin` and both `select`s. **`draw_ml` scales with the
amount** — half the mg is half the mL, exact for every family because each one's volume is linear
in its dose. All three log paths fill `dose_label`; the dashboard and calendar log the plan.

**Done — measured.** `LogDoseAmountRoundTripUITests` typed `12.75` over the seeded `74.5` (a value
no protocol on the account derives, so a decorative field could not pass) and logged. Before the
run, every iOS-written row on this account had `dose_label` NULL:

```sql
select id, protocol_id, dosed_on, draw_ml, site, dose_label from dose_log
where user_id = 'c8926abc-52b0-41f3-8968-bc44f56e1dd1' order by dosed_on desc;
```
```
d5a4f448 | fd1d8717 | 2026-08-03 | null  | null   | null
92c3af8f | d94cc62b | 2026-08-03 | 0.373 | R Delt | null
```

After — the run typed `12.75` over a seeded `74.5`, and BOTH columns moved:

```sql
select d.id, s.label, s.config->>'mgWeek' mg_week, d.dosed_on, d.draw_ml, d.site, d.dose_label
from dose_log d join saved_dosages s on s.id = d.protocol_id
where d.user_id = 'c8926abc-52b0-41f3-8968-bc44f56e1dd1' order by d.created_at desc limit 2;
```
```
3c4f9f5b | TRT Dose | 149 | 2026-08-04 | 0.064 | L Glute | 12.75 mg
92c3af8f | TRT Dose | 149 | 2026-08-03 | 0.373 | R Delt  | null
```

**Read the two rows together — that is the whole task.** Same protocol, one day apart. The
2026-08-03 row is what this app used to write: `0.373` mL, the plan, with nothing saying what dose
it was. The 2026-08-04 row carries `12.75 mg` because that is what was typed, and `0.064` mL —
`12.75 ÷ 200 mg/mL` — because the volume followed the dose instead of staying at the plan's
`0.373`. Before this change the same tap would have written `0.373` and a NULL, and the web would
have rendered it as a full `74.5 mg` dose off the fallback.

Unit suite on the shipped build: `Executed 64 tests, with 0 failures` (see T-24 for the four that
were red first). Frames: `03-logdose-keypad-after.png` (the field visible and focused with the
keypad up, `74.5` beside `mg`) and `04-logdose-amount-edited.png`.

## ~~T-53 — The log-dose sheet offers two protocols the user cannot tell apart~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Status:** done

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

## T-47 — Correct code that nothing calls, three times in one day
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** three separate defects found on 2026-08-04 turned out to be the same shape — an API that
is present, correct, and referenced by nothing:

- `CalculatorCategory.subtitle` — all four strings defined, `ToolsScreen` never mentioned it
  (T-01e, now rendered).
- `SteroidCatalog.canInject` — correct for all twelve compounds, consulted by nothing, so the
  steroid calculator offers injectable inputs for oral-only compounds and returns 0.75 mL for a
  tablet (T-44, still open).
- `.cyclePlotter` — `isListed` is true, so it is *meant* to be browsable, but it appears in no
  category's `allMembers` and `ToolsScreen` enumerates only `members` (T-11, still open).

**Why this is a task and not an observation.** Each was found by accident, while doing something
else. None would fail a build, a unit test or a UI test — **a declaration nobody reads is not a
compile error, it is silence** — and the same silence is what CLAUDE.md already records for a source
file missing from an Xcode target. Two of the three were shipping user-visible defects; one of them
(`canInject`) produces a wrong dose figure for a tablet.

**What makes it worth sweeping rather than fixing case by case:** three in a single day, all found
incidentally, strongly suggests the population is larger than three. Nobody has ever looked.

**Done when:** the app's own declarations are swept for unreferenced members — a script over
`Sources/` listing every `var`/`func`/`case` on a shared type whose name appears exactly once in the
tree — and each hit is either wired up, deleted, or recorded here with the reason it exists
unreferenced. The sweep matters more than the list: **run it, keep it runnable, and pair it with
win's doc-claim checker**, which is the same idea aimed at prose.

**RAISED 4 → 6, 2026-08-04, on win's argument, which is better than the one I filed it with.** I
priced it 4 because the three known instances are already tracked individually. That reasons about
the KNOWN three; the point of the task is the UNKNOWN ones. Three found *incidentally in a single
day, while doing other things*, means the population is larger and nobody has ever looked — and two
of the three were shipping user-visible defects, one of which produces a wrong dose figure for a
tablet. The tracked-already argument justifies not fixing them twice; it does not justify not
looking.

**This and the doc-claim checker are two halves of one idea, and whoever builds the second should
read the first.** The claim checker catches a SENTENCE that no longer matches the code; this catches
a DECLARATION the code never consults. Same family: *a thing that exists and is never read.*

**PRACTICAL CAUTION, from win having already built the analogous tool — this is where the effort
actually goes.** "Referenced exactly once" will be noisy: protocol conformances, `CaseIterable`
members, anything reached by reflection or by a `switch` over `allCases` will look unreferenced and
be perfectly fine. **Expect to spend most of the work on the exclusion list rather than the finder,
and write the REASON beside each exclusion** — without it the next reader cannot tell a considered
exemption from an oversight, which is the one thing win would have done differently in the claim
checker. An exemption that exempts nothing, or that nobody can audit, is the §5.32 shape this
project already knows.

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

## T-56 — The rig's lock cannot tell compiling from driving the device
**Priority 4/10** · **Owner:** mac · **Status:** open

**NARROWED 2026-08-04, and the original framing was wrong — recorded rather than rewritten, per
rule 7.** This was filed as "the lock does not survive a killed capture run", after a SIGKILLed
sweep left the rig held and it was released by hand.

**That is not a defect. The lease is TIME-based and self-clearing, and deliberately so.** Its own
header says a pid check "provided NO mutual exclusion while printing that it had", that expiry
"does not depend on any process still existing", and that an expired lease is reclaimed **loudly**
— `EXPIRED LEASE from '<holder>' … reclaiming` — precisely because "an expired lease may mean the
holder DIED MID-RUN". So the mechanism already handles the case the task was filed about. The
hand-release was impatience, not repair: the killed sweep would have self-cleared in 900s. **The
original "done when" — record the owning pid — would have made it worse**, reintroducing the exact
check the design rejected.

Confirmed in the wild the same day: the rig was held by a lease belonging to a GLP-1 agent that had
died on a session limit. It cleared itself. Mac waited it out rather than stealing it, which is
right — forcing a lock whose holder you *believe* is dead is the reasoning a time-based design
exists to make unnecessary, and `testmanagerd` being resident means no one can prove from outside
that nothing is mid-flight.

**The real gap, which both sides converged on independently:** the lock guards ONE resource while
two different ones are being contended. A `xcodebuild` compile contends for CPU; a test run contends
for the **simulator**. One lease over both means either agents block each other for no reason, or —
as observed — the lock warns that `xcodebuild` is already running while the lease is free, because a
worktree agent was compiling without taking it. It cannot currently distinguish the two, so it is
simultaneously too strict and too permissive.

**PROVEN 2026-08-04, and it is no longer a theory.** A T-05 run acquired the device lock after **99
retries** and then died:

> `error: unable to attach DB: … build.db: database is locked. Possibly there are two concurrent
> builds running in the same filesystem location.`

**The rig lock protected the simulator and nothing protected `DerivedData`.** The device was held
legitimately while an agent compiled into the same build directory. So the framing "one lock cannot
tell compiling from driving" is still too generous: **these are two different resources that need two
different locks, and only one of them exists.** A single lease can never be right — held for the
whole build it serialises work that need not be, held only for the run it leaves the build directory
unguarded, which is what happened.

**Done when:** a build and a device run are serialised against each other by **two** leases — one for
`DerivedData`, one for the simulator — with the device lease held only for the run; and the lease
records its holder's pid **as information**, so a waiter can tell a dead holder from a live one
without that pid ever becoming the exclusion mechanism. Demonstrated by a compile and a capture that
neither falsely block nor falsely pass, and by a waiter correctly identifying a dead holder.

## ~~T-57 — The web silently drops two protocol types, and three ACTIVE protocols are invisible today~~ — **DONE 2026-08-04**
**Priority 7/10** · **Owner:** win · **Status:** done

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

**BUILT 2026-08-04 — and measured by running the real function over the real production configs, not
by inspection.** `npx tsx` against `deriveProtocols` with the exact configs read out of
`saved_dosages`:

```
derived: 3 of 5
  bpc157     dose=250 mcg  vol=0.1   freqDays=1     route=SubQ conc=2500
  oilblend   dose=275 mg   vol=1     freqDays=2.33  route=IM   conc=275
  microdose  dose=10 mg    vol=0.05  freqDays=3.5   route=IM   conc=200
dropped: femalehrt, totallynew
[account-schedule] active protocol dropped: no deriveDose branch for calculator_type "totallynew" …
```

Four changes in `lib/account-schedule.ts`:
- **`microdose` joins the trt/eod branch.** Verified against production first: its config is
  key-for-key identical to trt's, so this is one word, not a new derivation.
- **`oilblend` gets a branch**, with the maths transcribed from the calculator itself
  (`public/app.js:7705-7712`) rather than inferred — `totalMgMl` is the SUM of the components'
  mg/mL and `injVol` is already the draw volume. The live row resolves to 275 mg in 1 mL every
  2.33 days, which is the blend the user actually built.
- **`femalehrt` and `bioavailability` go on `NON_SCHEDULABLE`, each with its reason.** femalehrt's
  `route` is `patch`/`cream`/`oral` in every production row — a patch has no draw volume, no site
  and no rotation, so it was correctly not on an injection schedule and was simply never *said* to
  be. It still drops, but now deliberately and silently rather than accidentally and silently.
- **An unrecognised type is now `console.error`'d** naming the type and the row id and saying what
  to do about it. Never thrown — one bad row must not take the dashboard down.

**The third clause is now done too — `b66577b9`.** `UnscheduledProtocol` is its own minimal type,
`{id, label, calc, color, reason}`, with **no route, dose, volume, sites or inventory to forge**.
Returned by `deriveUnscheduled`, never merged into `protocols`. Deliberately NOT a flag on
`DerivedProtocol`: that type's `freqDays`/`vol`/`sites`/`inv` are non-optional and feed `isDoseDay`,
`eventsForDay` and the inventory and stats loops, so making them optional would put a schedule-shaped
hole into the calendar, rotation and inventory paths.

**The sharper half of the bug, found while fixing it:** `UpcomingDoses` returned `null` outright when
`protocols.length === 0` — so a user whose only active protocol is non-schedulable saw a **blank
dashboard with no explanation**, not merely a missing card.

**MEASURED — both functions run over the real production configs:**

```
scheduled:   1  -> oilblend(275 mg, 1mL, every 2.33d)
unscheduled: 3
   femalehrt        -> patch, cream or oral dose, so no injection schedule to show
   femalehrt        -> patch, cream or oral dose, so no injection schedule to show
   bioavailability  -> a one-off estimate, not an ongoing protocol
overlap between the two lists: 0   (a row is in exactly one)
unscheduled carry no schedule fields: true
every active row accounted for: 4/4 YES
```

**4 of 4, where two were previously invisible.** Zero overlap, and the unscheduled rows provably
carry none of the schedule fields, so nothing can place them on a calendar day, a rotation track or
an inventory meter.

**Severity note so it is not overstated later:** no user currently holds ONLY non-schedulable
protocols, so the blank-dashboard case is **latent**. The invisibility itself was live and is fixed.

## ~~T-58 — Every bpc157 protocol shows "Draw volume unknown", from a config-key mismatch~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** win · **Status:** done

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

**BUILT 2026-08-04.** Both readers fixed, current shape first and legacy second in each:
`lib/account-schedule.ts`'s bpc157 branch, and `components/account/ProtocolList.tsx:119-126` — note
the path, it is `components/account/`, not `components/account/dashboard/` as originally filed.

Measured on the live active row `{dose:250, bawMl:2, vialMg:5, syringeMl:0.5}`: concentration now
resolves to **2500 mcg/mL** and draw volume to **0.1 mL**, where both were `null`/`0` before and the
panel read "Draw volume unknown". `npx tsc --noEmit` clean.

**The legacy keys are kept rather than replaced.** No production row carries them today, but they
exist in older rows elsewhere and in `app/api/dosages/route.ts:27`'s validation; dropping them would
move the failure rather than fix it.

## ~~T-59 — iOS-logged history rewrites itself when a protocol is renamed; web-logged history does not~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** mac · **Status:** done

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

**CLOSED.** Four of the five come from `DoseSnapshot` (`Core/Models/DoseSnapshot.swift`), derived
from the saved protocol the way the WEB derives them — `protocol-meta.ts` (`compoundOf`,
`protoDisplay`, `abbrevCompound`) and `lib/account-schedule.ts` (`deriveProtocols`) on branch
`feature/dosage-status-model`, read from that source. That is deliberate: the fallback these columns
replace **is** the web's own derivation, so writing the same strings changes nothing a user sees
today and only stops it changing tomorrow. The fifth, `dose_label`, was closed first by T-52 and is
NOT re-derived here — it describes the injection rather than the protocol and the user can edit it;
freezing the plan would have silently undone T-52.

**`category` is the raw `calculator_type` slug, not a display name.** The live column reads
`trt` / `peptide` / `steroid` / `tirzepatide`; `DoseHistory.tsx:88` maps it through its own `CATEGORY`
table at render time. A pretty name would have sorted and filtered into a bucket of its own, apart
from every web-written row.

**Evidence — the row, then the rename, then the re-read.** Written over PostgREST with the QA
account's JWT (`user_id` in the body, as RLS requires), then:

```sql
update saved_dosages set label = 'RENAMED BY T-59 PROOF'
  where id = 'd94cc62b-aaa7-4f4c-ad69-72f73815050a';

select l.id, s.label as live_protocol_label, l.protocol_label as frozen_snapshot,
       l.compound_label, l.category
from dose_log l join saved_dosages s on s.id = l.protocol_id
where l.protocol_id = 'd94cc62b-aaa7-4f4c-ad69-72f73815050a' order by l.dosed_on;
```
```
 325c7e74… | RENAMED BY T-59 PROOF | TRT Dose | Test E | trt    ← written with the snapshot
 92c3af8f… | RENAMED BY T-59 PROOF | NULL     | NULL   | NULL   ← pre-fix iOS row
 3c4f9f5b… | RENAMED BY T-59 PROOF | NULL     | NULL   | NULL   ← pre-fix iOS row
```
The new row still says `TRT Dose` under a protocol now called something else; the two older iOS rows
have nothing of their own and render the new name. That is the defect and the fix in one result. The
label was restored to `TRT Dose` immediately afterwards (verified by re-select).

Full snapshot on the two rows written:
```sql
select id, dosed_on, scheduled_on, protocol_label, compound_label, category, dose_label,
       draw_ml, site from dose_log
where id in ('325c7e74-977e-433f-94b2-96d480a416e1','079856d1-c18f-4137-ae18-daf3a9571ad6');
```
```
 325c7e74… | 2026-08-02 | 2026-08-02 | TRT Dose                              | Test E                   | trt     | 74.5 mg | 0.373 | L Delt
 079856d1… | 2026-08-04 | 2026-08-04 | TB-500 (Thymosin Beta-4) · 350mcg/inj | TB-500 (Thymosin Beta-4) | peptide | 350 mcg | 0.042 | Abdomen R
```
`compound_label` is the web's own re-ordering of a dose-first label — `"105mg/wk · Testosterone
Acetate"` → `"Test Acetate"` — checked against the four web-written production rows that carry it.

**Unit:** `DoseLogSnapshotTests` asserts the encoded body of `OwnedDoseLogPin` (the struct that
actually becomes the request, now non-`private` so it can be asserted) carries all thirteen column
names. 11 tests, green in an 85-test run, and shown failing first against a deliberately wrong
column name. See T-51 for the same evidence chain on the other three columns.

## T-60 — The web has TWO compound tables that disagree on 13 half-lives, and one falsely claims to be the only one
**Priority 8/10** · **Owner:** pouroa · **Status:** filed — **PARKED 2026-08-05 by the owner**, who is resolving it with a separate agent.

**Nothing else waits on it, but two things must not happen while it is parked.** Do not reconcile iOS to `spec/compounds.json` — that is the table the live plotter does NOT use, and doing so moves iOS away from shipped behaviour on the authority of a file the plotter ignores. And do not "fix" either table toward the other: which half-life is correct is a pharmacological question, not an engineering one, which is why it is parked rather than assigned.

`spec/verify-claims.mjs` reports this as KNOWN FALSE against T-60 every run, so it stays visible without failing the build.

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

## ~~T-61 — The web's dashboard greeting paints its own text at 1.50:1~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** win · **Status:** done

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

**DONE `dedcc572` — and the fix is the opposite of what this task assumed.** Measured against the
real background, `--ib-bg: #fafafb`, not white:

| stop | luminance | contrast |
|---|---|---|
| old midpoint `#5fe8da` | 0.6521 | **1.43:1** — fails the 3:1 large-text floor |
| base `#0a9d90` | 0.2621 | 3.23:1 — legal, but only just |
| new midpoint `#075e56` | 0.0872 | **7.34:1** |

**There was no lighter colour that could work, which is why "pick a lighter highlight" was the wrong
brief.** The base is itself only 3.23:1, so on a near-white canvas *brighter* and *higher-contrast*
pull in opposite directions — every lighter peak fails harder than the one it replaces. Fixed by
inverting the sweep to peak **dark**. Worst case is now 3.23:1 at the base instead of 1.43:1 at the
peak.

**Divergence from iOS, recorded so nobody "corrects" it:** iOS uses the same two colours in the
opposite direction — a `#075E56` base peaking lighter at `#0A9D90`. Both are legal and share the same
worst case, so there is **no accessibility difference**. The web keeps `#0a9d90` as its resting
colour purely so a live product's greeting does not change appearance for zero measurable gain.

**Audited for the same pattern:** `public/home.js`'s hero headline uses the same
`background-clip:text` technique at 4.77:1 and is fine. No other occurrence in the codebase.
`prefers-reduced-motion` still disables the animation.

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
**Root cause: the card drew `label`, and iOS writes a CONSTANT into `label`.**
`CalculatorViewModel` saves `label: spec.saveTitle` — the calculator's own screen title. Every TRT
protocol saved on iOS is therefore literally named "TRT Dose", and `ProtocolLabel.split` finds no
` · ` to take a dose half from, so the supporting line was empty. The two rows on the QA account are
real and differ only in `mgWeek` — 137 and 149:

```sql
select id, label, config->>'mgWeek' mg_week, config->>'strength' strength, config->>'mode' mode
from saved_dosages where user_id = 'c8926abc-52b0-41f3-8968-bc44f56e1dd1'
  and calculator_type = 'trt' and label = 'TRT Dose';
```
```
249135d4 | TRT Dose | 137 | 200 | perweek
d94cc62b | TRT Dose | 149 | 200 | perweek
```

**Built:** `Core/Calculator/ProtocolSummary.swift`. The line is derived from the CONFIG, never from
the label — dose per injection, interval, what is in the vial, and the compound where the heading
does not already name it. **One unit convention, per injection**, which is the web's own `doseLabel`
convention (`lib/account-schedule.ts` — every branch states the dose for one injection) and closes
S-04 #5's three-conventions-in-one-list at the same time.

**Distinguishability is guaranteed rather than hoped for.** `ProtocolSummary.lines(for:)` renders
the whole list at once and, where two cards would still read alike, appends the config keys that
actually differ. Two rows cannot be identical in `calculator_type` + `config` — the unique index
forbids it — so a differing key always exists to name. Unit-tested on the pair the derived language
genuinely cannot separate (same weekly dose, same interval, same vial, same ester, one saved
`perweek` and one `ndays`): the lines come out `… · mode perweek` and `… · mode ndays`.

**Done — measured.** `LogDoseAmountRoundTripUITests` reads every card's rendered text off the device
and fails if any two are equal. Against the account in the frame:

```
T-53 CARD: TRT Dose                          | 74.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate
T-53 CARD: TRT Dose                          | 68.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate
T-53 CARD: TB-500 (Thymosin Beta-4)          | 350 mcg · every 1.75 days · 25 mg in 3 mL
T-53 CARD: Masteron (Drostanolone) Enanthate | every 3.5 days · 200 mg/mL
T-53 CARD: Testosterone Cypionate            | every 1.08 days · 250 mg/mL
```

The first two are the pair from the frame — same heading, and now `74.5 mg` against `68.5 mg`,
which is `149 ÷ 2` against `137 ÷ 2`. Photographed:
`docs/ui-audit/2026-08-04-logdose/01-logdose-sheet-t5352.png`.

**Not fully closed by this, and filed as T-21:** two of those five cards state no dose at all —
`Masteron` because it was saved in a mode `evaluate` does not run, `Testosterone Cypionate` because
its weekly dose is 0. They are distinguishable, which is what this task asked for, but "one
convention" is still "one convention and two blanks".

## T-81 — The projection's safety valve deletes long-running protocols from the dashboard and calendar
**Priority 8/10** · **Owner:** mac · **Status:** open

**What:** `DoseProjection.projectedDoses` ends its day loop with

```swift
step += 1
// Safety: never loop forever on a degenerate interval.
if step > days * 4 + 8 { break }
```

but `step` is not an iteration count. Forty lines earlier it is **fast-forwarded to the window**:

```swift
if startDay < windowStart {
    let elapsed = windowStart.timeIntervalSince(startDay) / 86_400.0
    step = max(0, Int((elapsed / interval).rounded(.down)))
}
```

So `step` starts at "how many doses this protocol has had since it began" and is compared against a
budget sized for "how many days the window is". For any protocol old enough, the valve fires on the
**first** iteration and the function returns an empty array — silently, with no error and no
partial result.

**The threshold is `elapsedDays > interval × (days × 4 + 8)`**, so it is worst for the most
frequent protocols:

| window | cap | daily (1 d) vanishes after | E3.5D vanishes after |
|---|---|---|---|
| dashboard `projectedDoses(days: 14)` | 64 | **64 days** | 224 days |
| calendar / `nextDose(lookAheadDays: 30)` | 128 | **128 days** | 448 days |

**Found by accident and reproduced deliberately.** `DoseLogSnapshotTests` projected a twice-weekly
peptide started 2026-01-01 over a 7-day window from 2026-08-04 and got **nothing**: cap 36, start
step 61. Widening the window to 14 days made the same protocol project normally. Nothing about the
protocol changed — only the size of the window it was asked about, which is the opposite of how a
window should behave.

**Production, today:** one active protocol is already past the 30-day cap. The one that matters is
the next: `Retatrutide · 4.5mg/inj`, started 2026-01-06, sits at step **60** against the dashboard's
cap of **64** — it disappears from the dashboard in about a fortnight, and `BPC-157 · 250mcg/inj`
(daily, step 35) follows it 29 days later.

```sql
-- interval derived the way DoseProjection.injectionIntervalDays derives it
select calculator_type, label, coalesce(start_date, created_at::date) as start_day,
       floor((current_date - coalesce(start_date, created_at::date)) / interval_days) as fast_forward_step
from (...) p where interval_days is not null order by 4 desc;
```
```
 trt     | 200mg/wk · Testosterone Cypionate | 0202-05-04 | 190370   ← bad start_date, but it is the shape
 peptide | Retatrutide · 4.5mg/inj           | 2026-01-06 |     60   ← dashboard cap is 64
 peptide | BPC-157 · 250mcg/inj              | 2026-06-30 |     35   ← daily; cap is 64
```

**Why it is an 8:** it is a dosing tracker whose whole value is being used for months, and this makes
a protocol quietly stop appearing **because** it has been used for months. The user sees no next
dose, no calendar entries and no error — indistinguishable from "nothing is scheduled". A protocol
that has run longest is the one most likely to be relied on.

**Done when:** the valve counts iterations of the loop it guards, not doses since the protocol
started — and a test projects a protocol started a year ago over a 7-day window and gets the doses in
that window.

## T-82 — Two day-string frames, and half of every day they disagree
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** `dose_log.dosed_on` is a calendar day, and this app produces that string in **two
different timezones**:

- `LogDoseSheet.dayFormatter` sets `f.timeZone = TimeZone.current` — the device's day.
- `DoseProjection` formats every occurrence day with `DoseDateFormat.dayFormatter`, pinned to UTC,
  and the dashboard and calendar log from occurrences.

East of UTC the two disagree from local midnight until UTC midnight — twelve hours a day in
Auckland, where the owner is. `dpFormatDay(2026-08-04 09:00 NZST)` is `"2026-08-03"`, so a dose
ticked on the dashboard on a Tuesday morning is stored as Monday, while the same dose logged through
the sheet is stored as Tuesday.

**What it costs:** the two rows are different rows. The unique index is `(protocol_id, dosed_on)`, so
the same injection logged from two surfaces on the same morning **upserts into two rows, not one** —
the supply ledger then subtracts two draws for one injection. It also decides which day the calendar
shows the tick on.

**Not the same as T-51,** which this was found next to. T-51 is about the hour; this is about which
day. `InjectionMoment.forLog` works around it by recognising "today" in either frame so a genuine
same-day log is not demoted to noon, and by writing `injected_at` as the true instant rather than
recomposing it from `dosed_on` — a workaround, not a fix, and it is commented as one.

**Done when:** one frame produces every `dosed_on` in the app, chosen deliberately, and a test pins a
device-zone morning east of UTC to the day the user would name.

**CORRECTED 2026-08-04 by win, from production — read this before fixing it.**

**No instance found.** `dose_log` was searched for the signature (same protocol, `dosed_on` one day
apart, created within six hours). Exactly one candidate, and on inspection it is NOT this bug: the
two rows have `dosed_on` and `scheduled_on` **mirrored** and **different sites**, both written
2026-07-29 — before iOS could write a site at all, so both are web-written. It is the web's
move-a-dose feature used twice. **It looked like this defect in the aggregate and stopped looking
like it the moment the rows were read.** Say "no instance found" here rather than implying damage, or
whoever closes this will go hunting for harm that does not exist.

**DO NOT STANDARDISE ON UTC — that was the obvious fix and it is the wrong one.** The web is
deliberately LOCAL and carries a comment written against exactly this hazard, in
`DashboardContext.tsx`'s `ymd` helper: *"local 'YYYY-MM-DD' (matches parseLocalDate / a Postgres
date) — never toISOString (that would shift the calendar day for negative-UTC offsets)"*. Every
web-written `dosed_on` is a local calendar day, and the unique index is shared, so iOS's frame must
agree with the web's or the two clients collide on the index while each believes it is right.
**`LogDoseSheet`'s `TimeZone.current` is the correct path; `DoseProjection`'s UTC is the odd one
out.**

**One nuance so the fix does not overshoot:** local is right for the EMITTED CALENDAR DAY, not
necessarily for the INTERVAL ARITHMETIC — stepping N days across a DST boundary in local time can
gain or lose an hour and drift a projection. Keeping the arithmetic in UTC and converting only where
a `dosed_on` is produced is a defensible shape. What must not survive is two surfaces disagreeing
about what day it is.

**Done when:** both surfaces emit the same local calendar day for the same instant, a test pins an
Auckland morning producing one `dosed_on` from both paths, and the DST case is pinned too.

## T-83 — iOS cannot say what time a dose was taken; the web can
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** the web's `DashLogFlow` has a `<input type="time">` and passes it down to
`markDone(..., injectionTime)`; `DoseHistory`'s detail sheet can edit it afterwards. iOS has no such
control on either path.

**What it costs, now that T-51 is closed:** a dose logged on the day it happened carries the real
clock time. A dose logged for **any other day** — the log sheet lets you pick one — carries the web's
`12:00` default, because the app has not asked and will not invent a time. That is the honest answer
and it is the same answer the web gives when its own picker is untouched, but the web at least offers
to be corrected. A user catching up on three days of missed logs gets three noons and no way to fix
them from the phone.

**Done when:** the log sheet accepts a time, defaulted to now for today and to 12:00 otherwise, and a
dose logged with a changed time reads back with that time.
---

## T-91 — A typed GLP-1 value is not snapped to the web's grid, so an off-grid save cannot dedup
**Priority 3/10** · **Owner:** mac · **Status:** open

**What it does now:** T-45 gave the GLP-1 `conc` and `dose` fields typed entry. iOS's `NumberField`
clamps a typed value into the field's range and does not snap it to any grid. The web does snap, and
the two builds snap differently:

- deployed / `master` — `ConcDrumField` rounds `conc` to **2 dp**; `SliderField` clamps `dose` to
  `[min, max]` and snaps it to `step` (sema 0.25, tirz 2.5, reta 0.5).
- `feature/dosage-status-model` — `QuickPickerField` clamps both to the array bounds and snaps to
  **half the array's first gap** (conc 0.5, sema 0.125, tirz 1.25, reta 0.25).

**Why it is a 3 and not higher.** The number iOS keeps is the user's own vial strength and the
arithmetic on it is exact, so no dose is wrong. The cost is the fingerprint: `saved_dosages` dedups
on the whole config, so an iOS row at `conc: 6.3` never resolves to the web row the same user would
have saved at `6.5`. Every value in ordinary clinical use (1, 2, 2.5, 5, 7.5, 10, 12, 12.5, 15, 20,
25) is already on both grids, so the divergence needs a deliberately odd entry to reach.

**Not fixed inside T-45 on purpose.** `NumberField` clamps on EVERY KEYSTROKE and rewrites the
visible text when the clamp bites; snapping on the same edge would rewrite the number under the
caret mid-entry (typing `0.25` would go `0.2` → snapped `0.25` → `0.255` → `0.25`). The web snaps on
BLUR. Doing this properly means a commit-time edge on that control, which is a change to every
numeric field in the app and needs its own pass. `TickDrum`'s own doc comment argues the opposite
case and should be read first: *"a TYPED value need not be on a tick … snapping the user's typed dose
to the nearest 5 would be the calculator editing the number the user acts on."*

**Done when:** a decision is recorded either way — snap on commit and match the web, or document the
divergence in `CALC-PARITY.md` as deliberate — and if it is snapped, a test pins iOS and the web to
the same value for a typed off-grid entry.

## T-92 — iOS clamps GLP-1 concentration at 60 mg/mL; the deployed web has no upper bound
**Priority 3/10** · **Owner:** mac · **Status:** open

**What it does now:** T-45 set the `conc` field's range to `0...60`, the bounds of
`GLP1_CONC_VALUES`, which is exactly what `feature/dosage-status-model`'s `QuickPickerField` clamps
to. The **deployed** build does not clamp at all — `ConcDrumField` accepts any positive number and
only rounds it to 2 dp. So a vial above 60 mg/mL is typeable on the live site and is snapped down to
60 on iOS.

**Why it is a 3.** 60 mg/mL is already multiples of any GLP-1 vial that exists; nothing in the
production protocol mix comes close. And iOS's clamp REWRITES THE VISIBLE TEXT when it bites, so a
refused value is seen rather than silently absorbed — this cannot produce a wrong number shown as a
right one, which is the class that earns a high priority on this list.

**The real finding underneath it** is that the two web builds disagree about whether concentration
has a ceiling at all, and `TASKS.md`'s ordering of truth puts the deployed build above the branch.
Whichever wins, iOS should copy it rather than pick.

**Done when:** the web has one answer and iOS matches it.

## T-93 — The GLP-1 fields have no preset chips, and the web's computed ones are not portable
**Priority 2/10** · **Owner:** mac · **Status:** open

**What:** T-45 gave the GLP-1 `conc` and `dose` fields the ruler and typed entry but left `quick: []`
— no one-tap chips, where TRT's weekly dose has `[100, 200, 300, 400, 500]`. So the commonest
concentrations (5, 10, 12.5) take a keystroke rather than a tap.

**Why the web's own chips were NOT ported.** On `feature/dosage-status-model`, `QuickPickerField`
DERIVES its ladder — `[1,2,3,4,5].map(i => snap(max * i / 5))` — which for `GLP1_CONC_VALUES` yields
**12 · 24 · 36 · 48 · 60 mg/mL** and for tirzepatide's dose yields **7.5 · 16.25 · 23.75 · 32.5 · 40
mg**. Those are arithmetic on the array's maximum, not clinical values, and half of them are
strengths and doses nobody holds. Shipping them verbatim would have put a misleading one-tap row on
a dosing screen in the name of parity; inventing a better row is a design decision that belongs to
the owner, not to a defect fix. So neither was done, and the reason is written down here rather than
left as an empty array someone later reads as an oversight.

**Also note** the deployed build has no chip row on these fields at all — it renders a `DrumPicker`
plus an exact-entry box — so "the web has chips here" is only true on the unmerged branch.

**Done when:** either a chip row is specified by the owner and built, or this is closed as
deliberately absent with the deployed build cited.


---

**T-22 closure note (win, 2026-08-04).** Fixed in `eb2a5b1d`. `DashLogFlow.tsx:106` now passes
`amount` to `markDone`; `DashboardContext.tsx:399,404` write `drawMlFor(ev, amount)` and
`doseLabelFor(ev, amount)` instead of the plan.

**The two clients agree, derived independently, which is the part worth keeping.** iOS computed
`12.75` over a `74.5 mg` plan as `12.75 ÷ 200 = 0.064 mL`. The web reaches `0.064` by a different
route — `0.373 × (12.75 ÷ 74.5)`, scaling the planned volume rather than recomputing from strength.
Two implementations, neither having seen the other, same number. A cross-check is worth more than
either side testing itself twice.

**One deliberate narrowing:** `draw_ml` scales only for a bare number. `0.5 mL` typed against a
`74.5 mg` plan is a volume, not a dose, and scaling it would write `0.0025 mL` — a dosing app must
not compute through an ambiguous unit. The label takes what the user said; the volume stays planned.

## T-63 — A dead direct-to-Supabase save path in the reconstitution calculator
**Priority 2/10** · **Owner:** win · **Status:** open

**What:** `public/app.js` defines two things inside `ReconstitutionPage` that nothing uses:
`doSave` (`:8152`) and `nameCard` (`:8177`), a "Peptide name" input. Each is referenced exactly once
in the whole file — its own definition. The calculator's real save path, `handleSave` →
`/api/dosages`, is correct and unaffected.

**Why it is only a 2, stated so nobody re-raises it as urgent:** `nameCard` is never rendered, so
**there is no visible field for a user to type into and have discarded.** It is not the T-22 pattern;
it is leftover machinery from an earlier flow.

**The one thing that makes it worth writing down at all:** `doSave` posts **directly to
`IB_SUPA_URL + '/rest/v1/peptide_protocols'` from client JavaScript**, bypassing `/api/dosages` and
whatever validation lives there. Dead, so harmless today — but it is a wired-up-and-forgotten hazard
rather than an unused variable, and if anyone ever re-attaches it they inherit the bypass.

**Deliberately not fixed on sight:** `public/app.js` had uncommitted in-flight changes from other
work when this was found, and it is a very large file. Editing it mid-flight to delete dead code is a
poor trade. Do it when the tree is clean.

**Done when:** both are deleted, or `doSave` is repointed at `/api/dosages` if the peptide-name flow
is actually wanted.

---

### Sweep record — the "control that discards its value" class, 2026-08-04

**Recorded because a clean sweep is a result, and without this note the next person runs it again.**

After T-22 (the log sheet's `DOSE AMOUNT` accepted a typed dose and wrote the plan) and the dead
`currentPw` in the settings password panel, `components/`, `app/` and `public/app.js` were swept for
the same shape: **a control that appears functional but whose value never reaches the thing it claims
to affect.**

Every dose-, date-, site- and concentration-relevant control was traced from its set-site to its
send-site. Checked and clean: dashboard dose logging and editing, all six settings panels,
personalisation, the cycle planner's add/edit flows, blood-test review, calendar quick-add, and **all
~19 calculator save paths in `public/app.js`** — every visible input reaches its persisted payload.

**T-63 above is the only survivor, and it is dead code rather than a discarded value.** So the class
appears to be closed at two real instances, both already fixed.



## T-64 — The web still ships an EOD calculator its own navigation points away from
**Priority 3/10** · **Owner:** pouroa · **Status:** open

**What:** raised by mac while executing T-12, and it is the same redundancy on the other platform.
`public/app.js` has a live `EODPage` that can POST `calculator_type: 'eod'`, while
`public/nav-items.js:23,59` point the `eod` nav id at **`/trt-calculator/`** — the same URL as `trt`.
So the web has two calculators behind one URL, and the TRT one now carries the `Every N Days` mode
switcher that makes the other redundant.

**Why it is the owner's call and not win's:** the owner's reasoning for iOS — *"that option is inside
the TRT calc anyway"* — applies identically here. But the web is the shipped, indexed product with
existing users, and removing a page from it is a different decision from removing an unshipped screen
from an app in development. **It is filed rather than done.**

**Why it is only a 3:** nothing is wrong today. The page works and produces correct numbers. It is
redundancy, not a defect — and `deriveDose` handles `eod` correctly, so a row created there behaves.

**Done when:** the owner decides whether the web's EOD page is retired into the TRT calculator's mode
switcher, or kept — and if kept, whether iOS should regain parity with it.
