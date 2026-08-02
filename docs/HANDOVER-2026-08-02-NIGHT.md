# Handover — 2026-08-02, night

Written at a deliberate stop, at an item boundary, with nothing half-done. The capture
sweep is landed and pushed; the `Add` question is fully resolved and its test row
deleted; the board carries every finding below. **Nothing is in flight and nothing is
uncommitted.**

Branch `feature/tabview-shell`, tip `9b7d9b2` (plus this document). `BOARD.md` is
authoritative; `TASKLIST` on the cross-claude bus is the live queue.

**Why stopped here rather than pushed on.** The next item widens an assertion from 3
calculators to 15, which will produce a batch of failures that need careful triage —
and triage is the first thing that degrades. Behind it sits F-E, where the failure mode
is silently dropping one of four invariants. Both want a fresh context. This cost one
commit; losing an invariant costs a defect nobody can see.

---

## 1. What shipped

| | |
|---|---|
| `9b4afcb` | The default-size capture sweep, and a gate probe that can **see the rig's type size** |
| `32e5474` | **22 frames, one run, one SHA** — `IB2245754`–`IB2245775`. Fourteen screens photographed for the first time at any size |
| `9b7d9b2` | The `Add`-writes-a-BMI-row finding, driven; F-F re-filed; **BOARD rules 32–36** |

## 2. The queue, in the order the directing side set it

1. **Gate the CTA on `canSaveProtocol`.** Small, fully understood, closes a write. The
   flag exists, `AddScreen` honours it, `CalculatorScreen` never references it — one
   condition, not a design. **Then re-run the wiring assertions**: a CTA gate is exactly
   the kind of change that silently disables a button somewhere it should still work.
2. **Widen D12's aim to all fifteen** (`PinnedBarReachabilityUITests`). Measurement, no
   layout change. Design in §4 below.
3. **The default-size shears**, enumerated from (2) rather than from the frames.
4. **Delete the two dead `isIntermittent` entries** in `LeafOverlapUITests`.
5. **F-E**, the picker overflow. Unchanged in shape — see
   `HANDOVER-2026-08-02-EVENING.md §2`, which is still accurate and still worth reading
   in full. Its four invariants and inverted pass condition have not moved.

## 3. What the sweep found

Fourteen of fifteen calculators had never been photographed at any size. All of this is
at **default** — the size everyone has been looking at for three days.

**`Add` writes a protocol row from a calculator that computes no dose.** Driven on BMI,
not inferred. It writes and advances to the start-day confirmation, which reads **"ADDED
TO YOUR PROTOCOLS"** over a height and a weight and asks the user to *"Confirm the day
this protocol begins so the calendar and dose reminders line up."* **A body measurement
is given a start date and wired into a dosing schedule, and the app recruits the user
into doing it.** `status: draft` is not a mitigation — `savedDosages()` filters on
neither `status` nor `is_active`, so the row is in the protocol list the moment it is
written. Test row `2d9d1bc2…` deleted; `bmi`/`freetest`/`plotter` back to 0. A baseline
count was taken **before** the tap, which is the only reason the write is attributable
rather than a story.

**An input sheared by the pinned bar at default size** — `IB2245770`, BPC+TB500,
`TB-500 bac water` cut through its own control with `Add` live below it. D12 word for
word, at the size everyone uses. F-A is the same defect at AX5 on a different screen.

**Result cards sheared at default** — BMI and Free T Index through `Normal`,
Semaglutide through `Units (U-100)`. Nothing watches result rows against the plate.

**A primary CTA reports `enabled=true`, `hittable=false`** at (16, 687, 370, 72), with
`AXScrollToVisible` failing. Either the a11y framework is wrong about it — which matters
for VoiceOver and Switch Control users, who reach that button through exactly the
mechanism reporting it unreachable — or it is genuinely occluded and a thumb has the
same problem. Unresolved on purpose.

**`Cycle Plotter` is absent from Tools.** `CalculatorCategory.members` enumerates 14 of
15 slugs; `.cyclePlotter` is in none, while `ToolsScreen`'s own comment says it shows all
of them "including … the plotter". Reachable only via the dashboard `Add a protocol`
dialog, eight drags in.

**F-F is a different and worse finding than the one filed.** Re-filed as: *on a dosing
app, "not medical advice" is never legible without scrolling for it.* At rest on all
fourteen the disclaimer is below the display (y 909.67–1120.67), inside the tab bar's
region (BPC-157 at y 841.67, bar starts 792), or under the pinned bar (six at y 761.67).
On those six the tree reports a 19.33 × 13.0pt intersection with the hero **and the
string is not drawn at all** — proven by cropping `IB2245765`, not by trusting the
number. It is deterministic, not intermittent.

