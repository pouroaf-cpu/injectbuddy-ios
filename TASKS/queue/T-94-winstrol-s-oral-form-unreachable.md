## T-94 — Winstrol's oral form is unreachable on iOS
**Priority 3/10** · **Owner:** mac · **Agent:** — · **Status:** open

**What:** Winstrol is the ONLY compound in `IB_STEROIDS` marked `'oral|injectable'`, and the web
gives it a Form toggle for exactly that reason (`app.js:8944`, rendered only when
`canInject && canOral`). T-44 made the form follow the compound's class, which is right for the
other eleven; Winstrol gets `injectable`, the form the web itself opens it on. **Its oral tablet
path cannot be reached on iOS at all.**

**Why it is a 3 and not higher:** the web opens it on injectable too, so the default agrees and
nobody sees a wrong number — the capability is absent, not incorrect. `steroid 5` is also the
smallest cohort in production.

**Found by:** agent `t44-steroid` while building T-44, reported rather than taken because a Form
toggle is a new control and T-44's scope was the oral/injectable split.

**Done when:** a compound that is both oral and injectable offers the choice, defaulting to the
form the web defaults to, and the toggle is photographed on Winstrol.
