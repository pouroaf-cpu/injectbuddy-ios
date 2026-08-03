# Tasks — the live findings list

**This file was a 2026-07-31 build backlog. It is now the consolidated findings list**, transcribed
from `docs/ui-audit/BOARD.md` §1–§4 on 2026-08-03 (task D2).

**This pass is ADDITIVE. Nothing was struck from `BOARD.md`** — not a line deleted, not an item
marked moved. The board still carries every finding below, in full, and remains the authority on the
evidence. This file is the queue you work from; the board is what you cite. **A human reconciles the
two and decides what gets struck**, using the two-way count in `§0` before anything is removed.

The old backlog is not deleted either — it is preserved verbatim in `§6`. Two of its entries
(TASK 20, TASK 21) are live P0 engineering work that has no board finding behind it, so deleting the
backlog would have lost them.

---

## The one sentence the owner should read first

> **A protocol saved from iOS is invisible, and a dose logged against it is discarded — so the Add
> flow, the app's primary write path, has never produced a usable row on any build.**

Three P0s in `§5` compose into that sentence and none of them is visible from the screen: `X-03`
(`dose_log` writes omit `user_id`, so no iOS-written dose has ever landed), `X-04` (saved protocols
land `draft`/inactive and nothing can activate them, so every consumer filters them out), and `X-05`
(the *un*log half of the same toggle succeeds, so iOS can permanently delete a web-logged dose it
cannot re-create). `X-06` is why none of it ever surfaced as an error, and `X-07` is why no
automated check was in a position to notice.

**A separate launch blocker, unrelated to the above:** `X-02` — the app offers account creation and
has no working in-app account deletion. That is a rejection at App Review, not a defect backlog item.

---

## 0. The count, both ways

Read out of `BOARD.md`, written into this file:

| BOARD section | findings read | entries written | ids |
|---|---|---|---|
| §1 Open — assigned | 34 | 34 | `B1-01` … `B1-34` |
| §2 Open — unassigned, needs a human decision | 9 | 9 | `B2-01` … `B2-09` |
| §3 Closed — with the evidence that closed it | 26 | 26 | `B3-01` … `B3-26` |
| §4 Known and not knowable | 5 | 5 | `B4-01` … `B4-05` |
| **total** | **74** | **74** | |

**Delta: zero.** No finding was merged, split, or dropped. Four things that could be read as a delta
and are not:

1. **§1 contains 36 checkboxes and 34 findings.** Two of the 36 sit inside `<details>` blocks and are
   the *superseded original wording* of the item above them — `1. Animated welcome screen` inside
   `B1-29`, and `Calculator quick buttons — code done` inside `B1-31`. They are carried inside their
   parent entry as history, not counted as findings. Nothing is lost either way.
2. **`B1-04` is partly withdrawn, not dropped.** Its BMI and Free T Index halves are withdrawn by the
   owner; its Semaglutide half is live. One board finding, one entry, one withdrawal note inside it.
3. **Deferred items are still entries.** `B1-09`, `B1-11`, `B1-15` and the tail clause of `B1-26` are
   marked deferred with the owner's name. Deferred is a scheduling state; it does not change the
   evidence status and it does not remove an entry.
4. **The `X-` entries are not from the board.** `X-01` arrived from the directing side during this
   pass; `X-02`…`X-09` arrived from it on 2026-08-03. All are recorded in `§5`, outside the 74, so
   the count check does not read them as an unexplained delta. Four of them are P0 — see the
   one-sentence summary above.
5. **`DUP-01`…`DUP-15` are not from the board either.** They came out of the 2026-08-03 duplication
   sweep (task S2) and are recorded in `§8`, outside the 74, for the same reason. They are findings
   *about the documents*, not about the app — no `DUP-` entry adds or removes an app defect.

**Statuses are transcribed, never upgraded.** In particular §4 is **NOT KNOWABLE** and is not a tick —
per `CLAUDE.md`, unverifiable goes to §4, not to a closed item. `B4-04` says "ACCEPTED" and is still
not knowable.

Legend, matching the board's own markers:

| here | board | means |
|---|---|---|
| `OPEN` | `- [ ]` | open, unfixed |
| `CLOSED — evidence` | `- [x]` | closed by a measurement or a screenshot, never by inspection |
| `PARTIAL` | `- [~]` | landed in part; the rest is named in the entry |
| `NOT KNOWABLE` | §4 plain bullet | cannot be established; not a tick and never becomes one |

`DEFERRED` and `WITHDRAWN` are overlays. They say what is scheduled. They do not change the status
above them.

---

## 1. From BOARD §1 — open, assigned

### `B1-01` — SAFETY: four interactive controls sit under the pinned bar at default size
**OPEN.** The barrel-size row — `0.3 mL (30u)`, `0.5 mL (50u)`, `1 mL (100u)`, `3 mL (IM)` — on
`TRT Dose` and `Steroid Dosage`. Each enabled, 44pt, wholly inside the window at **y 590.67…634.67**;
the result plate's top edge is **564.67**. `isHittable` false for all four on both screens, so no
VoiceOver or Switch Control user reaches them from that position at all.
Why nothing caught it: `PinnedBarReachabilityUITests` measures `field_*` and `control_*` only and
says so in its own coverage note — segmented rows carry no per-control identifier. Found by
`ProbeAttachmentUITests`, which was looking for something else. Carried as `knownOccluded`, asserted
from both ends (`§5.30`). Fix is a layout change, with the other default-size shears.

### `B1-02` — probe attachment audit: all three probes measure clean
**CLOSED — evidence.** Frames as reported by the accessibility layer: `bar_plate` (`.background`)
`402.0 x 226.33`; `bar_gate` (`.overlay`) `0.0 x 0.0` on three screens; `trunc_<id>`
(`.overlayPreferenceValue`) `0.0 x 0.0`, 9 on TRT, 5 on Reconstitution, 10 on Steroid. Two are still
overlays and that is fine **because they measure zero**, not because zero was declared in source.
**Aimed at** (`§5.33`) `TRT Dose`, `Reconstitution`, `Steroid Dosage` at default — 3 of 15. Cost
~226s for three screens; do not run per commit.

### `B1-03` — SAFETY: an input is sheared by the pinned bar at default size, with `Add` enabled below
**OPEN.** `IB2245770`, `BPC+TB500`. `TB-500 bac water` cut through its own control by the plate's top
edge; `Add` below it at full width, legible and enabled. F-A's shape and D5 word for word, except
F-A is AX5 on one screen and this is the size everyone uses, on a screen nobody had photographed
until `9b4afcb`. The real item is the aim: `PinnedBarReachabilityUITests` covers 3 of 15 screens.

### `B1-04` — result cards are sheared by the plate at default size too
**OPEN, in part. PARTLY WITHDRAWN — owner (Pouroa), 2026-08-03, H6.**
- `Semaglutide` (`IB2245766`) cut through `Units (U-100)` — **live**.
- ~~`BMI` (`IB2245771`)~~ and ~~`Free T Index` (`IB2245772`)~~, both cut through the word `Normal` —
  **withdrawn**. The owner's words: *"leave them alone, and don't let the links to it go anywhere, we
  will work on later."* No layout, shear or styling work on either screen. Routes in were removed at
  `bf52ecc`; the screens and the engine stay intact behind `isListed`. Recorded, not carried.

Nothing watches result rows against the plate — the reachability sweep reads `field_*` and
`control_*` only. Same aim gap as `B1-03`, so likely one fix.

### `B1-05` — SAFETY / DATA: the app displays protocol rows that were never started
**OPEN.** The write half of this finding is closed (`B3-01`); **this is the display half and it is a
different finding.** `SupabaseBackendClient.savedDosages()` selects
`id, calculator_type, label, config, created_at, start_date, is_active` ordered by `created_at` with
**no filter on `status` or `is_active`**. 71 of 102 production rows are `draft`; 24 of 39 users have
nothing active at all, so their whole list is drafts presented as running protocols.
Gating the CTA stops new rows of this kind. It does nothing about the rows already on people's
screens. **Do not read the tick on `B3-01` as covering both ends.**
When fixing: filter on `status`, **not** `is_active` — the mirror carries two of the three states.
Hiding "archived" fixes nothing; no row has ever been archived.
Original filing (`IB2245771`, `IB2245772`) is on the board in full, including the driven BMI write,
the row's exact `config`, and the *"ADDED TO YOUR PROTOCOLS"* confirmation over a height and a
weight. That evidence stands; it is history, not live BMI work.

### `B1-06` — `Cycle Plotter` is absent from the screen whose job is listing calculators
**OPEN.** `CalculatorCategory.members` enumerated **14 of the 15 slugs** and `.cyclePlotter` is in
none, while `ToolsScreen`'s own comment says it shows all of them "including … the plotter". T18's
shape a third time: source describing an intention rather than behaviour. Found by the capture sweep
dying on it — thirteen calculators located by the identical mechanism, this one never appeared after
twelve scrolls. Its only route is the dashboard `Add a protocol` dialog: **eight drags**, 16 actions
on an 874pt display. Frame `IB2245775`.
Note for whoever picks this up: `bf52ecc` changed `members` to filter on `isListed`, which withdrew
BMI and Free T Index. `cyclePlotter` stays deliberately reachable (H7–H12 build on it), so this
finding is unaffected by that commit and still open.

### `B1-07` — a primary CTA reported itself as not hittable *(board entry struck through — resolved)*
**OPEN on the board's marker, RESOLVED in substance — see `B3-02`.** Kept because two things in the
original filing are now known WRONG and are worth more than the fix:
1. **It was never a BMI finding.** True on TRT Dose, Reconstitution and Steroid Dosage too — every
   calculator, since they all render the one shared `resultBar`. `§5.37`: the sentence stated the
   scope of the sample.
2. **The claim that D5 "would go red on BMI today" was FALSE.** `assertReachable` resolved `Add` by
   LABEL and the bottom tab bar has an `Add` slot with the same label; `first { $0.isHittable }`
   picked the tab item. On all three screens it covers, the assertion was measuring the tab bar and
   going green. Widening the aim would have produced fifteen green results about a tab bar. The CTA
   now carries `cta_add` and is counted, not `firstMatch`ed. **Eighth check found reporting success
   while observing nothing, and the first found by fixing a different bug.** `§5.38`.

### `B1-08` — SAFETY: `Add` is enabled over a dose the user cannot read
**OPEN.** `IB2245752`, `Steroid Dosage` at AX5. `field_mgWeek` spans y 636.33…701.33 against a plate
top of 651.67, so `Weekly dose` is sheared through its own digits — and `Add` sits below it at full
width, legible, enabled, and **`Add` writes a protocol**. One complete input is usable on that screen
at AX5 and it is not the dose. Filed as safety, not layout.
The pinning gate cannot fix it: at AX5 the bar is already at its FLOOR. Carried as a named expected
failure in `PinnedBarReachabilityUITests.expectedShears` (`§5.30`).

### `B1-09` — APP-WIDE: every menu picker draws outside its own control at large text
**OPEN. DEFERRED — owner (Pouroa), 2026-08-03, H3.** Alias **F-E**.
`IB2245752` (`Steroid Dosage` · `Compound`, `Oxandrolone (Anavar)`) and `IB2245753` (`TRT Dose` ·
`Ester`, `Testosterone Enanthate`). The selected value wraps to three lines that overflow the field
chrome and render on top of the label above — two strings in the same pixels, neither legible.
Structural, not one screen: `FieldRow.content` is the only call site; `.picker` and `.stringPicker`
both render `Picker(...).pickerStyle(.menu).fieldChrome()`, so **12 picker fields across 8
calculators** share it. `CyclePlotterScreen` renders two `.menu` pickers *without* `fieldChrome` and
is NOT covered.
The observed case is not the worst: `Equipoise (Boldenone Undecylenate)` and
`Primobolan (Methenolone Enanthate)` at **34 characters**, `Nandrolone Phenylpropionate (NPP)` 33,
`Drostanolone Propionate (Mast-P)` 32 — the last two on TRT's Ester picker. `Oxandrolone (Anavar)`
is 20. Length-dependent: `2×/week` sits cleanly inside its box in the same frame.
**No existing check can see this** — nothing truncates and nothing clips, so the ratio sweep, T19's
renderer probe and the reachability sweep are all blind. Fourth mechanism in the F1 family.
**Deferral, exactly:** H3 decides the fix direction (controls grow downward, text never spills) and
absorbs this item, so it is not live work as a separate fix.
**MEASUREMENT REQUIRED before this is called dormant — do not assume either way:** does any part of
it reproduce at **DEFAULT** text size on `trt` or `peptide`? Both carry pickers (`TRT Dose` ·
Frequency/Ester, `Peptide` · Dose unit). The board's evidence for this finding is AX5 only; there is
no default-size frame either way. If it reproduces at default on either slug, **that part is live
work now** and does not wait for H3.
H3 also records what is already ruled out: `.fixedSize(horizontal:false, vertical:true)` on the menu
picker changed the geometry by nothing, byte-identical. Growth needs `.pickerStyle(.menu)` replaced
by a `Menu` whose label we lay out. Four invariants ride on that control — 44pt tap target,
accessibility label, `control_<key>` identifier, `unique(_:type:)` — re-assert all four after any
swap.

### `B1-10` — a new check, currently RED: no two content leaves may share pixels
**OPEN.** `LeafOverlapUITests`. Overlap is the fourth mechanism in the F1 family and the first one no
existing check could see. The invariant names no mechanism: two frames sharing pixels.
**Leaves, not siblings** — the sibling formulation would have gone GREEN on the frame it was written
for, because `Oxandrolone (Anavar)` is a child of the picker button and `Compound` is the button's
sibling. **Shown red on the target defect** (`Compound` × `Oxandrolone (Anavar)`, 148.6 × 49.3pt)
before being trusted. **STATE: AX5 green with 8 named debts; DEFAULT still red. Not claimed green.**

| where | pair | size |
|---|---|---|
| Steroid Dosage | `Compound` × `Oxandrolone (Anavar)` | AX5 |
| Steroid Dosage | `Oxandrolone (Anavar)` × `Vial strength` | AX5 |
| TRT Dose | `Ester` × `Testosterone Enanthate` | AX5 |
| TRT Dose | `2×/week` × tab bar | AX5 |
| TRT Dose | `2×/week` × hero glyph | AX5 |
| Reconstitution | `result_Add bac water` × tab bar | AX5 |
| Reconstitution | `result_Add bac water` × hero glyph | AX5 |
| Reconstitution | `Add bac water` × hero glyph | AX5 |
| **all three** | `Maths only — not medical advice.` × hero glyph | **default** |
| Reconstitution | `result_Units (U-100)` × tab bar | **default** |

Two are at DEFAULT and neither was on the board — `§5.22` again.
Note the interaction with `B1-11`: H4 deletes the disclaimer expected-failure entries, which is the
row marked **all three**. The `result_Units (U-100)` default row is untouched by that and stays red.

