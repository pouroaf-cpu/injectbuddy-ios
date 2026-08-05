## T-05 — Calendar pull-to-refresh did nothing — **MEASURED 2026-08-04, candidate (A) is DEAD**
**Priority 3/10** · **Owner:** mac · **Status:** doing — the diagnosis is closed, the affordance is not back yet

**What it was:** the gesture armed but issued zero requests — confirmed against the database's own
API log — while the identical gesture on an identically-shaped Dashboard view re-read one minute
earlier in the same run. The affordance was removed rather than shipped as a lie.

**The leading candidate was (A):** `RouteContent` gives the Dashboard an inline title and every other
tab root a large one, and a large title owns the pull-down stretch above a plain ScrollView. It was
the strongest of three because it is one level up from either screen, which is why comparing the two
files showed nothing.

### ~~(A) the large title owns the pull-down stretch~~ — **DISPROVEN, on the device**

Apparatus: `T05PullToRefreshUITests` at `78dc507`. Two DEBUG flags — `T05_EXPERIMENT=1` arms the
pull and publishes a reload counter incremented BEFORE its await; `CALENDAR_INLINE_TITLE=1` flips
the Calendar to the Dashboard's title so the two roots differ by nothing. One build, two runs.

```
CONTROL   (large title)  T05 inline=false before=1 after=2   ← THE PULL FIRED
CANDIDATE (inline title) T05 inline=true  before=1 after=2
```

**The control refreshed.** The defect does not reproduce on this build under the shipping
configuration, so the inline title is not the mechanism and **(A) is not established by the
candidate run** — both conditions behave identically.

**The control test is RED and that red is the result, not a broken test.** It asserts "no increment"
because that is what the defect predicts; it got an increment. Written that way deliberately, and
the outcome table was written into the suite BEFORE the run so the result could not be read to suit
whatever came back.

**What most likely fixed it, and it is already in the tree:** `CalendarScreen`'s own note names it —
batch 4 item 1 stopped `CalendarViewModel.load` blanking to `.loading` on a refresh, so the
ScrollView that owns the refresh control is no longer destroyed underneath it mid-pull. That note
calls it "the cheapest thing to try first". It appears to have already happened, as a side effect of
an unrelated change, and nobody re-measured.

**The consequence that matters most is a fear cancelled.** The reason this stayed open with the
affordance already removed was: *"if that mechanism is real, any future screen with a large title
will silently not refresh."* **It is not real.** Large titles do not break `.refreshable` on this
app, so T-54's header work is not blocked by this and does not need to route around it.

**WHAT THIS DID NOT MEASURE, stated so the run is not over-read.** The counter proves the CLOSURE
ran — which is strictly narrower than the original evidence, and deliberately so: the API log could
not distinguish "the closure never fired" from "it fired and the request was suppressed downstream".
This separates them and answers the first. **It does not prove a request reached Supabase.**

**Done when** (the remaining half): `.refreshable` is restored unconditionally — not behind
`T05_EXPERIMENT` — and a pull is shown to produce an actual read in the API log, the same observer
that condemned it. Until that, the affordance stays off: this project removed it for lying once and
a closure count is not a re-read.

**Candidates (B) and (C) are moot rather than disproven** — (B) the harness's scroll target, (C)
`reload()` mutating @State before its await. Neither needs killing now that the behaviour is correct
under both titles, but both stay written down in `CalendarScreen` in case the defect returns.

### The request half — **MEASURED 2026-08-04. NULL RESULT: the closure fires and no query executes.**

Two observers, neither able to fake the other's half: mac drove the device and cannot see the
database; win read the database and cannot touch the device.

```
BASELINE   11:12:04Z   dose_log 4790   saved_dosages 14223   total 2118254   entries 615
           11:12:42Z   dose_log 4790   saved_dosages 14223   total 2118254
           11:12:56Z   dose_log 4790   saved_dosages 14223   total 2118254
PULL       11:15:20Z -> 11:15:30Z        reloads 1 -> 2      (large title, shipping config)
AFTER      11:16:06Z   dose_log 4790   saved_dosages 14223   total 2118254   entries 615
```

**Not one call on any counter, and no new entry**, read 36s after pull-end — ample, since
`pg_stat_statements` records at statement end.

**THE AMBIENT RATE IS THE DISCRIMINATOR AND IT IS WHY A NULL IS EVIDENCE HERE.** Record it beside
the result, because a future reader needs the instrument and not just the conclusion: three
readings across **52 seconds showed zero drift** on a LIVE production database whose counters
demonstrably do move (2.1M historical calls). Without that, "nothing moved" is unreadable — it is
indistinguishable from a stats table that is not counting what we think it counts. The quiet period
exists to measure exactly this, and it did.