**F-B is five screens, not one.** F-F was six, not fourteen. Same correction twice: a
finding filed from the screens that happened to be photographed states its scope as its
sample.

## 4. Item 2's design, so it is not re-derived

It was written and then **reverted deliberately** rather than committed unrun — running
it and triaging the failures *is* the item, and unrun tests are the one thing this
project does not ship. What it was:

- Eleven new methods on `PinnedBarReachabilityUITests`, **one per screen, not a loop**:
  a loop that fails on the third calculator stops measuring the remaining eleven, and
  the point is to learn how many screens are affected in ONE run.
- **Fourteen, not fifteen.** `Cycle Plotter` is not a `CalculatorScreen`, renders no
  `bar_plate`, and there is no plate edge to measure against. Exclude with the reason
  stated, not silently.
- **`openCalculator` asserts no destination.** It navigates and measures whatever it
  lands on. Measuring the wrong screen is quieter than photographing one — the run goes
  green about a screen nobody asked about. Add the nav-bar-title assertion
  (`CaptureCurrentState.openCalculator` has the working form).
- Expect `BPC+TB500` **red at default**. That is the point of adding it.
- `assertReachable` **already** asserts `add.isHittable`, so widening will also surface
  the BMI hittability finding directly.

Result rows against the plate are a **second, more delicate** change and were not
attempted: distinguishing the in-scroll result card from its pinned duplicate is the
`result_<label>` ambiguity that cost a session once already.

## 5. Rules added — `BOARD §5`

**32** and **33** were cited as settled by the TASKLIST, by the directing side, and by a
comment inside `AuditFolderConsistencyTests`, with **no text behind either number** —
§5.31 aimed at the rules list itself. Landed. Three more the sweep earned:

- **34 — the accessibility tree has no z-order and no clipping.** A geometry check knows
  where things are and nothing about whether they are visible. The newest check we have
  can report a collision between things nobody can see, **and** go green over content
  that is not legible. Never read a red overlap as a visible defect without looking at
  the frame.
- **35 — an assertion can observe the wrong MOMENT rather than the wrong thing**, and
  fails in a way that reads like a finding. A probe that is greener than the run it
  models is not a simpler version of it.
- **36 — a check must be able to observe the condition its output asserts.** `bar_gate`
  published `ax=true/false`, identical at `large`/`xLarge`/`xxxLarge`, while every
  filename in a default sweep asserted "default". Seventh check found reporting success
  while observing nothing.

Worth adding later: the folder-consistency check's sibling — assert that every `§5.NN`
cited anywhere in the repo exists in `BOARD.md`.

## 6. Needs the human — four items, none blocking

1. **QA password rotation** is still outstanding. Relayed over the cross-claude bus on
   2026-08-02 and sitting in the bridge's message database on **both** machines.
2. **NEW — the QA account email is in an `.xcresult` on the Mac.** A temporary probe
   dumped the screen's whole static-text list to diagnose the `Add` outcome, and the
   drawer's contents were in it. Nothing was committed and the probe is deleted, but the
   artefact is on disk: the `testTEMPAddOnBMI` run under
   `~/Library/Developer/Xcode/DerivedData/InjectBuddy-*/Logs/Test/`, 2026-08-02 ~05:04
   PDT. Same copy-count problem as the password; the fix is deletion. Self-caught, and
   the discipline is adopted: no untargeted tree dumps.
3. **Auto-login is not configured on the Mac.** Convenience, not a blocker — the
   recurring "taps are dead" failure is a shell in the `Background` launchd domain, not
   a login screen.
4. **Database `CHECK` constraints** on `profiles.preferred_*` and `logging_interests`
   (C4). And now arguably a second one: nothing at the database level stops a
   `calculator_type` that cannot produce a dose from being written to `saved_dosages`.

## 7. Rig state

iPhone 16 Pro / iOS 18.3, booted, signed in as `devtools`, **content size reset to
`large`** (set and reset in the same command every run, C6). Not erased, so first-run
paths still have no coverage — do not read a green suite as evidence that first run
works.

`AuditFolderConsistencyTests` green in both directions against the new folder — 27
files, 27 rows, all distinct by md5. The capture sweep is green end to end.
`LeafOverlapUITests` unchanged and still carries its eight AX5 debts and four default
ones, two of which are now known to be **dead entries** (item 4).
