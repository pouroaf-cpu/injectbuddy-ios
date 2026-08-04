# CALC-PARITY — the calculator half of T-01b

**What this is.** Thirteen calculator screens compared against the web, one section each:
what iOS does now, what the web does, and why the difference matters. It is the calculator
counterpart to `SHELL-PARITY.md`, and it exists for the same reason — the detail lives in one
place and `TASKS.md` carries the entries, so there is one file to edit per screen.

**Frames.** The iOS side is `docs/ui-audit/2026-08-04-post-t01a/`, captured AFTER T-01a rebuilt
the chrome `CalculatorScreen` shares across all fifteen calculators. The older
`2026-08-03-current` set must not be used for parity work: comparing against it re-reports six
shipping features as missing on fourteen screens.

**Two screens are exempt and that is itself a finding.** BMI and Free T Index are withdrawn from
Tools (`CalculatorSlug.isListed` is false for both), and the capture harness navigates by tapping
a Tools row — so they **cannot be photographed at all** while withdrawn. Their frames predate
T-01a, so anything said about their chrome may already be fixed. Tracked as T-55.

**Ordering of truth**, as T-01: the web working tree → `https://www.injectbuddy.com` → the source
on `feature/dosage-status-model` → the 2026-07-31 captures. Where a claim rests on the web's own
`spec/`, that is cited, because `spec/math-spec.md` is written FOR ports and is the closest thing
to a contract between the two apps.

**The maths was compared, not only the layout.** A calculator that renders identically and divides
differently is worse than one that looks wrong, so arithmetic divergences are listed first on each
screen and several became their own high-priority tasks (T-41, T-42, T-43, T-44).

---

# T-01b — six calculator screens compared (2026-08-04)

**Method:** T-01's. iOS frame → web partner → every difference listed, functional before visual,
nothing fixed. **Ordering of truth applied:** the web working tree at `~/injectbuddy` on
`feature/dosage-status-model` (fetched `6a37ce2`) → the live site → the 2026-07-31 captures. Where a
capture and the source disagree the source wins, and on two of these six screens the captures are
silent or unusable, which is recorded rather than worked around.

**Frames used.** Four from `docs/ui-audit/2026-08-04-post-t01a/` — `18-calculator-reconstitution`,
`26-calculator-microdose`, `27-calculator-plotter`, `28-calculator-steroid`. The post-T-01a set is
the only valid one for those: T-01a rebuilt the chrome `CalculatorScreen` shares, so every
calculator's iOS side moved on `29a8ede`.

> **CAVEAT ON BMI AND FREE-T INDEX, and it is part of the finding, not a footnote.** Their iOS
> frames are `docs/ui-audit/2026-08-02-current/24-calculator-bmi-IB2245771.png` and
> `25-calculator-freetest-IB2245772.png` — **from the older set, taken before T-01a.** They cannot be
> re-shot: `CalculatorSlug.isListed` is `false` for `.bmi` and `.freeTestIndex`
> (`Core/Nav/NavItems.swift`), so `ToolsScreen` has no row for them and the sweep
> (`CaptureCurrentState.testCaptureFullDefaultSweep`) physically cannot reach them. **Anything below
> about their chrome may already be fixed** — both frames still show `−`/`+` steppers, sentence-case
> labels, white raised fields and no cyan bar, all of which T-01a replaced. The maths, the field
> sets, the ranges and the result content below are read from source and are current regardless.
> Two calculators withdrawn from every browse surface are also two calculators no capture
> instrument can see, which is worth a line in T-11's neighbourhood in its own right.

> **CAVEAT ON THE PLOTTER'S WEB REFERENCE.** `51-calc-plotter-empty.png` and
> `51-calc-plotter-result.png` are **the same frame**, and neither photographs the plotter: both are
> the first-run tour modal ("1 OF 2 · What this does") over a dimmed page. The reference set is
> therefore silent on this screen and the source rules absolutely. The plotter comparison below is
> against `public/legacy/cycle-plotter/{pk.js,controls.jsx,app.jsx}`, `spec/math-spec.md` and
> `spec/compounds.json`. Two things the frames still yield: a `+ Add dosage to plotter` control at
> the top of the page, and the tour's own words — *"add a compound, tick it, press Calculate"* —
> which describe a protocol list with per-item enable and an explicit calculate step.

---

## Cross-cutting — true on all six, listed once so the per-screen lists stay about their screen

**X-1 · The tick drum ships on one calculator, not fifteen.** `CalculatorCatalog.spec(for:)` passes
`drum:` on four fields, all of them inside `case .trt`. `FieldRow.drumStrip`
(`CalculatorScreen.swift`) renders `if !field.drum.isEmpty`, so on the five generic screens here
every numeric field is a bare recessed well with no scale. The web puts a drum on all of them —
`QuickPickerField` / `SliderField(drumValues:)` — and the reference frames show the ticks directly:
`38-calc-reconstitution-empty` (3 4 5 6 beside PEPTIDE IN VIAL, 150 200 250 300 350 beside TARGET
CONCENTRATION), `40-calc-microdose-empty` (all three rows), `48-calc-steroid-empty` (all three rows),
`39-calc-bmi-result` (both rows). `DrumPicker.tsx` calls it the primary input, not an ornament.
**Done when:** every numeric field on these six carries the web's own value array, or the field is
recorded here with the reason it cannot.

**X-2 · iOS computes live; the web gates on Show result.** `CalculatorScreen` renders
`ResultCard` whenever `vm.result.isValid`, *and* carries the cyan `Show result` bar T-01a built. The
web wraps every one of these in `useCalcGate(saveSig)` and blanks the result whenever an input
changes. The BMI and Free-T frames are the proof: both show a finished answer at rest on untouched
defaults. On this app the cyan bar has nothing left to reveal.
**Done when:** the owner has decided whether iOS keeps the live result (and the bar becomes
something else) or adopts the gate. This is a behaviour choice, not a bug — file it, do not pick.

**X-3 · Every iOS field opens pre-filled with a plausible clinical number; every web page opens
blank.** `MicrodoseTRTPage`, `SteroidDosePage`, `BMICalculator`, `ReconstitutionPage` all
`useState(0)`; `FreeTestPage` uses `''`. Each then glows the empty field when you press Show result
(`useFieldGlow` / `glow.gate`). iOS ships defaults on every field of every one of these six. The
consequence is specific and it is a dosing consequence: an untouched iOS steroid screen states
**0.75 mL / 75 units** and an untouched Free-T screen states **FAI 40.0, Normal**, for a user who has
entered nothing.
**Done when:** each screen either opens empty with a field-level prompt, or its pre-fill is written
down here with the reason that pre-fill is safe.

**X-4 · The saved-protocol label is the calculator's name, not the protocol.**
`CalculatorViewModel.save` writes `label: spec.saveTitle` — a constant. The web builds a descriptive
label at every save site: reconstitution `peptideMg + 'mg → ' + targetConc + 'mcg/mL'`, microdose
`(mgWeek) + 'mg/wk · ' + esterType`, steroid `Math.round(weeklyTotal) + ' mg/wk · ' + displayName +
' ' + esterLabel`. Three microdose protocols saved from iOS are three dashboard rows all reading
"TRT Microdose".
**Done when:** each of these three slugs builds the web's label string, or the deviation is recorded.

**X-5 · The web meters calculator use; iOS does not.** `ibCheckCalcLimit` / `CalcUsageBadge` /
`ibShowLimitModal`, and every reference frame carries "5 free calculations per week — no login".
Business rule, not layout — **owner's call**, and it belongs beside T-13 rather than inside a screen.

---

## T-01b-i — Reconstitution (compared 2026-08-04) — **7 differences**
**Priority 8/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-04-post-t01a/18-calculator-reconstitution.png` · web
`screens/38-calc-reconstitution-{empty,result}.png` · source `ReconstitutionPage` in
`public/app.js`.

**Functional — the app cannot do things the web can:**

1. **No mg/mcg unit toggle on "Peptide in vial", and the web converts the value when you flip it.**
   The web renders `DrumUnitToggle` inside the field (`pepCard`'s `extra:`), remembers the choice in
   `localStorage['ib_unit_dose']`, and `handlePepUnitToggle` rewrites the displayed number so the
   physical quantity is preserved (5 mg ⇄ 5000 mcg). iOS has a single `mg` field
   (`.number("peptideMg", "Peptide in vial", unit: "mg")`) and `configExtras(for: .reconstitution)`
   hardcodes `pepUnit: "mg"`. **Why that is wrong:** most research peptide vials are labelled in
   mcg. The user does the conversion in their head, on the input that multiplies straight into the
   bac-water volume. The toggle is visible in both reference frames as a two-state pill to the right
   of the field.
   **Done when:** the field carries the unit toggle, the value converts on toggle, and `pepUnit`
   stops being an extra and becomes the real chosen value.

2. **The bac-water volume is rounded to 2 decimals; the web shows 4.** iOS:
   `ResultRow(label: "Add bac water", value: "\(fmt(r.bacWaterMl, 2)) mL")` in
   `CalculatorEvaluate.swift`. Web: `HeroCyclePanel` metric `{label:'BAC Water to Add', decimals: 4,
   placeholder: '0.0000'}`, and the reference frame reads `0.0000 mL` — four places, deliberately.
   2 mg at 3000 mcg/mL is 0.6667 mL on the web and 0.67 mL on iOS. **Why that is wrong here
   specifically:** this number is not a dose, it is the number that *sets the concentration of every
   dose later drawn from that vial*. A rounding at reconstitution time propagates into every draw
   the peptide calculator computes afterwards.
   **Done when:** the row renders 4 decimals, matching the web's own decimal contract.

3. **One of the three result metrics is missing, and the surface is a card not a carousel.** The web
   result is a three-metric swipeable panel — `BAC Water to Add` / `Concentration` / `Vial Contents`
   — with page dots; the two reference frames are the same screen showing pages 1 and 2 of it. iOS
   shows two static rows and never echoes **Concentration**, the number the user just chose.
   **Done when:** all three metrics render, with the concentration among them.

4. **No hand-off into the peptide dosage calculator.** Web `goToDose` sets
   `window.__ibReconTransfer = {peptideMg, bacWaterMl, concentration}` and navigates to the peptide
   page, under the CTA "Just reconstituted? Work out your dose →", with a plain second link beneath
   it. iOS ends at the number. **Why that is wrong:** reconstituting is never the goal — working out
   the draw is — and the three numbers needed downstream are already in hand.
   **Done when:** the CTA exists and carries the three values into `.peptide`, or the shortfall is
   recorded the way T-17 records the plotter's.

5. **Target concentration accepts values the web's control cannot reach.** iOS
   `.number("targetConc", default: 1000, range: 0...10000, step: 50)`. Web
   `RECON_TARGET_CONC_VALUES` = `[0]` then 100…5000 by 50. iOS offers up to 10 000 mcg/mL — twice the
   web's ceiling — and a default of 1000 where the web opens at 0.
   **Done when:** the range is the web's array (which is also X-1's drum for this field).

**Visual — the same information rendered differently:**

6. **A readout the iOS screen has no equivalent of.** Both reference frames show a right-aligned
   `0 mcg/mL` immediately under the PEPTIDE IN VIAL row, above TARGET CONCENTRATION — a live echo of
   the concentration as you set the vial amount. **Source symbol not located** in
   `ReconstitutionPage`'s `left` composition; read it off the running page before building, per the
   rule that a document about the source is not the source.
   **Done when:** the readout is either built from the verified source, or the frame's element is
   identified as something else and this line is struck with the correction.

7. **No FAQ.** Three questions on the web (`CalcFAQ` items in `ReconstitutionPage`: what BAC water
   is, whether more water changes the peptide amount, what concentration to aim for). **Parked with
   T-13** — same reasoning as T-01a #5.

**No differences found in:** the formula card (`FormulaCard` transcribes
`IB_CALC_FORMULA.reconstitution` verbatim and matches), the plot CTA (`PLOT_CTA_CALC_IDS` includes `reconstitution`, and the wording
split gives it "Plot this protocol over time →", which is what the frame shows), and the arithmetic
itself — `CalculatorEngine.reconstitution` is `(peptideMg × 1000) ÷ targetConc` exactly as
`ReconstitutionPage` computes it.

---

## T-01b-ii — TRT Microdose (compared 2026-08-04) — **9 differences**
**Priority 9/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-04-post-t01a/26-calculator-microdose.png` · web
`screens/40-calc-microdose-{empty,result}.png` · source `MicrodoseTRTPage` + `MicroTRTInputs` in
`public/app.js`.

