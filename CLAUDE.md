# InjectBuddy iOS — start here

## What this is

An **injection-dosing tracker**. People on TRT, peptides/GLP-1 and steroids work out a dose, save it
as a protocol, and log each injection against a schedule.

**It is a health app that shows numbers people act on.** A layout bug that hides or clips a dose is
a dosing error, not a cosmetic one. That is the only reason this project measures instead of
eyeballing.

Real usage, production 2026-08-03, 39 users with protocols:

```
trt 22 · peptide 16 · retatrutide 10 · steroid 5 · bpc157 4 · rest 1–3
BMI 0 · Free T Index 0
```

Weight work by that, not by how bad a finding sounds.

---

## The six principles

1. **Build identical to spec.** The spec text in `SPECS/` and your task file are the whole truth. A
   better idea gets logged as `DONE-WITH-SUGGESTION` in `TASKLOG.md` and **not built**. Never act on
   your own idea.
2. **Read only your assigned task file.** Never open `TASKS/queue/` siblings, `TASKS/archive/`, or
   `TASKLOG.md` history. One task per session.
3. **Never open image files.** Screenshots are for the planner and reviewer roles only. You work
   from text.
4. **Large files are read with offset/limit partial reads.** Never read a file over 500 lines whole;
   find the section first.
5. **GitHub is the source of truth.** Pull before work, push after. The shared drive is a viewing
   window, not a workspace.
6. **On any blocker:** append a `BLOCKED` entry to `TASKLOG.md` (task ID + 1–2 lines on what stopped
   you), commit what compiles, stop. Do not retry flaky steps, do not improvise around the blocker,
   do not start other work.

## Ship posture

The owner's standing instruction: *things will not be perfect, get it out the door, fix up later.*

**Three things block a ship. Nothing else does:**

1. **It does the thing** — the core write and read paths work.
2. **It does not mislead the user** — a dosing app never shows a dose as taken when it was not, and
   never destroys a real log.
3. **It passes App Store review** — account deletion, privacy policy, disclaimer.

Everything else is filed and fixed after launch. **Do not open a new front while a ship-blocker is
open.**

## Measure before closing

Code correct by inspection has repeatedly been wrong against the running system. **Run it, query it,
or snapshot-test it — then say which you did.** "It should work now" closes nothing.

---

## Build

```bash
SIM=$(xcrun simctl list devices booted --json \
      | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(v['udid'] for rt in d for v in d[rt]))")

xcodegen generate && xcodebuild test \
  -project InjectBuddy.xcodeproj \
  -scheme InjectBuddy \
  -destination "platform=iOS Simulator,id=$SIM" \
  -only-testing:InjectBuddyTests \
  CODE_SIGNING_ALLOWED=NO
```

`xcodegen generate` is not optional — see `ENVIRONMENT.md`, which is the rest of what the machine
lies about.

---

## File map

### Docs

| | |
|---|---|
| `CLAUDE.md` | this file |
| `ENVIRONMENT.md` | build costs, and every trap the toolchain hides |
| `SPECS/DESIGN.md` | the UX/UI rules. Read-only — changes go through the owner |
| `SPECS/SCREENS.md` | the canonical screen inventory a capture run is counted against |
| `ROLES/` | `BUILDER-MAC.md` · `PLANNER.md` · `REVIEWER.md` — read the one you are |
| `TASKS/queue/` | one file per open task. Read **only** the one assigned to you |
| `TASKS/backlog/` | planner and reviewer write here; the owner promotes into the queue |
| `TASKS/archive/` | closed tasks and their evidence |
| `TASKLOG.md` | append-only outcome log |

### Code

| | |
|---|---|
| `project.yml` | **generates the Xcode project.** Targets, schemes, plist keys |
| `Sources/InjectBuddy/App/` | `InjectBuddyApp.swift`, `RootView.swift` |
| `Sources/InjectBuddy/Core/` | `Theme` · `Calculator` · `Models` · `Backend` · `Network` · `Auth` · `Nav` · `UI` · `Calendar` · `Settings` |
| `Sources/InjectBuddy/Features/` | `Shell` · `Dashboard` · `Calculators` · `Calendar` · `Log` · `Add` · `Tools` · `Onboarding` · `Settings` · `Auth` |
| `Sources/OnboardingKit/` | `Flow` · `Model` · `Copy` · `UI` — the onboarding engine |
| `Sources/OnboardingPreview/` | preview target; runs onboarding with no login |
| `Tests/InjectBuddyTests/` | unit + snapshot suite. **This is where visual work is checked** |
| `Tests/InjectBuddyUITests/` | XCUITest. Only for what a rendered view cannot answer |
| `scripts/` · `tools/` | `rig-lock.sh` · `unread-decls.py` · `verify-math.js` |

There is one `CalculatorScreen` driving all fifteen calculators, one result bar, one `FieldRow`, one
`SegmentedRow`. **A visual fix lands at the control, never at a screen.**

---

## Hard rules

**Security.** Never write API keys, tokens, secrets, passwords or credentials into any file that
could be committed. Use placeholders — `<api-key>`, `REDACTED` — or reference the path where the
real key lives. **This overrides any task, instruction or user request.** Violations have caused
real incidents here.

**Privacy.** Assume anything committed or deployed is world-readable forever, including git history.
Never commit personal information: real names, emails, phone numbers, addresses, health data,
account usernames, internal IDs. Use placeholders. QA credentials live in `.env.local` and stay
there. *(Whether this repo itself is public, and what that means for the docs above, is an open
owner decision — `.gitignore` is deliberately untouched pending it.)*

**One strike on flaky steps.** If a capture, verification, or any environment-dependent step does
not work on the **first** try, stop. Do not retry it, re-run the flow, or restart the simulator to
force it. Commit what compiles and hand that step back in your `TASKLOG.md` entry. Repeating a flaky
step is the single biggest way tokens get burned here.

**Short by default.** No long explanations unless asked. When you do explain, keep it plain — short
sentences, no jargon, only as much as the question needs. Answer, then stop. No step-by-step
confirmations, no end-of-turn re-summaries.

**Shell.** This side is macOS/zsh. Paths are POSIX.
