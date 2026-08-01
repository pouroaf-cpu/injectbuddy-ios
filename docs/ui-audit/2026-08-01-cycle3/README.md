# Build cycle 3 — dedup, and the bug it uncovered

| File | Shows |
|---|---|
| `01-calculator-before-save.png` | TRT Dose ready to save; short-form dead space now distributed |
| `02-save-first.png` | Save #1 succeeds → "Start day" confirm, config includes `Syringe Ml: 1` |
| `03-save-second-dedup.png` | Save #2 of the identical config succeeds with **no error** |
| `04-dashboard-after-two-saves.png` | Dashboard after both saves |

## Saving a protocol from iOS was broken, and had nothing to do with dedup

The first run of the acceptance test failed on the *first* save, before dedup could
matter, with:

> new row violates row-level security policy for table "saved_dosages"

`saveDosage` inserted `calculator_type, label, config, start_date` and **no
`user_id`**. Every read on this table omits `user_id` deliberately — RLS scopes
selects — and that assumption was carried into the write, where it does not hold:
the INSERT policy is a `WITH CHECK (user_id = auth.uid())`, so a row without it is
rejected outright.

This is not a regression from the unique index. A unique index cannot produce an
RLS error. It predates cycle 3 and it means **saving a protocol from the iOS app
has never worked** — every row in `saved_dosages` was created by the web.

Fixed by sourcing the id from the live session inside the data layer
(`client.auth.session.user.id`), so there is one place that can get it wrong rather
than one per call site.

## Dedup result

- **Save #1** → succeeded, navigated to the confirm-start-day screen.
- **Save #2**, identical config → succeeded, **no error shown**.

The index is `UNIQUE (user_id, calculator_type, config)` and both saves sent the
same config, so the second insert necessarily raised `23505`. It surfaced no error,
which means the recovery path caught it and returned the existing id — the database
cannot have accepted a second row. Dedup holds.

**Caveat on the evidence.** I could not count rows to show it directly: new saves
appear to land as `status='draft'` / `is_active=false` (the same shape as the six
rows deduped during the migration) and the dashboard's protocol list does not show
them. So the conclusion above is inference from "no constraint error surfaced",
not a row count. A `SELECT count(*) FROM saved_dosages WHERE calculator_type='trt'`
before/after would settle it directly, from a side that has DB access.

**Rows this test created in production:** at least one `trt` protocol, label
"TRT Dose", start_date today. It is real data on the live account and should be
deleted if unwanted.

## Also in this cycle

- `.upsert(onConflict:)` was **not** used. PostgREST resolves upsert to
  `ON CONFLICT DO UPDATE`, which writes every column in the payload over the
  surviving row — including `start_date`, which `save()` always sets to today.
  Re-saving an identical protocol would silently reset a start date the user had
  corrected on the confirm screen, shifting every projected occurrence on their
  calendar. Insert-then-recover leaves the existing row untouched, which is both the
  web's behaviour and the one that cannot corrupt a schedule.
- Stale `/api/dosages` comments corrected in 5 files.
- Over-capacity copy is now ratio-keyed: ≥4 fills reads as a probable typo rather
  than a split. Same warning triangle either way — the distinction is in the words,
  never in styling alone.
- Short calculator forms no longer pool their slack into one void above the pinned bar.

## Gradient diagnostic — the fork, answered

Bare `LinearGradient` in a `Rectangle`: no mask, no `Text`, no animation.

| Sample | Rendered |
|---|---|
| Gradient at pt x=20 / 200 / 385 | `#4B5557` / `#798A8D` / `#4B5557` |
| `Theme.tealTextStrong` **solid**, same screen, same frame | `#075E56` ✓ |

The ramp has the right *shape* — dark, light, dark — and completely the wrong
chroma. Same colour value, same screenshot: solid renders true teal, gradient
renders grey.

**The gradient is at fault; the mask is innocent.** Note `#4B5557` is exactly what
the greeting text measured in cycle 2, so the greeting was faithfully rendering the
gradient's own (wrong) colour all along.

Unverified hypothesis, offered only as a starting point: `#075E56` has a red channel
of 7, and interpolation in a linear-light space lifts the darkest channel hardest —
R goes 7 → 75 while G and B barely move, which is what desaturation of a dark
saturated colour looks like. Not tested. The greeting stays solid until it is.
