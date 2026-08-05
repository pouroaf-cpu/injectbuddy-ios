## T-21 — Two of five cards state no dose, because the engine refuses two whole shapes of config
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** T-53 gave every protocol card a per-injection dose derived from its config. Two of the QA
account's five state none, for two different reasons, and both are real config shapes in production:

1. **A steroid row saved in `perweek` or `ml2mg`.** `CalculatorEvaluate` hardcodes `mode: .ndays`
   for `.steroid` (`injPerWeek: 0, mlDrawn: 0`), so `DoseVolume.modeIsEvaluatedAsSaved` refuses the
   row rather than evaluate it in a mode it was not saved in. The QA `Masteron` row is
   `mode: perweek`, and production holds **9 steroid rows across 5 users**. This is the same defect
   T-01a #1 fixed for TRT — `mode` became a real field there and never did here.
2. **A weekly dose of 0.** `Testosterone Cypionate · 0mg/wk` evaluates to `mlPerInj = 0`, which the
   engine calls invalid, so no dose and no volume. The web renders it as `0 mg`.

**Why it matters:** it is not only the card. The same gate feeds `draw_ml` (so these protocols log a
NULL volume and consume nothing from the vial — see the `NewDoseLogPin` header) and it now feeds
T-52's amount field, so **a Masteron user cannot record a partial dose at all**: no derived amount
means no field to correct.

**Done when:** a steroid protocol saved `perweek` states a dose per injection on its card and logs a
non-NULL `draw_ml`, verified by a `select` on a row logged from the sheet.
