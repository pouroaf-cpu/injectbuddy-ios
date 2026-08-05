## T-19 — Eight calculators the web has and iOS does not
**Priority 5/10** · **Owner:** pouroa · **Agent:** — · **Status:** HELD

**OWNER'S DECISION 2026-08-05: do not add these. "I don't want them in yet."** Not a deferral for
capacity — an explicit hold. **Do not build them, and do not spec them either**: a spec written now
would be a spec written against a web that will have moved by the time they are wanted, which is how
the 2026-07-31 captures became the third-best source in a week.

A spec pass was started on this and **stopped mid-run** the moment the instruction arrived. Nothing
was added to the app and nothing is half-built.

**Still true and still worth keeping** — the eight are `femalehrt`, `ftv`, `reverse`, `blend`
(saved as `oilblend`), `glp1titration`, `nootropic`, `bioavailability`, `e2estimator`.

**Two of them already exist as DATA even though they do not exist as SCREENS**, which is the thing to
remember if this unparks: `femalehrt` has 2 active rows and `oilblend` 1, across 2 real users. Those
were the protocols invisible on their own dashboards until T-57. So the web can already create rows
of types iOS cannot open — **the absence of the screen is not the absence of the data.**

**Same shape as T-12's EOD decoder, and worth naming as a pattern rather than a coincidence:** a
missing SCREEN is a display problem; a missing DECODER is a data problem. iOS keeps `CalculatorSlug`
cases for types it cannot render precisely so a web-created protocol still decodes, schedules and
shows. `femalehrt` and `oilblend` are the same situation one step earlier — the rows exist and iOS
has neither screen nor slug.

**Done when:** the owner asks for them.


**What:** the reference set and the live site carry eight calculators with no iOS counterpart —
**ftv** (42), **reverse** (43), **blend** (44), **glp1titration** (45), **femalehrt** (46),
**nootropic** (47), **bioavailability** (49), **e2estimator** (50). `public/legacy/` confirms them
as real pages: 21 calculator directories against the 15 slugs `CalculatorSlug` defines.

**Why it is filed separately from T-01b rather than inside it:** T-01b is "compare each screen and
list its differences". These have no iOS screen to compare — they are absent features, the same
category as progress, cycle planner, blood tests, chat, suggestions and the peptide tracker. Putting
them in a difference list would make eight missing products look like eight layout notes.

**The standing decision points one way and the effort points the other**, which is why this is the
owner's: *iOS matches the web in every way it can, nothing dropped for being hard.* Eight new
calculators is not a parity pass, it is a roadmap.

**Done when:** the owner rules on each — built, or recorded here with the reason it will not be.
