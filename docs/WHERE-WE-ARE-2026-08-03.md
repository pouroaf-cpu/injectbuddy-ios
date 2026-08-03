# Where we are — 2026-08-03

**Read this first if you are opening the project cold.** It is written for someone with
no context, not for the people who were here. Plain language, no shorthand.

Branch `feature/tabview-shell`, tip `62ab0bf`. **Everything is committed and pushed. The
working tree is clean and nothing is half-finished.** The session was stopped
deliberately, at a boundary, because the machine was about to lose its internet
connection — not because anything broke.

---

## 1. What we are doing

InjectBuddy is an **injection-dosing app**. People use it to work out how much of a drug
to draw into a syringe. That is why the standard of proof here is higher than normal: a
layout bug that hides a number is a dosing error, not a cosmetic complaint.

The current work is **twelve tasks that came from the app's owner**, written up as a
spec:

- File: `docs/SPEC-2026-08-03-HUMAN-TASKS.md`
- It is on a **different branch**: `docs/human-tasks-2026-08-03`, commit `85d5b4b`
- It has not been merged into the working branch yet. Read it there.

They are numbered H1–H12. Three of the owner's decisions **overturn things previously
recorded as defects**, so do not re-file them:

1. **Mid-word hyphenation is accepted.** He was shown both options and chose the
   hyphenated one, so `Semaglu-tide` is no longer a defect. The *other* problems on that
   screen — overlap, clipped title, icons that stayed small while text grew — are still
   real.
2. **The disclaimer finding is won't-fix.** He was told the "not medical advice" line is
   never readable without scrolling and said it does not matter.
3. **BMI and Free T Index come out of the Tools list entirely.** His words: "leave them
   alone, and don't let the links to it go anywhere, we will work on later." Remove the
   rows rather than disabling them.

**The order the twelve tasks run in:**

1. H6 (remove those two calculators from Tools) — the calculator-screen half of this is
   already done, see below
2. Widen the reachability check to every calculator — **measurement only, no layout
   changes**, so that the next step works from a list instead of from whichever screen
   happened to get photographed
3. H1 + H2 + H3 as **one pass** — stepper buttons scale, the unit sits at 70% of its
   value's resolved size, controls grow downward instead of spilling. This absorbs the
   picker-overflow item and the default-size shears; they are not separate work.
4. H5 — take the calculator's name out of the scrolling content. ~~put it in the
   navigation bar~~ — struck 2026-08-03 against the `DESIGN-PARITY §9` addendum's
   on-device measurement; build option (a), the content-area header. See H5.
5. H4 — strike the disclaimer finding and delete the test entries tracking it
6. H7–H12 — the Cycle Plotter feature. Staged in the spec; follow the staging, it is
   dependency order.

---

## 2. Where we got to

Three items landed this session, each committed and pushed separately.

| Commit | What it did |
|---|---|
| `72eb16c` | **G1** — the `Add` button is now disabled on calculators that cannot produce a protocol |
| `7d148a7` | **The rules list had two rules numbered 32 and two numbered 33.** Merged, and a check added |
| `62ab0bf` | **Audited every measurement probe**, and found four buttons hidden under the result bar |

### `72eb16c` — the Add button wrote rows it should not have

Pressing **Add** on the BMI calculator was writing a row into the protocols table, from a
height and a weight, and then showing a screen saying *"ADDED TO YOUR PROTOCOLS"* which
asked the user to confirm the day the protocol begins "so the calendar and dose reminders
line up". A body measurement was being given a start date and wired into a dosing
schedule. This was driven on the device and confirmed in the database, and the test row
was deleted afterwards.

The fix is one condition. A flag called `canSaveProtocol` already existed and was already
honoured elsewhere in the app; the calculator screen simply never referenced it.

**This closed the writing half only.** The app still *displays* rows it should not — see
§4 below. Do not read this as closing that.

### `7d148a7` — the rules list contradicted itself

`docs/ui-audit/BOARD.md` has a section §5 of numbered rules that the rest of the
repository cites by number. It contained **two different rules numbered 32 and two
numbered 33**. For a day, every citation of `§5.32` pointed at a coin flip — including
one inside a test written to enforce that very rule.

The cause is worth knowing because it generalises: an earlier commit wrote rules 31–33 in
**descending** order, and the next author scanned *forward* looking for the next free
number, did not find them, and wrote fresh text at the end. **"Find the next free number"
is a forward scan, so a descending run is invisible to it.**

The duplicates were merged rather than deleted — everything unique to each version was
kept — and a test now asserts the numbers are unique, ascending, gap-free, and that every
citation anywhere in the repo resolves to a rule that exists.

### `62ab0bf` — the measurement probes, and what the audit walked into

The app carries small invisible elements ("probes") whose only job is to let the tests
measure things. One of them, `bar_plate`, had been attached in a way that put it **on top
of** the result bar in the accessibility layer — including the `Add` button inside it. So
the app was reporting its own primary button as unreachable, on every calculator. That is
not just a test problem: VoiceOver and Switch Control users reach buttons through exactly
that layer.

All three probes have now been measured rather than eyeballed, and all three are clean.

**While doing that, the audit found something unrelated and worse:** on `TRT Dose` and
`Steroid Dosage`, the four barrel-size buttons (`0.3 mL`, `0.5 mL`, `1 mL`, `3 mL`) sit
**underneath the result bar at the normal text size**. They are enabled and correctly
sized, and no one can tap them without scrolling. See §4.

