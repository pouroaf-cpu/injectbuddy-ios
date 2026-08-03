# Human tasks — 2026-08-03

Twelve items from Pouroa, with four ambiguities resolved by him directly. Written into git rather
than left on the bus because it spans more work than one context will hold.

**Three of these overturn existing board findings.** Those reversals are his call, are recorded as
his, and must not be re-raised by a later session as if they were oversights.

---

## H1 — Stepper buttons scale with Dynamic Type

The `+` / `−` controls are fixed size today, so at large text the value grows and the controls do
not. They scale.

The 44pt minimum becomes a **floor, not a size**. Growing them costs horizontal room in a row that
has already produced two truncation defects, so this lands with H2 and H3 as one measurement pass,
not separately.

## H2 — The unit sits ~30% smaller than its value

`mg/mL`, `mg/week`, `mcg` render at **70% of the value's resolved size**, at every text size.

Ratio, not a point difference — so it holds as the scale changes rather than being correct at one
size. Decided by win; the human said "30% smaller where possible" and a ratio is the only form of
that which survives Dynamic Type.

**The unit keeps its no-truncate guarantee.** It never wins the row again, but it never clips
either — that was F1, the worst finding of the original audit. If a 70% unit still cannot fit
beside its value, the row reflows (H3), it does not shrink the unit further.

## H3 — Text never spills; controls grow downward

Where content cannot fit on one line, **the control grows vertically**. Text never renders outside
its own chrome.

This is the picker overflow (F-E) with the fix direction now decided by the human, and it absorbs
it. The compound name currently draws on top of the label above and the field below — two strings
in the same pixels, on the control that selects which compound is being dosed.

### HYPHENATION IS NOW ALLOWED — this reverses a board finding

**The human chose mid-word hyphenation explicitly, with the alternative shown.** So:

```
┌────────────┐
│ Oxan-      │
│ drolon-  ⌄ │
│ (Anavar)   │
└────────────┘
```

`Semaglu-tide` and `Retatru-tide` are **accepted behaviour**, not defects. Strike the hyphenation
half of the Tools-at-AX5 finding and the hyphenation note on Steroid Dosage. What remains of those
findings is real and stays: the **overlap**, the **clipped title**, and **icons that stayed small
while text grew**.

Do not re-file hyphenation. It was raised, shown, and decided against.

**Scope: the shared control, not a screen.** `FieldRow.content` is the only call site for
`.picker`/`.stringPicker` — 12 picker fields across 8 calculators. `CyclePlotterScreen` renders two
pickers *without* `fieldChrome` and is not covered; state that rather than leaving it to the reader.

**Already ruled out, with measurements — do not retry:** `.fixedSize(horizontal:false,
vertical:true)` on the menu picker changed the geometry by nothing, byte-identical. Growth requires
replacing `.pickerStyle(.menu)` with a `Menu` whose label we lay out ourselves.

**Four invariants ride on that control** and each is a way to trade one visible defect for four
invisible ones: the 44pt tap target, the accessibility label, the `control_<key>` identifier, and
`unique(_:type:)`. Re-assert all four after the swap, on a screen measured before it. `unique`
fails at *resolution*, so a regression there presents as an assertion that has quietly stopped
meaning anything inside a suite still reporting green.

## H4 — Drop the disclaimer-visibility finding

F-F is closed as **won't fix, by the human's decision**. He was shown that "not medical advice" is
never legible at rest on any calculator and said it does not matter.

Remove the finding, and remove the expected-failure entries that carry it so the overlap suite
stops tracking a debt nobody intends to pay. Record it as his call with the date.

*Win's note, recorded once and not to be re-raised:* the audience for that line is not users.

## H5 — Calculator name out of the scrolling content

> **The nav-bar wording below is SUPERSEDED — struck 2026-08-03, against a measurement.** It is
> kept struck rather than deleted so nobody re-derives it. **The deliverable is UNCHANGED:** the
> title comes out of the scrolling content and the truncating-title defect closes. Only the
> *destination* named in the original wording is dead. There is one live instruction here, not two.

~~The screen title moves into the top navigation bar (`BPC-157`, `TRT Dose`), and the header area is
restyled.~~

**Why it was struck.** `docs/DESIGN-PARITY.md:225-244` — the §9 addendum, measured on device —
probed a wrapping `Text` in `.principal` at default and AX5: two lines render, **three are clipped
at both ends**, and the bar does not grow further at AX5. It fails **silently** — no ellipsis, so
nothing on screen says content is missing, and a sheared third line reads as a rendering glitch or
as the whole title. "Testosterone Dosage Calculator" does not fit two lines at AX5. §9 had already
rejected the nav bar on that measurement and chosen **option (a), the branded header in the content
area** (`DESIGN-PARITY.md:206`, `:241`). The nav bar was specified before the probe; the probe
settled it. This is a spec that lost to a measurement.

**Build option (a): the content-area header.** Not `.principal`.

This resolves the open screen-header parity finding, which had been about the title colliding with
the header row. Two things it must not undo: **titles never truncate** (`Steroid Dos…` is a live
defect and this is the fix for it), and the PWA's own truncating header is *not* the parity target
— iOS is deliberately better there.

## H6 — BMI and Free T Index: out, and unreachable

**The human's words: "leave them alone, and don't let the links to it go anywhere, we will work on
later."**

