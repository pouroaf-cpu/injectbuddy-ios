# BATCH.md — current batch

**Operating mode: batch-first.** The Simulator build/test cycle is the bottleneck. Never build to
check one change. Queue a batch, build once, sweep once in a single Simulator session, clear.

A change is not done when coded. **It is done when its batch sweep passes.**

Measured on this rig, 2026-08-03 — the numbers the mode exists for:

| | |
|---|---|
| Cold build-for-testing (fresh DerivedData + SPM resolve) | 258s |
| No-op rebuild | 11s |
| Unit suite, test-without-building, 41 tests | 45s wall / 1.2s execution |
| One UI test, warm, really running | 159s wall / 126s execution |
| One UI test that **skips** | 42s wall, exits **green** |

Per-run harness overhead is ~41s regardless of content. **The build is not the dominant cost once
DerivedData is warm — 11s. The bottleneck is the signed-in UI run.** So batch by SIGN-IN, not by
build. One runner sustains roughly 20–25 signed-in checks/hour.

---

## Batch 1 — the Add flow, end to end

**Why these are one batch:** a protocol saved from iOS is invisible, and a dose logged against it is
discarded. The Add flow — the app's primary write path — **has never produced a usable row on any
build.** Items 1–4 are the write path, 5–7 are the app's inability to report a failed write, 8 is
independent, 9 is in the tree and cannot be separated from the build.

| # | Change | What the sweep must look at |
|---|---|---|
| 1 | `unlogDose` — `user_id` in the delete predicate | An untick no longer depends on RLS alone to be correct |
| 2 | `user_id` on the `dose_log` insert, mirroring the `saved_dosages` pattern | A logged dose produces a row |
| 3 | Client writes **return the row and throw on empty** | A refusal can no longer be discarded silently by any call site |
| 4 | `status` on the `saved_dosages` insert — parameterised, default `active`, accepts `draft`/`archived`. **Never write the `is_active` mirror.** | Saved protocol appears on the dashboard |
| 5 | Optimistic-write pattern — both view models + two `SettingsScreen` sites, six in the family | **Look for a tick that STAYS, not a flicker.** `DashboardViewModel.markTaken`'s rollback is conditional on `data.nextDose?.occurrence == occurrence` — if the dashboard reloaded between the tap and the failure, the rollback is skipped entirely and the false "taken" persists. Also: a failed write leaves **no** success state on screen, the error lands somewhere the current screen actually renders, and the press gets visible feedback within 400ms (`DashboardComponents.swift:104` passes no `isLoading`, so there is no spinner across the await) |
| 6 | `CalendarScreen` gets `.refreshable` | There is a way back from a failure |
| 7 | ~~Delete-account dialog copy stops promising deletion it does not perform~~ **SUPERSEDED 2026-08-03 — real deletion shipped.** | ~~Copy matches behaviour~~ Copy promises deletion **and the promise is true**. `TASKS.md` `X-02`, verified across 30 surfaces. |
| 8 | CI repoint off `working-directory: app` + placeholder xcconfig, **no repo secrets** | Lands independently; no device needed |
| 9 | Result bar as one shared control + calculator name as content-area header (`DESIGN-PARITY` §9 option **(a)**, never `.principal`) | **Four findings, one sweep** — barrel buttons on `trt` AND `steroid`, F-H, F-I, and the keypad/frequency finding. It either closes four at once or it tells us the ~52%-of-content-area diagnosis was wrong. Verify at default size on `trt` plus at least one screen outside the top five. Barrel labels keep their units (the `SegmentedRow` `lineLimit` removal) |

### State of the nine, 2026-08-03 — CODED AND COMPILING. NOTHING SWEPT.

Every item below is in the tree and the tree builds. **Not one of them is done**, because this
file's own second line is the standard: *a change is not done when coded, it is done when its batch
sweep passes*. No test has executed, no row has been read back from the database, and nothing here
has been observed doing what it was written to do. Read this table as "the code exists and the
compiler accepted it", which is the weakest true claim, and do not tick anything off it.

