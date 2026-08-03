# Current state — 2026-08-02

iPhone 16 Pro, iOS 18.3, light, sRGB, unscaled. Every frame carries a serial and a
row in `../SCREENSHOT-LOG.md`.

## The default-size set is ONE RUN AT ONE SHA

**`IB2245754`–`IB2245775`, captured `9b4afcb`, 04:42–04:53 PDT, in a single
`testCaptureFullDefaultSweep` run.** That property is the point of this pass, not a
detail of it.

**What it replaces was internally inconsistent.** `02`–`05` and `08` were shot at
10:38 the previous day — *before* the measured pinning gate, before the material,
before the type scale landed in its final form — while `06`/`07`/`11` came from
after. A folder named "current state" was holding **two different builds
photographed an hour apart**. That is §5.31, a name outliving its content, pointed
at the folder the consistency check exists to protect.

**The rig size is now asserted, not assumed.** `bar_gate` published `ax=true/false`,
which reads identically at `large`, `xLarge` and `xxxLarge` — so nothing in the
harness could tell the default size from a merely-non-accessibility one, while every
filename in a default sweep asserts "default" in its name. The probe now publishes
`size=<category>` and the run fails before writing a single frame unless it reads
`size=large`.

**Each frame asserted its own destination before it was written**, on the navigation
bar title — a check shown red first, by poisoning it to expect `Reconstitution` after
tapping `TRT Dose`. All 27 files in this folder are distinct by md5.

The five AX5 frames (`09`, `10`, `12`, `13`, `14`) are **not** superseded by this
pass — they are a different type size and are the only large-text evidence there is.

## ⛔️ THREE FRAMES IN THIS FOLDER ARE PHOTOGRAPHS OF THE WRONG SCREEN

**Recorded 2026-08-03. Kept, not deleted** — deleting them would lose the record that the harness had
this defect, which is now the more useful thing.

| File | What it is NAMED | **What it ACTUALLY SHOWS** |
|---|---|---|
| `03-calendar-IB2245755.png` | Calendar | **The DASHBOARD, mid-fade.** `Hello, devtools.` ghosted under the arriving `Calendar` title, the Next dose card with `Mark taken`, the `PROTOCOLS` list, and a `Loading…` spinner. **There is no calendar grid in the frame.** |
| `04-tools-IB2245756.png` | Tools | **The CALENDAR, mid-fade**, with the Tools list ghosting in behind it. ⚠️ **That ghost is a PRE-H6 Tools list — `BMI` and `Free T Ind…` are legible in it.** A reader checking the H6 withdrawal against this frame would conclude it never happened. It is a ghost bleeding through a transition, not a photograph of Tools. |
| `05-add-IB2245757.png` | Add | **TOOLS, mid-fade**, with the Add screen ghosting in (`…ARE YOU ADDING?`, the four category rows, the footer sentence). |

**None of the three is evidence about the screen it is named for.** Nothing in this folder has ever
shown the Calendar, and nothing named `04-tools` has ever shown Tools.

**The cause, and it is why the set reads as coherent.** `shot()` fires during the cross-fade after
`tab()`, so every shell frame lands one screen behind — **the outgoing screen is SHARP and the
destination ghosts in.** So each frame is a good, well-rendered photograph of a real screen, filed
under the next screen's name.

> ***It is not blurry, it is MISFILED*** — and misfiled evidence is the harder failure, because
> nothing about the image looks wrong. That is why three frames survived two capture cycles and only
> one of them was ever noticed.

It reproduces — the same defect is in a run on 2026-08-03. The `04-tools` case was already filed at
`BATCH.md:162` ("the `04-tools.png` Calendar-under-a-Tools-label frame"); **`03-calendar` and
`05-add` were not, until now.**

> **One accidental use, stated because it is load-bearing elsewhere.** `05-add`'s *foreground* is a
> sharp, complete photograph of the Tools list — so it is a **better** photograph of Tools than
> `04-tools` is. **`BMI` and `Free T Index` are absent from it**, in the `TESTOSTERONE & HORMONES`
> section, which is complete and unscrolled in that frame — the same section the `04-tools` ghost
> shows them in at 08-02. That is H6's withdrawal, visible. **The frame is cut off after
> `BPC+TB500`, so it speaks for three sections and not for anything below them.**

