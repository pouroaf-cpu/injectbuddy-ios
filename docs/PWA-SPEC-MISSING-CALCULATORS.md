# PWA spec — the three calculators with no iOS screen

Extracted from the PWA source on the Windows box (`Projects\Injectbuddy`), which the Mac
cannot read. Written 2026-08-02 so these are **implementation, not archaeology** when they
come up the queue (T15).

Source of truth: `public/app.js`. Config shapes cross-checked against `lib/edit-schema.json`,
`lib/edit-schema.ts`, `public/ib-edit-schema.js`, and the write path `app/api/dosages/route.ts`.

> **Read §0 before building any of them.** Two of the three have a trap in the saved config
> that will not surface until a user's row fails to load, and the server will not catch it.

---

## 0. Cross-cutting — read first

**The server does not validate these three.** `validProtocol()` has no case for
`bioavailability`, `femalehrt` or `oilblend`, so they fall through to
`default: Object.keys(config).length > 0`. A wrong config shape is accepted **silently**.
Getting `config` right is entirely on the client, and iOS writes straight to PostgREST with
no server in the path at all.

This is the same class of failure as the three config-shape bugs already fixed on this
project — internally consistent code, wrong against reality, invisible until someone queried
real rows. Verify against real rows before ticking anything here.

**Number formatting** (`app.js:1218`) — every displayed number goes through:

```js
const fmt = (n, d = 2) => isNaN(n) || !isFinite(n) || n < 0 ? '—' : n.toFixed(d);
```

Negative and non-finite render as an em-dash, **not** a number. Match this.

**Calc gate.** Results stay hidden until Calculate is pressed; changing any input marks the
result stale. The web shows a 380 ms spinner before revealing.

**Row insert.** `saved_dosages` takes `user_id`, `calculator_type`, `label` (nullable),
`config` (jsonb), `status` (`'active'` default; `'draft'`/`'archived'` accepted; a DB trigger
keeps `is_active` in sync). Dedup on iOS is the unique index on
`(user_id, calculator_type, config)` — see `BOARD.md`; do **not** reintroduce the
`/api/dosages` assumption.

---

## 1. Bioavailability — "Ester Bioavailability & Half-Life"

`BlendCalcPage` sibling; component `BioavailabilityPage` (`app.js:6487`).
Nav label elsewhere is "Ester Half-Life Calculator"; rail label "Bioavailability".

**Slug:** `calculator_type: 'bioavailability'`.

### Inputs

| Field | Key | Control | Unit | Default | Min | Step |
|---|---|---|---|---|---|---|
| Compound / ester | `ester` | searchable combobox, placeholder "Search compound…" | — | `testenan` | — | — |
| Route | `route` | 2-chip segmented, stretch | — | `IM` | — | — |
| Dose | `dose` | numeric, decimal keypad | mg | `'100'` | 0 | unset |
| Inject every | `freq` | numeric, decimal keypad | days | `'3.5'` | 0 | 0.5 |

Route options verbatim: `IM`, `SubQ`. No quick-value buttons on this calculator.

### Ester table — reproduce exactly

`t` is elimination half-life **in days**. Combobox label renders as `label + ' (t½ ' + t + 'd)'`.
Picker order is the key order below.

```js
const ESTERS = {
  testprop:  {label: 'Testosterone Propionate',      t: 0.8},
  testace:   {label: 'Testosterone Acetate',         t: 3},
  testenan:  {label: 'Testosterone Enanthate',       t: 4.5},
  testcyp:   {label: 'Testosterone Cypionate',       t: 8},
  testundec: {label: 'Testosterone Undecanoate',     t: 21},
  nanddeca:  {label: 'Nandrolone Decanoate (Deca)',  t: 15},
  nandph:    {label: 'Nandrolone Phenylprop (NPP)',  t: 2.7},
  trenace:   {label: 'Trenbolone Acetate',           t: 3},
  trenenan:  {label: 'Trenbolone Enanthate',         t: 4.5},
  trenhex:   {label: 'Trenbolone Hexa (Parabolan)',  t: 14},
  mastprop:  {label: 'Masteron Propionate',          t: 0.8},
  mastenan:  {label: 'Masteron Enanthate',           t: 4.5},
  eq:        {label: 'Boldenone Undecylenate (EQ)',  t: 14},
};
```

