# Pre-restructure DONE archive

Every struck-through / closed block from the old root `TASKS.md`, moved here verbatim on the
2026-08-05 restructure. Nothing was edited. Kept because most of these carry the evidence that
closed them — a commit, a query or a photograph.

---

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

## ~~T-09 — The Calendar tells the user nothing is due when it has simply not looked~~ — **DONE 2026-08-04**
**Priority 7/10** · **Owner:** mac · **Agent:** — · **Status:** done

**CLOSED by `df0fc5a`, built by agent `t09-window`. THE CLASS WAS REMOVED, NOT THE WINDOW WIDENED —
and the distinction is stated because the diff alone cannot say which.**

The Calendar no longer builds a windowed series at all. `CalendarViewModel` holds `ScheduledProtocol`
values and `CalendarData.occurrences(on:)` asks a per-date predicate about whatever day the grid
draws — the shape the web has always had (`isDoseDay(p, date)`, `lib/account-schedule.ts:428-437`:
no accumulator, no loop, no budget, which is why the web cannot have this defect). **"No dots" now
has exactly one meaning.** `DoseProjection.projectedDoses` is untouched — the dashboard's "next N
days, in order" is a genuine series question.

**Every coverage assertion is paired with an emptiness assertion at the same distance**, so a fix
that painted dots on every cell fails by design. `testPredicateMatchesTheSeriesDayForDayOver400Days`
pins the predicate against the old series across 8 cadences × 400 days, so the two cannot disagree
about which days are dose days.

**A corollary the agent caught that would have shipped a NEW lie in place of the old one:** pins were
fetched `since` yesterday. With past days now drawing dots, every logged dose in the previous month
would have rendered **untaken**. The fetch now goes back to the first renderable month.

**Frames:** `docs/ui-audit/t09-calendar-window/` — `t09-02-calendar-plus-3-months.png` is the task's
frame, a month far past the old 30-day window showing real dose days, plus current month, far-day
agenda and previous month. 2/2 UI tests green.

**Unfiled divergence found and deliberately not taken:** iOS FLOORS fractional cadences
(E3.5 → 0,3,7,10,14) where the web ROUNDS (0,4,7,11,14). A real disagreement about which days a
twice-weekly user injects — and the iOS comment claiming it "matches the web schedule" is wrong.
Moving it here would have hidden a reschedule inside a coverage fix. **Filed as T-97.**

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

## ~~T-12 — TRT EOD is the missing mode switcher wearing a second screen~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Agent:** — · **Status:** done

**BUILT 2026-08-04 by mac, `bce1c7f` + `b4dc10e`, 163/163 green and shown red first. Not closed:
the done-when requires `Every N Days` photographed producing an EOD interval, and the rig session is
batched with T-44's frame.**

**THE SCOPE CHANGED, AND THE REASON IS THE WHOLE VALUE OF THIS TASK. The instruction was to remove
`.eod` from `CalculatorSlug`. Doing that would have silently deleted live protocols.**

`CalculatorSlug.rawValue` is the DECODER for `saved_dosages.calculator_type`, and **the web can
still write that type today** — `app.js` ships a live `EODPage` in `PAGES` and `RAIL_PAGES` whose
save POSTs `{calculator_type: 'eod'}`. The premise recorded above — *"there is no TRT EOD calculator
on the web and there never was one"* — was drawn from `public/legacy/` holding no `eod` directory.
**That is true of the legacy static pages and false of the live SPA**, and win has corrected it at
source (`cab03c6`), naming the inference: *"it is not in the place I looked, therefore it does not
exist"* — the same shape as reading an absent `pg_stat_statements` entry as an absent query.

**What makes it fatal rather than untidy: the web's EOD save config is
`{strength, mgWeek, syringeMl, esterType}` (`app.js:6051`) and carries NO CADENCE KEY** — no `mode`,
no `nDays`, no `injPerWeek`. So the every-2-days interval hangs *entirely* on the slug. Delete the
case and `DoseProjection.injectionIntervalDays` falls through to `.none → nil`, and the protocol is
**never projected**: no error, no empty state, absent from the calendar while the user is still
injecting. **That is T-57's shape and T-81's shape.** Recorded as the standing rule both sides now
hold: *a decoder is not a feature, and removing a screen never removes the need to read what the
other platform wrote.*

**SO: EOD IS REMOVED AS A CALCULATOR AND RETAINED AS A PROTOCOL TYPE.**
- Gone: category membership (out of `allMembers`, not merely unlisted), every browse surface, the
  Add funnel, the drawer, the dashboard's open-calculator dialog.
- Kept: the slug, its title/short title/icon/colour, its spec (which `values(fromConfig:)` needs),
  its evaluate branch and `CalculatorEngine.eod` — because `DoseProjection:145` EVALUATES a protocol
  to get its dose, so deleting that branch strips the dose off a web-created EOD row on the calendar.
- `formSlug` sends a tapped EOD protocol to the TRT calculator. **That is not an iOS invention —
  `nav-items.js:23` and `:59` point `eod` at `/trt-calculator/`, the same URL as `trt`.** The web's
  own nav already treats EOD as a label that lands on the TRT calculator, which is the owner's
  *"that option is inside the TRT calc anyway"* in the web's own configuration.

**`isListed` IS NOW A COMPOSITION OF TWO DIFFERENT STATES, and that was forced by a test rather than
chosen for neatness.** Folding EOD into the existing withdrawal would have broken three real
invariants `CalculatorLinkWithdrawalTests` asserts of a *withdrawn* slug — that it belongs to exactly
one category, keeps a renderable spec, and cannot save. EOD satisfies none of those now. Relaxing
that test to accommodate it would have cost the meaning of the withdrawal in order to describe the
collapse. So `isWithdrawn` (H6 — screen intact, owner returning to it) and `isCollapsed` (T-12 —
nothing to restore) are separate literal switches and `isListed` is `!withdrawn && !collapsed`.

