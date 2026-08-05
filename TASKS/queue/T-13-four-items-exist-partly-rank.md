## T-13 — Four items exist partly to rank in search; decide them together
**Priority 4/10** · **Owner:** win · **Status:** DECIDED 2026-08-05 — three ditched, one kept in filtered form

**What:** T-01a parked three — the calculator FAQ, the related-calculators carousel, the breadcrumb.
`SHELL-PARITY.md` §S-03 adds the Tools hub's per-card guide links and its "How calculators work"
FAQ. Those pages are public and indexed, so "it is for SEO" is a real argument there.

**It is not a real argument on the calendar.** `app/calendar/page.tsx:8` sets
`robots: { index: false, follow: false }`. Its "How it works" text and three citations — the 2018
Endocrine Society guideline, the WEGOVY label, a 2016 ester-pharmacology paper — cannot be for
search, because search never sees them. **That one is for the user and is being built** (T-01d #7).

**Correction to T-01a #6 while this is parked:** the carousel's contents are not "TRT EOD, TRT
Microdose". The web's own calculator navigation is TRT Dose · TRT Microdose · Semaglutide ·
Tirzepatide · HCG, then Peptide Reconstitution · Peptide Dosage · BPC-157 · BPC-157 + TB-500 Blend ·
BMI · Cycle Plotter. Take the target from the source.

**Why together:** deciding them screen by screen is how a product ends up explaining itself in three
places and nowhere.

**THE OWNER DELEGATED THIS: *"SEO is irrelevant on mobile, so you make the call — if it's not needed, ditch."* Decision below, item by item, with the reason each way.**

**1 · Breadcrumb (`T-01a #12`) — DITCH.** A breadcrumb exists on the web because a web page has no
inherent back affordance. iOS has a navigation stack and a system back button that users already
trust. It would be a second, worse back button that says the same thing.

**2 · Related-calculators carousel (`T-01a #6`) — DITCH.** Every calculator is one tap away in Tools,
which is a permanent tab. A carousel is a worse version of a surface the app already has, at the
bottom of a screen the user reached because they already knew what they wanted.

**3 · Tools guide links and "How calculators work" (`S-03 #6, #7`) — DITCH.** The guide links point at
`/guides/`, which has no iOS existence — porting them means either shipping dead links or opening a
browser out of the app. The prose is a landing-page explainer for someone deciding whether to use the
product; an app user has already decided.

**4 · Calculator FAQ (`T-01a #5`) — KEEP, FILTERED. This one is not SEO furniture and today proved
it.** The evidence is `app.js:10264`, the semaglutide FAQ, which the web itself uses to carry safety
content:

> *"…some compounders produce 2 mg/mL, 7.5 mg/mL, or 12 mg/mL formulations. … **Selecting the wrong
> concentration is the most common dosing error — it can mean you draw two or three times the
> intended dose.** … Use the Custom option if your vial doesn't match a preset."*

That paragraph was **the decisive evidence for T-45**, a real dosing defect. It names a vial the
web's own picker cannot select, states the harm in the product's own voice, and documents the escape
hatch. Deleting the FAQ as "SEO" would have deleted that.

**So the rule is not keep-or-ditch, it is a filter:** an FAQ entry survives if it states a **hazard**,
explains a **number the screen shows**, or documents **how to enter something unusual**. It goes if it
answers a question only a search engine asks — "what is a TRT calculator", "is it free", "do I need an
account".

**Same filter already applied and already correct elsewhere:** the calendar's "How it works" plus its
three citations (T-01d #7) are kept, on a `robots: noindex` page where the SEO argument never applied
— they are the only place the app explains why the schedule looks the way it does.

**Done — the four are decided. Remaining work is execution, not a decision:** mac drops items 1–3 from
T-01a and S-03, and ports the FAQ under the filter above rather than wholesale.
