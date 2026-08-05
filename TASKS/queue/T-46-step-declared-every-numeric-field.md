## T-46 — `step` is declared on every numeric field and read by nothing

**RENUMBERED from T-45 by mac, 2026-08-04.** T-45 was already handed to the GLP-1
truncation job before this was filed — my allocation error, not the filer's. Two tasks under one
ID is the exact failure rule 10 exists to prevent, and it recurred inside my own block because I
handed out IDs from it without recording them. Worth noting the block scheme only protects
BETWEEN the two sides; WITHIN a block it protects nothing unless issued IDs are written down as
they are issued.
**Priority 3/10** · **Owner:** mac · **Status:** open

**What it does now:** `CalculatorInput.Kind.number` carries a `step`, fifteen calculators declare one
(`0.5` days, `0.05` mL, `10` mg/week…), `FieldRow` passes it into `NumberField`, and `NumberField`
stores it in a `let` that nothing reads. It became inert when the hand-rolled `−`/`+` pair was
replaced by `TickDrum`, which moves in `drum` values instead. **The web snaps to its step on blur**
(`commitDose`: `Math.round((clamped - min) / step) * step + min`); iOS does not snap at all, so a
peptide dose of `0.4567 mg` is accepted where the web would settle it to `0.457`.

**Why this is a 3 and not higher.** No wrong number is displayed and no wrong number is saved — the
field shows exactly what the engine uses, which is the invariant that matters. What is lost is
tidiness of entry, and the value is the user's own typing rather than something the app invented.

**Why it is filed at all:** a spec field that states a number nobody honours is a trap for whoever
wires it up next. It was found during T-41, where the step had to be made unit-dependent to be
correct — and it is correct now, and still unread. Either snap on blur like the web, or delete
`step` from the model.

**Done when:** either iOS snaps to `step` on blur and a test pins `0.4567 mg → 0.457`, or `step` is
gone from `CalculatorInput.Kind.number` and its fifteen call sites.

**Found by:** T-41, 2026-08-04.