> **Why no existing check caught it, and this is the transferable part.** `shot()` fails a frame that
> is **byte-identical** to a previous one. A mid-transition frame is byte-identical to *nothing* — so
> it passes every check that looks for repetition **while being a photograph of a different screen**.
> **Repetition-detection cannot detect wrongness.** The fix is an identity assertion — assert the
> destination's own content is on screen before the shutter — not a settle-wait, which is a guess
> that gets tuned until it stops failing.

**One citation rests on `04-tools` and is corrected rather than re-opened:** `SCREENSHOT-LOG.md:65`
reads *"`Cycle Plotter` is absent from it"* off this frame. **The claim has an independent source in
the same sentence** — `CalculatorCategory.members` enumerating 14 of 15 slugs with `.cyclePlotter` in
none, which is a code reading rather than a frame. **Strike the frame, keep the enumeration.**

**H6 does not rest on either frame.** It was confirmed on the device by two independent suites.

## Frames

| Serial | File | Screen |
|---|---|---|
| IB2245754 | `02-dashboard-IB2245754.png` | Dashboard |
| IB2245755 | `03-calendar-IB2245755.png` | ⛔️ **NOT THE CALENDAR — see the warning below.** |
| IB2245756 | `04-tools-IB2245756.png` | ⛔️ **NOT TOOLS — see the warning below.** |
| IB2245757 | `05-add-IB2245757.png` | ⛔️ **NOT ADD — it is TOOLS. See the warning above.** |
| IB2245758 | `08-logdose-sheet-IB2245758.png` | Log-dose sheet |
| IB2245759 | `06-calculator-trt-IB2245759.png` | TRT Dose, at rest |
| IB2245760 | `07-calculator-barrel-row-IB2245760.png` | TRT Dose scrolled to the barrel row |
| IB2245761 | `11-calculator-keyboard-toolbar-IB2245761.png` | TRT Dose, weekly dose focused, keypad up |
| IB2245762 | `15-calculator-eod-IB2245762.png` | **TRT & EOD — first capture ever** |
| IB2245763 | `16-calculator-hcg-IB2245763.png` | **HCG — first capture ever.** Clean at this size |
| IB2245764 | `17-calculator-peptide-IB2245764.png` | **Peptide — first capture ever** |
| IB2245765 | `18-calculator-reconstitution-IB2245765.png` | **Reconstitution — first capture ever.** Carries F-F, and the disclaimer is not visible anywhere in the frame |
| IB2245766 | `19-calculator-semaglutide-IB2245766.png` | **Semaglutide — first capture ever.** `Units (U-100)` sheared by the plate at DEFAULT size |
| IB2245767 | `20-calculator-tirzepatide-IB2245767.png` | **Tirzepatide — first capture ever** |
| IB2245768 | `21-calculator-retatrutide-IB2245768.png` | **Retatrutide — first capture ever** |
| IB2245769 | `22-calculator-bpc157-IB2245769.png` | **BPC-157 — first capture ever.** Disclaimer at y 841.67, inside the tab bar's region |
| IB2245770 | `23-calculator-bpc157blend-IB2245770.png` | **BPC+TB500 — first capture ever. AN INPUT IS SHEARED BY THE PLATE AT DEFAULT SIZE**, with `Add` enabled below it |
| IB2245771 | `24-calculator-bmi-IB2245771.png` | **BMI — first capture ever.** Result card sheared through `Normal`; `Add` enabled on a calculator that cannot save a protocol | — **RETIRED 2026-08-03 — no longer captured.** The screen is WITHDRAWN by the owner's decision (H6, `bf52ecc`), and no route in the app reaches it any more. Retired because the screen is withdrawn, **not because the capture broke**. This frame stands as evidence and is not deleted. Re-list the calculator and the capture entry returns in the same commit.
| IB2245772 | `25-calculator-freetest-IB2245772.png` | **Free T Index — first capture ever.** Same shear, same enabled `Add` | — **RETIRED 2026-08-03 — no longer captured.** The screen is WITHDRAWN by the owner's decision (H6, `bf52ecc`), and no route in the app reaches it any more. Retired because the screen is withdrawn, **not because the capture broke**. This frame stands as evidence and is not deleted. Re-list the calculator and the capture entry returns in the same commit.
| IB2245773 | `26-calculator-microdose-IB2245773.png` | **TRT Microdose — first capture ever.** Clean at this size |
| IB2245774 | `28-calculator-steroid-IB2245774.png` | **Steroid Dosage at DEFAULT — first capture ever.** Compare `IB2245752`, the same screen at AX5 |
| IB2245775 | `27-calculator-plotter-IB2245775.png` | **Cycle Plotter — first capture ever**, and reachable only by the dashboard dialog. Carries C8's two chrome-less pickers |
| IB2245746 | `09-dashboard-ax5-IB2245746.png` | Dashboard at AX5, greeting capped |
| IB2245747 | `10-tools-ax5-IB2245747.png` | Tools at AX5 |
| IB2245748 | `12-calculator-trt-ax5-IB2245748.png` | TRT Dose at AX5 |
| IB2245752 | `13-calculator-steroid-ax5-IB2245752.png` | Steroid Dosage at AX5 — the sheared dose field and the picker overflow |
| IB2245753 | `14-calculator-trt-ester-ax5-IB2245753.png` | TRT's `Ester` picker at AX5 — the picker overflow on a second screen |