### Formulas — verbatim (`app.js:6494-6505`)

```js
const E = ESTERS[ester];
const D = parseFloat(dose); const tau = parseFloat(freq);
const ke = Math.log(2) / E.t;
const valid = D > 0 && tau > 0;
const accum = valid ? 1 / (1 - Math.exp(-ke * tau)) : NaN;
const subqPeak = route === 'SubQ' ? 0.7 : 1;
const subqTrough = route === 'SubQ' ? 1.2 : 1;
const peak = valid ? D * accum * subqPeak : NaN;
const trough = valid ? D * accum * Math.exp(-ke * tau) * subqTrough : NaN;
const ratio = valid ? peak / trough : NaN;
const suggestTau = Math.max(0.5, Math.round(0.585 * E.t * 2) / 2); // τ for ratio ~1.5, to 0.5d
const spiky = valid && ratio > 1.8;
```

> **Do not simplify the ratio.** The SubQ multipliers are applied to peak and trough *before*
> the ratio, so for SubQ the ratio is `e^(ke·τ) × 0.7/1.2`, **not** `e^(ke·τ)`. The formula
> legend shown to the user says `peak:trough = e^(ke·τ)` — the legend is a simplification and
> the code is what ships. Implement the code.

Model: one-compartment multiple-dose, flip-flop kinetics. "SubQ flattens the curve vs IM
(slower release): peak ×0.7, trough ×1.2 (approx)."

### Outputs

Eyebrow: **"Steady-state serum (4 weeks)"**. Three-column grid, in order:

| # | Label | Value | Decimals | Colour |
|---|---|---|---|---|
| 1 | PEAK | `peak` | 0 | accent |
| 2 | TROUGH | `trough` | 0 | default text |
| 3 | PEAK:TROUGH | `ratio` | 2 | `#f43f5e` if spiky, else `#34d399` |

Sticky bar: `amount = peak`, `amountUnit = 'mg peak'`, `ml: 0`, `units: 0`.
Empty state: "Enter a dose and frequency."

**Note the colour pair against `DESIGN-PARITY.md` before using it.** `#f43f5e` and `#34d399`
are the PWA's values; the iOS palette already replaced `danger #FF5757` with `#A31313` at
7.90:1 for exactly this reason. Use the iOS semantic colours, not these hexes.

### Chart — optional for v1

Steady-state curve over 28 days, `VW=320, VH=150, PAD=8, DAYS=28`, 120 samples, normalised to
curve max, vertical gridline at every dose time.

```js
function bioCurve(ke, tau, days, samples) {
  var pts = [];
  var burn = 10 * (Math.log(2) / ke); // ~10 half-lives of prior dosing
  var first = -Math.ceil(burn / tau) * tau;
  var maxY = 0;
  for (var s = 0; s <= samples; s++) {
    var t = (days * s) / samples;
    var lvl = 0;
    for (var ti = first; ti <= t + 1e-9; ti += tau) lvl += Math.exp(-ke * (t - ti));
    pts.push({x: t, y: lvl});
    if (lvl > maxY) maxY = lvl;
  }
  return {pts: pts, maxY: maxY};
}
```

### Warnings

- **Spiky** — `ratio > 1.8`. Red panel: "**Peaky levels.** A peak:trough of `fmt(ratio,1)`
  means big swings between shots. For *{ester label}* (t½ *{t}* d), injecting about every
  **{suggestTau} days** or sooner keeps the ratio near 1.5 for steadier levels."
- **Stable** — `!spiky && valid`. Green panel: "**Stable levels.** This frequency keeps peaks
  and troughs close together for *{ester label}*."
- Always-on disclaimer: pharmacokinetic model, not medical advice; relative serum levels
  (mg in the depot), not lab readings; confirm with bloodwork.

### Saved config

```js
const config = {ester: ester, route: route, dose: D, freq: tau};
const label = E.label + ' · ' + D + 'mg E' + tau + 'D ' + route;
```

