import XCTest
@testable import InjectBuddy

// ─── SteroidSeedingTests  (T-96) ─────────────────────────────────────────────
//
// `SteroidCompound.defaultConc(for:)` and `SteroidCompound.defaultTab` existed,
// were correct, and were READ BY NOTHING. The vial strength stayed on the spec's
// 200 mg/mL and the tablet strength on 10 mg/tab whatever compound was picked.
//
// THE LIVE WRONG NUMBER, and the case this file exists for:
//
//     ANADROL SHIPS 50 mg TABLETS — `defaultTab:50`, `app.js:8757`, whose own
//     `presentation` field reads '50 mg tabs'. Pick Anadrol, leave the tablet
//     strength on 10, and the Tablets KPI reads FIVE TIMES TOO HIGH.
//
// A test of the arithmetic is green through that: `steroidOral` divides correctly,
// it is just handed a tablet that does not exist. So the tests here pin WHAT THE
// FIELD HOLDS after a pick, not what the formula does with it — the same shape as
// `SteroidFormParityTests`, and for the same reason.
//
// ── AND THE OTHER HALF: A SEEDER THAT ALWAYS FIRES ───────────────────────────
// "It seeded" is the easy half. A seeder wired into a render — or one that fires
// on its own output — passes every seeding test above while overwriting the user
// mid-keystroke and looping. §4 pins the negative: seeding fires on a PICKER MOVE
// and on nothing else, and it is a fixed point on its own result.
//
// THE EXPECTATIONS BELOW ARE TRANSCRIBED FROM `public/app.js`, NOT FROM THE SWIFT.
// Read on 2026-08-04 from `origin/feature/dosage-status-model` at `~/injectbuddy`
// (`git show origin/feature/dosage-status-model:public/app.js`):
//
//   • `IB_STEROIDS`                8748-8761  (`defaultConc` / `defaultTab` per compound)
//   • `anadrol … defaultTab:50`    8757       ← the live harm
//   • `defConc` / `defTab`         8797-8798  (`d.defaultConc || 200`, `d.defaultTab || 10`)
//   • `useState(defConc)`          8803       (vial strength seeded at mount)
//   • `useState(String(defTab))`   8811       (tablet strength seeded at mount)
//   • the re-seed effect           8813       `useEffect(… setStrength(defConc) …,
//                                              [esterKey, form])` — STRENGTH ONLY
//   • the compound dropdown        8936-8941  (same slug → `setEsterKey`; different
//                                              slug → `window.location.href`, i.e. a
//                                              REMOUNT, which re-runs 8803 and 8811)
//   • `steroidConfig()`            8866       (the 13 saved keys — must not move)
//
// Re-derive them from the source, never from this file, if they ever have to move.

final class SteroidSeedingTests: XCTestCase {

    private let acc = 0.001

    // MARK: - Helpers

    private func index(of label: String,
                       file: StaticString = #filePath, line: UInt = #line) -> Int {
        guard let i = SteroidCatalog.picks.firstIndex(where: { $0.label == label }) else {
            XCTFail("No compound picker entry labelled `\(label)`", file: file, line: line)
            return 0
        }
        return i
    }

    /// `values` with the compound picker moved to `label`'s entry — exactly what the
    /// picker control writes, and nothing else.
    private func picking(_ label: String, in values: CalculatorValues,
                         file: StaticString = #filePath, line: UInt = #line) -> CalculatorValues {
        var v = values
        v.numbers["compound"] = Double(index(of: label, file: file, line: line))
        return v
    }

    private func row(_ r: CalculatorResult, _ label: String) -> String? {
        r.rows.first { $0.label == label }?.value
    }

    // MARK: - 1 · ANADROL. The live harm, by name.

