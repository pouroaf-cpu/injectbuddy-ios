// GENERATED FILE — DO NOT EDIT BY HAND.
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
// `tmax` and `defaultDose` have no counterpart there and come from
// spec/plotter-ios-fields.json — see that file for their provenance and for
// why they were left alone by T-60.
//
// PlotterCompoundSpecTests re-reads spec/compounds.json at test time and
// asserts this table against it row for row, so a hand edit here goes RED.
//
// 27 rows: 23 reconciled to the spec, 4 carried by iOS alone
// (spec/plotter-ios-fields.json → extras). 8 spec compounds are not
// shipped — see `notCarried` in that file, and T-32.

extension PlotterCompound {

    static let all: [PlotterCompound] = [
        .init(id: "test-e",        label: "Testosterone Enanthate",    short: "Test E",            type: "trt",      category: "Testosterone",  halfLife: 4.5,    tmax: 2.0,   defaultDose: 100.0,  unit: "mg"),
        .init(id: "test-c",        label: "Testosterone Cypionate",    short: "Test C",            type: "trt",      category: "Testosterone",  halfLife: 6.0,    tmax: 2.5,   defaultDose: 100.0,  unit: "mg"),
        .init(id: "test-p",        label: "Testosterone Propionate",   short: "Test P",            type: "trt",      category: "Testosterone",  halfLife: 0.8,    tmax: 0.5,   defaultDose: 50.0,   unit: "mg"),
        .init(id: "test-u",        label: "Testosterone Undecanoate",  short: "Test U",            type: "trt",      category: "Testosterone",  halfLife: 21.0,   tmax: 6.0,   defaultDose: 1000.0, unit: "mg"),
        .init(id: "npp",           label: "Nandrolone Phenylprop.",    short: "NPP",               type: "trt",      category: "Anabolics",     halfLife: 2.7,    tmax: 1.0,   defaultDose: 100.0,  unit: "mg"),
        .init(id: "nandrolone-d",  label: "Nandrolone Decanoate",      short: "Deca",              type: "trt",      category: "Anabolics",     halfLife: 7.0,    tmax: 3.0,   defaultDose: 200.0,  unit: "mg"),
        .init(id: "tren-a",        label: "Trenbolone Acetate",        short: "Tren A",            type: "trt",      category: "Anabolics",     halfLife: 3.0,    tmax: 0.5,   defaultDose: 100.0,  unit: "mg"),
        .init(id: "tren-e",        label: "Trenbolone Enanthate",      short: "Tren E",            type: "trt",      category: "Anabolics",     halfLife: 7.0,    tmax: 2.0,   defaultDose: 200.0,  unit: "mg"),
        .init(id: "boldenone",     label: "Boldenone Undecylenate",    short: "EQ",                type: "trt",      category: "Anabolics",     halfLife: 14.0,   tmax: 5.0,   defaultDose: 300.0,  unit: "mg"),
        .init(id: "masteron-p",    label: "Masteron Propionate",       short: "Mast P",            type: "trt",      category: "Anabolics",     halfLife: 2.0,    tmax: 0.8,   defaultDose: 100.0,  unit: "mg"),
        .init(id: "masteron-e",    label: "Masteron Enanthate",        short: "Mast E",            type: "trt",      category: "Anabolics",     halfLife: 4.5,    tmax: 2.0,   defaultDose: 200.0,  unit: "mg"),
        .init(id: "bpc157",        label: "BPC-157",                   short: "BPC",               type: "peptide",  category: "Healing",       halfLife: 0.25,   tmax: 0.04,  defaultDose: 250.0,  unit: "mcg"),
        .init(id: "tb500",         label: "TB-500",                    short: "TB-500",            type: "peptide",  category: "Healing",       halfLife: 2.5,    tmax: 0.25,  defaultDose: 2000.0, unit: "mg"),
        .init(id: "cjc-nodac",     label: "CJC-1295 (no DAC)",         short: "Mod GRF",           type: "peptide",  category: "Growth",        halfLife: 0.08,   tmax: 0.01,  defaultDose: 100.0,  unit: "mcg"),
        .init(id: "cjc-dac",       label: "CJC-1295 + DAC",            short: "CJC/DAC",           type: "peptide",  category: "Growth",        halfLife: 7.0,    tmax: 2.0,   defaultDose: 2000.0, unit: "mcg"),
        .init(id: "ipamorelin",    label: "Ipamorelin",                short: "Ipam",              type: "peptide",  category: "Growth",        halfLife: 0.09,   tmax: 0.042, defaultDose: 200.0,  unit: "mcg"),
        .init(id: "ghrp2",         label: "GHRP-2",                    short: "GHRP-2",            type: "peptide",  category: "Peptide",       halfLife: 0.083,  tmax: 0.021, defaultDose: 200.0,  unit: "mcg"),
        .init(id: "ghrp6",         label: "GHRP-6",                    short: "GHRP-6",            type: "peptide",  category: "Peptide",       halfLife: 0.083,  tmax: 0.021, defaultDose: 200.0,  unit: "mcg"),
        .init(id: "sermorelin",    label: "Sermorelin",                short: "Sermorelin",        type: "peptide",  category: "Peptide",       halfLife: 0.0076, tmax: 0.003, defaultDose: 300.0,  unit: "mcg"),
        .init(id: "hgh",           label: "HGH (Somatropin)",          short: "HGH",               type: "peptide",  category: "Growth",        halfLife: 0.16,   tmax: 0.125, defaultDose: 1000.0, unit: "IU"),
        .init(id: "pt141",         label: "PT-141",                    short: "PT-141",            type: "peptide",  category: "Other",         halfLife: 0.5,    tmax: 0.042, defaultDose: 1000.0, unit: "mg"),
        .init(id: "igf1lr3",       label: "IGF-1 LR3",                 short: "IGF-1",             type: "peptide",  category: "Growth",        halfLife: 0.8,    tmax: 0.25,  defaultDose: 100.0,  unit: "mcg"),
        .init(id: "ta1",           label: "Thymosin Alpha-1",          short: "Thymosin Alpha-1",  type: "peptide",  category: "Peptide",       halfLife: 0.083,  tmax: 0.021, defaultDose: 1000.0, unit: "mcg"),
        .init(id: "mt2",           label: "Melanotan II",              short: "MT-II",             type: "peptide",  category: "Other",         halfLife: 1.5,    tmax: 0.042, defaultDose: 500.0,  unit: "mg"),
        .init(id: "semaglutide",   label: "Semaglutide",               short: "Sema",              type: "glp1",     category: "GLP-1",         halfLife: 7.0,    tmax: 1.0,   defaultDose: 0.5,    unit: "mg"),
        .init(id: "tirzepatide",   label: "Tirzepatide",               short: "Tirz",              type: "glp1",     category: "GLP-1",         halfLife: 5.0,    tmax: 1.0,   defaultDose: 2.5,    unit: "mg"),
        .init(id: "retatrutide",   label: "Retatrutide",               short: "Reta",              type: "glp1",     category: "GLP-1",         halfLife: 6.0,    tmax: 1.0,   defaultDose: 1.0,    unit: "mg"),
    ]
}