### The D-series transcription — NOT STARTED

The instruction to do this arrived at the same time as the instruction to stop, so **no
work was done on it at all.** Nothing was written, nothing was reverted, there is no
partial state. §3 below explains what it is.

---

## 3. What to do next, in order

**1. Widen the reachability check to every calculator.** Measurement only — no layout
changes in this step. Its purpose is to produce a *list* of what is broken.

One thing about this step was wrong in every document written before today and is worth
saying clearly: it was justified on the grounds that the check "already asserts the right
thing and only needs pointing at more screens". **That was false.** The check was
resolving the `Add` button by its text label, and the bottom tab bar has an `Add` button
with the same label — so it was measuring the tab bar and passing. Widening it on the old
reasoning would have produced fifteen green results about a tab bar. It has been fixed,
but the lesson stands: **a check aimed at too few screens and a check reading the wrong
element look identical from the outside, and the fixes are opposite.**

Also: the two calculators whose `Add` is now deliberately disabled need a *different*
assertion from the ones where it should work. On a calculator that cannot save, the rule
is "the button is on screen and NOT enabled"; elsewhere it is "on screen and reachable".

**3. Then the H1+H2+H3 pass**, as described in §1.

---

## 4. What is open and not fixed

**The two safety items first.**

1. **Four buttons are underneath the result bar at normal text size.** The barrel-size
   row on `TRT Dose` and `Steroid Dosage`. Measured at y 590.67–634.67 with the bar's top
   edge at 564.67. Unreachable without scrolling, and unreachable *entirely* for anyone
   navigating by accessibility rather than by touch. Nothing caught this because the
   existing check only looks at controls carrying a particular kind of identifier, and
   these have none.

2. **An input is cut in half by the result bar at normal text size**, on the BPC+TB500
   calculator, with `Add` sitting live below it. Being able to press a commit button over
   a value you cannot fully read is worse than not being able to press it, because the
   second one stops you.

**Then:**

3. **The app shows protocols that were never started.** The list does not filter on
   status. In production, 71 of 102 rows are drafts and 31 are live, and 24 of 39 users
   have *nothing* live at all — so their entire list is drafts presented as running
   protocols. When fixing this: filter on the `status` column, **not** on `is_active`,
   which is a mirror of it that only carries two of the three states. And note that
   simply hiding "archived" rows fixes nothing, because no row has ever been archived.

4. **Result cards are cut by the bar** on ~~BMI, Free T Index and~~ Semaglutide at normal
   text size. **BMI and Free T Index struck — both screens descoped by the owner's
   decision, 2026-08-03** (`SPEC-2026-08-03-HUMAN-TASKS.md` H6: "No layout work, no
   shear work, no styling on either screen"). Struck by his call, not our oversight;
   the measurement on both still stands. **Semaglutide is still live.**

5. **Cycle Plotter is missing from the Tools list** — the screen whose job is listing
   calculators. Its only route is a dialog on the dashboard, eight scrolls in.

6. **Menu pickers draw outside their own control** at large text sizes once the selected
   text is long enough.

7. **A calculator's title truncates**, and the frequency control is cut off when the
   keypad is up.

---

## 5. What needs a person

None of these block the work.

1. **Automatic login is not set up on the Mac.** Convenience only.
2. **The database has no `CHECK` constraints** on some profile columns — and nothing at
   the database level stops a calculator that cannot produce a dose from writing a
   protocol row. The app now prevents it; the database still would not.
5. **The `D`-series decisions live only on the message bus** (see §3). Someone should
   decide whether they belong in git permanently or should be retired in favour of the
   numbered rules in `BOARD.md`, which overlap them.

---

## 6. The rig, and one trap

- iPhone 16 Pro simulator, iOS 18.3.1, booted, signed in as the QA account.
- **The simulator's text size is left at `large`, which is the normal default.** Say this
  out loud before debugging anything, because it has already been misread once as "the
  app broke": if a previous run set an accessibility text size and did not reset it,
  every screen looks wrong and nothing is actually wrong. Set it and reset it *in the
  same command*.
- The simulator has **not** been erased, so nothing here has ever tested a genuine first
  run of the app. A green test suite is not evidence that first-run works.
- Test credentials come from `.env.local` (not in git) and **must** be passed with a
  `TEST_RUNNER_` prefix. Without it the test suite **skips every test and reports
  success.**

The full invocation:

```
set -a; . ./.env.local; set +a
TEST_RUNNER_QA_EMAIL="$DEVTOOLS_TEST_EMAIL" \
TEST_RUNNER_QA_PASSWORD="$DEVTOOLS_TEST_PASSWORD" \
xcodebuild test -project InjectBuddy.xcodeproj -scheme InjectBuddy \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:InjectBuddyUITests
```

---

## 7. The one habit that matters here

**Nothing is marked done because it looks right.** Every closed item in `BOARD.md` was
closed by a measurement or a photograph. If something cannot be verified, it goes in the
"not knowable" section rather than getting a tick.

And specifically: **before trusting a test that passes, make it fail on purpose.** Every
significant finding this session came from a check that was green over a real defect —
one was reading the wrong button, one was reading the accessibility model instead of the
screen, one was measuring a screen nobody had asked about. A check that has never been
seen to fail has not been shown to work.
