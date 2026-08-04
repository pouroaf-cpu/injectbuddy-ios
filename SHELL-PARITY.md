# SHELL-PARITY — the five non-calculator screens, iOS against the web

**What this is.** The working comparison behind `TASKS.md` T-01b, for the **shell** half of the
split: dashboard, calendar, tools hub, add/confirm-start, log-dose sheet, settings. The
**calculator** half is mac's (T-01a plus the thirteen calculator screens); nothing here restates it.

**Why it exists as its own file.** T-01a proved that a difference list is only actionable if the
reader can see *what we have now* without going to find it. So every entry below inlines the current
iOS layout and the tokens it uses, and cites the web target by file and line rather than by
screenshot caption. A builder should be able to work from this page alone.

## Sources of truth, in order

1. **The web working tree** — `C:\Users\PFrew\Projects\Injectbuddy`, branch
   `feature/dosage-status-model`. It has **uncommitted edits** to `app.js`, `ib-calc.css` and every
   legacy calculator HTML, so it is ahead of the live site. Outranks everything.
2. **The live site — `https://www.injectbuddy.com`.** Public, no auth, currently serving branch head
   `8a51aa5a`. **Open it rather than reading a capture.** `/trt-calculator/` returns 200 and contains
   `Every N Days` and `Per Week`, which is T-01a difference #1 confirmed against the running app.
   The Vercel preview `injectbuddy-ro1o21wrf-pouroas-projects.vercel.app` is the same build and also
   unauthenticated; prefer the apex domain, it survives redeploys.
   The web repo is `https://github.com/pouroaf-cpu/injectbuddy.git`, branch
   **`feature/dosage-status-model`** — not `main`, which does not contain it.
3. **The reference captures** — `github.com/pouroaf-cpu/injectbuddy-design-refs/screens`, 72 frames
   at mobile width, taken **2026-07-31** from `feature/dosage-status-model`, still unmerged.
   **These are now third-best, not the target.** Two commits landed on the TRT calculator after they
   were taken — `a0b410cc` "shimmer becomes a wayfinder" and `8a51aa5a` "grid-beam wayfinder
   background + transparent field containers" — so anything visual about that screen must be
   re-checked against the live site before it is called done.
4. **The iOS frames** — `docs/ui-audit/2026-08-03-current/`, 20 frames, the newest set. The
   `2026-08-02-current` set is what the entries below were written against.

**The caveat, widened.** TASKS.md says "where a capture and the live site disagree, the live site
wins". It also has to say: **where the captures are silent, the source still rules.** The captures
disagree by omission as often as by contradiction — the TRT EOD finding below was invisible in every
frame and fell out of the source only.

## How the Swift line numbers in this file came about — read once

The three entries below were written on **2026-08-04 from an untracked copy** of the app at
`Projects\injectbuddy-ios`, whose `Sources/` was last written **2026-08-02 07:01** — two days behind
mac's build. That is fixed: Windows now has a real checkout at `Projects\injectbuddy-ios-repo`,
`feature/tabview-shell` at `29a8ede` (T-10).

**What survived the check.** Every *structural* finding stands — they rest on the frames and on the
web source, which is the authoritative half and lives on Windows. Both items originally marked
[confirm on Mac] were **confirmed true on mac's tree**: the unrendered category subtitles, and the
plotter's absence from every category (now T-11).

**What did not.** Some Swift line numbers drifted — `NavItems.swift:138-145` on the old copy is
`listedCases`/`unlistedCases` on mac's. **Cite iOS by symbol name, not by line.** The web source is
cited by line and that is fine; it lives here and is current.

**Where mac and Windows disagree about iOS code, mac wins without arguing it** — mac can see the
checkout building. Where they disagree about the web, Windows wins. Correct this file directly.

---

**A trap in the iOS frames.** In `2026-08-02-current` three shell frames are **misfiled**:
`03-calendar` is the Dashboard, `04-tools` is the Calendar, `05-add` is Tools. `shot()` fired during
the cross-fade after `tab()`, so each landed one screen behind — sharp, well-rendered, and under the
wrong name. Do not cite those three by filename without opening them.

---

## Current iOS tokens, for reference

From `Sources/InjectBuddy/Core/Theme/Theme.swift`. Quoted here so a difference can say "wrong token"
rather than "wrong colour".