## What this pass found

Fourteen of these screens had never been photographed at any size. Everything below
is at **default** — the size everyone has been looking at for three days.

### 1. An input sheared by the pinned bar, at default size — `IB2245770`

`BPC+TB500`. `TB-500 bac water` is cut through its own control by the plate's top
edge, and `Add` sits below it, full width and enabled. That is **F-A's exact shape
and D5 word for word** — an action you can reach for a value you can't — except
F-A was filed as an AX5 finding on one screen and this is default size on a
different one.

**`PinnedBarReachabilityUITests` covers three calculators: TRT Dose,
Reconstitution, Steroid Dosage.** BPC+TB500 is not one of them. So D5's assertion,
built precisely to stop this, is aimed at 3 of 15 screens and the defect is live at
default size on one it has never looked at. **This is F-D a third time** — the check
is sound and its AIM is short (§5.33).

### 2. Result cards sheared at default size — `IB2245771`, `IB2245772`, `IB2245766`

`BMI` and `Free T Index` are both cut through the word `Normal`; `Semaglutide` is cut
through `Units (U-100)`. The in-scroll result card runs under the plate on every
calculator whose card is tall enough, and nothing watches result rows against the
plate — the reachability sweep reads `field_*` and `control_*` only.

### 3. `Add` is enabled on calculators that cannot save a protocol — `IB2245771`, `IB2245772`

`canSaveProtocol` is **false** for `bmi`, `freeTestIndex` and `cyclePlotter`, and its
own comment says the flag exists because "a calculator with no save path walks the
user into a wall at the last step". `AddScreen` honours it. **`CalculatorScreen` does
not reference it at all** — the CTA is gated on `vm.result.isValid && network.isOnline`
— so BMI and Free T Index render a full-width, fully enabled `Add`.

**NOT YET DRIVEN, and the severity depends entirely on which way it goes:** if the
tap fails, it is the wall the flag exists to prevent, reached from Tools instead of
from Add. If it succeeds, a "BMI" protocol lands in the user's protocol list — a
saved dosing protocol from a calculator that computes an index and no dose. Filed
unresolved rather than guessed.

### 4. `Cycle Plotter` is absent from the screen whose job is listing calculators

`CalculatorCategory.members` enumerates **14 of the 15 slugs** and `.cyclePlotter` is
in none of them, so `ToolsScreen` cannot render it — while that screen's own comment
says it "Shows ALL calculators including the ones that cannot save a protocol (BMI,
Free T Index, **the plotter**)". A shipped calculator, missing from the browse
surface, with a comment asserting the opposite.