| # | In the tree at | State |
|---|---|---|
| 1 | `1cf8de0` | Coded, compiles. Unswept. |
| 2 | `6badb96` | Coded, compiles. Unswept. |
| 3 | `6badb96` | Coded, compiles. Unswept. |
| 4 | `1cf8de0` | Coded, compiles. Unswept. |
| 5 | `cdd2d4a` | Coded, compiles. Unswept. |
| 6 | `cdd2d4a` | Coded, compiles. Unswept. |
| 7 | `cdd2d4a` | Coded, compiles. Unswept. |
| 8 | `edfc2f1` | Committed earlier. CI has not been observed passing on the repoint. |
| 9 | `69a674a` | Committed earlier. Filed as `TEST-QUEUE` Q2, not run. |

`6badb96`, `cdd2d4a` and `edfc2f1` were committed by an agent a session limit killed mid-task, and
each of those messages says in its own words that it parses and was never type-checked. That is no
longer the state — `1cf8de0` closed the two holes they left (items 1 and 4) and the whole thing
compiles. It is still not evidence about behaviour.

### The sweep, in one signed-in session

Save a protocol → **see it on the dashboard** → log a dose against it → read the row back → confirm
nothing silently rolls back. That sequence has never once executed successfully.

Verification requirement for item 4: the row read back must show `status='active'` **and**
`is_active=true`. Asserting only what was sent would still pass on a trigger that had been dropped —
the `is_active` half is what proves the trigger's non-draft branch fired.

### ~~Rig hazard~~ — STRUCK 2026-08-03, on evidence

**Both conditions this section named were met in one run.** A build carrying `user_id` on the
`dose_log` insert and in the `unlogDose` predicate is installed, **and** a dose has been written and
read back: `dose_log` 14 → 15, `user_id=c8926abc-52b0-41f3-8968-bc44f56e1dd1`,
`created_at=2026-08-03 06:20:47.108362+00`, confirmed by a second reader querying production
directly. `logDose` and `unlogDose` no longer have opposite outcomes.

**Struck because it was measured, not because a commit landed** — which is the distinction this
section was rewritten twice to preserve. The superseded text is below, kept only so the retirement
is legible rather than a silent deletion.

<details><summary>The hazard as it stood</summary>

### Rig hazard — live on the build that is INSTALLED, fixed only in source

**Do not tap a dose cell on the Calendar tab on the QA account.** `logDose` fails on the NOT NULL;
`unlogDose` succeeds because RLS `USING` scopes it. The two halves of one toggle have opposite
outcomes, so tapping a ticked dose permanently deletes a real row the app cannot re-create.

**Narrowed again 2026-08-03, and read the distinction carefully — it is the whole of what changed.**
The hazard's cause is fixed **in source**: the half that removes the asymmetry is item 2 —
`user_id` on the `dose_log` insert, in the tree since `6badb96` — and item 1's `user_id` in the
DELETE predicate (`1cf8de0`) hardens the destructive half against another account's row. The
section heading used to say "live until item 1 is in the build"; item 1 is in the TREE, which is
not the same sentence, and the NOT NULL was never item 1's to fix anyway.

**Nothing has been built onto the device.** The binary sitting on the simulator predates all of it,
so on the rig as it stands today the hazard is exactly as live as it was when it was written. It
does not retire when a commit lands. It retires when (a) a build carrying `1cf8de0` or later is
installed on that simulator **and** (b) a logged dose has been written and read back — because
`logDose` failing for some second reason recreates the identical asymmetry, and a fix that has
never been run is a hypothesis about a write path that has never once produced a row.

Until both of those are true, treat this section as live.

