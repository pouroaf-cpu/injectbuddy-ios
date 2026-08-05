## T-64 — The web still ships an EOD calculator its own navigation points away from
**Priority 3/10** · **Owner:** pouroa · **Status:** open

**What:** raised by mac while executing T-12, and it is the same redundancy on the other platform.
`public/app.js` has a live `EODPage` that can POST `calculator_type: 'eod'`, while
`public/nav-items.js:23,59` point the `eod` nav id at **`/trt-calculator/`** — the same URL as `trt`.
So the web has two calculators behind one URL, and the TRT one now carries the `Every N Days` mode
switcher that makes the other redundant.

**Why it is the owner's call and not win's:** the owner's reasoning for iOS — *"that option is inside
the TRT calc anyway"* — applies identically here. But the web is the shipped, indexed product with
existing users, and removing a page from it is a different decision from removing an unshipped screen
from an app in development. **It is filed rather than done.**

**Why it is only a 3:** nothing is wrong today. The page works and produces correct numbers. It is
redundancy, not a defect — and `deriveDose` handles `eod` correctly, so a row created there behaves.

**Done when:** the owner decides whether the web's EOD page is retired into the TRT calculator's mode
switcher, or kept — and if kept, whether iOS should regain parity with it.

---

### Sweep record — the "guard bounds a different quantity" class, on the WEB, 2026-08-04

**Recorded because a clean sweep is a result, and because WHY it is clean is more useful than the
fact.**

T-81 found iOS's `DoseProjection.projectedDoses` accumulating `step` as *doses since the protocol
began* and comparing it against `days * 4 + 8`, a budget sized for *the display window*. Two
quantities, one variable, silent truncation — a live protocol sat at step 60 against a cap of 64 and
simply stopped appearing.

**The web was swept for the same shape and has none.** `lib/account-schedule.ts`,
`CalendarView.tsx`, `SerumChart` / `FullscreenSerumChart`, `ScheduleCalendar`, `DoseHistory`,
`lib/serum.ts`, `lib/cycle-schedule.ts`, `lib/site-rotation.ts`, `DashboardContext.tsx`, plus a
repo-wide grep for `while` / `for` / `MAX_` / `LIMIT` / `_CAP` / `slice(0,`.

**The reason is architectural, and it is the part worth keeping.** The web never generates a dose
series at all. Its primitive is `isDoseDay(p, date)` — a **pure per-date test**:

```ts
const d = wholeDaysBetween(p.startDate, date)
if (Number.isInteger(f)) return d % f === 0
const k = Math.round(d / f); return Math.round(k * f) === d
```

No accumulator, no loop, no budget — **so there is no seam where a counter and a differently-derived
cap could drift apart.** Every schedule surface calls this same primitive or `eventsForDay`, so the
property holds everywhere by construction rather than by remembering.

The one real loop-with-a-guard, `lib/serum.ts:93`, is sound: `guard` counts iterations of the loop it
bounds — the same quantity — and tops out around 150 for a daily protocol against a limit of 5000.

**What this says about T-81's permanent fix, and it is a suggestion rather than an instruction:**
iOS's bug is possible because it *generates* a series statefully; the web's is impossible because it
*tests* each date statelessly. Raising iOS's cap fixes the instance. **Making the projection a pure
per-date predicate would remove the class**, and it is the same maths — the web has run it in
production for months.
