# 2026-08-04 — the frame set AFTER T-01a

Twenty frames, default content size, captured by
`CaptureCurrentState.testCaptureFullDefaultSweep` at `1788646` (972s).
Gate probe asserted `size=large` before the first frame, so every filename
claiming "default" was taken at default.

**Why this set exists and why `2026-08-03-current` must not be used for T-01b.**
T-01a rebuilt the chrome that `CalculatorScreen` shares across all fifteen
calculators — the numeric row (label left, recessed navy-outlined well, tick
ruler), the small-caps section headers, and the cyan result bar. Every
calculator's iOS side therefore MOVED. Comparing a July web capture against an
iOS frame from before T-01a would be listing differences against a build that no
longer exists, and would re-report as missing the six things that now ship.

`06-calculator-trt.png` here is the same screen as
`2026-08-04-t01a/20-calculator-trt-default.png`, taken in the sweep rather than
singly.