**THE CAPABILITY PROOF IS NUMERIC, WHICH IS STRONGER THAN THE PHOTOGRAPH THAT WAS ASKED FOR — both
are being done.** iOS's `TickDrum.everyNDays` is `[0] + stride(from: 1.0, through: 14.0, by: 0.5)`;
the web's `EVERY_N_DAYS_VALUES` (`app.js:3891`) is `[0]` then `1 → 14` by `0.5`. **Identical, and
2.0 is in both.** And `trt(mode: .ndays, nDays: 2)` gives `freq = 7/2 = 3.5` — the exact constant
`CalculatorEngine.eod` hardcoded — with every other field of the result equal too, asserted as whole
`TrtResult` equality. `testTheEquivalenceIsSpecificToTwoDays` proves the equivalence is not passing
for some other reason: at the TRT spec's own default `nDays: 3.5` the two results DIFFER.

**A second route was found while doing this and it strengthens the decision:** `trtFreqOptions`
already ships an option literally labelled **"EOD"** (3.5×/week) in `Per Week` mode. EOD is reachable
two ways inside the TRT calculator, not one.

**The regression guard is the important test in `EodCollapseTests`:**
`testAWebWrittenEodProtocolStillDecodesAndStillProjects`, built from a fixture in the WEB's exact
saved shape, fails the moment anyone acts on the original instruction.

**Done when:** ~~the EOD screen is gone~~ ✔, ~~the app still builds with no stale `.eod` routes~~ ✔,
~~`Every N Days` photographed producing an EOD interval~~ ✔ — **ALL MET.**

**PHOTOGRAPHED, and both frames prove which screen they are.** `docs/ui-audit/t12-eod-collapse/`:
- `t12-01-tools-no-eod.png` — the Tools list reading **TRT Dose → TRT Microdose → HCG**, with no
  `TRT & EOD` between them, Tools tab lit in the bar.
- `t12-02-trt-every-2-days.png` — **TRT Dose**, `EVERY N DAYS = 2`, **`Injections / week = 3.50`**,
  dose per injection 28.57 mg against a 100 mg weekly total. That 3.50 is the exact constant
  `CalculatorEngine.eod` hardcoded, read off the running app.

**AND THE FRAME RUN FOUND A DEFECT THE UNIT TESTS COULD NOT SEE — which is the whole argument for
taking it.** The first two runs failed with *"the TRT calculator has no Every N Days mode control"*
while the control was on screen and selected. The tree dump said why:

```
Button, identifier: 'mode_tab', label: 'Every N Days', Selected
Button, identifier: 'mode_tab', label: 'Per Week'
Button, identifier: 'mode_tab', label: 'mL → mg'
```

`ModeTab` set `.accessibilityIdentifier("\(idPrefix)tab")` on its container, and **a container
identifier propagates to descendants and overwrites the ones the segments set for themselves.** So
`mode_ndays` / `mode_perweek` / `mode_ml2mg` were written and were never observable by anything —
defeating, silently, the exact purpose `idPrefix` is documented as serving. Nothing referenced them,
so nothing ever failed. **That is T-47's pattern in the accessibility tree rather than in Swift**,
and it is the sixth instance found this way. The container identifier is removed; nothing referenced
`mode_tab` either.

**A precondition that fails because the PROBE is wrong looks identical to one that fails because the
FEATURE is missing**, and here the two readings pointed opposite ways — the second would have meant
stopping the EOD removal entirely, as the task instructed. What separated them was that `field_nDays`
had already been found: the `ndays`-only field cannot render unless that mode is live.

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

## ~~T-42 — The plotter labels a fabricated number as a lab result~~ — **DONE 2026-08-04**
**Priority 9/10** · **Owner:** mac · **Agent:** — · **Status:** done — **KEPT by owner ruling**

**THE OWNER RULED ON THIS EXPLICITLY: KEEP IT.** The instruction *"leave the maths on the cycle
plotter and the half-lives alone"* arrived AFTER `c16a20c` had merged, so it was written expecting
work in progress and there was none. The ruling turned on two facts: **the pharmacokinetics is
bit-for-bit unchanged** — what moved was a display scalar applied after the model, plus a label —
and **reverting would not have been neutral**, because it restores a screen that multiplies by one
global constant and calls the result `ng/dL`, a figure the user can go and compare against real
bloodwork.

**The rest of the plotter is FROZEN and this closure does not reopen any of it:** T-32 not started,
`tmax` not approached, `pkSolveKa` untouched, the four `defaultDose` rows left exactly as they are.


**CLOSED. Built by agent `t42-units`. 229/229 green, shown red first, photographed.
The board's highest open item.**

**THE ARGUMENT THAT CLOSED IT IS NOT `math-spec.md` — it is the product's own published
explanation of why it REFUSES to do this.** `public/legacy/cycle-plotter/index.html:2296-2297`:

> **"Why does the plotter use relative units instead of ng/dL?"**
> *"Absolute serum concentrations (in ng/dL) require **compound-specific pharmacokinetic parameters
> including volume of distribution and bioavailability** that are not reliably available for all
> compounds. The relative units shown are directly proportional to your dose and allow you to compare
> peak-to-trough ratios, evaluate injection frequency, and estimate steady-state timing accurately."*

**The web did not omit ng/dL. It declined it, in writing, with reasons.** And `grep` for
`ng/dL|ngdl|13.5` in `pk.js` returns **zero hits** — not an axis, not a label, not a computation.

**Why that makes it an IMPOSSIBILITY rather than a parity gap.** The web names the two things a real
conversion needs — volume of distribution and bioavailability, **both compound-specific**. iOS used
`13.5`, **one global constant**. A single scalar cannot encode one per-compound parameter, let alone
two.

**Corrected from the first framing of this task, because the sharper number is the true one:** the
factor gated on all-testosterone selections, so it was not "wrong across 27 compounds" — it stood in
for the Vd and bioavailability of **four esters at once**, half-lives 4.5 / 6.0 / 0.8 / 21.0 days.
No single value is right for all four. The weaker claim was mine; the agent checked it.

