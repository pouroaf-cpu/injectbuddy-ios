# Rules — earned the hard way

**Project law.** These are the rules the rest of the repo cites, and they are cited from
source comments, test suites, handovers and `CLAUDE.md`. They were written inside
`docs/ui-audit/BOARD.md` §5, which is an audit board; they outlive any one audit, so they
live here.

**The citation namespace is still `§5.NN`, deliberately.** Every rule keeps the number it
was written under. `§5.24` means rule 24 below, exactly as it meant rule 24 in the board,
and no citation anywhere in the repo was repointed to create this file. If you add a rule,
take the next free number by reading to the END of the list — the numbers must stay unique,
ascending and contiguous, which `BoardRuleCitationTests` asserts.

**This copy is additive.** The identical 39 rules are still in `docs/ui-audit/BOARD.md` §5
at the time of writing, and that is where `BoardRuleCitationTests` parses definitions from.
Nothing was removed from the board by this pass; the two copies get reconciled by a human
who checks the count first.

**Two of the four rules `CLAUDE.md` states up front are not numbered rules and are not
duplicated here:** *never tick a finding on inspection* is the board's own operating rule
(`BOARD.md` header, above §0), and *the unit test suite does not cover UI wiring* is stated
in `CLAUDE.md` only. The other two are below verbatim: *internally consistent code is not
evidence* is §5.1, and *a green indistinguishable from an absence is not evidence* is
§5.24. Do not give either of the unnumbered two a number without checking the list first.

---

## 5. Rules earned the hard way

1. **Internally consistent code is not evidence.** Three times this session code
   that was correct by inspection was wrong against reality: the RLS refusal, the
   `/api/dosages` assumption, the GLP-1 grouping. Each took minutes to settle by
   looking at the running system instead of the source describing it.
2. **Measure before changing a constant.** `heroOverhang` 22→38 was rebuilt and
   re-measured to *identical pixels* before being reverted. Shipped on suspicion
   it would have looked fixed on the dashboard while costing every screen 16pt.
3. **Contrast is symmetric.** Swapping foreground and background changes nothing.
4. **An outer `safeAreaInset` cannot lift a sibling inset pinned further in.**
   Anything pinned needs clearance where it is pinned.
5. **A montage is a survey instrument, not a measuring one.** A 12.7pt overlap
   read as "grazing" off a downscaled 4272px image.
6. **Hiding is not removing.** `allowsHitTesting(false)`, `opacity(0)` and
   off-screen offsets all stop a user *seeing or touching* an element and leave it
   in the **accessibility tree**. Anything conditionally shown needs
   `accessibilityHidden` as well as its visual guard. Found on the closed drawer,
   where fourteen calculator rows sat at x = -290 and were still swipeable.
   **Swept the rest** — hero circle, welcome Canvas, calculator toggle switch all
   already carry `accessibilityHidden(true)`; the offline banners are
   `allowsHitTesting(false)` but deliberately stay announced, because "You're
   offline" is meaningful status rather than decoration. No further instances.
7. **Prefer a container that truncates visibly over one that clips silently.**
   Truncation announces itself — "Testosterone Dosage…" tells you to go looking. A
   clipped container has no ellipsis, so a sheared line reads as a glitch or as the
   whole string. Measured: `.principal` renders two lines and shears the third with
   no visual signal, at every type size. Never accept silent clipping on a title, a
   value, or a unit — the same reason `lineLimit` on a value+unit pair is banned.
8. **Closing a finding protects the code that existed when you closed it.** New
   controls land underneath old bugs. The quick-value row arrived after F11 was
   closed and immediately sat under the pinned result bar — not a regression of the
   fix, a new surface arriving under an old problem. Anything added below the fold
   on the calculator gets checked against the pinned bar as a matter of course.
9. **The screens nobody complains about are where defects accumulate**, because
   attention follows complaints rather than risk. The log-dose sheet was a stock
   `.insetGrouped` list at audit time and got the least work of any screen. It then
   turned out to hold a touch-target violation, the app's worst contrast failure
   (2.13:1), no type scale at all, and a latent copy of the truncation bug — four
   for four, on the screen nobody was looking at.
