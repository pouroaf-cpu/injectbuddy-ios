# Screenshot log

**Append-only.** Never edit a row and never delete one. If a row is wrong, add a
new row that supersedes it and say so in `What it shows`.

Serials are `IB` + 7 digits, sequential, never reused and never reissued. A
serial identifies **one capture event of one frame** — re-shoot the same screen
tomorrow and it gets a new serial. That is the point: two rows with the same
serial, or a capture time that did not move between "refreshes", or a commit SHA
that does not contain the fix someone thought they were photographing, are all
things this table makes *detectable* rather than merely plausible. This project
has twice shipped evidence that looked fine and was not — a "refreshed" set that
came back byte-identical because the taps had silently failed, and a frame that
was the iOS home screen with the app backgrounded.

**The rule starts on 2026-08-02. Everything captured before it is unserialised**
— `2026-08-01-current` and all the per-cycle folders. Those frames have no
reliable per-frame capture time, and inventing one would be precisely the
fabricated-evidence problem this log exists to prevent. They are not backfilled.

Times are the capture machine's local clock (PDT, UTC−7) with the NZ equivalent
alongside, because the two sides of this project are 19 hours apart and a bare
wall-clock time is ambiguous between them.

No serial is stamped into the image. These frames get measured — pixel
positions, contrast samples, overlap distances — and a visible stamp would mutate
the evidence in order to label it, so the file on disk would no longer be what
the device rendered. The filename carries the serial instead.

