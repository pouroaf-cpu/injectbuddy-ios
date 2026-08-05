## T-62 — iOS corner radii are roughly double the web's, everywhere
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** the web's radius scale is one token with two derivations — `app/globals.css:34` sets
`--radius: 0.5rem` (**8px**), and `tailwind.config.ts` derives `lg: var(--radius)` (8px),
`md: calc(--radius - 2px)` (6px), `sm: calc(--radius - 4px)` (4px). iOS uses
`Theme.Radius.card = 16` and `.control = 10`.

**So every card is twice as round as the web's and every control is not far off it.** It is the kind
of difference that reads as "a different app" without any single element looking wrong, which is why
it survived a token-level parity pass that got the colours right.

**Priority 4 deliberately:** nothing is unreadable and no number is wrong. It is a systematic visual
divergence, so it belongs with T-54's header treatment rather than ahead of any dosing item — but it
is one line to change and it touches every screen.

**Recorded alongside, not filed as tasks — two web mechanics iOS has no concept of:** a **grid-beam
wayfinder** background (`public/app.js:4347+`) — a static teal SVG grid with six animated beams that
travel along the grid lines toward the next unanswered calculator field — and a **chrome-shimmer
border sweep** (`public/ib-calc.css:1642-1830`) marking that field. Both are recent, both are
wayfinding rather than decoration, and **both postdate `DESIGN.md`, which still says the grid
backdrop was removed.** They are the visual half of the same idea as T-01a's mode switcher: the web
tells you where you are in the form. Whether iOS should have an equivalent is a product question, not
a parity defect — raised here so it is a decision rather than an oversight.

**Done when:** the radius scale matches the web's, or the divergence is recorded here as deliberate
with a reason.
**Root cause: the card drew `label`, and iOS writes a CONSTANT into `label`.**
`CalculatorViewModel` saves `label: spec.saveTitle` — the calculator's own screen title. Every TRT
protocol saved on iOS is therefore literally named "TRT Dose", and `ProtocolLabel.split` finds no
` · ` to take a dose half from, so the supporting line was empty. The two rows on the QA account are
real and differ only in `mgWeek` — 137 and 149:

```sql
select id, label, config->>'mgWeek' mg_week, config->>'strength' strength, config->>'mode' mode
from saved_dosages where user_id = 'c8926abc-52b0-41f3-8968-bc44f56e1dd1'
  and calculator_type = 'trt' and label = 'TRT Dose';
```
```
249135d4 | TRT Dose | 137 | 200 | perweek
d94cc62b | TRT Dose | 149 | 200 | perweek
```

**Built:** `Core/Calculator/ProtocolSummary.swift`. The line is derived from the CONFIG, never from
the label — dose per injection, interval, what is in the vial, and the compound where the heading
does not already name it. **One unit convention, per injection**, which is the web's own `doseLabel`
convention (`lib/account-schedule.ts` — every branch states the dose for one injection) and closes
S-04 #5's three-conventions-in-one-list at the same time.

**Distinguishability is guaranteed rather than hoped for.** `ProtocolSummary.lines(for:)` renders
the whole list at once and, where two cards would still read alike, appends the config keys that
actually differ. Two rows cannot be identical in `calculator_type` + `config` — the unique index
forbids it — so a differing key always exists to name. Unit-tested on the pair the derived language
genuinely cannot separate (same weekly dose, same interval, same vial, same ester, one saved
`perweek` and one `ndays`): the lines come out `… · mode perweek` and `… · mode ndays`.

**Done — measured.** `LogDoseAmountRoundTripUITests` reads every card's rendered text off the device
and fails if any two are equal. Against the account in the frame:

```
T-53 CARD: TRT Dose                          | 74.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate
T-53 CARD: TRT Dose                          | 68.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate
T-53 CARD: TB-500 (Thymosin Beta-4)          | 350 mcg · every 1.75 days · 25 mg in 3 mL
T-53 CARD: Masteron (Drostanolone) Enanthate | every 3.5 days · 200 mg/mL
T-53 CARD: Testosterone Cypionate            | every 1.08 days · 250 mg/mL
```

The first two are the pair from the frame — same heading, and now `74.5 mg` against `68.5 mg`,
which is `149 ÷ 2` against `137 ÷ 2`. Photographed:
`docs/ui-audit/2026-08-04-logdose/01-logdose-sheet-t5352.png`.

**Not fully closed by this, and filed as T-21:** two of those five cards state no dose at all —
`Masteron` because it was saved in a mode `evaluate` does not run, `Testosterone Cypionate` because
its weekly dose is 0. They are distinguishable, which is what this task asked for, but "one
convention" is still "one convention and two blanks".
