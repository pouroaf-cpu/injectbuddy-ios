## T-15 — No saved config has been read back since `mode` became a real field
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** T-01a #1 moved `mode`, `nDays` and `mlDrawn` out of `configExtras` and into real fields,
and moved the default from `perweek` to the web's `ndays`. `configJSON()` and
`values(fromConfig:)` were both updated. **None of that has been observed against the database.**

**Why it matters more than it looks:** the unique index covers the WHOLE config, so the key set and
the types are what decide whether an iOS save is the same protocol as the equivalent web row or a
different one. A `mode` that serialised as a number, or a `nDays` that went missing because it is
now mode-gated in the form, would not fail a build and would not fail the unit suite — it would
quietly write a protocol the web reads as new. Exactly the shape of the config defects already
closed on this file (hcg, tirzepatide, retatrutide).

**Done when:** a TRT protocol is saved from the device in each of the three modes and the rows are
SELECTed back, showing eight keys with `mode` as the chosen string. Paste the rows.

**This prediction came true on the READ side (T-24, 2026-08-04)** before anyone checked the write
side. `DoseVolume.modeIsEvaluatedAsSaved` still said "trt means `perweek`" — the rule from before
`mode` was a field — and was silently refusing 21 of 39 TRT rows. No build failed, no test failed,
and the symptom was a NULL that looked like "this protocol has no volume". The write side is still
unobserved and this task still stands.
