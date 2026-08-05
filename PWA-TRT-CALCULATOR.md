# PWA — how the TRT calculator actually behaves

Read from the live source on the Windows machine, 2026-08-04: `public/app.js` (the calculator SPA)
and `public/ib-sfx.js` (the sound layer). The page itself is `public/legacy/trt-calculator/index.html`,
rewritten from `/trt-calculator/` in `next.config`.

**This is the reference for T-01. Build to this, not to the 2026-07-31 screen captures** — the live
app has moved past them.

Nearly every behaviour below has a comment in the source explaining *why*, usually naming the thing
that went wrong first. Those reasons are reproduced here, because they are the parts most likely to
be re-broken by a reimplementation.

---

## 1 · The numeric field — `QuickPickerField`

The control used for Vial Strength, Weekly Dose and Every N Days. One row, five elements:

```
[ −− ] [ − ]  [   0   ·  mg/mL ]  [ + ] [ ++ ]
        100   150   200   250   300
```

### Two step sizes, and the glyph carries the size

- **outer `−−` / `++` = the major step**
- **inner `−` / `+` = the minor step, half the major**

> *"the doubled glyph carries the doubled step, so the relationship is readable without printing the
> numbers on the buttons."*

Defaults derive from the field's own value ladder (major = tick spacing, minor = half). Per-field
overrides on TRT:

| Field | Major | Minor | Preset chips |
|---|---|---|---|
| Vial Strength | from ladder | half | `100 · 150 · 200 · 250 · 300` |
| Weekly Dose | **10** | **5** | `50 · 100 · 150 · 200 · 250 · 450` |
| Every N Days | **1** | **0.5** | `1 · 2 · 3 · 3.5 · 7` |

**Weekly Dose overrides its steps for a reason worth keeping:** the ladder ticks every 5, so the
derived pair would be 5 and 2.5 — *"2.5 mg/wk is below any real titration step while putting a
decimal into a field that is otherwise always whole."*

**The presets are not an even split.** An even split of vial strength gave 80/160/240/320/400, which
*"spends two of five chips on 320 and 400 (rare) while omitting 200 — the concentration this page's
own copy cites 18 times."* The ladder is clinical, not arithmetic. Every N Days' five are the
intervals the page's own copy names: daily, EOD, E3D, twice weekly, weekly.

### Snapping

**The snap grid is the MINOR step, not the ladder tick.** It was the tick, and that silently broke
the inner buttons: *"on a 10-tick barrel a +5 rounded straight back to the nearest 10 and the value
never moved."*

Presets are snapped through the same function, *"so a caller can't seat a chip on a value the
steppers could never reproduce."*

### From empty

`−` holds at the minimum; `+` gives the first real increment rather than jumping to the preset
scale. Buttons disable at each end.

### Press feedback — and the two implementations that failed

One-shot Web Animations API call on the button element:

```
scale 1 → 0.92 (at 40%) → 1,  170ms,  easing: linear
```

**Not CSS `:active`** — *"iOS Safari only honours it when a touch listener exists on the element or
an ancestor, so on a plain `<button>` these registered no press at all on device."*

**Not a toggled class** — *"bump() changes state, so React re-renders and rewrites className from
the VDOM, stripping the class before the animation can paint. Measured: the scale never left 1."*

**Linear, not ease-out** — WAAPI applies easing per segment, so an ease-out curve *"makes each leg
race to its end value: measured with the animation paused, cubic-bezier(.22,1,.36,1) was already
back to 0.986 by 60ms."* Linear gives an even triangle: down over 68ms, back over 102ms.

`el.animate()` is owned by the element, so a re-render cannot cancel it and **rapid taps stack
cleanly instead of one swallowing the next.**

### The odometer

On every committed change the value box **riffles through random digits for 7 frames at 34ms, then
lands on the real number.**

- Purely cosmetic — the model already holds the correct value, so *"a result taken mid-shuffle is
  still right."* Only the display lags.
- Same digit count every frame, `tabular-nums`, so the box never jitters in width.
- **Suppressed** while typing (it would fight the caret), on an empty field, and under
  `prefers-reduced-motion`.