**Narrowed 2026-08-03, measured — the earlier version of this warning was wider than the defect.**
The destructive path is **only** `CalendarViewModel.toggleTaken`. The **dashboard card is safe**:
`NextDoseCard` renders "Mark taken" only in the `!alreadyTaken` branch — a taken dose renders static
text with no button — and `markTaken` is insert-only and cannot reach `unlogDose`. So the dashboard
log path is usable for verification; the Calendar tab is not.

If a check needs a logged dose, create it and read it back — never toggle one.

Strike this section when the sweep has logged a dose and read the row back on an installed build
carrying the fix — not when the commit lands. A rig hazard that outlives its cause is the
`content_size` trap again; a rig hazard struck on a source read is `§5.1`, and this one destroys
real rows when it is struck early.

</details>

---

## Batch 2 — unblock the Add flow, and the barrel a user cannot reach

**Batch 1's sweep ran and the Add flow still has never executed.** It failed at step 1, before any
save, so **items 1–7 of batch 1 are NOT OBSERVED — not failed, never reached.** Nothing from them
is ticked. Item 8 (CI) passed. Item 9 landed the bar at **17.37% from 52.40%**, shown red first at
cap 0.55 with `bar=120.00` corroborated by two independent suites — that one is real.

**The rig hazard does NOT retire.** A build carrying the fixes is installed, but no dose has been
written and read back. Calendar tab stays off limits.

| # | Change | What the sweep must look at |
|---|---|---|
| 1 | **`NumberField` must accept being empty.** `CalculatorScreen.swift` sets `value = 0` on empty text and the paired `onChange(of: value)` rewrites it to `"0"` — a control fighting its own input. The model needs an empty representation that is not `0`: optional, or a sentinel the formatter renders as `""`. **Fix the control, not the test.** | Clear a weekly dose, retype: no leading zero. Everything else is behind this item. |
| 2 | **STOP FIXING. ONE MEASUREMENT DECIDES THE SEVERITY.** Two measurements do not reconcile and the gap is the whole finding: the capture harness walked `trt` to its scroll end and the last element stopped at **y 653 against a plate top of 671** — content clearing the plate — while `control_syringeMl_0.5 mL (50u)` measures **642.7–686.7**, which crosses it. Both cannot be true at the same scroll position. **THE QUESTION: at FULL SCROLL, are `1 mL (100u)` and `3 mL (IM)` fully clear of the plate and tappable?** **YES** → the user reaches every barrel by scrolling; it is a **D5** violation and a real defect, but **not criterion 1**, does not block the ship, and gets filed with the measurement against it. **NO** → a barrel cannot be selected at all on the two most-used calculators; **criterion 1, and it blocks.** Tune nothing before this answer: shrinking the plate moves the straddle from row 2 to row 3, and tuning `ViewThatFits`'s ideal width until the branch flips is tuning a collision. | Measure at full scroll on `trt` AND `steroid`. Nothing else on this item. |
| ~~2a~~ | ~~*(superseded — the original clearance framing)*~~ **The barrel straddle — criterion 1, not cosmetics.** A user cannot select `1 mL (100u)` or `3 mL (IM)` on `trt` or `steroid`, at default size, no flag. Measured: `control_syringeMl_0.5 mL (50u)` spans y 642.7–686.7, plate top 671.0. **Do NOT re-add `lineLimit`** — that buys the straddle back by reintroducing the truncation D4 forbids, trading one criterion-1 defect for another. Fix as **clearance per D2**: whatever pins the plate reserves the space it occupies. If the plate is an overlay rather than an inset, **that is the finding** and it is one site. | All four barrel rows reachable at default on `trt` AND `steroid`, units still intact |
| 3 | **Two titles on every calculator.** `RouteContent` applies `.navigationTitle` to every route; item 9 added a content header. **One shared site — suppress the inherited nav title on calculator routes.** Reported not written last pass; that was right then, not now. | Exactly one title per calculator |
| 4 | **The `syringe` identifier collision.** Item 9's `ScreenHeader` mark is a second `app.images["syringe"]`, so `testCaptureFullDefaultSweep` died after one calculator and **22 frames were not taken**. Give the header mark its own identifier. P6 in its plainest form. | Buys back the screen-outside-the-top-five this sweep could not observe |
| 5 | **Two stale test lists.** `DynamicTypeTruncationUITests.calculators` and `CalculatorWiringUITests`' BMI leg still route to withdrawn calculators. **Update the lists; do not touch the app.** | — |

