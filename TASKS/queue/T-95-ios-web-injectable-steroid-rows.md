## T-95 — iOS and web injectable steroid rows can never dedup, because `tab` differs when untouched
**Priority 4/10** · **Owner:** mac · **Agent:** — · **Status:** filed

**What:** the saved steroid config carries the oral trio (`dose`, `tab`, `split`) even on an
INJECTABLE save, because the web saves all 13 keys whatever form is showing. Untouched, the web's
`tab` is `String(defTab)` — `"10"`, or `"50"` on Anadrol (`app.js:8798, 8811`). **iOS writes `""`.**

**What it costs:** the database de-duplicates on the WHOLE config, so an iOS injectable steroid row
and the equivalent web row are different protocols and always have been. Saving the same protocol on
both clients yields two rows.

**Why it is FILED and not open — this is a data decision, not a code tidy.** Changing `""` to
`"10"` re-fingerprints **every future injectable steroid row** against production rows already
written with `""`. That belongs to the owner and in daylight, not inside a commit about option
lists. Same reasoning that left the 3-vs-6 config split alone under T-45.

**Found by:** agent `t44-steroid`, reported and deliberately not taken.

**Done when:** the owner rules on whether iOS adopts the web's untouched defaults, and either the
change lands with the re-fingerprinting acknowledged, or it is recorded here that iOS keeps `""`.
