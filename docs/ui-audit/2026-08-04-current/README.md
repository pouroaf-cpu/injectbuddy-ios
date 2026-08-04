# 2026-08-04 — the current frame set

**89 frames. Every screen a user can reach, plus the whole onboarding flow, all
photographed on the device in two runs at one build.**

| | |
|---|---|
| Device | iPhone 16 Pro `1481D20C`, iOS 18.3 |
| Content size | `large` (default) — **asserted from the gate probe before the first frame**, not assumed |
| App set | 19 frames, `CaptureCurrentState.testCaptureFullDefaultSweep` |
| Onboarding | 70 frames, `OnboardingCaptureTests.testWalkSixPaths`, in `onboarding/` |
| Gate reading | `ax=false size=large cap=0.0000 forcedPinned=false area=690.67 bar=200.00 share=0.2896` |

## What build this is, and why that needs saying

`HEAD` was **`d0da759`** and **the working tree was dirty**. These frames are of a
build that is not in git history:

- **T-01c / T-01d / T-54 in progress** — `ShellHeader.swift`, `DashboardWeek.swift`
  and `SiteRotationCard.swift` are new and untracked; `DashboardScreen`,
  `DashboardViewModel`, `DashboardComponents`, `CalendarScreen`,
  `CalendarViewModel`, `DrawerView` and `RouteContent` are modified.
- Working-tree fingerprint: **`893bfea6483e`**
  (`sha1` of `git diff HEAD` plus every untracked file under `Sources/` and `Tests/`).

That fingerprint is here because "2026-08-04" names a day and a day held several
builds. If a frame here has to be argued about later, the fingerprint is what
says which code produced it. `02-dashboard.png` shows the new header, the
seven-day strip and the site-rotation card — none of which exist at `d0da759`.

## What is in the app set

`02` dashboard · `03` calendar · `04` tools · `05` add · `08` log-dose sheet ·
`06`/`07`/`11` TRT at rest, scrolled to the barrel row, and with the keypad up ·
then every listed calculator: `16` HCG, `17` peptide, `18` reconstitution,
`19` semaglutide, `20` tirzepatide, `21` retatrutide, `22` BPC-157,
`23` BPC+TB500, `26` TRT microdose, `27` cycle plotter, `28` steroid dosage.

Every shell frame and every calculator frame asserted its own arrival before the
shutter — the tab's destination proof, or the navigation-bar title. No frame here
was taken on trust.

### `15-calculator-eod` is gone, and that is the finding

The first run of this sweep **died** on *"TRT & EOD never became hittable after 12
scrolls"*, eight frames in. That was checked before the list was touched, because
a failing probe and a missing feature read identically:

`CalculatorSlug.isCollapsed` is `true` for `.eod` (T-12) and `isListed` is
`!isWithdrawn && !isCollapsed`, so `members` drops it at the source and no browse
surface enumerates it. **The scroll could not find the row because the row is not
there.** The entry is removed from the sweep with that reasoning recorded at
`CaptureCurrentState.swift`.

This is *not* the same state as BMI and Free T Index, which are **withdrawn** —
screen, spec, category and engine all intact. `.eod` is **collapsed**: no
category, no route, nothing to restore. So it could not be repaired by routing
around Tools the way `Cycle Plotter` was; there is no screen at the end of that
route. `15-calculator-eod.png` in `2026-08-04-post-t01a` is left alone — it is
evidence of a build that shipped.

Listed calculators are now twelve, and the twelve frames above are all of them.

## What is in `onboarding/`

Six paths × every screen on that path, **settled frames only**:

| Path | Screens |
|---|---|
| `1-trt-adv` | 10 — `.adv` sees ONE benefit screen (rule 1) |
| `2-trt-first` | 12 |
| `3-glp-some` | 12 |
| `4-aas-some` | 12 |
| `5-other-some` | 12 |
| `6-skip-both` | 12 — ends on `10b-locked`, the declined-paywall state |

Each arrival was proved against the progress bar's exact percentage
(25/35/45/55/62/69/76/84/90/97/100), so a frame cannot be filed under a screen the
walk never reached. Branch rules 1, 3 and 4 were asserted from both ends, and the
loop back to screen 1 was verified to clear the typed name.

**The `-early` frames are deliberately not copied here.** The sweep's own coverage
note is that motion is not measurable by screenshot comparison anywhere in this
flow — on tapped screens the arrival proof consumes the reveal window, and on
`welcome` a blinking caret makes any two frames differ. Both frames are artefacts;
the settled one is the one to look at. Keeping 70 of the 140 is that statement,
not a saving.

Shot against `OnboardingPreview` (`com.injectbuddy.ios.onboardingpreview`), which
is a real app on the real device — no auth, no session, no network.

## What is NOT here, and both are decisions

- **The drawer and Settings.** They render the account's real email and avatar,
  and these frames go into a chat window. The standing decision is not to capture
  more of them. The one exception already made is
  `launch/screenshots/review-0{1,2}`, cropped on the host and declared as cropped,
  because App Review needs the deletion path shown.
- **The signed-out / welcome path.** Recovering it costs the Keychain session and
  a real sign-in — `simctl erase` is the only way back, and this simulator has
  never been erased.

If either is wanted, say so: the drawer and Settings need a masking decision made
first, not a capture.

## One open finding visible in this set

`28-calculator-steroid.png` — the disclaimer *"Maths only — not medical advice."*
sits at y 798.67–812.00 with the pinned region starting at y 591.00, so the tab bar
covers it by 175.3 × 13.3pt. That is F-F, struck **won't fix** by the owner (H4).
Measured and reported, not asserted. Every other calculator's disclaimer is below
the fold at rest and is not occluded by anything.
