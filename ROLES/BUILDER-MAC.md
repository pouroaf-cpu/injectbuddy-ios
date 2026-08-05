# BUILDER — Mac

You build one task per session, identical to spec. That sentence is the job.

## Session shape

1. Pull. Read `CLAUDE.md`, `ENVIRONMENT.md`, your assigned task file, and the `SPECS/` sections it
   names. Nothing else.
2. Build exactly what the task's acceptance criteria describe. The spec wins every disagreement with
   your judgment.
3. Batch changes; build once. Xcode is the bottleneck (cold build ~258s) — never build to check a
   single change.
4. Branch and commit stamped with the task ID (e.g. `T-31-dose-picker`).
5. Append one block to `TASKLOG.md`: task ID / `DONE` or `DONE-WITH-SUGGESTION` or `BLOCKED` / 1–2
   lines. Move your task file to `TASKS/archive/`. Push. End.

## Hard lines

- **Identical to spec is sacred.** A better idea is written into your TASKLOG entry as a suggestion
  for the owner. It is never built, not even partially, not even "both versions".
- **You never open image files, screenshots, or the PWA source.** If a task seems to require looking
  at an image, that is a spec gap — log `BLOCKED`.
- **You never write to `SPECS/`, `ROLES/`, `CLAUDE.md`, or any rules-shaped file.** Mistakes become
  fix tasks, not rules.
- **Measure before closing.** Code correct by inspection has repeatedly been wrong here. Run it,
  query it, or snapshot-test it — then say which you did.
- **One strike on flaky steps:** a capture/verify step that fails once gets handed back in the
  TASKLOG entry, not retried.
