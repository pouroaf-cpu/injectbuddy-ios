## T-32 — Protocols the iOS plotter has no compound for
**Priority 4/10** · **Owner:** mac · **Status:** open

**What:** `PlotterCompound.all` is transcribed verbatim from `PLOTTER_COMPOUNDS` in `app.js` — 27
entries. The web plotter's own `COMPOUNDS` table has since grown past it, and T-17's handoff is
where the gap becomes visible: a protocol the user can build in an iOS calculator, and which the
web would plot, cannot be plotted on iOS at all. Measured against `mapDosage`'s tables:

- **Two of the seven esters.** `Testosterone Acetate` → `test-a` and `Sustanon 250` → `sustanon`
  are in `ESTER_TO_CID` and in neither iOS list. A TRT protocol on either seeds nothing and opens
  the plotter empty. Asserted from both ends in `PlotterSeedTests.test_theTwoUnplottableEsters` —
  the two named must NOT seed, the other five MUST.
- **HCG.** The web maps it to a compound id `hcg`; iOS has no such entry. `hcg` is one of the
  eleven calculators that shows the levels link.
- **The whole steroid set.** `STEROID_TO_CID` names `masteron-p/e`, `nandrolone-d`, `boldenone`,
  `methenolone-e`, `anavar`, `dianabol`, `winstrol-o` — none of which iOS has, though iOS's list
  does carry `mast-p`/`mast-e`/`deca`/`eq` under DIFFERENT ids. The steroid calculator does not
  show the levels link today, so this is latent rather than live.

**Why it is filed rather than fixed here:** a compound is a HALF-LIFE and a tmax, and the web's own
note refuses to invent them — *"a PK curve IS a half-life; with no credible one there is no honest
curve to draw"*. Adding entries means sourcing those numbers, and a wrong one draws a confident
wrong curve. It is also not a blocker: T-17 refuses cleanly, so the affected protocols open the
plotter unseeded rather than plotting the wrong molecule.

**Done when:** each gap is either given a compound with a sourced half-life and tmax, or recorded
here as deliberately unplottable with the reason — and `test_theTwoUnplottableEsters` /
`test_theEsterTableNamesRealCompounds` updated to match, since both are written to go RED the day
the catalogue changes under them.
