# GLP-1 option lists — the web's authoritative values, for T-45

**Why this file exists.** T-45's agent died on a session limit mid-verification. This is the web half
of that task, extracted from the source so the restart does not re-derive it. Every value below is
read from `C:\Users\PFrew\Projects\Injectbuddy\public\app.js` on branch `feature/dosage-status-model`
— the working tree, which outranks the live site and the 2026-07-31 captures.

**The finding, restated from the web side.** iOS truncates each list *exactly at the web's warning
threshold*. That looks like a safety measure and is the opposite of one, for two reasons:

1. **The web does not treat the threshold as a ceiling. It treats it as something to say out loud.**
   Above it the value is still selectable and an orange `InfoBox` appears. Deleting the options
   deletes the warning with them, so iOS is silently stricter *and* silently quieter.
2. **The truncation removes correct options, not just extreme ones.** Concentration is the clear
   case: iOS stops at 20 mg/mL, so **a 25 mg/mL vial has no entry**. A user holding one picks 20 and
   draws **25% too much**. That is a wrong number reached through the UI working as designed.

## Concentration — `GLP1_CONC_VALUES` (`app.js:3922`)

```
0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60
```

**17 entries.** iOS ships the first 12, stopping at 20. **Missing: 25, 30, 40, 50, 60 mg/mL.**
There is no warning attached to concentration at all — it is not a dose, it is a property of the vial
the user already owns. **Nothing about a high concentration is unsafe to state; being unable to
state it is.**

## Dose lists

| | web values | web max | iOS stops at | warning above |
|---|---|---|---|---|
| Semaglutide `SEMA_DOSE_VALUES` (`:3919`) | `0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.4, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5` | **7.5** | 2.4 | `> 2.4` |
| Tirzepatide `TIRZ_DOSE_VALUES` (`:3920`) | `0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5, 35, 37.5, 40` | **40** | 15 | `> 15` |
| Retatrutide `RETA_DOSE_VALUES` (`:3921`) | `0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24` | **24** | 12 | `> 12` |

## The warnings iOS deleted along with the options

Verbatim, all three, same shape and same colour — `InfoBox` with `accent: '#f97316'`:

- `app.js:10242` — `isValid && dose > 2.4` → **"Exceeds typical weekly maximum of 2.4 mg — verify with your prescriber."**
- `app.js:10368` — `isValid && dose > 15` → **"Exceeds typical weekly maximum of 15 mg — verify with your prescriber."**
- `app.js:10493` — `isValid && dose > 12` → **"Exceeds typical weekly maximum of 12 mg — verify with your prescriber."**

Note the wording: *typical*, and *verify with your prescriber*. The web is deliberately not asserting
a hard clinical limit — it is flagging and deferring. An app that instead removes the option asserts
a limit the web declined to assert, while giving the user no way to record what they are actually
taking.

## The control, and why the fix is not just "add the missing values"

Each dose field is a `SliderField` with **both** a continuous range and a drum list
(`app.js:10227`, `:10354`, `:10479`):

| | `min` | `max` | `step` | drum |
|---|---|---|---|---|
| Semaglutide | 0.25 | 7.5 | 0.25 | `SEMA_DOSE_VALUES` |
| Tirzepatide | 2.5 | 40 | 2.5 | `TIRZ_DOSE_VALUES` |
| Retatrutide | 0.5 | 24 | 0.5 | `RETA_DOSE_VALUES` |

Concentration uses `QuickPickerField` with `values: GLP1_CONC_VALUES` (`app.js:10225`), which
**also accepts typed entry**. So on the web the list is a set of conveniences over a continuous
range — not the set of permissible values.

**On iOS it is a closed `Menu`, so the list IS the permissible set.** That is the actual defect:
the same array means "suggestions" on one platform and "the only legal answers" on the other. Adding
the missing entries closes the 25 mg/mL hole, but two vials from now there will be another one.
**The durable fix is a control that accepts a value outside the list**, with the warning restored
above the threshold.

## Restart checklist for T-45

1. Extend the four arrays to the values above — this alone fixes the 25 mg/mL draw error.
2. Restore the three warnings, verbatim, at `> 2.4` / `> 15` / `> 12`.
3. Make the concentration field accept a value not on the list, so the next unusual vial is not a
   new defect.
4. **Measure it:** a saved GLP-1 protocol at 25 mg/mL read back out of the database, and a frame
   showing the warning rendered above the threshold. Not "the picker has more entries now".