`ester` string key · `route` `'IM'`|`'SubQ'` · `dose` **number** (mg) · `freq` **number** (days).
Doses and freqs are the parsed floats, **not** the strings. Example label:
`Testosterone Enanthate · 100mg E3.5D IM`.

---

## 2. Female HRT Planner

Component `FemaleHRTPage` (`app.js:7027`); tables at `6980-7013`.

**Slug:** `calculator_type: 'femalehrt'`.

### Inputs

| Field | Key | Control | Default | Notes |
|---|---|---|---|---|
| Protocol | `proto` | wrap-chip row, 4 options | `'post'` | picking `mtf` **force-sets** `prog = 'none'` |
| Estradiol route | `route` | wrap-chip row, 5 options | `'patch'` | changing route resets `doseIdx` to `min(1, doses.length - 1)` |
| Estradiol dose | `doseIdx` | searchable combobox, options depend on route | `1` | value is the **array index** |
| Progesterone | `prog` | wrap-chip row, 4 options | `'cont'` | **card hidden when `proto === 'mtf'`** |
| Testosterone | `test` | 3-chip stretch row | `'none'` | optional |

No numeric fields, no free text. `isValid` is hard-coded `true` — this calculator can always
be calculated and saved.

Render guard: `const dose = R.doses[Math.min(doseIdx, R.doses.length - 1)] || R.doses[0];`

### Lookup tables — reproduce exactly

```js
const FHRT_PROTOCOLS = {
  peri: {label: 'Perimenopause', e2target: 'symptom relief (~50–100 pg/mL)', prog: true},
  post: {label: 'Postmenopause', e2target: 'symptom relief (~40–100 pg/mL)', prog: true},
  lowt: {label: 'Female low-T',  e2target: 'maintain existing',              prog: false},
  mtf:  {label: 'Transgender MTF', e2target: 'feminising (~100–200 pg/mL)',  prog: false},
};
// route -> [{dose label, approx serum E2 pg/mL}]
const FHRT_ROUTES = {
  patch:  {label: 'Patch',  doses: [{d:'25 mcg/day',e2:40},{d:'37.5 mcg/day',e2:55},{d:'50 mcg/day',e2:70},{d:'75 mcg/day',e2:90},{d:'100 mcg/day',e2:110}],
           sites: ['Lower abdomen L','Lower abdomen R','Upper buttock L','Upper buttock R'],
           note: 'Transdermal — lowest VTE risk. Rotate sites, avoid the waistline.'},
  gel:    {label: 'Gel',    doses: [{d:'0.5 mg/day',e2:25},{d:'1.0 mg/day',e2:45},{d:'1.5 mg/day',e2:65}],
           sites: ['Upper arm L','Upper arm R','Inner thigh L','Inner thigh R'],
           note: 'Apply to clean dry skin; let dry before dressing. Wash hands — avoid transfer to others.'},
  spray:  {label: 'Spray',  doses: [{d:'1 spray/day',e2:20},{d:'2 sprays/day',e2:35},{d:'3 sprays/day',e2:50}],
           sites: ['Inner forearm L','Inner forearm R'],
           note: 'Let dry fully; transfer risk if skin contact before dry.'},
  oral:   {label: 'Oral',   doses: [{d:'1 mg/day',e2:40},{d:'2 mg/day',e2:70}],
           sites: [],
           note: 'First-pass through the liver — higher VTE/clot risk than transdermal. Often avoided where transdermal is an option.'},
  inject: {label: 'Injection', doses: [{d:'2 mg/week',e2:80},{d:'4 mg/week',e2:150},{d:'5 mg/week',e2:180}],
           sites: ['SubQ abdomen L','SubQ abdomen R','SubQ thigh L','SubQ thigh R'],
           note: 'Estradiol valerate/cypionate. Peaks and troughs across the week; split dosing flattens levels.'},
};
const FHRT_PROG = {
  none:   {label: 'None',       text: null},
  cyclic: {label: 'Cyclic',     text: 'Micronized progesterone 200 mg at night, days 14–28 of each cycle (induces a monthly bleed). Protects the uterine lining when estrogen is used with a uterus.'},
  cont:   {label: 'Continuous', text: 'Micronized progesterone 100 mg at night, every day. No scheduled bleed. Endometrial protection for daily estrogen.'},
  iud:    {label: 'IUD',        text: 'Levonorgestrel IUD provides local endometrial protection — no oral progesterone needed for that purpose.'},
};
const FHRT_TEST = {
  none:  {label: 'None',      text: null},
  cream: {label: 'Cream',     text: 'Testosterone cream ~0.5 mg/day to the skin (roughly 1/10th of a male Testosterone (TRT) dose). For low libido/energy where indicated; keep serum total-T in the female reference range.'},
  inj:   {label: 'Injection', text: 'Testosterone ~5–10 mg/week SubQ (1/10th of a typical male dose). Monitor total-T to stay in the female range.'},
};
```