**The escape hatch was checked too**, because "the counter did not move" and "the request went
somewhere nobody is looking" are different claims: **zero new query shapes created inside
11:15:15–11:15:40Z** (a shape the `WITH pgrst_source%` filter missed would have created an entry
with `stats_since` in the window), and the newest PostgREST entry of any kind predates the pull by
54 minutes.

**So T-05's original observation was right about the symptom and WRONG ABOUT THE LAYER.** The
gesture arms, `.refreshable` runs, the closure executes and the counter increments — and
`CalendarViewModel.load` does not reach the network. A cache, a guard, or an early return.

**WHAT IS NOT YET PROVEN, and it decides where to look next.** The database instrument sees
**queries executed in Postgres**. It cannot separate:

- **(a)** the app never made an HTTP request — a logic bug in `load`;
- **(b)** the app made one that failed or was cancelled before PostgREST ran a statement — auth
  refresh, cancelled task, dropped connection.

Both produce exactly this reading, and **(b) is the worse of the two**: a request path that fails
silently would also explain the original behaviour better than a logic bug does. Only the device
side can tell them apart.

**Done when:** the device says which. A `URLProtocol` log or an `os_log` at the point
`SupabaseBackendClient` is actually called, driven through one pull, distinguishes (a) from (b) in a
single cheap run — no database access needed. **Do not close this on the null alone: it proves
nothing ARRIVED, not that nothing was SENT.**

**Candidate (A) remains disproven** — see above; the large title is not the mechanism and header
work is not blocked by it. Candidates (B) and (C) are now the live ones again, alongside the new
network-layer question, and (C) — `reload()` mutating `@State` before its await — looks better than
it did, because a `Task` cancelled by a view update would produce exactly this null.

### The last question — instrument BUILT, and it has answered NOTHING yet

**What is still unknown.** The null above proves no statement executed in Postgres. It cannot
separate **(a)** the app never made an HTTP request — a logic bug in `load` — from **(b)** a request
was made and died before PostgREST ran a statement. **(b) is the worse of the two** and explains the
original behaviour better than a logic bug does.

**Built `2026-08-04`, committed, UNPROVEN.** Four DEBUG counters on `CalendarViewModel.load` —
`entered`, `requested`, `returned`, `threw` — plus the error string, surfaced through the existing
`t05_probe`. They sit exactly between the two measurements already taken: `reloads` proved the
closure runs, the database proved no statement executed, and these say whether the backend call was
reached and what it did. **If `threw` moves while `returned` does not, the pull reaches the network
layer and is cancelled.**

**IT HAS NOT RUN.** The attempt died in `setUp` — *"No Calendar tab appeared within 15s"* — on a
cold isolated `DerivedData` where launch is slower than the helper's timeout. **No data was
produced.** The instrument is committed so the next session does not rebuild it, NOT because it has
shown anything. Raise the tab timeout or warm the build before re-running.

**THE PRIME SUSPECT, and its own comment convicts it.** The `catch` in `CalendarViewModel.load`
says: *"A cancelled load surfaces NOTHING and touches NO state."* A cancelled `Task` makes the
`async let` pair throw `CancellationError`, `LoadFailure.message` returns nil for it **by design**,
and the whole failure is swallowed — no state change, no banner, nothing on screen. **That is the
exact shape of every observation so far:** the gesture arms, the closure runs, the counter
increments, no statement executes, and the user sees a spinner return with stale data and no error.

That is **candidate (C)** — `reload()` mutates `visibleMonth` (`@State`) **before** its await, which
`DashboardScreen.reload()` does not do. It was the weakest of the three candidates when they were
written and it is now the strongest, purely because (A) is dead and the null rules out the layers
above it.

**Next measurement, cheap and device-only:** one pull with the counters read. No database access, no
coordination with the other side.

**WHAT CANDIDATE (C) PREDICTS, AND WHY THE EXISTING COUNTERS ALREADY SETTLE IT.** A cancellation is
not just consistent with the evidence — it makes a specific prediction the other candidates do not:
**`threw` increments while `returned` does not** (or `requested` fires and `returned` never
follows). A logic bug that never reaches the network gives the opposite signature — `entered` moves
and `requested` does not. The four counters separate those two in **one run**, with no database
access and no coordination with the other side. That is the whole remaining question, and the
instrument for it is already built and committed; it has simply never executed.
