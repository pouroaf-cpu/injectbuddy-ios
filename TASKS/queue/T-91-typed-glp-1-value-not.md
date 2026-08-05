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