**Functional — the app cannot do things the web can:**

1. **No mode switcher — T-01a #1 again, on a second screen.** `MicroTRTInputs` opens with the same
   `ModeTab`: `Every N Days` · `Per Week` · `mL → mg`, and the reference frame shows it with
   `Every N Days` active. The iOS spec has no `mode` field, and `evaluate(slug: .microdose)` in
   `CalculatorEvaluate.swift` hardcodes `mode: .ndays, injPerWeek: 0, mlDrawn: 0`. Worse than
   absent: `configExtras(for: .microdose)` writes `"mode": "ndays"` and `"injPerWeek": 0` into the
   saved config, so the row asserts a mode the user was never shown.
   **Done when:** the microdose spec carries the `mode` field, `showsUnderMode` drives its rows (the
   machinery T-01a already built is generic — it keys off the spec having a `mode` field, not off
   `slug == .trt`), and the extras stop asserting it.

2. **No ester field — and iOS saves the exact value the web refuses to save.** `MicroTRTInputs`
   renders `EsterCombobox` over `ESTER_TYPE_OPTIONS` as its *first* input after the mode tabs;
   `glow.gate` flags it on Show result, and `handleSave` bails with `'Input Ester type'` when it is
   empty. `configExtras(for: .microdose)` on iOS writes `"esterType": ""`. **Why that is wrong:**
   every microdose protocol iOS saves is a row the web would have rejected at its own save gate, the
   web cannot restore the ester when it reads the row back (`loadDosage` does `if (cfg.esterType)`),
   and the empty string participates in the whole-config unique index — so an iOS save and the
   equivalent web save are different rows, which is the exact failure `CalculatorCatalog`'s own
   cross-platform note warns about. The reference `result` frame shows the field ringed red, which
   is the web flagging it as the one thing missing.
   **Done when:** `esterType` is a real `stringPicker` field on this spec, out of extras, and the
   ester is required before Add.

3. **The injection interval cannot be 3.5 days.** iOS `.number("nDays", "Inject every", unit: "days",
   default: 3, range: 1...7, step: 1)`. Web `EVERY_N_DAYS_VALUES` is `[0]` then 1…14 by **0.5**, and
   `snapNDays` falls back to 3.5. **Why that is wrong:** twice-weekly is the interval this page's own
   FAQ names ("twice-weekly injections of 1–3 mg per injection"), and a step of 1 makes it
   unreachable. It also caps at 7 where the web goes to 14.
   **Done when:** the field is the web's array, 1…14 by 0.5.

4. **The weekly-dose field goes to 100 mg/wk on a page about 0.5–10 mg/wk.** iOS
   `range: 0...100, step: 0.5`. Web `MICRO_WEEKLY_DOSE_STEPS` is 0.5…50 by 0.5 and `snapMicroDose`
   *clamps* to `[0.5, 50]`. **Why that is wrong:** the page's own copy says "Total weekly doses above
   10 mg risk pushing serum levels above the female physiological range". iOS's ceiling is ten times
   that with no clamp, on the one calculator whose entire premise is smallness.
   **Done when:** the field clamps to the web's 0.5…50 and steps by 0.5.

5. **Vial strength range differs.** iOS `range: 1...100, step: 1`, default 10. Web
   `MICRO_VIAL_STRENGTH_VALUES` is `[0]` then 5…100 by **5**, and the page opens at 0.
   **Done when:** the field uses the web's array.

6. **The page is framed for women on the web and unframed on iOS.** Web title:
   *"Testosterone (TRT) Microdosing Calculator for Women"*; its breadcrumb reads "Testosterone (TRT)
   Microdose"; four of its five FAQ entries are about women's therapy. iOS: `saveTitle` "TRT
   Microdose", `CalculatorSlug.title` "TRT Microdose", no framing anywhere. **Why that matters
   beyond wording:** the ranges in #3–#5 only look arbitrary until you know who the page is for.
   **Done when:** the owner has decided how iOS names this calculator, and it is written here.

7. **Saved label** — see X-4; the web string for this slug is
   `(Math.round(mgWeek * 10) / 10) + 'mg/wk · ' + esterType`.

**Visual — the same information rendered differently:**

8. **iOS shows a quick-chip row the web does not have, in place of the drum the web does.** The iOS
   frame renders five chips under WEEKLY DOSE (5 / 10 / 15 / 20 / 25, "5" selected). The web
   microdose page has **no chip row at all** — `MicroWeeklyDoseField` is a `QuickPickerField` whose
   only affordances are the value box and the drum. So this screen has an input the web does not
   have, and lacks the one it does (X-1).
   **Done when:** the chip row is either justified here as an iOS addition or removed with the drum
   built in its place.

9. **The syringe control is named and labelled differently.** Web: section header `SYRINGE SIZE`,
   options `0.3 mL` / `0.5 mL` / `1 mL` / `3 mL` (`SyringeSizeCard`). iOS: `SYRINGE BARREL`, options
   `0.3 mL (30u)` / `0.5 mL (50u)` / `1 mL (100u)` / `3 mL (IM)` (`CalculatorCatalog.barrelOptions`).
   Note this is the very header T-01a #10 quoted as the example of the web's small-caps style — iOS
   built the style and changed the word.
   **Done when:** the header and the four option labels match the web, or the annotations are
   recorded as a deliberate iOS improvement.

**Also present on the web and parked with T-13:** the five-question FAQ and the related-calculators
carousel (visible in the reference frame as "Testosterone (TRT) Dosage Calculator" and a second card).

---

