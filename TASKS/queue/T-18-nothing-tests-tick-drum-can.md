## T-18 — Nothing tests that the tick drum can be dragged
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** `TickDrum` replaced the `−`/`+` steppers as the primary numeric input on every calculator.
`testRuler_tracksItsOwnField` proves the ruler reports its own field's value and that two drums are
not crossed. **It does not touch the drag.** `TickDrum` publishes one `.adjustable` element and
XCUITest has no direct way to invoke an accessibility adjustable action.

**Why it matters:** the control the user actually operates is the one with no coverage. The retired
steppers had a real behavioural test (`step_up_mgWeek` moves `mgWeek` by 10 and does not move
`strength`); trading that for a value-tracking assertion is a net loss in coverage on a dosing
input, and saying so is cheaper than discovering it.

**Done when:** either a swipe on `drum_mgWeek` is shown to change the field by a known number of
gradations, or — better — the drag maths is extracted into a testable pure function and unit-tested,
with the UI test keeping only the wiring assertion. Whichever, it must be shown RED first: a drag
test that passes against a drum that ignores drags is the failure mode this project keeps finding.
