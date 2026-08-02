# START HERE — session log

Two paired sessions so far, Windows Claude directing and Mac Claude building.
This file is the entry point; it is written so a cold session can pick up without
re-deriving anything.

**Read in this order:**

1. This file — what happened, what broke, how it was fixed
2. `ui-audit/BOARD.md` — current open/closed state, and §5, the rules
3. `DESIGN-PARITY.md` — colour, type, header and Dynamic Type rules
4. `ui-audit/2026-08-02-current/` — **what the app actually looks like now.**
   Per-cycle folders and `2026-08-01-current` are the audit trail, not current state.
5. `DECISIONS-2026-08-02.md` — every call made while the human was away, with what
   would reverse it
6. `HARNESS-AND-LOOSE-ENDS.md` — the workshop floor: how to run things, and the
   traps that cost real time

Branch `feature/tabview-shell`, latest `6eec303`. Everything below is committed.

**Stopping point 2026-08-02 evening: `HANDOVER-2026-08-02-EVENING.md`.** It names the
next item (**F-E**, the picker overflow) with its shape, its two ruled-out approaches and
its pass condition, so a cold session starts cutting rather than re-deriving. It also
carries the three items that need the human.

---

# Day 2 — 2026-08-02

## The one-sentence version

Every serious defect found today was a **number the user could not trust**: a dose
displayed that the engine never used, a dose truncated to `1…`, and a result
computed confidently for an input hidden behind an overlay — and every one was
invisible to code review, to the 27 unit tests, and to the audit as it existed
that morning.

## 1. The defects

### 1.1 The field displayed a number the engine did not use — the SECOND breach

`mgWeek` is ranged `0...1000`. Focusing a populated field did not select its
contents, so typing `250` onto `100` gave `100250`; `clamp` then handed the engine
**1000**, silently. The screen showed `100250 mg/week` beside a `2.500 mL` draw
computed from 1000, with a correct over-capacity warning for a number the user
could not see.

Yesterday's headline bug — field 100, engine 300 — was the *first* breach of the
same invariant. Two breaches on two different paths means the first fix was a patch
on a path rather than an invariant on the control, so it is now enforced on **both
edges** of `NumberField`: clamping rewrites the text, and focusing selects.

**App-wide.** `NumberField` is the only numeric input and `FieldRow` its only call
site, so every ranged field in every calculator had it. "The TRT dose field" and
"every dose field in the app" are different findings and only the second was true.

### 1.2 A dose truncated to `1…` at AX5 — finding F1 again, through a new mechanism

The field row was `[ value ][ unit ][ − ][ + ]` on one line. The unit carries
`.fixedSize()` — correct, a unit must never truncate — and the steppers are 44pt
each, so at AX5 the unit took the row and **the value** was squeezed. The weekly
dose rendered as `1…`, which could be 100, 150 or 1000 mg/week.

Compounding it, the field's font was a frozen `.system(size: 17)` at the call site
that the type-scale re-baseline could not reach, so the number stopped growing while
its unit did not — the value became the smallest text on the most safety-critical
screen in the app, then disappeared.

**F1 banned `lineLimit` on a value+unit pair. That ban was necessary and not
sufficient**; layout reached the same outcome without touching it. Fixed by
reflowing above AX1.

**How it was found matters more than the fix.** The TRT calculator at AX5 had never
been captured — two attempts had failed and it was about to be recorded as a known
gap. It is the most safety-critical screen in the app and the screen the *original*
truncation bug lived on, and it had a second one.

### 1.3 A result presented for an input the user could not reach

At AX5 the pinned result bar — already collapsed to primary + CTA, which was the F11
fix — still took ~58% of the content area, leaving room for exactly one field.
`Vial strength` was visible; `Weekly dose` was sheared through the middle of its
glyphs by the bar's top edge. So the screen offered `Draw per injection · 0.250 mL`
and an enabled `Add` for a weekly dose the user could neither see nor reach.

`Add` writes a protocol. The first two defects were display bugs; this one persists.

It also defeated the reachability rule adopted an hour earlier, and produced its
missing half: **the input the action commits must be reachable too. An action you
can reach for a value you can't is worse than an action you can't reach, because the
second one stops you.**

Not trimmed a third time. F11 was measured against frozen type and the bar now scales
with everything else, so another trim is a smaller number against the same broken
premise: an overlay owning the majority of the content area is not context for the
screen, it *is* the screen.

### 1.4 The quick-value row was unreachable with the keypad up

And the occluder was **not the keyboard** — it was the pinned result bar, sitting
above it. Weekly dose is only the second field on the screen; every field below it
was worse. The chips now ride in a keyboard toolbar, which also supplies the only
exit from a `.decimalPad` — it has no return key, so dismissing it previously meant
tapping some other control.

The tell that this was real: `quick_mgWeek_400.tap()` **reported success and moved
nothing.**

