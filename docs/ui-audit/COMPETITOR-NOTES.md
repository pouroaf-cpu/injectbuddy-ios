# Competitor notes — a peptide tracking app

What they do, taken from ten screenshots supplied 2026-08-01. Captures live in
`onboarding-reference/` (5) and `app-reference/` (5).

Observation only. Nothing here is scoped or scheduled.

---

## 1. Onboarding — five screens seen

One question per screen. Progress rail with a travelling dot, back chevron. Cards
carry a title and a detail line. Selected = border + fill + checkmark.

**Q. How did you hear about us?**
App Store · TikTok · Instagram or Facebook · Reddit or other forums · A friend ·
Google search · **ChatGPT or another AI** · Other

**Q. What's your main goal?**
Healing & Recovery *(recover from injury or pain)* · Healthy Aging *(maintain
health as you age)* · Weight Loss *(reduce weight and appetite)* · Energy &
Vitality *(boost energy and improve sleep)* · Cognitive Health *(improve focus
and memory)* · Appearance

**A narrative beat — no question.**
Eyebrow `DAY ONE`, headline "This is day one.", body *"This is your sky. It's a
visualization of your progress. Every week adds a new beam of light."* Continue.

**Q. Where do you get your peptides?**
503A / Compounding Pharmacy *(prescription peptides from a licensed provider)* ·
Research-Use Only *(purchased from research peptide suppliers)* · Mix *(I use
both pharmacy and research sources)* · Not sourcing yet *(I'm still researching
and haven't started)*

**Q. Do you want help connecting with a licensed provider?**
*"This is for prescriptions and monitoring. If you're interested, we'll reach out
when it's ready."*
Yes, introduce me · I already have one · No, I do my own research · Maybe, tell
me more

### What the questions are actually for

Only one of these five is product configuration. The rest are business.

- **Attribution** — "how did you hear about us" is growth instrumentation, and
  listing *ChatGPT or another AI* as its own channel says they are already
  tracking LLM-sourced acquisition.
- **Segmentation** — goal and sourcing route split the base into cohorts before
  the user has seen a single screen of product.
- **Monetisation, pre-registered** — the provider question is a referral funnel
  captured at the moment of highest intent, and *"when it's ready"* means they
  are collecting demand for something that does not exist yet. That is a cheap,
  honest way to size a feature before building it.
- **Risk posture** — asking pharmacy vs research-use tells them what proportion
  of their base is on grey-market supply. Useful for compliance and for tone.

## 2. Protocol details — a screen we do not have

- Header: back, "Protocol details", **Edit**
- Dose summary — "Each dose 100 mg"
- **Next two weeks** — a two-week day grid, S–S, with a filled circle for a dose
  day and a ring for today, plus an explicit **legend** ("Dose day" / "Today")
- **Inventory** — *Add vial* and *Add pen* side by side
- **History** — empty state *"You have no doses logged for this protocol."*
  - *Log past or extra dose*
  - *"Logging a dose from here won't change your adherence score. Use this to log
    a dose outside of your schedule."*
- **Pause** / **End**
- **Danger zone** (⚠) — *"This protocol has no logged doses, so it can be
  permanently deleted. Any vials stay in your inventory. This cannot be undone."*
  → *Delete protocol*

## 3. Log dose — far richer than ours

Context card: compound, schedule name, "100 mg Sat".

**Log details** — *"Scheduled for Today at 8:00 AM"*, then editable rows:

| Field | Value shown |
|---|---|
| Date | 1 Aug 2026 › |
| Time | 9:32 PM › |
| Dose | 100.0 mg › |
| Taken from | `None` chip — *"Log without using anything from your supply"*, plus *"You have nothing on hand for this one yet."* |

**Injection site** — with a `?` help affordance. A card per site, each showing its
state (all `New` here): Left/Right Tricep · Left/Right Love Handle · Upper
Left/Right Abdomen · Lower Left/Right Abdomen · Left/Right Glute · Left/Right
Thigh · **None**.

**Notes** — *"Anything to remember"* ›

**Skip this dose** — a first-class action, not a hidden one.

## 4. Mechanics they have and we don't

- **Adherence score.** Referenced but not seen. Scheduled-vs-logged, and they are
  careful to say when an action *won't* affect it.
- **"Your sky."** A progress visualisation that gains a beam of light per week.
  A retention mechanic dressed as a reward, introduced in onboarding before the
  user has any data.
- **Pen as well as vial.** We model `vial_inventory` only. GLP-1 users are mostly
  on pens.
- **Site rotation with per-site state.** Rotation is visible at the moment of
  choosing rather than something the user has to remember.
- **Skip as data.** A missed dose is recorded rather than absent.

## 5. Craft worth stealing regardless of features

1. **Say what survives, not just what is lost.** *"Any vials stay in your
   inventory. This cannot be undone."*
2. **Gate the destructive action on safety** — delete is offered only because
   there are no logged doses.
3. **State the consequence before the act** — *"won't change your adherence
   score"*, on the secondary path where a user would otherwise guess.
4. **Legend the chart.** Filled vs ringed, both labelled. Not colour alone.
5. **Make "none" explicit and explained**, rather than leaving a blank.
6. **Per-item state on a picker**, so a choice carries its own history.

## 6. Where they are worse than us

Not a one-way comparison.

- **Contrast fails in motion.** `onboarding-reference/ref-05` and the lower cards
  of `ref-01` are captured mid-fade and are close to unreadable. Text that passes
  at rest and fails while animating — the exact defect we measured and removed.
- **Dark-only.** No evidence of a light theme in ten screenshots.
- **Onboarding asks for business data before delivering product value.** Two of
  five screens seen are attribution and lead capture. Defensible, but it is a
  cost paid by every new user.

## 7. Our position

The schema is further ahead than the app. `dose_log` already carries `site`,
`draw_ml`, `injection_time`, `injection_timezone`, `injected_at` and
`scheduled_on`; `vial_inventory` is live. Of the eleven capabilities above,
**seven need no schema change** — only notes and skip need columns, and adherence
is a derivation.

`LogDoseSheet.swift:8` has said so in its own header the whole time.
