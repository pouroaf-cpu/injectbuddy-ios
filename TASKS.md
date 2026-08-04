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
site disagree, the live site wins — Windows has the source.

**Done when:** every screen has been compared, every difference is either built or recorded with a
reason it cannot be.

---

### T-01a — TRT calculator (compared 2026-08-04) — **12 differences**
**Priority 9/10** · **Owner:** mac · **Status:** open
Frames: iOS `docs/ui-audit/2026-08-03-current/06-calculator-trt-IB2245780.png` · web
`screens/30-calc-trt-result.png`.

**Functional — the app cannot do things the web can:**

1. **No mode switcher.** The web leads with a three-way segmented control — `Every N Days` ·
   `Per Week` · `mL → mg`. iOS has no visible mode control at all, though the engine stores a
   `mode` in the saved config. A user cannot switch how they think about the dose.
2. **No compound search.** The web has a searchable, typeahead compound field with a magnifier icon
   over the full compound list. iOS has an `Ester` picker — a plain menu, fewer entries, no search.
3. **No link to the levels chart.** The web has a tinted card — `📊 See your levels over time →` —
   taking you from the calculator straight into the plotter with this protocol loaded. iOS has
   nothing connecting the two.
4. **No formula card.** The web shows `units = (per-shot dose ÷ vial strength) × 100` and then
   defines each term underneath — `per-shot dose`, `vial strength`, `× 100` — colour-coded. It is
   the thing that makes the number trustworthy rather than magic. Absent on iOS.
5. **No FAQ.** The web carries an accordion of real questions — how to calculate the volume, which
   vial concentration to pick, the difference between the two modes. Absent on iOS.
6. **No related calculators.** The web ends with a horizontal card carousel — TRT EOD, TRT Microdose
   — with a one-line description each. Absent on iOS.

**Visual — the same information rendered differently:**

7. **Number fields have no scale.** Every web numeric field carries a **tick ruler** beside the
   value showing the plausible range (`20 30 40 50 60 70` for vial strength, `10 15 20 25 30 35` for
   the dose). iOS has `−`/`+` steppers instead. The ruler tells you where your number sits; the
   stepper does not.
8. **Label placement.** Web puts the label in a grey pill to the **left** of the value, on the same
   row. iOS stacks the label above the field. The web row is denser and reads as one control.
9. **Value emphasis.** The web wraps the value in a heavy navy-outlined box — the number is the
   focus of the row. iOS renders it as ordinary text inside a bordered container.
10. **Section labels.** The web uses small caps section headers — `SYRINGE SIZE` — above grouped
    controls. iOS uses sentence-case field labels throughout, so nothing groups.
11. **The result affordance.** Web: a full-bleed **bright cyan** sticky bar, `👁 Show result`,
    unmistakably the primary action. iOS: a pale teal `See your result` button sharing a row with a
    navy `Add`, so the two compete.
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

---

## T-02 — The web app leaves data behind when an account is deleted
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
