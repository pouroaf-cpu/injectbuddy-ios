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
**Agent:** `t01c-dash` · **Status:** doing
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
**Agent:** `t01d-cal` · **Status:** doing
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