| Serial | File | What it shows | Captured (PDT / NZ) | Folder | Commit | App state |
|---|---|---|---|---|---|---|
| IB2245723 | `02-dashboard-IB2245723.png` | Dashboard, signed in, three saved protocols and a next-dose card | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | Defects 1 and 2 fixed; AX5 Tools layout still live |
| IB2245724 | `03-calendar-IB2245724.png` | 30-day injection calendar | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245725 | `04-tools-IB2245725.png` | Tools — the calculator list, default type size | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245726 | `05-add-IB2245726.png` | Add tab | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245727 | `06-calculator-trt-IB2245727.png` | TRT Dose calculator at rest, nothing focused | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245728 | `07-calculator-barrel-row-IB2245728.png` | TRT Dose scrolled down to the segmented syringe-barrel row | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245729 | `08-logdose-sheet-IB2245729.png` | Log-dose sheet | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245730 | `09-dashboard-ax5-IB2245730.png` | Dashboard at the largest accessibility text size | 2026-08-01 15:01 / 2026-08-02 10:01 | `2026-08-02-current` | `3b8b8b1` | as above |
| IB2245731 | `10-tools-ax5-IB2245731.png` | Tools at AX5 — hyphenated `Semaglu-tide`, orphaned `e` on `Tirzepatide`, clipped title, icons that did not scale | 2026-08-01 15:01 / 2026-08-02 10:01 | `2026-08-02-current` | `3b8b8b1` | as above; this layout is the open finding |
| IB2245732 | `11-calculator-keyboard-toolbar-IB2245732.png` | TRT Dose with the weekly-dose field focused — the quick values in the keyboard toolbar, Done button, and the select-all-on-focus handles on `100` | 2026-08-01 15:00 / 2026-08-02 10:00 | `2026-08-02-current` | `3b8b8b1` | Defect 2 fixed — this frame IS the fix |
| IB2245733 | `90-defect-before-typed-100250-IB2245733.png` | BEFORE — weekly dose reads `100250` while the result bar shows a 2.500 mL draw computed from the clamped 1000; the quick-value row is not on screen, behind the pinned bar | 2026-08-01 14:25 / 2026-08-02 09:25 | `2026-08-02-current` | `6f7b0ef` | Defects 1 and 2 both live |
| IB2245734 | `91-defect-before-chip-tap-no-effect-IB2245734.png` | BEFORE — the same screen after tapping `quick_mgWeek_400`. Nothing moved. The tap reported success against an occluded element | 2026-08-01 14:26 / 2026-08-02 09:26 | `2026-08-02-current` | `6f7b0ef` | Defects 1 and 2 both live |
| IB2245735 | `11b-calculator-keyboard-toolbar-keypad-up-IB2245735.png` | **Supersedes IB2245732.** Same screen, re-shot with the software keypad actually on screen — the toolbar's quick values and Done sit above the keypad and clear of the pinned result bar, and the inline quick row is hidden while the field is focused. IB2245732 was taken with a hardware keyboard attached, so iOS suppressed the software keypad and the accessory bar was photographed sitting on the tab bar, in a position it will never occupy in front of a user. That frame is not evidence about the default configuration | 2026-08-01 15:17 / 2026-08-02 10:17 | `2026-08-02-current` | `3949f3b` + working tree | Defects 1 and 2 fixed; inline quick row now hidden on focus |
| IB2245736 | `02-dashboard-IB2245736.png` | Dashboard, signed in — greeting now on the scaling type token | 2026-08-01 15:30 / 2026-08-02 10:30 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245737 | `03-calendar-IB2245737.png` | 30-day injection calendar | 2026-08-01 15:30 / 2026-08-02 10:30 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245738 | `04-tools-IB2245738.png` | Tools — the calculator list, default type size | 2026-08-01 15:30 / 2026-08-02 10:30 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245739 | `05-add-IB2245739.png` | Add tab | 2026-08-01 15:30 / 2026-08-02 10:30 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245740 | `06-calculator-trt-IB2245740.png` | TRT Dose at rest, nothing focused — inline quick row visible | 2026-08-01 15:31 / 2026-08-02 10:31 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245741 | `07-calculator-barrel-row-IB2245741.png` | TRT Dose scrolled to the segmented syringe-barrel row | 2026-08-01 15:31 / 2026-08-02 10:31 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245742 | `08-logdose-sheet-IB2245742.png` | Log-dose sheet | 2026-08-01 15:31 / 2026-08-02 10:31 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245743 | `09-dashboard-ax5-IB2245743.png` | Dashboard at AX5 — **the greeting now scales**; compare IB2245730, where it was pixel-identical to default | 2026-08-01 15:32 / 2026-08-02 10:32 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245744 | `10-tools-ax5-IB2245744.png` | Tools at AX5 — unchanged, still the open layout finding | 2026-08-01 15:32 / 2026-08-02 10:32 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245745 | `11-calculator-keyboard-toolbar-IB2245745.png` | TRT Dose, weekly dose focused, software keypad up — toolbar quick values and Done above the keypad, inline row hidden | 2026-08-01 15:29 / 2026-08-02 10:29 | `2026-08-02-current` | `c1956cd` + type-scale fix | Defects 1 and 2 fixed; type scale now tracks Dynamic Type; AX5 Tools layout still live |
| IB2245746 | `09-dashboard-ax5-IB2245746.png` | **Supersedes IB2245743.** Dashboard at AX5 after capping the greeting at `accessibility1` — greeting is two lines and the Next dose card's `Mark taken` CTA is fully on screen. In IB2245743 that CTA was cut off by the bottom of the display | 2026-08-01 15:47 / 2026-08-02 10:47 | `2026-08-02-current` | `8fcb2cb` + greeting cap | Type scale scaling; greeting capped; AX5 Tools layout still live |
| IB2245747 | `10-tools-ax5-IB2245747.png` | **Supersedes IB2245744.** Tools at AX5, unchanged — still the open layout finding | 2026-08-01 15:47 / 2026-08-02 10:47 | `2026-08-02-current` | `8fcb2cb` + greeting cap | as above |
| IB2245748 | `12-calculator-trt-ax5-IB2245748.png` | **The first capture of the TRT calculator at AX5, ever.** After the NumberField reflow: `200` renders as the largest text in the field with `mg/mL` beneath it and the steppers beside, nothing truncated. Before the reflow this screen showed a small `200` beside a huge `mg/mL`, and the weekly dose truncated to `1…` | 2026-08-01 15:47 / 2026-08-02 10:47 | `2026-08-02-current` | `8fcb2cb` + AX5 reflow | Value truncation on a dose field FIXED; pinned bar still covers all but the first field at AX5 |
| IB2245749 | `06-calculator-trt-IB2245749.png` | **Supersedes IB2245740.** TRT Dose at rest after the measured pinning gate. The plate top moves from pt 456.33 to pt 564.67 — **52.40% -> 35.40% of the content area** — and the shear through the `Frequency` control is gone; four of five inputs are complete without scrolling. Plate is `.regularMaterial` (#FEFEFE) with a 1px hairline, replacing the `.bar` slab (#DBDBDB) | 2026-08-01 20:11 / 2026-08-02 15:11 | `2026-08-02-current` | `369fbc5` | Measured gate at cap 0.40, `lead` rung; T21 tone changed, blur NOT delivered |
| IB2245750 | `07-calculator-barrel-row-IB2245750.png` | **Supersedes IB2245741.** TRT Dose scrolled to the end. Shows the card's new hairline stroke against the near-white plate — and shows `Draw per injection · 0.250 mL` rendered TWICE at full display treatment, once in the scroll and once in the pinned `lead` bar. That duplication is a new open finding, listed in BOARD §1 | 2026-08-01 20:11 / 2026-08-02 15:11 | `2026-08-02-current` | `369fbc5` | as above |
| IB2245751 | `11-calculator-keyboard-toolbar-IB2245751.png` | **Supersedes IB2245745.** Weekly dose focused at 300, software keypad up (asserted on screen before shooting). The field being edited is fully visible, the result updates live to 0.750 mL in the `compact` rung, chips and Done clear the plate. `Frequency` is sheared by the plate edge in this state — recorded, not hidden: with the keypad up the content area is a fraction of the screen and the reachability sweep asserts at rest | 2026-08-01 20:11 / 2026-08-02 15:11 | `2026-08-02-current` | `369fbc5` | as above |
| IB2245752 | `13-calculator-steroid-ax5-IB2245752.png` | **The first capture of `Steroid Dosage` at AX5, ever — the BEFORE frame for the shear the reachability sweep found.** `field_mgWeek` spans y 636.33…701.33 against a plate top of pt 651.67, so the weekly dose is cut through its own digits. The run ASSERTS the shear is present before writing the file, so this frame cannot be a photograph of a screen where the defect is absent. It also shows three defects nobody had seen: the `Compound` picker's value renders OUTSIDE its own chrome and overlaps both the label above it and `Vial strength` below; the screen title truncates to `Steroid Dos…`; and the compound hyphenates mid-word as `Oxan-drolone` | 2026-08-01 22:23 / 2026-08-02 17:23 | `2026-08-02-current` | `98743bc` | Measured gate at cap 0.40, `unpinned` rung at AX5; shear is live, and is a named expected failure in the reachability sweep |
| IB2245753 | `14-calculator-trt-ester-ax5-IB2245753.png` | **The overlap is the shared picker control, not `Steroid Dosage`.** TRT's `Ester` picker at AX5, scrolled into view: `Testosterone Enanthate` wraps to three lines that overflow the field chrome and draw on top of the `Ester` label above it. Different screen, different picker, and a string 2 characters LONGER than the `Oxandrolone (Anavar)` that overflowed in IB2245752 — while `Frequency`'s `2×/week` in the same frame sits cleanly inside its box, so the defect is length-dependent rather than universal | 2026-08-01 22:29 / 2026-08-02 17:29 | `2026-08-02-current` | `56dd1fe` | Same as IB2245752 |
| IB2245754 | `02-dashboard-IB2245754.png` | **Supersedes IB2245736.** Dashboard, signed in. Part of the first single-run, single-SHA default-size sweep — the set it replaces was two builds photographed an hour apart | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | Measured gate at cap 0.40; rig size ASSERTED as `large` by the `bar_gate` probe before any frame was written |
| IB2245755 | `03-calendar-IB2245755.png` | ⛔️ **NOT THE CALENDAR — this frame is the DASHBOARD mid-fade** (`Hello, devtools.`, Next dose, `Mark taken`, `PROTOCOLS`, `Loading…`; no calendar grid anywhere in it). Nothing cites it for a finding. See `2026-08-02-current/README.md` | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245756 | `04-tools-IB2245756.png` | ⛔️ **NOT TOOLS — this frame is the CALENDAR mid-fade**, with a **pre-H6** Tools list ghosting behind it (`BMI` and `Free T Ind…` are legible in the ghost). See `2026-08-02-current/README.md`. **The `Cycle Plotter` claim below is CORRECTED, not withdrawn:** `Cycle Plotter` is absent from the Tools list — **and that stands on `CalculatorCategory.members` enumerating 14 of the 15 slugs with `.cyclePlotter` in none, which is a code reading. The frame cited beside it is a photograph of the Calendar and is not evidence for anything.** The finding had two sources, one of them was never real, and nobody noticed because the real one was sitting next to it — **a true claim with a false citation is harder to catch than a false claim** | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245757 | `05-add-IB2245757.png` | ⛔️ **NOT THE ADD FUNNEL — this frame is TOOLS mid-fade**, with the Add screen ghosting in. See `2026-08-02-current/README.md`. ⚠️ **The claim previously recorded here — *"Add funnel — which DOES filter to `savableMembers`, unlike the dashboard's `Add a protocol` dialog"* — CANNOT have come from this frame:** the frame shows the Tools list, and the Add funnel's *calculator* list does not appear in it at all. **The claim is not withdrawn and is not re-verified here — it needs its real source named** (a code reading of `savableMembers` against the dashboard dialog's `CalculatorSlug.listedCases`). Citation struck, claim left open for whoever re-sources it | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245758 | `08-logdose-sheet-IB2245758.png` | **Supersedes IB2245742.** Log-dose sheet | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245759 | `06-calculator-trt-IB2245759.png` | **Supersedes IB2245749.** TRT Dose at rest | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245760 | `07-calculator-barrel-row-IB2245760.png` | **Supersedes IB2245750.** TRT Dose scrolled to the barrel row | 2026-08-02 04:42 / 2026-08-02 23:42 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245761 | `11-calculator-keyboard-toolbar-IB2245761.png` | **Supersedes IB2245751.** Weekly dose focused at 300, software keypad asserted on screen before shooting | 2026-08-02 04:43 / 2026-08-02 23:43 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245762 | `15-calculator-eod-IB2245762.png` | **TRT & EOD — first capture ever, at any size.** Disclaimer at y 961.0, below an 874pt display | 2026-08-02 04:43 / 2026-08-02 23:43 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245763 | `16-calculator-hcg-IB2245763.png` | **HCG — first capture ever.** Clean at this size: result card whole, no duplication visible, no shear | 2026-08-02 04:44 / 2026-08-02 23:44 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245764 | `17-calculator-peptide-IB2245764.png` | **Peptide — first capture ever.** Disclaimer at y 1119.0, below the display | 2026-08-02 04:45 / 2026-08-02 23:45 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245765 | `18-calculator-reconstitution-IB2245765.png` | **Reconstitution — first capture ever, and THE FRAME THAT CARRIES F-F.** The tree reports `Maths only — not medical advice.` at y 761.67, on screen, overlapping the hero by 19.33 x 13.0pt; the pixels at y 720–820 are the `Add` plate, the hero circle and the tab bar, and the string appears NOWHERE in the frame. Also shows `Add bac water · 5.00 mL` twice at full display treatment | 2026-08-02 04:45 / 2026-08-02 23:45 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245766 | `19-calculator-semaglutide-IB2245766.png` | **Semaglutide — first capture ever.** `Units (U-100)` in the in-scroll result card is SHEARED by the plate's top edge at DEFAULT size; `Draw 0.100 mL` renders twice | 2026-08-02 04:46 / 2026-08-02 23:46 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245767 | `20-calculator-tirzepatide-IB2245767.png` | **Tirzepatide — first capture ever** | 2026-08-02 04:47 / 2026-08-02 23:47 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245768 | `21-calculator-retatrutide-IB2245768.png` | **Retatrutide — first capture ever** | 2026-08-02 04:47 / 2026-08-02 23:47 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245769 | `22-calculator-bpc157-IB2245769.png` | **BPC-157 — first capture ever.** Disclaimer at y 841.67 — on screen, clear of the hero, and inside the tab bar's region, which starts at y 792 | 2026-08-02 04:48 / 2026-08-02 23:48 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245770 | `23-calculator-bpc157blend-IB2245770.png` | **BPC+TB500 — first capture ever, and the worst frame in this set. AN INPUT IS SHEARED BY THE PINNED BAR AT DEFAULT SIZE**: `TB-500 bac water` is cut through its own control by the plate's top edge, with `Add` full width and enabled below it. F-A's shape and D5 word for word, at the size everyone uses — on a screen `PinnedBarReachabilityUITests` does not cover | 2026-08-02 04:49 / 2026-08-02 23:49 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245771 | `24-calculator-bmi-IB2245771.png` | **BMI — first capture ever.** Result card sheared through `Category / Normal`; `24.69` rendered twice; and a full-width, fully enabled `Add` on a calculator whose `canSaveProtocol` is FALSE — **RETIRED 2026-08-03 — no longer captured.** The screen is WITHDRAWN by the owner's decision (H6, `bf52ecc`), and no route in the app reaches it any more. Retired because the screen is withdrawn, **not because the capture broke**. This frame stands as evidence and is not deleted. Re-list the calculator and the capture entry returns in the same commit. | 2026-08-02 04:50 / 2026-08-02 23:50 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245772 | `25-calculator-freetest-IB2245772.png` | **Free T Index — first capture ever.** Same three: sheared through `Band / Normal`, `40.0` twice, enabled `Add` on a non-saving calculator — **RETIRED 2026-08-03 — no longer captured.** The screen is WITHDRAWN by the owner's decision (H6, `bf52ecc`), and no route in the app reaches it any more. Retired because the screen is withdrawn, **not because the capture broke**. This frame stands as evidence and is not deleted. Re-list the calculator and the capture entry returns in the same commit. | 2026-08-02 04:50 / 2026-08-02 23:50 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245773 | `26-calculator-microdose-IB2245773.png` | **TRT Microdose — first capture ever.** Clean at this size | 2026-08-02 04:51 / 2026-08-02 23:51 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245774 | `28-calculator-steroid-IB2245774.png` | **Steroid Dosage at DEFAULT size — first capture ever.** The AX5 frame IB2245752 is the same screen; at default the compound picker sits cleanly inside its chrome, which is what makes the picker overflow length- and size-dependent rather than universal | 2026-08-02 04:52 / 2026-08-02 23:52 | `2026-08-02-current` | `9b4afcb` | as above |
| IB2245775 | `27-calculator-plotter-IB2245775.png` | **Cycle Plotter — first capture ever, and the only frame here reached by a route other than Tools.** Absent from the Tools list entirely; taken via the dashboard `Add a protocol` dialog, which needed eight drags to bring the entry into the tree. Carries C8's two `.menu` pickers that render without `fieldChrome` | 2026-08-02 04:53 / 2026-08-02 23:53 | `2026-08-02-current` | `9b4afcb` | as above |