### `B1-11` — the disclaimer is unreadable at rest on every calculator
**OPEN. DEFERRED — owner (Pouroa), 2026-08-03, H4: WON'T FIX, his call.** Alias **F-F**.
He was shown that "not medical advice" is never legible at rest on any calculator and said it does
not matter. Recorded as his decision, with the date, and **not to be re-raised by a later session as
an oversight.** H4 also removes the expected-failure entries that carry it, so the overlap suite
stops tracking a debt nobody intends to pay.
The measurement is kept because it was expensive and because a later reversal would need it. Measured
at rest on all fourteen at `9b4afcb`. The hero/disclaimer intersection is **SIX** calculators, not
every one, identical on all six — Reconstitution, Semaglutide, Tirzepatide, Retatrutide, BMI, Free T
Index — each `(172, 762, 19.33 × 13.0)` = 251.3pt². The hero never moves: `(172, 762, 58, 58)` on
every screen at every scroll offset. The other eight put the disclaimer below an 874pt display
(y 909.67–1120.67), except `BPC-157` at y 841.67, inside the tab bar's region (starts y 792).
**And on the six the disclaimer is not drawn at all** — `IB2245765` cropped and read off the pixels:
the tree reports the string at y 761.67; the pixels at y 720–820 are the navy `Add` plate, the hero
circle and the tab bar; the string appears nowhere in the frame. So the finding as filed describes an
accessibility-tree intersection between two elements, one of which is not drawn (`§5.34`).
**Deterministic, not intermittent** — byte-identical `19.33 × 13.0` from a standalone walk probe and
from the sweep. Two of the three `isIntermittent` entries for this pair (`TRT Dose`,
`Steroid Dosage`) name a collision that cannot occur at rest at all and are dead entries.

### `B1-12` — content draws into the tab bar and past the bottom of the display at AX5
**OPEN.** A picker value on TRT and a result row on Reconstitution both reach into the tab bar;
`Testosterone Enanthate` extends to y 915 on an 874pt display. `heroOverhang` is 22pt and reserves
for the circle, not for this.

### `B1-13` — `accessibilityHidden(true)` does not remove the hero glyph
**OPEN.** `§5.6` was wrong rather than incomplete. `Image 'syringe'` sits in the tree as a leaf at
`(172, 762, 58, 58)` on every calculator — the circle's own frame, centred at x = 201 on a 402pt
window, ancestors all generic full-window containers rather than the TabBar, so it IS the raised hero
and not a second glyph. **Measured twice**, byte-identical: with the flag on the composed hero, and
with it applied directly to the `Image`.
So a decorative glyph is a VoiceOver stop on every screen in the app, and `§5.6`'s sweep was reading
the source rather than the tree — `§5.1` on our own audit.
**This invalidates an assumption in `RESULT-PANEL-SPEC §5`**, which specs the barrel-fit strip as
`.accessibilityHidden(true)` and relies on that to keep a decorative duplicate of the dose figures
out of the tree. It must not ship on that assumption: assert the absence on the strip itself, red
first with the modifier removed. A working mechanism is not yet identified.

### `B1-14` — `Steroid Dosage`'s screen title truncates to `Steroid Dos…` at AX5
**OPEN.** `IB2245752`. `§5.7` bans this outright — never accept silent clipping on a title, a value
or a unit. H5 (calculator name into the nav bar) is the fix and must not undo it: titles never
truncate, and the PWA's own truncating header is deliberately **not** the parity target.

### `B1-15` — `Oxan-drolone`, hyphenated mid-word
**OPEN on the board's marker. REVERSED — owner (Pouroa), 2026-08-03, H3.** `IB2245752`, same family
as `Semaglu-tide` on Tools (`IB2245747`).
**Mid-word hyphenation is now accepted behaviour, not a defect.** The human chose it explicitly with
the alternative shown. `Semaglu-tide` and `Retatru-tide` likewise. **Do not re-file hyphenation** —
it was raised, shown, and decided against. Not live work.

### `B1-16` — the result bar owned 52.40% of the content area at DEFAULT size
**CLOSED — evidence.** Gated on a **measured share**, not a Dynamic Type category. The bar lays out
four candidate states hidden at their own ideal heights and takes the tallest that fits within 40% of
the content area. Measured at default (content area 638.67pt, cross-checked against a band profile at
638.34pt — header bottom 152.33, tab bar top 790.67):

| rung | height | share | |
|---|---|---|---|
| `full` | 334.67pt | **52.40%** | the finding |
| `lead` | 226.33pt | **35.44%** | ships at default |
| `compact` | 186.00pt | 29.12% | keypad-up form |
| `unpinned` | 120.00pt | 18.79% | the floor |

At AX5 (content area 617.67pt) `full` measures **642.33pt — 104%**, `lead` 59.20%, `compact` 58.88%,
`unpinned` 22.56%, so the gate stands the bar down at AX5 by measurement and T24's outcome survives
without the size gate that produced it. Each candidate checked against the framebuffer: predicted
334.67 / 226.33 / 186.00 against band-profiled 334.34 / 226.00 / 185.67 — within 0.33pt every time.
**The cap is 0.40 and it is measured, not chosen.** The floor is 18.79% at default and 22.56% at AX5
and `D5` makes it mandatory, so the gate chooses inside `[18.79%, 52.40%]`. A one-third cap leaves
14.54 points and `lead` needs 16.65 — misses by 2.11, and what pays is the dose. The `leadPlusTotal`
cross-check measures **260.33pt = 40.76%**, over by 4.86pt: the trade was forced, not chosen. Its
branch was driven at `BAR_SHARE_CAP=0.45` rather than left unrendered.

### `B1-17` — a dose field is sheared at AX5 on `Steroid Dosage`
**CLOSED — evidence** (as a finding: found by the new reachability sweep on its first run at that
size). `field_mgWeek` spans y 636.33…701.33 with the plate top at 651.67. **The gate cannot fix it**
— at AX5 the bar is already at its floor. The fix belongs to that screen's layout, so it is filed
rather than folded in: the open half is `B1-08` and `B1-20`.

### `B1-18` — the same headline dose figure renders twice, conspicuously
**OPEN.** `IB2245750`: scrolled to the end of the TRT form, `Draw per injection · 0.250 mL` appears
in the in-scroll card AND in the pinned `lead` bar, both at full display treatment, ~500px apart. The
duplication predates T20; the `lead` rung made it worse to look at. Found by the judgment pass on
this session's own change. **Not a divergence risk** (one `CalculatorResult`) — it is a product
question: should the pinned copy suppress itself when the in-scroll card is on screen?

### `B1-19` — `Frequency` is sheared by the plate edge with the keypad up
**OPEN.** `IB2245751`. The reachability sweep asserts **at rest**, where the content area is the whole
screen; with the keypad up it is a fraction of it and the bar is in `compact`. Recorded rather than
cropped out of the evidence. Whether the invariant should extend to keypad-up is undecided —
extending it naively asserts something the keyboard makes unsatisfiable, the same trap as asserting
the straddle rule at AX5.

### `B1-20` — `Steroid Dosage` shears `field_mgWeek` at AX5
**OPEN.** The bar is at its floor and cannot move; this needs the form to stop leaving a control
across the plate edge, or the plate edge to stop being opaque to it. Carried as a **named expected
failure** in `PinnedBarReachabilityUITests.expectedShears`, so the suite still asserts the rule on
every other screen at AX5 and goes red the day this one starts passing. `§5.30`.

### `B1-21` — T25: nothing renders behind the pinned bar
**OPEN — and a HYPOTHESIS, not a finding.** Filed out of T21. Evidence: `.ultraThinMaterial` — the
most transparent material — sampled `#767676` at four different scroll positions, identical. A
material over a moving backdrop cannot return the same value four times.
The read to start with: **a material getting darker as it gets thinner is the signature of
compositing over an undefined backdrop, not over form content.** The app is light-only on `#FAFAFB`,
so nothing dark should be near it.
**Ruled out, and worth as much as the finding:** moving `.safeAreaInset` from the `GeometryReader`
onto the `ScrollView` inside it — the composition that should have let the form scroll under the bar
— gave byte-identical measurements at all four positions. It bought nothing and is not banked.

### `B1-22` — the pinned bar's plate: tone changed, request not delivered
**PARTIAL.** The human asked for *transparent with a light blur, so the bar reads as floating over
the form rather than as furniture covering it*. What shipped is `.regularMaterial` plus a 1px
hairline: it **fixes the complaint** — the flat grey slab is gone — and **does not deliver the
request**, because there is nothing for translucency to be translucent over (`B1-21`).
Measured ladder, same screen, same scroll position, one run:
`ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB (shipped) · regular #FEFEFE · thick #FFFFFF`.
`.thinMaterial` is 8 values from `.bar` — a change nobody can see, which is why it was not taken. The
result card gained a hairline in the same pass; card and plate both measure `#FEFEFE`, and two
surfaces within one value of each other are not a boundary.
**Contrast does not fail anywhere.** Worst composite across four scroll positions and five materials:
`#075E56` dose value **7.14–7.59:1**, navy eyebrow **14.60–15.65:1**, `Add` white-on-navy **15.79:1
exactly at every position** (`Theme.navy` is opaque). Not covered: the disabled CTA is
`navy.opacity(0.4)` and *would* composite; WCAG exempts disabled controls and it is not claimed here.

### `B1-23` — the pinning gate is a proxy, so the assertion is not the gate
**CLOSED — evidence.** `PinnedBarReachabilityUITests`. 40% of the content area is a fact about area,
not about whether you can see the dose you are committing. So the invariant asserted is `D5` itself,
in two passes, against the plate's **rendered** frame:
1. the committing action is wholly on screen and hittable, at every size;
2. at rest no input control straddles the plate's top edge, and at every size every input can be
   brought to **full** visibility.

**Shown to fail before being trusted** (`§5.24`): `BAR_SHARE_CAP=0.55` forces the gate to approve the
full-height bar and the sweep goes red on `control_injPerWeek` — the `Frequency` picker, the exact
control the finding names. Green at 0.40.
Coverage, stated so a green run is not over-read: numeric fields and menu pickers on three
calculators. Segmented rows, toggles and day steppers are **not** measured. The straddle half is not
asserted at accessibility sizes (the bar is at its floor there and the assertion would be
unsatisfiable); the real AX5 case it found is `B1-20`, filed rather than hidden by the scoping.
See also `B1-07`: at the time this was closed, `assertReachable` was resolving `Add` by label and
measuring the tab bar. That is fixed (`cta_add`), and it is why this entry's green is worth reading
twice.

### `B1-24` — the pinned result bar leaves one field visible at AX5
**CLOSED — evidence.** `IB2245748`. Closed first by a Dynamic Type gate (T24) and now by the measured
gate, which reaches the same outcome without guessing where the problem starts: at AX5 the `lead`
rung measures 59.20% of the content area and the cap stands it down.

### `B1-25` — Dashboard at AX5 fails the reachability test
**OPEN.** Not the greeting percentage — the greeting is the diagnosis. The bug is that the Next dose
card's `Mark taken` CTA was off the bottom of the screen at AX5, so the action for today's dose
needed a scroll on the home screen. Capping the greeting (`DESIGN-PARITY §10`) fixed **this
instance**; the rule it produces is `§5.19` and **every screen still needs checking against it**.

### `B1-26` — Tools at AX5 reads as broken
**OPEN, in part.** `IB2245731`, unchanged from `2026-08-01-current/10-tools-ax5.png`. Six things in
one frame. **This frame passed the audit, and passed correctly** — that is what `§5.15` exists for.

| # | in the frame | state |
|---|---|---|
| 1 | `Semaglu-tide` hyphenated mid-word | **reversed by owner, H3** — accepted behaviour |
| 2 | `Retatru-tide` | **reversed by owner, H3** — accepted behaviour |
| 3 | `Tirzepatide` wrapping to an orphaned `e` on line two | **open** |
| 4 | the `Tools` title clipped against the header row above it | **open** — screen-header rule, `DESIGN-PARITY §9`, probably resolves with H5 |
| 5 | icons that stayed small while the text went huge | **open** |
| 6 | four rows filling the entire screen | **open** |

Constraints on the fix: **no `dynamicTypeSize(...up to:)` cap** on calculator names (navigation
labels in a dosing app; AX5 users are exactly who needs them legible) and **no `lineLimit`**.
Direction to try first: fix the icon at a sensible size instead of letting the layout starve the
label, and let the row grow vertically since the list scrolls and vertical space is cheap.
**Tail clause — DEFERRED, owner (Pouroa), 2026-08-03, as AX5/T11:** *"then re-check the other nine
screens at AX5 with the judgment pass, not the metric pass — the expectation is that this is not the
only one."* That re-survey is T11 and is deferred. **It is a clause of this entry, not an entry of
its own** — the four open defects above are live and do not wait for it.

### `B1-27` — the in-scroll `ResultCard` renders unconditionally, so at default the same rows exist twice
**CLOSED — evidence** ("largely dissolved by the measured gate"). At default the pinned bar shows ONE
row (`lead`), so the duplication is a single figure rather than a whole card; at AX5 there is no
pinned copy at all.
The addressing rule changed with it: `result_<label>` now follows the ROW to whichever surface is
displaying it, because the old rule ("`result_` names the pinned bar") assumed a bar whose contents
never varied. Two wiring assertions went red on `result_Weekly total` resolving to zero elements —
red about something true.
Historical: `result_Weekly total` measured as two elements, y=641 (pinned, hittable) and y=896
(in-scroll, not). `CalculatorScreen.swift`'s F12 comment says the breakdown renders in the scroll
*instead* when the bar collapses; the code does not do that, and the code is what shipped.
**Not a divergence risk** — both cards get the same `CalculatorResult`. What is left is the product
question in `B1-18`.

### `B1-28` — Welcome + onboarding, piece 2: restyle `AuthFlowView`
**PARTIAL — CODE DONE, VISUALLY UNVERIFIED.** Builds, tests green. **Not ticked until measured**,
same bar as everything else. Not screenshotted: the simulator holds a signed-in session and
`AuthFlowView` only renders when signed out; signing out would cost every authenticated screen for
the rest of the work. Needs the account password from the human, or a throwaway account.
`grep -c "Theme.Typeface"` returned **0** — the second screen found in that state after the log
sheet, and the first screen a new user ever sees. Type scale + palette + the 44pt field family.
Secondary labels off `#0FBCAD` (2.13–2.38:1) onto `#075E56`. **Behaviour unchanged** — validation,
cooldown, Discord OAuth and verify all work.
Spec: `docs/WELCOME-AND-ONBOARDING.md`. Three pieces, not one — the auth flow already exists and is
not being rebuilt.

### `B1-29` — Welcome + onboarding, piece 1: animated welcome screen
**PARTIAL — BUILT, launch frame verified.** Occupies `.loading`, fronts `.signedOut` with the two
CTAs. Drifting serum-concentration curves in a single `Canvas` inside `TimelineView(.animation)`; the
mark draws via `Path.trim`; staggered fade+rise 60ms apart, 450ms, ease-out; solid fills only.
Measured: wordmark **7.34:1**, and the band behind the copy samples pure `#FAFAFB` on both sides —
**the curves do not cross the text block**, the rule that outranks the aesthetics.
Still to verify: the signed-out CTA path, and the mid-transition text measurement.
*Superseded original brief, carried as history (it is a `<details>` block on the board, not a
separate finding):* animation duration is a ceiling, never a floor — a returning signed-in user must
never wait on it; solid fills only, no multi-stop gradient on text; Reduce Motion → final state
immediately; text measured **mid-transition**, not only at rest.

### `B1-30` — Welcome + onboarding, piece 3: five-step onboarding AND the Settings surface that edits the same data
**OPEN. One feature, not two.** `DashSettings`' Personalisation tab collects exactly what onboarding
collects: nickname, units, measurements, timezone, interests. **Ship onboarding alone and a user sets
those once at signup and can never change them** — wrong unit, wrong timezone, no way back. That is a
one-way door and it would be ours.
So: onboarding writes the profile, Settings edits it, same fields, same validation, same NOT NULL
discipline, field components built once and used in both. Mirrors the PWA's `STEP_META`. Three NOT
NULL columns plus a NOT NULL array — **a skipped step writes the DEFAULT, never a null**.
`onboarding_completed_at` set only on completion. Store metric, don't round on the way in (180 lb
must return 180 lb). Step 3 collects value+unit pairs, the exact shape that truncated before, so it
reflows at AX5.