Found by the sweep dying on it: thirteen calculators were located on that list by the
identical mechanism and this one never appeared after twelve scrolls. Its only route
is the dashboard's `Add a protocol` dialog, which enumerates `allCases` — and that
dialog needs **eight drags** to reach the entry, because it carries 16 actions on an
874pt display. The same dialog offers all three calculators that cannot save a
protocol, under a title promising one.

### 5. F-F is measured, and it is not what the board says

**The board says the hero covers the disclaimer tail "on every calculator". Measured
on all fourteen at rest, it is six**, and on those six the overlap is *identical*:

    Reconstitution · Semaglutide · Tirzepatide · Retatrutide · BMI · Free T Index
    disclaimer y 761.67, hero (172, 762, 58, 58) -> (172, 762, 19.33 x 13.0), 251.3pt²

The hero never moves — fixed at `(172, 762, 58, 58)` on every screen and at every
scroll offset, which is F-G's finding from another angle. What varies is where the
form's content ends. The other eight put the disclaimer somewhere else entirely:

| | disclaimer y at rest | |
|---|---|---|
| Peptide, BPC+TB500 | 1119.0, 1120.67 | below an 874pt display |
| TRT Dose, Steroid Dosage | 1031.33 | below the display |
| TRT & EOD, TRT Microdose | 961.0, 943.67 | below the display |
| HCG | 909.67 | below the display |
| BPC-157 | 841.67 | on screen — and **inside the tab bar's region**, which starts at y 792 |

**And on the six that "overlap", the disclaimer is not visible at all.** `IB2245765`
is the proof: the tree reports `Maths only — not medical advice.` at y 761.67, on
screen; the pixels at y 720–820 are the navy `Add` plate, the hero circle and the tab
bar, and the string appears **nowhere in the frame**. The plate is opaque
(`.regularMaterial`, measured #FEFEFE) and T25 established nothing renders behind it.

So the finding as filed — "the hero covers the last ~19pt" — is describing an
**accessibility-tree intersection between two elements, one of which is not drawn**.
`LeafOverlapUITests` reads a tree with no z-order and no clipping, so it cannot tell
"these share pixels" from "one of these is underneath an opaque plate". The real
state is worse and simpler: **at rest, on every calculator measured, the disclaimer is
unreadable** — below the display, behind the tab bar, or under the pinned bar.

**It is also deterministic, not intermittent.** The same 19.33 × 13.0 came back
byte-identical from a standalone walk probe and from this run. The three
`isIntermittent` entries for this pair were flagged because the observation depended
on scroll offset; read at rest it does not vary. Two of those three (`TRT Dose`,
`Steroid Dosage`) name a pair that **cannot occur at rest at all** and should be
deleted rather than flagged — and because `isIntermittent` switches off the both-ends
assertion, the check that would have caught that was the one the flag disabled.

### 6. The duplicated headline figure is not one screen

F-B was filed against `IB2245750` on TRT. It is on `Reconstitution`
(`Add bac water 5.00 mL`), `BMI` (`24.69`), `Free T Index` (`40.0`) and `Semaglutide`
(`0.100 mL`) too — the same figure at full display treatment twice, once in the
scroll and once in the pinned bar.

## Not captured, and why — decisions, not omissions

- **Drawer and Settings.** They render the account's real email and avatar. Standing
  decision; two 08-01 frames already carry it and are a blocker on this repo ever
  being public, and these frames go into a chat window on a phone.
- **The welcome / signed-out path.** Shooting it means signing out, which discards
  the Keychain session and costs a real Supabase sign-in to recover.
- **No frame was dropped for any other reason.** All 22 intended default-size frames
  were taken.

### A frame deliberately NOT shot: F-F

F-F's overlap exists only at rest, and the at-rest frame of every calculator it
happens on is already in this set. A dedicated capture would have been a
byte-identical duplicate of `IB2245765` under a second serial. **`IB2245765` is the
frame that carries F-F** — naming it here is the substitute for issuing a serial that
would say nothing (T17's reasoning).