## Supersession, and where the superseded files live

`IB2245723`–`IB2245735` were the set **before** the type-scale fix. They are
superseded by `IB2245736`–`IB2245745` and their **files are removed from the
working tree** so the folder means "current state" and nothing else. The rows
above stay — that is what append-only is for — and each row names the commit the
file exists at, so `git show 25c7b221:docs/ui-audit/2026-08-02-current/<file>`
retrieves any of them. A row without a retrievable file would be a broken record;
a folder holding two full sets would be a folder nobody trusts.

`IB2245730` is the one worth keeping findable: it is the dashboard at AX5 with the
greeting frozen at its default size, and it is the evidence that the type scale
did not scale.

## Frames attempted and discarded

Recorded because a discarded frame is evidence about the harness, and because
silence here looks like the frame was never attempted.

| Intended | Why discarded | Serial |
|---|---|---|
| `12-calculator-trt-ax5` | `openTRT()` could not find the TRT row at AX5 — the labels wrap so hard that only four rows fit and the list needs scrolling. `continueAfterFailure = true` let the capture run anyway, so the file was a genuine photograph of the **Tools** screen under a name claiming the TRT calculator. Dropped, not renamed. The harness now sets `continueAfterFailure = false` for capture runs and asserts the destination before shooting: a sweep that cannot fail loudly will keep producing frames that lie. | none issued |
| `12-calculator-trt-ax5`, first and second attempts | Same cause, still unsolved: at AX5 the Tools list needs more scrolling than one swipe to bring the TRT row into view. This time the harness **failed the run** instead of photographing the wrong screen, which is the fix working. No frame, no serial. The AX5 calculator remains uncaptured and is the gap in the AX5 survey. | none issued |