Dose combobox label format: `d.d + '  (~' + d.e2 + ' pg/mL)'` — **two** spaces before the paren.

### Formulas

**There are none.** No `IB_CALC_FORMULA` entry exists for `femalehrt`, and the component
performs no arithmetic beyond table indexing. The only output number is `dose.e2`, read
straight from the table. Do not invent a calculation.

### Outputs

Eyebrow **"Suggested regimen"**, then the protocol label in accent bold, then these rows
(each: eyebrow title / bold body / muted sub), in order:

1. **Estradiol** — `R.label + ' · ' + dose.d`; sub: `'Approx serum E2 ~' + dose.e2 + ' pg/mL (population average, varies widely). Goal: ' + P.e2target + '. ' + R.note`
2. **Progesterone** — only when `!isMtf && FHRT_PROG[prog].text`
3. **Anti-androgen** — only when `isMtf`; body "Prescriber-directed"; sub: MTF feminisation usually pairs estradiol with an anti-androgen (e.g. spironolactone or a GnRH analogue); specifics set by the clinician.
4. **Testosterone** — only when `FHRT_TEST[test].text`
5. **Rotate application sites** — only when `R.sites.length > 0` (hidden for `oral`); body `R.sites.join(' → ')`

Sticky bar: `amount = dose.e2`, `amountUnit = 'pg/mL'`, `ml: 0`, `units: 0`. `e2` values are
integers; no decimal formatting applied.

Empty state: "Press calculate to see your suggested regimen."

Always-on disclaimer: educational planning aid only, **not** medical advice or a prescription;
must be prescribed and monitored by a qualified clinician; figures are approximate starting
points (NAMS 2022) with wide individual variation; bloodwork and prescriber supersede the tool.

### Saved config — contains a trap

```js
const config = {proto: proto, route: route, doseIdx: doseIdx, prog: prog, test: test};
const label = P.label + ' · ' + R.label + ' ' + dose.d;
```

> **`doseIdx` stores an array index, not the dose.** It is only meaningful together with
> `route`, and **reordering any dose array silently changes the meaning of every saved row**
> — a user's "37.5 mcg/day" becomes "50 mcg/day" with no migration and no error. Treat the
> `FHRT_ROUTES` dose arrays as append-only, and never sort them.
>
> `doseIdx` must serialise as a JSON **number** or the row is ignored on load
> (`typeof cfg.doseIdx === 'number'`). A Swift encoder emitting `"1"` breaks loading with no
> visible failure.
>
> `prog` is **still written when `proto === 'mtf'`** even though the UI hid the control — it
> will be `'none'` because selecting mtf force-sets it. Write the key regardless; omitting it
> diverges from web rows.

Example label: `Postmenopause · Patch 37.5 mcg/day`.

---

## 3. Oil blend — "Testosterone Blend Calculator"

Component `BlendCalcPage` (`app.js:7363`).

### Slug — two strings, and they are not interchangeable

- **`'oilblend'` is the saved slug** — the literal in the POST body and the auth-modal pending
  payload (`app.js:7418, 7421`). This is what goes in `calculator_type`.
- **`'blend'` is the client-side page id only** — page route, `calcId`, related-links key,
  PostHog property. Never written to the database.
- `lib/edit-schema.json` carries `"oilblend": { "aliasOf": "blend" }` so a stored `oilblend`
  row resolves to the `blend` schema entry.