**On item 5, worth recording:** two independent suites failing to reach BMI and Free T Index is the
**running-screen confirmation the unit test explicitly cannot supply**. H6 is now verified on the
device, which it was not before. The reds are the app being right and the lists being old.

**Then one build, one signed-in session, and the sweep runs the Add flow end to end.** The dashboard
is sitting on an untaken dose due today, so items 1–7 and the hazard's retirement are one run away
— *after* item 1, not now.

**The auth bypass is NOT in this batch**, and it would make this cheaper. The write path is the
ship, and changing how the app boots in the same build we finally verify it in is how a result
becomes unattributable. **Batch 3 is the bypass plus onboarding**, and if batch 2's sweep is clean
that is where the sign-in ceiling comes off.

**Filed, left alone:** the `04-tools.png` Calendar-under-a-Tools-label frame; `ProbeAttachmentUITests`
reporting one occluded entry per run so clearing that debt takes eight runs; and this file's own
stale `DashboardComponents.swift:104` citation — **the file-plus-a-line rule biting inside a day.**
Fix that citation to name the string next time this file is touched for another reason, not before.

---

## Batch 3

**Batch 2's sweep passed. The Add flow executed end to end for the first time** — `dose_log` 14→15,
`saved_dosages` 102→103, `status='active'` **and** `is_active=true`, tick stayed, row confirmed by a
second reader querying production. **Both P0s are closed on evidence.** The rig hazard is struck.

| # | Change | What the sweep must look at |
|---|---|---|
| 1 | **`draw_ml` on the dashboard log path.** The dashboard-logged row wrote `draw_ml = NULL` and it is the **only** NULL in the table — all 14 pre-existing rows carry a volume. The web writes it (`DashboardContext.tsx:353`, `draw_ml: ev.vol ?? null`) and **consumes it**: `app/api/inventory/route.ts:8` computes remaining supply as `(vial_count × vial_ml) − Σ(dose_log.draw_ml since stocked_on)`. **So a NULL is a dose that consumes nothing from inventory** — log every dose from the iOS dashboard and the app reports your stock untouched. That is the "never run dry mid-protocol" promise wrong in the direction of running dry. The value is already in hand (`mlDrawn: 0.5` in the config, and in the projection). **`LogDoseSheet` writes it and the dashboard does not — enumerate every log path and state the count**; this is the same one-of-three-call-sites shape as the optimistic-write family. | A dashboard-logged row carries a volume; inventory decrements |
| 1b | **NEW BEHAVIOUR, NOT A REGRESSION — do not file it as one.** `peptide` was the only injectable branch of `evaluate` that never populated structured `drawMl`, so the barrel **over-capacity check has never fired on that calculator at all**. It is now populated. | An over-capacity warning becoming possible on Peptide is the fix working |
| 2 | **~~Retatrutide shear~~ → THE REGRESSION BEHIND IT: `69a674a` added ~116pt to the form on ELEVEN calculators.** Removing `SegmentedRow`'s `lineLimit` pushed its `ViewThatFits` into the column branch: four stacked 44pt rows 4pt apart = **188pt**, against **~72pt** for the single row of pills in the pre-change frame `21-calculator-retatrutide-IB2245768.png` (shot at `9b4afcb`, confirmed by `git merge-base` to be an ancestor of `69a674a`). `4 × Theme.minTarget + 3 × Spacing.xs = 188` — exact. **The shear is a symptom; the 116pt is the finding.** **MEASURE FIRST:** at rest, default, on Retatrutide — `bar_plate.frame` top against the frame of `result_Draw`. **If they intersect it is criterion 2, not cosmetics** — a displayed dose volume sheared mid-glyph with no ellipsis is the app misleading the user about a number, at default size, in a dosing app. Then **fix the fit test at the one site**: the branch decision must be made on **the width the row would actually render at**, not on the labels' unwrapped single-line ideal, and **not** on a threshold nudged until it flips. If that cannot be expressed, **that is a finding about `ViewThatFits`, not a licence to pick a number.** `lineLimit` stays out — it buys back the silent clipping being fixed. | Measure **Retatrutide, Semaglutide AND Tirzepatide** — they share a field set, so they land at the same offset. **State the sample**: which you measured, not which one you found it on. If the fit test is fixed, re-check whether the barrel D5 finding closes too | A value+unit pair clipping silently — the one thing CLAUDE.md says never to accept — at default size, on a real screen. Note it is **exactly the screen the sweep had never reached** until batch 2 item 4 bought it back. | No shear at default; units intact |
| 3 | **The auth bypass. DEBUG ONLY.** Boot past `AuthFlow`: restore the Keychain session, and sign in from QA credentials if there is none. **Release is untouched and the gate stays exactly as it is** — guard at compile time. Removes the ~20–25 signed-in-checks/hour ceiling for the whole app. | See PRE-SHIP CHECKLIST — a **Release** build must still show sign-in |
| 4 | **The onboarding target — FOUNDATION ONLY, `a15c62f`. Screens are a separate pass and do not exist yet.** `OnboardingPreview` target, `Sources/OnboardingKit/`, the copy file, the state machine, the sink. `OnboardingFlowView` switches over all 13 steps with **no `default`** — that switch **is** the screens pass's checklist, one arm at a time. What renders today is a labelled scaffold, not the design. | **NOT sweepable yet** — §7's six paths are unproven and there is nothing to look at. Do not schedule the no-login sweep until the screens pass lands |