10. **A component verified in one container is not verified.** `PrimaryButton` was
   measured on the calculator, scaled correctly, and was trusted. The same component
   in a `List` row did not scale at all.
11. **If taps die but `simctl` still screenshots, check the login session** before
   touching the Simulator — CoreSimulator is a daemon with no display dependency,
   so the symptom points the wrong way.
12. **An XCUITest tap can PASS against an occluded element.**
   `quick_mgWeek_400.tap()` reported success while the model never moved, because
   the chip was behind the pinned result bar. A passing tap is not evidence of an
   interaction; only a state change is. Assert the consequence, never the tap.
13. **An ambiguous element fails before your assertion runs.** `result_<label>`
   matched two elements — the pinned bar and the in-scroll copy — and the test
   died without ever printing its own message, which was then read as "the element
   is missing" for a whole session. Resolve identifiers through a helper that
   asserts exactly one match first, and name the surface in the identifier.
14. **A test cleaned up to be well-behaved stops exercising the path the bug lives
   on.** The specced fix for `testTypeThenChip` was "clear the field before
   typing". It would have worked — and nothing in the suite would ever have gone
   out of range again, so the clamp defect would have been tidied out of reach
   rather than found. Before making a test better behaved, ask what it stops
   reaching.
15. **Every audit gets a judgment pass, before any measuring.** Look at each frame
   and ask "would I ship this?", and write down anything that reads as wrong even
   when no number attaches to it. `2026-08-01-current/10-tools-ax5.png` passed the
   audit, and passed *correctly* — nothing truncated, nothing under 44pt, contrast
   fine — while showing `Semaglu-tide` hyphenated mid-word, `Tirzepatide` wrapping
   to an orphaned `e`, a clipped `Tools` title and icons that stayed small while the
   text went huge. Metrics are a floor, not a verdict: they were chosen to catch the
   last set of bugs, not the next one. This is rule 9 one level up — not which
   screens we looked at, but what we were capable of seeing when we looked.
16. **Every screenshot carries a serial and a log row** — `SCREENSHOT-LOG.md`,
   append-only, one row per capture event, with the capture time and the commit it
   was taken at. This project has twice shipped evidence that looked fine and was
   not. A serial plus a timestamp plus a SHA makes a stale or mislabelled frame
   detectable instead of plausible. No stamp inside the image: these frames get
   measured, and marking the pixels to label them means the file is no longer what
   the device rendered.
17. **A capture sweep must fail loudly.** With `continueAfterFailure = true`, a
   failed navigation produced a genuine photograph of the Tools screen under a
   filename claiming the TRT calculator. Assert the destination before shooting.
18. **A screenshot taken under a non-default rig configuration is not evidence
   about the default configuration.** `IB2245732` was shot with a hardware
   keyboard attached, so iOS suppressed the software keypad and the keyboard
   toolbar was photographed sitting on the tab bar — a position it never occupies
   in front of a user, and the pinned bar's relationship to it untested. Nothing
   in the image says so. Same family as the byte-identical "refresh" and the
   backgrounded home screen, except that this one flattered the fix, which is why
   it was easy to miss. Hardware keyboard, Reduce Motion, a non-standard device
   scale — none of them announce themselves. Re-shot as `IB2245735`.
19. **Report layout as a percentage of the viewport, never in lines.** "The
   greeting takes three lines" is comparable to nothing. "The greeting takes 31% of
   the content area at AX5" is comparable across screens, across type sizes, and
   against the same screen next week. Measure it off the framebuffer — a vertical
   band profile of the PNG — rather than from the view hierarchy, because that
   measures what the user sees rather than what the layout claims. Two denominators:
   full frame height (how the screen feels) and the content area between fixed
   header and tab bar (what you can actually change). Put the numbers in the
   screenshot log next to the serial, so drift is a diff rather than a re-derivation.