## 2. The type scale never scaled

Every `Theme.Typeface` token was `Font.system(size:weight:design:)` — fixed points,
which SwiftUI excludes from Dynamic Type. The comment directly above the enum
claimed the opposite: *"Every face is built with `relativeTo:` so it still scales."*
Not one of them was.

Proof: the dashboard greeting and the `PROTOCOLS` eyebrow are **pixel-identical**
between `IB2245723` (default) and `IB2245730` (AX5), while system-styled text on the
same screen scales enormously. The hierarchy *inverts* — the greeting is the largest
text at default and one of the smallest at AX5.

**The queued work would have spread it.** T10 was "apply the type scale to the ten
screens that don't have it". Nine of those ten have no `Theme.Typeface` at all,
meaning they use system text styles and scale correctly today. The sweep would have
replaced working Dynamic Type with frozen sizes on nine screens, starting with
`DisclaimerGate` — the first screen a new user sees — and it would have been reported
as a parity win.

It also reframed the AX5 Tools finding: `ToolsScreen` looks broken at AX5 **because
it scales correctly and the layout cannot take it**, while the dashboard looked fine
**because it wasn't scaling at all**. Opposite defects, about to be treated by one
sweep in opposite directions.

## 3. The through-line: every check we removed was one that could not fail

Seven now, from seven unrelated directions. Every one reported success.

| The check | Why it could not fail |
|---|---|
| `continueAfterFailure = true` in the capture sweep | A failed navigation photographed the Tools screen and filed it under the TRT calculator's name |
| A screenshot of the keyboard toolbar | A hardware keyboard suppressed the software keypad, so the frame *flattered* the fix it was taken to prove |
| Two "different" captures | Byte-identical, because the gesture between them never landed |
| "Assert the displayed string contains no ellipsis" | Reads the accessibility model, not the render — passes on the exact frame showing `1…` |
| `TEST_RUNNER_BAR_SHARE_CAP` set for a whole run | `TEST_RUNNER_` reaches the **runner**, not the app under test. The override never arrived, the run reported success, and the frame was filed under a cap it was not taken at — while being the override that proves the pinning gate works |
| A 0.4s `press(forDuration:thenDragTo:)` walking a form | Registers as a **press**, not a drag. Scrolled zero pixels, so six scroll positions would have been one frame under six names |
| The runner's Documents directory between runs | It **survives**. A skipped frame leaves the previous run's file under the name this run meant to write, and it gets copied out, measured and serialised as evidence about this commit |

None of them were *wrong* about something. They were **silent about everything**,
and a green that is indistinguishable from an absence is not evidence.

So the harness now has four guards, each added after the corresponding check was
caught passing: `continueAfterFailure = false`; assert the keyboard is on screen
before shooting; fail when two frames are byte-identical; count matches before
resolving an identifier. And the rule, `BOARD §5.24`: **reproduce the defect and
watch the assertion go red before trusting it, and ask which layer actually observes
the thing being asserted.**

`FORCE_INLINE_FIELD=1` exists for exactly that — a DEBUG-only hook that restores the
`1…` layout so anyone can re-prove the truncation sweep goes red on the real bug,
rather than trusting it because it was red once on one machine.

## 4. What the audit could not see

`2026-08-01-current/10-tools-ax5.png` passed the audit, and passed **correctly** —
nothing truncated, nothing under 44pt, contrast fine. A human looked at it for two
seconds and found six problems: `Semaglu-tide` hyphenated mid-word, `Tirzepatide`
wrapping to an orphaned `e`, `Retatru-tide`, the title clipped against the header,
icons that stayed small while text went huge, four rows filling the screen.

Three rules came out of that, and they are the ones most likely to matter tomorrow:

1. **Every audit opens with a judgment pass** — look at the frame and ask "would I
   ship this?" before measuring anything. Metrics are a floor, not a verdict; they
   were chosen to catch the last set of bugs, not the next one.
2. **At every size, not just AX5.** Every finding today came out of AX5 frames — not
   because the default screens are clean, but because those were the frames anyone
   looked at. One glance at a default frame we already had found the result bar
   taking 52% of the content area with two of five inputs above the fold.
3. **Report layout as a percentage of the viewport, never in lines.** "Three lines"
   is comparable to nothing; "31% of the content area" is comparable across screens,
   sizes and weeks. Two denominators: full frame, and the content area between fixed
   header and tab bar.

And the corollary to §5.7 that today earned: **the least-surveyed screen is the
highest-prior defect, not the lowest.** Nobody complains about a screen nobody has
looked at. The one screen never captured at large text held the worst finding on the
board.

## 5. The tests

Four wiring assertions plus a truncation sweep, all green at default and AX5.

The sweep asserts a geometric invariant — **a value cell is never narrower than its
own unit** — because the textual version cannot fail (§3). It goes red on all three
mechanisms that have produced this bug without naming any of them.

