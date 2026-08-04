import XCTest
@testable import InjectBuddy

// ─── SteroidFormParityTests  (T-44) ──────────────────────────────────────────
//
// Pins the two numbers the steroid screen used to get wrong, and the two rules
// that made it get them wrong.
//
// WHY THIS FILE EXISTS RATHER THAN A LINE IN CalculatorEngineTests. That file pins
// the ARITHMETIC, and neither of T-44's defects was arithmetic. `steroidInjectable`
// and `steroidOral` were both correct and both had been correct since they were
// written. What was wrong was WHICH ONE RAN and WHAT IT WAS HANDED:
//
//   1 · `evaluate` ran `steroidInjectable` for all twelve compounds, including the
//       five the web marks `cls:'oral'`. The shipped default — Oxandrolone (Anavar),
//       `canInject: false` — showed a 200 mg/mL vial strength and a syringe barrel
//       and answered **0.75 mL / 75 units for a tablet**. `canInject` existed, was
//       correct, and was read by nothing.
//   2 · the compound picker enumerated `SteroidCatalog.all`, so an ester compound
//       could only ever be evaluated on `esters.first`. Trenbolone Acetate is first
//       (0.87), so **300 mg/week of Tren Enanthate reported 261 mg active instead
//       of 213 — 22.5 % high**, with no control on the screen able to correct it.
//
// A test of the formula is green through both.
//
// THE EXPECTATIONS BELOW ARE TRANSCRIBED FROM `public/app.js`, NOT FROM THE SWIFT.
// Read on 2026-08-04 from `origin/feature/dosage-status-model` at
// `~/injectbuddy` (`git show origin/feature/dosage-status-model:public/app.js`):
//
//   • `IB_STEROIDS`                    8748-8761   (`cls`, `esters`, `esterFactor`)
//   • `IB_STEROID_ORDER`               8762
//   • `canInject` / `canOral` / `form`  8787-8789
//   • `steroidConfig()`                8866        (the 13 saved keys)
//   • the compound dropdown            8925-8932   (ester expansion + label rule)
//   • the Form toggle                  8944        (Winstrol only)
//   • `oralInputs`                     8964-8968
//   • `inputs = isInject ? … : …`      8969
//   • the oral KPI card                8979-8982
//   • `activeLine` / `syringeSize`     8984 / 8988 (both `isInject ? … : null`)
//
// Re-derive them from the source, never from this file, if they ever have to move.

final class SteroidFormParityTests: XCTestCase {

    private let acc = 0.001

    // MARK: - Helpers

    /// A values bag for the steroid spec with the picker on `label`'s entry.
    private func values(picking label: String,
                        _ overrides: [String: Double] = [:],
                        file: StaticString = #filePath, line: UInt = #line) -> CalculatorValues {
        let spec = CalculatorCatalog.spec(for: .steroid)
        var v = CalculatorValues.defaults(for: spec.fields)
        guard let idx = SteroidCatalog.picks.firstIndex(where: { $0.label == label }) else {
            XCTFail("No compound picker entry labelled `\(label)`", file: file, line: line)
            return v
        }
        v.numbers["compound"] = Double(idx)
        for (k, n) in overrides { v.numbers[k] = n }
        return v
    }

    private func evaluate(_ v: CalculatorValues) -> CalculatorResult {
        CalculatorEngine.evaluate(slug: .steroid, values: v, scale: .u100)
    }

    private func row(_ r: CalculatorResult, _ label: String) -> String? {
        r.rows.first { $0.label == label }?.value
    }