## T-01b-iii — Steroid Dosage (compared 2026-08-04) — **12 differences**
**Priority 10/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-04-post-t01a/28-calculator-steroid.png` · web
`screens/48-calc-steroid-{empty,result}.png` · source `SteroidDosePage`, `IB_STEROIDS`,
`IB_STEROID_ORDER` in `public/app.js`; iOS `SteroidCatalog.swift`,
`CalculatorEngine.steroidInjectable`, `CalculatorEvaluate.swift`.

**Maths — the two platforms compute different numbers from the same inputs. These go first.**

1. **The ester cannot be chosen, so the active-hormone number is wrong for two compounds by up to
   22%.** The web has **no separate ester picker**: `compoundOptions` expands every ester compound
   into one dropdown entry per ester — "Trenbolone Acetate", "Trenbolone Enanthate", "Masteron
   Propionate", "Masteron Enanthate" — and `esterFactor = ev.esterFactor` reads the *chosen* one.
   The reference frame opens on `Trenbolone Acetate` for exactly this reason. iOS's picker has one
   entry per compound and `evaluate(slug: .steroid)` takes `compound.defaultEster`, which
   `SteroidCompound.defaultEster` defines as `esters.first`. Trenbolone is therefore permanently
   0.87 and Masteron permanently 0.84; 0.71 and 0.73 are unreachable from the phone. At 300 mg/week
   of Trenbolone Enanthate the web reports **213 mg active** and iOS reports **261 mg** — 22.5%
   high, on the one number this calculator exists to produce that TRT does not already give you.
   `configExtras(for: .steroid)` compounds it: it writes `"esterKey": compound.defaultEster?.key`,
   so the saved row records an ester the user never picked.
   **Done when:** the compound picker is the web's ester-expanded list, `esterFactor` reads the
   chosen ester, and `esterKey` in the config is the user's choice.

2. **Five oral-only compounds are offered with injectable inputs and produce a syringe volume for a
   tablet.** `IB_STEROIDS` marks `anavar`, `dianabol`, `tbol`, `anadrol`, `superdrol` as `cls:'oral'`
   and `SteroidCatalog` mirrors that with `canInject: false` — but the iOS picker enumerates
   `SteroidCatalog.all` unfiltered, and the spec renders vial strength / weekly dose / inject every /
   syringe barrel for every entry. **The frame is the evidence:** the screen opens on
   **Oxandrolone (Anavar)** — an oral — at 200 mg/mL with a syringe barrel underneath, and
   `evaluate` returns 300 ÷ 2 = 150 mg per injection ÷ 200 mg/mL = **0.75 mL, 75 units** of a drug
   that has no injectable form. The web cannot reach this state: `form` is initialised
   `canInject ? 'injectable' : 'oral'` and the toggle only appears for `winstrol`, the one compound
   marked `'oral|injectable'`. **This is a health-app failure of the exact kind CLAUDE.md names** —
   a confident number that is not a dose.
   **Done when:** the picker is filtered to injectable compounds, or #3 lands and the form follows
   the compound.

3. **No oral form at all, and the engine for it is already ported and unreachable.**
   `CalculatorEngine.steroidOral(doseMgPerDay:tabMg:split:)` exists and matches the web's
   `perDoseMg` / `tabsPerDose` exactly; `CalculatorCatalog`'s own comment says orals are held back
   because the generic spec model renders one field set. The web swaps the whole input set on
   `formToggle` — Daily dose (mg) / Tablet strength (mg/tab) / Doses per day — and swaps the result
   panel to `HeroCyclePanel` with Tablets / Per Dose / Daily.
   **Done when:** the form toggle exists and drives both the field set and the result, or the
   omission is recorded with the reason.

4. **No mode switcher.** `injectInputs` leads with the same three-way `ModeTab` as TRT and microdose,
   plus an extra "Injections per week" `ChipRow` (Daily / EOD / 3× / 2× / 1×) in `ml2mg` mode. iOS
   hardcodes `.ndays` with `injPerWeek: 0, mlDrawn: 0` in `evaluate`. Third screen, same defect —
   T-01a #1, T-01b-ii #1, this.
   **Done when:** as T-01b-ii #1.

5. **Vial strength does not follow the compound.** Web: `defConc = ev ? ev.defaultConc : (d.defaultConc
   || 200)`, re-applied by `useEffect(..., [esterKey, form])`, so picking Winstrol sets 50, Tren A
   100, NPP 100, Primobolan 100, Deca 200, Equipoise 250. The reference frame shows Tren Acetate
   opening at **100**. iOS is a flat `default: 200` for all twelve. **Why that is wrong:** a user who
   trusts the pre-fill on a 50 mg/mL Winstrol vial draws **four times** the intended volume.
   `SteroidCompound.defaultConc(for:)` already exists on iOS and nothing calls it.
   **Done when:** the strength field re-seeds from `defaultConc(for:)` on every compound/ester change.

6. **The compound order does not match the web, and the file says it does.**
   `SteroidCatalog.all`'s header comment reads "Order matches the web hub". `IB_STEROID_ORDER` is
   `trenbolone, masteron, primobolan, npp, deca, equipoise, anavar, dianabol, tbol, winstrol,
   anadrol, superdrol`. iOS is `anavar, trenbolone, dianabol, npp, tbol, deca, winstrol, equipoise,
   anadrol, masteron, primobolan, superdrol`. The consequence is #2: the web's first entry is an
   injectable and iOS's is an oral, which is why the frame opens on Anavar.
   **Done when:** the order is `IB_STEROID_ORDER` and the comment is true.

**Functional — the app cannot do things the web can:**

7. **"Active weekly" is shown conditionally, unnamed, and without its working.** Web `activeLine`
   renders whenever `d.parent` exists — for *every* compound — as
   `Active <parent>: NNN mg/week`, with `(300 mg × 0.87)` appended when `esterFactor < 1`, and the
   parent is the hormone's name ("Active Nandrolone", "Active Trenbolone"). iOS appends a row
   labelled `"Active weekly"` **only** `if compound.esterFactor(for: ester) < 1`. So the compounds
   where active = total are silent instead of confirming it, the parent hormone is never named, and
   the multiplication that produced the number is hidden — on the one figure a user cannot check by
   inspection.
   **Done when:** the row always renders, names the parent, and shows `total × factor`.

8. **No plot hand-off.** Web `handlePlot` maps the compound (+ester) to a plotter id via
   `steroidPlotterId()`, sets `window.__plotterPreset = {compoundId, dose, freqDays}` and navigates,
   behind the button `Plot blood levels over time →` (`ib-plot-btn`). `steroid` is deliberately
   **not** in `PLOT_CTA_CALC_IDS`, so iOS's generic `PlotLevelsCTA` correctly skips it — and nothing
   replaces it, which is how a correctly-copied list leaves a hole.
   **Done when:** the steroid screen has its own route to the plotter, carrying the compound and
   frequency (blocked behind T-17, and behind T-11 for the destination).

9. **No half-life card, and no way to tell "unknown" from "not offered".** Web `hlCard` shows
   "Pharmacokinetic timing" with `hlDays = halfLifeHours / 24` and `clearDays = round(hlDays × 5)`;
   where `halfLifeHours` is `null` it shows an amber `InfoBox` stating the half-life is *not
   reliably established in the published literature* and that only the dose↔volume conversion is
   exact. Four entries are null (`tbol`, `anadrol`, `superdrol`, and both enanthate esters). iOS
   carries no half-life data on this screen at all — `SteroidCatalog`'s comment says the flags stay
   on the web. **Why that is wrong:** the refusal *is* the datum. `spec/math-spec.md` §6 —
   "Half-lives marked or known to be UNVERIFIED must keep that flag through every port."
   **Done when:** the card renders, including the unverified case.

10. **No formula card.** `IB_CALC_FORMULA.steroid` exists verbatim and is transcribable today:
    `injectable: units = (weekly mg ÷ shots ÷ mg/mL) × 100 · active hormone = ester mg × esterFactor ·
    oral: tablets = (daily mg ÷ doses) ÷ mg/tab`, legend `mg/mL` / `esterFactor` ("parent-hormone MW ÷
    full-ester MW — the active-hormone fraction") / `× 100`. `CalcFormulaCatalog.formula(for:)`
    returns `nil` for `.steroid` via its `default` branch — which its own comment defers to T-01b,
    so this is that. It is also the only place esterFactor is explained.
    **Done when:** `.steroid` is transcribed into `CalcFormulaCatalog`.

11. **iOS suggests doses on a page the web deliberately builds as a neutral converter.** The comment
    above `IB_STEROIDS` states the page's contract: *"neutral conversion tool … Maths +
    pharmacokinetic timing only — no doses, cycles, or regimens."* `mgWeek` opens at **0**. iOS opens
    at **300 mg/week** with quick chips `[200, 300, 400, 500, 600]` — five suggested weekly steroid
    doses, rendered as tappable presets, on the screen with the least clinical supervision of the
    fifteen. **This one is the owner's, not ours.**
    **Done when:** the owner has ruled on the pre-fill and the chip row, and the ruling is here.

12. **Saved label** — see X-4; the web string is
    `Math.round(weeklyTotal) + ' mg/wk · ' + d.displayName + (ev ? ' ' + ev.label : '')`.

**Also present on the web and parked with T-13:** the four-question FAQ (including "What is the
esterFactor / active-hormone amount?") and the related-calculators strip.

**Verified identical, so it is not on the list:** the injectable arithmetic itself.
`CalculatorEngine.steroidInjectable` delegates to `trt`, and `SteroidDosePage`'s own comment says
"Injectable calc — identical to TRTPage". Branch for branch the two agree. Every difference above is
about *which inputs reach it*.

---

## T-01b-iv — Cycle Plotter (compared 2026-08-04) — **11 differences**
**Priority 9/10** · **Owner:** mac · **Status:** open
Frame: iOS `docs/ui-audit/2026-08-04-post-t01a/27-calculator-plotter.png`. **Web reference unusable
— see the caveat at the top.** Source: `public/legacy/cycle-plotter/pk.js`, `controls.jsx`,
`spec/math-spec.md` §4, `spec/compounds.json`. iOS: `CyclePlotterScreen.swift`,
`CyclePlotterViewModel.swift`, `CalculatorEngine` PK section, `PlotterCompound.all`.

**Maths — this screen and the web draw different curves from the same inputs. Highest severity in
the batch.**

1. **iOS multiplies the curve by 13.5 and labels the axis ng/dL. The shared maths spec forbids
   exactly this, in those words.** `CyclePlotterViewModel.rebuild`:
   `factor = allTestoFlag ? CalculatorEngine.testoNgdlFactor : 1.0`, `testoNgdlFactor = 13.5`.
   `CyclePlotterScreen.chartCard`: `Text(vm.allTesto ? "Estimated level (ng/dL)" : …)`.
   `spec/math-spec.md` §4.1: *"This yields **mg-equivalents of active drug, not ng/dL.** Converting
   to a blood concentration would need a volume of distribution we do not have and will not guess.
   The chart is labelled in mg and must never claim a lab number. **A port must not add a unit
   conversion here.**"* The frame shows a curve peaking just over **1,500 "ng/dL"** for 100 mg/week
   Test E — a number in the exact units and the exact range of a real testosterone lab result, which
   a user will compare against their bloodwork. This is a fabricated clinical measurement.
   **Done when:** the factor is removed and the axis is labelled in mg-equivalents, or the owner has
   approved a documented deviation from the shared spec and the web has been changed to match.

2. **A different absorption model.** Web `pk.js rates(halfLife)`: `ke = ln2/halfLife`,
   `riseHL = max(0.01, halfLife × 0.25)` (halved again if `riseHL >= halfLife`), `ka = ln2/riseHL` —
   ka is derived from the half-life and nothing else. iOS `CalculatorEngine.pkSolveKa(ke:tmax:)`
   bisects 100 times for the ka that puts the peak at a per-compound `tmax` field that **exists
   nowhere in the web's data** (`spec/compounds.json` carries name, short, type, cat, halfLife,
   unit). Different ka means a different peak height and a different time-to-peak for every compound
   on every curve. `spec/vectors/pk-kernel.json` pins the web kernel; `git ls-files` in this repo
   returns no vector file, so nothing here replays it.
   **Done when:** `pkSolveKa` is replaced by the spec's `rates()`, `tmax` leaves `PlotterCompound`,
   and `spec/vectors/pk-kernel.json` runs green in the unit suite.

3. **No smoothing — iOS draws the sawtooth the web deliberately does not.** `pk.js` `SMOOTH_FRAC =
   0.5` and `smoothPoints()` apply a centred moving average whose window is half the injection
   interval, before the curve reaches the chart *and* the stats. Its own comment: read literally the
   raw model "is noisy, and the swings read as bigger than the estimate can honestly claim". The iOS
   frame is that comb of spikes, unsmoothed. `spec/math-spec.md` §4.2 additionally requires that a
   port **state which variant it reproduces** (plotter 0.5 vs dashboard 1.0); iOS states neither
   because it reproduces neither.
   **Done when:** `smoothPoints` is ported at `SMOOTH_FRAC = 0.5`, named as the plotter variant, and
   `spec/vectors/pk-series.json` replays clean.

4. **The compound table is a different table, and the file claims it is verbatim.**
   `PlotterCompound.all`'s comment says "verbatim from app.js PLOTTER_COMPOUNDS" — **`PLOTTER_COMPOUNDS`
   does not exist anywhere in the web tree on this branch.** The real source is `spec/compounds.json`
   (31 compounds, generated from `pk.js`, described there as "the single source of truth for compound
   half-lives across web, iOS and Android"). iOS has 27, with different ids and different numbers.
   Half-lives that disagree, iOS vs spec: Test C 5.0 / **6.0**, Test U 20 / **21**, NPP 2.5 / **2.7**,
   Tren A 1.5 / **3.0**, Tren E 5.5 / **7.0**, Mast P 2.5 / **2.0**, Mast E 5.5 / **4.5**,
   BPC-157 0.17 / **0.25**, TB-500 0.58 / **2.5**, CJC no-DAC 0.021 / **0.08**, CJC+DAC 8.0 / **7.0**,
   IGF-1 LR3 0.83 / **0.8**, PT-141 0.113 / **0.5**, MT-II 3.7 / **1.5**, Retatrutide 7.0 / **6.0**.
   Units that disagree: TB-500 mcg / **mg**, PT-141 mcg / **mg**, MT-II mcg / **mg**, HGH mcg / **IU**.
   Absent on iOS: Sustanon, HCG, Primobolan (`methenolone-e`), the three orals (Anavar, Dbol, oral
   Winstrol), Pinealon. Present only on iOS: GHRP-2, GHRP-6, Sermorelin, Thymosin Alpha-1.
   **Tren A at 1.5 days against the spec's 3.0 is a factor-of-two error in every trough it draws.**
   **Done when:** `PlotterCompound.all` is generated from or checked against `spec/compounds.json`,
   the false "verbatim" comment is corrected per rule 7, and §6's recommendation (serve the table,
   file as fallback) is raised with the owner.

**Functional — the app cannot do things the web can:**

5. **One metric where the web has three.** `pk.js seriesFor(p, from, to, metric)` supports
   `serum` | `release` (mg/day) | `total` (active remaining), and `controls.jsx MetricSegment`
   exposes Serum level / mg per day as the site's standard segmented control. iOS plots serum only.
   **Done when:** the metric switch exists, or the omission is recorded.

6. **No protocols, no dates, no weekday schedules.** The web plotter is a date-based protocol board:
   each protocol is a card with a start date, an optional finish (`finishMs` — injections stop, the
   curve keeps decaying so clearance is visible), an on/off state (the whole card is the toggle), an
   assignment to chart 1 or 2, and a `PeriodPicker` with From/To dates and 4w/8w/12w/26w presets.
   `injectionTimes` supports **two scheduling models** — a fixed `freqDays` interval, and
   `days: [1,3,5]` weekday scheduling, which it draws unevenly on purpose (`pk.js`: collapsing MWF to
   "every 2.33 days" "would draw a smooth curve that nobody injects"), stepping by calendar days so
   a DST boundary cannot drift a shot off its weekday. iOS has: a cycle length in weeks, one dose,
   one interval from a fixed list, one chart, no dates at all.
   **Done when:** the owner has scoped how much of this iOS builds; it is a screen, not a control.

7. **No "Add dosage to plotter".** Visible at the top of both reference frames, and the tour's step 1
   is "add a compound, tick it". The web's route in from a saved protocol is `plot-handoff.ts` /
   `PlotterCTA.tsx` plus `window.__plotterPreset` from the calculators. iOS's plotter always starts
   from a hardcoded `PlotterLine(compoundId: "test-e", dose: 100, freqDays: 7)`.
   **Done when:** a saved protocol can be loaded into the plotter (this is the destination half of
   T-17).

8. **No explicit calculate step.** The tour says "press Calculate". iOS's `rebuild()` runs on every
   `didSet` of `lines` and `cycleWeeks`. Same question as X-2, and it should be answered once for
   both.

**Visual — the same information rendered differently:**

9. **The `−`/`+` stepper T-01a removed everywhere else is still here.**
   `Stepper(value: $vm.cycleWeeks, in: 1...52)` in `cycleLengthCard`, plainly visible in the frame.
   The screen is bespoke so the T-01a sweep of `CalculatorScreen` never touched it. The web's own
   array is `CYCLE_WEEKS_VALUES` = `[0]` then 4…20 — iOS also allows 1 and 52 weeks, which that
   array does not.
   **Done when:** the control is a drum over `CYCLE_WEEKS_VALUES`.

10. **Both pickers are `.pickerStyle(.menu)` — the control with the known measured defect, and no
    search over 27 entries.** `CompoundLineRow` uses `.menu` for compound and for frequency.
    `CompoundCombobox` was built in T-01a precisely to replace this and is not used here; T-16
    records the overlap defect the remaining `.menu` sites still carry.
    **Done when:** the compound picker is `CompoundCombobox`.

11. **The frequency list is iOS's own.** `PlotterCompound.freqs` — TID 0.33, BID 0.5, ED 1, EOD 2,
    E3D 3, 2×/wk 3.5, weekly 7, E2W 14 — has no counterpart in `pk.js`, which takes a raw
    `freqDays` (labelled by `PK.freqLabel`) or a weekday set. `0.33` is also not 1/3.
    **Done when:** the control matches whatever #6 settles on, and no invented value survives.

**Cross-reference, not a difference:** the plotter is unreachable from Tools (`.cyclePlotter` is in
no `CalculatorCategory`'s member list) — that is **T-11**, a routing defect. The frame reaches it
from the Dashboard, which is why the frame exists.

---

## T-01b-v — BMI (compared 2026-08-04) — **11 differences**
**Priority 5/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-02-current/24-calculator-bmi-IB2245771.png` — **predates T-01a,
see the caveat at the top** · web `screens/39-calc-bmi-{empty,result}.png` · source `BMICalculator`
and `BMI_CATS` in `public/app.js`.

