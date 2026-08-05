#!/usr/bin/env node
// ─── generate-plotter-compounds.mjs ──────────────────────────────────────────
//
// Emits Sources/InjectBuddy/Core/Calculator/PlotterCompoundTable.swift from
// spec/compounds.json + spec/plotter-ios-fields.json.
//
//   node spec/generate-plotter-compounds.mjs           # write the Swift file
//   node spec/generate-plotter-compounds.mjs --check   # exit 1 if it is stale
//
// WHY THIS EXISTS, and it is the whole point of T-60.
//
// The pre-T-60 table was a faithful hand-copy of the web's PLOTTER_COMPOUNDS,
// carrying a comment saying so — and the comment was accurate. The table it
// copied was dead: the in-app plotter was removed in favour of the standalone
// /cycle-plotter/ page, App() redirects 'plotter' straight there, and nothing
// reads PLOTTER_COMPOUNDS any more. So iOS ran 17 wrong half-lives (Tren A 2x,
// PT-141 4.4x, TB-500 4.3x, Melanotan II 2.5x) for however long that had been
// true, and nothing could detect it because the two tables use different id
// vocabularies (`eq` vs `boldenone`, `reta` vs `retatrutide`).
//
// A second hand-copy — of the right table this time — would sit exactly one
// refactor away from the same position. So the Swift table is GENERATED, and
// PlotterCompoundSpecTests re-reads spec/compounds.json independently and
// asserts the shipped table row for row. A hand edit to the Swift fails the
// test; a spec update without a regenerate fails the test; a new compound on
// the web side fails THIS script.
//
// PROVENANCE, verified 2026-08-04 rather than taken on report:
//   • spec/compounds.json here is byte-identical to the web's — git blob
//     cf14ff76a5c80f7053f28c10df8443228bc82edf on
//     pouroaf-cpu/injectbuddy@feature/dosage-status-model. `git hash-object`
//     on this copy returns the same sha.
//   • That file's own $comment says it is generated from
//     public/legacy/cycle-plotter/pk.js (blob ff59e1f0). Parsed pk.js's
//     COMPOUNDS object and compared all 31 rows on name/short/type/cat/
//     halfLife/unit: zero differences. The spec's claim to be the single
//     source of truth is TRUE, and pk.js is what the live plotter loads.

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..');
const SPEC = path.join(HERE, 'compounds.json');
const OVERLAY = path.join(HERE, 'plotter-ios-fields.json');
const OUT = path.join(ROOT, 'Sources/InjectBuddy/Core/Calculator/PlotterCompoundTable.swift');

const die = (msg) => { console.error('generate-plotter-compounds: ' + msg); process.exit(1); };

const specFile = JSON.parse(fs.readFileSync(SPEC, 'utf8'));
const overlay = JSON.parse(fs.readFileSync(OVERLAY, 'utf8'));
const spec = specFile.compounds;

// ── Preconditions. Each one is a way this generator could produce a plausible
// wrong table, so each is checked rather than assumed.
if (specFile.compoundCount !== Object.keys(spec).length) {
  die(`compounds.json says compoundCount ${specFile.compoundCount} but carries ${Object.keys(spec).length}`);
}

const iosOnly = overlay.iosOnly;
const extras = Object.fromEntries(Object.entries(overlay.extras).filter(([k]) => !k.startsWith('$')));
const notCarried = Object.fromEntries(Object.entries(overlay.notCarried).filter(([k]) => !k.startsWith('$')));
const stale = overlay.staleDefaultDoseUnit;

// Every spec compound is either shipped or explicitly not carried. A 32nd
// compound appearing on the web stops the build here instead of vanishing.
for (const id of Object.keys(spec)) {
  const shipped = id in iosOnly, refused = id in notCarried;
  if (shipped && refused) die(`\`${id}\` is in BOTH iosOnly and notCarried`);
  if (!shipped && !refused) {
    die(`\`${id}\` is new in compounds.json and is in neither iosOnly nor notCarried.\n` +
        `  Decide: ship it (add tmax + defaultDose to iosOnly) or record why not (notCarried).\n` +
        `  Adding a tmax means SOURCING one — see T-32.`);
  }
}
for (const id of Object.keys(iosOnly)) if (!(id in spec)) die(`iosOnly has \`${id}\`, which is not a spec id`);
for (const id of Object.keys(notCarried)) if (!(id in spec)) die(`notCarried has \`${id}\`, which is not a spec id`);
for (const id of Object.keys(extras)) if (id in spec) die(`extras has \`${id}\`, which IS a spec id — move it to iosOnly`);