- An incrementing token cancels any in-flight shuffle, so *"hammering ++ doesn't leave an older
  animation writing over a newer value."*

### Typing

- `type="text"`, `inputMode="decimal"`.
- **Focus clears the field** rather than selecting all: *"the box empties and the caret blinks in it,
  which reads as 'type here'."* An empty draft is ignored on commit, so clicking in and straight
  back out leaves the previous value intact.
- Blur commits. Enter blurs.
- While editing, the filled state drops — **the navy border and the tick disappear while you retype
  and return only when a value is committed.**
- The box width hugs its digits so the confirmation tick sits immediately after the number rather
  than pinned to a fixed spot.

### Accessibility

Each stepper announces its size: `"Increase Weekly Dose by 10 mg/wk"`. Preset chips carry
`aria-pressed`.

---

## 2 · The ester picker — `EsterQuickPick`

Three chips — **Test E · Test C · Test P** — plus **Other**, which swaps the row for a searchable
combobox over the full ester list.

- Picking one of the three *from inside the search list* returns to the chip row with it lit, *"so
  the two states always agree about what is selected."*
- If the current value is not one of the three — a restored protocol on Undecanoate — it **opens in
  search mode**, because a chip row with nothing lit gives no sign of what is set.
- The two modes use different React keys so the branch **remounts**, which re-runs the entry
  animation.
- It is a wrapper around the existing combobox, not a change to it: that combobox has ten call sites
  across the calculator suite.

---

## 3 · The shimmer wayfinder — one prompt at a time

Exactly one control on the page is ever prompting. Each computes the same predicate:
**"everything before me is answered, and I am not."**

```
ester  →  vial strength  →  weekly dose  →  every N days
```

It advances down the form as you complete it. On iOS this is the single most visible thing the app
is missing — there is currently nothing telling a first-time user where to start or what is next.

Each field also has its own error message rather than a generic one: *Select an ester type · Input
vial strength · Input weekly dose · Set the injection interval*.

---

## 4 · Modes change which fields exist

Three modes — `ndays` · `perweek` · `ml2mg` — as a segmented control at the top.

- **Every N Days** field renders only in `ndays`.
- **Injections per week** renders only in `perweek`, and is a *slider*, not a quick-picker.
- `ml2mg` drops the weekly-dose field entirely.

iOS has no mode control at all, though it stores a `mode` in the saved protocol.

---

## 5 · Sound — `ib-sfx.js`

Site-wide, synthesised with the Web Audio API. **No audio files ship.**

- **Blip** when the pointer enters any interactive icon — a link, button, `role=button` or `summary`
  containing an inline `<svg>`.
- **Swoosh** when an internal link navigates to another page.
- **Master gain 0.35** — deliberately gentle.
- **A mute toggle pinned bottom-left**, remembered in `localStorage` under `ib_sfx_muted`.
- The AudioContext is created and resumed on the **first** pointerdown or keydown, because browsers
  block audio until a user gesture. Hovers before that first click are silent by design.
- iOS Safari needs more than `resume()`: a one-sample silent buffer is played inside the unlocking
  gesture to wake the audio hardware.
- **Embeds are silent** — a widget in someone else's page must not make noise.
- iOS routes Web Audio through the ringer channel, **so the hardware silent switch works by
  design** — nothing extra is needed to respect it.

**For iOS:** the direct equivalents are `.sensoryFeedback` for the press-level feedback and, if
sound is wanted, an `AVAudioSession` configured so the silent switch is honoured. `UX-UI-RULES.md`
§8 currently says sound is off by default — the web's answer is *on, gentle, with a persistent mute*
which is a different call and worth reconciling.

---

## 6 · What this means for the iOS build

The iOS numeric field is a label, a value, a unit and **two** steppers. The web's is **four**
steppers with a stated 2:1 relationship, a clinical preset ladder under every field, a snap grid
tuned so no button is ever a no-op, an odometer on commit, a focus behaviour that says "type here",
a border that retracts while you edit, and a press animation chosen after two other implementations
were measured and rejected.

None of that is decoration. Every piece of it is in the source with the failure it fixes written
next to it.