**Then a sweep that finally covers batch 1 items 1, 6, 7 and the 400ms clause.** All four are
reachable for the first time: the Calendar hazard is struck **and** there is at last an iOS-written
row to unlog and re-log. **They stay NOT OBSERVED until that run — none of them becomes a pass on
the strength of today.**

### Item 2 of batch 2 — filed, not blocking, and the table is the reason

**D5 violation.** Every barrel is selectable at some scroll position; **there is no position where
all four are.** Identical to the pixel on `trt` and `steroid`, default text size.

| | at rest | at FULL SCROLL |
|---|---|---|
| `0.3 mL (30u)` | clear, hittable | 49–93 — **above navBottom 100.33, not hittable** |
| `0.5 mL (50u)` | **642.7–686.7 — straddles plateTop 671** | 97–141 |
| `1 mL (100u)` | off-screen | **145–189 — hittable, tapped, `selected=true`** |
| `3 mL (IM)` | off-screen | **193–237 — hittable, tapped, `selected=true`** |

Keep both columns together: **that pair is the whole of why this is not criterion 1**, and a later
reader given only the at-rest row will re-escalate it.

**And the reconciliation, which is the more useful half:** the at-rest `642.7–686.7` and the capture
harness's `y 653 against plate 671` **were both correct** — different scroll positions. Set against
each other they read exactly like a defect. **The conflict was in the framing, not the numbers.**

---

## Batch 4