| Token | Value | Note |
|---|---|---|
| `accent` | `#0FBCAD` | **fill only** — 2.38:1 on white, illegal as text at any size |
| `accentSoft` | `#EAFAF8` | selected-state fill |
| `navy` | `#001D5C` | second brand colour — icon buttons, section labels, numerals |
| `tealText` | `#0A9D90` | 3.37:1 — legal for large text only (18pt+, or 14pt+ bold) |
| `tealTextStrong` | `#075E56` | 7.65:1 — the only teal legal as body text |
| `canvas` | `#FAFAFB` | page |
| `surface` | `#F8F8FB` | raised tile |
| `fieldBorder` | `#8E8E93` | input boundary; 3.26:1, satisfies WCAG 1.4.11 |
| Spacing | `xs 4 · sm 8 · md 16 · lg 24 · xl 32` | |
| Radius | `card 16 · control 10 · pill 999` | |
| `minTarget` | `44` | HIG floor |

Type: `greeting` 24/heavy/−0.72 tracking · `display` 34/heavy · `eyebrow` 13.5/semibold ·
`cardTitle` 17/bold · `cardMeta` 14/medium · `tabLabel` 13.5/semibold (bold when active).

**Two standing constraints that shape every fix below.** The app is **light-only**
(`UIUserInterfaceStyle: Light` locked in `project.yml`; the dark paths were removed deliberately).
And **no `lineLimit` on a value+unit pair or a screen title** — units vanishing at accessibility
sizes was the worst finding of the whole audit.

---

## S-01 — Dashboard (compared 2026-08-04) — **9 differences**

Frames: iOS `2026-08-02-current/02-dashboard-IB2245754.png` · web
`screens/01-dashboard-populated.png`.
Web source: `app/account/page.tsx:78-97` (the `upcoming` panel),
`components/account/dashboard/DashTabs.tsx`.

### What we have now

`Sources/InjectBuddy/Features/Dashboard/DashboardScreen.swift:59-103`, a plain `ScrollView` over a
`VStack(alignment: .leading, spacing: Theme.Spacing.xl)` padded `Theme.Spacing.md`:

```
greeting                                 GreetingHeadline(prefix:name:)
NextDoseCard          (if data.nextDose) "Next dose" · 0mg/wk · Testosterone Cypionate
                                         · "0mg · due today" · navy "Mark taken" button
section("This cycle") (if data.cycle)    CycleTimelineStrip
section("Protocols", trailing: + Add)    ProtocolGrid — one row per protocol, coloured
                                         left spine, compound icon tile, chevron
section("Week at a glance") (if totals)  StatsIsland
```

Section headers are `Text(title.uppercased())` in `Theme.Typeface.eyebrow` / `Theme.navy`
(`DashboardScreen.swift:129-131`). The greeting is time-of-day-derived
(`greetingPrefix(for:)`, 5–12 morning / 12–17 afternoon / 17–22 evening / else "Hello") over the
**first name only**, matching the web's `.split(/\s+/)[0]` — deliberately without the web's
truncation (`firstName(_:)`, and the comment at `:112`).

### What the web's dashboard actually is

`app/account/page.tsx:78-97`. The `upcoming` panel — the default, no-hash view — composes:

```tsx
<InjectionDayPicker />                      // the 7-day date strip
<div className="ib-dashboard-switch-today">
  <UpcomingDoses />                         // today's dose card(s)
</div>
<div className="ib-dashboard-switch-right">
  <MobileInjectionCount />                  // "2 injections today"
  <SerumChart />                            // modelled serum level over time
  <SiteRotation />                          // "Recommended site" → Left Thigh
</div>
{labs && <LabHighlights data={labs} phase={phase} />}
```

`DashTabs` (`components/account/dashboard/DashTabs.tsx:21`) then holds five *more* panels behind the
URL hash — `history` · `inventory` · `saved` · `calculators` · `settings`.

**This is the correction the Mac made on 2026-08-01 and it still holds:** iOS's protocol grid is not
the web's dashboard. On the web it lives in the **`saved`** panel
(`page.tsx:99-106` → `SavedProtocolsPanel` → `ProtocolList`), which is not the default view. iOS put
the `saved` panel on the front page and built none of `upcoming`.

### The differences

**Functional — the app cannot do things the web can:**

1. **No site rotation.** The web's `SiteRotation` names the next site to use — the capture reads
   `Recommended site · Left Thigh`. iOS has no equivalent. **This is the same hole as T-03**: iOS
   never writes `dose_log.site`, so it could not render a recommendation even if the card existed.
   T-03 is the precondition, not a separate job — sequence them.