20. **The primary action must be reachable without scrolling at every supported
   type size.** Binary, not negotiable, and it is the rule with teeth: a percentage
   tells you *why* a screen is wrong, reachability tells you *that* it is. The AX5
   dashboard failed this today while every metric we had said it was fine — we had
   been arguing the percentage and missing the reachability all day. Decorative
   chrome over ~20% of the content area is a softer companion finding: it prompts a
   look, it does not force a fix.
21. **A capture run leaves the device dressed for the wrong test.** `simctl ui
   content_size` is device state, not run state. An AX5 sweep left it set and the
   next wiring run failed all four assertions against a reflowed layout — it read
   as "the app broke" and nothing had. Reset it in the same command that sets it.
22. **The judgment pass applies to every frame at every size, not just the
   accessibility ones.** Every finding today came out of AX5 frames — not because
   the default screens are clean, but because those were the frames anyone looked
   at. Applying the viewport method to a *default*-size frame we had captured and
   never judged immediately found the result bar taking 52% of the content area and
   two of five inputs above the fold. §5.7 again, one level up: the AX5 frames are
   not the audit, they are the half that is easier to see.
23. **A test that cannot fail is worse than no test, and it is easy to spec one by
   accident.** "Assert the displayed string contains no ellipsis" was specced as
   the fix for the truncation class. It passes on the exact frame that renders
   `1…`, because the accessibility layer returns model text and not rendered
   glyphs — measured: `field.value == "100"` while the screen showed `1…`. Before
   writing an assertion, ask which layer actually observes the thing being
   asserted. Then reproduce the defect and watch the test go red; a test that has
   never failed has not been shown to work.
24. **The checks that fail us are the ones that cannot fail.** Four came out on
   2026-08-02 alone, from four unrelated directions, and every one of them reported
   success:
   - `continueAfterFailure = true` turned a failed navigation into a photograph of
     the wrong screen, filed under the right screen's name.
   - A suppressed software keyboard produced a frame that *flattered* the fix it was
     taken to prove.
   - Two "different" captures came back byte-identical because the gesture between
     them never landed.
   - "Assert the displayed string contains no ellipsis" reads the accessibility
     model, not the render, so it passes on the exact frame showing `1…`.
   Note what they have in common: none of them were wrong about something, they were
   silent about everything. A check that has never been observed to fail has not been
   shown to work, and its green is indistinguishable from its absence. So: reproduce
   the defect and watch the assertion go red before trusting it, ask which layer
   actually observes the thing being asserted, and make the harness able to fail —
   `continueAfterFailure = false`, assert the precondition, assert frames differ,
   count matches before resolving. Every guard added today came from a check that
   had been quietly passing.
25. **A view measured under a compressing proposal reports a height it will never
   render at.** SwiftUI proposes a `.background` the size of the view it decorates, so
   a candidate laid out there is SQUEEZED to fit rather than reporting its own ideal
   height. The pinning gate measures four candidate bars this way, and at AX5 the full
   bar measures **642.33pt against a 617.67pt content area — 104%**. Without
   `.fixedSize(horizontal: false, vertical: true)` that candidate would have come back
   clamped to the container, the gate would have approved **exactly the bar it exists
   to stand down**, and every number downstream would have been arithmetically perfect
   and about a layout that does not exist. Anything measured to make a decision must be
   measured free of the proposal, or the measurement is of the constraint and not of
   the thing.
26. **`TEST_RUNNER_` reaches the RUNNER, not the app under test.** `xcodebuild` forwards
   prefixed host environment into the test process; the app is a separate process and
   sees nothing unless the test copies it into `app.launchEnvironment`. A DEBUG override
   that drives the pinning gate was set for a whole run, changed nothing, and the run
   reported **success** — while photographing the default gate under a filename claiming
   the override. That is the fifth check in two days that reported success while
   observing nothing, and this one was observing the override that PROVES the gate
   works. The app now publishes the value it actually resolved and the test asserts the
   override arrived; forwarding without asserting arrival is the same bug one step
   later.
