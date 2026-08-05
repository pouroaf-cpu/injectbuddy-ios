## T-55 — Two screens cannot be photographed, so nothing about them can be verified
**Priority 5/10** · **Owner:** mac · **Status:** open

**What:** three surfaces have no current frame, for two different reasons.

**a) `bmi` and `freetest` are unphotographable while withdrawn.** `isListed` is false for both, so
Tools cannot reach them — and the capture harness navigates by tapping a Tools row. Their only frames
predate T-01a. **Found by mac during the 2026-08-04 sweep and reported in the channel; filing it,
because rule 6 says a defect found while doing a task is added here immediately and this one was
carried in a message.** It is a hole in the harness, not in the sweep: any calculator that is
withdrawn from Tools becomes unverifiable by the same mechanism, so this recurs the next time
something is withdrawn.

**b) Settings has not been photographed since 2026-08-01.** Absent from `2026-08-02-current`,
`2026-08-03-current` and `2026-08-04-post-t01a`. The one frame,
`archive/2026-08-01/08-settings-default.png`, predates everything built since, so `SHELL-PARITY.md`
§S-06 cannot be written.

**c) Confirm-start has no iOS frame in any sweep**, while the web reference
`screens/05-add-confirm-default.png` exists. Same consequence: uncomparable.

**Why it matters beyond the three:** this project's whole standard is that nothing closes without a
photograph or a query. A screen the harness cannot reach is a screen that can never be closed — so
the gap is not "three missing images", it is three surfaces permanently exempt from the bar
everything else is held to.

**Done when:** the harness can reach a calculator that is not listed in Tools, and Settings and
confirm-start appear in the sweep.
