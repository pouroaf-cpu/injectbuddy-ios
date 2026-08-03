# Decisions — 2026-08-02

The human is away for the day and handed the wheel to the paired sessions
(Windows directing, Mac building). Everything decided without them is written
down here so it can be reviewed rather than rediscovered. Anything decided
unilaterally by the building side is flagged `[mac, provisional]`.

Durable record lives in git. `BOARD.md` holds findings and evidence; this file
holds decisions and their reasoning. The live task list is on the cross-claude
bus (key `TASKLIST`) and is state, not record — it is not a substitute for this.

**The `D` rules below and this file's numbered sections are two different series.**
`D3` is not §3. If you arrived from a `D<n>` citation, read the `D` rules and stop
there — matching the number against a section heading gives a wrong answer that
reads right.

---

## The `D` rules

Ten rules. `BOARD §5` holds the longer rule list and the evidence behind findings;
these are the ones that apply to every piece of work regardless of what it touches.

### D1 — Measure it, don't read it

No claim from inspection. Anything touching a displayed number, dose, unit,
calculation, truncation, tap target or the accessibility tree is measured on the
running app, and so is anything closing a `BOARD` finding.

Work may ship unverified. It may not be **written down** as verified without proof —
if verification is skipped, the commit says so and the finding stays open.

### D2 — Look at it before you measure it

Judgment pass first: open the frame and ask "would I ship this?" Write down whatever
reads as wrong, including what no number will attach to.

Metrics are a floor, not a verdict. They were chosen to catch the last set of bugs,
not the next one.

### D3 — Serial and log row per frame

Every captured frame gets an `IB…` serial and a row in `SCREENSHOT-LOG.md` recording
when it was taken, from which commit, and of what. Nothing is stamped inside the
image — the file on disk stays exactly what the device rendered.

### D4 — A check must be able to observe the thing it asserts

Ask which layer actually sees the condition before trusting a result. A truncation
check that reads the accessibility model gets the string the app *intended*, so it
passes on the exact frame drawing `1…`.

A green indistinguishable from an absence is not evidence: make a check fail on
purpose before believing it green.

### D5 — The committing action, and the input it commits

The control that commits an action must be wholly on screen and genuinely reachable,
**and so must the input it commits.**

*An action you can reach for a value you can't see is worse than an action you can't
reach, because the second one stops you.*

**Split for screens that cannot save:** the assertion becomes "committing action
wholly on screen and **not enabled**".

### D6 — Compare leaves, not siblings

When checking whether two elements collide, compare the bottom-most drawn elements.
Sibling comparison misses the common case — a child colliding with its parent's
sibling — and goes green on the exact bug it was written for.

The accessibility tree has no z-order and no clipping, so a reported collision may be
between things the user cannot see, and a clean result is not proof anything is legible.

### D7 — Every press gets visible feedback inside 400ms

Tap to visible change, under 400ms, always. Where the real work takes longer an
animation bridges the gap — the animation **is** the feedback, not decoration. A
control that looks identical for half a second reads as broken and gets pressed twice.

Feedback belongs to the shared control, not the screen: `PrimaryButton` and
`OAuthButton` in `Core/UI/Components.swift` are the two places this lands.

### D8 — Change the screen first, then talk to the server

Never block a screen transition on a database round-trip. Navigate immediately, show
the destination, fill it in when the data arrives. The wait lives inside the new
screen, not in front of it.

**The exception, and it is this app's whole subject:** move the *user* forward
optimistically, never a *number*. A dose, volume or confirmation is not shown as
settled before the write is confirmed, and a failed write is always surfaced.

### D9 — Every spacing value comes from `Theme.Spacing`

The scale is `xs 4 · sm 8 · md 16 · lg 24 · xl 32` — a 4pt grid. No raw numbers in
`.padding`. If the value you want is not on the scale that is a design decision: add
a token, don't inline a number.

### D10 — One screen margin, one control height

Horizontal screen margin is `Theme.Spacing.md` everywhere; content never touches the
edge. Any two controls that stack in the same flow are the same height, and that
height is set once at the shared control.

**Padding is additive to `minHeight`.** A control that sets `minHeight: 44` and then
adds vertical padding renders taller than 44 — measure the resulting frame rather
than assuming the floor is the height.

---


## 1. Dashboard IA — iOS does not mirror the PWA's six tabs

**Decided:** win. iOS keeps the single-scroll dashboard; `history` and
`inventory` become their own routes off the tab bar / drawer.

**Reasoning:** nesting a six-segment control inside an iOS tab bar is an
anti-pattern; the PWA's tab strip exists because the web has no tab bar. Parity
of *content* is the goal, not parity of *chrome*. Unblocks history, inventory and
protocol detail at once.