> **Web bug, do not copy it.** The `blend` edit-schema entry has
> `"href": "/bpc-157-tb500-blend-calculator/"` — the *peptide* blend calculator, not
> `/blend-calculator/`. Mirrored in `public/ib-edit-schema.js:1172` and
> `public/ib-erail.js:280`, and `ib-erail.js:120` labels `blend: 'BPC+TB500'`. Saved oil-blend
> rows deep-link to the wrong calculator on web. **iOS should link to `/blend-calculator/`.**
> Worth raising with the web side separately.

### Inputs

Component list, **1 to 5 rows**. Each row: `name` (text, placeholder "Compound / ester") and
`mgml` (numeric, decimal keypad, placeholder "0", unit mg/mL, min 0).

Row controls: `×` remove, disabled when `comps.length <= 1`. `+ Add compound` shown only while
`comps.length < 5`. Any edit, add or remove sets `presetId = 'custom'`.

| Field | Key | Control | Unit | Default | Min | Step |
|---|---|---|---|---|---|---|
| Draw volume | `injVol` | numeric, decimal | mL | `'1'` | 0 | 0.05 |
| Injections / week | `injPerWeek` | numeric, integer keypad | ×/wk | `'2'` | 0 | 1 |

View toggle: chips `mg/mL` / `Barrels`, default `'barrels'`, persisted in `localStorage`
(`ib_blend_view`). Display-only — **not** saved to config.

### Presets

Default selected on load is `sust250`.

```js
const BLEND_PRESETS = [
  {id:'custom',  name:'Custom blend', comps:[{name:'',mgml:0}]},
  {id:'sust250', name:'Sustanon 250', comps:[
    {name:'Test Propionate',mgml:30},{name:'Test Phenylpropionate',mgml:60},
    {name:'Test Isocaproate',mgml:60},{name:'Test Decanoate',mgml:100}]},
  {id:'tmt450',  name:'TMT 450 (Test/Mast/Tren E)', comps:[
    {name:'Test Enanthate',mgml:150},{name:'Masteron Enanthate',mgml:150},{name:'Tren Enanthate',mgml:150}]},
  {id:'testnpp', name:'Test/NPP 300', comps:[
    {name:'Test Enanthate',mgml:200},{name:'NPP',mgml:100}]},
  {id:'cutmix',  name:'Cut Mix 150 (Prop/Mast/Tren A)', comps:[
    {name:'Test Propionate',mgml:50},{name:'Masteron Propionate',mgml:50},{name:'Tren Acetate',mgml:50}]},
];
```

### Formulas — verbatim (`app.js:7391-7399`)

```js
const iv = parseFloat(injVol); const fpw = parseFloat(injPerWeek);
const parsed = comps.map(function(c) { var m = parseFloat(c.mgml); return {name: c.name, mgml: isFinite(m) && m > 0 ? m : 0}; });
const totalMgMl = parsed.reduce(function(s, c) { return s + c.mgml; }, 0);
const injMl = isFinite(iv) && iv > 0 ? iv : 0;
const freq = isFinite(fpw) && fpw > 0 ? fpw : 0;
const perInj = parsed.map(function(c) { return {name: c.name || 'Component', mg: c.mgml * injMl}; });
const totalPerInj = totalMgMl * injMl;
const isValid = totalMgMl > 0 && injMl > 0;
```

Weekly per component: `c.mg * freq`. Weekly total: `totalPerInj * freq`.

Barrel geometry: `maxMg = mgml * MAX_DRAW_ML`, `mg = mgml * drawVol`,
`frac = clamp01(drawVol / MAX_DRAW_ML)`. Slider `min:0, max: maxMg || 1, step: (maxMg || 1)/120`;
dragging emits `t / mgml`, or `null` when `mgml <= 0` (guards divide-by-zero).

```js
const MAX_DRAW_ML = 3.0;
const MIN_DRAW_ML = 0.05;
function clampDraw(v) { return Math.min(MAX_DRAW_ML, Math.max(MIN_DRAW_ML, v)); }
```

