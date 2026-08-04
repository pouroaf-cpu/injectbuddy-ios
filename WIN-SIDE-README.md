# Windows side — read this first

Rewritten 2026-08-04, from scratch. Every other markdown file in this project was deleted on the
owner's order the same day. Rules are being rewritten; nothing below is a rule, it is context.

---

## 1. What InjectBuddy is

An **injection-dosing tracker**. People on TRT, peptides/GLP-1 and steroids use it to work out a
dose, save it as a protocol, and log each injection against a schedule.

**It is a health app that displays numbers people act on.** A layout bug that hides or truncates a
dose is a dosing error, not a cosmetic one. That is the only reason this project measures things
instead of eyeballing them.

Real usage, from production on 2026-08-03 — 39 users with saved protocols:
`trt 22 · peptide 16 · retatrutide 10 · steroid 5 · bpc157 4 · everything else 1–3`.
BMI and Free T Index: zero. Weight work by real usage, not by how bad a finding sounds.

## 2. The pieces

| | |
|---|---|
| **Web app (PWA)** | Next.js, live, `github.com/pouroaf-cpu/injectbuddy`. Source is on this machine at `C:\Users\PFrew\Projects\Injectbuddy`. |
| **iOS app** | `github.com/pouroaf-cpu/injectbuddy-ios`, branch `feature/tabview-shell`. Not shipped yet. |
| **Backend** | Supabase project `injectbuddy` / `rktklvutvbombuajrvrv`. iOS writes directly via PostgREST; every row is scoped by RLS to `auth.uid()`, so a write missing `user_id` fails silently. |
| **Also exists** | Android app, Discord bot, embeds — not in scope here. |

## 3. How the pair works

**Windows (this side) directs. The Mac builds.** The Mac has Xcode, the simulator and the
framebuffer; it is the only side that can compile, run or photograph the app. It also has direct SQL
to the database.

**This side owns:** the PWA source (the Mac cannot see it — hand it what it needs, or point it at
the web repo to clone), subagents and a browser, and sending screenshots to the owner, who reads on
mobile.

**The rig is one resource.** One simulator, one framebuffer, one text-size setting. Everything
touching the device serialises through the Mac.

**A drive mount exists:** `M:` is the Mac's home directory over SSHFS. Use it to read logs, frames
and its working tree. **Git operations over the mount do not work** — the object store is
unreadable. Read only.

## 4. Ship the MVP, as soon as possible

The owner's standing instruction: *things will not be perfect, get it out the door, fix up later.*

**Three things block a ship, nothing else does:**

1. **It does the thing** — the core write and read paths work.
2. **It does not mislead the user** — a dosing app never shows a dose as taken when it was not, and
   never destroys a real log.
3. **It passes App Store review** — account deletion, privacy policy, disclaimer.

Everything else is filed and fixed after launch. Do not open a new front while a ship-blocker is
open.

## 5. Where the app actually is

**Working and verified on the device (2026-08-03):** saving a protocol, logging a dose and reading
it back, un-logging, account deletion end to end, the result bar reduced from 52% to 17% of the
screen, all four syringe barrels reachable, the sheared dose volume fixed, a cancelled refresh no
longer wiping the home screen, CI running the unit suite, and a first pass of the onboarding flow.

## 6. Xcode is the bottleneck — stay off it

Everything else is cheap. Measured on the rig, 2026-08-03:

| | |
|---|---|
| No-op rebuild | **11s** |
| Cold build | 258s |
| Unit suite | 45s |
| One UI test, end to end | 159s |
| Fixed harness overhead, every run | ~41s |
| **Checks per hour against the real app** | **~20–25** |

**The compile is not the cost.** Every look at the real app pays: harness spin-up (~41s before your
code runs), install, launch, authenticate over the network, load the data, then navigate to the
screen — with a wait for the app to go idle between every tap. Two to three minutes whether the
change was one line or fifty. So:

- **Snapshot tests first, XCUITest only when nothing else can answer it.** A snapshot renders a
  SwiftUI view to a PNG inside the unit suite — no launch, no auth, no navigation. Anything visual
  goes there. The device is for writes, navigation and hittability. See `UX-UI-RULES.md` §1.
- **Batch.** Queue several changes, build once, walk them all in one session. Never build to check
  one change, and never interleave build-check-build-check.
- **Only use the device for what only the device can answer.** Does it render, does it fit, does the
  row land in the database. Anything answerable by reading the source, a log or the database is
  answered that way.
- **Prefer surfaces that need no login.** The onboarding preview target is its own app with no auth
  — a change there costs an 11-second rebuild and nothing else. That is the model to copy.
- **A run that reports success while doing nothing is worse than no run.** Four separate instruments
  did exactly that on 2026-08-03 — a piped exit code, a probe measuring one of three occluders, a
  crop that silently did not crop, and a test filter that matched no tests. Check the artefact
  changed, not the exit code.

## 7. Two habits worth keeping

Everything else was deleted. These two caught every real defect found on 2026-08-03:

- **Measure before closing.** Code that is correct by inspection has repeatedly been wrong against
  the running system. Run it, query it, or photograph it.
- **A frame must prove which screen it is.** Three screenshots in the archive were photographs of
  the wrong screen for two capture cycles, because nothing checked.
