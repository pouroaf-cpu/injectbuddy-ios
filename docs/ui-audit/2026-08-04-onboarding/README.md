# Onboarding — the six-path walk, 2026-08-03

**`OnboardingCaptureTests/testWalkSixPaths`, `Executed 1 test, 0 failures`, 382s.** Drives
`OnboardingPreview` — no auth, no session, no network. Sources at `2ee550c`.

> ## ⚠️ THIS IS A CURATED SET: **140 FRAMES WERE TAKEN, 17 ARE KEPT.**
>
> **A curated set that does not say it is curated is a sample pretending to be a census.**
>
> The walk shot 70 early + 70 settled across six paths. Kept here: the **twelve settled frames of
> `.trt/.first`** (the longest route — all three benefit screens plus the reassurance line),
> `welcome` **early** as well as settled, and the **four frames that differ by branch**. That carries
> every claim the sweep makes and stays reviewable. The rest are reproducible by re-running.

## ⛔️ MOTION IS **NOT** VERIFIED BY THIS SWEEP, ON ANY SCREEN

**`01-welcome-early` and `01-welcome-settled` are FRAMES, NOT MOTION EVIDENCE.** A pair labelled
"early" and "settled" in an evidence folder will be read as proof of an animation by anyone who does
not read the run log. It is not.

**Two measurements, together leaving no screen where a screenshot comparison can see an entrance:**

1. **On every screen reached by a tap, the early frame is not early.** `arrive()` polls the progress
   bar to prove which screen it is, and that round-trip takes **longer than the reveal's 350ms +
   stagger**. Proving the screen consumes the window — `pathway`'s two frames are byte-identical.
2. **On `welcome` — the one screen reached by launch, where the early frame *is* early — a THIRD
   frame taken after the reveal still differs from the second** (181635 vs 181585 bytes). Something
   animates continuously: the name field is focused on appear and **the caret blinks**. So
   early-vs-settled differing there proves nothing; it would differ whether or not the reveal ran.

> ***The only screen where the early frame is provably early is the only screen with a caret on it.***

**MOTION STATUS: built, judged by eye, NOT verified by instrument.** The owner asked for text that
arrives rather than appears; we can show him that it does, and we cannot prove it with a check. Same
call as the 400ms press-feedback clause — *"not observable with the instruments we have; do not build
a harness to close it."*

**Reduce Motion is implemented and likewise unverified by instrument.** `OnboardingReveal` returns the
settled state immediately with no offset, no stagger and no fade. A Reduce Motion test was written and
**deleted**: the caret made it red on a correct build, and — worse — it would have made the normal
check green on a build that ignored the setting entirely. Verify by eye, setting and resetting in one
command.

**Two options that exist and are deliberately NOT built** (recorded so nobody re-derives them): a
noise-floor comparison — *early-vs-settled differs by much more than settled-vs-settled2* — which
needs a **threshold**, and thresholds get tuned until they stop failing; and retroactive early-frame
identification by three-way comparison, which is a harness.

## What IS asserted, on every one of the six paths

- **The route.** Every arrival proved against SPEC §3's **exact** bar percentage — 25/35/45/55/62/69/
  76/84/90/97/100. Read from `accessibilityValue`, not rendered text, so a `.uppercased()` list style
  cannot reach it. **No frame here is filed under a screen the run did not reach** — the property
  `03-calendar` lacked for two capture cycles.
- **Branch rules 1, 3 and 4, from BOTH ends.** `.adv` sees one benefit screen; the `.first`
  reassurance line is **absent** off `.first`; `＋ Add another compound` is **absent** off `.adv`.
  Rule 4's whole content is that no other level sees it — a present-only check would pass on a build
  that showed it to everyone.
- **The five personalisation placements rendering** — a name is typed on every path.
- **The loop clearing the typed name**, asserted as *the typed name is not there* rather than against
  a particular representation of empty.

## Frames

| File | What it is |
|---|---|
| `2-trt-first-01-welcome-early.png` | Screen 1, early frame. **Not motion evidence — see above.** |
| `2-trt-first-01-welcome-settled.png` | Screen 1 — the placeholder congratulation, the prompt, the name field |
| `2-trt-first-02-pathway-settled.png` | **Placement 1** — `What brings you here, Pou?` + the four cards |
| `2-trt-first-03-experience-settled.png` | **Placement 2** — the name mid-sentence in the "like a mate" line |
| `2-trt-first-04a/b/c-benefit1/2/3-settled.png` | All three benefit screens (`.first` sees three) |
| `2-trt-first-05-setup-settled.png` | **Placement 3** + the `.first` reassurance line |
| `2-trt-first-06-reminders-settled.png` · `07-inventory` | The two optional steps |
| `2-trt-first-08-firstDose-settled.png` | **Placement 4** — the name opening the line |
| `2-trt-first-09-paywall-settled.png` | **Placement 5** — the name mid-sentence |
| `2-trt-first-10a-dashboard-settled.png` | End state, accepted |
| `1-trt-adv-04a-benefit1-settled.png` | **Rule 1** — `.adv`'s single benefit screen, CTA reads `Set me up`, no Skip |
| `1-trt-adv-05-setup-settled.png` | **Rule 4** — `＋ Add another compound` up front |
| `6-skip-both-09-paywall-settled.png` | **Rule 6** — the alternate opener, both optionals skipped |
| `6-skip-both-10*-settled.png` | **Rule 7** — the end state after declining |

## Not in this set

**AX5.** This is the default-size walk. `setup` is already recorded as failing D5's second half at
AX5 (`SPEC-ONBOARDING` §7) and that is unchanged by this run.

**The congratulation line and the art are placeholders and are drawn as placeholders** — deliberately,
so a screenshot cannot be mistaken for finished copy. Two dashed warning boxes on screen 1 is correct
until the owner writes the line and the art lands.

**Every named string is ⚠️ PROPOSED** and awaits the owner's voice. The *nameless* form of all six
pairs is his existing copy byte-for-byte.