### `B1-31` — calculator quick buttons
**CLOSED — evidence.** Tapping 400 sets the field to 400 and the result to 400.0 mg/week; the barrel
row renders four buttons with the selection navy-filled. `2026-08-01-quickbuttons/`.
**Caught a real bug doing it:** the quick button wrote the binding but `NumberField`'s local text
state did not follow, so the field displayed **100 while the calculator computed 300**. A dosing
field showing a different number from the one being used is not a styling defect. Fixed by syncing
text on external value changes, skipped while focused so it cannot fight live typing.
*Superseded original, carried as history (a `<details>` block, not a separate finding):* code done,
builds, tests green; barrel is a 4-button segmented row instead of a menu; dose fields carry one-tap
values (TRT weekly 100/200/300/400/500, and per-calculator sets for EOD, microdose, HCG, peptide,
BPC-157, steroid); TRT and steroid weekly-dose steppers step in **10s**. Vial strength deliberately
has no quick values — set once per vial, not per dose. Not screenshotted at the time: the Mac's GUI
session had dropped.

### `B1-32` — type scale missing on TEN screens, not two
**OPEN. Do NOT start it.** `AddScreen`, `ConfirmStartScreen`, `CyclePlotterScreen`, `CalendarScreen`,
`DisclaimerGate`, `SettingsScreen`, `DrawerView`, `ToolsScreen`, `MainShell`, `RouteContent`.
Only Dashboard, `CalculatorScreen`, `LogDoseSheet` and `AuthFlowView` have it — and two of those four
only because they were fixed that day. So the log sheet was never an outlier; it was the first one
anyone looked at. This is `§5.7` with a number attached, and the number is **10**.
Two worth calling out: **`DisclaimerGate` is the first screen any new user sees**, before welcome and
before auth, and it is stock system type. And `CyclePlotterScreen` is Swift Charts, whose axis marks,
legends and annotations carry their own default typography that will NOT follow `Theme` — they need
explicit styling or the chart stays system-default while the screen around it changes.
**One item, not ten.** It is a sweep, and sweeps done in a hurry are where regressions come from.
Scope it with the human after onboarding.

### `B1-33` — measure Settings and the confirm-start-day screen
**OPEN.** The only two screens the control inventory did not reach (a drawer mis-tap landed on BMI).
Both are stock `Form`/`List` and are *probably* the same 44pt list-row treatment as the log sheet,
**but that is a guess and guesses do not get ticked.**

### `B1-34` — T19: the renderer publishes whether it truncated
**CLOSED — evidence**, and it found that the result rows were never covered at all.
`truncationProbe` lays each value view out twice — once as it renders, once free of any width
constraint — and publishes whether the second is wider. Layout answering a question about layout,
rather than the accessibility layer answering a question it cannot see (`§5.23`). DEBUG only.
**Shown red before being trusted:** reproduced with `FORCE_INLINE_FIELD=1` at AX5, 13 probes fire.
Green at default — 93 probes clean across 11 calculators.
**It does NOT supersede T4b's ratio.** On the same reproduced defect: ratio 9 failures, renderer 13.
Caught by the renderer and **not** by the ratio:

| | rendered | ideal |
|---|---|---|
| `BPC+TB500 · field_bpcVial` | 131.67pt | 138.67pt |
| `BPC+TB500 · field_tbDose` | 131.67pt | 137.67pt |
| `BPC+TB500 · field_tbVial` | 131.67pt | 138.67pt |
| `BPC+TB500 · result_BPC-157 draw` | 247.33pt | 347.67pt |
| `BPC+TB500 · result_TB-500 draw` | 247.33pt | 347.67pt |
| `Peptide · result_Volume` | 319.00pt | 525.00pt |

The three fields are the documented blind spot — a long value beside a short unit keeps the ratio and
passes green. **The three `result_` rows are worse: the ratio compares `field_<key>` against
`unit_<key>`, so it never looked at the result card at all** — the surface F1 was found on, with no
truncation check since. And one case the ratio catches that the renderer does not:
`Free T Index · shbg`, value cell 79.0pt against a 147.0pt unit, where the string still fits — a
squeezed layout without truncation. **Both checks stay**; neither is a superset of the other.
Coverage: numeric fields and result rows. The probe on a `TextField` compares a `Text` of the same
string against the field's whole frame, so it is CONSERVATIVE — UIKit's internal inset means a value
clipped by only that inset can still pass.

---

## 2. From BOARD §2 — open, unassigned, needs a human decision

### `B2-01` — whole sections of the PWA have no iOS screen at all
**OPEN.** The PWA dashboard is six tabs; iOS covers three.

| PWA | iOS |
|---|---|
| `upcoming` | Dashboard — have |
| `history` (`DoseHistory`) | **missing entirely** — no route, no screen |
| `inventory` (`SupplyAlert`/`MySupply`) | **missing entirely**, and `vial_inventory` is a live table with rows |
| `saved` (`ProtocolList`) | folded into the dashboard grid |
| `calculators` (`CalcGrid`) | Tools tab |
| `settings` (`DashSettings`) | partial |

`DashSettings` has six sub-tabs — Account, Profile, Personalisation, Badges, Metrics, Billing & Plan.
iOS Settings has Preferences, Discord, Account and display name, so **four of six don't exist**.

### `B2-02` — tapping a protocol card goes nowhere
**OPEN.** The cards render a chevron, which promises navigation, and there is no protocol detail route
— `SCREENS.md` specced an edit sheet and even that isn't wired. Worth fixing regardless of the bigger
IA question: a chevron that promises and doesn't deliver is a defect on its own.

### `B2-03` — dashboard information architecture
**OPEN.** The PWA dashboard is tabbed (`upcoming` / `history` / `inventory` / `saved` /
`calculators` / `settings`); iOS is one scroll with next-dose plus all protocols. The iOS protocol
grid corresponds to the PWA's `saved` tab. Adopt the tabbed IA, or keep the single scroll and match
only the visual language? Out of scope for styling parity either way.

### `B2-04` — three calculators exist on the web with no iOS screen at all
**OPEN.** `bioavailability`, `femalehrt`, `oilblend`. Feature gap, not a config bug.

### `B2-05` — greeting shimmer
**OPEN.** Solid `#075E56` ships. SwiftUI desaturates *any* multi-stop gradient — measured — and both
fix routes failed. Filed approach if it's wanted back: solid text with a **single-colour** translucent
band swept as a mask, since single-colour gradients measure exact. Not started.
**Mac's read: feasible, with one constraint that decides it.** A translucent *white* band would
lighten the ink where it passes and drop contrast below threshold mid-sweep — the same failure mode as
`#5FE8DA` from a different direction. The band must be `#0A9D90`, so the worst composite is 3.37:1 and
still legal for the 24pt heavy greeting. Measurable before building. Worth one cycle **only if the
human actually wants the shimmer** — the screen reads correct without it and every prior attempt cost
a cycle.

### `B2-06` — Inter vs SF
**OPEN.** Deferred, not rejected. SF was chosen because bundled Inter costs the Dynamic Type metrics
that protect against the truncation class of bug. Revisit only with that trade understood.

### `B2-07` — tab bar glyphs are accessible grey (~6:1) rather than brand-coloured
**OPEN. Mac's read: leave it, it reads as deliberate.** iOS convention is a neutral unselected item;
the brand is already present via the selected item (`#075E56` + bold). Colouring the unselected ones
would weaken a selected/unselected distinction that was only just fixed from 2.77:1.

### `B2-08` — log-sheet rows
**CLOSED — evidence.** They now carry the calculator's bordered language.
*(Board sub-heading: "From the control inventory (`2026-08-01-controls/`) — scope before building".
The calculator family is universal: numeric ± fields and every menu picker, including the barrel
picker, are **44.0pt** at default and **77.35pt** at AX5. Four things sit outside it.)*

### `B2-09` — log sheet type scale, contrast and rows
**CLOSED — evidence**, all done in one pass. Eyebrow `#85858B` grey → **navy `#001D5C`** semibold
(measured). `Cancel` **2.13:1 → 6.86:1** (`#0FBCAD` → `#075E56`), the worst number left in the app.
Rows now compound-first with no `lineLimit`, using a shared `ProtocolLabel.split` so the dashboard and
the sheet cannot drift — the latent form of the truncation bug that hit seven dashboard cards is gone
before it triggered. `2026-08-01-logsheet/`.

---

## 3. From BOARD §3 — closed, with the evidence that closed it

**These are closed by measurement or screenshot, never by inspection.** They are transcribed so the
list stands alone; they are not work.

### Safety and accessibility

### `B3-01` — SAFETY / DATA: `Add` no longer writes a protocol row from a calculator that computes no dose
**CLOSED — evidence.** Alias **G1**, commit `72eb16c`. `CalculatorScreen`'s CTA is gated on
`slug.canSaveProtocol && vm.result.isValid && network.isOnline`. One condition added; the flag and
`AddScreen`'s use of it were already there.
**Closed by a measurement, and the measurement was watched failing first.**
`CalculatorWiringUITests.testAddCTA_isGatedOnCanSaveProtocol`, run against the tree *before* the gate,
reported both offenders by name and by frame: `BMI: Add is ENABLED … (frame (16.0, 687.0, 370.0,
72.0))` and `Free T Index: Add is ENABLED … (frame (16.0, 687.0, 370.0, 72.0))`. With the gate:
`Executed 5 tests, with 0 failures`.
**Aimed at** (`§5.33`): the two non-saving calculators that are `CalculatorScreen`s and reachable from
Tools, plus `TRT Dose` as the other end. It does NOT cover `Cycle Plotter` — the third
`canSaveProtocol == false` slug — which routes to `CyclePlotterScreen`, renders no `cta_add`, and was
absent from Tools anyway (`B1-06`). Excluded with the reason stated, not silently.
**Both ends** (`§5.30`): the `TRT Dose` leg asserts the CTA is still ENABLED and passed in the same run
as the two reds. `save(backend:)` has exactly one caller — this button's closure.
**NOT closed by this: the row-display half.** See `B1-05`.
*(The BMI and Free T Index names here are closing evidence, not live work on those screens. H6
withdraws both from every route in; the gate is still required and is not redundant, because
`canSaveProtocol` is false for three slugs and `Cycle Plotter` stays reachable.)*

### `B3-02` — a primary CTA reported itself not hittable: cause found, and it was the measurement probe
**CLOSED — evidence.** Resolves **F-K**, as branch (a). The `bar_plate` element existed so D5 could
read the plate's rendered top edge. It was attached as **`.overlay`**, so a `Color.clear` carrying
`.accessibilityElement()` sat ON TOP of the whole result bar — including the `Add` button inside it.
The accessibility layer therefore reported the primary CTA of **every calculator** as
`hittable=false`, and `AXScrollToVisible` failed with `kAXErrorCannotComplete`. Changed to
**`.background`**.
**The controlled comparison, one variable, both directions:**

| probe | `bar_plate` frame | `Add` hittable |
|---|---|---|
| `.overlay` | `(0.0, 564.6666666666666, 402.0, 226.33333333333337)` | **no** — 3 of 3 red |
| `.background` | `(0.0, 564.6666666666666, 402.0, 226.33333333333337)` | **yes** — 3 of 3 green |

The frame the probe exists to publish is byte-identical, so no straddle verdict moves.
`PLATE <screen>: top=… frame=…` is now printed before anything is asserted — `continueAfterFailure` is
false, so the trailing `REACH` line never printed on a failing run and the one number every straddle
verdict is measured against was invisible in exactly the runs that needed it.
It was neither a lie nor an occlusion: it was **true**, and we put the thing there.
**Aimed at** (`§5.33`): `TRT Dose`, `Reconstitution`, `Steroid Dosage` at default — the three screens
D5 opens. The other eleven are not measured by anything yet; `bar_plate` is rendered by the one shared
`resultBar` so the same fix reaches them, but that is an inference, not a measurement. **G2 is what
tests it.** Regression run at default: `Executed 11 tests, with 0 failures` across
`CalculatorWiringUITests`, `PinnedBarReachabilityUITests` and `LeafOverlapUITests`.

### `B3-03` — AX5 unit truncation
**CLOSED — evidence.** `Draw… 0.25…` → `Draw per injection / 0.250 mL`. Primary rows stack
label-above-value; no value+unit pair carries a `lineLimit`. `cycle1/04`.

### `B3-04` — hero blanking the primary CTA while the keypad is up
**CLOSED — evidence.** `cycle2/03`.

### `B3-05` — result card clipping the field being edited
**CLOSED — evidence.** `cycle2/03`.

### `B3-06` — result bar ate ~64% at AX5
**CLOSED — evidence.** → 32.6%, collapses to primary + CTA.

### `B3-07` — input borders 1.3:1
**CLOSED — evidence.** → `#8E8E93` at 3.26:1. Mac reopened this against its own prematurely-closed
finding.

### `B3-08` — every failing contrast surface
**CLOSED — evidence.** Dose readout and CTAs 2.38 → 15.79:1; hero glyph 2.38 → 6.43:1 (the last one,
on the most prominent control); empty-state action and error-banner Retry, both found unprompted;
danger `#FF5757` 3.11 → `#A31313` 7.90:1.

### `B3-09` — over-capacity barrel warning
**CLOSED — evidence.** Uses icon **and** text, never colour alone.

### `B3-10` — F1 again, through layout instead of `lineLimit`: a dose truncated to `1…` at AX5
**CLOSED — evidence.** `NumberField` laid out `[ value ][ unit ][ − ][ + ]` on one line. The unit
carries `.fixedSize()` (correct — a unit must never truncate) and the steppers are 44pt each, so at
AX5 the unit took the row and **the value** was squeezed. `1…` on a weekly dose could be 100, 150 or
1000 mg/week. Compounding it, the field's font was a frozen `.system(size: 17)` at the call site,
which the `Theme` re-baseline could not reach — so the dose number stayed 17pt while `mg/mL` grew past
it and the value became the smallest text on the screen. Fixed by reflowing above AX1 (value on its
own full-width line, unit and steppers beneath) and moving the field to a scaling token. Evidence:
`IB2245748`, the first capture of this screen at AX5 ever taken.
**The lesson is about the old fix:** F1 banned `lineLimit` on a value+unit pair and that ban was
necessary and not sufficient. Layout reached the same place without it.

### `B3-11` — the field displayed a number the engine did not use (second breach of that invariant)
**CLOSED — evidence.** `mgWeek` is `0...1000`; focusing a populated field did not select it, so typing
250 onto 100 gave `100250`, and `clamp` then handed the engine 1000 in silence. The screen showed
`100250 mg/week` beside a `2.500 mL` draw computed from 1000, with a correct over-capacity warning for
a number the user could not see. Evidence `IB2245733` / `IB2245734`.
Fixed on BOTH edges of `NumberField` — clamping rewrites the text, and focusing selects — because one
breach on one path is a patch and two is an invariant. **App-wide**: `NumberField` is the only numeric
input and `FieldRow` its only call site. Pinned by
`testOverRange_fieldNeverShowsANumberTheEngineRejected`, which asserts the agreement, not the string.