> These clamp the **barrel-drag write path only**. Typing into the Draw volume box is not
> clamped on web. On iOS, `NumberField` now clamps *and rewrites the text* (T1), so iOS will
> diverge from the web here — **that divergence is correct and deliberate**; do not "fix" it
> back. Note it in `BOARD.md` when this ships.

### Outputs

Hero metrics, in order:

| # | Label | Value | Decimals | Unit | Shown when |
|---|---|---|---|---|---|
| 1 | Per Injection | `totalPerInj` | 0 | mg | always |
| 2 | Weekly Total | `totalPerInj * freq` | 0 | mg/wk | `freq > 0` |

Live readouts inside the "Dose it" card (visible before Calculate): total blend strength
`fmt(totalMgMl,0)` mg/mL; blend label `fmt(totalMgMl,0) + ' mg/mL blend · ' + names.join(' / ')`
for active components; per-row values as above; footer `'Drawing ' + fmt(drawVol,2) + ' mL'`
and `fmt(totalPerInj,0)` mg "per shot". Barrels-only hint: "All compounds share one draw —
move any barrel and the rest adjust with it."

Result panel: collapsible **"Per-compound breakdown"**, open by default. One row per component
with `mgml > 0`, in component order: name left; `fmt(c.mg,1)` mg in accent right, then, only
when `freq > 0`, `'  ·  ' + fmt(c.mg * freq, 0) + ' mg/wk'`.

Sticky bar: `ml = injMl`, `units: 0`, `amount = totalPerInj`, `amountUnit = 'mg'`.
Empty states: "Add a compound with a concentration above to start dosing." and
"Add at least one compound with a concentration."

### Warnings

- Calculate gated on `[{key:'mix', ok: totalMgMl > 0}, {key:'vol', ok: injMl > 0}]`; a failing
  gate glows the offending card red and aborts. iOS equivalent: highlight the blend list when
  no positive concentration, the draw-volume field when it is 0/blank.
- Component count clamp: add disabled at 5, remove disabled at 1.
- **No syringe over-capacity warning exists on this calculator.** A 3 mL draw is the barrel
  max but typing 10 mL is accepted on web without warning. iOS already has an over-capacity
  warning pattern (icon **and** text, never colour alone) — adding it here is an improvement
  on the web, not a parity break. Recommend adding it.

Disclaimer: per-compound dose = injection mL × that compound's mg/mL; arithmetic only, not
medical advice, not an endorsement of any compound; verify the vial's actual labelled
concentrations.

### Saved config

```js
const config = {
  comps: parsed.filter(function(c){return c.mgml>0;}).map(function(c){return {name: c.name, mgml: c.mgml};}),
  injVol: injMl,
  injPerWeek: freq
};
const label = (totalMgMl > 0 ? fmt(totalMgMl,0) + ' mg/mL blend' : 'Blend') + ' · '
            + parsed.filter(function(c){return c.mgml>0;}).length + ' compounds';
```

- `comps` — **array of objects**, `{name: string, mgml: number}`. Components with `mgml <= 0`
  are **filtered out** before saving. `name` may be an empty string; the `'Component'` fallback
  is display-only and is **not** persisted. `mgml` is a number, never a string.
- `injVol` — **number** (mL), the sanitised `injMl`.
- `injPerWeek` — **number**; can legitimately be `0`, since `isValid` does not require it.
- `presetId` and `viewMode` are **not** saved.

Example label: `250 mg/mL blend · 4 compounds`.

Edit-rail schema exposes only two editable keys, and note the inconsistency:
`injPerWeek` has `min: 1` in the rail while the calculator itself will save `0`.

---

## Gaps — explicitly not found in source

Recorded rather than inferred, per `CLAUDE.md`: an invented range or half-life in a dosing app
is worse than a gap.

- No `max` on any numeric input in these three. `step` unset for bioavailability `dose` and
  blend `mgml` (browser default 1, which does not restrict typed decimals).
- No `IB_CALC_FORMULA` entry for `femalehrt` — no formula card is rendered for it.
- No syringe over-capacity warning on the blend calculator.
- No edit-schema entries for `bioavailability` or `femalehrt`. `edit-schema.json`'s `_comment`
  confirms this is intentional: types not listed "use the rail's generic config fallback until
  refined".
