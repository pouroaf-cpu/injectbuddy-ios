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
| 5 | Optimistic-write pattern — both view models + two `SettingsScreen` sites, six in the family | A failed write leaves **no** success state on screen, and the error lands somewhere the current screen renders |
| 6 | `CalendarScreen` gets `.refreshable` | There is a way back from a failure |
| 7 | Delete-account dialog copy stops promising deletion it does not perform | Copy matches behaviour |
| 8 | CI repoint off `working-directory: app` + placeholder xcconfig, **no repo secrets** | Lands independently; no device needed |
| 9 | Result bar as one shared control + calculator name as content-area header (`DESIGN-PARITY` §9 option **(a)**, never `.principal`) | **Four findings, one sweep** — barrel buttons on `trt` AND `steroid`, F-H, F-I, and the keypad/frequency finding. It either closes four at once or it tells us the ~52%-of-content-area diagnosis was wrong. Verify at default size on `trt` plus at least one screen outside the top five. Barrel labels keep their units (the `SegmentedRow` `lineLimit` removal) |

### The sweep, in one signed-in session

Save a protocol → **see it on the dashboard** → log a dose against it → read the row back → confirm
nothing silently rolls back. That sequence has never once executed successfully.

Verification requirement for item 4: the row read back must show `status='active'` **and**
`is_active=true`. Asserting only what was sent would still pass on a trigger that had been dropped —
the `is_active` half is what proves the trigger's non-draft branch fired.

### Rig hazard — live until item 1 is in the build

**Do not tap a dose cell on the Calendar tab on the QA account.** `logDose` fails on the NOT NULL;
`unlogDose` succeeds because RLS `USING` scopes it. The two halves of one toggle have opposite
outcomes, so tapping a ticked dose permanently deletes a real row the app cannot re-create.

**Narrowed 2026-08-03, measured — the earlier version of this warning was wider than the defect.**
The destructive path is **only** `CalendarViewModel.toggleTaken`. The **dashboard card is safe**:
`NextDoseCard` renders "Mark taken" only in the `!alreadyTaken` branch — a taken dose renders static
text with no button — and `markTaken` is insert-only and cannot reach `unlogDose`. So the dashboard
log path is usable for verification; the Calendar tab is not.

If a check needs a logged dose, create it and read it back — never toggle one.

Strike this section when item 1 lands. A rig hazard that outlives its cause is the `content_size`
trap again.

### Known state

The tree does **not** compile while item 9 is mid-rewrite (`cannot find 'ResultSheet' in scope`,
`extra argument 'idPrefix'`, type-check timeout). That is expected and is not a regression. **No
build attempt until every item above is coded** — a failing build that belongs to someone else's
half-finished file is not information. A batch does not go to the runner until it compiles locally.

`xcodegen generate` **is** required for this batch: `Tests/InjectBuddyUITests/AddFlowToDoseLogUITests.swift`
is a new file in a globbed directory and the generated `pbxproj` does not reference it. That is the
one case the "only on project-definition adds/removes" rule names — it is not a licence to run it
routinely. The test addresses `cta_add`, `kb_done` and the calculator's first text field, all of
which live in `CalculatorScreen.swift`, so its identifiers may need re-aiming once item 9 lands.