2. **No serum chart.** `SerumChart` plots the modelled level across the protocol. iOS has
   `CycleTimelineStrip`, which shows *occurrences*, not *levels*. Different question answered.
3. **No injection-day picker.** The web leads the panel with a 7-day strip
   (`InjectionDayPicker`) — the capture shows `FRI 31 · SAT 1 … THU 6`, today tinted `#EAFAF8` with
   a teal border, per-day dots marking scheduled injections. It is the panel's *navigation*: picking
   a day re-renders what is below it. iOS's "Week at a glance" is a read-only totals island in the
   same position and cannot be tapped.
4. **No injections-today count.** `MobileInjectionCount` — the capture's `2 injections today` — is
   the one number that answers "am I done for the day". Absent on iOS.
5. **No lab highlights.** `LabHighlights` renders when `labs` is non-null, with its retest cadence
   derived from the active cycle's phase (`page.tsx:70-76` — mid-blast and steady cruise get
   different cadences). iOS has no blood-test surface at all.
6. **Five panels have no iOS existence.** `history` · `inventory` · `saved` · `calculators` ·
   `settings` are all reachable on the web from the dashboard. iOS reaches settings through the
   drawer and calculators through Tools; **`history` and `inventory` exist nowhere in the app.**
   File the two missing ones as features, not as dashboard differences.

**Visual — the same information rendered differently:**

7. **The primary metric is not a metric.** Web: `0.5 mg` at display size, navy, with a coloured
   left spine on the card. iOS: `0mg/wk · Testosterone Cypionate` set as a `cardTitle` text row —
   the number has no more weight than the compound name beside it. `Theme.Typeface.display`
   (34/heavy) exists for exactly this and the dashboard never uses it.
8. **The disclaimer is missing.** The web carries it on every page, and the account page comments
   at `page.tsx:146-149` that this is the *last* page to drop it — "a page that estimates drug
   levels". `11.5px`, `rgba(20,20,28,0.38)`, `marginTop: 32`. iOS's dashboard has none.
9. **The screen has no title.** Web: a centred `Dashboard` title between a hamburger and an edit
   button. iOS: the brand lockup `injectbuddy` in the same slot, so every tab's header is
   identical and the header stops telling you where you are. Note this interacts with **T-05** —
   `RouteContent` gives the Dashboard an inline title and every other tab root a large one, which is
   the leading candidate for the dead pull-to-refresh.

**Not a difference, recorded so it is not re-raised:** the web's bottom nav (`Dashboard · Calendar ·
Log dose · Tools · Add`, with `Log dose` as a raised centre hero) and iOS's tab bar already match,
including the hero. The web's `BottomNavLogBridge` (`page.tsx:139-141`) exists so its hero opens the
same sheet rather than duplicating the write path — iOS does the same thing structurally.

**Done when:** each of the nine is built, or recorded here with the reason it cannot be.

---

## S-02 — Calendar (compared 2026-08-04) — **8 differences**

Frames: iOS **`2026-08-02-current/04-tools-IB2245756.png`** — *the misfiled one; it is the Calendar,
with Tools ghosting behind it* · web `screens/02-calendar-populated.png`.
Web source: `app/calendar/page.tsx`, `components/calendar/CalendarView.tsx`.

### What we have now

`Sources/InjectBuddy/Features/Calendar/CalendarScreen.swift:52-75` — a `ScrollView` over a
`VStack(spacing: .lg)` padded `.md`, on `Theme.groupedBackground`:

```
MonthGrid(...).card()     one month · ‹ Today › paging · Mo-start · dose dots · today ringed
DayAgenda(...)            "SELECTED · SUN 2 AUG" · one row per dose · tap toggles taken
```

Two facts from the source that the frame cannot show:

- **The projection window is 30 days**, while the grid renders whole months
  (`CalendarScreen.swift:6-8`). Days past the window render with no dots — indistinguishable from
  days with nothing scheduled.
- **`firstWeekday = 2 // Monday, matching the wireframe header`** (`CalendarScreen.swift:116`). The
  comment is the finding: iOS matched *a wireframe*, and the live web is Sunday-start.

### The differences

**Functional:**