**Functional:**

1. **The BMI is shown to 2 decimals; the web shows 1.** iOS `ResultRow(label: "BMI", value: fmt(r.bmi,
   2))` → the frame reads `24.69`. Web `fmt(bmi, 1)` → `24.7`. Two decimals on a ratio of two
   self-reported measurements claims precision the inputs do not have.
   **Done when:** the row renders 1 decimal.

2. **The category string differs.** iOS `CalculatorEngine.bmiCategory` returns `"Normal"`;
   `BMI_CATS` labels it `"Normal range"`. The five other labels and all the boundaries
   (18.5 / 25 / 30 / 35 / 40) match exactly — checked value by value.
   **Done when:** the string is the web's.

3. **No band scale.** The web draws a six-stop gradient bar with a white marker at
   `clamp((bmi − 15) / 30, 0, 1)`, tick labels `15 · 18.5 · 25 · 30 · 40+` beneath it, and the
   category in a chip tinted with that band's own colour (`BMI_CATS[].color`). iOS prints two text
   rows. The bar is the thing that answers "how close am I to the next band", which the number alone
   does not.
   **Done when:** the scale renders with the marker and the coloured chip.

4. **No categories table.** Web lists all six bands with their ranges (`≥ 40` for the last) and
   highlights the one you are in. Absent on iOS.
   **Done when:** the table renders.

5. **The units control is a toggle, not a two-state segmented control.** Web: a stretched `ChipRow`
   under the header `UNITS`, options `kg / cm` and `lb / ft·in`. iOS: `.toggle("imperial", "Imperial
   units", default: false)` — a switch labelled with only one of its two states, so the metric case
   is never named on screen.
   **Done when:** it is a two-option segmented control carrying both labels.

6. **Imperial height is two full-width rows on iOS and one on the web.** Web puts `ft` and `in`
   side by side inside a single card under one `Height` label, each with its unit caption beneath.
   iOS renders `.number("heightFt", "Height (ft)")` and `.number("heightIn", "Height")` as two
   separate numeric rows.
   **Done when:** the two components share one labelled row.

7. **Every range is wider than the web's, and every field accepts 0.** Web: weight 30–250 kg, height
   100–230 cm, weight 66–550 lb, feet clamped 3–8, inches 0–11. iOS: `heightCm 0...260`,
   `weightKg 0...300`, `weightLb 0...660`, `heightFt 0...8`, `heightIn 0...11`. A height of 0 is the
   divide-by-zero the web's clamps exclude — iOS returns `.nan` and renders `—`, so it fails safe,
   but the control still offers it.
   **Done when:** the ranges are the web's (this is also X-1's drum arrays: `BMI_WEIGHT_KG_VALUES`,
   `BMI_HEIGHT_CM_VALUES`, `BMI_WEIGHT_LB_VALUES`).

8. **No formula card.** `IB_CALC_FORMULA.bmi` exists: `BMI = weight (kg) ÷ height (m)²` with a legend
   covering the imperial conversions (`pounds ÷ 2.205`, `inches × 0.0254`) and the CDC bands.
   `CalcFormulaCatalog` returns `nil` for `.bmi`.
   **Done when:** transcribed.

**Visual:**

9. **Field order is reversed.** The web renders **weight then height** (both reference frames);
   iOS renders height then weight.
   **Done when:** the spec's field order matches.

10. **The CTA is generic.** Web: a single `Calculate BMI →` button, full width, in the accent
    gradient. iOS: the shared cyan `Show result` bar with `Add` stacked under it — and per X-2 the
    result is already on screen before either is pressed. **Additionally, and flagged for
    re-verification because the frame predates T-01a:** the frame shows a full-width navy `Add` on a
    calculator where `canSaveProtocol` is `false`. `CalculatorScreen` gates that button's
    `isEnabled`, not its presence — so it renders as a disabled commit action on a screen with
    nothing to commit. Confirm against a current frame before filing this half.
    **Done when:** the CTA reads "Calculate BMI →" and no commit control renders on a
    non-saving calculator.

11. **Web-only, recorded so it is not silently dropped:** the four-question FAQ (parked with T-13)
    and the **embed builder** — theme / accent colour / width / height / live preview / "Show code",
    the whole lower half of `39-calc-bmi-result.png`. The embed section publishes an iframe of the
    calculator for third-party sites; it **cannot exist on iOS** and that is the reason, written
    down rather than skipped.

---

## T-01b-vi — Free Testosterone Index (compared 2026-08-04) — **10 differences**
**Priority 8/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-02-current/25-calculator-freetest-IB2245772.png` — **predates
T-01a, see the caveat at the top** · web `screens/41-calc-freetest-{empty,result}.png` · source
`FreeTestPage` in `public/app.js`.

**Maths and behaviour — highest severity first:**

1. **Switching the TT unit does not convert the number, so the result becomes wrong by 28.84×.** Web
   `changeTtUnit` converts the typed value through nmol/L and back, and its comment states the
   failure it exists to prevent, verbatim: *"Toggling the unit converts the typed value so the
   physical quantity is kept (600 ng/dL → ~20.8 nmol/L, not read as 600 nmol/L → a 28.84× wrong
   FAI/band)."* On iOS `ttUnitNgdl` is an ordinary `.picker` and `tt` is left untouched, so flipping
   the unit on the shipped default of 20 turns **FAI 40.0 "Normal" into FAI 1.4 "Low"** without the
   user changing a blood value. This is a health app changing a clinical reading because a dropdown
   moved.
   **Done when:** the unit picker converts the value, and a test pins 600 ng/dL ⇄ 20.8 nmol/L.

2. **The default unit is the wrong one.** Web `useState('ngdl')`, commented "US default"; the
   reference frame shows `ng/dL` selected. iOS `.picker("ttUnitNgdl", default: 0)` = nmol/L, with a
   TT default of 20 (an nmol-scale number). Combined with #1, the first action a US user takes is
   the one that breaks.
   **Done when:** the default is `ngdl`.

3. **Inputs are pre-filled, so the screen states a result for a blood test nobody took.** Web starts
   both fields at `''`. iOS ships `tt: 20`, `shbg: 50` — and the frame shows
   **Free Androgen Index 40.0, Band Normal** at rest. This is X-3, but it earns its own line here:
   the pre-filled output is shaped exactly like a lab interpretation.
   **Done when:** the fields open empty.

**Functional:**

4. **The band has no explanation and no colour.** Web bands carry a sentence and a colour each —
   Low `#fbbf24` "May indicate elevated SHBG binding testosterone."; **"Normal range (adult men)"**
   `#34d399` "Broadly within the 30–150 reference range for adult men."; Elevated `#f97316` "Above
   the typical adult-male range — discuss with your doctor." — rendered as a tinted card under a
   52px number in the band's colour (see `41-calc-freetest-result.png`: `3.5` in amber over a
   `Low` card). iOS's `faiBand` returns a bare word into a plain row, and its middle label is
   `"Normal"` rather than `"Normal range (adult men)"`.
   **Done when:** the band renders as a coloured card with the web's label and note.