27. **Never select a material by its name.** The names describe THICKNESS, and thickness
   is how much backdrop shows through — not how light the result is. Measured on the
   calculator's pinned plate, one run, same screen and scroll position:
   `ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB · regular #FEFEFE · thick #FFFFFF`.
   `.ultraThinMaterial`, the obvious reading of "transparent with a light blur", came
   out **101 values darker** than the near-opaque `.bar` it was meant to lighten. That
   is not an anomaly, it is the general case over a dark or absent backdrop. Measure the
   ladder on the actual screen, every time.
28. **A gesture that registers as the wrong gesture moves nothing and reports
   success.** `coordinate.press(forDuration: 0.4, thenDragTo:)` was used to walk a form
   in small steps; 0.4s registers as a PRESS and scrolled **zero pixels**, so six
   capture positions would have been one frame under six names. Caught only because the
   sweep asserts the FIRST gesture changed something before letting later no-ops end the
   loop. `swipeUp(velocity:)` is a swipe at any velocity; a long press is not a drag.
29. **A test process's Documents directory SURVIVES between runs.** When a frame is
   skipped — a guard returning early, a run failing partway — the previous run's file is
   still sitting under the name this run meant to write, and the host copies it out as
   this run's evidence. It gets measured, serialised and cited while being a photograph
   of different code. Nearly happened. Fixed rather than written down: the
   directory is emptied at run start, and a frame that is not on disk afterwards fails
   the run instead of resolving to whatever is there.
30. **When an assertion is unsatisfiable, name what makes it unsatisfiable — do not
   narrow the condition until it passes.** The reachability sweep found a real shear on
   `Steroid Dosage` at AX5 that no pinning gate can fix, because the bar is already at
   its floor there. The first response was to stop asserting the straddle rule at
   accessibility sizes. That bought silence on ONE known screen and paid for it with the
   assertion on EVERY screen at AX5 — including the ten not yet surveyed, at the size
   every finding this week came out of. It was a size gate on a test, which is the same
   mistake as a size gate on the bar and wrong for the same reason: a size is a guess at
   where the problem lives.
   The replacement is a NAMED EXPECTED-FAILURE LIST, asserted from both ends: a listed
   case must still fail, and the run goes red the moment it starts passing, telling you
   to delete the entry. An entry naming a control that is not on screen fails too, so a
   stale entry cannot sit there suppressing nothing. Both directions were reproduced
   before being trusted.
   The difference is not cosmetic. **A narrowed check stays narrow forever and nobody
   remembers why; a listed one has to shrink.** And a filed finding plus a green suite
   still reads as green — the list puts the debt in the place people actually look,
   which is the run.
   Corollary, from applying the same rule to the folder check below: scoping by a
   DOCUMENTED, DATED boundary is legitimate where scoping by "which ones fail" is not.
   `2026-08-01-current` is exempt because the serial rule starts on 2026-08-02 and says
   so in writing — and even that exemption is asserted from the other end, so a
   pre-serial folder that gains serials rejoins the rule instead of falling in a gap.
31. **A name that outlives its content is the failure mode this project keeps
   rediscovering, and nothing was checking the names.** The `2026-08-02-current` README
   listed `IB2245743` and `IB2245744` after those files had been superseded, and never
   listed `IB2245748` at all — a table naming frames that were not there, and a folder
   holding a frame the table did not know about. **Neither harness ran that check; a
   human caught it by reading the table against a checkout.** Now
   `AuditFolderConsistencyTests` asserts it in BOTH directions, because the failure that
   happened was one direction and the other is just as reachable. Shown red both ways
   before being trusted. The whole evidence chain — serial, log row, commit SHA — is
   worth exactly what the link between a name and a file is worth.