**Reverses if:** building history as its own route leaves the dashboard feeling
empty.

## 2. Greeting shimmer — dropped, not deferred

**Decided:** win. Removed from the open list entirely.

**Reasoning:** every attempt cost a cycle. SwiftUI desaturates multi-stop
gradients on text, and the only legal band colour caps the composite at 3.37:1.
The screen reads correct without it.

**Reverses if:** someone finds a treatment that measures above 4.5:1 without the
desaturation. Nobody should go looking.

## 3. Typeface — SF stays, Inter rejected

**Decided:** win. Closed.

**Reasoning:** bundling Inter costs the Dynamic Type metrics that protect against
the truncation class of bug, and unit truncation was the worst finding of the
entire audit.

## 4. Protocol card chevron — build the detail route

**Decided:** win. A chevron that promises navigation and delivers none is a
defect independent of the IA question, and decision 1 unblocks it.

## 5. Clamping is no longer silent `[mac, provisional]` → approved by win

**Decided:** mac proposed, win approved.

**What:** when a typed value is outside a field's spec range, the field text is
rewritten to the clamped value. Previously the engine took the clamped number and
the field went on displaying what was typed.

**Reasoning:** measured on the running build — `mgWeek` is `0...1000`, the field
displayed `100250`, and the result bar showed a 2.500 mL draw computed from 1000.
The invariant being enforced is **the field can never display a number the engine
did not use**. This was its second breach, which means the first fix was a patch
on one path rather than an invariant on the control, so it is now enforced on both
edges of `NumberField`.

**Cost accepted:** typing past a ceiling snaps the text mid-entry. In a dosing app
a visible snap beats a silent 100× discrepancy.

**Scope:** app-wide. `NumberField` is the only numeric input and `FieldRow` its
only call site, so every ranged numeric field in every calculator was affected —
not just the TRT dose.

**Reverses if:** the mid-entry snap turns out to be hostile in a field with a low
ceiling and fine steps. Nothing in the current specs looks like that.

## 6. Select-all-on-focus in `NumberField`

**Decided:** win specified, mac accepted after judging the interaction cost.

**What:** focusing a populated numeric field selects its contents, so typing
replaces rather than appends.

**Reasoning:** the root cause of `100250` was that typing appended to `100`.
With this, typing 250 into a field showing 100 gives 250, the everyday path never
reaches the clamp, and decision 5 becomes the backstop for genuine over-range
entry rather than a routine event.

**Judged cost:** incremental edits (tap in, change one digit) now mean retyping
the number. Accepted — dose values are two to four characters, and the ± steppers
and quick chips already own the "adjust from here" interaction. If a longer field
ever appears this is worth revisiting.

## 7. Quick values move into a keyboard toolbar

**Decided:** mac proposed, win approved over its own suggestion.

**What:** the focused field's quick values render in a
`ToolbarItemGroup(placement: .keyboard)` with a Done button. The in-scroll row
stays for the unfocused state.

**Reasoning:** measured — the quick-value row is occluded with the keypad up, and
the occluding element is **the pinned result bar**, not the keyboard. Weekly dose
is the second field on the TRT screen and its chips were already behind the bar;
every field below it is worse. The toolbar is reachable by construction rather
than by where a field happens to sit in the form. It also supplies the only exit
from a `.decimalPad`, which has no return key — before this, dismissing the keypad
meant tapping some other control.

**Rejected alternative:** collapsing the pinned bar further. The live result is
the reason this screen is not the PWA's "Show result" flow.

## 8. Result-row identifiers name the surface `[mac, provisional]` → approved by win

**Decided:** mac proposed, win approved.

**What:** `result_<label>` addresses the **pinned** result bar. The in-scroll copy
is `detail_result_<label>`. The keyboard toolbar's chips are `kb_quick_<key>_<v>`,
distinct from the in-scroll `quick_<key>_<v>`.

**Reasoning:** measured — `result_Weekly total` matched two elements. An ambiguous
`XCUIElement` fails at resolution before any assertion runs, which is why the chip
test died without printing its own message. `result_` names the surface the user
always sees, so a test written against it is a test written against what is on
screen.

**Not a data risk:** both cards are handed the same `CalculatorResult` value. They
cannot disagree. The ambiguity was in addressing them, never in the numbers.

## 9. `unique(_:type:)` is narrowed in exactly one place `[mac, provisional]`

**Decided:** mac.

**What:** the UI suite resolves identifiers through a helper that first asserts
exactly one match. It is narrowed to `.button` for `kb_done` only.

