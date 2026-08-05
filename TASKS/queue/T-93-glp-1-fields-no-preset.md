## T-93 — The GLP-1 fields have no preset chips, and the web's computed ones are not portable
**Priority 2/10** · **Owner:** mac · **Status:** open

**What:** T-45 gave the GLP-1 `conc` and `dose` fields the ruler and typed entry but left `quick: []`
— no one-tap chips, where TRT's weekly dose has `[100, 200, 300, 400, 500]`. So the commonest
concentrations (5, 10, 12.5) take a keystroke rather than a tap.

**Why the web's own chips were NOT ported.** On `feature/dosage-status-model`, `QuickPickerField`
DERIVES its ladder — `[1,2,3,4,5].map(i => snap(max * i / 5))` — which for `GLP1_CONC_VALUES` yields
**12 · 24 · 36 · 48 · 60 mg/mL** and for tirzepatide's dose yields **7.5 · 16.25 · 23.75 · 32.5 · 40
mg**. Those are arithmetic on the array's maximum, not clinical values, and half of them are
strengths and doses nobody holds. Shipping them verbatim would have put a misleading one-tap row on
a dosing screen in the name of parity; inventing a better row is a design decision that belongs to
the owner, not to a defect fix. So neither was done, and the reason is written down here rather than
left as an empty array someone later reads as an oversight.

**Also note** the deployed build has no chip row on these fields at all — it renders a `DrumPicker`
plus an exact-entry box — so "the web has chips here" is only true on the unmerged branch.

**Done when:** either a chip row is specified by the owner and built, or this is closed as
deliberately absent with the deployed build cited.


---

**T-22 closure note (win, 2026-08-04).** Fixed in `eb2a5b1d`. `DashLogFlow.tsx:106` now passes
`amount` to `markDone`; `DashboardContext.tsx:399,404` write `drawMlFor(ev, amount)` and
`doseLabelFor(ev, amount)` instead of the plan.

**The two clients agree, derived independently, which is the part worth keeping.** iOS computed
`12.75` over a `74.5 mg` plan as `12.75 ÷ 200 = 0.064 mL`. The web reaches `0.064` by a different
route — `0.373 × (12.75 ÷ 74.5)`, scaling the planned volume rather than recomputing from strength.
Two implementations, neither having seen the other, same number. A cross-check is worth more than
either side testing itself twice.

**One deliberate narrowing:** `draw_ml` scales only for a bare number. `0.5 mL` typed against a
`74.5 mg` plan is a volume, not a dose, and scaling it would write `0.0025 mL` — a dosing app must
not compute through an ambiguous unit. The label takes what the user said; the volume stays planned.
