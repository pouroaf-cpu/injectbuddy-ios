## T-92 — iOS clamps GLP-1 concentration at 60 mg/mL; the deployed web has no upper bound
**Priority 3/10** · **Owner:** mac · **Status:** open

**What it does now:** T-45 set the `conc` field's range to `0...60`, the bounds of
`GLP1_CONC_VALUES`, which is exactly what `feature/dosage-status-model`'s `QuickPickerField` clamps
to. The **deployed** build does not clamp at all — `ConcDrumField` accepts any positive number and
only rounds it to 2 dp. So a vial above 60 mg/mL is typeable on the live site and is snapped down to
60 on iOS.

**Why it is a 3.** 60 mg/mL is already multiples of any GLP-1 vial that exists; nothing in the
production protocol mix comes close. And iOS's clamp REWRITES THE VISIBLE TEXT when it bites, so a
refused value is seen rather than silently absorbed — this cannot produce a wrong number shown as a
right one, which is the class that earns a high priority on this list.

**The real finding underneath it** is that the two web builds disagree about whether concentration
has a ceiling at all, and `TASKS.md`'s ordering of truth puts the deployed build above the branch.
Whichever wins, iOS should copy it rather than pick.

**Done when:** the web has one answer and iOS matches it.
