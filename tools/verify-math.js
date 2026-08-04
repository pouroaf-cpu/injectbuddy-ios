// Independent recompute of the 14 calculator golden vectors (CALC-MATH.md), in
// Node — a different engine/language than the Swift CalculatorEngine. Catches any
// transcription error in the EXPECTED values the Swift golden tests assert against.
// Run: node tools/verify-math.js

const U = ml => Math.round(ml * 100);              // U-100 units
const approx = (a, b, t = 0.001) => Math.abs(a - b) <= t;
let fails = 0;
function check(name, got, want, t) {
  const ok = approx(got, want, t);
  if (!ok) { fails++; console.log(`  FAIL ${name}: got ${got}, want ${want}`); }
  else console.log(`  ok   ${name} = ${got}`);
}

console.log('1. trt-dose (perweek: strength 200, mgWeek 100, inj/wk 2)');
{ const strength=200,mgWeek=100,inj=2; const mgInj=mgWeek/inj, mlInj=mgInj/strength;
  check('mgPerInj',mgInj,50); check('mlPerInj',mlInj,0.25); check('units',U(mlInj),25); }

console.log('2. trt-eod (strength 200, mgWeek 70)');
{ const strength=200,mgWeek=70,freq=3.5; const mgInj=mgWeek/freq, mlInj=mgInj/strength;
  check('mgPerInj',mgInj,20); check('mlPerInj',mlInj,0.1); check('units',U(mlInj),10); }

console.log('3. hcg (vial 5000 IU, bac 1, dose 250)');
{ const vial=5000,bac=1,dose=250; const conc=vial/bac, draw=dose/conc;
  check('conc',conc,5000); check('drawMl',draw,0.05); check('units',U(draw),5);
  check('dosesPerVial',Math.floor(vial/dose),20); }

console.log('4. peptide (mg 50, baw 10, dose 500 mcg, inj/wk 1)');
{ const mg=50,baw=10,doseMcg=500,inj=1; const doseMg=doseMcg/1000, conc=mg/baw, mlInj=doseMg/conc;
  check('doseMg',doseMg,0.5); check('conc',conc,5); check('mlInj',mlInj,0.1); check('units',U(mlInj),10);
  check('weeklyMg',doseMg*inj,0.5); check('totalDoses',mg/doseMg,100); }

console.log('5. reconstitution (mg 5, targetConc 1000 mcg/mL)');
{ const mg=5,target=1000; check('bacWaterMl',(mg*1000)/target,5); check('vialContentsMcg',mg*1000,5000); }

console.log('6. semaglutide (conc 5, dose 0.5)');
{ const conc=5,dose=0.5,vol=dose/conc; check('vol',vol,0.1); check('units',U(vol),10); }

console.log('7. tirzepatide (conc 7.5, dose 5)');
{ const conc=7.5,dose=5,vol=dose/conc; check('vol',vol,0.6667,0.0001); check('units',U(vol),67); }

console.log('8. retatrutide (conc 5, dose 2.5)');
{ const conc=5,dose=2.5,vol=dose/conc; check('vol',vol,0.5); check('units',U(vol),50); }

console.log('9. bpc-157 (concMcgMl 2500, dose 250)');
{ const conc=2500,dose=250,draw=dose/conc; check('drawMl',draw,0.1); check('units',U(draw),10); }

console.log('10. bpc-157-tb500 blend (bpc 5000/2/250, tb 5000/2/2000)');
{ const bC=5000/2,bD=250/bC,tC=5000/2,tD=2000/tC;
  check('bpcDraw',bD,0.1); check('bpcUnits',U(bD),10);
  check('tbDraw',tD,0.8); check('tbUnits',U(tD),80);
  check('totalMl',bD+tD,0.9); check('totalUnits',U(bD)+U(tD),90); }

console.log('11. bmi metric (h 180cm, w 80kg)');
{ const h=180/100,bmi=80/(h*h); check('bmi',bmi,24.6914,0.001); }

console.log('12. bmi imperial (5ft10=70in, 180lb)  [expect 25.8245, NOT 25.81]');
{ const inch=70,bmi=703*180/(inch*inch); check('bmi',bmi,25.8245,0.001); }

console.log('13. free-T index (tt 20 nmol, shbg 50)');
{ const tt=20,shbg=50,fai=(tt/shbg)*100; check('fai',fai,40); }

console.log('14. trt-microdose (ndays: strength 10, mgWeek 5, nDays 3)');
{ const strength=10,mgWeek=5,nDays=3,freq=7/nDays; const mgInj=mgWeek/freq,mlInj=mgInj/strength;
  check('freq',freq,2.3333,0.001); check('mgPerInj',mgInj,2.1429,0.001);
  check('mlPerInj',mlInj,0.21429,0.001); check('units',U(mlInj),21); }

console.log(`\n${fails === 0 ? 'ALL VECTORS PASS' : fails + ' VECTOR(S) FAILED'}`);
process.exit(fails === 0 ? 0 : 1);
