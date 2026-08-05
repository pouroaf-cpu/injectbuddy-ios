## T-35 — A collapsed control publishes its own glyphs as overlapping leaves
**Priority 3/10** · **Owner:** mac · **Status:** open

**What:** `Combobox` and the pinned result bar both publish an accessibility element that is a
`StaticText` spanning the WHOLE control, **and** their child glyphs as separate leaves inside it.
Measured on `Steroid Dosage` at AX5:

```
StaticText 'Oxandrolone (Anavar)' (16.0, 337.7, 370.0, 265.3)   ← the whole combobox face
Image     'magnifyingglass'       (38.0, 444.7,  50.7,  51.3)
Image     'chevron.down'         (326.0, 459.0,  38.7,  22.7)
StaticText 'Show result'          (16.0, 506.3, 370.0, 153.3)   ← the whole pinned bar
Image     'mark_see_result'       (89.3, 560.7,  71.0,  45.0)
```

`LeafOverlapUITests` calls those three pairs overlaps. **Nothing draws on anything** — the magnifier
sits left of the value, the chevron right of it, both inside the chrome.

**What was tried and did not work,** so nobody repeats it: `accessibilityHidden(true)` on each
glyph; `accessibilityHidden(true)` on the whole face; `accessibilityElement(children: .ignore)` on
the button above them. All three are in place and all three leave the glyphs in the snapshot — they
even carry SF Symbol default labels (`Search`, `Go Down`). **The automation snapshot is not the
VoiceOver tree.** VoiceOver reads one element; XCUITest sees four.

**Why it is not "just delete the magnifier":** it is the web's, it is half of what makes the field
read as searchable (T-01a #2), and it is not what is wrong. The suite's own reasoning — *"a
container is never a leaf"* — is what does not hold here: the container collapsed INTO a leaf.

**Done when:** either the suite stops counting a leaf against the husk its own siblings collapsed
into (probably: a leaf wholly inside another leaf that carries no text of its own is not a second
thing), or SwiftUI is made to publish one element — with the fix shown to work on a real frame, not
assumed. The three entries in `expectedOverlaps` naming T-35 go with it; they are asserted from both
ends, so they will go red the day this is fixed.
