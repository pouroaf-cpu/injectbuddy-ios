# Agent Workflow — claim a row, do the work, remove the row

Every agent working on the iOS plan follows this lifecycle. It mirrors
`C:\Users\PFrew\Projects\_agent-system\RULES.md`, which wins on any conflict.

## On START
1. Read `WIREFRAME-PLAN.md`, `INSTRUCTIONS.md`, `TASKS.md`.
2. Open `ACTIVE.md`. **If another agent's row overlaps your intended files/area, do not proceed** —
   pick non-overlapping work, wait, or flag the collision.
3. **Claim a row** in `ACTIVE.md`, keyed by agent-id = `$env:CLAUDE_AGENT_NAME`
   (fallback: a short unique id like `claude-7f3a`). Row format:
   ```
   | agent-id | HH:MM | branch/worktree | files / area | one-line intent | status |
   ```
4. **Before editing any file**, fill in `files / area` + `intent` and set `status = working`. An empty
   row, or one stuck on `awaiting task` after you have a task, is a bug.
5. In `TASKS.md`, set your task to `🔄 In progress` with your agent-id beside the title.

## While WORKING
- Keep your row current. **Only ever edit or remove your own row.**

## On END (after commit/push of the app code)
1. Verify against the task's Definition of Done (`INSTRUCTIONS.md`).
2. Commit + push the iOS app changes; confirm the push succeeded — that is the cleanup trigger.
3. In `TASKS.md`: mark the task `✅ Done`, move its block to the Done archive (newest first, cap 10),
   recording agent-id + date + commit.
4. **Remove your row from `ACTIVE.md`** — the last act of the session, automatic on a successful push.

## Stale rows
A row hours old with clearly abandoned work may be removed; note it in your commit/journal.