32. **An exemption is safe when the exempted set CANNOT GROW — enumerate it, do not
   predicate it.** `AuditFolderConsistencyTests` grandfathers the pre-serial capture
   folders out of the serial rule. Written as a date predicate — "folders dated before
   2026-08-02" — the set is evaluated at runtime and closed only by CONVENTION: a folder
   named `2026-07-30-something` created next week satisfies it and walks straight out of
   the rule, and the innocent version (someone reorganising an old capture) is likelier
   than the adversarial one. Written as a literal list it is closed by construction.
   **The general test:** ask what could join the exempted set tomorrow. If the answer is
   "nothing", it is a grandfather clause. If it is "anything of that kind, including
   things not built yet", it is a NARROWING and the debt needs naming instead (§5.30).
   And assert the exemption FROM THE OTHER END: an entry that never matches anything is
   exempting nothing and hiding that it exempts nothing.
   **THE PAIR THAT MADE THE DISTINCTION VISIBLE, an hour apart, only one legitimate.**
   Switching the straddle assertion off at accessibility sizes was a NARROWING: the
   exempted set was open — every screen at AX5, forever, including the ten not yet
   surveyed and every screen not yet written — so it silenced cases nobody had looked at.
   Grandfathering `2026-08-01-current` out of the serial rule is a GRANDFATHER CLAUSE:
   the set is folders that already existed when the rule landed, and nothing can join it
   because time only moves one way. Same word, opposite structure.
   **The alternative that looks obvious and is worse:** backfilling serials onto those
   frames. That manufactures a provenance which never existed — §5.16's reasoning with
   the sign flipped, since an in-image stamp was refused for mutating evidence in order
   to label it. A documented gap is honest; an invented serial is a number that looks
   issued and was not.

33. **When a finding is closed by a check, RECORD WHAT SURFACE THE CHECK WAS AIMED AT.**
   The finding gets remembered as closed and the AIM gets forgotten — and the aim is the
   whole of what was actually established.
   **F-D is why it is a rule.** F1 was a truncation finding FOUND ON A RESULT CARD. The
   check that closed it compares `field_<key>` against `unit_<key>`, so it never looked
   at a result row in its life. Its logic was not wrong; its AIM was. A green tick sat
   over the surface the finding was found on for two days, and a closed item does not
   get re-examined.
   **It has now paid out twice more, on the same day it was written.**
   `PinnedBarReachabilityUITests` implements D5 and is aimed at 3 of 15 calculators —
   `IB2245770` is an input sheared by the plate AT DEFAULT SIZE on one of the twelve it
   never looks at. And nothing at all is aimed at result rows against the plate, which
   is three more sheared frames in the same sweep.
   So a closure reads "closed by X, **aimed at Y**", and when Y is not the surface the
   finding was found on, that is a second finding rather than a footnote.
   Do not run it as a sweep — sweeps done in a hurry are where regressions come from
   Add the line as each area is touched; T11 is the natural first pass, and it
   should treat result cards as an UNSURVEYED SURFACE rather than a re-check.
   **AMENDED BY §5.38, and the amendment matters more than the rule it qualifies.** The
   D5 example above — "aimed at 3 of 15 calculators" — was true and was **not the
   reason** that suite was green over a defect. It was also addressing the wrong element
   entirely. Recording an aim is necessary and it is not sufficient: a check can be
   pointed at the right screen and still be reading something else on it. Ask BOTH — what
   surface, and what element — because an aim gap and an addressing gap present
   identically and their remedies are opposite.

34. **THE ACCESSIBILITY TREE HAS NO Z-ORDER AND NO CLIPPING, so a geometric check
   cannot tell "these share pixels" from "one of these is behind an opaque plate".**
   `LeafOverlapUITests` is the newest check here and this is its blind spot, found the
   day after it landed. It reported the hero overlapping
   `Maths only — not medical advice.` by 19.33 × 13.0pt on six calculators. Cropping
   `IB2245765` and reading the pixels: at y 720–820 there is the navy `Add` plate, the
   hero circle and the tab bar, and **the disclaimer string is nowhere in the frame at
   all**. Both elements are in the tree, the geometry is correct, and one of them is not
   drawn.
   The suite is still right that something is wrong — it is wrong about what. **Never
   read a red overlap as proof of a VISIBLE defect without looking at the frame**, and
   never read a green one as proof the content is legible: an element hidden under an
   opaque surface produces no overlap with anything and no complaint from any check we
   own. Caught only because the frame was cropped instead of the number being trusted.