**It found seven instances nobody had looked at.** With the defect reproduced, it
reports 12 failures across 8 calculators, including `Free T Index · shbg`,
`Reconstitution · targetConc` and `Steroid Dosage · strength`. The hand-found bug was
one of eight.

**Its blind spot is documented in its own header and is reachable, not theoretical.**
It is a ratio, so it is blind to a long value beside a short unit: `1000` → `10…`
next to `mg` passes green. `Reconstitution` holds 1000 in a 49.7pt cell, so
four-digit doses are ordinary here. Closing that is T19 — have the renderer publish
its own truncation state in DEBUG rather than inferring it from geometry.

Coverage, stated so a green run is not over-read: default + AX5 across 14
calculators; three GLP-1 screens have **no numeric fields at all** and are measured
by nothing — the suite prints that rather than skipping silently.

## 6. Where to pick up

`BOARD.md` is authoritative and `TASKLIST` on the cross-claude bus is the live queue.
In short:

- **T9 — onboarding + Settings Personalisation.** Not started, and the build order is
  the important part: **Settings surface first, wizard second.** Built the other way
  round, an unfinished T9 ships the one-way door — a wizard that writes units and
  timezone once with no screen that can edit them. `onboarding_completed_at` is
  stamped only by the wizard, never by a Settings save, which is what makes
  Settings-first safe. Design for `timezone = NULL` as the **norm** (88 of 89 live
  profiles) while the API rejects null.
- **T19** — renderer-measured truncation, above.
- **T20** — the result bar takes ~52% of the content area at *default* size. Gate the
  pinning on a measured share, not a Dynamic Type category.
- **T21** — the pinned plate should be a material, not grey. Contrast measured against
  the *worst* composite, not a representative one.
- **T11** — re-survey at every size with the judgment pass.
- **T8** — protocol detail route; the chevron promises navigation and delivers none.

## 7. Working notes

- **Credentials** are at `injectbuddy-ios/.env.local` (gitignored, verified with
  `git check-ignore` before the file was written) as `DEVTOOLS_TEST_EMAIL` /
  `DEVTOOLS_TEST_PASSWORD`. The runner reads `QA_EMAIL` / `QA_PASSWORD` and
  `xcodebuild` only forwards host environment carrying the **`TEST_RUNNER_`** prefix
  — without it the suite *skips and reports success*. **The password was relayed over
  the message bus on 2026-08-02 at the human's instruction and sits in the bridge's
  DB on both machines; rotation is outstanding.**
- **A capture run leaves the device dressed for the wrong test.** `simctl ui
  content_size` is device state, not run state. An AX5 sweep left it set and the next
  wiring run failed all four assertions against a reflowed layout — it read exactly
  like "the app broke". Reset in the same command that sets it.
- **`Tools` is a `List`**, which XCUITest surfaces as a collectionView, not a
  scrollView — and at accessibility sizes its rows are **lazy**, so
  `waitForExistence` reports "does not exist" for a row two swipes away. Both are why
  the AX5 calculator took three attempts to capture.
- **The device is signed in, not erased.** `HARNESS §4` was corrected; first-boot is
  only reachable via `simctl erase`, at the cost of the session.
- **The PWA source and the database are on the Windows box.** Specs for the missing
  calculators, history, inventory and Settings are now committed here
  (`PWA-SPEC-*.md`) so the building side can work from them rather than from
  archaeology.

---

# Day 1 — 2026-08-01

The full narrative is in `SESSION-HANDOVER-2026-08-01.md` and
`HANDOVER-2026-08-01-FULL.md`. The short version:

An accessibility and safety audit (17 findings, all measured), brand parity with the
PWA, three data bugs invisible in the code, and the XCUITest harness that exists
because verification kept being the bottleneck.

The findings that still shape the work:

- **Units disappeared at large text** — `Draw… 0.25…`. The worst finding of that
  audit, and the ancestor of Day 2's §1.2.
- **The field showed a different number from the one being calculated** — 100
  displayed, 300 computed, with all 27 unit tests green throughout. This is why the
  UI test target exists.
- **Saving a protocol from iOS had never worked** — every insert refused by RLS
  because `user_id` was omitted. Every row in the table was web-created.
- **No dedup on protocol saves** — iOS bypasses `/api/dosages`, so it was fixed at
  the database with a unique index rather than in either client.
- **Brand teal as text failed everywhere** — `#0FBCAD` on white is 2.38:1. The
  palette was split: fills vs text.
- **Contrast is symmetric** — swapping foreground and background changes nothing.
  Filling the teal button fixed the parity bug and left the accessibility bug
  untouched.

The rule that has now paid out on both days: **internally consistent code is not
evidence.** Three bugs on Day 1 and the type-scale comment on Day 2 were all correct
by inspection and wrong against reality.