**Sweep 3 results:** item 1 (`unlogDose` + `user_id`) **PASS** — `dose_log` 15→16→15 and a **set
comparison against the pre-sweep ids returning `missing=0, extra=0`**, which is stronger than a
count; `draw_ml` **0.373** against `149/2/200 = 0.3725`, confirming batch 3 on the dashboard path.
Item 7 (delete-account copy) **PASS** — **re-check this the moment real deletion lands; it stops
being true then.** **→ REAL DELETION LANDED 2026-08-03, so this re-check has been done and item 7 is
SUPERSEDED.** The copy that passed said deletion was unavailable; that sentence is now false, and it
has been replaced by copy that promises deletion — which is true, verified across 30 surfaces with
the QA account as an unchanged control. See `TASKS.md` `X-02` and `docs/SPEC-ACCOUNT-DELETION.md` §5.
**Do not re-assert the old copy as a pass: the thing it was true about no longer exists.** Item 6 **FAIL**. The 400ms clause: **feedback PASS, spinner NOT OBSERVED, and
that is where it stops** — `tap()` returns only on quiescence so "button gone" cannot distinguish a
wired spinner from an unwired one, and `simctl io screenshot` at 856ms/frame cannot see a 400ms
window. **Not observable with the instruments we have. Do not build a harness to close it** — that
sentence is a true statement about our evidence and it is worth more than a green.

| # | Change | What the sweep must look at |
|---|---|---|
| 1 | **CRITERION 1 — a cancelled load renders as a full-screen error on the home screen.** Observed twice on device after a pull-to-refresh: *"The operation couldn't be completed. (Swift.CancellationError error 1.)"* **with the next-dose card gone.** `DashboardViewModel.load` ends `catch { state = .failed(…) }` with **no case for cancellation** (`DashboardViewModel.swift:95`); `CalendarViewModel.load` is the same shape. **A cancellation is not a failure — it is the app superseding its own request** — and rendering it as one costs the user their dose card for a race they caused by pulling twice. **Intermittent makes it worse, not better: it reaches a user and cannot be reproduced by whoever they report it to.** **Fix at the load pattern, not at two view models — there will be a third. Enumerate every `catch` that sets a failed state and state the count.** This is the optimistic-write family one layer down: a `catch` treating every throw as a user-visible failure. | Pull twice fast on the dashboard: previous state stays, nothing is surfaced, the dose card never disappears |
| 2 | **Calendar `.refreshable` fires nothing. ONE BOUNDED ATTEMPT — 30 minutes — THEN REMOVE THE AFFORDANCE.** Measured: Calendar parked, a production label change 56s before the pull never appeared, Supabase's API log shows **zero requests** after the initial read. Discriminator, same gesture one minute apart on identically-shaped ScrollViews: **dashboard pull → re-read in 3s; calendar pull → nothing.** The gesture arms `.refreshable` — proven on the dashboard in the same run — and the two screens' source shape is identical, so the cause is **not visible from a source read.** **A pull gesture that silently does nothing is worse than no pull gesture: the user believes they have refreshed and they have not — the same lie as the optimistic tick.** `.task` re-runs on tab re-appearance, so the data path survives removal and only the affordance is lost. **File the mystery with the discriminator either way.** | Either a pull re-reads, or there is no pull to make |
| 3 | **The Calendar's taken-tick is unreadable to accessibility — cheapest item on the board.** `AgendaRow` conveys "logged" by SF Symbol + colour + strikethrough, **none of which reaches the label**: rows read `"TRT Dose, TRT"` taken or not. **A VoiceOver user cannot tell a taken dose from an untaken one in a dosing app**, and the sweep had to use the database as its observer for exactly this reason. Two lines of `accessibilityValue` at one control. **This is not the deferred accessibility work** — it buys correctness for the user and observability for every future run, at one site. | A run can read the tick without querying the database |

### Batch 4 residual risk — KNOWN, BOUNDED, ACCEPTED. Not an oversight to re-open.

**Confirmed on the device:** the `.loading`-blanking half. **26 real drags across 13 double-pulls,
299 screen samples, zero with the card missing, zero error banners** — and refresh proven by an
external database write, not by "Loading…". Under the old code `load()` set `.loading` on every
call, so the card would have vanished on **every** pull. It vanished on none.