So: remove both from the Tools list and from the add-protocol dialog. No layout work, no shear
work, no styling on either screen.

**Remove the rows rather than disabling them.** A visible row that does nothing is the chevron
defect we already have filed — it promises navigation and delivers none. Keep the screens and the
engine intact behind the flag so re-enabling is one line.

### The CTA gate is still required — do not skip it as redundant

Removing the links makes the BMI write *unreachable*, not *fixed*. And `canSaveProtocol` is false
for **three** calculators: BMI, Free T Index and **Cycle Plotter** — and Cycle Plotter stays
reachable and is about to be built on. Gate the CTA on `canSaveProtocol` as planned.

`AddScreen` already honours the flag. `CalculatorScreen` never references it. The comment on the
flag says it exists so a calculator does not "walk the user into a wall at the last step" — the
code that would honour it is the code that is missing.

---

# Cycle Plotter — H7 to H12

A feature build, not a fix. Sequence it; do not open all of it at once.

## H7 — The plotter shows saved dosages, and the user picks which

**The human chose a selector over any automatic rule**, having been shown that 71 of 102 saved rows
are `draft`, 31 are `active`, and 24 of 39 users have nothing active at all.

That choice sidesteps the draft problem by making it explicit rather than guessing. It also means
the plotter does **not** depend on the protocol-status work (G5) landing first.

- Selector lists the user's protocols with their status visible — `active` and `draft` distinguished,
  because a user picking what to plot needs to know which are actually running.
- Read `status`, never the `is_active` mirror. The mirror carries two states; the source carries
  three.
- Selection persists across sessions.
- Zero state: a user with no protocols gets a real empty state, not an empty chart.

## H8 — Add a dosage from the plotter

Start date and dosage strength. Writes a protocol.

**Setting a start date activates the protocol** — that is the web's model and its own comment says
"you can't schedule something that's switched off". Copy it or diverge deliberately, and say which.

Writes go to PostgREST directly; iOS bypasses the web API. **`user_id` must be present** — omitting
it is exactly how "saving a protocol from iOS had never worked" happened, every insert refused by
RLS. Assert the write landed by reading it back, not by the call returning.

## H9 — Collapse and stick on scroll

Scrolling past the fold collapses the plotter, which then stays pinned to the top.

This screen already has a pinned-surface problem elsewhere in the app: the result bar was taking
52% of the content area and shearing inputs. **Gate the collapsed height on a measured share of the
content area**, the same way the result bar now is — not on a scroll offset and not on a type size.
Cap is 0.40 there; measure this one rather than inheriting the number.

## H10 — A dose card per protocol, with its injection history

Card shows: **start date, finish date, frequency, strength**. Beneath it, **every injection** for
that protocol.

`dose_log` already carries `site`, `draw_ml`, `injection_time`, `injection_timezone`, `injected_at`
and `scheduled_on` — this needs no schema change. `draw_ml` arrives from PostgREST as a **string**.

Paging: the web has none and it is a known gap. A user two years in has hundreds of injections.
Page it here rather than inheriting the omission.

## H11 — The card is editable; Save greys until an edit is made

**The human chose protocol *and* logged injections**, not protocol alone.

So this edits two different things and they carry different risk:

- **Protocol fields** — start date, frequency, strength. Future doses re-derive.
- **Logged injections** — the record of what was actually taken. Editing these **rewrites history**.

Two things follow, and neither is optional:

1. **Never silently re-derive a logged injection from a protocol edit.** If changing a protocol's
   start date would move doses the user has already logged as taken, that is a conflict and the
   user resolves it. A dosing app must not quietly restate what someone did.
2. **Deleting a logged injection is destructive and needs a confirm that says what survives.**

Save is disabled until the form is dirty, and returns to disabled after a successful save. The
plotter re-renders from the saved state, not from the form state — so what the user sees plotted is
what was persisted.

## H12 — Open/close, and the stacking rule

The plotter opens and closes. **When open it sits above everything.**

**The "Cycle length" container must never rise underneath the plotter.** It is below; it stays
below. This is a layout constraint to assert, not a visual to eyeball — the leaf-overlap suite is
the place for it, and it should be shown red first by forcing the container upward.

---

## Order

Fixes before the feature. Every one below G-block is small and mostly already measured; the plotter
is days of work and would otherwise sit on top of known-broken surfaces.

1. **H6 + the CTA gate** — remove the two calculators, gate the write.
2. **Widen the reachability check to all fifteen** — measurement only, no layout change. It
   enumerates what H1–H3 have to fix instead of leaving it to whichever screen got photographed.
3. **H1 + H2 + H3 as one pass** — one control, one measurement. Absorbs F-E and the default-size
   shears.
4. **H5** — the title out of the scrolling content, which also closes the truncating-title defect.
   Built as `DESIGN-PARITY §9` option (a), the content-area header; ~~nav-bar title~~ was struck
   2026-08-03 against a measurement. See H5.
5. **H4** — strike the disclaimer finding and its test entries. Housekeeping; do it while the
   suite is already open.
6. **H7 → H12** — the plotter, staged: selector and render first, then add, then the card and its
   history, then editing, then the collapse/stick behaviour last since it is the one that depends
   on the rest existing.

The protocol-status read (G5) is unblocked by H7's selector and drops behind the plotter.