35. **An assertion can observe the wrong MOMENT rather than the wrong thing, and it
   fails in a way that reads like a finding.** Two in one afternoon, same shape:
   "`Cycle Plotter` is not in the dialog either — it would be unreachable from anywhere
   in the app" was reported about a dialog **that had never opened**, because the tap
   landed on the tab bar's `Add` rather than the section's. And "No dashboard scroll
   view" came from a single query issued straight after a tab switch, which cannot
   distinguish *not there* from *not there yet* — it passed in a standalone probe
   precisely because the app had settled there and the real run had not.
   **A probe that is greener than the run it models is not a simpler version of it.**
   So: assert the PRECONDITION before drawing a conclusion from its contents, and retry
   anything read across a transition. A failing assertion is evidence about the app only
   once you know it was looking at the app you think it was.

36. **A CHECK MUST BE ABLE TO OBSERVE THE CONDITION ITS OUTPUT ASSERTS.** The capture
   harness names every frame in a default-size sweep `…-default…` and files them in a
   folder documented as default size — and until `9b4afcb` nothing in it could see the
   device's type size. `bar_gate` published `ax=true/false`, which reads **identically
   at `large`, `xLarge` and `xxxLarge`**, so a sweep run at the wrong size produced a
   full set of frames whose names asserted something the run had no way to check, and
   reported success.
   That is the **seventh** check found reporting success while observing nothing, and it
   is the one that would have quietly invalidated every "at default size" claim made in
   this audit. The probe now publishes `size=<category>` and the run fails before
   writing a single frame unless it reads `size=large`.
   **Generalised:** whenever output — a filename, a folder, a log row, a commit message
   — asserts the conditions a run happened under, something in the run must MEASURE
   those conditions. Otherwise the assertion is a label applied by intention, and
   intention is exactly what the rig does not preserve.

37. **A FINDING STATES THE SCOPE OF THE SAMPLE IT WAS FOUND IN, NOT THE SCOPE OF THE
   DEFECT — and it does it silently, because the sentence reads the same either way.**
   "Sheared on BPC+TB500" and "sheared on BPC+TB500, of fourteen calculators measured"
   are different claims, and only the second tells the next person whether to go
   looking. So: **when you write a finding, write what you looked at next to it.**
   **Four times in one day, all four caught by the person who wrote them** — which is
   the argument for the rule, not against it. "The hero/disclaimer overlap happens in
   exactly one place" came from walking three screens; the fourteen-screen enumeration
   made it six. "`Cycle Plotter` may be unreachable from anywhere in the app" came from
   one dialog that had never opened. **F-F** was filed as every calculator and is six.
   **F-B** was filed as one screen and is five.
   **This is §5.33's mirror, and the pair is most of what went wrong today.** Record
   what surface a CHECK was aimed at; record what sample a FINDING was drawn from. Same
   failure at opposite ends of the same sentence — F-D was the ratio sweep's aim, and
   D5 aimed at 3 of 15 calculators is the same thing again. A scope nobody wrote down
   is read as "all of it" by the next person, and by you in a week.