1. **One month, paged, against seven months continuous.** `CalendarView.tsx:311-312` renders
   **1 month back → 5 forward** as one scroll — the capture runs Jun 2026 to Dec 2026 unbroken. iOS
   shows one month and makes you page with `‹ Today ›`. You cannot see a cycle that crosses a month
   boundary without leaving the month you are in.
2. **The 30-day window silently truncates the schedule.** Follows from the above: even after paging
   forward, five of the seven months a web user sees are blank on iOS — **and blank means "nothing
   scheduled", not "not projected"**. That is a screen stating something false, not merely showing
   less. Higher severity than the paging.
3. **Day cells carry no compound identity.** Web cells print the compound as text chips — `Test E`,
   `Sema`, `+1` when they overflow. iOS prints coloured dots. Two blue dots and a red one do not
   tell you what is due without tapping the day.
4. **The week starts on the wrong day.** Web `CalendarView.tsx:48` — `startOff = firstDay.getDay()`,
   commented "US week starts Sunday". iOS is Monday-start. Every row is shifted by one against the
   thing it is meant to match.
5. **No add affordance.** The web header carries a teal `+` beside the month label. iOS has none;
   adding requires leaving for the Add tab.
6. **The day sheet is missing two of its three facts.** Per `page.tsx:32-33` the web's day sheet
   gives "the dose, the draw volume, and a suggested injection site that rotates automatically".
   iOS's `DayAgenda` gives the dose. Draw volume is absent (**and see T-04** — `doseLine`'s dead
   volume derivation is the same missing number on the dashboard). Site is absent for the **T-03**
   reason: iOS never writes it.

**Visual / content:**

