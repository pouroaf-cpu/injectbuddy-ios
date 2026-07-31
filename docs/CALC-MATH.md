# Calculator Math — extracted from Injectbuddy/public/app.js

> Internal build reference for the Swift `CalculatorEngine`. NOT part of the app repo — stays in the
> planning folder. Source of truth is `Injectbuddy/public/app.js`; if anything here is ambiguous,
> re-read the source. **cycle-plotter PK model is NOT fully captured below — read app.js ~line 8920+
> (`pkBuildEntries`, `pkTotalLevel`) for the real model before porting it.**

Canonical order + labels (from `components/nav/SharedNav.tsx` CALC_ITEMS):
1. trt-dose "TRT Dose" · 2. trt-eod "TRT & EOD" · 3. hcg "HCG" · 4. peptide "Peptide" ·
5. reconstitution "Reconstitution" · 6. semaglutide "Semaglutide" · 7. tirzepatide "Tirzepatide" ·
8. retatrutide "Retatrutide" · 9. bpc-157 "BPC-157" · 10. bpc-157-tb500 "BPC+TB500" · 11. bmi "BMI" ·
12. free-testosterone-index "Free T Index" · 13. trt-microdose "TRT Microdose" · 14. cycle-plotter "Cycle Plotter"

Internal app.js page slugs differ: trt, eod, hcg, peptide, reconstitution, semaglutide, tirzepatide,
retatrutide, bpc157, bpc157blend, bmi, freetest, microdose, plotter.

---

## Shared constants

```javascript
const SYRINGE_SIZES = [
  { label: '0.3 mL', ml: 0.3, isInsulin: true },
  { label: '0.5 mL', ml: 0.5, isInsulin: true },
  { label: '1 mL',   ml: 1.0, isInsulin: true },
  { label: '3 mL',   ml: 3.0, isInsulin: false },
];
const ESTER_TYPE_OPTIONS = ["Testosterone Cypionate","Testosterone Enanthate","Testosterone Propionate","Testosterone Undecanoate","Testosterone Acetate","Testosterone Suspension","Sustanon 250"];
const GLP1_CONC_VALUES = [0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20];
const SEMA_DOSE_VALUES = [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.4];
const TIRZ_DOSE_VALUES = [0, 2.5, 5, 7.5, 10, 12.5, 15];
const RETA_DOSE_VALUES = [0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
const TESTO_NGDL_FACTOR = 13.5; // Test-E 100 mg/wk -> ~800 ng/dL steady state (median)
```

U-100 convention everywhere: **1 unit = 0.01 mL**, i.e. `units = mL * 100`.

BMI categories: Underweight 0–18.5, Normal 18.5–25, Overweight 25–30, Obesity I 30–35,
Obesity II 35–40, Obesity III 40+.

getVolumeMeta(ml): <0.01 "Too small to measure"; <0.03 "Difficult to measure"; <0.1 "Acceptable";
<=0.5 "Ideal"; <=1 "Good"; <=3 "Large injection"; >3 "Unrealistic volume".

---

## Per-calculator formulas (verbatim JS)

### trt-dose / trt-microdose (same engine; micro defaults to small strength + 0.3 mL syringe)
```javascript
if (mode === 'ndays')      { freqPerWeek = 7 / nDays;  mgPerInj = mgWeek / freqPerWeek; mlPerInj = mgPerInj / strength; weeklyTotal = mgWeek; }
else if (mode === 'perweek'){ freqPerWeek = injPerWeek; mgPerInj = mgWeek / freqPerWeek; mlPerInj = mgPerInj / strength; weeklyTotal = mgWeek; }
else /* ml2mg */           { mlPerInj = mlDrawn; mgPerInj = mlDrawn * strength; freqPerWeek = injPerWeek; weeklyTotal = mgPerInj * freqPerWeek; }
const unitsPerInj = mlPerInj * 100;
const isValid = strength > 0 && mlPerInj > 0 && isFinite(mlPerInj);
```

### trt-eod
```javascript
const freqPerWeek = 3.5; // hardcoded
const mgPerInj = mgWeek / freqPerWeek;
const mlPerInj = mgPerInj / strength;
const unitsPerInj = mlPerInj * 100;
```

### hcg
```javascript
const concentration = bacWaterMl > 0 ? vialIU / bacWaterMl : 0; // IU/mL
const drawMl = concentration > 0 ? dose / concentration : 0;
const units = Math.round(drawMl * 100);
const dosesPerVial = dose > 0 ? Math.floor(vialIU / dose) : 0;
```