**Reasoning:** a keyboard `ToolbarItemGroup` bridges its items to UIKit and
publishes the identifier on both the bridged bar button and the hosted SwiftUI
label — measured as two elements at (348, 539, 38, 44) and (345, 539, 44, 44).
Reordering the modifiers changed nothing; `accessibilityElement(children:
.ignore)` changed nothing, to the pixel. It is not removable from the app side.
The narrowing is recorded rather than applied quietly, because narrowing by habit
is how `firstMatch` hid a stepper bug for a session.

**Reverses if:** a later SwiftUI release stops publishing the duplicate.

## 10. No visible serial stamp inside screenshots

**Decided:** mac, on win's request for a judgment call. Accepted by win.

**Reasoning:** these frames get measured — pixel positions, contrast samples,
overlap distances. A stamp mutates the evidence in order to label it, has to land
somewhere that may be exactly what someone needs to read, and means the file on
disk is no longer what the device rendered. Filename plus the append-only log
gives the traceability without touching a pixel. Annotate a *copy* if a frame
needs a caption.

## 11. Existing screenshot folders are not retro-serialised

**Decided:** win.

**Reasoning:** yesterday's captures have no reliable per-frame capture times, and
inventing them is exactly the fabricated-evidence problem the serial rule exists
to prevent. `SCREENSHOT-LOG.md` says the rule starts 2026-08-02 and everything
before it is unserialised.

## 12. Audit cadence — build and move on, except where numbers are involved

**Decided:** win, from the human.

**What:** small and cosmetic work ships without verification and is picked up in
the next audit round. The measurement bar still holds absolutely for: anything
that changes a displayed number, dose, unit or calculation; anything closing a
`BOARD` finding; anything touching truncation, tap targets or the accessibility
tree.

**The distinction:** "never tick on inspection" is a rule about *closing
findings*, not about *doing work*. Work may ship unverified. It may not be
written down as verified without proof. If verification is skipped, the commit
says so and the `BOARD` item stays open.

## 13. Every audit gets a judgment pass

**Decided:** win, from the human, after `10-tools-ax5` from `2026-08-01-current`.

**What:** before any measuring, look at each frame and ask "would I ship this?"
Anything that reads as wrong is written down even when no number can be attached
to it. Goes in `BOARD §5`.

**Why:** that frame passed the audit, and passed *correctly* by the rules in
force — nothing truncated, nothing under 44pt, contrast fine. A human looked at
it for two seconds and found six problems: `Semaglu-tide` hyphenated mid-word,
`Tirzepatide` wrapping to an orphaned `e`, `Retatru-tide`, the `Tools` title
clipped against the header, icons that stayed small while text went huge, and
four rows filling the screen. The audit could only see what it could put a number
on. Metrics are a floor, not a verdict — they were chosen to catch the last set
of bugs, not the next one.

**Constraints on the fix, recorded now so they are not re-litigated:** no
`dynamicTypeSize(...up to:)` cap on calculator names — they are navigation labels
in a dosing app and AX5 users are exactly who needs them legible. No `lineLimit`,
for the reason that rule exists.

## 14. Capture runs fail loudly

**Decided:** mac, prompted by win.

**What:** `continueAfterFailure = false` in the capture harness, and the
destination is asserted before any frame is taken.

**Reasoning:** `12-calculator-trt-ax5` was a genuine photograph of the Tools
screen under a filename claiming the TRT calculator, because navigation failed
and the run continued. A capture sweep that cannot fail loudly will keep
producing frames that lie.

## 15. The type scale did not scale, and the queued sweep would have spread it

**Decided:** mac found and fixed it; win approved and asked for it to be recorded
under its own name rather than neutrally.

**What was wrong:** every token in `Theme.Typeface` was
`Font.system(size:weight:design:)` — a fixed point size, which SwiftUI does not
apply Dynamic Type to. The comment directly above the enum claimed the opposite:
*"Every face is built with `relativeTo:` so it still scales with Dynamic Type."*
Not one of them was. Internally consistent documentation, wrong against reality —
the same failure mode as three of yesterday's bugs.

**Evidence:** the dashboard at default (`IB2245723`) and at AX5 (`IB2245730`)
render the greeting and the `PROTOCOLS` eyebrow at pixel-identical size, while
everything on the same screen using system text styles scales enormously. The
hierarchy inverts: the greeting is the largest text on the screen at default and
one of the smallest at AX5. Fixed and re-measured — `IB2245743` shows it scaling.

**The part worth writing down: the directing side specced a sweep that would have
degraded accessibility on nine screens, and the building side caught it before it
ran.** T10 was "apply the type scale to the ten screens that don't have it". Nine
of those ten have no `Theme.Typeface` at all, which means they use system text
styles and scale correctly today. The sweep would have replaced working Dynamic
Type with frozen sizes on every one of them, starting with `DisclaimerGate` — the
first screen a new user sees — and it would have been reported as a parity win.

