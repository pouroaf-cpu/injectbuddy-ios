# Protocol detail — spec (T8), and a finding found while writing it

Win, 2026-08-03, from the PWA source on the Windows box (`components/account/ProtocolList.tsx`,
`dashboard/DoseEditorModal.tsx`, `protocol-meta.ts`) and the iOS source at `efb4f9e`.

T8 was the only queued route with no spec. This is it. §1 is a defect I found while writing it and
it is more urgent than the route.

---

## 1. FINDING — iOS shows protocols the user has stopped

**`SavedDosage` has a `status` column. iOS has never heard of it.**

The PWA models three states, and the comment in `ProtocolList.tsx:18-20` is explicit:

> `active` is running (inventory, sites, forecast); `draft` is saved-but-not-running; `archived`
> is a stopped protocol kept for history (**never deleted**). `is_active` in the DB is kept in
> sync with status by a **trigger**, so the dashboard/rail keep reading `is_active`.

iOS `SupabaseBackendClient.savedDosages()` selects:

```
id, calculator_type, label, config, created_at, start_date, is_active
```

`status` is **not in the select list**, and there is **no filter on either column**, ordered by
`created_at` only. So:

- A protocol the user **archived** on the web — deliberately stopped, kept for history — still
  appears in the iOS protocol grid.
- A **draft** appears identically.
- Nothing on the iOS card distinguishes any of the three. The PWA renders a status badge with a
  colour and a dot per state (`STATUS_META`); iOS renders none.
- Ordering compounds it: the PWA sorts by `STATUS_RANK` (active → draft → archived) so stopped
  protocols sink. iOS sorts by `created_at` alone, so an archived protocol from March can sit
  **above** the one the user is actually running.

**This is the same root as the `Add`-writes-a-BMI-row finding: the iOS protocol list has no
concept of which rows belong in it.** One end writes rows that should never exist; the other end
displays rows that were deliberately retired. Neither end filters.

**Not knowable from here:** how many live rows are `archived` or `draft`. That is a query against
production and it decides whether this is cosmetic or whether users are looking at a list of
protocols they thought they had stopped. Worth running before the fix is scoped.

**Fix direction, not a decision:** add `status` to the select, filter to `active` + `draft` for
the dashboard grid, sort by status rank then `created_at`, and render the badge. Archived becomes
reachable from the detail route (§3) rather than from the grid. Do **not** filter on `is_active`
instead — it is a trigger-maintained mirror, so it is a derived column and `status` is the source
of truth. Reading the mirror is how iOS ended up blind to the third state.

---

## 2. What the PWA actually offers on a protocol

Two surfaces, and iOS has neither.

**`ProtocolList` row actions** — rename, set status, set start date, delete.
**`DoseEditorModal`** — opened by tapping a dose in the schedule: start date + vial supply.

The important detail is that these are the same object edited from two places, and the PWA keeps
them in sync through a shared dashboard context rather than a refetch.

### The actions, with their real semantics

| Action | Mechanics | The bit that matters |
|---|---|---|
| **Rename** | `PATCH { label }` | Free text. A user-set nickname never collides with the auto-numbering (§4). |
| **Set status** | `PATCH { status, is_active }` | Both are written together client-side even though a trigger mirrors them — belt and braces. Archiving drops it off the dashboard without deleting it. |
| **Set start date** | `PATCH { start_date, is_active: true, status: 'active' }` | **Setting a date activates the protocol.** The PWA's own comment: *"you can't schedule something that's switched off."* This is a one-control-two-effects behaviour and iOS must reproduce it or diverge deliberately. |
| **Delete** | `DELETE`, behind a confirm | The only destructive action. `archived` exists so deletion is rarely the right answer. |
| **Vial supply** | inventory panel, injectables only | Orals show *"Oral protocol — no vial to track. Edit the dose in the calculator."* |

### Two behaviours worth copying verbatim