38. **A CHECK THAT ADDRESSES A CONTROL BY A STRING THE APP USES TWICE IS MEASURING
   WHICHEVER ONE IT FOUND, AND CANNOT TELL YOU WHICH.** `PinnedBarReachabilityUITests`
   asked for `buttons.matching(identifier: "Add").first { $0.isHittable }`, with
   `?? buttons["Add"]` behind it. **The bottom tab bar has an `Add` slot with the same
   label.** So the query had two answers on every calculator, and the selector it used
   to choose — "the hittable one" — is the very property being asserted. On any screen
   where the real CTA was not hittable, which is the entire finding the assertion
   exists to catch, it selected the TAB ITEM and went green. Three screens, both
   assertions, silently satisfied by an element from a different view.
   **This is the eighth check found reporting success while observing nothing, and the
   first found by accident** — it surfaced only because the CTA was given an identifier
   for an unrelated reason (gating it on `canSaveProtocol`) and the suite immediately
   went red on all three screens. Nobody was looking for it.
   **Three things it costs, in order of how badly:**
   (a) A fallback (`??`) whose branch is invisible in the result. A run cannot tell you
       it took it. If the fallback resolves to something plausible, it is not a fallback,
       it is a second answer with no label.
   (b) A selector that filters on the property under test. `first { $0.isHittable }`
       cannot ever report "not hittable"; it reports "no element", or it reports a
       different element. Never choose the subject of an assertion by the predicate of
       that assertion.
   (c) **A plan built on the false negative.** The queue had "widen D5 from 3 screens
       to 15" ahead of the fixing work, on the reasoning that its hittability assertion
       "already exists and would go red on BMI today". It would not have. Widening the
       aim would have produced fifteen green results about a tab bar. **An aim gap and
       an addressing gap look identical from the outside — both present as a check that
       is green where you expected red — and the remedies are opposite.** Before
       widening a check's aim, confirm it measures the right element at its current aim.
   **The remedy is an identifier and a COUNT.** `cta_add`, resolved through the
   count-first helper that fails by NAMING the duplicates. `firstMatch` and
   `first { … }` both answer a question you did not ask when the query is ambiguous;
   only counting tells you the query was ambiguous.

39. **A PROBE ADDED SO SOMETHING COULD BE MEASURED BECAME THE DEFECT IT WAS MEASURING —
   check where you attached it, not just what it publishes.** `bar_plate` exists so the
   reachability check can read the plate's rendered top edge instead of trusting the
   pinning gate's arithmetic, which was the right instinct and is still the right
   design. It was attached with **`.overlay`**. A `Color.clear` carrying
   `.accessibilityElement()` therefore sat on top of the whole result bar in the
   accessibility tree, including the `Add` button inside it, and made the primary CTA of
   every calculator report `hittable=false`. `.background` publishes a byte-identical
   frame — `(0.0, 564.6666666666666, 402.0, 226.33333333333337)`, measured both ways —
   and does not sit over the control.
   **The general shape: an accessibility probe is not passive.** It is a real element in
   the tree the harness reads, and — worse — the tree that VoiceOver and Switch Control
   read. A zero-cost observer that changes what it observes is the oldest trap there is,
   and here it changed the thing for USERS, not merely for the test. `gateProbe` is the
   version that got this right by accident (`Color.clear` at 0×0), and it is worth being
   explicit that it was luck: prefer `.background`, size zero where you can, and when a
   probe must span a region, ask what it is now standing in front of.

---

### The rules list, checked against itself

**FIXED, AND IT WAS WORSE THAN THE CASE THE CHECK WAS PROPOSED FOR.** The check was
proposed to catch *missing text* — §5.32 and §5.33 were cited as settled by the TASKLIST,
by the directing side and by a comment inside `AuditFolderConsistencyTests` while nothing
stood behind either number. What was on disk was **two different rules numbered 32 and
two numbered 33**, both pairs real and substantive. `003e859` wrote 31–33 in **descending
order** (`33, 32, 31`); `9b7d9b2`, scanning forward from 30 for the next free number, did
not see them and wrote fresh text for 32 and 33 at the end. For a day, every `§5.32`
citation in this repository resolved to a coin flip — **including the one inside the test
that exists to enforce that rule.**
The duplicates are merged, not deleted: everything unique to each draft was folded into
the surviving entry (§5.32 keeps the narrowing-versus-grandfathering pair and the
backfilled-serials argument; §5.33 keeps the do-not-sweep tail). The list is now `1…39`,
contiguous, each number once, ascending — parsed and asserted, not eyeballed.
`BoardRuleCitationTests` now asserts three things and **the third is the one that would
have prevented it**: numbers unique, every `§5.NN` cited anywhere in the repo resolves,
and the rules ascend without gaps. An ordering defect became a correctness defect, because
"find the next free number" is a forward scan and a descending run is invisible to it.
Shown red in all three directions before being trusted (§5.24).
