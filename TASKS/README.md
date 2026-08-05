# TASKS

`queue/` is one file per open task — read only the one assigned to you.
`backlog/` is where the planner and reviewer write; the owner promotes from there into `queue/`.
`archive/` holds everything already closed, and the evidence that closed it.
A task file keeps the id in its name so it can be referenced from `TASKLOG.md`.

New task files use `TASK-TEMPLATE.md`.

---

## Conventions carried over from the old single-file TASKS.md

These were written after the failures they describe. Rules 9a, 11, 12 and 13 are verbatim.

1. **Every task has an id, a priority, a status and a description.** A title alone is not a task —
   the next reader must be able to act on it without asking what it means.
2. **Say what is wrong, not just what to do.** For a defect: what it does now, and why that is
   wrong. For a job: what does not exist yet.
3. **Every task says what "done" looks like** — an observable condition, not "fixed".
4. **Sub-tasks only when the work genuinely splits.** Do not manufacture depth. Sub-tasks carry
   their own description.
5. **Check for a duplicate before adding.** This list once existed in four documents at the same
   time and re-surfaced the same item to the owner every session.
6. **A defect found while doing a task is added immediately, by whoever found it** — as its own
   task, before it is forgotten. Do not carry it in a message.
7. **Nothing is deleted.** A closed task moves to `archive/` with the commit SHA or the evidence
   that closed it, and stays.
8. **Done means measured.** A photograph, a query, a run. Not "it should work now".

9a. **And the file is what you BELIEVE, not what a message said.** On 2026-08-04 both sides spent
    hours treating T-81 — a live 8/10 dosing-visibility defect — as merged and green. It was neither:
    the guard sat untouched in `DoseProjection.swift:319` and the entry said `Status: open` the whole
    time. It began as one ambiguous sentence, where "merged and pushed, build green" described the
    T-45 work in the same message and was read as describing the T-81 finding beside it. **Win then
    repeated it back as established fact — twice, once to the owner — while holding a checkout in
    which a single grep would have refuted it.** An ambiguous claim is a mistake; repeating a claim
    about a file you can read without reading it is a different and worse one. **Before you assert a
    task's status, look at the task.**

11. **A task whose cause is UNKNOWN gets re-measured before it is reasoned about.** T-05 sat open for
    three days on the theory that a large title owns the pull-down stretch. Measured 2026-08-04 with
    a control: **the defect no longer reproduces at all** — it had been fixed days earlier as a side
    effect of an unrelated change, while the task went on describing a defect that did not exist.
    Everything reasoned on top of it, including "any future screen with a large title will silently
    not refresh", was reasoning about a ghost.
12. **A measurement must assert its own preconditions, not only its result.** Three instruments in
    one day reported success while measuring nothing: a skip sharing an exit code with a pass, a
    capture run reporting success with zero frames, and an environment flag that never reached the
    app. The third would have produced a **false confirmation** — the control reproducing the defect
    perfectly because the feature under test was never armed — and sent the next person chasing
    causes that had already been cleared.

13. **An agent in a worktree must rebase before writing to a SHARED FILE, not only before committing
    code.** On 2026-08-04 a T-45 worktree cut from a tip that predated T-51's closure merged cleanly
    and **resurrected the open version of T-51 beside the struck-through one** — two headings, one
    id, one of them stale. Rules 9 and 10 did not cover it: the write was to the right file, from the
    right block, by the right owner, and still wrong, because the branch point was old. Git cannot
    help here — both versions are legitimate text.
    **And a silent tidy-up is indistinguishable from quietly dropping a task**, so a duplicate
    removed this way leaves a note saying what happened.

    > *Footnote, 2026-08-05:* rule 13 is verbatim and names rules 9 and 10, which are no longer
    > above it. 9's substance is now principle 5 in `CLAUDE.md` (GitHub is the source of truth);
    > 10's block-allocated ID scheme is dead under the sequential model.

**Priority** is out of 10 — 10 is a user is being harmed today, 1 is tidy-up.
**Status:** `open` · `doing` · `blocked` · `done` · `filed` (real, deliberately not being worked).
