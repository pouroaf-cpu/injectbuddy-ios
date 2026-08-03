# Build cycle 1 — after shots

Same rig as `../2026-08-01/`: iPhone 16 Pro simulator, iOS 18.3, Xcode 16.2, light,
sRGB, unscaled PNGs straight from `simctl io booted screenshot`.

Pair each of these against the before-shot of the same screen in `../2026-08-01/`.

| File | Screen / state | Before | What changed |
|---|---|---|---|
| `01-tab-dashboard-populated.png` | Dashboard, populated | `01-` | Protocol cards full-width and no longer truncating; gradient greeting; navy eyebrows; brand canvas; tab bar contrast |
| `02-calculator-trtdose-default.png` | TRT Dose, default | `11-` | Visible field chrome, 44pt steppers, result hierarchy inverted back the right way |
| `03-calculator-keyboard-decimalpad.png` | TRT Dose, keypad up | `12-` | Hero circle hidden, CTA label readable, result card collapsed, edited field fully visible |
| `04-calculator-trtdose-dynamictype-ax5.png` | TRT Dose at AX5 | `15-` | **No value or unit truncates** |
| `05-logdose-sheet.png` | Log-dose sheet | `10-` | CTA is now the app's one primary-button treatment |
| `06-lightlock-simulator-in-dark-mode.png` | Dashboard, **simulator set to dark** | — | Proof the light-only lock holds |

## The AX5 comparison is the one to look at first

Before (`../2026-08-01/15-`) → after (`04-`):

```
Draw…          0.25…        Draw per injection
Units (…       25.0          0.250 mL
Dose p…      50.00…        Units (U-100)
Injections /…  2.00          25.0
Weekly…      100.0…        Dose per injection      50.00 mg
                            Injections / week           2.00
                            Weekly total          100.0 mg
```

Every unit survives. The primary rows stack label-above-value unconditionally so
they cannot truncate at any type size; the secondary rows use `ViewThatFits` and
fall back to stacked rather than clipping.

## `06-` — what it proves

The simulator is in dark mode in that capture (note the status bar) and the app is
still fully light. That is `UIUserInterfaceStyle: Light`, declared in `project.yml`
and verified present in the generated `Info.plist` after `xcodegen generate`, doing
its job. `.preferredColorScheme(.light)` alone would not have covered the system
surfaces.

## Measured after-values

| Element | Before | After | Required |
|---|---|---|---|
| Primary dose readout | #0FBCAD, 2.34:1 | #075E56, **7.65:1** | 4.5:1 |
| Primary CTA | teal text 2.38:1 | white on #075E56, **7.65:1** | 4.5:1 |
| Tab bar unselected item | #929299, 2.77:1 | #5C5C66 (sampled), **~6:1** | 3:1 glyph / 4.5:1 label |
| Input boundary | #F2F2F7 on #F2F2F7, 1.00:1 | white + hairline stroke | 3:1 |
| Stepper half | 46 × 32 pt | **44 × 44 pt** | 44 × 44 pt |
| `danger` | #FF5757, 3.11:1 | #A31313, **7.90:1** | 4.5:1 |
