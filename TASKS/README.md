# TASKS

`queue/` is one file per open task. `archive/` holds everything already closed.
A task file keeps the id in its name so it can be referenced from TASKLOG.md.

---

## Conventions carried over from the old single-file TASKS.md

Kept verbatim. These were written after the failures they describe.

**One list. Both sides read it, both sides write it.** If it is not here it is not tracked, and a
job carried in a message does not survive a context clear.

## How to use it

1. **Every task has an id, a priority, an owner, a status and a description.** A title alone is not
   a task — the next reader must be able to act on it without asking what it means.
2. **Say what is wrong, not just what to do.** For a defect: what it does now, and why that is
   wrong. For a job: what does not exist yet.
3. **Every task says what "done" looks like** — an observable condition, not "fixed".
4. **Sub-tasks only when the work genuinely splits.** Do not manufacture depth. Sub-tasks carry
   their own description.
5. **Check for a duplicate before adding.** This list once existed in four documents at the same
   time and re-surfaced the same item to the owner every session.
6. **A defect found while doing a task is added here immediately, by whoever found it** — as its own
   task, before it is forgotten. Do not carry it in a message.
7. **Nothing is deleted.** Done is struck through, with the commit SHA or the evidence that closed
   it, and stays.
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
9. **This file is edited in the checkout, and you pull before you write it.** On 2026-08-04 Windows
   spent a session editing an untracked copy at `Projects\injectbuddy-ios\TASKS.md`; it showed T-03
   open three days after it was closed with evidence, and mac was sent to re-do finished work. The
   only copy that counts is the one in the repo.
10. **Take IDs from your own block so a crossing write cannot collide.** Both sides push instantly.
    **mac allocates upward from T-14; win allocates from T-50.** On the same day T-06, T-07 and T-08
    each meant two different things at once — a merge conflict is recoverable, two tasks silently
    sharing an ID is not.

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

**Priority** is out of 10 — 10 is a user is being harmed today, 1 is tidy-up.
**Status:** `open` · `doing` · `blocked` · `done` · `filed` (real, deliberately not being worked)
**Owner:** `mac` · `win` · `pouroa`
**Agent:** the named subagent currently doing the work, or `—` when nobody is on it.

**WHY `Agent` IS SEPARATE FROM `Owner`, AND IT IS NOT BOOKKEEPING.** `Owner` is the SIDE
accountable for the task — it never changes while the task is open. `Agent` is the process
actually holding the files RIGHT NOW, and it is the field that answers the question this project
keeps getting wrong: *who is editing this, and can I safely edit it too?* Two agents on one file
produced three "both sides needed, neither subsumes the other" merges in a single day (rule 13),
and a session was spent waiting on a rig lease held by a holder that had provably died. A task
carrying a live agent name is a task whose files are claimed.

Three rules, so the field cannot rot into decoration:
- **Set it when the agent is recruited, not when it reports.** An agent that dies mid-task must
  still be visible, or its half-finished edits look like nobody's.
- **Clear it to `—` the moment the work lands or the agent dies.** A stale name is worse than an
  empty one: it makes a free file look claimed and a dead agent look alive, which is exactly the
  failure the rig lease had.
- **A task with `Status: doing` and `Agent: —` is a claim that a HUMAN side is on it.** If neither
  is true, the status is wrong.

---