**NOT OBSERVED:** the cancellation classifier itself. XCUITest brackets every interaction with
*"wait for the app to idle"* and `.refreshable` holds its control until the async closure returns,
so **the harness cannot issue pull 2 while load 1 is in flight** — measured gap 5.76s–7.02s, every
time. Two loads were never concurrent, so no cancellation was proven to occur.

**The residual risk, stated so nobody has to re-derive it:** if the classifier is wrong, **the
symptom that returns is the error banner, not the vanished card** — a smaller defect than the one we
started with, on a path a user can still reach by pulling faster than the harness can.

**Do not build a harness to close it.** This is the 400ms clause again: not observable with the
instruments we have, and a true statement about our evidence is worth more than a green.

### Two things batch 4 leaves behind — read both before the next sweep or the next `RouteContent` edit

**1. `Loading…` IS NOW A BLIND INSTRUMENT, BY DESIGN. Its absence is NOT evidence a refresh did not
fire.** Item 1's fix required a second half: `load()` no longer sets `.loading` when data is already
loaded, because *"a cancelled load leaves the previous state alone"* is unsatisfiable if the
preamble has already discarded that state — without it the fix trades a permanent error banner for
a permanent spinner. `Sweep3UITests`'s `loadingTextShowing()` reached for exactly this signal.
**Use the database or the API log as the observer. The next sweep will reach for it too.**

**2. FILED CANDIDATE, with its mechanism — why `.refreshable` fired nothing on the Calendar.**
`RouteContent.titleDisplayMode` is `route == .dashboard || carriesOwnHeader ? .inline : .automatic`,
so **the dashboard is the only tab root with an inline title and every other gets a LARGE one — and
a large title owns the pull-down stretch above a plain ScrollView.** That is one level up in shared
shell code, which is why the two screen files read identical and the cause was invisible to a source
read. The discriminator is already in the log: same gesture one minute apart, dashboard pull →
re-read in 3s, calendar pull → zero requests.

> **THE TRAP THAT OUTLIVES THE AFFORDANCE — this is the part worth keeping.** If that mechanism is
> real, the dashboard's refresh works **because** its title is inline, and **any future screen with
> a large title will silently not refresh.** Not "might not" — silently, with the gesture arming and
> nothing happening, which is what took a parked screen, a production edit and an API log to catch
> the first time.

**Take the measurement when something next touches `RouteContent` for another reason — not before.**
It is ~10 minutes from here: flip the Calendar to `.inline` and pull once. It stays filed because
the affordance is already removed, `.task` on tab re-appearance keeps the data path whole, and
nothing a user can do is broken — so measuring it now is a new front on a closed item.

Weaker candidates, recorded so they are not re-derived: the harness's `scrollContainer()` takes the
first hittable scroll-ish element and the Calendar has a `LazyVGrid` the dashboard does not (**same
gesture was established; same target element was not**); and `CalendarScreen.reload()` mutates
`visibleMonth` before its await where the dashboard awaits immediately. And item 1's `.loading`
change is itself a candidate fix — the ScrollView owning the refresh control is no longer destroyed
under it mid-pull. **The affordance returns on a request appearing in the API log, never on that
argument.**

---

## PRE-SHIP CHECKLIST — things that can only be checked on the way out

**RELEASE BUILD STILL SHOWS THE SIGN-IN SCREEN.** ✅ **DONE 2026-08-03.** One launch of a **Release**
build before submission, confirming `AuthFlow` appears. A DEBUG-only auth bypass is being added so
the app boots straight past sign-in on this rig; if it ever leaks to Release we ship an app **anyone
can open as someone else**, and it is exactly the class of defect that looks fine in every test we
own — because every test we own runs the debug build. Compile-time guard is the fix; this launch is
the evidence. **Not optional and not delegable to a passing green.**