// `order` must cover every emitted row exactly once.
const expected = new Set([...Object.keys(iosOnly), ...Object.keys(extras)]);
const seen = new Set();
for (const id of overlay.order) {
  if (seen.has(id)) die(`order lists \`${id}\` twice`);
  if (!expected.has(id)) die(`order lists \`${id}\`, which is neither an iosOnly nor an extras row`);
  seen.add(id);
}
for (const id of expected) if (!seen.has(id)) die(`order is missing \`${id}\``);

// ── Merge. Spec wins on every field it carries; the overlay may only supply
// the two it does not (plus whole rows for compounds the live table lacks).
const rows = overlay.order.map((id) => {
  const o = iosOnly[id];
  const base = o ? { ...spec[id], tmax: o.tmax, defaultDose: o.defaultDose, defaultDoseUnit: o.defaultDoseUnit }
                 : { ...extras[id] };
  if (base.defaultDoseUnit !== base.unit && !(id in stale)) {
    die(`\`${id}\` has unit "${base.unit}" but its defaultDose is in "${base.defaultDoseUnit}", ` +
        `and it is not listed in staleDefaultDoseUnit.\n` +
        `  Either convert the dose, or record the mismatch there with the reason.`);
  }
  for (const f of ['name', 'short', 'type', 'cat', 'halfLife', 'unit', 'tmax', 'defaultDose']) {
    if (base[f] === undefined) die(`\`${id}\` is missing \`${f}\``);
  }
  return { id, ...base };
});

// ── Emit.
const num = (v) => (Number.isInteger(v) ? v.toFixed(1) : String(v));
const q = (s) => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
const pad = (s, n) => s + ' '.repeat(Math.max(0, n - s.length));

const w = (f) => Math.max(...rows.map((r) => (typeof r[f] === 'number' ? num(r[f]) : q(r[f])).length));
const wId = w('id'), wName = w('name'), wShort = w('short'), wType = w('type');
const wCat = w('cat'), wHl = w('halfLife'), wTmax = w('tmax'), wDose = w('defaultDose');

const body = rows.map((r) =>
  '        .init(id: ' + pad(q(r.id) + ',', wId + 2) +
  ' label: ' + pad(q(r.name) + ',', wName + 2) +
  ' short: ' + pad(q(r.short) + ',', wShort + 2) +
  ' type: ' + pad(q(r.type) + ',', wType + 2) +
  ' category: ' + pad(q(r.cat) + ',', wCat + 2) +
  ' halfLife: ' + pad(num(r.halfLife) + ',', wHl + 1) +
  ' tmax: ' + pad(num(r.tmax) + ',', wTmax + 1) +
  ' defaultDose: ' + pad(num(r.defaultDose) + ',', wDose + 1) +
  ' unit: ' + q(r.unit) + '),'
).join('\n');

const shipped = rows.filter((r) => r.id in spec).length;
const swift = `// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Regenerate with:
//     node spec/generate-plotter-compounds.mjs
// and check for staleness with:
//     node spec/generate-plotter-compounds.mjs --check
//
// Source of truth: spec/compounds.json — a byte-identical copy of the web's
// (git blob cf14ff76a5c80f7053f28c10df8443228bc82edf on
// pouroaf-cpu/injectbuddy@feature/dosage-status-model), itself generated from
// public/legacy/cycle-plotter/pk.js, which is what the LIVE plotter loads.
// \`tmax\` and \`defaultDose\` have no counterpart there and come from
// spec/plotter-ios-fields.json — see that file for their provenance and for
// why they were left alone by T-60.
//
// PlotterCompoundSpecTests re-reads spec/compounds.json at test time and
// asserts this table against it row for row, so a hand edit here goes RED.
//
// ${rows.length} rows: ${shipped} reconciled to the spec, ${rows.length - shipped} carried by iOS alone
// (spec/plotter-ios-fields.json → extras). ${Object.keys(notCarried).length} spec compounds are not
// shipped — see \`notCarried\` in that file, and T-32.

extension PlotterCompound {

    static let all: [PlotterCompound] = [
${body}
    ]
}
`;

if (process.argv.includes('--check')) {
  const current = fs.existsSync(OUT) ? fs.readFileSync(OUT, 'utf8') : '';
  if (current !== swift) die(`${path.relative(ROOT, OUT)} is STALE. Run: node spec/generate-plotter-compounds.mjs`);
  console.log(`up to date — ${rows.length} rows (${shipped} spec-backed, ${rows.length - shipped} iOS-only)`);
  process.exit(0);
}

fs.writeFileSync(OUT, swift);
console.log(`wrote ${path.relative(ROOT, OUT)} — ${rows.length} rows ` +
            `(${shipped} spec-backed, ${rows.length - shipped} iOS-only, ` +
            `${Object.keys(notCarried).length} spec compounds not carried)`);