**It also reframed the AX5 Tools finding.** `ToolsScreen` looks broken at AX5
*because it scales correctly and the layout cannot take it*; the dashboard looked
fine *because it did not scale at all*. Opposite defects, about to be treated by
one sweep in opposite directions. T10 and T11 are therefore no longer a merged
sweep: they are a re-baseline followed by a re-survey.

**Cost accepted:** two tokens move ~2pt at default size, greeting 24 → 22 and
cardMeta 14 → 15. Everything else maps exactly.

**Left open, deliberately:** the greeting at AX5 now takes roughly 40% of the
dashboard. That is correct Dynamic Type behaviour and it is still a product
question. It is a §1 item, not a regression of this fix.

## 16. Capture frames must differ from each other

**Decided:** mac.

**What:** `shot()` keeps every frame taken in a run and fails if a new one is
byte-identical to an earlier one.

**Reasoning:** it caught a real one within a minute of being added —
`07-calculator-barrel-row` came back identical to `06-calculator-trt` because
`app.swipeUp()` resolved to a gesture the form never received. That is the same
failure as the "refreshed" set which came back byte-identical with matching
checksums, except that time a human noticed afterwards. The run now stops.

## 17. Greeting capped at `accessibility1` `[win, provisional]`

**Decided:** win, while the human was away. Overturnable on review.

**What:** `GreetingHeadline` carries `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`.
It is the only capped element in the app.

**Reasoning:** the greeting is chrome, not content — no dose, no date, no state,
nothing a user acts on. Measured consequence of leaving it uncapped once the
tokens started scaling: at AX5 it took three lines, and the Next dose card's
`Mark taken` CTA was **cut off by the bottom of the screen**. A user at AX5 could
not see the action for today's dose without scrolling, on the home screen,
because of a decorative string. `IB2245743` before, `IB2245746` after.

**Rejected:** a shorter greeting string at large sizes. Two strings for one
element is a second thing to keep in sync, and the short form would be the one
nobody ever looks at.

**The rule, not the one-off:** written into `DESIGN-PARITY §10` — content scales
without limit, decorative chrome may be capped, and the test is whether a user
acts on it. Without that, the next person caps something that matters and cites
this decision. Calculator names were considered under the same argument and
rejected (D3).

**Reverses if:** the human prefers a greeting-first home screen at accessibility
sizes.

## 18. `NumberField` reflows above AX1 — and this was finding F1 again

**Decided:** mac.

**What:** above `.accessibility1` the field row changes from
`[ value ][ unit ][ − ][ + ]` on one line to the value on its own full-width line
with the unit and steppers underneath.

**Why it is a safety fix, not a layout tweak:** the unit carries `.fixedSize()` —
correct, a unit must never truncate — and the steppers are 44pt each, so at AX5
the unit took most of the width and **the value was what got squeezed**. The
weekly dose rendered as `1…`. In a dosing calculator `1…` could be 100, 150 or
1000 mg/week and nothing on screen disambiguates it. Separately, the field's font
was a frozen `.system(size: 17)` at the call site, which the Theme re-baseline
could not reach, so the dose number stayed 17pt while `mg/mL` grew past it — the
value became the smallest text on the most safety-critical screen in the app.

F1 banned `lineLimit` on a value+unit pair. This reached the same place through
**layout** instead, which is why that ban was necessary and not sufficient. Both
now hold: nothing truncates because nothing has to share a line with something
`.fixedSize()`.

**Found by** capturing the TRT calculator at AX5 for the first time — the screen
that had never been surveyed at large text, and the screen the original truncation
bug lived on.

---

## Deferred checks — for the next audit, not now

1. **Inner shadow on data input cells vs the field-border finding.** The input
   borders were a closed finding — 1.3:1 raised to `#8E8E93` at 3.26:1. An inner
   shadow lands on exactly those pixels. Not a reason to audit now; it is a reason
   for the next audit to re-measure that border rather than trust the tick.
2. **Duplicate `ResultCard` at default type size.** The in-scroll card renders
   unconditionally, so the same rows exist twice — `CalculatorScreen.swift`'s F12
   comment says the breakdown renders in the scroll *instead* when the bar
   collapses, and the code does not do that. Code and comment disagree; the code
   is what shipped. Both read one `CalculatorResult`, so this is duplication, not
   a divergence risk.
3. **The keyboard accessory bar with a hardware keyboard attached.** With the
   software keypad suppressed the toolbar sits directly on the tab bar — visible
   in `IB2245732`. Real for any user with a Bluetooth keyboard. Written down, not
   fixed.