**Third attempt succeeded — `IB2245748`.** The harness now scrolls until the row is hittable rather than swiping a fixed number of times, re-querying each pass. Two things had to be true and neither was obvious: at AX5 the list is **lazy**, so `waitForExistence` on the row failed with "does not exist" while it was two swipes away; and `Tools` is a `List`, which XCUITest surfaces as a collectionView, not a scrollView, so asking only for `scrollViews` found nothing to scroll on a screen that scrolls perfectly well by hand.

---

## 2026-08-03 — the default set, re-shot on a harness whose frames mean what their names say

**`testCaptureFullDefaultSweep`, `** TEST SUCCEEDED **`, 806s, 0 failures.** App built from
`Sources/` at **`3fe7302`**; harness at **`f506c4e`**. Capture window **2026-08-03 05:49–06:03 PDT /
2026-08-04 00:49–01:03 NZ** — the run's start and end, stated as a window rather than invented
per-frame times. Each frame's own status bar carries its minute.

> **⛔️ THE THREE SHELL FRAMES IN `2026-08-02-current` ARE PHOTOGRAPHS OF THE WRONG SCREEN**, and the
> same is true of `2026-08-01-current`. `03-calendar` is the Dashboard, `04-tools` is the Calendar,
> `05-add` is Tools — `shot()` fired during the cross-fade after `tab()`, so every shell frame landed
> one screen behind. **The outgoing screen is sharp and the destination ghosts in**, so each is a
> good photograph of a real screen filed under the next screen's name: **not blurry, misfiled.**
> Rows `IB2245755`, `IB2245756` and `IB2245757` above are annotated. The frames are **kept, not
> deleted** — the record that the harness had this defect is now the more useful thing.
>
> **`tab()` now asserts arrival** against something only the destination renders. It caught two
> defects on its first two runs: a proof string that could not match because `.insetGrouped`
> uppercases `Section` headers, and `Log dose` having **no proof at all** while being captured twice
> per sweep on trust.

