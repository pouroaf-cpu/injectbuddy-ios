# InjectBuddy iOS — start here

## What this is

An **injection-dosing tracker**. People on TRT, peptides/GLP-1 and steroids work out a dose, save it
as a protocol, and log each injection against a schedule.

**It is a health app that shows numbers people act on.** A layout bug that hides or clips a dose is
a dosing error, not a cosmetic one. That is the only reason this project measures instead of
eyeballing.

Real usage, production 2026-08-03, 39 users with protocols: `trt 22 · peptide 16 · retatrutide 10 ·
steroid 5 · bpc157 4 · rest 1–3`. Weight work by that, not by how bad a finding sounds.

## Your role

**You build. Windows directs.** You have Xcode, the simulator, the framebuffer and direct SQL to the
database. Windows has the web app's source, subagents and a browser, and sends screenshots to the
owner, who reads on mobile.

**The rig is one resource** — one simulator, one framebuffer, one text size. Everything touching the
device serialises through you.

## The three files

| | |
|---|---|
| `TASKS.md` | The shared job list. One list, both sides write it. If it is not there it is not tracked. |
| `UX-UI-RULES.md` | What the app must look like, and how that is checked. |
| `AUDIT.md` | The audit procedure. **Only the owner calls an audit.** |

---

## Before anything else — two setup jobs

### 1 · Clone the web app

```bash
git clone https://github.com/pouroaf-cpu/injectbuddy.git
```

The PWA source is not in this repo. **You have twice inferred the web's behaviour from a doc in this
repo and been wrong both times** — once about a payload shape, once about a config key that would
have written a plausible wrong dose volume to every logged dose. Read the source, never a document
about the source.

### 2 · Set up snapshot testing

`UX-UI-RULES.md` §1 makes snapshot tests the default for anything visual. **Nothing here has ever
run one.**

- Add `pointfreeco/swift-snapshot-testing` to the unit test target in `project.yml`, then
  `xcodegen generate`.
- First assertion on `CalculatorScreen` at default size. **Show it failing against a deliberately
  wrong reference before trusting it** — a reference recorded from a broken state passes forever.
- Then the matrix: fifteen calculators × default / large / AX5. One run, about a minute.

---

## Xcode is the bottleneck

Measured 2026-08-03: no-op rebuild **11s**, cold build 258s, unit suite 45s, one UI test 159s, plus
**~41s of harness overhead before your code runs**. Against that, only **~20–25 checks an hour**
against the real app — because every one pays install, launch, authenticate over the network, load
data, then navigate with an idle-wait between every tap.

- **Snapshot first. XCUITest only for what a rendered view cannot answer** — does a row land in the
  database, does navigation reach the screen, is a control hittable under a pinned bar.
- **Batch.** Queue several changes, build once, walk them all in one session. Never build to check
  one change.
- **A run that reports success while doing nothing is worse than no run.** Four instruments did
  exactly that in one day. Check the artefact changed, not the exit code.

## Traps that are not obvious from the code

- **`project.yml` generates the project.** A new source file is not in the target until
  `xcodegen generate` runs — and a file that is not in a target is not a compile error, it is
  absent. It also regenerates `Info.plist`; put plist keys in `info.properties`.
- **`xcodebuild` strips the `TEST_RUNNER_` prefix.** The host sets `TEST_RUNNER_QA_EMAIL`; the test
  reads `QA_EMAIL`. Without it the UI suite **skips and exits 0** — a skip and a pass share an exit
  code.
- **That is only the FIRST hop. `TEST_RUNNER_` reaches the test RUNNER, and the runner is not the
  app.** Anything read by `ProcessInfo.environment` *inside a view* is the APP's environment, and
  nothing forwards the runner's into it — you must set `app.launchEnvironment` by hand, as
  `CaptureCurrentState` does for `BAR_SHARE_CAP`. **The failure is silent and it inverts a result:**
  a flag that never arrives leaves the feature under test unarmed, so the control "reproduces the
  defect" perfectly, the candidate shows no improvement, and the experiment confidently clears the
  real cause. T-05 came within one assertion of exactly that on 2026-08-04. **A measurement must
  assert its own preconditions arrived, not only its result.**
- **`simctl ui content_size` is device state, not run state.** Set and reset it in the same command,
  or the next run measures a reflowed layout and reads as "the app broke".
- **Assert arrival before every screenshot.** Three frames in the old archive were photographs of
  the previous screen for two capture cycles — each a good photograph of a real screen under the
  wrong name.
- **The Keychain session survives uninstall.** Only `simctl erase` signs you out — and the simulator
  has never been erased, so nothing here has ever tested a genuine first run.
- **The app is light-only.** `UIUserInterfaceStyle: Light` is locked. Do not reintroduce a dark path.
- **iOS writes to Supabase directly via PostgREST.** Every row is RLS-scoped to `auth.uid()`, so a
  write missing `user_id` **fails silently**.
- **QA credentials** are in `.env.local`, gitignored. Never commit them, never screenshot an
  unmasked login form, never use the owner's account.

## Two habits

- **Measure before closing.** Code correct by inspection has repeatedly been wrong against the
  running system. Run it, query it, or photograph it.
- **A frame must prove which screen it is.**
