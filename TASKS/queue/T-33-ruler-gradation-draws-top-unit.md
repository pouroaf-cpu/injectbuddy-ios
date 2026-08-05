## T-33 — A ruler gradation draws on top of the unit label on TRT, at DEFAULT size
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** measured on `TRT Dose`, default text size, at rest, by `LeafOverlapUITests/testTRTDose`:

```
StaticText 'unit_nDays'  (217.3, 573.3, 33.3, 18.0)
StaticText '3'           (244.2, 583.2,  7.0, 13.3)
shared region            (244.2, 583.2,  6.4,  8.1)
```

The `3` is a `TickDrum` gradation label. It is drawn ON the `days` unit of the `Every N days` row —
**a value+unit pair with a number from a different control printed through it**, 6.4 x 8.1pt of
shared pixels. A reader sees `days` with a stray digit in it, on the field that decides how often
they inject.

**Why it is filed and not fixed in this pass:** it is not the picker defect and not caused by the
combobox — it is `TickDrum` from T-01a #7 sitting too close to the numeric row's unit, and it has
been there since that commit. Fixing it means changing the numeric row's layout, which is the same
control T-20 is already open against and eleven calculators render through. One change, one pass.

**Why it was not seen before:** this run is the first time `testTRTDose` has been run since T-01a
landed, and at the time the suite reported only ONE pair per screen (T-34, now fixed). **There may
be more behind it — the count of one is not claimed**, and `testTRTDose` has not been re-run since
T-34; when it is, expect the same shape of result `Steroid Dosage` gave (one reported, ten actual).

**Done when:** the drum and the unit label do not share pixels at default size or AX5 on TRT, shown
by `LeafOverlapUITests/testTRTDose` green with no new `expectedOverlaps` entry — and re-checked on
one calculator outside the top five, since eleven render this row.