### `B3-12` — quick-value row unreachable with the keypad up
**CLOSED — evidence.** The occluder is the **pinned result bar**, not the keyboard — it sits above the
keyboard and covers the strip the chips are in. `quick_mgWeek_400.tap()` reported success and moved
nothing. The focused field's quick values now ride in a keyboard toolbar with a Done button, which
also supplies the only exit from a `.decimalPad`. Evidence: `IB2245734` before, `IB2245732` after.

### Data integrity

### `B3-13` — iOS protocol saving never worked
**CLOSED — evidence.** Every insert refused by RLS because `user_id` was omitted. The read path omits
it deliberately (RLS scopes SELECTs) and that assumption was carried into the write path, where the
`WITH CHECK` made it fatal. Sourced from the session inside the data layer.

### `B3-14` — no dedup on protocol saves
**CLOSED — evidence.** iOS bypasses `/api/dosages` entirely (direct PostgREST). Fixed at the database:
`UNIQUE (user_id, calculator_type, config)` on jsonb. Verified by count — 99 rows, two identical
saves, 100 rows, 0 duplicate groups.

### `B3-15` — `.upsert` rejected
**CLOSED — evidence.** In favour of insert-then-recover-on-23505. PostgREST resolves upsert to
`ON CONFLICT DO UPDATE`, which would overwrite `start_date` with today and shift every calendar
occurrence.

### `B3-16` — config shapes vs ground truth
**CLOSED — evidence.** 9 web-backed slugs verified against the real rows. Three bugs fixed: the GLP-1
family was grouped in one `configExtras` case but the web writes semaglutide differently from
tirzepatide/retatrutide; `hcg` had inherited the injectable mode pair.

### `B3-17` — five stale `/api/dosages` comments
**CLOSED — evidence.** Corrected — they described a write path iOS has never used.

### Parity and chrome

### `B3-18` — input control inventory
**CLOSED — evidence.** Every distinct control measured at default and AX5. Verdict: not universal —
the calculator family is, four things outside it are not (`B2-08`, `B2-09` and the board's §2
sub-list). Killed the suspicion that pickers differ from ± fields — both are exactly 44.0 / 77.35pt,
because cycle 2 floored pickers with the same `Theme.minTarget`. Confirmed the log sheet as the
off-family screen. `2026-08-01-controls/`.

### `B3-19` — palette + type scale into `Theme.swift`
**CLOSED — evidence.** It had neither.

### `B3-20` — dark mode removed
**CLOSED — evidence.** `UIUserInterfaceStyle` via `project.yml` (not the generated plist), verified
surviving `xcodegen generate`. Docs swept, including the `SCREENS.md:15` toggle that specified it.

### `B3-21` — protocol cards no longer truncate the compound name
**CLOSED — evidence.** Seven were; two were indistinguishable.

### `B3-22` — navy header squares, centred teal wordmark, density, per-compound spine
**CLOSED — evidence.**

### `B3-23` — colour roles settled
**CLOSED — evidence.** Navy = actions, teal keeps the FAB. Taken from the PWA's real usage, not a
hierarchy principle. `DESIGN-PARITY.md §8`.

### `B3-24` — centre tab slot drew its own syringe glyph
**CLOSED — evidence.** Under the hero circle — removed the glyph rather than covering it. `cycle8/02`.

### `B3-25` — hero overlap
**CLOSED — evidence.** All eight screens scrolled to content end, plus the AX5 collision check.
`cycle9`.

### `B3-26` — calculator's pinned CTA
**CLOSED — evidence.** −12.7pt → +3.3pt. `heroOverhang` was *not* the fix and 22→38 moved it zero
pixels: an outer `safeAreaInset` reaches scrolled content but cannot lift a sibling inset pinned
further in.

---

## 4. From BOARD §4 — known and NOT KNOWABLE

**These are not ticks and must never become ticks by transcription.** Per `CLAUDE.md`: unverifiable
goes here, not to a closed item. Nothing below has been promoted.

### `B4-01` — which screens already reserved room for the hero before the fix
**NOT KNOWABLE.** Overlap was only ever demonstrated on the dashboard and calculator; the other six
were never shown either way. Reconstructing it means rebuilding the old binary to answer a question
that changes nothing.

### `B4-02` — `eod`, `reconstitution`, `bpc157blend` config shapes
**NOT KNOWABLE.** No web rows exist, so there is no ground truth to compare against. Internally
consistent; that is all anyone can say — and `§5.1` says internally consistent is not evidence.

### `B4-03` — no PWA capture for the calculator or log-dose screens
**NOT KNOWABLE.** Parity on those two is structural-only. **Do not invent a target.**

### `B4-04` — the log-dose date chip is 34.0pt tall at default size
**NOT KNOWABLE — ACCEPTED, not missed.** Accepted is not closed and this entry stays in §4.
Hit area measured behaviourally, not inferred: tapping 4pt above the chip's drawn top did nothing,
4pt below did nothing, and the chip's centre opened the picker. So the effective target equals the
drawn size — UIKit is *not* padding it, and the "may be moot" hypothesis is dead.
Accepted anyway, for four reasons taken together: it is Apple's own compact `DatePicker`, shipped in
Settings, Calendar and Reminders; it already measures **52.7pt at AX5**, so the shortfall exists only
at default size and never for the larger-text users who most need a big target; it is short but
~120pt **wide**, so it fails in one dimension only, unlike the toggle which was small in both; and
`DESIGN-PARITY §6` keeps native controls native — the same trade already made for `UISwitch`.
The row around it *is* now 44pt with the calculator's field treatment, so the visual complaint that
started this is fixed. Revisit only if a custom row presenting a graphical picker becomes worth the
platform cost.

### `B4-05` — PII in the drawer and Settings captures
**NOT KNOWABLE.** They contain a real email and avatar. Repo is private. **Blocker on ever making it
public.**

---

## 5. From the directing side — not from the BOARD inventory

**Recorded outside the 74 deliberately.** These entries did not come out of `BOARD.md §1–§4`; they
arrived from the directing side. They are listed here so the two-way count in `§0` stays exact and
nobody reads them as an unexplained delta.

`X-01` arrived during the D2 transcription. **`X-02`…`X-09` arrived on 2026-08-03**, after it, and
four of them are **P0 data-integrity defects on the app's primary write path** — they are the most
urgent work in this file and they are here rather than in `§1` only because the board has not seen
them yet. **A human reconciles them onto `BOARD.md`;** until then this section is where they live and
`§1`'s numbering is untouched.

**Verification note.** `X-03`, `X-04` and `X-09` were checked against the **live database**, not
against the source — column nullability, defaults, triggers, RLS policies, index definitions and row
distributions were queried directly. That is `RULES.md` §5.1, and in `X-09`'s case it withdrew a P0
that reading the code had appeared to confirm.

### `X-01` — a stored `saved_dosages` row still routes into a withdrawn calculator screen
**OPEN — NOT closed. Owner: mac. Unstarted. DO NOT SCHEDULE WORK ON IT.**
The saved-protocol grid at `Sources/InjectBuddy/Features/Dashboard/DashboardScreen.swift:96` pushes
`.calculator(slug)` for whatever slug a stored `saved_dosages` row carries, so a stored `bmi` or
`freetest` row still opens a withdrawn calculator screen.
Two facts, and they are what make it safe **today**:
1. **Production row counts for `bmi` / `freetest` / `plotter` are 0** (night handover — the driven
   test row `2d9d1bc2…` was deleted and the counts went back to 0).
2. **`isListed` is a browse-surface guard BY DESIGN.** Reference `bf52ecc`: it filters
   `CalculatorCategory.members`, `savableMembers`, the dashboard add dialog and `NavItems.calculators`.
   A route driven by a stored row was never in its scope, so **this is not a bug in the H6 work.**

**Why it is explicitly NOT closed:** *"zero rows today" is a fact about the DATA, not about the code,
and the row that changes it is one insert away.*
**Why no work is scheduled:** the owner's standing decision is that both withdrawn screens stay behind
the flag with **no layout or styling work on either**, and a stored-row route with zero rows is
exactly the shape that decision already covers.

---

### `X-02` — LAUNCH BLOCKER: the app offers account creation and has no working account deletion
**OPEN. P0. Owner: HUMAN.** Files against **`§6` TASK 12** (submission content / App Review
readiness), which is where the other review-gating work already lives.

`Features/Settings/SettingsScreen.swift:49` tells the user, in a destructive confirmation dialog:
*"This permanently removes your account and saved protocols. This can't be undone."*
The implementation at `:183-189` is:

```swift
private func deleteAccount() async {
    // TODO: call a backend account-deletion endpoint once it exists
    // (BackendClient has no delete-account method yet — SCREENS §4). For now we
    // sign the user out so the session is cleared client-side.
    await auth.signOut()
}
```

It signs the user out. The account and every saved protocol remain. The TODO at `:184-186` states
this plainly, so it was never concealed — it was filed as a stub and the stub shipped behind a
dialog that promises the opposite.

**Why this is a launch blocker and not a defect.** Apple requires an in-app account-deletion path
for any app that offers account creation. This app does (`AuthFlowView` signup, `B1-28`). It is a
**rejection at review**, not a nice-to-have, and no amount of screenshot evidence elsewhere moves it.

**The item is the MISSING CAPABILITY, not the wording.** The misleading copy is being corrected
today by a separate agent. **Do not read that correction as closing this.** Honest copy on a button
that does not delete the account is still an app that cannot pass review — it removes the lie and
leaves the blocker. Closing this needs a real deletion path: a backend endpoint that deletes the
auth user and the owned rows, and `BackendClient` gaining the method it currently lacks.

**Owner is the human** because it needs a Supabase-side decision (edge function vs admin endpoint)
and a data-retention answer, neither of which is the building side's to make.

---

### `X-03` — P0 / DATA: `dose_log` writes omit `user_id`, so no iOS-written dose has ever landed
**OPEN. P0. Fix in flight.** Measured against production, not inferred.

`NewDoseLogPin` (`Core/Models/Models.swift:164-176`) carries exactly four fields — `protocol_id`,
`dosed_on`, `draw_ml`, `site`. There is no `user_id`. Queried live:

| fact | value |
|---|---|
| `dose_log.user_id` | `uuid`, **NOT NULL**, **no default** |
| triggers on `dose_log` | **0** |
| RLS | `dose_log_owner_all`, ALL, `WITH CHECK auth.uid() = user_id` |

So the column cannot be filled by a default, cannot be filled by a trigger, and the policy rejects
the row without it. **The write cannot succeed and never has.**

**The confirming measurement, and it is the one that settles it:** all **14** live `dose_log` rows
carry `scheduled_on`, `protocol_label` and a non-null `draw_ml`. iOS writes **none** of those three.
Every row in that table came from the web. **No iOS-written row has ever landed on any build.**

This is `B3-13` arriving a second time on a different table — the read path omits `user_id` because
RLS scopes SELECTs, and the assumption was carried into the write path where the `WITH CHECK` makes
it fatal. `saveDosage` was fixed for exactly this (`SupabaseBackendClient.swift:132-140` carries the
comment); `logDose` was not. **One breach is a patch, two is an invariant** — the same words `B3-11`
used. Whatever fixes this should make it structurally impossible to write this table without an
owner, not add a third careful call site.

Also tracked as `docs/TEST-QUEUE.md` Q1 (`f5e915a`). Same finding, that is the runner's queue entry.

---

### `X-04` — P0 / DATA: iOS-saved protocols land `draft` and inactive, and nothing in the app can activate them
**OPEN. P0. Fix in flight.** Measured against production.

`NewSavedDosage` (`Core/Models/Models.swift:77-89`) sends `calculator_type`, `label`, `config`,
`start_date` — **neither `status` nor `is_active`**. Production defaults are `status = 'draft'`,
`is_active = false`. Trigger `trg_sync_saved_dosage_status` exists on the table (confirmed live), but
its INSERT branch leaves both alone when neither is supplied, so it does not rescue the row.
`updateStartDate` (`SupabaseBackendClient.swift:103-112`) writes `start_date` **alone**, so the
trigger's UPDATE branch is a no-op too — the confirm-start-day screen cannot activate it either.

**Every consumer filters on `isActive`**, so the row is invisible everywhere at once:

| site | code |
|---|---|
| `Core/Calendar/DoseProjection.swift:143` | `for proto in protocols where proto.isActive` |
| `Features/Dashboard/DashboardViewModel.swift:74` | `dosages.filter { $0.isActive }` |
| `Features/Calendar/CalendarViewModel.swift:49` | `dosages.filter { $0.isActive }` |
| `Features/Log/LogDoseSheet.swift:183` | `rows.filter(\.isActive)` |

A saved protocol therefore never appears, never generates a projected dose, and never becomes
loggable. It is the write half of `B1-05`, whose display half is the mirror image: `B1-05` is about
draft rows being **shown as running protocols**, this is about iOS-created rows being **shown
nowhere**. Both are true and they are different findings — do not fold them.

**Live distribution, queried today. Record these; they are the reason this is not a free fix:**

| | rows | with a `start_date` |
|---|---|---|
| `draft` / inactive | **71** | 4 |
| active | **31** | 17 |
| **total** | **102** | |

