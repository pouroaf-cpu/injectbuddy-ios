# Input control inventory — every distinct control, measured

Measured off the running app at both default and AX5. Nothing fixed; this is the
scope, not a change.

## Answer in one line

**No — not universal. The calculator family is; four things outside it are not:
the log-dose date chip, the toggle, the log-sheet row treatment, and the same
primary button rendering two different heights at AX5.**

## Default size

| Control | Where | Height | Radius | Border | Fill | Label | Unit |
|---|---|---|---|---|---|---|---|
| Numeric field + inline unit + ± | TRT, BMI, all `.number` specs | **44.0 pt** | 10 | 1 pt `#8E8E93` | white | above, outside | **inline** |
| Menu picker | Frequency, Ester, **Syringe barrel** | **44.0 pt** | 10 | 1 pt `#8E8E93` | white | above, outside | n/a |
| Toggle | BMI "Imperial units" | **≈31 pt** (system `UISwitch`) | pill | none | system | above, outside | n/a |
| Protocol row | log-dose sheet | **44.0 pt** | section corners only | none — `#C6C6C8` separator | white | leading, inline | n/a |
| Date row / **chip** | log-dose sheet "Day" | row 43.7 pt / **chip 34.3 pt** | small | none | `#EEEEEF` | leading, inline | n/a |
| Primary button | Mark taken, Add, Log dose | **72.0 pt** | 10 | none | navy `#001D5C` | centred | n/a |
| Category row | Add tab | **66.7 pt** | section corners | none — `#C6C6C8` | white | leading, 2-line | n/a |

## AX5

| Control | Default | AX5 | Growth |
|---|---|---|---|
| Numeric field + ± | 44.0 | **77.35** | 1.76× |
| Menu picker | 44.0 | **77.35** | 1.76× |
| Log protocol row | 44.0 | wraps to 3 lines, grows freely | — |
| Date chip | 34.3 | **≈52.7** | 1.54× |
| Primary button — **calculator** | 71.7 | **91.3** | 1.27× |
| Primary button — **log sheet** | 72.0 | **71.7** | **1.00× — does not grow** |

Nothing clips: every control grows enough for its own text. But they grow at four
different rates.

## The two suspicions

1. **"Pickers are probably not the same height as the ± fields."** — **Killed.** Both
   are exactly **44.0 pt** at default and **77.35 pt** at AX5. They match because
   cycle 2 put `minHeight: Theme.minTarget` on the pickers as well as the fields, so
   both are floored by the same constant and grow on the same font metric. The barrel
   picker added later inherited it. `01-` / `02-`.

2. **"The log-dose sheet is the screen most likely to be off-family."** — **Confirmed,
   and it is the worst of the set.** Two separate problems:
   - **The date chip is 34.3 pt** — under the 44 pt floor, and it *is* the tap target
     for changing the dose date. `07-date-chip-crop.png`.
   - **Its rows are a different visual language.** Same 44 pt height as a calculator
     field, but separator-delimited list rows on white, versus bordered boxes with a
     `#8E8E93` stroke and a 10 pt radius. Height matches; radius, border and fill do
     not — which is exactly the "same height, still looks wrong" case.

## The other two, neither of which was on the list

3. **The toggle is ≈31 pt** — the system `UISwitch` at its fixed size. Under 44 pt,
   and off-family in every property: pill radius, no border, system fill. It is the
   only control in the app that cannot be resized without replacing it.

4. **`PrimaryButton` renders two different heights at AX5** — 91.3 pt on the
   calculator, 71.7 pt in the log sheet, from the *same* component. The log sheet
   places it inside a `List` row with `.listRowInsets(EdgeInsets())`, which constrains
   it; the calculator places it in a `VStack` where it grows. Same code, two results,
   and the log sheet's is the one that stops scaling.

## Not inputs, listed for completeness

Add-tab category rows (66.7 pt) and drawer nav rows are navigation, not data entry,
so their height difference is not a family violation.

## Not covered

The confirm-start-day screen and Settings were not reached in this pass — a drawer
mis-tap landed on BMI instead of Settings, which is why `05-` shows BMI. BMI's fields
measured 44.0 pt, consistent with the family. Settings' own rows are stock
`Form`/`List` and are very likely the same 44 pt list-row treatment as the log sheet,
but I have not measured them and am not going to claim them.
