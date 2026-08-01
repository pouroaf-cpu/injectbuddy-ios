# UI audit evidence — 2026-08-01

Screenshots backing the mobile UI / HIG audit. Captured from the running app, not mocked.

## Capture environment

| | |
|---|---|
| Build | `48992c9` on `feature/tabview-shell` |
| Device | iPhone 16 Pro simulator (402 × 874 pt, 3× — PNGs are 1206 × 2622 px) |
| OS | iOS 18.3 simulator runtime |
| Toolchain | Xcode 16.2 (16C5032a) |
| Colour space | sRGB IEC61966-2.1 (verified with `sips -g profile`) |
| Appearance | Light. Dark mode is not shipped (light-only decision, 2026-08-01) so no dark captures are kept here. |
| Dynamic Type | `large` (system default) unless the filename says `dynamictype-ax5` |
| Data | The signed-in account's real protocols — populated, not seeded fixtures |

All PNGs are straight from `xcrun simctl io booted screenshot`: unscaled, uncropped,
unannotated. Coordinates quoted in the findings are **device points**; multiply by 3 to
index the PNG.

## Index

| File | Screen | State |
|---|---|---|
| `01-tab-dashboard-populated.png` | Dashboard tab | Default, populated — next-dose card, 7 protocol tiles, tab bar with raised hero |
| `02-tab-calendar-month.png` | Calendar tab | Month grid, default scroll |
| `03-calculator-semaglutide-default.png` | Semaglutide calculator (pushed from Tools) | Default values; menu-picker inputs, pinned result bar |
| `04-tab-tools-list.png` | Tools tab | Full calculator list, sectioned |
| `05-tab-add-list.png` | Add tab | Category list (GLP-1, Testosterone & Hormones, Peptides, Steroids) |
| `06-drawer-open.png` | Off-canvas drawer over Dashboard | Open, scrolled to top — profile header, nav items, footer |
| `07-drawer-scrolled-bottom.png` | Off-canvas drawer | Scrolled to bottom — remaining calculators, Settings, theme + Sign out footer |
| `08-settings-default.png` | Settings | Default — preferences, connections, account actions incl. destructive rows |
| `09-tab-dashboard-scrolled.png` | Dashboard tab | Scrolled to bottom — "week at a glance" list against the tab bar |
| `10-logdose-sheet.png` | Log-dose sheet (modal) | Presented from the centre tab slot — protocol picker, date row, submit |
| `11-calculator-trtdose-default.png` | TRT Dose calculator | Default — two number fields with steppers, two menu pickers, live result |
| `12-calculator-keyboard-decimalpad.png` | TRT Dose calculator | Field focused, `.decimalPad` up — form mid-entry |
| `13-calculator-empty-invalid.png` | TRT Dose calculator | Vial strength cleared — invalid result, Add disabled |
| `14-tab-dashboard-dynamictype-ax5.png` | Dashboard tab | Dynamic Type `accessibility-extra-extra-extra-large` |
| `15-calculator-trtdose-dynamictype-ax5.png` | TRT Dose calculator | Dynamic Type `accessibility-extra-extra-extra-large` |
| `16-tabbar-over-scrolled-content.png` | Dashboard tab | List content scrolled under the translucent tab bar — worst backdrop the app can produce (it ships no imagery) |
| `17-tab-dashboard-increasecontrast.png` | Dashboard tab | Accessibility → Increase Contrast **enabled** |

## Known blocker on ever making this repo public

`06-drawer-open.png`, `07-drawer-scrolled-bottom.png` and `08-settings-default.png` show the
signed-in account's **real email address and avatar photo**. The repo is private (confirmed
via `gh repo view`), so this is contained, and it was left in place deliberately: purging it
would mean force-pushing a shared branch mid-collaboration, which is a worse trade than the
contained exposure. Recorded here so the decision is on paper rather than in someone's memory.

**If this repo is ever made public, these three files must be purged from history first.**
Further captures of authenticated screens should use a throwaway profile.

## Reproducing a measurement

Every colour figure in the findings comes from these files. To re-derive one, index the
PNG at `(pt × 3)` and apply WCAG 2.1 relative luminance:
`L = 0.2126·R + 0.7152·G + 0.0722·B` on linearised sRGB, ratio `(L1 + 0.05) / (L2 + 0.05)`.

Text foregrounds are taken from the source colour (`Theme.swift` / UIKit semantic values),
not eyedropped off a glyph — iOS stem-darkening makes an antialiased glyph's darkest pixel
read up to ~0.25 higher than the nominal colour, which flatters the ratio. Backgrounds are
sampled from the PNG. See the calibration section of the findings report.
