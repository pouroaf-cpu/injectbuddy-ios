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
| `12-calculator-trt-ax5`, second attempt | Same cause, still unsolved: at AX5 the Tools list needs more scrolling than one swipe to bring the TRT row into view. This time the harness **failed the run** instead of photographing the wrong screen, which is the fix working. No frame, no serial. The AX5 calculator remains uncaptured and is the gap in the AX5 survey. | none issued |