| Serial | File | What it shows | Captured | Folder | Build | Notes |
|---|---|---|---|---|---|---|
| IB2245776 | `02-dashboard-IB2245776.png` | Dashboard | 2026-08-03 05:49–06:03 / 2026-08-04 00:49–01:03 | `2026-08-03-current` | `3fe7302` | as above |
| IB2245777 | `03-calendar-IB2245777.png` | **Calendar — supersedes `IB2245755`, which is the Dashboard. The first true Calendar frame in this project.** | as above | `2026-08-03-current` | `3fe7302` | asserted on the `Today` button |
| IB2245778 | `04-tools-IB2245778.png` | **Tools — supersedes `IB2245756`, which is the Calendar.** `TESTOSTERONE & HORMONES` is TRT Dose · TRT & EOD · TRT Microdose · HCG and nothing else: **`BMI` and `Free T Index` are gone, H6 confirmed on a frame that can answer it.** Sample: cut off after `BPC+TB500`, so it speaks for three sections and not below them | as above | `2026-08-03-current` | `3fe7302` | asserted on a `Reconstitution` row |
| IB2245779 | `05-add-IB2245779.png` | **Add — supersedes `IB2245757`, which is Tools** | as above | `2026-08-03-current` | `3fe7302` | asserted on the footer, not the header — the header is `.insetGrouped`-uppercased |
| IB2245780 | `06-calculator-trt-IB2245780.png` | TRT Dose, at rest | as above | `2026-08-03-current` | `3fe7302` | `GATE … area=690.67 bar=120.00 **share=0.1737**` — the result bar at **17.37%** |
| IB2245781 | `07-calculator-barrel-row-IB2245781.png` | TRT Dose, barrel row — all four labels keep their units | as above | `2026-08-03-current` | `3fe7302` | |
| IB2245782 | `08-logdose-sheet-IB2245782.png` | Log-dose sheet | as above | `2026-08-03-current` | `3fe7302` | first capture with an arrival proof |
| IB2245783 | `11-calculator-keyboard-toolbar-IB2245783.png` | TRT Dose, keypad up | as above | `2026-08-03-current` | `3fe7302` | |
| IB2245784 | `15-calculator-eod-IB2245784.png` | TRT & EOD | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 965 |
| IB2245785 | `16-calculator-hcg-IB2245785.png` | HCG | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 913.67 |
| IB2245786 | `17-calculator-peptide-IB2245786.png` | Peptide | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 1123 |
| IB2245787 | `18-calculator-reconstitution-IB2245787.png` | Reconstitution — **the disclaimer IS legible in this frame**, where `IB2245765` recorded it appearing nowhere. Clears the pinned region by **+16.00pt** | as above | `2026-08-03-current` | `3fe7302` | the only calculator that clears |
| IB2245788 | `19-calculator-semaglutide-IB2245788.png` | Semaglutide — `Draw 0.100 mL` complete with its unit | as above | `2026-08-03-current` | `3fe7302` | disclaimer **fully inside `bar_plate`** |
| IB2245789 | `20-calculator-tirzepatide-IB2245789.png` | Tirzepatide | as above | `2026-08-03-current` | `3fe7302` | disclaimer **fully inside `bar_plate`** |
| IB2245790 | `21-calculator-retatrutide-IB2245790.png` | Retatrutide | as above | `2026-08-03-current` | `3fe7302` | disclaimer **fully inside `bar_plate`** |
| IB2245791 | `22-calculator-bpc157-IB2245791.png` | BPC-157 | as above | `2026-08-03-current` | `3fe7302` | disclaimer **fully inside `tabBar`** — and it was never on F-F's list of six |
| IB2245792 | `23-calculator-bpc157blend-IB2245792.png` | BPC+TB500 | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 1124.67 |
| IB2245793 | `26-calculator-microdose-IB2245793.png` | TRT Microdose | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 947.67 |
| IB2245794 | `27-calculator-plotter-IB2245794.png` | Cycle Plotter | as above | `2026-08-03-current` | `3fe7302` | reached by its only route, not from Tools |
| IB2245795 | `28-calculator-steroid-IB2245795.png` | Steroid Dosage | as above | `2026-08-03-current` | `3fe7302` | disclaimer below the fold, y 1035.33 |

**Not shot, all three decisions rather than omissions:** the drawer and Settings (they render the
account's real email and avatar — **so the new account-deletion UI is NOT in this set**, and a
separately masked capture is owed to `launch/APP-REVIEW-NOTES.md`); the signed-out path (costs the
Keychain session); and AX5 (this is the default-size set — `2026-08-02-current`'s five AX5 frames are
**not superseded** and remain the only large-text evidence there is).