7. **No "How it works", no references.** `app/calendar/page.tsx:27-47` — a 17/700 heading, a
   ~150-word explanation of what the projection does and does not do ("it never changes a dose or
   volume"), then three real citations: the 2018 Endocrine Society guideline, the WEGOVY FDA label,
   and a 2016 ester-pharmacology paper. **This one cannot be waved off as SEO.** The page is
   `robots: { index: false, follow: false }` (`page.tsx:8`) — it is not indexed, so that text exists
   for the *user*, and it is the only place the app explains why the schedule looks the way it does.
8. **Header shape.** Web: a breadcrumb `← InjectBuddy` with the month `Jul 2026` beside it, under a
   centred `Injection Calendar` title. iOS: the brand lockup, then a large `Calendar` title, then
   the month again inside the card — the month is stated twice and the screen name once.

**Also here — T-05.** `CalendarScreen` has **no `.refreshable`** (compare `DashboardScreen.swift:23`,
which has one). That is the removed affordance, and it is consistent with T-05's record. The
candidate cause — large title vs inline title owning the pull-down stretch — is still unmeasured, and
**anything added to this screen inherits the problem.** Measure it before building 1–8 on top.

**Done when:** each of the eight is built, or recorded here with the reason it cannot be.

---

## S-03 — Tools hub (compared 2026-08-04) — **7 differences**

Frames: iOS **`2026-08-02-current/05-add-IB2245757.png`** — *misfiled; it is Tools* · web
`screens/04-tools-hub.png` (`/calculators/`).
iOS source: `Features/Tools/ToolsScreen.swift`, `Core/Nav/NavItems.swift:121-164`.

### What we have now

The whole screen, in full — this is not an excerpt:

```swift
List {
    ForEach(CalculatorCategory.allCases) { category in
        let members = category.members
        if !members.isEmpty {
            Section(category.title) {
                ForEach(members) { slug in
                    Button { navigator.push(.calculator(slug)) } label: {
                        Label(slug.title, systemImage: slug.icon)
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}
.listStyle(.insetGrouped)
```

A stock `.insetGrouped` list. Four sections — `GLP-1` · `Testosterone & hormones` · `Peptides` ·
`Steroids` — each row an SF Symbol and a title. **No brand token appears on this screen at all.**

`CalculatorCategory` also carries a `subtitle` per category (`NavItems.swift:138-145`:
"Semaglutide, tirzepatide, retatrutide" / "TRT, microdosing, HCG" / …) which **`ToolsScreen` never
renders.** The copy is already written and already in the binary, unused.

### The differences

1. **Rows have no description.** The web gives every calculator a card: a category tag chip, the
   title, and two or three lines saying what it is for. iOS gives a title. On a browse surface whose
   whole job is choosing, the thing that distinguishes `Peptide Dosage` from `Peptide
   Reconstitution` is exactly the text iOS drops.
2. **No search, no count, no category jump.** The web leads with a calculator count and a horizontal
   row of category chips that scroll you to a section. iOS's only navigation is scrolling.
3. **The category subtitles are built and not shown.** One-line fix, listed separately from #1
   because it needs no new copy — see `NavItems.swift:138-145`. **[confirm on Mac]**
4. **The cycle plotter is in no category, so Tools cannot reach it.** `members`
   (`NavItems.swift:157-163`) enumerates glp1/hormone/peptide/steroid; `.cyclePlotter` appears in
   none of them. **`ToolsScreen`'s own header comment claims it "shows ALL calculators including the
   ones that cannot save a protocol (BMI, Free T Index, the plotter)" — that is false today.** The
   plotter ships (frame `27-calculator-plotter`) and the browse surface omits it. **[confirm on
   Mac — this is where the stale-tree risk bites hardest.]**
5. **Eight calculators exist on the web and not in the app.** From `public/legacy/`: FTV, reverse,
   blend, GLP-1 titration, female HRT, nootropic, bioavailability, E2 estimator. Mac is filing these
   as features rather than diffs and that is right — recorded here only so the Tools list's shortness
   is not mistaken for a layout problem.
6. **No guide links.** Every web card ends with `Read the … guide →` into `/guides/`. iOS has no
   guides surface, so there is nowhere for these to point. That makes it a **feature question, not a
   styling one** — file it, do not fake it with a web link.
7. **No "How calculators work" prose and no FAQ.** The web ends with an explainer and an accordion.

**Owner's call, and unlike the calendar this one is genuinely arguable.** `/calculators/` is a public
indexed page — #6 and #7 really are partly there to rank, which is the same argument parked on
T-01a's FAQ and carousel. **Decide all four together, not screen by screen.** Contrast S-02 #7, where
the argument does not apply: the calendar is `robots: noindex`, so its explainer is for the user.

**Done when:** each of the seven is built, or recorded here with the reason it cannot be.

---

## S-04 — Log-dose sheet (compared 2026-08-04) — **6 differences**

Frames: iOS `docs/ui-audit/2026-08-03-current/08-logdose-sheet-IB2245782.png` · web
`screens/03-log-dose-sheet-open.png`.
Web source: `components/account/dashboard/DashLogFlow.tsx`, `DashboardContext.tsx:352`.

**Read the frame's date before using it.** That frame is from 2026-08-03 05:50. **T-03's site picker
landed at `29a8ede`, 2026-08-03 22:51 — sixteen hours later.** So the sheet in the picture has no
site row and the sheet in the code does. Nothing below claims the site is missing; it is built. The
next capture supersedes this frame.

### What we have now

`Features/Log/LogDoseSheet.swift` — `WHICH PROTOCOL?` as a list of selectable cards, a `Day` row, and
a navy `Log dose` button. Post-T-03 it also asks for the site, seeded one step past the last site
logged against that protocol (the web's own `nextSiteIdx`), and derives `draw_ml` from the protocol's
config via `DoseVolume.perInjectionMl` — no volume picker, but no NULL either.

The write payload is the whole story. `Core/Models/Models.swift:208-219`:

```swift
struct NewDoseLogPin: Encodable {
    var protocolId: String   // protocol_id
    var dosedOn: String      // dosed_on   — a bare calendar day
    var drawMl: Double?      // draw_ml
    var site: String?        // site
}
```

**Four columns.** The web writes `injected_at`, `injection_time` and `injection_timezone` as well
(`DashboardContext.tsx:352`, `DoseHistory.tsx:287`). `grep -rn "injected_at" Sources/` returns
nothing.

**Five, as of 2026-08-04 (T-52):** `dose_label` is now on the write. The three remaining display
snapshot columns — `protocol_label`, `compound_label`, `category` — are filed as T-23; the web falls
back to the live protocol for all three, so they cost history rather than a screen.

### The differences

1. **No injection time, so the serum chart plots iOS doses at an assumed noon.** The web's sheet has
   an `INJECTION TIME · OPTIONAL` field with a stated default and timezone — "Defaults to 12:00 pm ·
   America/New_York". iOS records a bare day.
   **Checked rather than assumed:** this does *not* break the chart. `SerumChart.tsx:169-178` falls
   back — ``new Date(`${row.dosed_on}T${row.injection_time || '12:00'}:00`)`` — so the point still
   plots. What it costs: every iOS-logged dose sits at noon on the curve regardless of when it was
   taken, and because that fallback string has no zone it is parsed in **the viewer's** local time,
   so the same row lands at a different absolute moment for a reader in Auckland than in New York.
   The comment directly above it says this is "what makes the curve reflect reality: … logging one
   adds the time, so the curve jumps the moment it lands." For iOS rows it jumps at noon.
   `observedIntervalFor` then derives cadence from those timestamps, quantised to whole days.
   **Same shape as T-03** — a column iOS declines to fill that a web feature reads — but a degraded
   curve rather than a hole, so it ranks below it.
2. ~~**No dose amount field.**~~ **BUILT 2026-08-04 (T-52).** The sheet has a `DOSE AMOUNT` field
   seeded with the derived per-injection dose; it writes `dose_log.dose_label` and scales `draw_ml`
   with it. **Read the web's source before repeating its shape here:** the web's own field is
   decorative — `DashLogFlow.tsx` seeds `amount` from `p.doseLabel` and never reads it back, so an
   edited amount on the web is discarded and the plan is stored. Filed as T-22. iOS does not copy
   that.
3. **The sheet never says what you are about to log.** Web header: `Log injection` over
   `0.5mg · Semaglutide · 0.5 mg · SubQ` — including the **route**. iOS: `Log a dose`, and the
   identity is only whatever the selected card happens to show.
4. ~~**Two protocol cards are indistinguishable.**~~ **BUILT 2026-08-04 (T-53).** Every card's line
   is derived from its own config by `ProtocolSummary`, and the list is resolved as a whole so no
   two cards can read the same — where the derived language cannot separate two rows, the config
   keys that differ are named outright.
5. ~~**Card meta mixes units within one list.**~~ **MOSTLY (T-53).** One convention now, per
   injection, which is the web's own `doseLabel` convention. Two of the five cards still state no
   dose — a steroid saved in a mode `evaluate` does not run, and a protocol whose weekly dose is 0.
   Filed as T-21; it is a gap in the engine's coverage, not in this screen.
6. **The primary action is navy and unexplained.** Web: a full-width **teal** `Log it` under a line
   saying what it will do — "Records the injection against the date + site you chose, for your own
   tracking." iOS: a navy `Log dose` with no such line. Teal is the web's primary-action colour here
   and navy is its icon/label colour; iOS has them the other way round.

**Done when:** each of the six is built, or recorded here with the reason it cannot be.

---

## S-05 … S-06 — add/confirm-start, settings

Not yet compared. Entries land here as they are done.

---

## Findings that are not screen differences

**F-01 — the web has no TRT EOD calculator, and iOS grew a screen to cover for that.**
`public/legacy/` holds 21 calculator directories; the only TRT ones are `trt-calculator` and
`trt-microdosing-calculator`. EOD is not a page on the web — it is a *frequency inside* the TRT
calculator: `trt-calculator/index.html:296`, "Supports weekly, E3.5D, and EOD dosing".

iOS frame `15-calculator-eod` is therefore not an orphan. It is **T-01a difference #1 seen from the
other end**: iOS has no mode switcher, so it grew a second calculator screen to hold the mode the
switcher would have carried. Building the switcher while leaving the EOD screen standing ships the
mode twice.

**Consequence for T-01a #6.** The related-calculators target is not "TRT EOD, TRT Microdose". The
web's own calculator navigation is TRT Dose · TRT Microdose · Semaglutide · Tirzepatide · HCG, then
a second column (Peptide Reconstitution · Peptide Dosage · BPC-157 · BPC-157 + TB-500 Blend · BMI ·
Cycle Plotter). Take the target from the source, not from the caption.

**Corroborated in the iOS catalog.** `CalculatorCatalog.swift:268-274` — the `.eod` spec is the TRT
spec with the help text *"Hardcoded every-other-day interval (3.5 injections/week)"*. It is not a
different calculator. It is the TRT calculator with one mode nailed shut, which is precisely what a
mode switcher would replace.

**Open, owner's call:** whether TRT EOD collapses into the TRT calculator once the mode switcher
exists. It is a shipping screen; it does not get deleted off the back of this note.

**F-02 — resolved, and it cost something before it was.** Windows had no checkout; see TASKS.md
**T-10** for what the stale copy actually caused, and **T-50** for the untracked tree that still
exists beside the real one. Both are recorded rather than quietly fixed, because a stale copy that
looks authoritative is the kind of failure that comes back.