> **The run, three independent legs.** Release build, exit 0, launched on an **erased iPhone 16 Pro
> Max** — a *second* simulator, erased first, so **no Keychain session could exist**. A green from
> the primary rig would have been indistinguishable from a restored session sending it to
> `MainShell` legitimately, and erasing the primary rig would have destroyed the evidence the rest of
> the day rests on.
> 1. **Screenshot:** the signed-out welcome — wordmark, *"Plan the cycle. Log the dose. Know the
>    day."*, `Create account`, `Sign in`. That is `realSignInGate`, the only branch Release compiles.
> 2. **`nm` on the Release binary: ZERO `DebugAuthBypass` symbols.** The guard did not merely not-run
>    — the code is not in the binary.
> 3. **The confound was removed, not reasoned away** (the erase, above).
>
> **Method disclosed:** `DisclaimerGate` comes up first on a cold install and `simctl` has no tap, so
> `ib_disclaimer_accepted_v1` was set in the app container's defaults and the app relaunched. Same
> state the button produces, orthogonal to the gate under test, but performed on the container rather
> than through the UI. **`DisclaimerGate` at large text remains unobserved** and stays in the
> cold-start batch.

**~~REAL ACCOUNT DELETION~~ ✅ DONE 2026-08-03 — see `TASKS.md` `X-02` and
`docs/SPEC-ACCOUNT-DELETION.md` §5.** Edge Function `delete-account` v1, 30 surfaces to zero, QA
account unchanged to the id-set checksum. **One residual: the offline failure path has not been run**
— the guard is written, but exercising it takes the Mac's network down. UI suite, or the last act of
a session.

---

## Batch-after-next — the cold-start batch. ONE erase, ONE run.

**Ordering is deliberate and not negotiable: this happens AFTER the batch-1 sweep**, because
`simctl erase` destroys the Keychain session that sweep needs, and a first run is the only state in
which a first-run gate can be observed. There is no cheaper substitute and no way to interleave it.

Everything that has never been seen cold goes in this one run:

| Look at | Why it has never been observed |
|---|---|
| `DisclaimerGate` at **default AND large text** | First-run only. **`Theme.swift:106` names it FIRST in a list of ten screens with frozen sizes** — a gate whose text does not scale is a real criterion 3 finding. This is the specific thing to look at. |
| Sign-up | Reached only from a signed-out first run |
| The empty dashboard | Only exists before any protocol is saved |

**This is the last pre-ship check.** If the gate turns up a scaling defect we deal with it then —
no speculating now, and nothing is built against it in advance.

### Known state

**The tree compiles.** `xcodebuild build-for-testing`, iPhone 16 Pro / iOS 18.3.1, **exit 0**, at
`1cf8de0`. All three symptoms this paragraph used to list are gone: `ResultSheet` is defined at
`CalculatorScreen.swift`, `private struct ResultSheet: View` (item 9's rewrite finished), there is
no `idPrefix` argument left to be extra, and no type-check timeout. Measured wall time, this rig,
SPM already resolved: **138s** for the build that first went green, **6s** for the no-op rebuild
straight after it. Those numbers replace the "do not attempt a build" instruction that stood here —
the reason for it was a half-finished file, and the file is finished.

**Compiling is the only thing that has been established.** No test has run, the batch sweep has not
happened, and no build has been installed on the simulator. The gate this note describes is a
compile gate — *a batch does not go to the runner until it compiles locally* — and it has been
passed, which moves the batch to the runner and closes nothing.

`xcodegen generate` **has been run**, at `1cf8de0`, and does not need running again. Reason, so
nobody repeats it "just in case": `Tests/InjectBuddyUITests/AddFlowToDoseLogUITests.swift` was a new
file in a globbed directory, so the generated `pbxproj` had **0** references to it while every other
test file had **4**. After the run it has **4**. That is the one case the "only on project-definition
adds/removes" rule names, and running it is what made the file part of the target — it is still not
a licence to run it routinely. The test addresses `cta_add`, `kb_done` and the calculator's first
text field, all of which live in `CalculatorScreen.swift`, which item 9 rewrote; whether those
identifiers still resolve is a question for the run, not for a source read.