**Setting a start date activates.** Not a side effect to clean up — it is the model. A protocol
with no start date is saved but not running.

**Orals are told why they have no vial panel.** An empty state that explains its own absence,
which is the same instinct as `COMPETITOR-NOTES §5.5`.

---

## 3. The iOS route

`ProtocolCard` renders a chevron and there is no destination. Build the destination.

**Push, not a sheet.** The chevron already promises a push. A sheet would be a second divergence
on top of an unfulfilled promise.

**Contents, top to bottom:**

1. **Header** — the protocol's display name, the calculator-type pill, and the dose line.
   Use `protoDisplay()`'s two-line split (§4) so the name reads the same here as on the card.
2. **Status** — the badge, and the control that changes it. Three states, named, not a toggle.
   A toggle cannot express three states and `archived` is the one users need and iOS lacks.
3. **Start date** — a date control, with the consequence stated on screen: *sets the schedule and
   activates it*. The PWA prints exactly that next to the field; copy it. A control with two
   effects must say so.
4. **Config summary** — read-only. The values the protocol was saved with. Editing them means
   re-running the calculator, which is the PWA's model too.
5. **Vial supply** — injectables only, with the oral explanation for the rest.
6. **Delete** — last, behind a confirm, and the confirm says what survives.
   `COMPETITOR-NOTES §5.1`: say what survives, not just what is lost.

**Writes go to PostgREST directly, not `/api/dosages`.** iOS bypasses the web API — that is settled
and it is why dedup had to be a unique index at the database. Every PATCH above is a PostgREST
update against `dosages` with the RLS `user_id` present. **`user_id` omitted is exactly how "saving
a protocol from iOS had never worked" happened on 08-01** — every insert refused by RLS. Assert a
write actually landed by reading it back, not by the call returning.

---

## 4. Display rules iOS must not re-invent

These are in `protocol-meta.ts` and are shared by three surfaces on the web so they cannot drift.
Port them; do not approximate them.

- **`protoDisplay(row)`** splits a saved label into primary/secondary on `· — → +`, and puts the
  **compound on top when the other half starts with a digit**. So `250mg · Test E` displays as
  `Test E` over `250mg`, not the order it was stored in.
- **`abbrevCompound`** is ordered **longest-first** deliberately: `Testosterone Cypionate` must
  match before the bare `Testosterone`. A naive dictionary gets this wrong and produces `Test
  Cypionate`.
- **`compoundColor`** is per-**compound**, not per-row, so every `Test E` card is the same colour
  everywhere. Anchored hues for the common esters, deterministic hash for the rest. The web notes
  it "MUST stay byte-identical" to its own rail implementation — iOS is now a third implementation
  of the same hash and will drift unless it is ported exactly and tested against known inputs.
- **`dedupeNames`** numbers repeats — first `Test E` stays `Test E`, then `Test E (1)`. A
  user-set nickname has a distinct title so it never collides and never gets a number.

**Test the hash with fixtures.** A colour hash that silently disagrees between platforms is a
divergence nobody reports as a bug — it just looks slightly wrong on one device.

---

## 5. Deliberate divergences — decide these, do not drift into them

- **Archived visibility.** Web keeps archived rows in the same list, ranked to the bottom. Given
  §1, iOS should probably filter them out of the grid and surface them behind a filter or inside
  the detail route. That is a product call and it is the human's.
- **`start_date` semantics.** If iOS ships a start-date control that does *not* activate, the two
  clients disagree about what a date means. Copy the behaviour or change both.
- **Delete vs archive.** The web makes archive the easy path and delete the deliberate one. If iOS
  ships delete without archive, it makes the destructive action the only action.

---

## 6. What this unblocks

T8 is filed as "the chevron promises navigation and delivers none", which reads as a polish item.
It is not. The detail route is where **status** becomes visible and editable, and §1 says iOS is
currently showing protocols the user has stopped with nothing to indicate it and no way to change
it. The chevron is the symptom.
