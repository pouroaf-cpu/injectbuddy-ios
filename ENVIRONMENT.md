# ENVIRONMENT — the machine, and what it lies about

Everything here was learned by being burned. None of it is inferable from the source.

---

## What a build costs

Measured 2026-08-03:

| | |
|---|---|
| No-op rebuild | **11s** |
| Cold build | **258s** |
| Unit suite | **45s** |
| One UI test | **159s** |
| Harness overhead before your code runs | **~41s** |

That buys only **~20–25 checks an hour** against the real app, because every one pays install,
launch, authenticate over the network, load data, then navigate with an idle-wait between every tap.

- **Snapshot first. XCUITest only for what a rendered view cannot answer** — does a row land in the
  database, does navigation reach the screen, is a control hittable under a pinned bar.
- **Batch.** Queue several changes, build once, walk them all in one session. **Never build to check
  one change.**

## Building

The command is in `CLAUDE.md`. Two things about it that are not obvious:

- **The destination is discovered, not named.** `generic/platform=iOS Simulator` is a **build-only**
  destination and `test` rejects it, and a hard-coded device name goes red the moment the device
  lineup changes. CI discovers a UDID for the same reason — see `.github/workflows/ci.yml`.
- **CI runs unit tests only.** The XCUITest target needs QA credentials reaching the runner, CI
  holds no secrets, and a UI suite without them skips every test and exits 0.

---

## Traps

### `project.yml` generates the project

A new source file is not in the target until `xcodegen generate` runs — and **a file that is not in a
target is not a compile error, it is absent.** It also regenerates `Info.plist`; put plist keys in
`info.properties`.

### `xcodebuild` strips the `TEST_RUNNER_` prefix — and that is only the first hop

The host sets `TEST_RUNNER_QA_EMAIL`; the test reads `QA_EMAIL`. Without it the UI suite **skips and
exits 0** — a skip and a pass share an exit code.

**`TEST_RUNNER_` reaches the test RUNNER, and the runner is not the app.** Anything read by
`ProcessInfo.environment` *inside a view* is the APP's environment, and nothing forwards the runner's
into it — you must set `app.launchEnvironment` by hand, as `CaptureCurrentState` does for
`BAR_SHARE_CAP`.

**The failure is silent and it inverts a result:** a flag that never arrives leaves the feature under
test unarmed, so the control "reproduces the defect" perfectly, the candidate shows no improvement,
and the experiment confidently clears the real cause. T-05 came within one assertion of exactly that
on 2026-08-04.

### `simctl ui content_size` is device state, not run state

Set and reset it in the same command, or the next run measures a reflowed layout and reads as
"the app broke".

### An accessibility identifier on a container overwrites the ones its children set

`ModeTab` set an identifier on its container, which propagates to descendants and **overwrites the
identifiers the segments set for themselves** — so `mode_ndays` was written and was never
observable. On 2026-08-04 a UI test reported "the TRT calculator has no Every N Days mode control"
twice while that control was on screen and selected. Read literally, that failure said to abandon
the whole task. Dump the tree before believing a probe that cannot find something.

### The Keychain session survives uninstall

Only `simctl erase` signs you out — and the simulator has never been erased, so **nothing here has
ever tested a genuine first run.**

### The app is light-only

`UIUserInterfaceStyle: Light` is locked. Do not reintroduce a dark path.

### iOS writes to Supabase directly via PostgREST

Every row is RLS-scoped to `auth.uid()`, so **a write missing `user_id` fails silently.**

### QA credentials

In `.env.local`, gitignored. Never commit them, never screenshot an unmasked login form, never use
the owner's account.
