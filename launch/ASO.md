# InjectBuddy iOS — App Store Optimisation (ASO) Pack

Internal planning doc. Copy the chosen strings into App Store Connect. Character limits are
App Store hard limits — counts below are verified against the strings as written.

---

## 1. App name / Title (≤30 chars)

App Store **Name** (the bold line under the icon). Pick one:

| # | Title | Chars | Note |
|---|-------|-------|------|
| **A (recommended)** | `InjectBuddy: TRT & Peptide` | 26 | Brand + two top intents |
| B | `InjectBuddy TRT Calculator` | 26 | Leads brand, packs "TRT calculator" |
| C | `InjectBuddy: Dose Calculator` | 28 | Broadest, weaker keyword |

> Apple counts the brand-only name ("InjectBuddy", 11) against the same field; A/B spend the rest
> on the strongest keywords. The **Name** field is the single highest-weight ASO surface — keep
> "TRT" and/or "Calculator" in it.

## 2. Subtitle (≤30 chars)

| # | Subtitle | Chars | Note |
|---|----------|-------|------|
| **A (recommended)** | `Peptide & GLP-1 dose planner` | 28 | Covers peptide + semaglutide/tirz audience |
| B | `Reconstitution & cycle tool` | 27 | Hits "reconstitution" + cycle planner |
| C | `TRT, peptide & GLP-1 dosing` | 27 | Pairs with Title B (which omits peptide/GLP-1) |

> Do not repeat words already in the Name (Apple de-duplicates). If Title = A ("TRT & Peptide"),
> use Subtitle B or C to add "reconstitution", "cycle", "GLP-1". If Title = B, use Subtitle A.

## 3. Keyword field (≤100 chars, comma-separated, no spaces)

Rules: no spaces, no plurals you can avoid (Apple stems), do NOT repeat words from Name/Subtitle,
single words combine into phrases automatically (e.g. "trt"+"calculator" → "trt calculator").

**Recommended (paired with Title A + Subtitle B):**
```
testosterone,semaglutide,tirzepatide,retatrutide,bpc157,hcg,injection,steroid,cycle,bmi,trt,reconstitution
```
Char count: 97 / 100.

**Alternative (paired with Title B "TRT Calculator" + Subtitle A):**
```
testosterone,semaglutide,tirzepatide,retatrutide,bpc157,hcg,injection,steroid,reconstitution,microdose,trt
```
Char count: 99 / 100.

Notes:
- Omit "calculator", "peptide", "dose", "GLP-1" from this field **only if** they already appear in
  Name/Subtitle (they do in the recommended pairing) — don't waste the 100 chars on duplicates.
- "bpc157" with no hyphen/space matches "bpc 157" and "bpc-157" searches.
- Avoid drug brand names (Ozempic, Wegovy, Mounjaro) — trademark risk in metadata; cover them in
  the description body instead, factually.

## 4. Promotional text (≤170 chars, editable anytime without review)

> `14 dosage calculators for TRT, peptides and GLP-1s, plus a cycle planner. Reconstitution, draw volumes and IU on a U-100 syringe — instant, offline maths.`

Chars: 153 / 170.

## 5. App Store description (long-form)

```
InjectBuddy turns your prescribed numbers into exact draw volumes — in seconds, offline,
on your phone. Built for people on TRT, peptide and GLP-1 protocols who are tired of doing
reconstitution maths by hand.

Lead with the result. Enter your vial concentration, BAC water and target dose; InjectBuddy
shows the mL to draw and the units on a U-100 syringe, with the injection schedule laid out.

— 14 CALCULATORS —
• TRT Dose — ester, concentration, weekly dose → mL per injection + IU + schedule
• TRT (EOD) — every-other-day testosterone dosing
• TRT Microdose — daily / micro-shot volumes
• HCG — vial IU, BAC water and dose → units to draw
• Peptide Dosage — mcg dose → units on a U-100 syringe
• Reconstitution — vial mg + BAC water → concentration and draw
• Semaglutide — weekly GLP-1 dosing in units
• Tirzepatide — weekly dosing in units
• Retatrutide — weekly dosing in units
• BPC-157 — peptide units to draw
• BPC-157 + TB-500 blend — two-compound draw
• BMI — body mass index + WHO category
• Free-T Index — total T and SHBG → free-testosterone estimate
• Cycle Plotter — multi-compound timeline you can plan and visualise

— CYCLE PLANNER —
Save your protocols and see them as a dashboard: next dose with a countdown, a weekly
timeline, and your week-at-a-glance totals. A 30-day injection calendar projects every due
date from your protocol frequency, and you can mark doses as taken to keep an accurate log.

— WHY INJECTBUDDY —
• Offline maths — every calculation runs on-device; nothing about your dose is sent anywhere
  to be computed.
• Sync across devices — your saved protocols and logs are tied to your account, so they
  follow you. Companion to injectbuddy.com.
• Clean, fast, no clutter — the app opens straight into your planner, not a marketing page.
• No tracking — InjectBuddy does not include any advertising or analytics tracking SDK.

— IMPORTANT —
InjectBuddy is an informational maths tool, not medical advice. It converts numbers you
already have into draw volumes; it does not decide what your dose should be. Prescription
medication must be used as directed by a licensed prescriber. Always verify any result with
your doctor or pharmacist.

An account is required so your protocols and logs sync securely to your devices.
```

## 6. "What's New" — v1.0

```
First release of InjectBuddy for iOS.

• All 14 dosage calculators — TRT, peptides and GLP-1s — with instant, offline maths
• Cycle planner dashboard: next dose, weekly timeline and totals
• 30-day injection calendar with dose logging
• Save and sync your protocols to your account
• Light and dark themes

Questions or a calculator you want added? Email support@injectbuddy.com.   <<CONFIRM: support email>>
```

## 7. Competitor / keyword note

- **Web is the anchor.** injectbuddy.com already ranks for TRT/peptide/GLP-1 calculator terms
  (the legacy site targets "TRT calculator", "semaglutide calculator", "reconstitution calculator",
  etc.). The app should mirror that vocabulary so brand searches ("injectbuddy") and the strong
  generic terms reinforce each other. Brand search for "injectbuddy" is the easiest win — make sure
  the Name field carries it.
- **Category landscape (App Store):** the niche has a few players — generic "peptide
  reconstitution calculator" and "TRT calculator" utilities exist, but most are thin single-function
  calculators with weak metadata and no cycle planner. <<CONFIRM: run a manual App Store search for
  "TRT calculator", "peptide calculator", "reconstitution" and "semaglutide" before launch to snapshot
  the current top 3 per term — these shift.>>
- **Winnable terms:** long-tail and compound queries where incumbents are weak —
  "reconstitution calculator", "peptide dose calculator", "BPC-157 calculator", "tirzepatide units",
  "retatrutide dose", "TRT microdose". "retatrutide" in particular is newer and low-competition.
- **Harder / saturated:** single-word "BMI" and broad "semaglutide" (brand-name medical apps
  outrank). Don't lead with these; let them ride as secondary keyword-field terms.
- **Category pick:** **Medical** (primary) is the honest fit for a dosage tool and aligns with the
  1.4.1 positioning in APP-REVIEW-NOTES.md; **Health & Fitness** as secondary if a secondary category
  is offered. <<CONFIRM: final category choice.>>
```
