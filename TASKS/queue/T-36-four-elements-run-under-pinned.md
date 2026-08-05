## T-36 — Four elements run under the pinned result bar on Steroid Dosage at AX5
**Priority 6/10** · **Owner:** mac · **Status:** open

**What:** measured by `LeafOverlapUITests/testSteroidDosage` at AX5, at rest, once T-34 stopped
hiding it. The pinned bar's own frame is `(16.0, 506.3, 370.0, 153.3)`, and running under it:

```
StaticText 'Oxandrolone (Anavar)' (16.0, 337.7, 370.0, 265.3)  shares 370.0 x  96.7
StaticText 'Vial strength'        (24.0, 644.3, 140.3, 156.7)  shares 140.3 x  15.3
TextField  'field_strength'      (196.3, 635.0, 173.7,  65.0)  shares 173.7 x  24.6
```

and `Vial strength` carries on down into the tab bar (`house.fill`, `calendar`), while
`unit_strength` grazes the raised hero by 0.7pt.

**Why it matters:** `field_strength` is the vial concentration — the number every dose on this
screen is divided by. UX-UI-RULES §2: *"Nothing a user acts on may sit under pinned furniture."*
§3 makes reachability at every supported text size binary.

**How it relates to T-20:** same family, different size and different depth. T-20 is one row
straddling the plate's edge at DEFAULT size; this is four elements deep at AX5, including the input
itself and its unit. They should be fixed together at the shared control, and T-20's "done when"
already asks for the form's bottom inset to be measured rather than guessed.

**Why it is only now visible:** T-34. This suite has run on this screen before and reported one pair
each time.

**Done when:** at AX5 on `Steroid Dosage`, no input, unit or label shares pixels with the pinned
bar, the tab bar or the hero — with the five `expectedOverlaps` entries naming T-36 deleted, not
suppressed. Re-checked on one calculator outside the top five, since the bar is shared.
