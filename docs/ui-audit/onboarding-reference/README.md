# Onboarding reference — a competitor's peptide app

Supplied by the human 2026-08-01 as "some other apps start up screens". This is
the *feel* to aim for. Read it with `docs/WELCOME-AND-ONBOARDING.md`.

| File | What to take from it |
|---|---|
| `ref-01-question-cards-plain.png` | One question per screen, plain option cards |
| `ref-02-question-cards-with-detail.png` | Cards with title **and** detail line; selected = border + fill + **checkmark** |
| `ref-03-narrative-payoff-beat.png` | A non-question screen mid-flow — a reward beat, not another form |
| `ref-04-two-line-question.png` | Question wrapping to two lines without cramping |
| `ref-05-midtransition-fade.png` | Captured mid-fade — see the contrast warning below |

---

## Take this

1. **One question per screen.** The single biggest improvement over the PWA's
   five dense steps. A screen asks one thing, in a large light-weight title,
   left-aligned, with room around it.
2. **Progress as a rail with a travelling dot**, not a row of pips. Back chevron
   sits beside it. Reads as distance covered rather than forms remaining.
3. **Option cards with a title and a detail line.** We already have this copy —
   `INTEREST_LABELS` in `PersonalisationForm.tsx:19` carries exactly this shape
   ("Hormones" / "TRT, HRT and supporting protocols"). It is currently unused on
   iOS.
4. **Selected state = border + fill + checkmark.** Three signals, not one. Note
   this already satisfies our no-colour-alone rule — the reference does it right.
5. **A narrative beat between questions** (`ref-03`). Breaks the form rhythm and
   is where a product earns "beautifully designed" rather than "well laid out".
6. **Ambient motion** — slow drifting particles, a soft directional glow. Present
   but never competing with the text.

## Do NOT take this

**The dark theme.** Every reference is dark. InjectBuddy iOS is **light-only** —
that was a deliberate decision this session, `UIUserInterfaceStyle: Light` is
locked in `project.yml`, and all dark code paths were removed. The *structure*
transfers; the palette cannot.

Light equivalents, all from `DESIGN-PARITY.md §8`:

| Reference | InjectBuddy light |
|---|---|
| dark card on near-black | white card on canvas `#FAFAFB`, 1 pt `#8E8E93`, r16 |
| brighter fill + white border when selected | `#EAFAF8` fill + `#0FBCAD` border + `#075E56` check |
| white title | navy `#001D5C` |
| grey detail line | `#101018` at secondary weight — **measure it** |
| white progress rail | navy rail, teal travelling dot |
| glow / beam | teal at low opacity, or drop it |

**Do not reintroduce a dark screen "just for onboarding".** A light app with one
dark screen is not a style choice, it is a bug report waiting to happen.

## The contrast warning, from the references themselves

`ref-05` and the lower cards in `ref-01` are captured **mid-fade** and are close
to unreadable — the "Other" and "ChatGPT or another AI" rows, and every line in
`ref-05`. That is the exact failure this spec already warns about: *text that
passes at rest and fails while it animates*.

The reference apps ship it. We are not going to. Measure the animated text at
several points through the transition, not only at its final state.

## Scope tension — raise it, don't resolve it silently

The reference asks things InjectBuddy's PWA does not: how you heard about us,
where you source peptides, whether you want a provider introduction. Those are
acquisition and monetisation questions.

The human's instruction was **"we have this on the webapp so keep it the same"**.
Adding questions breaks that parity, needs new `profiles` columns, and puts iOS
ahead of the web in a way the web then has to catch up to.

**Recommendation: keep the PWA's five data points, adopt this app's
presentation.** That is where the quality gap actually is — the reference does
not collect better information, it asks for the same kind of information far
better. New questions are a separate product decision for the human.