**Axis wording taken from the live plotter, not invented** — `app.jsx:34` `METRIC_LABEL.serum =
'Estimated serum level'` and `:557` `'relative units'`. `:555` records the web REJECTING the
abbreviation: *"'rel.' read as a truncation artefact… so say so in words."* Stacked rather than
inline, because side-by-side has nowhere to go at AX5 (UX-UI-RULES §2).

**`testoNgdlFactor` is DELETED, and `scripts/unread-decls.py` — T-47's sweep, built this morning —
reported it unread the moment the multiplication went.** `allTesto` went with it: the `@Published`
flag existed only to choose between the fabricated units and the real ones, and there is now one
answer for every selection.

**THE FAQ IS PORTED, and it is the app's first ported FAQ entry.** It sits inside the chart card
directly under the curve, because the existing bottom-of-screen note is a disclaimer about the whole
tool while this explains the axis. **The page carries the answer TWICE and the copies differ** — the
structured data at `:49-52` has one extra sentence the visible copy drops: *"The shape and timing of
the curve is correct even if the absolute scale is not calibrated to ng/dL."* That is the sentence
saying what the chart is still GOOD for, which is the difference between an explanation and a
disclaimer, so it is included. It is the web's string, not ours.

**Note for T-13:** the precedent named in that task does not exist — the calendar's "How it works" is
not built on iOS (it is T-01d #7, still pending). This is the first one.

**Shown RED, twice over.** Reintroducing `× 13.5` fails the pin with **1,259 assertion failures**
across the series. And the suite carries its own falsification: `test_theComparisonWouldCatchAScalar`
runs the identical comparison against a deliberately 13.5×-scaled curve and requires it to disagree
at all 416 non-zero samples. **The pin compares against `CalculatorEngine.pkTotalLevel` recomputed
in the test, not against a recorded curve — so a reintroduced scalar cannot be quietly re-baselined.**

**The best test of the set does not depend on knowing the factor's value at all:**
`test_addingANonTestosteroneLineDoesNotRescaleTheTestosteroneCurve`. Under the old code, adding a
single non-testosterone line silently divided the Test E curve by 13.5. `masteron-e` is chosen
because its 4.5-day half-life matches `test-e`, so the sample grid provably cannot move and any
difference is unambiguously a rescale.

**And the precondition that would otherwise have inverted the result:**
`assertOnTheTestosteroneOnlyBranch()` runs before the axis is read. A run landing on any other
selection finds no lab unit, passes cleanly, and clears the defect without going near it — the T-05
shape, caught before it could happen.

**FRAMES:** `docs/ui-audit/t42-plotter-units/`. `t42-01-plotter-relative-units.png` — **Cycle
Plotter**, axis **"Estimated serum level / relative units"**, the curve peaking near **100** where it
used to read ~1,500, and the FAQ answer on screen beneath it. `t42-02-plotter-units-faq.png`.

**Done when** — ~~the axis is labelled in the units the model actually produces and the ng/dL factor
is gone~~ ✔; ~~the table is reconciled and the "verbatim from app.js" comment corrected~~ ✔ (T-60).

**THREE STANDING DIVERGENCES REPORTED AND DELIBERATELY NOT TOUCHED:**
1. **`ka` derivation** — `pk.js:91-96` uses `ka = ln2 / max(0.01, halfLife × 0.25)`; iOS bisects for a
   per-compound `tmax`. Genuinely coupled to T-60's territory, since `tmax` is now spec-pinned.
2. **`SMOOTH_FRAC = 0.5`** — the web draws a centred moving average over half the injection interval;
   iOS plots the raw sawtooth. `math-spec.md` §4.2 says *"a port must state which variant it
   reproduces"* and **iOS states nothing**. Worth its own task.
3. **A third found here, in neither task:** iOS rounds every plotted point to 4dp. That rounding
   appears in **neither** `pk.js` nor `app.js` — display quantisation, not a unit change, recorded in
   the code rather than described as the web's.

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

## ~~T-43 — Flipping the Free T Index unit does not convert the value either~~ — **DONE 2026-08-04**
**Priority 8/10** · **Owner:** mac · **Agent:** — · **Status:** done

**CLOSED by `bce1c7f` + `b4dc10e`.** Built by agent `t43-fai`, reviewed and corrected by mac.

**It needed a DECLARATION, not a mechanism.** T-41 built `UnitScaling` per field, and this is one
line of spec on top of it — `CalculatorModels.swift` was not touched at all. That is the T-41 entry's
prediction (*"T-43 gets this for free"*) turning out to be exactly right.

**BASE IS nmol/L, so `factor` is 1/28.84 — the RECIPROCAL of the engine's constant, not the
constant.** `UnitScaling.factor` is documented as *base units per alternate unit*, and one ng/dL is
1/28.84 nmol/L. Getting this backwards is the plausible-wrong answer and it is what the red run
below was aimed at. nmol/L is the base because the shipped default (20) is already in it and because
`CalculatorEngine.freeTestIndex` defines FAI with BOTH terms in nmol/L.

**THE RANGE WAS THE SECOND HALF, exactly as it was on T-41.** `0...2000` was held in BOTH units — a
ng/dL lab-report ceiling which, read as nmol/L, admits an FAI of 4000. Now `0...100 nmol/L`,
resolving to `0...2884 ng/dL`. The ends are images of each other, so nothing in range on one side is
out of range on the other, and the new ceiling is *above* the old one so nothing previously
acceptable now clamps. The field also gained a `unit:` suffix — **it previously declared none at
all**, on the one screen whose entire defect is that the same number means two different blood
values.

**THE ROUND TRIP IS EXACT ONE WAY ONLY, and that is a property of 28.84 rather than of the code.**
nmol/L → ng/dL → nmol/L returns the original for every two-decimal value; the other direction cannot,
because 0.005 nmol/L is 0.144 ng/dL — wider than the ng/dL hundredth — so 600 returns 599.87.
**The web has the identical asymmetry** and that is why this is parity rather than a compromise:
`changeTtUnit` rounds with `Math.round(conv * 100) / 100` in both units. Values that sit on the nmol
grid (288.4, 576.8, 2884) are asserted EXACT with no tolerance to hide in; everything else is
asserted inside one nmol hundredth, a bound *derived* from the rounding rather than tuned until it
went green.

**A citation was corrected rather than quietly fixed.** The source comment first cited
`app.js:7878-7887`; that range is the Reverse Dose Solver. `changeTtUnit` is at **`:8434`**, with a
second identical copy at `:8595` for the FTV page iOS does not have. **The quoted code was verbatim
correct and only the reference was wrong — which is the more dangerous of the two**, because a wrong
reference pointing at real-looking code reads as corroboration to the next person.

**A STALE TEST WAS FOUND BY THIS WORK AND IS THE MORE USEFUL FINDING.**
`PeptideDoseUnitTests.testResolutionIsIdentityForCalculatorsWithoutAUnitSelector` opened by
asserting *"the other thirteen calculators declare no unit scaling"*. This task declared one on Free
T Index — **and the test stayed GREEN**, because that selector's default is the base value, so
resolution is identity at defaults whatever the mechanism does. It never exercised the case it
appeared to cover. The membership is now DERIVED from the specs and asserted out loud, so a third
declaration has to be declared here rather than silently shrinking the test's coverage.

**Measured: 163/163 green, and shown RED first.** Setting `factor: 28.84` failed 7 of the FAI tests,
including `testConversionIsNotAClamp` — *"600 ng/dL landed on the nmol/L ceiling — this is a clamp,
not a conversion"*. A one-way round-trip test passes on an implementation that clamps, which is why
both directions and the not-a-clamp case are pinned separately.

**No frame, and the reason is recorded rather than left as an omission:** Free T Index is withdrawn
from Tools (T-55), so it cannot be reached on the device. The "shown on the device" half that T-41
had has no equivalent here until T-55 moves.

**One residual, named so it is a decision and not a surprise:** entering in ng/dL, the FAI's last
displayed decimal can move by 0.1 across a flip (900 ng/dL, SHBG 20 → 156.0 becomes 156.1). **The
BAND does not move**, which is the thing the task was about. `baseDecimals: 4` would remove it at the
cost of putting `20.7999` in a field the user typed 20.8 into, and of disagreeing with the web on a
displayed number.

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

## ~~T-44 — The steroid calculator offers injectable inputs for oral-only compounds~~ — **DONE 2026-08-04**
**Priority 7/10** · **Owner:** mac · **Agent:** — · **Status:** done

**Built by agent `t44-steroid`, reviewed by mac. Committed `bce1c7f` + `b4dc10e`. 163/163 unit
tests green, shown red first. NOT closed: the done-when names a rendered screen and the frame has
not been taken — it is batched into the next rig session with T-12's.**

**Both wrong numbers are gone.**

- **The ester is now pickable, because the compound list expands esters as the web's does.** The web
  builds one dropdown entry per ester (`app.js:8927-8932`, `brand + ' ' + ester.label`, value
  `slug|esterKey`) and its own comment says *"there is no separate ester picker"*. iOS forced
  `esters.first`. **Tren E at 300 mg/week now returns 213 mg active, not 261 — the 22.5% error is
  closed** and pinned, along with Tren A still returning 261 so the fix cannot be a blanket change to
  the factor. 12 compounds become 14 entries.
- **An oral compound renders tablet inputs and no syringe.** `cls:'oral'` (`app.js:8748-8761`) picks
  the form per compound exactly as the web picks it per page: Daily dose / Tablet strength / Doses
  per day, and a Tablets / Per Dose / Daily result. **`drawMl` is nil**, which is the load-bearing
  half — `DoseVolume` publishes `drawMl` into `dose_log`, so a tablet can no longer contribute a draw
  volume. The shipped default Oxandrolone no longer returns 0.75 mL / 75 units for a tablet.

**`canInject` existed and was correct; nothing consulted it.** That is T-47's pattern, and this is
the second of its three known instances to be closed.

**THE SAVED CONFIG KEY SET IS UNCHANGED and that was the constraint the work was held to.** Still
the web's 13 keys. The new iOS fields are named `oralDose`/`tabMg`/`oralSplit`, added to
`configOmittedKeys`, and re-emitted as the web's `dose`/`tab`/`split` as STRINGS, because on the web
those are raw input state. An injectable save is byte-identical to what this build already wrote.
One value changes on oral rows only — `mgWeek: 0` rather than iOS's hidden 300 — and it is safe
precisely because an oral steroid could not be saved at all before, so there are no rows to
re-fingerprint.

**Shown RED before trusted green:** ignoring `canInject` failed
`testAnOralOnlyCompoundIsOfferedNoInjectableInput` and
`testTheFormOffersExactlyOneSetOfInputsPerCompound`, and no others — the two tests that name this
defect, rather than a cascade that would have proven nothing.

**FOUR THINGS FOUND AND DELIBERATELY NOT TAKEN.** Each is a decision, not an oversight:

1. **Dropdown ORDER not changed.** The web walks `IB_STEROID_ORDER` (`:8762`) starting at
   `trenbolone`; iOS walks `IB_STEROIDS` key order starting at `anavar`. Adopting the web's order
   would move the shipped default and therefore what an untouched save writes — and would break the
   before/after comparability of `28-calculator-steroid.png`.
2. **Winstrol's Form toggle is not implemented.** It is the only `'oral|injectable'` compound; iOS
   sits it on injectable, which is the form the web opens it on. Its oral tablet path is unreachable
   on iOS. **Filed as T-94.**
3. **The web's untouched `tab` on an INJECTABLE page is `String(defTab)`, not `""`.** iOS writes
   `""`, so iOS and web injectable steroid rows already never dedup against each other. Fixing it
   re-fingerprints every future injectable row against production, so it is a data decision.
   **Filed as T-95.**
4. **`SteroidCompound.defaultConc(for:)` and `defaultTab` are still read by nothing** — vial strength
   stays 200 and tablet strength 10 whatever compound is picked, where the web re-seeds both per
   compound/ester (`useEffect` `:8813`). **Anadrol ships 50 mg tablets, so its seeded 10 is wrong
   until the user edits it.** Two more instances of T-47's pattern, found while fixing the first one.
   **Filed as T-96.**

**Done when** — ALL MET: an oral compound renders no injectable inputs and no draw volume ✔, the
ester is selectable ✔, the Tren E case returns 213 mg ✔, **and it is photographed** ✔.

**FRAME: `docs/ui-audit/t44-steroid-form/t44-01-steroid-oxandrolone-oral.png`**, and it differs from
`28-calculator-steroid.png` exactly as predicted. Self-identifying: **Steroid Dosage**, compound
**Oxandrolone (Anavar)**, and the form is **DAILY DOSE (mg) · TABLET STRENGTH (mg/tab) · DOSES PER
DAY**, resolving to `Tablets 0.00 tab`. **No vial strength, no syringe barrel, no draw volume** —
where the old frame showed 200 mg/mL, a barrel, and 0.75 mL / 75 units for a tablet.

The UI test asserts arrival through `field_oralDose` specifically, which proves BOTH that the screen
loaded AND that it opened on the oral form — a single element that cannot be satisfied by the defect.
It then asserts `field_strength` and `field_mgWeek` are ABSENT, which is the half a frame alone
cannot prove to a run.

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

## ~~T-47 — Correct code that nothing calls, three times in one day~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Agent:** — · **Status:** done

**CLOSED by `df0fc5a`, built by agent `t47-deadcode`. `scripts/unread-decls.py`, runnable, no
toolchain — pure text analysis, so it is cheap enough to run often.**

**1945 declarations · 52 unread raw · 23 excluded · 29 unread · ~86% genuine.** The false-positive
rate is REPORTED rather than tuned away: two-case enums and Codable cases reachable from the database
will always land here, and widening the exclusions to remove them would have cost
`UnitSystem.imperial`, a real finding of identical syntactic shape.

**The rule that made the live examples visible: `foo:` is an argument label, not a read.**
`defaultTab` occurs 13× in its file — one declaration and twelve memberwise-init WRITES. "Appears
more than once" calls it alive. It also strips comments first, because `canInject` appears 8× in
prose explaining why it was unread, and a raw grep counts the explanation as evidence of the fix.

**Two candidate exclusions were written and DELETED, which is the part worth keeping.** One formed a
closed loop with another (`protocol-declaration` + `satisfies-protocol` silenced all six declarations
of `BackendClient.deleteDosage`/`.profile`, which nothing calls) — *an exclusion justified by another
exclusion is not a justification*. The second, Equatable/Hashable stored properties, would have
silenced `defaultTab`, **the very finding the task was filed for.**

**New user-visible findings:** `canOral` (the sibling of `canInject`, still unread — see T-94);
`PlotterCompound.defaultDose` (28 per-compound defaults, read nowhere); `UnitSystem.imperial` — **a
setting the user can change that changes nothing**; `barrelField(for:)`, dead AND cited by a comment
claiming it carries the EOD barrel default, which is the doc-claim checker's exact intersection.
A dead three-deep `defaultConc` chain was surfaced only by a pigeonhole check on shared names —
every link individually "has a reader".

**It caught a regression I had introduced minutes earlier**, which is the fastest possible validation:
repointing the withdrawal tests at `withdrawnCases` left `unlistedCases` read by nothing. It is now
used where it belongs.

**Shown red before trusted:** the self-test was verified failing two ways — disable comment stripping
and three dead members go missing; count argument labels as reads and the dead stored property goes
missing, which is exactly how `defaultTab` hid.

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

## ~~T-60 — iOS's plotter compound table was copied from a DEAD web table~~ — **iOS HALF DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Agent:** — · **Status:** done (iOS half; the web-side deletion is win's)

**CLOSED on the iOS side by agent `t60-compounds`. 220/220 green, shown red first. THIS UNBLOCKS
T-42.**

**Every claim was re-verified before acting, because two statements about this table had already been
wrong today in OPPOSITE directions.** `spec/compounds.json` was parsed against
`public/legacy/cycle-plotter/pk.js` on all 31 rows: **zero differences.** The spec's claim to be the
single source of truth is TRUE. `PLOTTER_COMPOUNDS` is dead — `app.js:11297-11300` redirects the
in-app plotter to `/cycle-plotter/`.

**THE DIVERGENCE IS WORSE THAN REPORTED: 17 half-lives and 4 units, not 13.** Of 23 name-comparable
rows only **6 agreed**. Tren A 1.5 → **3.0** (2×), PT-141 0.113 → **0.5** (4.4×), TB-500 0.58 →
**2.5** (4.3×), CJC-no-DAC 0.021 → **0.08** (3.8×), MT-2 3.7 → **1.5** (2.5×). Four rows also had
the wrong UNIT (PT-141, TB-500, MT-2 mcg→mg; HGH mcg→IU).

**And the "verbatim from app.js" comment was itself inaccurate in a second way: iOS shipped 27 rows,
not 31.** Four were dropped in transcription — so the copy was neither complete nor of the right
source, while reading as provenance.

**NOT RETYPED — GENERATED AND INDEPENDENTLY ASSERTED**, because the failure that produced this was a
faithful copy of a wrong source, and another hand-copy of a right source is one refactor from the
same position. `spec/compounds.json` is committed **byte-identical to the web's blob**
(`cf14ff76a5c80f7053f28c10df8443228bc82edf`), `spec/generate-plotter-compounds.mjs` emits the Swift
table (`--check` gates staleness), and `PlotterCompoundSpecTests` **re-reads the JSON from disk** and
asserts the shipped table against it — not against a second copy of the values, so it can genuinely
fail.

**Shown RED in Swift, not only in the node mirror:** editing the generated table back to
`tren-a 1.5` failed `test_everyShippedCompoundMatchesTheSpec` with `1.5` against `3.0`. The generator
also refuses an unclassified new compound and a `defaultDose` unit that disagrees with its row.
Anti-vacuous measures: the match test asserts `compared == 23` so it cannot pass by comparing
nothing, and the loader throws a named error rather than `XCTSkip`.

**`tmax` untouched, as instructed — and a real hazard was caught by checking it.** `pkSolveKa`
bisects for a `tmax` whose supremum is `halfLife / ln2`. **17 half-lives just moved, several
DOWNWARD**, so an unreachable `tmax` would have made the bisection return silent nonsense. A test now
asserts `tmax < halfLife / ln2` for all 27 rows; sermorelin is tightest at 0.003 vs 0.0110.

**Still open, deliberately:** the row set stays 27 — adding the 8 missing compounds needs a `tmax`
each, which T-32 exists for and which must not be invented. The spec has now handed T-32 credible
half-lives for all 8, which is new information for it. Four rows carry a `defaultDose` still in the
dead table's unit; `defaultDose` is read by nothing today, and **anyone wiring it to the UI must
convert those four first** (HGH has no exact mcg→IU conversion without a potency factor).

**The web-side half — deleting `PLOTTER_COMPOUNDS` from `public/app.js` — is win's and is not done**;
it is held because that file currently carries the owner's uncommitted in-flight work.

**⚠ REWRITTEN 2026-08-04. The original framing was wrong and it was win's. Old text is below, per
rule 7 — it is the reason the task existed and the reason it was parked.**

**What was claimed:** the web ships two compound tables that disagree on 13 half-lives, and the one
declaring itself the single source of truth is NOT the one the live plotter uses. Owner parked it as
a pharmacological question.

**What is actually true.** `PLOTTER_COMPOUNDS` in `public/app.js` **is dead.** The in-app plotter was
removed in favour of the standalone `/cycle-plotter/` page — `App()` redirects `plotter` straight
there — and nothing reads that table any more. The live plotter is
`public/legacy/cycle-plotter/pk.js`, which is exactly what `spec/compounds.json`'s own `$comment`
says it is generated from.

**Compared properly, they agree on all 31 compounds. Zero disagreements.** So
`spec/compounds.json`'s claim to be the single source of truth is **TRUE**, and the 13 "disagreements"
were between the live table and a corpse.

**How the wrong conclusion was reached, because the mechanism is the lesson.** Win's doc-claim
checker compared the spec against `PLOTTER_COMPOUNDS`, found 13 differences, and reported them.
**The instrument was pointed at the wrong artefact, so it produced a real-looking failure — and a
FAILING check is trusted harder than a passing one.** It then generated a task, a parked owner
decision, and an instruction to mac not to reconcile against the spec. All three were wrong, from one
mis-aimed check. The checker is repointed at `pk.js` and now reports 6 of 6.

**The real finding, which is smaller but actionable, and it is on the iOS side.** iOS's plotter
compound table carries the comment *"verbatim from app.js `PLOTTER_COMPOUNDS`"*. **That is true, and
it means iOS copied the dead table.** So iOS's half-lives differ from the live plotter's on the same
13 compounds — Tren A by 2×, PT-141 by 4.4×, Melanotan II by 2.5× — because it was transcribed from
a table nothing has run for some time.

**Unparked. This is no longer a pharmacological question and does not need the owner:** there is one
live table, it agrees with the spec, and iOS should match it.

**Correction to the instruction win gave mac:** win said *"do not reconcile iOS to
`spec/compounds.json` — that is the table the live plotter does NOT use."* **The opposite is the
case.** `spec/compounds.json` is generated from the live plotter and is the correct reconciliation
target. Reconcile to it.

**Done when:** iOS's compound table matches `spec/compounds.json`, pinned by a test that fails if
they drift; and `PLOTTER_COMPOUNDS` is deleted from `public/app.js` (**T-63's neighbour** — same file,
same class, and it should not be left to mislead the next reader as it misled this one).

---

**Original entry, left standing:**


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

## ~~T-81 — The projection's safety valve deletes long-running protocols from the dashboard and calendar~~ — **INSTANCE FIXED 2026-08-04**
**Priority 8/10** · **Owner:** mac · **Agent:** — · **Status:** done — **the INSTANCE, not the class**

**CLOSED by `df0fc5a`. And the way it was found is the finding.**

**BOTH SIDES SPENT THE DAY BELIEVING THIS WAS ALREADY FIXED. It was not.** A message reporting the
discovery ended *"Merged and pushed, build green"* — describing a DIFFERENT task in the same message —
and that was read back as established fact and repeated twice, once to the owner, while both sides
held a checkout in which one grep would have refuted it. **`TASKS.md` said `open` the whole time.**
That is what rule 9a now exists for: *a task's status is what the file says, not what a message said.*

It was actually found by agent `t82-dayframe` building an unrelated DST fixture — a daily protocol
started in January emitted ONE day of seven. **It moved the fixture rather than fixing another task's
bug inside T-82, and flagged it.** Fixing it in place would have buried an 8 inside a 6's diff.

**The defect:** `step` is fast-forwarded to *doses since the protocol began*; the guard compared it
against `days * 4 + 8`, a budget derived from the *window length*. Two different quantities. A daily
protocol running 200 days, projected over 30, starts at `step = 200` against a cap of 128 and emits
**one** occurrence. Still active, still due, silently absent — no error, no empty state.

**It is a THRESHOLD, not a constant**, which is why nothing ever caught it: a protocol projects
perfectly right up until the day it does not. `Retatrutide · 4.5 mg/inj` was at step 60 against 64.

**Shown RED first:** `"1" is not equal to "30"`. Fixed by counting iterations of the loop the budget
actually describes.

**THIS IS THE INSTANCE, NOT THE CLASS — stated because "cap raised" and "class removed" are
different closures and a later reader cannot tell them apart from the diff.** The projection still
builds the series statefully. The web cannot have this bug at all, because its primitive is a pure
per-date predicate with no accumulator and no budget. **T-09 has since removed the class on the
CALENDAR path** by moving it to exactly that shape; the dashboard's `projectedDoses` still carries it.

**A correction inside the fix, recorded rather than smoothed over:** the degenerate-interval test
first ran red at 129-vs-128, and **the off-by-one was in the ASSERTION, not the guard** — the
threshold is tested after the increment, so 129 passes are permitted. Stated exactly, because a bound
quietly widened to go green is indistinguishable from one that was always right.

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

## ~~T-82 — Two day-string frames, and half of every day they disagree~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Agent:** — · **Status:** done

**CLOSED by `df0fc5a`, built by agent `t82-dayframe`.**

**Fixed with a NAMED PAIR rather than two patches, and that shape came from the web side's own
post-mortem:** there, the root cause of the identical class was a MISSING EXPORT — `parseLocalDate`
had always been exported to READ a Postgres date and nothing exported the inverse to WRITE one, so
six components wrote their own private copy. iOS now has `dpLocalDay` (writer) beside
`dpParseLocalDay` (reader), and the two files that had their own private day formatters
(`ConfirmStartScreen`, `CalculatorViewModel`) call it.

**Local for the emitted calendar day, UTC for the arithmetic.** Only the window origin converts;
the interval walk stays on day tokens in a fixed UTC frame where a day is always 86400s, so no DST
transition can gain or lose an hour across an N-day step. Pinned across the 2026-09-27 NZDT change.

**Latent, not live — say so rather than implying damage.** Production was searched for the signature
and **no instance was found**; the one candidate was the web's move-a-dose feature used twice.

**A LIVE bug was removed alongside it, and it is the more serious half.** `InjectionMoment.forLog`
recognised "today" in EITHER day frame. East of UTC, `dpFormatDay(now)` **is** yesterday's date for
the first twelve hours, so an Auckland user deliberately back-dating a dose to yesterday matched the
UTC arm and the row was stamped with **this morning's clock time and instant**. The user made an
explicit choice and the app silently overrode it — worse than a wrong default, because nobody
re-checks something they typed.

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

## ~~T-96 — `defaultConc` and `defaultTab` are read by nothing, so Anadrol seeds a 10 mg tablet~~ — **DONE 2026-08-04**
**Priority 5/10** · **Owner:** mac · **Agent:** — · **Status:** done

**CLOSED. Built by agent `t96-seed`. 220/220 green, shown red first, photographed.**

**FRAME: `docs/ui-audit/t96-anadrol-tablet/t96-01-steroid-anadrol-50mg-tab.png`** — Steroid Dosage,
**Anadrol (Oxymetholone)**, **TABLET STRENGTH 50 mg/tab**. Self-identifying.

**The red run states the harm in its own numbers:** forcing `defaultTab` back to a constant 10 failed
`testAnadrolsTabletCountIsNoLongerFiveTimesTooHigh` with `"10.00 tab"` against `"2.00 tab"` — the 5×
exactly, on the screen, not as an argument.

**THE WEB HAS TWO RE-SEED MECHANISMS, NOT ONE, and the brief only named one.** `useEffect` on
`[esterKey, form]` (`app.js:8813`) re-seeds **concentration only**. But a cross-compound pick is a
NAVIGATION — `:8940` `window.location.href = '/steroid-dosage-calculator/' + s + '/'` — which
remounts and re-runs BOTH `useState` seeds (`:8803`, `:8811`). A same-compound ester pick
short-circuits at `:8938`. So the real rule is asymmetric: **compound change re-seeds both, ester
change re-seeds concentration only.** That asymmetry is reproduced and pinned.

**Seeding follows T-41's shape rather than inventing one:** the spec resolves purely, the VALUE seeds
once on the transition, re-entrancy guarded (`isConverting` generalised to `isSettling`). A seeder
that ran every render is how a field comes to show a number the engine never used.

**A user-typed strength is replaced by a COMPOUND change and survives everything else** — the web's
behaviour, and correct: a tablet strength is a fact about the compound in front of you, not a
preference to carry forward. **One deliberate divergence:** the web's navigation also wipes dose,
split, mgWeek, nDays and the barrel because the component is rebuilt; iOS is one screen and keeps
them. Discarding a dose because the user corrected the compound is a worse screen, not a more
faithful one. Pinned by `testACompoundChangeKeepsTheDoseTheUserTyped`.

**Config key set unchanged — measured, not reasoned.** `saved_dosages` holds **9 steroid rows, none
written by iOS**: every one carries the web's `tab: "10"`, and iOS injectable saves write `tab: ""`,
of which there are zero. So there is nothing to re-fingerprint. **And one production row is
`anavar / tab: "20"` — a user who hit exactly this defect and corrected the tablet strength by
hand.**

**Still open from this area:** the web also re-seeds on the `form` toggle, which iOS has no analogue
for because it has no form toggle (T-94).

**What:** `SteroidCompound.defaultConc(for:)` and `SteroidCompound.defaultTab` exist, are correct,
and **nothing consults them.** Vial strength stays at 200 mg/mL and tablet strength at 10 mg/tab
whatever compound is picked, where the web re-seeds both per compound and per ester on selection
(`useEffect`, `app.js:8813`).

**The live wrong number: Anadrol ships 50 mg tablets.** Pick Anadrol and the tablet strength stays
10, so the tablets-per-dose figure is **5× too high** until the user notices and edits it. That is a
dosing number on a dosing screen, which is why this is a 5 rather than a 2.

**This is T-47's pattern, instances four and five**, and both were found the same way as the first
three — incidentally, while doing something else. They are the argument for T-47 being a sweep
rather than three individual fixes.

**Why T-44 did not take it:** the value must follow the picker, which is `CalculatorViewModel`
work — a different lane from the form split, and the T-44 agent correctly stopped at its boundary.

**Done when:** selecting a compound (and an ester) re-seeds vial strength and tablet strength as the
web does, Anadrol is shown seeding 50 mg/tab, and a test pins the re-seed for at least one compound
of each kind.

## ~~T-97 — iOS floors fractional cadences where the web rounds, so E3.5 users inject on different days~~ — **DONE 2026-08-04**
**Priority 6/10** · **Owner:** mac · **Agent:** — · **Status:** done

**What:** for a fractional interval, iOS computes the day offset as `Int(Double(step) * interval)` —
a FLOOR — giving `0, 3, 7, 10, 14` for E3.5D. The web rounds (`Math.round(k * f)`), giving
`0, 4, 7, 11, 14`. **The two clients tell the same user to inject on different days**, and they drift
apart and back together across the week.

**Why it matters beyond tidiness:** `nDays: 3.5` is the web's own default and the commonest TRT
interval, so this is not an edge case — it is the modal protocol. It also decides which day a dose is
projected on, and therefore which `dosed_on` a tap on the calendar writes.

**The iOS comment is actively wrong** and says the floor is *"matching the web schedule rather than
0,4,7,11,14"* — it names the web's actual behaviour as the thing it is avoiding.

**Found by:** agent `t09-window` while removing T-09's class. Deliberately not taken there, because
changing which days a protocol falls on is a reschedule and would have been hidden inside a coverage
fix.

**Done when:** ~~one rule produces both clients' dose days, chosen deliberately and recorded, and a
test pins E3.5D's first five days against the web's~~ ✔ **ALL MET.**

**ANSWERED FROM THE LIVE WEB FUNCTION, RUN RATHER THAN READ** — win executed `isDoseDay` over a
28-day span and reported the grids, so the expected values in `testFractionalCadencesLandOnTheWebsDays`
compare iOS against the WEB rather than against itself:

```
3.5 → 0,4,7,11,14,18,21,25,28      2.5 → 0,3,5,8,10,13,15,18,20,23,25,28
1.5 → 0,2,3,5,6,8,9,11,…           7 → 0,7,14,21,28        2 → 0,2,4,…,28
```

**The rule is not "rounds" — a day is a dose day iff it is the NEAREST INTEGER DAY to some exact
multiple of the interval.** iOS now emits `round(step × interval)`, which is that set generated
forwards.

**NEITHER CLIENT WAS ARITHMETICALLY WRONG, and that is why this survived.** Web 3.5 gives gaps of
4,3,4,3; the old floor gave 3,4,3,4. **Both average exactly 3.5.** They differed only in PHASE, so no
aggregate check could ever see it — only a user holding both clients.

**iOS moved rather than the web, and the reason is DATA, not correctness.** The web holds the
history: every `dose_log` row already written and every projection those users have seen was
generated on its grid. Changing the web would misalign rows that already exist. (A tiebreaker only:
flooring also injects *earlier*, leaning to marginally more drug sooner.)

**Portability, pinned rather than assumed:** JS `Math.round` is half-UP; Swift `.rounded()` is
`.toNearestOrAwayFromZero`, **identical for non-negative values and divergent for negatives**. The
walk never produces a negative step, and `testRoundingMatchesJavaScriptForTheValuesTheWalkCanProduce`
pins both the agreement and the divergence, so the guard is not mistaken for a nicety.

**AN EXISTING GREEN TEST HAD TO CHANGE, AND IT WAS WRONG RATHER THAN MERELY OUTDATED.**
`testProjection_TwiceWeeklyDates` pinned `06-01, 06-04, 06-08, 06-11, 06-15` and its comment called
those "the rounded offsets", which they were not. **The test agreed with the code, the comment agreed
with the test, and all three disagreed with the web.** Recorded in the test rather than quietly
re-baselined: a green test whose expectation encodes the defect converts the bug into the
specification.

**The old source comment is deleted rather than corrected** — it claimed the floor was "matching the
web schedule rather than 0,4,7,11,14", naming the web's actual behaviour as the thing it avoided.
The test says it better than the prose could.

---

## Non-task blocks from the old file

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

---

## Carried forward from upstream d0da759 / 7a08cbe

Added to the old `TASKS.md` after the snapshot this archive was split from.

### T-48 — the current frame set is re-shot, and two things fell out of shooting it
**Priority 4/10** · **Owner:** mac · **Status:** done

**What:** `docs/ui-audit/` had no frame set for the current build. The newest was
`2026-08-04-post-t01a`, taken before T-01c/T-01d/T-54, and no set anywhere held the onboarding
flow alongside the app.

**Done:** `docs/ui-audit/2026-08-04-current/` — 19 app frames
(`CaptureCurrentState.testCaptureFullDefaultSweep`, gate-asserted `size=large`) and 70 onboarding
frames (`OnboardingCaptureTests.testWalkSixPaths`, six paths, settled frames only), all on
iPhone 16 Pro `1481D20C` / iOS 18.3. The README records the working-tree fingerprint
`893bfea6483e` on top of `d0da759`, because the tree was dirty and "2026-08-04" names a day that
held several builds.

**Two things found while doing it, both recorded rather than carried in a message:**

1. **The sweep still expected `TRT & EOD`, which T-12 collapsed.** The first run died on
   *"TRT & EOD never became hittable after 12 scrolls"* eight frames in. Checked before the list
   was touched: `CalculatorSlug.isCollapsed` is true for `.eod` and `isListed` excludes it, so
   `members` drops it at the source — the row is not there. Entry removed from
   `CaptureCurrentState.swift` with the collapse-vs-withdrawal distinction recorded, since the two
   states are not the same and only one of them has a screen at the end of a second route.
   **Twelve listed calculators, twelve frames.**

2. **`Tests/InjectBuddyTests/T01cDashboardUpcomingTests.swift` did not compile**, so
   `build-for-testing` was red for the whole scheme and nothing could be captured until it was
   fixed. Two test methods call the main-actor-isolated `DashboardViewModel.derive` from a
   non-isolated context. `@MainActor` added to both — the fix the compiler names. **The file is
   T-01c's in-progress work and is still untracked**, so the fix sits in the working tree with the
   rest of it rather than being committed out from under its owner.

**Still not captured, and both are standing decisions rather than gaps:** the drawer and Settings
(they render the account's real email and avatar), and the signed-out/welcome path (recovering it
costs the Keychain session — `simctl erase` is the only way back and this simulator has never been
erased). The drawer and Settings need a masking decision made before they need a capture.