    /// THE HEADLINE CASE. Anadrol's `defaultTab` is 50 (`app.js:8757`).
    ///
    /// The screen opens on Oxandrolone at 10 mg/tab, which is Oxandrolone's own
    /// default and is why the defect was invisible from the opening frame: the
    /// tablet strength is only wrong once you pick something else.
    @MainActor
    func testPickingAnadrolSeedsFiftyMilligramTablets() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(vm.values.number("tabMg"), 10, accuracy: acc,
                       "the form opens on Oxandrolone, `defaultTab:10`")

        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)

        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc,
                       "Anadrol ships 50 mg tablets — `defaultTab:50`, app.js:8757. "
                       + "10 is the `d.defaultTab || 10` fallback the field was stuck on.")
    }

    /// AND THE NUMBER THE USER ACTS ON. 100 mg/day of Anadrol in one dose is TWO
    /// 50 mg tablets. Against a 10 mg tablet the same screen said ten.
    ///
    /// Both readings are asserted, so the "5× too high" claim in T-96 is checkable
    /// here rather than remembered.
    @MainActor
    func testAnadrolsTabletCountIsNoLongerFiveTimesTooHigh() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        var v = vm.values
        v.numbers["oralDose"] = 100
        v.numbers["oralSplit"] = 1
        vm.values = v

        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc,
                       "typing a dose must not disturb the seeded tablet strength")
        XCTAssertTrue(vm.result.isValid)
        XCTAssertEqual(row(vm.result, "Tablets"), "2.00 tab",
                       "100 mg/day at 50 mg/tab is two tablets")
        XCTAssertEqual(row(vm.result, "Per Dose"), "100.0 mg")

        // What the same inputs read before T-96, stated as arithmetic.
        let stuck = CalculatorEngine.steroidOral(doseMgPerDay: 100, tabMg: 10, split: 1)
        XCTAssertEqual(stuck.tabsPerDose, 10, accuracy: acc)
        XCTAssertEqual(stuck.tabsPerDose / 2, 5, accuracy: acc, "the factor T-96 names")
    }

    // MARK: - 2 · One compound of each kind, and then all fourteen

    /// AN ORAL. Superdrol is 10 mg/tab, so switching Anadrol → Superdrol must move
    /// the field BACK DOWN — a seeder that only ever raised it would pass §1.
    @MainActor
    func testAnOralCompoundChangeReseedsTheTabletStrengthBothWays() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc)

        vm.values = picking("Superdrol (Methasterone)", in: vm.values)
        XCTAssertEqual(vm.values.number("tabMg"), 10, accuracy: acc,
                       "`superdrol … defaultTab:10` — app.js:8760")

        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc)
    }

    /// AN INJECTABLE. The vial strength is the same defect on the other form:
    /// Winstrol is a 50 mg/mL suspension and Equipoise is 250 mg/mL, and both sat
    /// on 200 whatever was picked.
    @MainActor
    func testAnInjectableCompoundChangeReseedsTheVialStrength() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc)

        vm.values = picking("Winstrol (Stanozolol)", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 50, accuracy: acc,
                       "`winstrol … defaultConc:50` — app.js:8755")

        vm.values = picking("Equipoise (Boldenone Undecylenate)", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 250, accuracy: acc,
                       "`equipoise … defaultConc:250` — app.js:8756")

        vm.values = picking("Primobolan (Methenolone Enanthate)", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 100, accuracy: acc,
                       "`primobolan … defaultConc:100` — app.js:8759")
    }

    /// A wrong vial strength is a wrong DRAW VOLUME, which `DoseVolume` publishes
    /// into `dose_log`. 300 mg/week of Winstrol every 3.5 days is 150 mg, and at
    /// 50 mg/mL that is 3.00 mL — not the 0.75 mL a stuck 200 mg/mL reported.
    @MainActor
    func testTheSeededVialStrengthReachesTheDrawVolume() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Winstrol (Stanozolol)", in: vm.values)
        XCTAssertEqual(vm.result.drawMl ?? -1, 3.0, accuracy: acc,
                       "150 mg per injection ÷ 50 mg/mL")

        let stuck = CalculatorEngine.steroidInjectable(strength: 200, mgWeek: 300, mode: .ndays,
                                                       nDays: 3.5, injPerWeek: 0, mlDrawn: 0,
                                                       esterFactor: 1)
        XCTAssertEqual(stuck.mlPerInj, 0.75, accuracy: acc, "what a stuck 200 mg/mL reported")
    }

    /// ALL FOURTEEN PICKER ENTRIES against the web's table, so a compound added or
    /// edited later is checked rather than assumed. `defConc` is
    /// `ev ? ev.defaultConc : (d.defaultConc || 200)` (8797) and `defTab` is
    /// `d.defaultTab || 10` (8798) — the fallbacks are part of the expectation.
    func testEveryPickerEntrySeedsTheWebsDefaults() {
        let web: [String: (conc: Double, tab: Double)] = [
            "Oxandrolone (Anavar)":                 (200, 10),   // 8749  defaultTab:10
            "Trenbolone Acetate":                   (100, 10),   // 8750  ester defaultConc:100
            "Trenbolone Enanthate":                 (200, 10),   // 8750  ester defaultConc:200
            "Dianabol (Metandienone)":              (200, 10),   // 8751  defaultTab:10
            "Nandrolone Phenylpropionate (NPP)":    (100, 10),   // 8752  defaultConc:100
            "Turinabol (Tbol)":                     (200, 10),   // 8753  defaultTab:10
            "Deca (Nandrolone Decanoate)":          (200, 10),   // 8754  defaultConc:200
            "Winstrol (Stanozolol)":                ( 50, 10),   // 8755  both declared
            "Equipoise (Boldenone Undecylenate)":   (250, 10),   // 8756  defaultConc:250
            "Anadrol (Oxymetholone)":               (200, 50),   // 8757  defaultTab:50
            "Masteron Propionate":                  (100, 10),   // 8758  ester defaultConc:100
            "Masteron Enanthate":                   (200, 10),   // 8758  ester defaultConc:200
            "Primobolan (Methenolone Enanthate)":   (100, 10),   // 8759  defaultConc:100
            "Superdrol (Methasterone)":             (200, 10),   // 8760  defaultTab:10
        ]
        XCTAssertEqual(Set(web.keys), Set(SteroidCatalog.picks.map(\.label)),
                       "the picker entry list has moved away from this table")

        for pick in SteroidCatalog.picks {
            guard let expected = web[pick.label] else { continue }
            XCTAssertEqual(pick.defaultConc, expected.conc, accuracy: acc,
                           "`defConc` for \(pick.label)")
            XCTAssertEqual(pick.defaultTab, expected.tab, accuracy: acc,
                           "`defTab` for \(pick.label)")
        }
        // Anadrol is the only entry whose tablet is not the fallback, which is
        // exactly why the fallback looked correct for as long as it did.
        XCTAssertEqual(SteroidCatalog.picks.filter { $0.defaultTab != 10 }.map(\.label),
                       ["Anadrol (Oxymetholone)"])
    }

    // MARK: - 3 · The ester — the web's SECOND mechanism, and a narrower one

    /// `useEffect(function () { setStrength(defConc); }, [esterKey, form])`
    /// (`app.js:8813`). Trenbolone Acetate is 100 mg/mL and Enanthate is 200, and on
    /// iOS the two are separate picker entries, so this is a picker move that stays
    /// on one compound.
    @MainActor
    func testAnEsterChangeReseedsTheConcentration() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Trenbolone Acetate", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 100, accuracy: acc)

        vm.values = picking("Trenbolone Enanthate", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc,
                       "the ester carries its own `defaultConc` — app.js:8750")

        // Masteron is the second ester compound, 100 → 200 the same way (8758).
        vm.values = picking("Masteron Propionate", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 100, accuracy: acc)
        vm.values = picking("Masteron Enanthate", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc)
    }

    /// AND IT MOVES NOTHING ELSE. `tab` is deliberately not in the effect at 8813 —
    /// the two ester compounds are `cls:'injectable'` and carry no `defaultTab`, so
    /// an ester flip that also wrote a tablet strength would write a fallback of 10
    /// the web never writes there.
    @MainActor
    func testAnEsterChangeDoesNotTouchTheTabletStrength() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Trenbolone Acetate", in: vm.values)
        var v = vm.values
        v.numbers["tabMg"] = 25          // a value only the user could have put there
        vm.values = v

        vm.values = picking("Trenbolone Enanthate", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc, "the ester DID re-seed")
        XCTAssertEqual(vm.values.number("tabMg"), 25, accuracy: acc,
                       "an ester flip re-seeds `strength` alone — app.js:8813")
    }

    // MARK: - 4 · WHEN IT MUST NOT FIRE. The half that a seeding test cannot see.

    /// The rule reads the PICKER INDEX and nothing else. An identical bag is not a
    /// transition, which is what stops a render-driven caller from re-seeding
    /// forever.
    func testReseedingReturnsNilWhenTheCompoundDidNotChange() {
        let spec = CalculatorCatalog.spec(for: .steroid)
        let v = CalculatorValues.defaults(for: spec.fields)
        XCTAssertNil(SteroidCatalog.reseeding(from: v, to: v))

        // Every other field moving, one at a time, is still not a transition.
        for key in ["strength", "tabMg", "oralDose", "oralSplit", "mgWeek", "nDays", "syringeMl"] {
            var edited = v
            edited.numbers[key] = v.number(key) + 7
            XCTAssertNil(SteroidCatalog.reseeding(from: v, to: edited),
                         "editing `\(key)` re-seeded the strengths")
        }
    }

    /// A FIXED POINT ON ITS OWN OUTPUT. The ViewModel writes the seeded bag back,
    /// which fires the same `didSet` again; if that second pass could also seed, the
    /// screen would loop. The re-entrancy guard covers it, and so does this.
    func testReseedingIsAFixedPointOnItsOwnResult() {
        let spec = CalculatorCatalog.spec(for: .steroid)
        let opening = CalculatorValues.defaults(for: spec.fields)
        let moved = picking("Anadrol (Oxymetholone)", in: opening)

        guard let once = SteroidCatalog.reseeding(from: opening, to: moved) else {
            return XCTFail("the Anadrol pick did not re-seed at all")
        }
        XCTAssertEqual(once.number("tabMg"), 50, accuracy: acc)
        XCTAssertNil(SteroidCatalog.reseeding(from: once, to: once),
                     "the seeder fires on its own output — this is an infinite loop")
        XCTAssertNil(SteroidCatalog.reseeding(from: moved, to: once),
                     "the write-back itself must not look like another transition")
    }

    /// A VALUE THE USER TYPED SURVIVES EVERYTHING BUT A COMPOUND CHANGE. This is the
    /// difference between seeding on a transition and seeding on a pass: a seeder
    /// hung off a render passes §1 and §2 and overwrites this on the next keystroke.
    @MainActor
    func testATypedStrengthSurvivesEveryChangeExceptThePicker() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Deca (Nandrolone Decanoate)", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc)

        var v = vm.values
        v.numbers["strength"] = 150      // this vial is not the usual one
        vm.values = v
        XCTAssertEqual(vm.values.number("strength"), 150, accuracy: acc,
                       "typing in the strength field re-seeded it away")

        // Every other input on the form, moved in turn.
        for (key, value) in [("mgWeek", 500.0), ("nDays", 7.0), ("syringeMl", 3.0)] {
            var edit = vm.values
            edit.numbers[key] = value
            vm.values = edit
            XCTAssertEqual(vm.values.number("strength"), 150, accuracy: acc,
                           "editing `\(key)` re-seeded the strength")
        }
    }

    /// …AND A COMPOUND CHANGE DOES REPLACE IT, which is the web's behaviour (the
    /// navigation at 8940 rebuilds the page) and the right one: a vial strength is a
    /// fact about the compound in front of you, not a preference to carry over.
    ///
    /// Stated as its own test because it is the decision, not a side effect.
    @MainActor
    func testACompoundChangeReplacesATypedStrength() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Deca (Nandrolone Decanoate)", in: vm.values)
        var v = vm.values
        v.numbers["strength"] = 150
        v.numbers["tabMg"] = 25
        vm.values = v

        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc,
                       "Anadrol has no `defaultConc`, so `d.defaultConc || 200`")
        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc)
    }

    /// The dose the user typed is NOT thrown away. The web's navigation resets it
    /// because the whole component is rebuilt; iOS is one screen, and discarding a
    /// dose because the compound was corrected is a worse screen, not a more
    /// faithful one. A deliberate, named deviation — change it here if it changes.
    @MainActor
    func testACompoundChangeKeepsTheDoseTheUserTyped() {
        let vm = CalculatorViewModel(slug: .steroid)
        var v = vm.values
        v.numbers["oralDose"] = 40
        v.numbers["oralSplit"] = 2
        vm.values = v

        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        XCTAssertEqual(vm.values.number("oralDose"), 40, accuracy: acc)
        XCTAssertEqual(vm.values.number("oralSplit"), 2, accuracy: acc)
        XCTAssertEqual(vm.values.number("tabMg"), 50, accuracy: acc, "…but the tablet moved")
    }

    /// The published result is the evaluation of the SETTLED bag, not of the bag
    /// halfway through. This is the invariant the re-entrancy guard buys, asserted
    /// on the screen's own output rather than on the rule in isolation.
    @MainActor
    func testTheResultIsEvaluatedAgainstTheSeededValues() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        var v = vm.values
        v.numbers["oralDose"] = 150
        v.numbers["oralSplit"] = 3
        vm.values = v

        XCTAssertEqual(vm.result,
                       CalculatorEngine.evaluate(slug: .steroid, values: vm.values, scale: .u100),
                       "the published result does not match the values on screen")
        XCTAssertEqual(row(vm.result, "Tablets"), "1.00 tab")   // 50 mg ÷ 50 mg/tab
    }

    /// AND NO OTHER CALCULATOR IS SEEDED. Fourteen of the fifteen have no compound
    /// picker, and a rule that leaked into them would move a dose on a screen this
    /// task never looked at.
    @MainActor
    func testTheOtherCalculatorsAreUntouchedByTheSeeder() {
        for slug in CalculatorSlug.allCases where slug != .steroid {
            let vm = CalculatorViewModel(slug: slug)
            let opening = vm.values
            guard let first = vm.spec.fields.first(where: {
                if case .number = $0.kind { return true } else { return false }
            }) else { continue }
            var v = vm.values
            v.numbers[first.key] = v.number(first.key) + 1
            vm.values = v

            for (key, was) in opening.numbers where key != first.key {
                XCTAssertEqual(vm.values.number(key), was, accuracy: acc,
                               "\(slug) moved `\(key)` when `\(first.key)` was edited")
            }
        }
    }

    // MARK: - 5 · The saved config. Values may move; KEYS MAY NOT.

    /// `saved_dosages` de-duplicates on the WHOLE config, so a key set that drifted
    /// by one would re-fingerprint every future steroid row against the rows already
    /// in production. Seeding changes VALUES. These are the thirteen keys
    /// `steroidConfig()` writes (`app.js:8866`), before and after a seed.
    ///
    /// THE VALUES DO MOVE — a Winstrol save now writes `strength: 50` where it wrote
    /// 200 — and that was measured against production before it was taken. Queried
    /// 2026-08-04: `saved_dosages` holds **9 steroid rows, and none of them is an iOS
    /// row.** Every one carries `tab: "10"`, which is the web's `String(defTab)`
    /// (`app.js:8811`); an iOS injectable save writes `tab: ""` (`configExtras`), and
    /// there are zero of those. So there is nothing for the new values to
    /// re-fingerprint against, and the 200 they replace was the wrong number anyway.
    @MainActor
    func testTheConfigKeySetIsUnchangedBySeeding() {
        let webKeys: Set<String> = ["slug", "form", "mode", "esterKey", "strength", "mgWeek",
                                    "nDays", "injPerWeek", "mlDrawn", "syringeMl",
                                    "dose", "tab", "split"]
        let vm = CalculatorViewModel(slug: .steroid)
        for label in ["Anadrol (Oxymetholone)", "Winstrol (Stanozolol)",
                      "Trenbolone Enanthate", "Oxandrolone (Anavar)"] {
            vm.values = picking(label, in: vm.values)
            guard case let .object(obj) = vm.configJSON() else {
                return XCTFail("steroid config is not an object on \(label)")
            }
            XCTAssertEqual(Set(obj.keys), webKeys, "steroid config key set on \(label)")
            for iosOnly in ["compound", "oralDose", "tabMg", "oralSplit"] {
                XCTAssertNil(obj[iosOnly], "`\(iosOnly)` leaked into the config on \(label)")
            }
        }
    }

    /// THE SHIPPED FINGERPRINT IS UNMOVED. Seeding now runs at `init` as well, and
    /// on the opening compound it is the IDENTITY — Oxandrolone's defaults ARE the
    /// spec's 200 mg/mL and 10 mg/tab. So an untouched save writes exactly the bytes
    /// it wrote before T-96, and no existing row is re-fingerprinted.
    ///
    /// If the picker order ever moves to the web's (`IB_STEROID_ORDER`, 8762) this
    /// test is the one that says so, because that IS a data decision.
    @MainActor
    func testAnUntouchedSteroidSaveIsByteForByteWhatItWasBefore() {
        let vm = CalculatorViewModel(slug: .steroid)
        XCTAssertEqual(SteroidCatalog.pick(at: Int(vm.values.number("compound"))).label,
                       "Oxandrolone (Anavar)", "the opening compound moved")
        XCTAssertEqual(vm.values.number("strength"), 200, accuracy: acc)
        XCTAssertEqual(vm.values.number("tabMg"), 10, accuracy: acc)

        guard case let .object(obj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(obj["strength"]?.double ?? -1, 200, accuracy: acc)
        XCTAssertEqual(obj["tab"], JSONValue.string("10"))
        XCTAssertEqual(obj["form"]?.string, "oral")
        XCTAssertEqual(obj["slug"]?.string, "anavar")

        // And the seed at `init` really is the identity on this entry, which is the
        // whole reason it is safe to run.
        let spec = CalculatorCatalog.spec(for: .steroid)
        let raw = CalculatorValues.defaults(for: spec.fields)
        XCTAssertEqual(SteroidCatalog.seeding(raw, forPickAt: Int(raw.number("compound")),
                                              includingTablet: true),
                       raw, "the opening seed is no longer the identity")
    }

    /// An ORAL save carries the SEEDED tablet strength through to the string the web
    /// stores. This is the wrong number leaving the screen and reaching the database
    /// — `"50"`, not `"10"`.
    @MainActor
    func testASavedAnadrolProtocolCarriesTheFiftyMilligramTablet() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        var v = vm.values
        v.numbers["oralDose"] = 100
        vm.values = v

        guard case let .object(obj) = vm.configJSON() else {
            return XCTFail("steroid config is not an object")
        }
        XCTAssertEqual(obj["slug"]?.string, "anadrol")
        XCTAssertEqual(obj["form"]?.string, "oral")
        XCTAssertEqual(obj["tab"], JSONValue.string("50"),
                       "the oral trio are web `<input>` strings — app.js:8810-8812")
        XCTAssertEqual(obj["dose"], JSONValue.string("100"))
        XCTAssertEqual(obj["split"], JSONValue.string("1"))
    }

    /// And the round trip still lands where it started: a seeded-then-saved config
    /// reopens on the same tablet. `values(fromConfig:)` is the path
    /// `DoseVolume.perInjection` takes long after the screen is gone.
    @MainActor
    func testASeededAnadrolConfigSurvivesTheRoundTrip() {
        let vm = CalculatorViewModel(slug: .steroid)
        vm.values = picking("Anadrol (Oxymetholone)", in: vm.values)
        var v = vm.values
        v.numbers["oralDose"] = 100
        v.numbers["oralSplit"] = 2
        vm.values = v

        let back = CalculatorCatalog.values(fromConfig: vm.configJSON(), slug: .steroid)
        XCTAssertEqual(SteroidCatalog.pick(at: Int(back.number("compound"))).label,
                       "Anadrol (Oxymetholone)")
        XCTAssertEqual(back.number("tabMg"), 50, accuracy: acc)
        XCTAssertEqual(back.number("oralDose"), 100, accuracy: acc)
        let r = CalculatorEngine.evaluate(slug: .steroid, values: back, scale: .u100)
        XCTAssertNil(r.drawMl)
        XCTAssertEqual(row(r, "Tablets"), "1.00 tab")   // 50 mg per dose ÷ 50 mg/tab
    }
}