(102 matches `B1-05`'s "71 of 102 production rows are `draft`" exactly, from an independent query.)

**The 71 rows are live user data and a LEGITIMATE state. They must NOT be repaired without the
owner's decision.** `draft` is a real status the web uses deliberately; a bulk activate would put 71
protocols onto 39 users' calendars and start generating dose reminders for schedules those people
never confirmed. In a dosing app that is worse than the bug. **Fixing the write path forward is not
the same decision as backfilling history, and only the second one needs the owner.**

**Fix direction (in flight):** send `status`, defaulting to `'active'`, accepting `draft` and
`archived`. **Do NOT write the `is_active` mirror** — the trigger owns it, and writing both is how
the two columns get to disagree.

---

### `X-05` — P0 / SAFETY: `unlogDose` succeeds where `logDose` fails, so iOS can delete a dose it cannot re-create
**OPEN. P0. Fix in flight. Carries a LIVE RIG HAZARD — read the last paragraph before touching the
QA account.**

`SupabaseBackendClient.swift:200-207` deletes on `(protocol_id, dosed_on)` with **no payload**. RLS
evaluates `USING` on a DELETE and there is no `WITH CHECK` to fail, so the delete passes — while the
matching INSERT is refused for the missing `user_id` (`X-03`).

**The sentence for the board: the two halves of one toggle have opposite outcomes.** That is also
the explanation for why this survived five separate reads of this file. Both halves look correct,
both are internally consistent, and the asymmetry is not in either function — it is in the
difference between how RLS treats an INSERT and a DELETE. Nothing in the Swift shows it. `RULES.md`
§5.1 with a new mechanism: internally consistent code, wrong against the running system, and this
time the inconsistency is *between* two functions rather than inside one.

The user-visible consequence is the dangerous part. Untick a dose that the **web** logged: the
delete succeeds, the pin is gone permanently, and re-ticking it fails silently (`X-06` is why it
fails silently). **iOS can permanently destroy dose-history data it has no ability to restore** —
in an app whose dose history is the record of what someone actually injected.

**A confirmation dialog was explicitly ruled out.** It is not the fix; a dialog would make a
destructive one-way action feel authorised. The fix is `user_id` in the delete predicate (in flight).

> **RIG HAZARD — active until the fix lands. NARROWED 2026-08-03 by measurement.**
>
> **On the QA account, do not tap a dose row on the Calendar tab.** That is the destructive path and
> it is the only one. There are 14 live `dose_log` rows and no iOS code path can rebuild one.
>
> **The dashboard "Mark taken" card is SAFE and is not restricted.** Measured, with the reason,
> because a hazard stated wider than it is gets ignored wholesale — and the dashboard log path is
> the one a verification run actually needs:
> - `NextDoseCard` (`DashboardComponents.swift`) renders `Mark taken` **only** in the
>   `!model.alreadyTaken` branch; a dose already taken renders static `Logged for <day>` text with
>   no button, so there is no control to untake it.
> - `DashboardViewModel.markTaken` is **insert-only** — it calls `backend.logDose` and nothing else.
>   It has no untake path and cannot reach `unlogDose`.
> - `unlogDose` has exactly one caller in the app: `CalendarViewModel.toggleTaken`
>   (`CalendarViewModel.swift:104`), in its `wasTaken` branch.
>
> So: log doses from the dashboard freely, and read them back. **Never toggle on Calendar.**

---

### `X-06` — the app cannot tell a user when a write did not happen
**OPEN. Defect CLASS, and larger than any single P0 above. Fix in flight.** Six sites in the family.

`LogDoseSheet` is the **correct house pattern** — it awaits the write, and only then moves the
published state. **Two of the three log call sites diverge from it**: they flip an `@Published`
optimistically *before* the await and roll back on failure with **no error surface**, so the UI
shows the write succeeding, then quietly shows it not having happened, and at no point says why.

`CalendarScreen.swift:23` has `.task` and **no `.refreshable`** — so once it has failed there is no
gesture that retries. `DashboardScreen.swift:22-23` has both and is the model.

**Two measured specifics from the worst site, both worse than a silent rollback.** Both are read off
`DashboardViewModel.markTaken` and `NextDoseCard` **as they stand at `9df44ca`** — see the
freshness note below before acting on either:

1. **The rollback is CONDITIONAL, so the failure can be permanent.** `markTaken` flips
   `nextDose.alreadyTaken = true` optimistically *before* the await, then rolls it back inside
   `if var data = loaded, data.nextDose?.occurrence == occurrence`. **If the dashboard reloaded
   between the tap and the failure, that guard does not match and the rollback is skipped
   entirely.** The tick stays on screen with nothing written and no error shown — the `catch` block
   sets no error state at all. That is not a half-second flicker; it is a **persistent false
   "taken"** on a dose the user has not taken, which in a dosing app is the wrong direction for the
   error to point. It also survives until the next successful reload, so the user's own refresh is
   what silently undoes it.
2. **The same site gives no feedback across the await.** `NextDoseCard` builds its
   `PrimaryButton` with a title and an action and **no loading state**, so the control looks
   byte-identical from tap to completion. A control that looks unchanged for half a second reads as
   not having registered the press, and gets pressed again — on a *dose* button that is not a
   cosmetic complaint, and it is the second write that `X-05` makes destructive. (This is the
   400ms-visible-feedback decision, `DECISIONS-2026-08-02.md:76`; cited in prose rather than by
   number because that series may not survive the rules rewrite.)

> **Freshness — read before acting.** Both specifics above are true of **`9df44ca`**, the last
> commit. They are **already addressed in the uncommitted working tree** by the agent that owns
> `Sources/` — `markTaken` now awaits the write *before* committing state and sets `actionError` on
> failure, and the button now takes `isLoading: isMarking`. Recorded at the sha rather than as live
> defects so that a session reading a later tree finds the evidence and the fix, not a finding that
> looks false. **Do not re-file them from this entry without re-reading the two files.**

**The framing matters more than the list, and it is the reason this is its own item: fixing the
writes does not fix this.** `X-03`, `X-04` and `X-05` are three specific writes that fail. This is
the property that made all three *invisible* for the entire life of the feature — and it will make
the next failed write invisible too, on a build where those three are green. A silent rollback is a
green indistinguishable from an absence (`RULES.md` §5.24) rendered in UI instead of in a test.
**Both specifics above being fixed in one file is exactly why this stays open as a class:** the
house pattern has to reach all six sites, not the one that got measured.

Close it against the house pattern, not against the three bugs: every write path awaits, surfaces a
real error, and every screen that can fail a load can retry it.

---

### `X-07` — CI has never run the unit suite
**OPEN. Filed as an INSTANCE of `RULES.md` §5.24, NOT as a new rule.** Repoint fix in flight.

10 of the 10 most recent CI runs failed in **15–22 seconds**, on `working-directory: app` — a
directory that does not exist in this repo (the layout moved; `.github/workflows/ci.yml` did not).
Repo secrets are empty. A 15-second failure is a job that never reached a compiler.

**So the 27 green unit tests have never run anywhere but a developer's machine** — and `X-03` sat
next to them, in the same repository, for the entire life of the log-dose feature. **That is the
argument for CI existing at all**, stated as a measurement rather than as a principle, and it is the
most useful thing in this entry.

**One rule number per shape, not per incident** — the standing instruction from the directing side.
This is §5.24 again (a signal nobody can read, reporting nothing while appearing to be a check) with
CI as the layer instead of an assertion. It gets no new number and it should not be written up as a
new rule; cite §5.24.

**The secrets are deliberately NOT being set.** CI is being decoupled from them instead, so the
build does not depend on a value only one machine has — which is the same failure mode one level up.

---

### `X-08` — SPEC DRIFT: three times in one day a spec lost to a measurement or to source
**OPEN. Filed as ONE pattern with three instances, not as three corrections.** The corrections are
cheap and are being made; the pattern is what is worth a queue entry.

| # | instance | what won |
|---|---|---|
| 1 | H5's nav-bar wording vs the on-device `.principal` measurement | **the measurement** |
| 2 | `RESULT-PANEL-SPEC` §4/§5 cancelled but still pointed at from five places | **the superseding spec** — this is `DUP-01`, do not re-file it |
| 3 | `docs/PWA-SPEC-PROTOCOL-DETAIL.md:71` records a `PATCH {start_date, is_active: true, status: 'active'}` shape that the web's `ConfirmStart` **does not send** | **the web source** |

Instance 3 in full, because it produced a retraction: that PATCH shape belongs to a **different web
surface entirely**, and the doc collapsed two surfaces into one row of a table. `:71` even draws the
wrong conclusion out loud — *"Setting a date activates the protocol… iOS must reproduce it or
diverge deliberately."*

> **The directing side's `updateStartDate` divergence finding is WITHDRAWN. The doc was wrong and
> the iOS code was right.** `SupabaseBackendClient.swift:103-112` writing `start_date` alone is
> correct behaviour against the real web surface, not a divergence. Recorded rather than deleted so
> the next reader of `:71` finds the retraction instead of re-deriving it.

Note the direction of instance 3 against `X-04`: `updateStartDate` writing `start_date` alone is
**correct**, and it is *also* why the confirm-start screen cannot activate a draft row. Correct code
and a real defect, at the same line. The fix belongs in the insert (`X-04`), not here.

**The pattern: a spec written before the thing exists is a hypothesis.** All three lost to a
measurement or to source, and in all three the spec was internally coherent and confidently worded —
`RULES.md` §5.1 applied to documents rather than to code. **Nothing is built from a spec that has
not been checked against the running system or the real source since it was written**, and a spec
that loses gets a banner the same day (`DUP-01` is what happens when it does not).

---

### `X-09` — WITHDRAWN: "the web de-duplicates before inserting and iOS does not"
**NOT A DEFECT. Recorded so nobody schedules work on it.** No work in this entry.

The claim from the directing side was that saving the same TRT protocol twice yields one row on the
web and **two on iOS**, therefore two schedules and two sets of reminders for one injection. If true
it would be a correctness defect in a dosing app. **It is not true, and it was checked against
production rather than against the source.**

| query | result |
|---|---|
| unique indexes on `saved_dosages` | **`saved_dosages_user_calc_config_key` UNIQUE ON (user_id, calculator_type, config)` — present** |
| duplicate `(user_id, calculator_type, config)` groups across all 102 rows | **0** |
| `'1'::jsonb = '1.0'::jsonb` | **true** — so numeric formatting cannot split a group |

iOS de-duplicates by a **different mechanism** from the web, which is what makes the source read as
though it does not. The web computes a key-sorted stringify fingerprint in `route.ts:100-120`; iOS
inserts and **recovers on the unique violation** — `saveDosage` at `SupabaseBackendClient.swift:132`
catches SQLSTATE `23505` and returns the existing id via `existingDosageId(for:)`. Same outcome, one
row, and it is enforced in the database where both platforms are subject to it. This is already
closed as **`B3-14`** by measurement ("99 rows, two identical saves, 100 rows, 0 duplicate groups"),
and `B3-15` records why insert-then-recover was chosen over `.upsert` — upsert would have overwritten
`start_date` and shifted every calendar occurrence.

**The stacking claim falls with it.** "Both duplicates are drafts, so the user sees neither and can
save it a third time" describes a second row that is never created.

**Interaction with `X-04`, checked, because it is the one thing that could break this:** the index
covers `(user_id, calculator_type, config)`. `status` is not in it. So adding `status` to the INSERT
payload — the `X-04` fix — **does not weaken dedup**, and the two fixes do not need sequencing.

**The lesson, and it is the same one as `DUP-15`:** this was derived by reading two sources side by
side, which is exactly the method `RULES.md` §5.1 exists to distrust. One query against the running
system answered it in seconds. **A divergence between two codebases is a claim about behaviour;
close it by observing the behaviour, not by comparing the code.**

---

### `X-10` — Onboarding flow as its own runnable target, no login

**Spec: `docs/SPEC-ONBOARDING.md`** (owner's, `6bedc53`). Do not restate it here; read it there.
Thirteen screens × four segments, two independent branch dimensions, copy verbatim in one data
file keyed by screen and segment, state in memory handed to a sink protocol. A second app target
`OnboardingPreview` in the same Xcode project, flow in `Sources/OnboardingKit/`, **no dependency on
`Core/Backend`, `Core/Auth` or `Features/`** — `Core/Theme` allowed.

**Why it is worth building properly:** it is the first surface in this project that can be swept
**without signing in**, and sign-in is the measured bottleneck — ~20–25 signed-in checks/hour
against an 11s no-op rebuild. Every future iteration on this flow then costs a build and nothing
else.

> **DUPLICATE CHECK — RUN, AND IT FOUND ONE. This is the one thing to read before starting.**
> `docs/WELCOME-AND-ONBOARDING.md` §3 already specs onboarding: the **five-step personalisation
> flow** mirroring the PWA's `PersonalisationForm.tsx`, which **writes `public.profiles`** and sets
> `onboarding_completed_at`. It is open, unbuilt (`B1-31`-adjacent), and it is **not superseded** —
> the two specs describe different halves of one surface. The new one is the route and the copy;
> the old one is the **write contract**.
>
> `docs/SPEC-ONBOARDING.md` mentions `profiles`, `onboarding_completed_at`,
> `preferred_weight_unit`, `logging_interests` and `NOT NULL` **zero times** — measured, not
> impression. So the constraints live only in the older doc:
> - the three NOT NULL columns and the array **must never be written null** — a skipped step writes
>   the **default**, not a null;
> - `onboarding_completed_at` is set **only on completion** — it is the flag that stops the flow
>   reappearing;
> - **no rounding on the way in** — 180 lb entered must come back 180 lb.
>
> **The risk is concrete and it is deferred, not absent:** this pass ships a no-op sink, so nothing
> is written and nothing can go wrong yet. The moment a real sink is implemented it will be written
> against whichever spec its author is holding. **Whoever implements the sink reads
> `WELCOME-AND-ONBOARDING.md` §3 and `DATA-CONTRACT.md` first** — per `CLAUDE.md`, DATA-CONTRACT is
> authoritative for what the database accepts, and RLS refuses a bad write **silently**.

**Sub-items, separately schedulable:**

| | What | Owner |
|---|---|---|
| `X-10a` | The flow — the target, `OnboardingKit`, the copy file, the state machine, the screens | mac |
| `X-10b` | The fifteen illustrations — none exist; `SPEC-ONBOARDING.md` §5 lists them. **Placeholders ship in the flow pass; placeholders do not ship to the store.** | human |
| `X-10c` | The `$X/mo` price — a literal token in the copy until it is set | human |

**Not a ship-blocker for the current launch.** Starts when the batch-1 sweep is done.

---

## 6. Archive — the superseded 2026-07-31 build backlog

**Kept, not endorsed.** This is what `TASKS.md` held before the transcription, preserved verbatim
because deleting it would have lost live work that has no board finding behind it — **TASK 20**
(fixture-driven conformance runner, P0) and **TASK 21** (plotter compound bible, P0) in particular.
Its claim-a-row workflow (`ACTIVE.md`, `AGENT-WORKFLOW.md`) is retired per `CLAUDE.md` and must not be
followed. **A human triages this section against the findings list above.**

<details><summary>The 2026-07-31 backlog, as it stood</summary>

Status legend: ⬜ To do · 🔄 In progress · ✅ Done (archived)

> **2026-06-05 (bison30):** TASKS 1–8 are **code-complete on Windows** but kept `🔄` (not `✅`)
> because their Definition of Done requires an Xcode build + simulator run, which is impossible on
> this Windows box. They flip to `✅` after the Mac build/verify pass. Code is in the
> local repo `app/` (commit `646f115`).

### Phase 0 — scaffold

**TASK 1 — Scaffold the Xcode project** 🔴 P0 🔄 (bison30) code-complete, needs Mac build
- Issue: No Swift project exists.
- Fix: Create SwiftUI app (iOS 16+), SPM, app target + unit/UI test targets. Add `supabase-swift`.
  Set bundle id, signing, `.xcconfig` for the Supabase anon key (gitignored). Create the iOS Git repo.
- Affected: new project root, `Package.swift`/Xcode project, `.xcconfig`

**TASK 2 — Auth + RootView gate** 🔴 P0 🔄 (bison30) code-complete, needs Mac build
- Issue: App must require sign-in before the dashboard.
- Fix: `AuthStore` (Supabase session), `AuthFlow` (login/signup/reset), `RootView` switching on auth.
  Persist session in Keychain. Discord-link parity if feasible.
- Affected: `AuthStore`, `AuthFlow`, `RootView`

### Phase 1 — shell & dashboard

**TASK 3 — MainShell + side drawer** 🔴 P0 🔄 (bison30) code-complete, needs Mac build
- Issue: Need the off-canvas drawer (the "sidebar") over a NavigationStack.
- Fix: `MainShell` with hamburger + `DrawerView` (scrim, swipe-to-open/close, spring anim).
  Sections: Profile, Dashboard, Calendar, all 14 Calculators, Settings/Sign out. Items from a single
  `NavItems.swift`. iPad → `NavigationSplitView`.
- Affected: `MainShell`, `DrawerView`, `NavItems.swift`

**TASK 4 — DashboardScreen (cycle-planner, default)** 🔴 P0 🔄 (bison30) code-complete, needs Mac build
- Issue: App must open into the cycle-planner.
- Fix: Build the dashboard: next-dose summary, cycle timeline, saved-protocol cards. Load from
  `/api/me` + protocols/cycles. This is the default content screen.
- Affected: `DashboardScreen`, `DashboardViewModel`, `APIClient`, models

### Phase 2 — calculators & rest

**TASK 5 — CalculatorEngine (ported math)** 🔴 P0 🔄 (bison30) code-complete + golden tests, needs Mac run
- Issue: Calculator math must match the web exactly.
- Fix: Port formulas from `Injectbuddy/public/app.js` into a pure-Swift `CalculatorEngine`. Add golden
  unit tests comparing against known web outputs for all 14 calculators.
- Affected: `CalculatorEngine`, tests

**TASK 6 — CalculatorScreen × 14** 🟠 P1 🔄 (bison30) code-complete, needs Mac build
- Issue: Each calculator needs a native form.
- Fix: Generic `CalculatorScreen(slug)` driven by per-calculator field configs; live results from
  `CalculatorEngine`; "Save protocol" → backend. Wire all 14 into the drawer.
- Affected: `CalculatorScreen`, field configs

**TASK 7 — CalendarScreen** 🟠 P1 🔄 (bison30) code-complete, needs Mac build
- Issue: 30-day injection calendar.
- Fix: Project due dates from protocol frequency over a rolling 30-day window (match the web logic).
- Affected: `CalendarScreen`, projection util

**TASK 8 — SettingsScreen + theming** 🟡 P2 🔄 (bison30) code-complete, needs Mac build
- Issue: Settings, account, sign out.
- Fix: Settings list; Discord link; sign out. No theme override — the app is light-only.
- Affected: `SettingsScreen`
- *(See `B1-33` — this screen has still never been measured.)*

**TASK 9 — TestFlight pipeline** 🟡 P2 🔄 (bison30) fastlane + GH Actions written; needs GitHub secrets + ASC setup (`app/SIGNING.md`) + first CI run on Mac
- Issue: Need distribution.
- Fix: Archive + TestFlight upload (fastlane optional). Document signing.
- Affected: CI/signing

**TASK 10 — App Store Optimisation (ASO) metadata** 🟡 P2 🔄 (bison30) drafted, needs human finalize
- Issue: Review panel (SEO, 2026-06-05): the App Store is a search engine; title/subtitle/keyword field
  are harder to change post-launch than code, and ASO installs feed brand search → E-E-A-T.
- Fix: ✏️ Drafted in `launch/ASO.md` (title/subtitle/keywords/description/promo + competitor note).
  Remaining: human pick final variants, run a live App Store competitor search, paste into App Store
  Connect.
- Affected: store metadata (not code)

**TASK 12 — Submission content + App Review readiness** 🟠 P1 🔄 (bison30) drafted, needs human finalize
- Issue: A dosage/health app needs a hosted privacy policy, App Privacy answers, and a review-safe
  posture (Apple 1.4.1) before it can be submitted.
- Fix: ✏️ Drafted in `launch/` (APP-PRIVACY.md, PRIVACY-POLICY.md, APP-REVIEW-NOTES.md) and a
  first-run disclaimer gate shipped in-app. Remaining: fill the `<<CONFIRM>>` items (entity, support
  email, jurisdiction, dates), host the privacy policy at a public URL, create a seeded demo reviewer
  account.
- Affected: `launch/*`, App Store Connect

**TASK 13 — Supabase prod config for the iOS client** 🔴 P0 (blocks OAuth) ⬜
- Issue: Discord OAuth from the app won't complete until the redirect is allow-listed, and signup
  should use leaked-password protection (security advisor WARN, 2026-06-05).
- Fix: In the Supabase dashboard (project `injectbuddy` / rktklvutvbombuajrvrv): add
  `com.injectbuddy.ios://login-callback` to Auth → URL Configuration → Redirect URLs; enable Auth →
  leaked-password protection. (RLS already verified enabled on
  saved_dosages/dose_log/cycles/cycle_items/profiles.)
- Affected: Supabase dashboard (no code)

**TASK 11 — Guard CalculatorEngine against web drift** 🟡 P2 ⬜
- **Identifier collision, flagged during the D2 transcription:** this `TASK 11` is unrelated to the
  audit's **T11** (the AX5 judgment-pass re-survey, deferred as `AX5/T11` — see `B1-26`). Two
  different things have been called "T11" in this repo. Do not cite `T11` unqualified.
- Issue: Review panel (SEO/Engineer, 2026-06-05): the Swift port and web `app.js` can silently diverge
  over time; a wrong result in a health niche is an E-E-A-T wound.
- Fix: Add a CI/test step that re-derives the golden vectors from the current `public/app.js` (or a
  shared fixtures file) so a web math change breaks the iOS suite and forces a re-sync. Keep
  `CALC-MATH.md` as the spec of record.
- Affected: `Tests/InjectBuddyTests/CalculatorEngineTests.swift`, CI
- *(Largely superseded by TASK 20 below.)*

### Phase 3 — parity rewrite against the current mobile web

> **2026-07-30 (lemur87), operator-directed.** The `Features/` UI layer was written 2026-06-05 and
> targets a version of the product that no longer exists. Operator's call: treat `Features/` as
> **rewrite, not port**.
>
> **Do NOT rewrite these — they are current, correct, and expensive to re-derive:**
> `Core/Calculator/*` (engine + 14 golden vectors, pinned by the web repo's `spec/`),
> `Core/Calendar/DoseProjection.swift`, `Core/Backend/*` (PostgREST + RLS — deliberate, the web
> `/api/*` is cookie-auth and unusable from a bearer-token client), `Core/Models`, `Core/Auth`,
> `Core/Theme`, `Features/Onboarding/DisclaimerGate.swift`, `launch/`, fastlane + CI.

**TASK 14 — Shell: TabView + raised Log-dose hero** 🔴 P0 🔄 (lemur87) lean pass done, needs Mac build
- Issue: iOS's primary navigation is the off-canvas drawer. The web moved to a 5-slot fixed bottom bar.
- Fix: Rewrite `MainShell` as a SwiftUI `TabView` with a custom overlaid centre Log-dose button. Slots:
  Dashboard · Calendar · **Log dose** · Tools · Add. **Keep the drawer** behind Tools. Add `.tools`,
  `.add`, `.addConfirm(id:)` to `AppRoute`.
- Affected: `Features/Shell/*`, `Core/Nav/NavItems.swift`

**TASK 15 — Add flow + the start_date gap** 🔴 P0 🔄 (lemur87) lean pass done, needs Mac build
- Correction (lemur87, 2026-07-30): an earlier draft said "nothing ever writes `start_date`". **That
  was wrong** — `CalculatorViewModel.save` does write it via `NewSavedDosage.startDate`. The real gap
  is that it is hardcoded to **today**, silently: add a protocol you actually began three weeks ago and
  every occurrence `DoseProjection` places is shifted by three weeks, with nothing on screen saying so.
- Issue: (a) Saving lives on the calculator, which the web has removed in favour of the Add slot.
  (b) The start day is assumed, never confirmed.
- Fix: Mirror the web. Remove the inline Save. Add becomes contextual. Confirm screen: read the saved
  row back, show `label` + config, take a start day (default today, built from LOCAL date parts),
  PATCH `start_date`, return to Dashboard.
- Affected: `Features/Calculators/*`, new `Features/Add/*`, `Core/Backend/BackendClient.swift`
- Reference: web `components/account/add/AddFlow.tsx`, `ConfirmStart.tsx`, `public/ib-bottomnav.js`
- *(The calculator-count clause of the original text — "exclude the 4 calculators that cannot save …
  the picker should offer exactly 19" — predates H6 and `bf52ecc`. Read `isListed` and
  `savableMembers` for the current sets, not this line.)*

**TASK 16 — Dashboard rewrite** 🔴 P0 ⬜ ← scope DECIDED 2026-08-01: FULL PARITY
- Issue: The iOS dashboard is 3 files against ~30 web components. It is the app's home screen and the
  widest single gap.
- Fix: Rewrite to **full parity — all ~30 components**. Operator's call, 2026-08-01: no reduced v1 set.
- Sequencing this forces: **TASK 18 becomes a hard prerequisite for a subset** rather than a P2
  nice-to-have. Build the independent components first — vial ledger, supply alerts, site rotation,
  serum chart, dose history, cycle progress, tabs, log flow — then land TASK 18's surfaces, then the
  components that read from them.
- Affected: `Features/Dashboard/*`
- Reference: web `components/account/dashboard/` (30 components); design-refs `screens/01-dashboard-*.png`.
  NOTE: the serum chart is a blank band on `01-dashboard-populated.png` because the web tree had
  uncommitted edits at capture time — treat it as "chart goes here", not as the intended design.

**TASK 17 — Calendar rewrite** 🟠 P1 ⬜
- Issue: Built against the old dashboard model; the web calendar and the dose-log/pin model have moved
  on. `DoseProjection` itself stays — this is the screen, not the maths.
- Affected: `Features/Calendar/*`

**TASK 18 — Account surfaces iOS has never had** 🟠 P1 ⬜
- Issue: Missing entirely: blood tests (5 web routes incl. AI extraction), progress/body metrics, cycle
  planner, chat, suggestions, community. Each is a feature, not a screen.
- Fix: Decide per surface whether v1 ships it, defers it, or links out to the web. Blood tests in
  particular is a sub-app with an Anthropic extraction pipeline behind it.
- *(Overlaps `B2-01`, which measures the same gap from the PWA tab list.)*

**TASK 19 — Mac build + verify the REWRITTEN app** 🔴 P0 🔄 (mac-9d4e) builds clean; verification pending 16/17
- CORRECTION (mac-9d4e, 2026-07-31): "the app has never been built at all" is false, and was already
  false when written. Rebuilt twice: `xcodebuild -scheme InjectBuddy -destination 'platform=iOS
  Simulator, name=iPhone 16 Pro' -configuration Debug` → **BUILD SUCCEEDED, zero errors, zero
  warnings**, at both `c8114b1` and `db512cf`. Treat this as re-verify-after-rewrite, not a cold start.
- Fix: Runs LAST, after 14–17. `brew install xcodegen`; fill `Config/Secrets.xcconfig`;
  `xcodegen generate`; build; simulator run.
- Caveat (2026-08-01): "the golden tests pass" is a much weaker guarantee than it reads as — see TASK
  20. Treat a green TASK 19 as "it compiles and runs", NOT as "the maths is right".

**TASK 20 — Fixture-driven conformance runner (replaces the golden tests)** 🔴 P0 ⬜ — **LIVE, no board finding behind it**
- Issue: `CalculatorEngineTests.swift` asserts 15 spot values against a GOLDEN TEST VECTORS table in
  `CALC-MATH.md` — a hand-derived table. `testBmiImperial` already documents a disagreement with it
  (the table says 25.81, the JS formula gives 25.8245) and asserts the formula instead. The real
  contract is 599 machine-derived cases. 15 hand-picked values is not conformance.
- Fix: Build a Swift conformance runner over the design-refs package:
  - Load `spec/vectors/*.json` (10 corpora, 299 cases) **first** — the primary contract — then
    `fixtures/*.json` (21 corpora, 300 cases).
  - **Assert `specVersion` matches what the port implements and fail loudly on mismatch.**
  - Port the `compare()` in `spec/verify-vectors.mjs` — the NORMATIVE implementation. Relative
    tolerance `1e-9` for intermediate floats; **exact** equality for displayed/rounded values, strings,
    integers, booleans and `null`.
  - Decode `{"$nonFinite": "NaN"|"Infinity"|"-Infinity"}`. **A port returning `null` or `0` where the
    reference returns `NaN`/`Infinity` must FAIL, not be flattened.**
  - Evaluate every date-dependent case in `America/New_York`; set the test `Calendar`'s timeZone
    explicitly, never rely on the device or CI default.
  - Retire the 15 golden tests and the dangling `CALC-MATH.md` reference once green.
- Two engine defects this will surface (both visible by inspection, neither fixed):
  1. **Rounding.** `CalculatorEngine.swift` uses bare `.rounded()` at lines 174, 238, 254, 276, 279,
     plus `CalculatorEvaluate.swift:19` on the DISPLAY path (which fixtures compare *exactly*). Swift
     rounds half away from zero; JS `Math.round` rounds half up. Implement `roundHalfUp(x) =
     floor(x + 0.5)` and `roundTo(x, dp)` as named helpers and use them everywhere.
  2. **The guarded/unguarded split is probably not modelled.** `trt`/`eod`/`steroid` return `Infinity`
     and `NaN` by design on empty input; `hcg`/the GLP-1s/`bpc157`/`peptide`/`reconstitution`
     short-circuit to `0`. Same product, opposite behaviour, deliberate. Also `bpc157blend` rounds each
     leg *then* sums, `glp1titration.vials` uses `ceil` while `hcg.dosesPerVial` uses `floor`, and
     `glp1titration` does NOT round its unit counts while the standalone GLP-1 pages do. **Reproduce
     each exactly; do not harmonise them.**
- Affected: `Tests/InjectBuddyTests/*` (new runner), `Core/Calculator/*`. NOTE `Core/Calculator` is
  otherwise on the do-not-rewrite list — this task is the sanctioned exception.
- Reference: `injectbuddy-design-refs` — `spec/math-spec.md` §2.1/§2.2/§2.4/§3.2/§5/§6,
  `spec/verify-vectors.mjs`, `fixtures/README.md`.
- Supersedes: the "confirm the golden tests still pass" clause in TASK 19.

**TASK 21 — Plotter: adopt the compound bible, drop the local tmax table** 🔴 P0 ⬜ — **LIVE, no board finding behind it**
- Issue: The iOS plotter diverges from the web plotter in TWO independent ways, so the same protocol
  draws a different curve on phone and website:
  1. **Different model.** `pk.js:91-97` derives `ka = ln2 / max(0.01, halfLife*0.25)` — `tmax` appears
     nowhere in it. `CalculatorEngine.swift:313-314` instead solves `ka` from a per-compound `tmax` via
     `pkSolveKa`. **No `tmax` value in `CalculatorCatalog.swift:42-55` has a citation.**
  2. **Different numbers.** `CalculatorCatalog` is a FOURTH half-life table and disagrees with
     `spec/compounds.json`: Test C `5.0` vs `6.0` days, Test U `20` vs `21`.
- Decision (operator, 2026-08-01): one bible in Supabase (`public.compounds`), exported at build time
  to `spec/compounds.json`, bundled by both platforms. Neither reads it at runtime. Rationale: web repo
  `spec/COMPOUND-BIBLE.md`.
- Fix (iOS side):
  - Delete the `tmax` column and the hardcoded compound list from `CalculatorCatalog.swift`; load the
    exported `compounds.json` from the vendored corpus bundle instead.
  - Replace `pkSolveKa` usage with the two-branch rule: use a sourced `tmax` when present and tiered
    above `unverified`, else fall back to `ka = ln2 / max(0.01, halfLife*0.25)`. **Every compound is on
    the fallback on day one** — so this must reproduce `pk.js` exactly.
  - Honour the null contract: `half_life_days == nil` means not established. Do not render a number, do
    not plot a curve. Currently unenforced on both platforms.
  - Conformance against `pk-kernel.json` (84 cases) and `pk-series.json` must pass. **Do not start
    until `SPEC_VERSION` has been bumped**, or you will port to a corpus that is about to change.
- Affected: `Core/Calculator/CalculatorCatalog.swift`, `Core/Calculator/CalculatorEngine.swift`
  (`pkSolveKa`, `pkBuildEntries`), `Features/Calculators/CyclePlotterViewModel.swift`
- Relationship to TASK 20: TASK 20 builds the conformance runner; this is the first real defect it will
  catch. Do TASK 20 first — without it there is nothing to prove this fix by.
- *(Sequencing note: the owner's H7–H12 build the Cycle Plotter feature on this screen. This task is
  the maths underneath it, not the feature.)*

### ✅ Done — Auth-verify + offline ("phase 1") · mac-9d4e · 2026-07-31 · `c8114b1`, `db512cf`
Not a numbered task — assigned directly over the Win/Mac channel — recorded because it changed shipping
behaviour.
- **auth-verify:** `AuthFlowView.Mode.verify`. `signUp` reports whether Supabase withheld a session
  pending confirmation and routes to a "check your email" screen; resend on a 30s cooldown with a
  per-second countdown, cancelled on disappear.
- **offline:** `NetworkMonitor` (one app-wide `@StateObject`, hops to the main actor before publishing
  — `NWPathMonitor` calls back on its own queue). `OfflineBanner` in `MainShell`; `OfflineView` + retry
  on Dashboard and Calendar; Settings disables networked rows. Three write paths that had no offline
  handling — `CalculatorScreen` Add, `ConfirmStartScreen` start_date, `LogDoseSheet` log — now gated.
  **Calculators stay fully live offline; only the save is blocked.**
- **`CFBundleURLTypes` was missing entirely**, so `com.injectbuddy.ios://login-callback` was never
  registered and both the confirmation email and the Discord OAuth callback had nowhere to land — while
  the verify screen told users to click the link. Root cause is a repo trap, not a typo. Fixed in
  `project.yml`; verified stable across repeat `xcodegen generate`.
- **Two "empty state that is actually a failed load" bugs.** `LogDoseSheet` said "No protocols yet"
  when the load had failed for lack of a connection; `ConfirmStartViewModel` did
  `catch { state = .missing }`, reporting **any** load failure as "That protocol is no longer
  available" — a false claim about the user's data seconds after they saved it, which invites a
  duplicate. Both fixed; swept the codebase, exactly two instances, no others.

</details>

---

## 7. Known traps (read before editing)

**`Sources/InjectBuddy/Resources/Info.plist` is GENERATED — never hand-edit it.** `project.yml`
declares an `info:` block, so `xcodegen generate` rewrites the file and silently discards hand edits.
It ate `CFBundleURLTypes`, `UIApplicationSceneManifest` and `ITSAppUsesNonExemptEncryption` on
2026-07-31. The build stays green and the app runs — the only symptom is that a confirmation link does
nothing. Add keys under `targets.InjectBuddy.info.properties` in `project.yml` instead.

**Two different things have been called `T11`.** The audit's **T11** is the AX5 judgment-pass re-survey
(deferred, see `B1-26`); `TASK 11` in `§6` is the CalculatorEngine web-drift guard. Cite either one
qualified, never bare.

**Duplicates found during this transcription, reported rather than merged.** Several findings above are
carried in more than one document. Nothing was silently reconciled — the board remains the authority,
and the duplicates are listed so a human can decide which copies retire:

| finding | also appears in |
|---|---|
| `B1-01` four controls under the bar | `WHERE-WE-ARE-2026-08-03.md §4.1`, `ui-audit/2026-08-02-current/README.md` |
| `B1-03` BPC+TB500 input shear | `WHERE-WE-ARE §4.2`, `HANDOVER-2026-08-02-NIGHT.md §3`, `2026-08-02-current/README.md` |
| `B1-04` result cards sheared | `WHERE-WE-ARE §4.4`, `HANDOVER-…-NIGHT §3` |
| `B1-05` / `B3-01` the `Add` write and the draft rows | `WHERE-WE-ARE §2 + §4.3`, `HANDOVER-…-NIGHT §3`, `SPEC-2026-08-03-HUMAN-TASKS.md H6 + H7`, `2026-08-02-current/README.md` — **five documents** |
| `B1-06` Cycle Plotter absent from Tools | `WHERE-WE-ARE §4.5`, `HANDOVER-…-NIGHT §3` |
| `B1-09` picker overflow (F-E) | `WHERE-WE-ARE §4.6`, `HANDOVER-2026-08-02-EVENING.md §2`, `START-HERE.md`, `SPEC-…-HUMAN-TASKS H3` |
| `B1-11` disclaimer (F-F) | `WHERE-WE-ARE §1`, `HANDOVER-…-NIGHT §3`, `SPEC-…-HUMAN-TASKS H4`, `2026-08-02-current/README.md` |
| `B1-14` title truncation | `WHERE-WE-ARE §4.7`, `SPEC-…-HUMAN-TASKS H5` |
| `B1-15` / `B1-26` hyphenation | `WHERE-WE-ARE §1.1`, `SPEC-…-HUMAN-TASKS H3`, `START-HERE.md`, `DECISIONS-2026-08-02.md`, `RULES.md §5.15` |
| `B1-19` `Frequency` keypad-up shear | `WHERE-WE-ARE §4.7`, `HANDOVER-2026-08-02-EVENING.md` |
| `B2-01` missing PWA surfaces | `§6` TASK 18, `PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md`, `STATUS.md` |
| `B2-02` chevron promises navigation | `SPEC-…-HUMAN-TASKS H6`, `PWA-SPEC-PROTOCOL-DETAIL.md`, `DESIGN-PARITY.md` |
| `B2-04` three web-only calculators | `PWA-SPEC-MISSING-CALCULATORS.md`, `STATUS.md` |
| `B1-33` measure Settings | `§6` TASK 8 |
| BOARD §5 rules cited throughout | `docs/RULES.md` — an additive copy of the same 39 rules, by the same discipline as this file |

---

## 8. From the 2026-08-03 duplication sweep — contradictions and duplication

**Not from the BOARD inventory. Outside the 74** (see `§0`, delta note 5). These are findings about
the *documents*, filed here because there is nowhere else that a session actually reads.

**Filed one item per CAUSE, not one per SITE.** Fifteen entries against roughly **130 sites**. That
ratio is the point, and it is the lesson of the QA-credential incident stated as a filing rule: four
documents once carried the same QA item, and filing per-site would rebuild that problem inside the
fix. Where an entry names several documents, they are **sites of one cause** — close it once, in one
pass, or not at all.

**Every claim below was re-verified against the tree at `6de193a`,** not taken from the sweep.
Line numbers in the sweep predated the archive move (`909c994`) and several had moved; the ones here
are current. Two of the sweep's findings did not survive verification and are recorded as such in
`DUP-15` rather than filed as work.

**Ordered most dangerous first.** `DUP-01`…`DUP-13` are contradictions — two documents that cannot
both be acted on. `DUP-14` is hygiene: statements that AGREE, so no session can be misled by them,
only bored. `DUP-15` is about the sweep itself.

---

### `DUP-01` — a CANCELLED spec still has five live pointers into it
**OPEN. Most dangerous item in this section: acting on any one of these builds a cancelled feature.**

`docs/RESULT-PANEL-SPEC.md` carries a `⛔ SUPERSEDED — 2026-08-03` banner at `:3-18`. Its §3
(barrel-fit strip) is **cancelled**, its §4 (do not draw a syringe) is **reversed**, its §5 is
**moot** — superseded by `docs/SPEC-RESULT-SHEET-AND-SYRINGE.md`, the owner's call. Five places
still point at it as live work:

| site | what it says | what it needs |
|---|---|---|
| `HANDOVER-2026-08-02-EVENING.md:104-108` | T26 as open queue item 3; Mac "owes win two reads", one of them whether the **14pt track** reads as furniture | **delete** — the track is the cancelled §3 |
| `HANDOVER-2026-08-02-EVENING.md:114-119` | "**Blocking T26 §5**" — `accessibilityHidden` does not remove the hero glyph | **delete as a blocker** — see below |
| `ui-audit/BOARD.md:412-417` | inside the `accessibilityHidden` finding: "**invalidates an assumption in `RESULT-PANEL-SPEC §5`**" | **RE-AIM, do not delete** — see below |
| `Sources/InjectBuddy/Features/Shell/MainShell.swift:261` | source comment: "the barrel-fit strip in RESULT-PANEL-SPEC §5 is specced on exactly it" | **repoint** — DECIDED by the directing side, **not done here**, see the ownership note |
| `B1-13` (this file) | transcribes the BOARD sentence verbatim | follows whatever BOARD is re-aimed to; do not repoint it independently or the two drift |

**Why the a11y blocker is moot for the syringe but the BOARD entry is not deletable.**
`SPEC-RESULT-SHEET-AND-SYRINGE.md:265-266` makes the syringe **one VISIBLE accessibility element**
with a label of the form `"Syringe, 37.5 of 100 units"` — it is no longer trying to hide a
decorative duplicate, so `accessibilityHidden` is not on its critical path at all. But the BOARD
finding underneath is a *measured fact about the app* — a decorative glyph is a VoiceOver stop on
every screen — and it stands whatever the result panel does. **Re-aim it away from
`RESULT-PANEL-SPEC §5` and onto the hero glyph itself. Deleting it deletes a measurement.**

**Ownership note — the `MainShell.swift` repoint is decided but NOT actioned here.** The directing
side has decided that comment should be repointed. `Sources/` is owned by another agent as of this
pass, so it is filed, not edited. Whoever holds that file makes the one-line change; do not batch it
with the doc edits.

---

### `DUP-02` — "needs the human: database CHECK constraints" is carried open in four documents, and three quarters of it is already done
**OPEN — owner: HUMAN. Scope is `logging_interests` ONLY.** This is the "needs the human" cluster,
and it is **one item, not four.**

**The work is largely done and verified.** `DATA-CONTRACT.md:62-77`: constraints applied 2026-08-03,
**verified against all 91 live rows first — zero violated any of them**, so it was additive and
nothing was rewritten. `profiles_preferred_weight_unit_check`, `profiles_preferred_height_unit_check`
and `profiles_preferred_dose_unit_check` all exist in production. The four open asks all name
"`profiles.preferred_*` **and** `logging_interests`". Only the `logging_interests` half survives —
`DATA-CONTRACT.md:49` shows it as `text[]`, default `{}`, with the four allowed values enforced
nowhere in the database.

**The four stale copies. Sites to correct, NOT separate items:**

| site | numbering |
|---|---|
| `HANDOVER-2026-08-02-EVENING.md:121-132` §4 — "three items", listed **2, 3** | broken |
| `HANDOVER-2026-08-02-NIGHT.md:133-140` §6 — "four items", listed **3, 4** | broken |
| `WHERE-WE-ARE-2026-08-03.md:182-192` §5 — listed **1, 2, 5** | broken |
| `WIN-SIDE-README.md:138-139` — prose, no list | n/a |

**Record the diagnostic, it is worth more than the item.** Three of the four have **BROKEN
NUMBERING** — a header promising three items above a list starting at 2, a list running 1, 2, 5.
That is the fingerprint of items being deleted **from the copies** rather than from a source: each
document was pruned independently, and the gaps are where the pruning happened. It is the same
failure the QA-credential incident had, visible in the numbering before anyone reads the content.
**A list whose numbers skip is evidence that it is a copy.**

---

### `DUP-03` — T27 (`Units (U-100)` on a 3 mL barrel) is open in two documents and closed-by-construction in a third
**OPEN, with a stated acceptance condition.** Three sites, one finding:

- `HANDOVER-2026-08-02-EVENING.md:109-110` — queue item 4, open, "filed unbundled deliberately".
- `RESULT-PANEL-SPEC.md:117-122` — open, inside the superseded spec (`DUP-01`).
- `SPEC-RESULT-SHEET-AND-SYRINGE.md:27-28` — **"closed by construction here, provided the port keeps
  the barrel-derived scaling and does not hardcode U-100."**

**File the proviso as the acceptance condition, not as a tick.** T27 closes when, and only when, the
shipped port derives the scale from the selected barrel. A port that hardcodes U-100 reopens it
silently — and silently is exactly how it got filed in the first place. Assert the 3 mL case
specifically; it is the one with no units scale.

---

### `DUP-04` — the live profile counts disagree, and the real defect is that two of them carry no date stamp
**OPEN.** `DATA-CONTRACT.md` is authoritative per `CLAUDE.md`.

| site | claim | dated? |
|---|---|---|
| `DATA-CONTRACT.md:64, :91, :104` | **91 live rows**; **90 of 91** have `timezone = NULL` | **yes — "Applied 2026-08-03"** |
| `README.md:193` | 88 of 89 | **no** |
| `START-HERE.md:226-227` | 88 of 89 | **no** |
| `PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md:274` | "live distribution across **89 profiles**" | yes — header `:3` "Extracted 2026-08-02" |
| `PWA-SPEC-HISTORY-INVENTORY-SETTINGS.md:427` | 88 of 89 | same header |

**The numbers are not the item.** 88/89 → 90/91 over one day is a live table growing, which is
correct behaviour; both were true when written. **The item is that `README.md:193` and
`START-HERE.md:226-227` state a production row count with no date on it**, so a future session
cannot tell a stale number from a fresh one and has no way to know which to trust. `PWA-SPEC` does it
right — its number is dated at the top of the file and reads as a snapshot.

Fix: every production count carries the date it was queried, or it is written as a *shape*
("`timezone = NULL` is the norm, not the edge") with no number at all. The shape is what the design
depends on; the count is not.

---

### `DUP-05` — six documents describe a side drawer as THE navigation; the app ships a bottom tab bar
**OPEN. One cause — the 2026-06-05 shell — across six documents.**

| site | what it says |
|---|---|
| `README.md:4` | "all 14 dosage calculators in a **side drawer**" |
| `README.md:143` | "`NavItems` — the single source for **drawer items**" |
| `README.md:149` | "`MainShell` + **off-canvas DrawerView**" |
| `docs/SCREENS.md:3, :4, :23, :59, :124, :179` | "All screens render inside `MainShell` (**drawer** + `NavigationStack`)"; hamburger toolbar; reachable "from the drawer" |
| `docs/WIREFRAME-PLAN.md:11, :28, :36, :41, :60-61, :77-81` | "**One side drawer holds everything**"; §5 "Drawer spec (**core deliverable**)" |
| `docs/LAUNCH-CHECKLIST.md:26` | see below |
| `docs/README.md:9, :22, :35` | "All 14 calculators reachable from a single **side drawer**"; "Side menu: custom SwiftUI off-canvas drawer" |

What actually shipped is the TabView shell — `§6` TASK 14, and `B1-10` / `B1-12` are findings *about
the tab bar*, measured on the running app.

**`LAUNCH-CHECKLIST.md:26` is the dangerous one and is why this is not just tidying.** It is a
**Definition of Done**: *"Confirm Definition of Done: unauthed→auth, authed→dashboard, drawer lists
14 calcs + Dashboard + Calendar, swipe/scrim dismiss…"*. That is an **acceptance criterion for a
shell that no longer ships**. Anyone working the launch checklist honestly cannot pass it, and the
only ways through are to fake it or to rebuild the drawer.

Note the archived docs already handle this correctly — `docs/archive/INSTRUCTIONS.md:1-5` says in its
own banner *"Its Definition of Done refers to a drawer that no longer exists."* The six above have no
such banner. **One pass, one decision: banner them all or correct them all.**

---

### `DUP-06` — an archived handover that advertises itself as "everything a fresh session needs" is wrong three ways
**OPEN — low urgency, it is in `docs/archive/`, but it self-describes as a startup doc.**

`docs/archive/HANDOVER-2026-08-01-FULL.md:3-5`: *"**One self-contained document.** Everything a fresh
session needs."* Its Part B (`:181` onward) is contradicted by `docs/HARNESS-AND-LOOSE-ENDS.md` three
independent ways:

| Part B says | `HARNESS-AND-LOOSE-ENDS.md` says |
|---|---|
| `:195` "The three red assertions — exact state, and what is already ruled out" — presented as live diagnoses | `:13-17` "**CLOSED 2026-08-02, and the diagnosis below was wrong.** Why it got that wrong is more useful than the fact that it did." |
| device state erased and signed out at iOS first-boot | `:190-193` "**The previous text here said erased and signed out… That is no longer true, and a cold session planning around it is wrong within minutes.**" Observed 2026-08-02: **not erased**. |
| `:233`, `:294` the quick-value row is unreachable because "the **keyboard** covers the chips" | `:223-225` "**Resolved 2026-08-02, and the premise was wrong: the pinned result bar IS the occluder.**" It sits *above* the keyboard. |

The third is the one that costs a session: a fresh reader debugging keyboard avoidance is looking at
the wrong occluder, and `B3-12` records that `quick_mgWeek_400.tap()` **reported success and moved
nothing** — so the wrong premise plus a green tap is a whole afternoon.

Fix is one banner on that file — `docs/archive/README.md` already lists it as superseded, but the
file's own opening line still claims to be self-contained and a reader who lands on it directly never
sees the folder README.

---

### `DUP-07` — `DECISIONS-2026-08-02.md:389` cites `D3` for a rule that is not `D3`
**OPEN. One site, one line, and the file predicted this exact error.**

`:385-389` closes with *"Calculator names were considered under the same argument and rejected
(D3)."* `D3` is at `:41` and is **"Serial and log row per frame"** — nothing to do with type-size
caps. The real site is **§13, `:298-301`**: *"no `dynamicTypeSize(...up to:)` cap on calculator names
— they are navigation labels in a dosing app and AX5 users are exactly who needs them legible."*

**The file's own warning at `:12-15` describes this error in advance:** *"The `D` rules below and this
file's numbered sections are two different series. `D3` is not §3. If you arrived from a `D<n>`
citation, read the `D` rules and stop there — matching the number against a section heading gives a
wrong answer that reads right."* A reader following the warning correctly lands on `D3`, finds a
screenshot-logging rule, and concludes the citation is broken — which it is, but only after they have
been sent to the one place guaranteed not to help.

Fix: `(§13)`, not `(D3)`. **Repoint it by hand, alone.** `RULES.md:14-21` bans bulk repointing —
"not with `sed`, not with a find-and-replace, not 'in one pass'."

---

### `DUP-08` — the rig OS is written two ways, and BOTH are right
**OPEN as a wording fix, NOT as a contradiction. Resolved against the running system, per
`RULES.md` §5.1.**

`xcrun simctl list runtimes` on this machine returns exactly:

```
iOS 18.3 (18.3.1 - 22D8075) - com.apple.CoreSimulator.SimRuntime.iOS-18-3
```

So the runtime's **name** is `iOS 18.3` and its **version** is `18.3.1`. Neither set of documents is
wrong; they are quoting different fields of the same object.

| says `18.3.1` | says `18.3` |
|---|---|
| `WHERE-WE-ARE-2026-08-03.md:198` | `HANDOVER-2026-08-02-NIGHT.md:144` |
| `MAC-SIDE-README.md:64` | `HANDOVER-2026-08-02-EVENING.md:136` |
| | `HARNESS-AND-LOOSE-ENDS.md:193` |
| | `ui-audit/2026-08-01-current/README.md:4` |
| | `ui-audit/2026-08-02-current/README.md:3` |

`BOARD §0` (`ui-audit/BOARD.md:32`) is the rig-state authority and, as it happens, states neither.
Fix: `BOARD §0` records **`iOS 18.3 (18.3.1)`** — the full simctl string — and everything else points
at it. **Do not "correct" the five to 18.3.1; they are not errors.** This entry exists so nobody
spends a pass reconciling a disagreement that is not one, and so the next person who notices it finds
this instead of re-deriving it.

---

### `DUP-09` — the two cold-start docs disagree about the branch tip, on their first line
**OPEN.** Reconcilable, and that is not the point.

- `WHERE-WE-ARE-2026-08-03.md:6` — "Branch `feature/tabview-shell`, tip `62ab0bf`."
- `WIN-SIDE-README.md:120` — "Branch `feature/tabview-shell`, tip **`368a9fe`**, clean, everything
  pushed."

Both commits exist and both are on the branch; `368a9fe` is the later of the two, and each document
was accurate when it was written. **The item is that a cold-start doc's first paragraph states a
commit sha**, so the two documents a fresh session is told to read give it two different answers to
"where am I" before it has run a single command.

Fix: neither cold-start doc names a sha. `git log -1` is authoritative, always current, and costs one
command. Name the *branch* — that is stable and it is what the reader actually needs.

---

### `DUP-10` — `README.md` sends a cold session to `START-HERE.md` first; two other documents say `START-HERE` is explicitly NOT a startup doc
**OPEN. Three sites, and this one mis-routes every fresh session that starts at the repo root.**

- `README.md:12-21` — "**Starting a fresh session? Read these, in this order** — 1. `docs/START-HERE.md`…"
- `CLAUDE.md:49` — "`docs/START-HERE.md` | The long session log — the story of *why*. **Not a startup
  doc.**"
- `MAC-SIDE-README.md:23-24` — "`START-HERE.md` is the long session log behind these — go there when
  you need the story of *why*, **not to begin.**"

`START-HERE.md:3-6` agrees with the latter two — its own opening says *"Opening the project cold?
Read `WHERE-WE-ARE-2026-08-03.md` first."* So `README.md` is the only document in the repo that
disagrees, and it is the one a session sees first. Its list also omits both startup docs
(`MAC-SIDE-README.md`, `WIN-SIDE-README.md`) entirely.

Fix: `README.md`'s reading list becomes the two side-READMEs, matching `CLAUDE.md:38-39`.

---

### `DUP-11` — three documents are stale as WHOLE FILES, not in places
**OPEN. These cannot be fixed line by line; each needs a banner or a rewrite, as one decision.**

**`docs/STATUS.md`** — self-describes as a "snapshot, ≤50 lines, prune don't append" and every
headline in it has been overtaken:
- `:4` "**It compiles.**" is the *Now* section, on an app that has since been measured, screenshotted
  and audited across two sessions.
- `:9` `c8114b1`, `db512cf` "**not pushed**" and `:32` "`[ ] Push c8114b1/db512cf`" — both are in
  history and the tree is clean.
- `:8-10` "phase 2 is the conformance runner (TASK 20) plus the eight unbuilt calculators" — TASK 20
  is still live (`§6`), but the phase framing predates the entire UI audit.

**`docs/LAUNCH-CHECKLIST.md`** — `:6` "**Last updated 2026-06-05 by bison30**", two months stale. Its
P0 §B is "First Mac build + verify", which happened on 2026-07-31 (`§6` TASK 19, `STATUS.md:4-7`),
and `:26` is the drawer Definition of Done in `DUP-05`.

**`docs/README.md`** — `:14` "This is a **greenfield native app** (no Swift code exists yet)". The
app has ~50 source files, 27 unit tests and five XCUITest suites. Its retired-docs block at `:26-29`
is **correct and current** (it was fixed by `909c994`); the greenfield framing around it was not.

**Do not delete any of the three.** `LAUNCH-CHECKLIST` holds live App Store Connect work that exists
nowhere else, and `STATUS.md` holds the `CalculatorCatalog` don't-touch note (`:50-54`) that `§6`
TASK 21 depends on. Banner, then triage the live remainder into this file.

---

### `DUP-12` — the running "Nth check caught reporting success while observing nothing" tally is frozen at a different number in six documents
**OPEN. Ten statements, seven documents, and it will diverge again on the next find.**

This is load-bearing rhetoric — it is the sentence that makes `RULES.md §5.24` land — and it is
carried as a **running total** in places that have no way to know when it changes.

| kind | site | number |
|---|---|---|
| **running total** | `HANDOVER-2026-08-02-EVENING.md:39` | "**six** checks were found reporting success" |
| **running total** | `HANDOVER-2026-08-02-NIGHT.md:127` | "**Seventh** check found reporting success" |
| **running total** | `MAC-SIDE-README.md:54-55` | "**Eight** checks have now been caught" |
| **running total** | `WIN-SIDE-README.md:66-67` | "**Eight** checks have now been caught" |
| incident ordinal | `RULES.md:355` · `ui-audit/BOARD.md:1301` | "the **seventh** check" |
| incident ordinal | `RULES.md:390` · `ui-audit/BOARD.md:264` · `B1-07` (this file) | "the **eighth** check" |

**The distinction is the fix.** The six **incident ordinals** are correct and must not be touched —
they date a specific incident inside the finding that recorded it, the way a case number does. The
four **running totals** are the defect: four documents each claiming to hold the current count, three
different answers, and the two startup docs agreeing only by accident.

**One item: the total belongs in ONE place.** Put it in `RULES.md` beside rule §5.24 — the rule the
number exists to support — and have the other three say "see `RULES.md §5.24` for the count". The
next find then updates one integer instead of four, and the two startup docs stop being able to
disagree.

---

### `DUP-13` — two `§5.7` citations should be `§5.9`, and two `§5.7` citations nearby are CORRECT
**OPEN. Four sites, two wrong, two right. Read all four before touching any.**

`RULES.md:73-77` — **rule 7** is *"Prefer a container that truncates visibly over one that clips
silently… Never accept silent clipping on a title, a value or a unit."*
`RULES.md:84-85` — **rule 9** is *"The screens nobody complains about are where defects accumulate,
because attention follows complaints rather than risk."*

| site | text | verdict |
|---|---|---|
| `ui-audit/BOARD.md:689` | "This is §5.7 — **attention follows complaints rather than risk** — with a number" | **WRONG → §5.9** |
| `B1-32` (this file) | "So the log sheet was never an outlier; it was the first one anyone looked at. This is `§5.7` with a number attached, and the number is **10**." | **WRONG → §5.9** |
| `ui-audit/BOARD.md:419` | "§5.7 bans this outright — never accept **silent clipping** on a title" | **CORRECT — do not touch** |
| `B1-14` (this file) | "`§5.7` bans this outright — never accept silent clipping" | **CORRECT — do not touch** |

**These two were left on disk deliberately by the agent that fixed the other three** (`6e160aa`,
"§5.22 was citing itself wrong — §5.7 repointed to §5.9, all three sites"), precisely because
`RULES.md:14-21` forbids bulk repointing: *"NEVER BULK-REPOINT `§5`. Not with `sed`, not with a
find-and-replace, not 'in one pass'… Repoint citations one at a time, reading each one, or do not
repoint them."*

**So this entry is the instruction, not the fix.** Repoint the two wrong ones **individually, reading
each in context**. A `sed s/§5.7/§5.9/` over this repo breaks two correct citations to fix two broken
ones — net zero, and it destroys the silent-clipping ban that `B1-14` and `B3-10` both hang on.
`ui-audit/BOARD.md:1099` and `RULES.md:164` already cite `§5.9` correctly and are the model.

---

### `DUP-14` — twelve pure-duplication clusters: ~69 statements that AGREE
**OPEN — HYGIENE, not a defect. ONE item covering all twelve clusters.**

Everything below is **consistent everywhere it appears**. No session can be misled by it; the cost is
that a fact updated in one place goes stale in five, and the QA-credential incident is what that
looks like when it finally bites. Filed as one item so nobody opens twelve.

| cluster | statements | authoritative home |
|---|---|---|
| `TEST_RUNNER_` prefix or the suite skips and reports success | 11 | `RULES.md` rule 26 / `BOARD §5.26` — **plus the security exception below** |
| light-only lock (`UIUserInterfaceStyle: Light`) | 10 | `CLAUDE.md` |
| `simctl ui content_size` is DEVICE state, reset in the same command | 7 | `RULES.md` (rig rules) |
| Keychain holds the session, so `simctl erase` signs you out and uninstall does not | 6 | `CLAUDE.md` |
| `savedDosages()` filters neither `status` nor `is_active` | 6 | `B1-05`, this file |
| `project.yml` generates `Info.plist`; hand edits are destroyed | 5 | `CLAUDE.md` + `§7` above |
| Cycle Plotter absent from Tools | 5 | `B1-06`, this file |
| `.upsert` would have overwritten `start_date` and shifted every occurrence | 5 | `B3-15`, this file |
| the `10-tools-ax5` judgment-pass story | 4 | `RULES.md` §5.15 — **see the hyphenation warning below** |
| `result_<label>` addressing ambiguity | 4 | `B1-27`, this file |
| F-E picker overflow, specced in three places | 3 | `B1-09`, this file |
| onboarding must ship Settings-first, wizard second | 3 | `DATA-CONTRACT.md:55-60` |

**Two things in this table must NOT be lost in a merge, and they are the reason this is filed rather
than swept by a script:**

1. **`START-HERE.md:242-246` alone carries a security item.** *"The password was relayed over the
   message bus on 2026-08-02 at the human's instruction and sits in the bridge's DB on both machines;
   **rotation is outstanding**."* It is the **only** security statement in an eleven-statement
   cluster, and it is in the copy most likely to be judged redundant. Rotation is a live human task.
   **Relocate it before anything in that cluster is deleted** — it does not belong to the
   `TEST_RUNNER_` cluster at all, it just lives next door.
2. **Three of the four `10-tools-ax5` retellings still list hyphenation among the six problems.** The
   owner **reversed** that on 2026-08-03 (H3) — mid-word hyphenation is accepted behaviour, see
   `B1-15` and `B1-26` rows 1–2. Those three retellings are not merely duplicated, they are
   **duplicated AND now wrong**, and a session reading any of them re-files a defect the human
   already decided against. This cluster is the one to do first.

Counts are the sweep's, spot-checked and corroborated for order of magnitude; **re-derive the exact
site list at fix time** rather than trusting the integers above.

---

### `DUP-15` — what the sweep got wrong, recorded against the SWEEP
**CLOSED — recorded so nobody acts on either.** No work in this entry.

**1. `docs/TEST-QUEUE.md` was flagged as dead multi-agent residue. It is not.** It was created
**today** — `727e2d8` and `f5e915a`, both 2026-08-02 — and `:1-11` describes the *current* one-runner
device protocol ("One simulator, one runner. No agent other than the test-runner touches the device"),
not the retired 2026-07 claim-a-row arrangement. It is also OFF LIMITS to this pass.

**The lesson is about the method, not the file. A duplication sweep matches on SHAPE, and today's
scaffolding has the same shape as 2026-07's residue** — both are coordination files describing who
may touch what. Nothing in the text distinguishes them; only the commit date does, and a text sweep
does not read commit dates. **Rule: anything a sweep flags as dead that is younger than the current
session is confirmed with a human before deletion.** `git log --format='%ad' -- <file>` is one
command and it is not optional.

**2. The sweep's claim that `docs/README.md` advertises three retired docs as live is now FALSE.**
It was true when swept. `909c994` moved `INSTRUCTIONS.md`, `AGENT-WORKFLOW.md` and `ACTIVE.md` into
`docs/archive/`, and `docs/README.md:26-29` now names all three as *"Retired and moved to `archive/`
on 2026-08-02 — do not follow"*. All three carry their own in-file `RETIRED` banner
(`archive/INSTRUCTIONS.md:1`, `archive/AGENT-WORKFLOW.md:1`, `archive/ACTIVE.md:1`) — including
`INSTRUCTIONS.md`, which the sweep reported as the one lacking a banner. `docs/archive/README.md`
records all three. The related claim that `docs/TASKS.md:3-4` still tells agents to claim a row in
`ACTIVE.md` is also false as of `6de193a` — `§0` replaced that text, and `§6`'s surviving mention of it explicitly marks the workflow retired.

**Both of these are the same failure and it is the sweep's, not the documents'.** A sweep is a
**snapshot**, and a snapshot of a repo under active edit decays within hours. Every finding from one
must be re-verified against the tree before it is filed, which is why the header of this section
records the sha it was verified at. Filing an already-fixed finding costs a future session a full
pass to discover the fix — the same cost as filing a wrong one.
