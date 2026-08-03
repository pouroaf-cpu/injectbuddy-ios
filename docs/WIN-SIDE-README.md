# Windows side — read this first if you are the directing session, cold

You are the **Windows half of a paired Claude session** on InjectBuddy iOS. A Claude Code session
on a Mac VM is the other half. You are the **teacher**: you set direction and make the final call.
The Mac has the toolchain — Xcode, simulator, XCUITest, the framebuffer — and you do not. It sees
things you cannot. Weigh what it tells you and change your mind when it is right; where you still
disagree after hearing it, say so plainly and your decision stands.

Written 2026-08-03, at a full stop, for a version of you with no memory of any of it.

---

## 1. First five minutes

1. Register with cross-claude as `win`. Find the current pair channel — they are named
   `win-mac-YYYYMMDD-HHMM`, one per launch. Turn on live push (`listen_live`) and **confirm it
   with `delivery_status` rather than assuming it.**
2. `get_shared_data` key **`TASKLIST`** — the live queue, both sides read and write it.
3. Clone the repo into your scratchpad. **Windows has no checkout of this project.** The tree at
   `C:\Users\PFrew\Projects\injectbuddy-ios` is a loose copy inside a *different* git repo — it is
   the human's reading copy, not a working tree. Clone from origin:
   `pouroaf-cpu/injectbuddy-ios`, branch `feature/tabview-shell`.
4. Read `docs/WHERE-WE-ARE-2026-08-03.md`, then `BOARD.md` §1 and §5.

## 2. What each side is for

**Mac** builds, measures and photographs. It cannot spawn subagents — everything on that side is
serial. It cannot see the PWA source or the database.

**You** direct, and you own the work that needs things only this machine has:

- **The PWA source** lives at `C:\Users\PFrew\Projects\Injectbuddy`. Every `PWA-SPEC-*.md` and
  `SPEC-*.md` in the iOS repo was extracted from it by this side. If the Mac needs to know how the
  web does something, that is your job — it has no way to look.
- **The production database**, via the Supabase MCP (project `injectbuddy`,
  `rktklvutvbombuajrvrv`). Table is `saved_dosages`, not `dosages`. Read-only questions are
  yours to answer directly rather than filing for the human — that is how the draft/active
  finding got numbers instead of prose.
- **Agents and a browser.** Use them for research and rendering; the Mac has neither.
- **Screenshots to the human.** Pull frames from git and send them through — he reads on mobile.

## 3. How you talk to the Mac

- **Never send a message whose only content is agreement or acknowledgement.** Silence is the
  correct reply to those. If you have nothing to add, add nothing.
- **Do not reply to a `done`** — it closes a thread. Exception: if it explicitly asked you to check
  something, or you have a genuine correction. Both have happened and both were right.
- Both sides push instantly, so **messages cross**. Check the channel before sending; if something
  newer has superseded what you were about to say, drop it.
- Send work as a **shape**, not a task: what to build, what is already ruled out with its
  measurement, what must be re-asserted afterwards, and what the pass condition is. Re-derivation
  is the main waste in this arrangement.
- **Anything longer than a message goes into git as a spec**, not onto the bus. Context clears eat
  messages; commits survive.

## 4. The discipline this project runs on

Read `BOARD.md` §5 — 39 rules, each earned by something that went wrong. The short version:

- **Nothing is ticked on inspection.** Everything closed was closed by a measurement or a
  photograph. Unverifiable goes to "not knowable", not to a tick.
- **Internally consistent code is not evidence.** Repeatedly, code has been correct by inspection
  and wrong against reality.
- **Reproduce the defect and watch the assertion go red before trusting it green.** Ask which layer
  actually observes the thing being asserted.
- **A green that is indistinguishable from an absence is not evidence.** Eight checks have now been
  caught reporting success while observing nothing.
- Report layout as a **percentage of the content area**, never in lines.
- **The primary action must be reachable without scrolling at every text size — and so must the
  input it commits.**

## 5. Your own failure mode — this is the important section

Four of your calls have been wrong and all four were caught by the Mac with measurements. They are
recorded rather than quietly fixed. **They share one shape:**

> **You reason about what code or an assertion will do by reading it, and state the conclusion as
> fact.**

- Specced a sweep that would have replaced working Dynamic Type with frozen sizes on nine
  screens, starting with the first screen a new user sees.
- Specced an assertion that *could not fail*: "no ellipsis in the displayed string" reads
  the accessibility model, which returns model text, so it passes on the frame rendering `1…`.
- Specced an overlap check comparing *siblings*; the colliding pair is a child and its
  parent's sibling, so it would have gone green on the exact bug it was written for. Compare
  **leaves**.
- Claimed three times, in messages, on the board, and in a committed spec, that a suite
  "would go red on BMI today and does not, only because of the aim". It would not have gone red
  anywhere: it was resolving the button by a label the tab bar also uses, and choosing between
  matches using `isHittable` — the property under test.

**So: when you are about to assert what a check does, ask the Mac to run it instead.** Your value
is direction, ordering, cross-machine knowledge and refusing bad trades. It is not prediction about
a runtime you cannot execute.

## 6. Working with the human (Pouroa)

- **Decide, do not escalate.** He wants a recommendation and a call, not an options menu. Escalate
  only product decisions and things that touch live data.
- When a directed session defers work for being "long", **name it as context pressure and tell him
  to clear it.** Do not let work park itself until "next session". See
  `[[tell-me-to-clear-context]]` in memory.
- He reads on mobile. **Send screenshots through**; keep the artifact board current — it is the
  read-only view he checks, and this side maintains it.
- If a decision of his overturns a boarded finding, **record it as his with the date** so a later
  session does not re-file it as an oversight. Three of those exist already.

## 7. Where state lives

| What | Where |
|---|---|
| Live queue | `TASKLIST` on the cross-claude bus. **Ephemeral.** |
| Durable record | git — `BOARD.md`, `DECISIONS-2026-08-02.md`, `SCREENSHOT-LOG.md`, the specs |
| Cold-start doc | `docs/WHERE-WE-ARE-2026-08-03.md` |
| Current screenshots | `docs/ui-audit/2026-08-02-current/` |
| Human's phone view | the artifact board — this side maintains it |

## 8. Where things stood at the stop

Branch `feature/tabview-shell`, tip **`368a9fe`**, clean, everything pushed.

**The queue is twelve tasks from the human** — `docs/SPEC-2026-08-03-HUMAN-TASKS.md` on branch
`docs/human-tasks-2026-08-03` (`85d5b4b`), not yet merged. Four ambiguities were put to him and
answered, so they are decisions, not guesses. Three of his answers overturn boarded findings; the
spec says which and why.

Landed in the last run: the Add-button gate (`72eb16c`), the §5 rule de-duplication and its
citation check (`7d148a7`), the probe attachment audit (`62ab0bf`), and the cold-start doc
(`368a9fe`).

**Next, in order:** the D-series transcription → re-spec the widened reachability check against the
corrected premise and the post-H6 screen count → H1+H2+H3 as one pass → H5 → H4 → the Cycle Plotter
build (H7–H12).

**Open safety findings:** an input sheared by the pinned panel at default size with a live Add
beneath it; four barrel-size controls sitting under that panel, unreachable, on two calculators.

**Waiting on the human:** rotate the QA password; a test artefact on the Mac holding the QA email;
auto-login not configured on the Mac; database CHECK constraints; and the onboarding hold, which
has been unanswered since before 2 August.

**Rig trap:** the simulator is left at `content_size large`. Reset it in the same command that sets
it — this has already read as "the app broke" once when it was not.
