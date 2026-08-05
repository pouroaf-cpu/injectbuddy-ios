# T-98 — Snapshot testing is the default check, and nothing has ever run one

**Priority** 8/10 · **Status:** open

> Salvaged from the old `CLAUDE.md` during the 2026-08-05 restructure. It was a standing setup job,
> not a task, so the split did not pick it up — filed here rather than deleted.

## Goal

`SPECS/DESIGN.md` §1 makes snapshot tests the default for anything visual, and the device the
exception. **Nothing in this repo has ever run one.** Until this lands, every visual rule in
`SPECS/DESIGN.md` is unenforced, and every visual check costs a device run — ~20–25 checks an hour
against a suite that should do fifteen calculators × three text sizes in about a minute.

## Files

`project.yml` (unit test target), `Tests/InjectBuddyTests/`

## Spec references

`SPECS/DESIGN.md` §1 (how these are checked), §6 (fix at the shared control),
`ENVIRONMENT.md` (xcodegen, build costs)

## Acceptance criteria

1. `pointfreeco/swift-snapshot-testing` is on the unit test target in `project.yml`, and
   `xcodegen generate` has been run so the target actually contains it.
2. One assertion exists on `CalculatorScreen` at default text size, and it passes.
3. **That assertion has been shown failing against a deliberately wrong reference before being
   trusted.** A reference recorded from a broken state passes forever. The evidence of the
   deliberate failure is in the commit or the TASKLOG entry.
4. The matrix runs: fifteen calculators × default / large / AX5, in one run.
5. The run's wall-clock time is recorded, so the "about a minute" claim is measured rather than
   assumed.
