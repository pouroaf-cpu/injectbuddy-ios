# App reference — the competitor's main app

Supplied 2026-08-01, after the onboarding set. **These are a feature reference,
not a styling one.** The gap they show is capability, and most of it is already
modelled in our database.

| File | Screen |
|---|---|
| `ref-01-protocol-details-calendar-inventory.png` | Protocol details — two-week calendar, inventory |
| `ref-02-protocol-details-history-danger.png` | Same screen — history, pause/end, danger zone |
| `ref-03-log-dose-details.png` | Log dose — date, time, dose, taken-from |
| `ref-04-injection-site-rotation.png` | Injection site picker with per-site state |
| `ref-05-site-notes-skip.png` | Site list end, notes, skip this dose |

---

## The gap, against what we already have

`LogDoseSheet.swift:8` says it in its own header: *"No body-site picker, no draw
volume — both columns exist on dose_log."* The schema is ahead of the app.

| Reference feature | Our schema | iOS today |
|---|---|---|
| Date | `dose_log.dosed_on` | ✅ collects |
| Time of injection | `injection_time`, `injection_timezone`, `injected_at` | ❌ |
| Dose amount | `dose_label`, `draw_ml` | ❌ |
| Taken from — which vial | `vial_inventory` (protocol_id, vial_count, vial_ml, concentration, unit, color) | ❌ |
| Injection site | `dose_log.site` | ❌ |
| Site rotation state ("New" per site) | derivable from `dose_log.site` history | ❌ |
| Scheduled vs actual | `scheduled_on` vs `dosed_on` | ❌ |
| Notes | **no column** | ❌ |
| Skip this dose | **no column** | ❌ |
| Protocol details screen | `saved_dosages` + `dose_log` + `vial_inventory` | ❌ no screen |
| Pause / End | `status`, `is_active` | partial |
| Adherence score | derivable from `scheduled_on` vs logged | ❌ |

**Seven of the eleven need no schema change at all.** The columns are there and
unused. Notes and skip need one column each; adherence is a derivation, not
storage.

The PWA already has the concepts too — `SiteRotation` renders "Recommended site"
on its dashboard, and `vial_inventory` is live with rows in it.

## What the reference does well, worth copying regardless of scope

1. **Danger zone with the consequence spelled out** — *"This protocol has no
   logged doses, so it can be permanently deleted. Any vials stay in your
   inventory. This cannot be undone."* It names what survives, not just what
   goes, and delete is only offered when it is safe.
2. **A legend on the calendar** — "Dose day" / "Today" as filled vs ringed, with
   labels. Not colour alone. Same rule we hold ourselves to.
3. **Consequence copy on the secondary path** — *"Logging a dose from here won't
   change your adherence score."* The user is told the effect before acting.
4. **Per-site state on the picker** — every site carries "New" or its last-used
   state, so rotation is visible at the point of choosing rather than something
   to remember.
5. **An explicit "None"** for both vial and site, with an explanation
   (*"Log without using anything from your supply"*). Skipping is a choice, not a
   blank.
6. **Skip this dose** as a first-class action. A missed dose is data.

## What NOT to copy

Dark theme and heavy translucency, again. Same constraint as the onboarding
reference: `UIUserInterfaceStyle: Light` is locked, all dark paths removed. Take
the structure and the copy discipline; leave the palette.

## Status

**Not scoped, not scheduled.** Recorded so it isn't lost. The work in flight is
the auth restyle, welcome screen and onboarding. This is a bigger conversation
than a styling cycle and belongs to the human.
