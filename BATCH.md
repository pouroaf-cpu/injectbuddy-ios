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
| 7 | Delete-account dialog copy stops promising deletion it does not perform | Copy matches behaviour |
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

## PRE-SHIP CHECKLIST — things that can only be checked on the way out

**RELEASE BUILD STILL SHOWS THE SIGN-IN SCREEN.** One launch of a **Release** build before
submission, confirming `AuthFlow` appears. A DEBUG-only auth bypass is being added so the app boots
straight past sign-in on this rig; if it ever leaks to Release we ship an app **anyone can open as
someone else**, and it is exactly the class of defect that looks fine in every test we own —
because every test we own runs the debug build. Compile-time guard is the fix; this launch is the
evidence. **Not optional and not delegable to a passing green.**

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