    /// `SavedDosage` declares `init(from decoder:)`, so it has no memberwise init.
    /// Decoded from JSON, exactly as `ProtocolSummaryTests` does it.
    private func dosage(id: String, type: String, config: String) -> SavedDosage {
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":null,\
        "config":\(config),"start_date":null,"is_active":true}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    // MARK: - 1 · The ester, and the 22.5 % it was worth

    /// THE HEADLINE CASE. 300 mg/week of Trenbolone Enanthate.
    ///
    /// `esterFactor` 0.71 (`app.js:8749`, `enanthate:{…esterFactor:0.71…}`), so the
    /// active nandrolone-equivalent hormone is 300 × 0.71 = **213 mg/week**. The
    /// build this task closes reported 261 — 300 × 0.87, Acetate's factor — because
    /// `evaluate` used `compound.defaultEster` regardless of what was picked.
    func testTrenEnanthateAtThreeHundredMgReturns213MgActive() {
        let r = evaluate(values(picking: "Trenbolone Enanthate",
                                ["mgWeek": 300, "strength": 200, "nDays": 3.5]))
        XCTAssertTrue(r.isValid)
        XCTAssertEqual(row(r, "Active weekly"), "213.0 mg",
                       "300 mg/week Tren E is 300 × 0.71. 261 mg is Acetate's 0.87 — "
                       + "the T-44 defect, 22.5 % high.")
        XCTAssertEqual(row(r, "Weekly total"), "300.0 mg",
                       "The TOTAL is what is drawn and is not ester-adjusted.")
    }

    /// The engine's own answer for the same case, so the assertion above is not
    /// resting on a formatted string alone.
    func testTrenEnanthateActiveWeekArithmetic() {
        let e = CalculatorEngine.steroidInjectable(strength: 200, mgWeek: 300, mode: .ndays,
                                                   nDays: 3.5, injPerWeek: 0, mlDrawn: 0,
                                                   esterFactor: 0.71)
        XCTAssertEqual(e.activeWeek, 213, accuracy: acc)
        let wrong = CalculatorEngine.steroidInjectable(strength: 200, mgWeek: 300, mode: .ndays,
                                                       nDays: 3.5, injPerWeek: 0, mlDrawn: 0,
                                                       esterFactor: 0.87)
        XCTAssertEqual(wrong.activeWeek, 261, accuracy: acc)
        // The size of the error, stated rather than described.
        XCTAssertEqual(wrong.activeWeek / e.activeWeek, 1.2253, accuracy: 0.0005)
    }

    /// The OTHER ester of the same compound still answers for itself — the fix is a
    /// selectable ester, not a different hardcoded one.
    func testTrenAcetateAtThreeHundredMgStillReturns261MgActive() {
        let r = evaluate(values(picking: "Trenbolone Acetate",
                                ["mgWeek": 300, "strength": 100, "nDays": 3.5]))
        XCTAssertEqual(row(r, "Active weekly"), "261.0 mg")
    }

    /// Masteron is the second ester compound and its two factors differ by the same
    /// order (0.84 propionate / 0.73 enanthate, `app.js:8758`).
    func testMasteronsTwoEstersAreBothReachableAndDiffer() {
        let p = evaluate(values(picking: "Masteron Propionate",
                                ["mgWeek": 400, "strength": 100, "nDays": 3.5]))
        let e = evaluate(values(picking: "Masteron Enanthate",
                                ["mgWeek": 400, "strength": 200, "nDays": 3.5]))
        XCTAssertEqual(row(p, "Active weekly"), "336.0 mg")   // 400 × 0.84
        XCTAssertEqual(row(e, "Active weekly"), "292.0 mg")   // 400 × 0.73
    }

    // MARK: - 2 · The picker is the web's dropdown, esters expanded

    /// `app.js:8927-8932` pushes ONE OPTION PER ESTER, so twelve compounds become
    /// fourteen entries. Length first and as its own assertion: the defect was a list
    /// that was short by exactly the entries that mattered.
    func testCompoundPickerExpandsEstersIntoSeparateEntries() {
        XCTAssertEqual(SteroidCatalog.all.count, 12, "compound table")
        XCTAssertEqual(SteroidCatalog.picks.count, 14,
                       "picker entries — 12 compounds, Trenbolone and Masteron "
                       + "contributing two each")
        let labels = SteroidCatalog.picks.map(\.label)
        for expected in ["Trenbolone Acetate", "Trenbolone Enanthate",
                         "Masteron Propionate", "Masteron Enanthate"] {
            XCTAssertTrue(labels.contains(expected), "no picker entry `\(expected)`")
        }
        // And the un-expanded names are GONE — an entry called just "Trenbolone"
        // would be an entry with no ester, which is the state being fixed.
        XCTAssertFalse(labels.contains("Trenbolone"))
        XCTAssertFalse(labels.contains("Masteron (Drostanolone)"))
    }

    /// The label rule, verbatim: `brand + ' ' + ester.label` where brand is
    /// `displayName.split(' (')[0]`. Masteron is the case that proves it —
    /// "Masteron Enanthate", not "Masteron (Drostanolone) Enanthate".
    func testEsterLabelsUseTheWebsBrandRule() {
        let masteron = SteroidCatalog.picks.filter { $0.compound.key == "masteron" }
        XCTAssertEqual(masteron.map(\.label), ["Masteron Propionate", "Masteron Enanthate"])
        // A compound with no parenthetical keeps its whole name.
        let tren = SteroidCatalog.picks.filter { $0.compound.key == "trenbolone" }
        XCTAssertEqual(tren.map(\.label), ["Trenbolone Acetate", "Trenbolone Enanthate"])
        // A compound with no esters is untouched.
        XCTAssertEqual(SteroidCatalog.picks.first?.label, "Oxandrolone (Anavar)")
    }

    /// Every entry the spec offers is one the picker can resolve back, and the
    /// spec's option labels ARE the entry labels.
    func testSpecPickerOptionsMatchTheEntryList() {
        let spec = CalculatorCatalog.spec(for: .steroid)
        guard let field = spec.fields.first(where: { $0.key == "compound" }),
              case let .picker(options, def) = field.kind else {
            return XCTFail("no `compound` picker on the steroid spec")
        }
        XCTAssertEqual(options.map(\.label), SteroidCatalog.picks.map(\.label))
        XCTAssertEqual(options.map(\.value), (0..<SteroidCatalog.picks.count).map { Double(-e) })
        XCTAssertEqual(def, 0, "the shipped default entry")
    }

    // MARK: - 3 · An oral compound gets no injectable inputs and no draw

    /// OXANDROLONE, SPECIFICALLY — the shipped default and the compound in the audit
    /// frame `28-calculator-steroid.png`. `cls:'oral'` (`app.js:8749`),
    /// `canInject: false` here.
    ///
    /// The screen used to show it a vial strength and a syringe barrel and answer
    /// 0.75 mL / 75 units. The volume is the half that matters most: `DoseVolume`
    /// publishes `drawMl` into `dose_log`, so a draw for a tablet is a wrong number
    /// in the DATABASE, not only on the screen.
    func testOxandroloneProducesNoDrawVolumeAndNoUnits() {
        let r = evaluate(values(picking: "Oxandrolone (Anavar)",
                                ["oralDose": 50, "tabMg": 10, "oralSplit": 2]))
        XCTAssertTrue(r.isValid)
        XCTAssertNil(r.drawMl, "an oral compound has no draw volume")
        XCTAssertNil(r.scheduleLine, "an oral compound has no injection schedule")
        for r0 in r.rows {
            XCTAssertFalse(r0.value.contains("mL"),
                           "`\(r0.label)` reads `\(r0.value)` — millilitres for a tablet")
            XCTAssertFalse(r0.label.lowercased().contains("unit"),
                           "`\(r0.label)` is a syringe row on an oral result")
            XCTAssertFalse(r0.label.lowercased().contains("inject"),
                           "`\(r0.label)` is an injection row on an oral result")
        }
    }

    /// And it answers the question a tablet actually asks. 50 mg/day split over two
    /// doses at 10 mg/tab is 25 mg and 2.5 tablets per dose. Labels, order and
    /// decimals are the web's oral KPI card (`app.js:8979-8982`).
    func testOxandroloneReturnsTabletsPerDose() {
        let r = evaluate(values(picking: "Oxandrolone (Anavar)",
                                ["oralDose": 50, "tabMg": 10, "oralSplit": 2]))
        XCTAssertEqual(r.rows.map(\.label), ["Tablets", "Per Dose", "Daily"])
        XCTAssertEqual(row(r, "Tablets"), "2.50 tab")
        XCTAssertEqual(row(r, "Per Dose"), "25.0 mg")
        XCTAssertEqual(row(r, "Daily"), "50.0 mg")
        XCTAssertEqual(r.dosePerInjection?.value ?? -1, 25, accuracy: acc)
        XCTAssertEqual(r.dosePerInjection?.unit, "mg")
    }

    /// THE NUMBER THAT USED TO BE SHOWN, kept as arithmetic so the claim in the task
    /// is checkable rather than remembered. The old path ran the spec's own
    /// injectable defaults — 200 mg/mL, 300 mg/week, every 3.5 days — through
    /// `steroidInjectable` for Oxandrolone and got 0.75 mL / 75 units. Nothing
    /// reaches those numbers from the oral branch now, and this test only records
    /// what the branch is protecting against.
    func testTheOralDefectsOldNumbersAreNoLongerReachable() {
        let old = CalculatorEngine.steroidInjectable(strength: 200, mgWeek: 300, mode: .ndays,
                                                     nDays: 3.5, injPerWeek: 0, mlDrawn: 0,
                                                     esterFactor: 1)
        XCTAssertEqual(old.mlPerInj, 0.75, accuracy: acc, "the 0.75 mL in the audit frame")
        XCTAssertEqual(old.unitsPerInj, 75, accuracy: acc, "the 75 units in the audit frame")

        let now = evaluate(values(picking: "Oxandrolone (Anavar)"))
        XCTAssertNil(now.drawMl)
        XCTAssertFalse(now.rows.contains { $0.value.contains("0.750") })
    }

    /// ALL FIVE `cls:'oral'` compounds, not only the default. The web's list is
    /// Anavar, Dianabol, Tbol, Anadrol, Superdrol — and Winstrol is `'oral|injectable'`,
    /// which the web opens on INJECTABLE (`form = canInject ? 'injectable' : 'oral'`),
    /// so it belongs on the other side of this test, not this one.
    func testEveryOralOnlyCompoundEvaluatesAsAnOral() {
        let expectedOralKeys: Set<String> = ["anavar", "dianabol", "tbol", "anadrol", "superdrol"]
        let actualOralKeys = Set(SteroidCatalog.all.filter { !$0.canInject }.map(\.key))
        XCTAssertEqual(actualOralKeys, expectedOralKeys,
                       "the `cls:'oral'` set has moved away from app.js:8748-8761")

        for pick in SteroidCatalog.picks where !pick.canInject {
            let r = evaluate(values(picking: pick.label,
                                    ["oralDose": 40, "tabMg": 10, "oralSplit": 1]))
            XCTAssertNil(r.drawMl, "\(pick.label) produced a draw volume")
            XCTAssertEqual(r.rows.first?.label, "Tablets", "\(pick.label) result shape")
        }
    }

    /// The other side of the same rule: every injectable entry still produces a draw.
    /// A fix that turned the whole calculator oral would pass the test above.
    func testEveryInjectableEntryStillProducesADraw() {
        for pick in SteroidCatalog.picks where pick.canInject {
            let r = evaluate(values(picking: pick.label,
                                    ["strength": 200, "mgWeek": 300, "nDays": 3.5]))
            XCTAssertNotNil(r.drawMl, "\(pick.label) produced no draw volume")
            XCTAssertEqual(r.drawMl ?? -1, 0.75, accuracy: acc, "\(pick.label) draw")
        }
        XCTAssertEqual(SteroidCatalog.picks.filter(\.canInject).count, 9,
                       "7 injectable compounds, two of them contributing two esters, "
                       + "plus Winstrol which is `'oral|injectable'`")
    }

    // MARK: - 4 · The FORM: which fields the screen offers

    /// `CalculatorScreen.shouldShow` delegates to this, so this is the rule the user
    /// meets. The four injectable inputs and the three oral ones are never both
    /// offered, and never both withheld.
    func testTheFormOffersExactlyOneSetOfInputsPerCompound() {
        let injectableKeys = ["strength", "mgWeek", "nDays", "syringeMl"]
        let oralKeys = ["oralDose", "tabMg", "oralSplit"]

        for (idx, pick) in SteroidCatalog.picks.enumerated() {
            for key in injectableKeys {
                XCTAssertEqual(SteroidCatalog.showsField(key, forPickAt: idx), pick.canInject,
                               "`\(key)` on \(pick.label)")
            }
            for key in oralKeys {
                XCTAssertEqual(SteroidCatalog.showsField(key, forPickAt: idx), !pick.canInject,
                               "`\(key)` on \(pick.label)")
            }
            // The compound picker itself is on every form.
            XCTAssertTrue(SteroidCatalog.showsField("compound", forPickAt: idx))
        }
    }

    /// Named separately because it is the sentence in T-44: a `canInject: false`
    /// compound is offered NO injectable input at all.
    func testAnOralOnlyCompoundIsOfferedNoInjectableInput() {
        guard let idx = SteroidCatalog.picks.firstIndex(where: { $0.compound.key == "anavar" }) else {
            return XCTFail("no Oxandrolone entry")
        }
        XCTAssertFalse(SteroidCatalog.pick(at: idx).canInject)
        for key in ["strength", "mgWeek", "nDays", "syringeMl"] {
            XCTAssertFalse(SteroidCatalog.showsField(key, forPickAt: idx),
                           "Oxandrolone is still offered `\(key)`")
        }
        for key in ["oralDose", "tabMg", "oralSplit"] {
            XCTAssertTrue(SteroidCatalog.showsField(key, forPickAt: idx))
        }
    }

    /// An index from a config a different build wrote must not blank a dosing
    /// screen or crash it — it falls back to the first entry.
    func testAnOutOfRangePickIndexFallsBackRatherThanFailing() {
        XCTAssertEqual(SteroidCatalog.pick(at: 99).id, SteroidCatalog.picks[0].id)
        XCTAssertEqual(SteroidCatalog.pick(at: -1).id, SteroidCatalog.picks[0].id)
    }

    // MARK: - 5 · The saved config must not have moved

    /// THE TRAP THIS TASK WAS WARNED ABOUT, and the reason the oral fields are named
    /// `oralDose`/`tabMg`/`oralSplit` and then re-emitted as `dose`/`tab`/`split`.
    ///
    /// `saved_dosages` de-duplicates on the WHOLE config, so a key set that drifted by
    /// one would re-fingerprint every future steroid row against the rows already in
    /// production. These are the thirteen keys `steroidConfig()` writes
    /// (`app.js:8866`), and they are the same thirteen as before T-44.
    @MainActor
    func testConfigKeySetIsUnchangedByTheFormSplit() {
        let webKeys: Set<String> = ["slug", "form", "mode", "esterKey", "strength", "mgWeek",
                                    "nDays", "injPerWeek", "mlDrawn", "syringeMl",
                                    "dose", "tab", "split"]
        let vm = CalculatorViewModel(slug: .steroid)
        guard case let .object(obj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(Set(obj.keys), webKeys, "steroid config key set")
        // The iOS-only field names must NOT appear.
        for iosOnly in ["compound", "oralDose", "tabMg", "oralSplit"] {
            XCTAssertNil(obj[iosOnly], "`\(iosOnly)` leaked into the saved config")
        }
        // …and the same set on an INJECTABLE compound, since the two forms take
        // different branches through `configExtras`.
        var v = vm.values
        guard let tren = SteroidCatalog.picks.firstIndex(where: { $0.label == "Trenbolone Enanthate" })
        else { return XCTFail("no Trenbolone Enanthate entry") }
        v.numbers["compound"] = Double(tren)
        vm.values = v
        guard case let .object(inj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(Set(inj.keys), webKeys, "steroid config key set, injectable form")
    }

    /// The oral trio stay STRINGS, because that is what they are on the web — raw
    /// `<input>` state (`app.js:8810-8812`). `"50"` and `50` are two different
    /// protocols to a whole-config unique index.
    @MainActor
    func testTheOralTrioAreSavedAsStringsAndTheFormIsDerivedFromTheCompound() {
        let vm = CalculatorViewModel(slug: .steroid)   // opens on Oxandrolone, an oral
        var v = vm.values
        v.numbers["oralDose"] = 50
        v.numbers["tabMg"] = 10
        v.numbers["oralSplit"] = 2
        vm.values = v
        guard case let .object(obj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(obj["form"]?.string, "oral",
                       "`form` is `canInject ? 'injectable' : 'oral'` — app.js:8789")
        XCTAssertEqual(obj["slug"]?.string, "anavar")
        XCTAssertEqual(obj["esterKey"]?.string, "")
        XCTAssertEqual(obj["dose"], JSONValue.string("50"))
        XCTAssertEqual(obj["tab"], JSONValue.string("10"))
        XCTAssertEqual(obj["split"], JSONValue.string("2"))
        // An oral row must not carry a weekly INJECTABLE dose. The web's oral page
        // never touches that state and saves 0 (`useState(0)`, `app.js:8804`).
        XCTAssertEqual(obj["mgWeek"]?.double ?? -1, 0, accuracy: acc)
        XCTAssertEqual(obj["strength"]?.double ?? -1, 200, accuracy: acc,
                       "`d.defaultConc || 200` — app.js:8797")
    }

    /// An injectable save writes `form: "injectable"`, the picked ESTER, and the
    /// injectable trio untouched — byte-for-byte what this build wrote before T-44.
    @MainActor
    func testAnInjectableSaveCarriesThePickedEsterKey() {
        let vm = CalculatorViewModel(slug: .steroid)
        var v = vm.values
        guard let tren = SteroidCatalog.picks.firstIndex(where: { $0.label == "Trenbolone Enanthate" })
        else { return XCTFail("no Trenbolone Enanthate entry") }
        v.numbers["compound"] = Double(tren)
        vm.values = v
        guard case let .object(obj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(obj["slug"]?.string, "trenbolone")
        XCTAssertEqual(obj["esterKey"]?.string, "enanthate",
                       "`esters.first` would write `acetate` — the 22.5 % defect, saved")
        XCTAssertEqual(obj["form"]?.string, "injectable")
        XCTAssertEqual(obj["mode"]?.string, "ndays")
        // Unchanged from the previous build.
        XCTAssertEqual(obj["dose"], JSONValue.string(""))
        XCTAssertEqual(obj["tab"], JSONValue.string(""))
        XCTAssertEqual(obj["split"], JSONValue.string("1"))
    }

    // MARK: - 6 · The round trip, which is where a saved dose is re-derived

    /// `DoseVolume.perInjection` re-evaluates a SAVED config long after the screen is
    /// gone, through `CalculatorCatalog.values(fromConfig:)`. Matching on `slug`
    /// alone put every Trenbolone row back on Acetate, so a Tren E protocol saved
    /// correctly still logged the wrong active weekly.
    func testASavedTrenEnanthateConfigReopensOnEnanthate() {
        let config = JSONValue.object([
            "slug": .string("trenbolone"), "esterKey": .string("enanthate"),
            "form": .string("injectable"), "mode": .string("ndays"),
            "strength": .number(200), "mgWeek": .number(300), "nDays": .number(3.5),
            "injPerWeek": .number(2), "mlDrawn": .number(0.5), "syringeMl": .number(1),
            "dose": .string(""), "tab": .string(""), "split": .string("1"),
        ])
        let v = CalculatorCatalog.values(fromConfig: config, slug: .steroid)
        let pick = SteroidCatalog.pick(at: Int(v.number("compound")))
        XCTAssertEqual(pick.label, "Trenbolone Enanthate")
        XCTAssertEqual(row(evaluate(v), "Active weekly"), "213.0 mg")
    }

    /// A config written before the ester was selectable carries `esterKey: ""`. It
    /// must still resolve — to the compound's first entry, which is what it meant.
    func testAConfigWithNoEsterKeyResolvesToTheFirstEster() {
        let config = JSONValue.object([
            "slug": .string("trenbolone"), "esterKey": .string(""),
            "strength": .number(100), "mgWeek": .number(300), "nDays": .number(3.5),
        ])
        let v = CalculatorCatalog.values(fromConfig: config, slug: .steroid)
        XCTAssertEqual(SteroidCatalog.pick(at: Int(v.number("compound"))).label,
                       "Trenbolone Acetate")
    }

    /// And the oral trio survive the round trip, string → number → string.
    func testASavedOralConfigReopensWithItsTabletFields() {
        let config = JSONValue.object([
            "slug": .string("anadrol"), "esterKey": .string(""), "form": .string("oral"),
            "mode": .string("ndays"), "dose": .string("100"), "tab": .string("50"),
            "split": .string("2"),
        ])
        let v = CalculatorCatalog.values(fromConfig: config, slug: .steroid)
        XCTAssertEqual(v.number("oralDose"), 100, accuracy: acc)
        XCTAssertEqual(v.number("tabMg"), 50, accuracy: acc)
        XCTAssertEqual(v.number("oralSplit"), 2, accuracy: acc)
        let r = evaluate(v)
        XCTAssertNil(r.drawMl)
        XCTAssertEqual(row(r, "Tablets"), "1.00 tab")   // 100 ÷ 2 = 50 mg = one 50 mg tab
    }

    /// A saved ORAL protocol must publish no volume into `dose_log`. This is the
    /// consumer the nil `drawMl` exists for.
    func testASavedOralProtocolPublishesNoInjectionVolume() {
        let d = dosage(id: "oral-1", type: "steroid", config: """
        {"slug":"anavar","esterKey":"","form":"oral","mode":"ndays",
         "dose":"50","tab":"10","split":"2"}
        """)
        XCTAssertNil(DoseVolume.perInjectionMl(for: d),
                     "a tablet has no draw volume and must not write one")
        XCTAssertEqual(DoseVolume.perInjection(for: d).dose?.value ?? -1, 25, accuracy: acc)
    }

    // MARK: - 7 · Defaults

    /// The screen still opens on the compound it opened on, so the audit frame is a
    /// before/after of the SAME compound. The web's dropdown order is different
    /// (`IB_STEROID_ORDER`, `app.js:8762`, starting at `trenbolone`) — that moves the
    /// shipped default and what an untouched save writes, so it is reported against
    /// T-44 rather than taken here.
    @MainActor
    func testTheScreenStillOpensOnOxandrolone() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(SteroidCatalog.pick(at: Int(vm.values.number("compound"))).label,
                       "Oxandrolone (Anavar)")
        XCTAssertFalse(vm.result.rows.contains { $0.value.contains("mL") },
                       "the screen opens showing millilitres for a tablet")
    }

    /// The oral dose opens at 0 — the web's field opens EMPTY (`useState('')`,
    /// `app.js:8810`) and 0 is this control's own empty reading, so the screen
    /// invents no dose on a calculator whose own source says it carries "no doses,
    /// cycles, or regimens" (`app.js:8745-8746`).
    @MainActor
    func testOralDefaultsInventNoDose() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(vm.values.number("oralDose"), 0, accuracy: acc)
        XCTAssertEqual(vm.values.number("tabMg"), 10, accuracy: acc)    // `defTab` fallback, 8798
        XCTAssertEqual(vm.values.number("oralSplit"), 1, accuracy: acc) // `useState('1')`, 8812
    }

    /// The injectable defaults are untouched, so an untouched injectable save writes
    /// exactly what the previous build wrote.
    @MainActor
    func testInjectableDefaultsAreUnchanged() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc)
        XCTAssertEqual(vm.values.number("mgWeek"), 300, accuracy: acc)
        XCTAssertEqual(vm.values.number("nDays"), 3.5, accuracy: acc)
    }
}