5. **No reference-range box.** Web `InfoBox`: *"FAI = (Total Testosterone ÷ SHBG) × 100, both in
   nmol/L. Bands: < 30 low · 30–150 normal range for adult men · > 150 elevated."* Absent on iOS —
   so the thresholds the band names are nowhere on the screen.
   **Done when:** it renders.

6. **No formula card.** `IB_CALC_FORMULA.freetest` exists: `FAI = (total testosterone ÷ SHBG) × 100`
   with a three-term legend. `CalcFormulaCatalog` returns `nil` for `.freeTestIndex`.
   **Done when:** transcribed.

7. **The glossary terms are not linked.** Web wraps `Total Testosterone`, `SHBG` and `Free Androgen
   Index` in `IBTermLabel` — a tap-for-definition affordance visible in the frame as the ⓘ beside
   "Free Androgen Index". iOS renders plain text.
   **Done when:** the three terms carry the definition affordance, or the pattern is recorded as a
   separate cross-app task.

**Visual:**

8. **The unit lives in a separate row instead of on the field's own label.** Web labels the input
   `Total Testosterone (ng/dL)` / `(nmol/L)`, changing with the chips above it, and the SHBG field
   `SHBG (nmol/L)`. iOS shows `Total testosterone` with no unit, then a separate `TT unit` picker
   row beneath it. **Why that matters more here than usual:** a number field with no unit on it, on
   a screen where the unit is the thing that goes wrong (#1).
   **Done when:** the field label carries the live unit.

9. **iOS shows a third row the web does not:** `TT (nmol/L)` — the converted value. Defensible (it
   is the number the formula actually used, and it would make #1 visible), but it is a difference
   and it is recorded rather than absorbed.
   **Done when:** the row is either justified here or removed.

10. **Web-only, recorded so it is not silently dropped:** the four-question FAQ (parked with T-13)
    and the same embed builder as BMI (**cannot exist on iOS** — see T-01b-v #11). The frame's
    `Add` button carries the same disabled-commit question as T-01b-v #10.

**Not a difference on this screen but found while reading it, and it belongs in T-01b's "screens
iOS has no version of at all":** the web has a **second, more accurate** free-testosterone
calculator — `FreeTestVermeulenPage` (`ftv`), the Vermeulen 1999 equation solving for free and
bioavailable T from total T, SHBG and albumin. Its own copy says the FAI tool "is only a ratio
proxy" and is "more accurate than the Free Androgen Index". iOS ships the proxy and not the
calculation. That is a missing feature, not a layout difference, and it should be filed as one.

---

## What this batch did not settle

- **X-2 (live vs gated result) and T-01b-iv #8 are the same question** and should be answered once,
  by the owner, for all fifteen calculators plus the plotter.
- **The plotter's maths findings (#1–#4) are conformance failures against a spec the web ships**
  (`spec/math-spec.md`, `spec/verify-vectors.mjs`, 10 corpora / 272 cases). Nothing in this repo runs
  them — `git ls-files` returns no vector file. Wiring `spec/vectors/*.json` into the unit target is
  the mechanism that would have caught all four before a frame was ever taken, and it is worth its
  own task.
- **BMI and Free-T Index cannot be photographed** while `isListed` is false, so their chrome cannot
  be closed by capture. Either the withdrawal gets a capture-only escape hatch, or those two screens
  stay unverifiable.

---

# T-01b — the seven GLP-1 / peptide / HCG calculators, compared 2026-08-04

**Listing pass only. Nothing here is built.** Method and ordering of truth per T-01; output shape per
T-01a.

**iOS frames:** `docs/ui-audit/2026-08-04-post-t01a/` — `16-calculator-hcg`, `17-calculator-peptide`,
`19-calculator-semaglutide`, `20-calculator-tirzepatide`, `21-calculator-retatrutide`,
`22-calculator-bpc157`, `23-calculator-bpc157blend`. Default type size, sweep at `1788646`.

**Web read from the source, not the captures.** `~/injectbuddy` at `6a37ce2` on
`feature/dosage-status-model` (fetched 2026-08-04) — `public/app.js` symbols `HCGPage`,
`PeptidePage`, `SemaglutidePage`, `TirzepatidePage`, `RetatrutidePage`, `BPC157Page`,
`BPC157BlendPage`, plus the shared constants block (`SEMA_DOSE_VALUES` … `TB_DOSE_VALUES`),
`QuickPickerField`, `PeptideSwitcher` / `PEPTIDE_SWITCHER_CURRENT`, `IB_CALC_FORMULA`,
`getVolumeMeta`, and `lib/account-schedule.ts` `deriveDose`. iOS side:
`Core/Calculator/CalculatorCatalog.swift` (`spec(for:)`, `configExtras(for:values:)`) and
`Core/Calculator/CalculatorEvaluate.swift` (`evaluate(slug:values:scale:)`).

**Two corrections to comments already in the iOS tree, both found by reading the branch source.**
`CalculatorCatalog.configExtras` states, for `.hcg`, *"The web's HCG rows carry ONLY
bacWaterMl/dose/syringeMl/vialIU — no mode, nDays or injPerWeek"*, and for `.tirzepatide,
.retatrutide`, *"tirzepatide and retatrutide rows carry only conc/dose/syringeMl"*. **Both are false
against the source on `feature/dosage-status-model` AND against `master`** — `HCGPage.handleSave`
writes `{vialIU, bacWaterMl, dose, syringeMl, mode, nDays, injPerWeek}`, and all three GLP-1 pages
write `{conc, dose, syringeMl, mode, nDays, injPerWeek}`. Both comments say they were verified
against the live table; live rows predate the branch, which is exactly the failure T-01 warns about —
a document (or a row) about the source read in place of the source. See H-1, S-2, T-2, R-2 below.

---

## Shared across all seven — listed once, counts against every screen

These are the same defect on seven screens. Numbered `SH-n` so a screen's own list stays about that
screen. **None of these is a re-report of the T-01a chrome** — in each case the component T-01a built
exists and ships; what is missing is this calculator's data for it.

**SH-1 · The tick drum has no value array on any of these fourteen numeric fields, so they render as
bare wells.** `TickDrum` ships and is visible on the TRT frame. But `drum:` is passed **only** on
`.trt`'s four fields in `CalculatorCatalog.spec(for:)`; every field on these seven slugs omits it.
Frames `16`, `17`, `22`, `23` show a label and a value well with no ruler beside it. The web passes
`drumValues` on every one of these fields — `HCG_VIAL_IU_VALUES`, `BAC_WATER_VALUES`,
`HCG_DOSE_VALUES`, `PEPTIDE_BAC_WATER_VALUES`, `PEPTIDE_INJ_WEEK_VALUES`, `VIAL_PEP_MG_VALUES`,
`DOSE_PEP_MCG_VALUES`, `SEMA_/TIRZ_/RETA_DOSE_VALUES`, `GLP1_CONC_VALUES`, `BPC157_DOSE_VALUES`,
`BPC_BLEND_DOSE_VALUES`, `TB_DOSE_VALUES`, `TRT_INJ_WEEK_VALUES`. The arrays are transcribable
verbatim; this is a data gap, not a control gap.

**SH-2 · No syringe drawing.** Every one of these web pages renders `VisualSyringePanel` /
`HorizSyringe` — a to-scale barrel filled to the computed draw, against the selected barrel size.
`grep -rn "HorizSyringe\|VisualSyringe" Sources/` returns nothing. On a screen whose output is
"draw this much", the picture is the check that the number is plausible; iOS gives the number alone.

**SH-3 · The volume-quality verdict loses its colour and its remedy.**
`CalculatorEngine.volumeMeta` reproduces the web's seven bands exactly (checked term by term against
`getVolumeMeta`) but returns a bare `String`. The web returns `{label, color, hint}` and renders the
hint: `< 0.01 mL` → *"Try increasing BAC water, or reducing injections per week."*, `> 3 mL` →
*"Consider a more concentrated mix."* iOS shows the label only, so the two bands that tell the user
what to *do* say only that something is wrong.

**SH-4 · No peptide-type switcher on five of the seven.** `TwoColCalcPage` (app.js, the `leftCol`
branch on `PEPTIDE_SWITCHER_CURRENT`) puts a `PeptideSwitcher` combobox — 22 peptides, searchable —
at the top of the left column of `bpc157`, `bpc157blend`, `semaglutide`, `tirzepatide` and
`retatrutide`. It is visible in `33-calc-semaglutide-empty.png` as the `PEPTIDE TYPE` field reading
"Semaglutide". iOS has no equivalent on any calculator: there is no way to move between peptide
calculators except back out to Tools. `CompoundCombobox` already exists and is the right control.

**SH-5 · Every field on these seven opens pre-filled; the web opens blank.** Every `useState` on
these seven pages is `0` (or `5` for BPC vial, `5000` for blend vials), and the pages gate on
`glow.gate([...])` so `Show result` refuses and highlights the empty field. iOS seeds
`CalculatorValues.defaults(for:)` from the spec — HCG opens at `5000 IU / 1 mL / 250 IU`, Semaglutide
at `5 mg/mL / 0.5 mg`. **Not cosmetic:** a pre-filled dosing form invites `Show result` → `Add` on
numbers nobody entered, and the saved protocol is then a plausible fiction. It is also why the
"empty" reference captures and the iOS frames cannot be laid over each other at all.

**SH-6 · The result never states the concentration it divided by.** Every web page carries the
concentration as a live result metric (`HeroCyclePanel` metrics: HCG `Concentration IU/mL`, GLP-1
`Concentration mg/mL`, BPC-157 `Mix Strength mcg/mL`) or as inline text under the water field (HCG,
blend). iOS renders it on HCG and peptide only. The concentration is the one input the user did not
type and cannot check by re-reading the form.

---

## T-01b-1 — HCG · frame `16-calculator-hcg.png` — **9 differences**

Web: `app.js` `HCGPage`. Refs `screens/31-calc-hcg-{empty,result}.png`.

**Functional — arithmetic and saved data:**

1. **The dosing mode, and the two fields under it, do not exist on iOS — and three config keys go
   missing with them.** `HCGPage` renders a two-way `ModeTab` (`Every N Days` · `Per Week`) and then
   either `EveryNDaysField` or an `Injections per week` field (1–7, step 0.5), and
   `HCGPage.handleSave` writes `config = {vialIU, bacWaterMl, dose, syringeMl, mode, nDays,
   injPerWeek}` — **seven keys**. `CalculatorCatalog.spec(for: .hcg)` has four fields and
   `configExtras(for: .hcg)` returns `[:]`, so iOS writes **four**. Visible in
   `31-calc-hcg-result.png`: the mode tabs sit between `DOSE PER INJECTION` and `SYRINGE SIZE`, with
   `INJECTIONS PER WEEK 2` under them. **Why it is the worst thing on this screen:** the unique index
   is `(user_id, calculator_type, config)` over the whole jsonb, so a four-key iOS HCG row can never
   equal the seven-key web row for the same protocol — the same HCG protocol saved on both platforms
   is two rows, permanently. And `HCGPage.loadDosage` reads `cfg.mode`/`cfg.nDays`/`cfg.injPerWeek`,
   so an iOS-saved HCG row reopens on the web at its defaults (`perweek`, 2×/week) regardless of what
   the user intended. The mode does **not** change the draw volume — `deriveDose`'s hcg branch
   hardcodes `freqDays: 3.5` and ignores all three keys — so this is a fingerprint and round-trip
   defect, not a wrong dose.
2. **The two guard-rails on this screen are absent.** `HCGPage` renders an orange `InfoBox` when
   `dose > vialIU` (*"Dose exceeds total vial content of N IU — verify your inputs."*) and another
   when `isValid && drawMl < 0.01` (*"Draw is less than 1 unit — add more BAC water to lower the
   concentration."*). iOS renders neither. The first catches the commonest HCG input error — reading
   the vial's total IU into the per-shot dose field — and with iOS's dose field accepting up to 5000
   IU against a vial field defaulting to 5000, it is one keystroke away.
3. **The input ranges are wider than the web's on every field, in the direction that lets a wrong
   number through.** Web `vialIU` 1000–15000 step 500 · iOS `0…20000` step 1 (spec line
   `.number("vialIU", "Vial size", … range: 0...20000, step: 100)`). Web `bacWaterMl` 0.5–10 step 0.5
   · iOS `0…10` step 0.5 — but iOS permits **0**, and `hcg()` returns `concentration = 0` for it,
   which the web's `min: 0.5` makes unreachable. Web `dose` 100–5000 step 50 · iOS `0…5000`. A range
   that accepts a value the web forbids is a range that produces a result the web would not.

**The maths itself is correct.** `CalculatorEngine.hcg` reproduces `HCGPage` line for line —
`concentration = vialIU / bacWaterMl`, `drawMl = dose / concentration`, `units =
Math.round(drawMl * 100)`, `dosesPerVial = Math.floor(vialIU / dose)`. Checked term by term. Only
`isValid` differs: web requires `concentration > 0 && dose > 0 && isFinite(drawMl) && drawMl > 0`,
iOS requires `drawMl > 0`, which implies the first two and excludes NaN. No behavioural difference.

**Visual and content:**

4. **No formula card on this screen, though the web has one and iOS has the component.**
   `IB_CALC_FORMULA.hcg` is `units = (dose ÷ concentration) × 100` with three legend terms
   (`concentration` = total IU ÷ bacteriostatic water (mL); `dose` = your per-shot dose (IU); `× 100`
   = converts mL to U-100 insulin-syringe units). It is the last card in
   `31-calc-hcg-result.png`. `CalcFormulaCatalog.formula(for:)` has no `.hcg` case and falls to
   `default: return nil`. The file's own comment says the remaining slugs are "covered by T-01b's
   per-screen comparisons" — this is that comparison, and the text above is the transcription.
5. **`Draw` is shown to 3 decimals where the web shows 4.** `evaluate`'s `.hcg` branch:
   `fmt(r.drawMl, 3)`. The web's metric is `{label: 'Draw Volume', value: drawMl, decimals: 4}`. At
   HCG concentrations a 4th decimal is a real unit — 0.0250 mL is 2.5 u.
6. **Two field labels differ from the web's.** Web `Vial Strength` / `BAC Water Added`; iOS
   `VIAL SIZE` / `BAC WATER`. "Vial size" reads as a volume on a screen where every other number is a
   volume; the web says strength because the field is IU.
7. **iOS adds a quick-chip row the web does not have here.** The frame shows
   `250 · 500 · 1000 · 1500 · 2000` chips under `DOSE PER INJECTION`, from the spec's
   `quick: [250, 500, 1000, 1500, 2000]`. `HCGPage`'s dose field is a `SliderField` with a drum and no
   preset chips. Worth keeping, probably — but it is a difference, and it occupies the row where the
   drum belongs (SH-1).
8. **No FAQ.** Five questions on the web — what HCG is and why it is used on TRT, how to reconstitute
   it, typical dose, vial shelf life, which syringe. Two of them carry inline guide links. Same class
   as T-01a #5 / T-13.
9. **No related calculators and no cross-link.** The web ends with `relatedFor('hcg')` — TRT, EOD,
   Microdose, Female HRT, E2 Estimator, Free T, FTV — and a standalone link *"Using HCG alongside
   Testosterone (TRT)? Calculate your testosterone dose →"*. Same class as T-01a #6 / T-13.

**Done when:** each of the nine, plus SH-1…SH-6, is built or recorded here with the reason it cannot
be. #1 is the one that must be measured rather than asserted — a save from the device, SELECTed back,
showing seven keys with the chosen `mode`, in the shape T-15 uses for TRT.

---

## T-01b-2 — Peptide · frame `17-calculator-peptide.png` — **8 differences**

Web: `app.js` `PeptidePage`. Refs `screens/32-calc-peptide-{empty,result}.png`.

**Functional — the first one is a dosing hazard:**

1. **Changing the dose unit does not convert the dose, so mcg → mg multiplies the entered dose by
   1000 and iOS calculates for it.** `PeptidePage.handleUnitToggle` converts on every flip —
   `newUnit === 'mg' ? Number((dosePerInj / 1000).toFixed(3)) : Number((dosePerInj * 1000).toFixed(0))`
   — and re-bounds the field (`doseMin/doseMax/doseStep/doseDp` are all derived from `doseUnit`:
   1–20000 step 1 in mcg, 0.001–20 step 0.001 in mg). iOS has **no conversion anywhere**:
   `grep -rn "doseUnitMcg" Sources/` returns six hits, all of them reads —
   `configExtras`, `values(fromConfig:)`, the spec, and `evaluate`. `dosePerInj` is a single
   `.number("dosePerInj", … default: 500, range: 0...10000, step: 50)` whose range and step never
   move. So a user sitting on the default 500 mcg who taps the `DOSE UNIT` menu (visible in the
   frame, second-from-bottom) to `mg` now has **500 mg per injection**, and
   `CalculatorEngine.peptide` computes `dosePerInjMg = 500`, a draw of 100 mL, and offers `Add`. The
   quick chips make it worse: in mg mode they read `250 · 500 · 750 · 1000 · 2000`, i.e. five
   one-tap doses between 250 mg and 2 g of a peptide. **This is the highest-severity finding in this
   batch** — it is the only place where iOS silently reinterprets a number the user already entered.
2. **The peptide type field does not exist, and it is the web's first required input.**
   `PeptidePage` leads with an `EsterCombobox` over 22 peptides, and `glow.gate` lists
   `{key: 'type', ok: !!peptideType}` **first** — the web refuses to calculate without it. It is
   saved (`config.peptideType`) and it colours the syringe (`PEPTIDE_TYPE_COLORS[peptideType]`).
   iOS has no field; `configExtras(for: .peptide)` hardcodes `"peptideType": .string("")` with the
   comment *"`""` is the truthful answer: nothing was chosen"*. So **every peptide protocol iOS has
   ever saved is untyped** — the dashboard card, the log-dose list and the plotter all get a peptide
   with no name. Note this also means the key set matches (7 keys both sides), so the fingerprint is
   fine; what is missing is the value.
3. **Picking a peptide that has its own calculator does nothing on iOS; the web routes you there.**
   `PeptidePage`'s combobox `onChange` calls `setPage(dedicated[val])` for BPC-157, Semaglutide,
   Tirzepatide and Retatrutide, and for the three GLP-1s also renders a banner — *"X has a dedicated
   calculator → Open X Calculator"* — that carries the current concentration, dose and barrel over via
   `window.__glp1Preset`. Downstream of #2, so it cannot exist until the type field does; recorded
   now so building #2 alone does not read as closing this.
4. **Three input ranges disagree with the web, two of them by capping below what the web allows.**
   `peptideMg`: web `VIAL_PEP_MG_VALUES` = 5…500 step 5 with an mg/mcg unit toggle on the field;
   iOS `0…100` step 1, no toggle — **a 200 mg vial cannot be entered**. `injPerWeek`: web
   `PEPTIDE_INJ_WEEK_VALUES` = 1…28; iOS `1…14` — twice-daily protocols (a normal BPC/ipamorelin
   cadence) cannot be expressed. `bawMl`: web 0.5–10 step 0.5; iOS `0…30` — iOS permits 0, which
   `peptide()` turns into `concentration = 0`, and permits 30 mL into a vial the web caps at 10.
5. **The save gate the web added deliberately is absent.** `PeptidePage.handleSave` refuses with
   *"Add injections per week to save"* when `injPerWeek` is not `> 0`, and its comment explains why:
   `/api/dosages` `validProtocol` requires it, so without the gate the save 400'd and the user got
   *"Save failed — try again"* forever. iOS writes to PostgREST directly and bypasses that route
   entirely (see the `/api/dosages` note in `CalculatorCatalog`'s cross-platform header), so iOS can
   write a peptide row the web's own API would have rejected. Its spec default is `1`, so it will
   rarely be 0 — but nothing stops it.

**The maths is correct.** `CalculatorEngine.peptide` matches `PeptidePage` term for term:
`dosePerInjMg`, `concentration = peptideMg / bawMl`, `mlPerInj`, `unitsPerInj = mlPerInj * 100`,
`weeklyTotalMg`, `totalDoses`, `vialDays = totalDoses / (injPerWeek / 7)`, `vialWeeks`. Checked.

**Visual and content:**

6. **The unit toggle is a separate full-width row on iOS and an in-field control on the web.** Web:
   `DrumUnitToggle` passed as `extra` **inside** the `Dose per injection` `QuickPickerField`, so the
   unit sits with the number it governs — and the same pattern on `Peptide in vial` (`pepUnit`,
   which iOS does not have at all, see #4). iOS: a standalone `DOSE UNIT` menu picker two rows
   below the value, which the frame shows as a white bordered box reading `mcg ⌄`. This is not only
   layout — the separation is what makes #1 easy to trip.
7. **Precision and row set differ.** Web hero metrics: `Draw Volume` 4 dp, `Units` 1 dp, `Dose` in
   the chosen unit. iOS: `Draw per injection` 3 dp, `Units (U-100)` via `fmtInt` (0 dp),
   `Concentration`, `Weekly total`, `Total doses in vial`, and a `Vial lasts ~N weeks` line. iOS
   shows **more** rows here than the web, which is not a defect — but the two shared numbers are both
   coarser than the web's, on the calculator with the smallest draw volumes in the app.
8. **No FAQ (four items), and no "Ready to calculate your dose? → Head to the BPC-157 Peptide
   Calculator" card**, which the web shows in the result column once a result exists. Same class as
   T-01a #5/#6 and T-13.

**Done when:** each of the eight, plus SH-1…SH-6, is built or recorded with the reason. **#1 first
and separately** — it is a live wrong-dose path on a shipping screen, and it does not need the rest
of this list to be fixed.

---

## T-01b-3 — Semaglutide · frame `19-calculator-semaglutide.png` — **6 differences**

Web: `app.js` `SemaglutidePage`. Refs `screens/33-calc-semaglutide-{empty,result}.png`.

**Functional:**

1. **The concentration list stops at 20 mg/mL where the web's stops at 60, and iOS has no way to
   enter a value that is not on the list.** `GLP1_CONC_VALUES` (app.js constants block) is
   `[0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60]` — seventeen values.
   `CalcConst.glp1Concs` is the first **twelve** of them. Worse, the web's control is a
   `QuickPickerField`, which has an editable draft input clamped to `[values[0], values[last]]` —
   so the web accepts *any* concentration up to 60, typed. iOS's is `.picker(…)`, a closed SwiftUI
   `Menu` (the frame shows `5 ⌄`), so twelve values is the complete set of concentrations the app can
   express. **Why this is the second-worst thing in the batch:** a user with a 25 mg/mL compounded
   vial has no correct option. The nearest is 20, and `glp1(conc: 20, dose: d)` returns a draw
   **25 % larger than the true one** — a 0.5 mg dose reads 0.025 mL / 3 u instead of 0.020 mL / 2 u.
   The screen would look entirely normal while over-drawing. The web's own FAQ on this page names
   this exact failure: *"Selecting the wrong concentration is the most common dosing error — it can
   mean you draw two or three times the intended dose."*
2. **The dose list stops at 2.4 mg where the web's stops at 7.5 — and the warning that used to guard
   2.4 is gone with it.** `SEMA_DOSE_VALUES` has 22 entries to 7.5; `CalcConst.semaDoses` has the
   first 11, ending exactly at 2.4. The web pairs the wider list with a guard —
   `isValid && dose > 2.4` renders *"Exceeds typical weekly maximum of 2.4 mg — verify with your
   prescriber."* iOS truncates the list at the threshold instead, which silently removes both the
   dose and the sentence explaining why it needs care. A user prescribed above the Wegovy ceiling is
   told nothing; they simply cannot enter it.
3. **Neither of the two `InfoBox` warnings exists.** The over-maximum one (#2) and
   `isValid && volumeMl < 0.01` → *"Draw is less than 1 unit — accuracy may be limited at this
   scale."* iOS renders no warning of any kind on this screen.

**The maths is correct.** `CalculatorEngine.glp1` is `dose / conc` with `units = round(volumeMl*100)`,
identical to `SemaglutidePage`'s `volumeMl` / `units`. Checked. **The config is correct too**, and it
is the only one of the three GLP-1 slugs that is: `configExtras(for: .semaglutide)` emits
`mode: "perweek"`, `nDays: 7`, `injPerWeek: 1`, matching `SemaglutidePage`'s `useState` defaults and
its six-key `config`. Recorded because it is the counter-example that makes T-2 and R-2 below
obviously wrong rather than arguably wrong.

**Visual and content:**

4. **No mode switcher instance, so the three keys are written blind.** `SemaglutidePage` renders a
   two-way `ModeTab` and then `EveryNDaysField` or an `Injections per week` field. iOS renders
   neither — it writes `perweek / 7 / 1` as extras. The values are right for an untouched web save,
   so the fingerprint holds; what is missing is the user's ability to say otherwise. Visible in the
   reference capture between `DOSE` and `SYRINGE SIZE`. (`ModeTab` ships — this is a missing instance,
   not a missing control.)
5. **The result omits the concentration row and rounds the draw differently.** Web metrics:
   `Draw Volume` 2 dp, `Units` 0 dp, `Concentration` 1 dp mg/mL. iOS: `Draw` 3 dp and
   `Units (U-100)` only. The concentration row is the readback of #1 — the one place the chosen
   concentration is restated next to the number it produced.
6. **No FAQ (four items, including the concentration-error one quoted in #1), no related-calculator
   carousel, no "Read the full Semaglutide Dosing Guide →" link, and no disclaimer.** The web's
   `DisclaimerBox` on this page states the assumption the whole result rests on: *"Assumes U-100
   insulin syringe (1 unit = 0.01 mL)."* iOS prints `Units (U-100)` as a row label and states the
   assumption nowhere.

**Done when:** each of the six, plus SH-1…SH-6, is built or recorded with the reason. #1 and #2 are
one change — replace the truncated `CalcConst` arrays with the web's full ones and give the field a
typed entry path — and it is the change to make first.

**#1, #2 and #3 are CLOSED — T-45.** All four arrays restored and pinned to the web's literals;
`conc`/`dose` moved from a closed `Menu` to a typed `.number` field clamped to the arrays' bounds
with the full array as the ruler; both `InfoBox` warnings ported verbatim. The counts were verified
on both sides before acting and T-01b-3's figures are correct to the value. #4, #5 and #6 remain
open. Evidence in `TASKS.md` T-45.

---

## T-01b-4 — Tirzepatide · frame `20-calculator-tirzepatide.png` — **6 differences**

Web: `app.js` `TirzepatidePage`. Refs `screens/34-calc-tirzepatide-{empty,result}.png`.

The page is Semaglutide's with three constants changed, and iOS's spec is likewise — so **#1, #3, #5
and #6 of the Semaglutide list apply here unchanged and are not restated**. What is different on this
screen:

**Functional:**

1. **The dose list stops at 15 mg where the web's stops at 40.** `TIRZ_DOSE_VALUES` is
   `[0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5, 35, 37.5, 40]` — seventeen
   values; `CalcConst.tirzDoses` is the first **seven**, ending exactly at the web's warning
   threshold (`isValid && dose > 15` → *"Exceeds typical weekly maximum of 15 mg — verify with your
   prescriber."*). Same shape as Semaglutide #2, and with the same effect: the ceiling is enforced by
   removing the option instead of by warning about it.
2. **Three config keys are missing, and the comment in the iOS tree that justifies their absence is
   wrong.** `TirzepatidePage.handleSave` writes `config = {conc, dose, syringeMl, mode, nDays,
   injPerWeek}` — **six keys**, identical to Semaglutide's, on this branch *and* on `master`
   (`git show master:public/app.js`, the three `const config = {conc, dose, syringeMl, mode, nDays,
   injPerWeek}` sites). `configExtras(for: .tirzepatide, .retatrutide)` returns `[:]`, so iOS writes
   **three**. The comment above that case reads *"Semaglutide rows carry the mode pair; tirzepatide
   and retatrutide rows carry only conc/dose/syringeMl. Grouping them in one case is what made two of
   the three mismatch"* — it has the grouping exactly inverted: **all three share a config shape, and
   splitting them is what made two of the three mismatch.** Consequence: every iOS tirzepatide row is
   a different fingerprint from the equivalent web row, so the same protocol saved on both platforms
   exists twice; and `TirzepatidePage.loadDosage` reads `cfg.mode` / `cfg.nDays` / `cfg.injPerWeek`,
   so an iOS row reopens on the web at `perweek` / 7 / 1 whatever the user chose. It does **not**
   change the schedule — `deriveDose`'s GLP-1 branch hardcodes `freqDays: 7` and reads only
   `dose`, `conc` and `syringeMl`.
3. **The dose default is 5 mg where the web opens blank and its titration starts at 2.5.** Beyond
   SH-5, this one names a specific number: `.picker("dose", … default: 5)` is step two of the
   SURMOUNT ladder, not step one. A user who accepts the pre-filled form saves a second-step dose.

**The maths is correct** — the same `CalculatorEngine.glp1` as Semaglutide, and `TirzepatidePage`
computes `volumeMl = dose / conc` identically.

**Visual and content:**

4. **No mode switcher instance** — as Semaglutide #4, but here the fields are not merely uncontrolled,
   they are unwritten (see #2).
5. **The FAQ is different from Semaglutide's and equally absent** — three items, one of which
   (*"How is tirzepatide different from semaglutide?"*) is the reason a user opens this page rather
   than that one. Plus `relatedFor('tirzepatide')` and *"Read the full Tirzepatide Dosing Guide →"*.
6. **No formula card content check needed — it is shared with Semaglutide and already ships.**
   `CalcFormulaCatalog` covers `.semaglutide, .tirzepatide, .retatrutide` in one case with
   `glp1Legend`, transcribed correctly from `IB_CALC_FORMULA.retatrutide`/`.semaglutide`. Stated
   explicitly so a future reader does not re-open it: **this one is right.**

**Done when:** each of the six, plus SH-1…SH-6 and Semaglutide #1/#3/#5/#6, is built or recorded.
**#2 must be closed with a row, not a diff** — save a tirzepatide protocol from the device and
SELECT it back showing six keys.

**#1 is CLOSED — T-45**, with Semaglutide #1 and #3 which it inherits. `TIRZ_DOSE_VALUES` restored
to all 17 values and the 15 mg warning ported, so the ceiling is now flagged rather than deleted.
**#2 is STILL OPEN and is unchanged by T-45** — the three keys are deliberately not added, because
re-fingerprinting every future tirzepatide save is a migration question about rows that already
exist, not a side effect of an option-list fix. **The wrong comment that #2 calls out IS corrected**
in `CalculatorCatalog.configExtras`: all three pages write the same six keys, so splitting them is
what caused the mismatch, exactly as #2 says.

---

## T-01b-5 — Retatrutide · frame `21-calculator-retatrutide.png` — **5 differences**

Web: `app.js` `RetatrutidePage`. Refs `screens/35-calc-retatrutide-{empty,result}.png`.

Again the same page with different constants. **Semaglutide #1, #3, #5, #6 and Tirzepatide #4 apply
unchanged.** Specific to this screen:

**Functional:**

1. **The dose list stops at 12 mg where the web's stops at 24.** `RETA_DOSE_VALUES` is
   `[0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24]` — 22 values;
   `CalcConst.retaDoses` is the first **sixteen**, ending at the web's warning threshold
   (`isValid && dose > 12` → *"Exceeds typical weekly maximum of 12 mg — verify with your
   prescriber."*). Retatrutide is the third-largest protocol group in production (10 users), and it
   is the compound with the least settled dosing, so the truncated ceiling bites hardest here.
2. **The same three missing config keys as Tirzepatide, from the same `case` in
   `configExtras`** — `RetatrutidePage.handleSave` writes six keys, iOS writes three. Everything in
   Tirzepatide #2 applies verbatim; recorded separately because it is a separate `calculator_type`
   and will need its own row to close.

**The maths is correct** — the same `glp1` division.

**Visual and content:**

3. **No mode switcher instance.** As above.
4. **No FAQ.** `RetatrutidePage`'s FAQ items and `relatedFor('retatrutide')`, plus the guide link.
5. **The `conc` default is 5 and the `dose` default is 1.** Same class as SH-5; named here because
   1 mg is a real starting retatrutide dose, so the pre-filled form is *plausible enough to save*,
   which is the property that makes SH-5 dangerous rather than untidy.

**Done when:** each of the five, plus the shared and inherited items, is built or recorded.

**#1 is CLOSED — T-45.** `RETA_DOSE_VALUES` restored to all 22 values and the 12 mg warning ported.
**#2 is STILL OPEN**, for the reason given under Tirzepatide #2.

---

## T-01b-6 — BPC-157 · frame `22-calculator-bpc157.png` — **6 differences**

Web: `app.js` `BPC157Page`. Refs `screens/36-calc-bpc157-{empty,result}.png`.

**The maths is correct, and it is worth showing because the two sides derive it differently.** Web:
`concMgMl = vialMg / bawMl`, `doseMg = dose / 1000`, `drawMl = doseMg / concMgMl`. iOS
(`evaluate`, `.bpc157`): `conc = vialMg * 1000 / bawMl` (mcg/mL), then `bpc157(concMcgMl: conc, dose:)`
→ `dose / conc`. Both reduce to `dose × bawMl ÷ (1000 × vialMg)`. Identical. **The config shape
matches too** — web `{vialMg, bawMl, dose, syringeMl}`, iOS the same four keys with no extras.

**Functional:**

1. **The vial field has no mg/mcg toggle and caps at 100 mg where the web caps at 500.** Web:
   a `QuickPickerField` over `VIAL_PEP_MG_VALUES` (5…500 step 5) with a `DrumUnitToggle`
   (`vialUnit`, bounds `1…500 mg` or `1…500000 mcg`) — so a vial labelled "10000 mcg" is entered as
   printed. iOS: `.number("vialMg", "Vial size", unit: "mg", default: 5, range: 0...100, step: 1)`,
   mg only. A user reading `5000 mcg` off the label has to divide before typing, on a screen whose
   dose field is already in mcg — two units, one of them silently converted by the user.
2. **The over-vial warning is absent.** `dose > vialMg * 1000` renders *"Dose exceeds total vial
   content of N mg — verify your inputs."* iOS has no equivalent, and its dose field accepts up to
   5000 mcg against a default 5 mg vial — exactly the boundary the warning guards.
3. **The small-draw warning is absent.** `isValid && drawMl < 0.01` → *"Draw is less than 1 unit —
   consider adding more BAC water or reducing the dose."* This is the operative advice on BPC-157,
   whose typical 250 mcg dose out of a concentrated vial lands near the measurable floor. See SH-3:
   iOS has the band and drops the sentence.
4. **`bawMl` accepts 0 and up to 30 mL** where the web's slider is `min: 0.5, max: 10`. A 0 makes
   `conc` 0; the iOS evaluate guards with `bawMl > 0 ? … : 0`, so it renders no result rather than a
   wrong one — but the field should not offer it.

**Visual and content:**

5. **No formula card, though the web has one and it is the one this screen most needs.**
   `IB_CALC_FORMULA.bpc157` is `units = (dose ÷ mix concentration) × 100`, legend: `mix
   concentration` — peptide amount ÷ bacteriostatic water (mL); `dose` — your per-shot dose (same
   unit as the mix); `× 100` — converts mL to U-100 insulin-syringe units. `CalcFormulaCatalog` has
   no `.bpc157` case. "Same unit as the mix" is precisely the trap in #1.
6. **The result omits `Mix Strength`, and rounds `Draw` to 3 dp where the web uses 2.** Web metrics:
   `Draw Volume` 2 dp, `Units` 0 dp, `Mix Strength` mcg/mL 0 dp. iOS: `Draw` 3 dp and
   `Units (U-100)`. The mix strength is the derived number the whole screen turns on and iOS never
   shows it — the SH-6 case where it costs the most. **Also missing:** the cross-link *"Working with
   a different peptide? Use the Peptide Reconstitution Calculator →"*, the four-item FAQ,
   `relatedFor('bpc157')` and the BPC-157 guide link.

**One web-side defect found while reading this screen, filed as a finding rather than a difference —
it affects the web and iOS equally.** `lib/account-schedule.ts` `deriveDose`'s `bpc157` branch reads
`cfg.concMcgMl` and `cfg.vialMcg` — the **legacy** config shape that `BPC157Page.loadDosage` still
back-converts from. Neither the current web page nor iOS writes those keys any more (both write
`{vialMg, bawMl, dose, syringeMl}`), so `vol` is `null` for **every BPC-157 protocol saved by either
platform since the page changed** — no draw volume on the dashboard, and `dosesLeft` / `daysOfSupply`
return 0 because they divide by it. Same shape as T-06: a real row the schedule engine cannot read.
Needs its own task with `win` as owner (4 production users on `bpc157`).

**Done when:** each of the six, plus SH-1…SH-6, is built or recorded, and the `deriveDose` finding
above is filed as its own task.

---

## T-01b-7 — BPC-157 + TB-500 blend · frame `23-calculator-bpc157blend.png` — **6 differences**

Web: `app.js` `BPC157BlendPage`. Refs `screens/37-calc-bpc157blend-{empty,result}.png`.

**The per-component maths is correct and the config shape matches** — web `{bpcVial, bpcWater,
bpcDose, tbVial, tbWater, tbDose, syringeMl}`, iOS the same seven keys with no extras;
`CalculatorEngine.blend` reproduces `bpcConc`/`tbConc`/`bpcDraw`/`tbDraw`/`totalMl` and rounds each
component's units before summing, exactly as the page does.

**Functional:**

1. **`isValid` differs, and iOS shows a "total" for half a blend.** Web: `isValid = bpcValid &&
   tbValid` — both components must be complete or the page shows no result. iOS
   (`evaluate`, `.bpc157blend`): `isValid: r.isValid`, and `blend()` sets that to `totalMl > 0`. So
   with TB-500 left at a 0 dose (or 0 water) iOS renders a valid-looking card headed
   `Total draw 0.083 mL` — which is the BPC-157 draw alone — with `TB-500 draw 0.000 mL · 0 u`
   underneath. On a screen whose entire purpose is *what goes in the one syringe*, a total that
   silently excludes a component is a wrong total, not a partial one. **This is the only genuine
   arithmetic-behaviour divergence in the batch and it belongs at the top of this screen.**
2. **The TB-500 dose caps at 5000 mcg where the web caps at 10000, and steps by 50 where the web
   steps by 250.** Web: `SliderField {min: 250, max: 10000, step: 250}` over `TB_DOSE_VALUES`
   (250…10000 by 250). iOS: `.number("tbDose", "TB-500 dose", unit: "mcg", default: 2000,
   range: 0...5000, step: 50)`. TB-500 loading protocols run 5–10 mg/week split across doses; the
   upper half of that is unreachable on iOS. Note iOS's BPC-157 dose field (`0...5000` step 50) does
   match the web's `BPC_BLEND_DOSE_VALUES` range — only TB-500 is short.
3. **The vial sizes are a free number field on iOS and a two-option chip row on the web.** Web:
   `ChipRow` over `VIAL_SIZES = [{label: '5 mg', value: 5000}, {label: '10 mg', value: 10000}]`, in
   **mcg** under an "mg" label, for both peptides. iOS: `.number("bpcVial", "BPC-157 in vial",
   unit: "mcg", default: 5000, range: 0...20000, step: 250)` and the same for `tbVial` — visible in
   the frame as two typed wells reading `5000 mcg`. iOS is the more capable control here, and the
   *values* it produces are in the same unit the web saves, so the config still matches; but a user
   comparing the two screens sees a labelled "5 mg / 10 mg" choice on one and a raw 5000 on the other.
4. **The two live concentration read-outs are absent.** After each water field the web renders an
   accented `InfoBox` — *"BPC-157 concentration: N mcg/mL"* and *"TB-500 concentration: N mcg/mL"* —
   updating as you set the water. iOS shows neither, and neither appears in its result rows either,
   so the two concentrations this screen derives are never stated anywhere. SH-6, doubled.

**Visual and content:**

5. **No section grouping.** The web splits the form with two accented small-caps headers,
   `BPC-157 Vial` and `TB-500 Vial` (`sectionHead` in `BPC157BlendPage`), so the six fields read as
   two vials. The iOS frame shows five identical rows in an unbroken run, distinguished only by a
   `BPC-157` / `TB-500` prefix inside each label — `BPC-157 IN VIAL`, `BPC-157 BAC WATER`,
   `BPC-157 DOSE`, `TB-500 IN VIAL`, `TB-500 BAC WATER`. `CalcSectionHeader` ships (T-01a #10) and
   is used for `SYRINGE BARREL`; this screen needs two more instances.
6. **No formula card, no FAQ, no related calculators, no guide link, no disclaimer.**
   `IB_CALC_FORMULA.bpc157blend` is `per-peptide units = (peptide dose ÷ mix concentration) × 100`,
   legend: `mix concentration` — each peptide's mg ÷ bacteriostatic water (mL); `peptide dose` — your
   per-shot dose for that peptide (same unit as the mix); `× 100` — converts mL to U-100 units.
   `CalcFormulaCatalog` has no `.bpc157blend` case. The web's `DisclaimerBox` here states the thing
   the screen exists to say — *"Draw volumes calculated separately from each vial and combined for
   total syringe fill"* — which is also the sentence that makes #1 obviously wrong.

**Done when:** each of the six, plus SH-1…SH-6, is built or recorded. #1 is a one-line change to
`blend()`'s `isValid` plus a unit test with one component zeroed, and should not wait for the rest.

---

## Counts

| screen | differences | own list | + shared | + inherited |
|---|---|---|---|---|
| HCG | 9 | 9 | SH-1…6 | — |
| Peptide | 8 | 8 | SH-1…6 | — |
| Semaglutide | 6 | 6 | SH-1…6 | — |
| Tirzepatide | 6 | 6 | SH-1…6 | Sema #1, #3, #5, #6 |
| Retatrutide | 5 | 5 | SH-1…6 | Sema #1, #3, #5, #6 · Tirz #4 |
| BPC-157 | 6 | 6 | SH-1…6 | — |
| BPC-157 blend | 6 | 6 | SH-1…6 | — |

**46 screen-specific differences + 6 shared. No screen has zero differences.**

**Three things found here that are not layout and want their own tasks rather than a line in a
difference list:**

- the peptide dose-unit non-conversion (Peptide #1) — a live wrong-dose path;
- `deriveDose`'s `bpc157` branch reading a config shape neither platform writes (BPC-157, filed note)
  — owner `win`, web-side;
- the two wrong comments in `CalculatorCatalog.configExtras` (`.hcg`, `.tirzepatide/.retatrutide`) —
  they will re-justify the same omission the next time somebody reads that file, so they need
  correcting in place per rule 7 even if the keys are not added the same day.