### peptide
```javascript
const dosePerInjMg = doseUnit === 'mcg' ? dosePerInj / 1000 : dosePerInj;
const concentration = bawMl > 0 ? peptideMg / bawMl : 0;       // mg/mL
const mlPerInj = concentration > 0 && dosePerInjMg > 0 ? dosePerInjMg / concentration : 0;
const unitsPerInj = mlPerInj * 100;
const weeklyTotalMg = dosePerInjMg * injPerWeek;
const totalDoses = dosePerInjMg > 0 ? peptideMg / dosePerInjMg : 0;
const vialDays = injPerWeek > 0 ? totalDoses / (injPerWeek / 7) : 0;
const vialWeeks = vialDays / 7;
```

### reconstitution
```javascript
const bacWaterMl = targetConc > 0 ? (peptideMg * 1000) / targetConc : 0; // targetConc in mcg/mL
const vialContentsMcg = peptideMg * 1000;
```

### semaglutide / tirzepatide / retatrutide (identical engine; different dose option arrays)
```javascript
const volumeMl = (conc > 0 && dose > 0) ? dose / conc : 0; // conc mg/mL, dose mg
const units = Math.round(volumeMl * 100);
```

### bpc-157
```javascript
const conc = concMcgMl; // mcg/mL
const drawMl = (conc > 0 && dose > 0) ? dose / conc : 0;
const units = Math.round(drawMl * 100);
```

### bpc-157-tb500 (blend)
```javascript
const bpcConc = bpcWater > 0 ? bpcVial / bpcWater : 0;  // mcg/mL
const bpcDraw = (bpcConc > 0 && bpcDose > 0) ? bpcDose / bpcConc : 0;
const bpcUnits = Math.round(bpcDraw * 100);
const tbConc = tbWater > 0 ? tbVial / tbWater : 0;
const tbDraw = (tbConc > 0 && tbDose > 0) ? tbDose / tbConc : 0;
const tbUnits = Math.round(tbDraw * 100);
const totalMl = bpcDraw + tbDraw;
const totalUnits = bpcUnits + tbUnits;
```

### bmi
```javascript
if (units === 'metric') { const hm = heightCm / 100; bmi = weightKg / (hm * hm); }
else { const totalIn = heightFt * 12 + heightIn; bmi = 703 * weightLb / (totalIn * totalIn); }
```

### free-testosterone-index (FAI)
```javascript
const ttNmol = ttUnit === 'ngdl' ? ttNum / 28.84 : ttNum;
const fai = (isFinite(ttNmol) && shbgNum > 0) ? (ttNmol / shbgNum) * 100 : NaN;
// band: <30 Low; >150 Elevated; else Normal (30–150)
```

### cycle-plotter — READ app.js ~8920+ for real PK (pkBuildEntries / pkTotalLevel). Half-life table
and freq table are in the extraction notes; single-compartment exponential model. Do not ship the
simplified sketch — port the actual functions.

---

## Golden test vectors (assert these in CalculatorEngineTests)

| calc | inputs | expected |
|---|---|---|
| trt-dose | strength 200, mgWeek 100, perweek injPerWeek 2 | mgPerInj 50, mlPerInj 0.25, units 25, weekly 100 |
| trt-eod | strength 200, mgWeek 70 | freq 3.5, mgPerInj 20, mlPerInj 0.1, units 10 |
| hcg | vialIU 5000, bac 1, dose 250 | conc 5000, drawMl 0.05, units 5, dosesPerVial 20 |
| peptide | mg 50, baw 10, dose 500 mcg, inj/wk 1 | conc 5, mlPerInj 0.1, units 10, weekly 0.5mg, totalDoses 100 |
| reconstitution | mg 5, targetConc 1000 | bacWaterMl 5, vialContents 5000 mcg |
| semaglutide | conc 5, dose 0.5 | volumeMl 0.1, units 10 |
| tirzepatide | conc 7.5, dose 5 | volumeMl 0.6667, units 67 |
| retatrutide | conc 5, dose 2.5 | volumeMl 0.5, units 50 |
| bpc-157 | concMcgMl 2500, dose 250 | drawMl 0.1, units 10 |
| bpc-157-tb500 | bpc 5000/2/250, tb 5000/2/2000 | bpcDraw 0.1/u10, tbDraw 0.8/u80, total 0.9/u90 |
| bmi metric | h 180cm, w 80kg | 24.69 Normal |
| bmi imperial | 5ft10, 180lb | 25.81 Overweight |
| free-t-index | tt 20 nmol, shbg 50 | fai 40 Normal |
| trt-microdose | strength 10, mgWeek 5, ndays 3 | freq 2.333, mgPerInj 2.143, mlPerInj 0.2143, units 21.4 |
