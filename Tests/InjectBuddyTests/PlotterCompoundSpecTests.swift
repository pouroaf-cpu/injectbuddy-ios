import XCTest
@testable import InjectBuddy

// ─── PlotterCompoundSpecTests ────────────────────────────────────────────────
//
// T-60. The check that outlives the fix.
//
// The plotter's compound table was a faithful hand-copy of the web's
// `PLOTTER_COMPOUNDS`, and its comment said so accurately. That table is dead —
// the in-app plotter was removed in favour of `/cycle-plotter/`, and nothing
// reads it. iOS therefore ran 17 wrong half-lives and 4 wrong units, some by
// 4×, for as long as that had been true, and nothing could notice because the
// two tables use different id vocabularies.
//
// Reconciling the numbers fixes today. It does not fix next time — another
// faithful hand-copy, of the right table, is one refactor away from the same
// place. So:
//
//   • the Swift table is GENERATED from `spec/compounds.json`
//     (`spec/generate-plotter-compounds.mjs`), and
//   • this test re-reads THAT SAME JSON from disk, independently of the
//     generator, and asserts the SHIPPED Swift table against it row for row.
//
// The JSON is the real thing: `spec/compounds.json` in this repo is
// byte-identical to the web's (git blob `cf14ff76…` on
// `pouroaf-cpu/injectbuddy@feature/dosage-status-model`), which is itself
// generated from `public/legacy/cycle-plotter/pk.js` — the file the live
// plotter loads. It is NOT a second hand-copy of the values in the Swift, so
// these assertions can genuinely fail.
//
// ─── WHAT MAKES EACH ASSERTION ABLE TO FAIL ─────────────────────────────────
//
// This project has found eight checks that could not fail, and one instrument
// that reported success while doing nothing. So the preconditions are asserted
// before the result:
//
//   • `test_theSpecFixtureActuallyLoaded` — the file was found, parsed, holds
//     31 compounds, and carries a value the OLD iOS table got wrong (`tren-a`
//     3.0, where iOS had 1.5). If the loader ever silently reads the wrong
//     file, or the fixture is replaced by the dead table's numbers, that test
//     goes red before any comparison is trusted.
//   • `test_everyShippedCompoundMatchesTheSpec` counts its comparisons and
//     asserts the count is 23. It cannot pass by comparing nothing.
//
final class PlotterCompoundSpecTests: XCTestCase {

    // MARK: - The spec, read from disk

    private struct SpecCompound: Decodable {
        let name: String
        let short: String
        let type: String
        let cat: String
        let halfLife: Double
        let unit: String
    }

    private struct SpecFile: Decodable {
        let specVersion: Int
        let compoundCount: Int
        let compounds: [String: SpecCompound]
    }

    /// The eight spec compounds iOS does not ship, and why. Hard-coded HERE rather
    /// than read from `spec/plotter-ios-fields.json`, on purpose: reading the
    /// generator's own input would make this `XCTAssertEqual(x, x)`. Pinned, so
    /// shipping one of these — or quietly dropping another — turns this red and
    /// forces the change to be stated.
    ///
    /// Every one needs a `tmax` before `pkBuildEntries` can draw it, and the live
    /// source has none. That is T-32's decision, not T-60's.
    private static let notCarried: Set<String> = [
        "test-a", "sustanon",       // ESTER_TO_CID names both; the seed refuses them.
        "hcg",                      // The hcg calculator shows the levels CTA.
        "methenolone-e", "anavar", "dianabol", "winstrol-o",  // STEROID_TO_CID; latent.
        "pinealon",                 // Never carried by iOS.
    ]

    /// The four rows iOS ships that the LIVE table has no entry for at all, so
    /// there is nothing to reconcile them to. Their numbers are still the dead
    /// table's and are marked as such by an off-vocabulary category — see
    /// `test_theNonSpecRowsAreIdentifiableAsSuch`.
    private static let iosOnly: Set<String> = ["ghrp2", "ghrp6", "sermorelin", "ta1"]

    private static let expectedSpecCount = 31

    // MARK: - Loading

    /// Resolves `spec/compounds.json`. The unit bundle does not carry it (the
    /// `spec/` folder is not a target source), so the primary route is
    /// `#filePath` — the same technique snapshot-testing libraries use to reach
    /// the source tree from a simulator process. The bundle is tried first anyway
    /// so that adding it as a resource later Just Works.
    ///
    /// Throws an error naming every path it tried, rather than a bare "file not
    /// found": a probe that fails because the PROBE is wrong is indistinguishable
    /// from one that fails because the DATA is wrong, and this project has
    /// already acted on that confusion once.
    private func loadSpec(file: StaticString = #filePath) throws -> SpecFile {
        var tried: [String] = []

        if let url = Bundle(for: Self.self).url(forResource: "compounds", withExtension: "json") {
            tried.append(url.path)
            if let data = try? Data(contentsOf: url) {
                return try JSONDecoder().decode(SpecFile.self, from: data)
            }
        }

        // …/Tests/InjectBuddyTests/PlotterCompoundSpecTests.swift → repo root.
        let here = URL(fileURLWithPath: "\(file)")
        let root = here.deletingLastPathComponent()   // InjectBuddyTests
            .deletingLastPathComponent()              // Tests
            .deletingLastPathComponent()              // repo root
        let url = root.appendingPathComponent("spec/compounds.json")
        tried.append(url.path)
        if let data = try? Data(contentsOf: url) {
            return try JSONDecoder().decode(SpecFile.self, from: data)
        }

        // NOT `XCTSkip`. A skipped test and a passing one are indistinguishable at
        // the exit code, and this suite exists precisely to make a wrong table
        // impossible to miss.
        struct SpecUnreadable: Error, CustomStringConvertible {
            let tried: [String]
            var description: String {
                """
                Could not read spec/compounds.json. Tried:
                  \(tried.joined(separator: "\n  "))
                This is a PROBE failure, not a finding about the compound table — do not
                read it as "the spec and the app disagree". If the test bundle cannot
                reach the source tree, add spec/compounds.json to the InjectBuddyTests
                target's resources in project.yml and re-run xcodegen.
                """
            }
        }
        throw SpecUnreadable(tried: tried)
    }

    // MARK: - Preconditions

    /// Before any comparison is believed: the fixture is real, complete, and is
    /// the LIVE table rather than the dead one.
    func test_theSpecFixtureActuallyLoaded() throws {
        let spec = try loadSpec()

        XCTAssertEqual(spec.specVersion, 1)
        XCTAssertEqual(spec.compoundCount, Self.expectedSpecCount,
                       "compounds.json's own compoundCount changed.")
        XCTAssertEqual(spec.compounds.count, Self.expectedSpecCount,
                       "compounds.json carries \(spec.compounds.count) compounds, not \(Self.expectedSpecCount). "
                       + "If the web added one, the generator will refuse to run until it is "
                       + "either shipped or recorded in `notCarried` — do that first.")

        // Three values the DEAD table got wrong. If the fixture is ever replaced by
        // the dead table, or by a copy of iOS's old numbers, this fails here rather
        // than silently agreeing with everything downstream.
        XCTAssertEqual(spec.compounds["tren-a"]?.halfLife, 3.0,
                       "Tren A is 3.0 d in the live table; the dead one said 1.5.")
        XCTAssertEqual(spec.compounds["pt141"]?.halfLife, 0.5,
                       "PT-141 is 0.5 d in the live table; the dead one said 0.113.")
        XCTAssertEqual(spec.compounds["mt2"]?.halfLife, 1.5,
                       "Melanotan II is 1.5 d in the live table; the dead one said 3.7.")
    }

    // MARK: - Row for row

    /// Every compound iOS ships that the spec also carries must match it on all
    /// six spec fields. This is the assertion T-60 exists to install.
    func test_everyShippedCompoundMatchesTheSpec() throws {
        let spec = try loadSpec()
        var compared = 0

        for c in PlotterCompound.all {
            guard let s = spec.compounds[c.id] else { continue }  // iOS-only; asserted separately
            compared += 1
            XCTAssertEqual(c.label, s.name, "\(c.id): label")
            XCTAssertEqual(c.short, s.short, "\(c.id): short")
            XCTAssertEqual(c.type, s.type, "\(c.id): type")
            XCTAssertEqual(c.category, s.cat, "\(c.id): category")
            XCTAssertEqual(c.unit, s.unit, "\(c.id): unit")
            XCTAssertEqual(c.halfLife, s.halfLife, accuracy: 1e-9,
                           "\(c.id): HALF-LIFE. This drives the whole accumulation curve. "
                           + "If PlotterCompoundTable.swift was hand-edited, revert it and run "
                           + "`node spec/generate-plotter-compounds.mjs`.")
        }

        XCTAssertEqual(compared, PlotterCompound.all.count - Self.iosOnly.count,
                       "Expected to compare \(PlotterCompound.all.count - Self.iosOnly.count) rows "
                       + "against the spec and compared \(compared). This test must not be able to "
                       + "pass by comparing nothing.")
        XCTAssertEqual(compared, 23, "The spec-backed row count changed.")
    }

    /// The row SET, pinned from both ends. Reconciling values is worthless if a
    /// compound can appear or vanish unremarked.
    func test_theRowSetIsPinnedFromBothEnds() throws {
        let spec = try loadSpec()
        let shipped = Set(PlotterCompound.all.map(\.id))

        XCTAssertEqual(shipped.count, PlotterCompound.all.count, "Duplicate compound id in the table.")

        let missing = Set(spec.compounds.keys).subtracting(shipped)
        XCTAssertEqual(missing, Self.notCarried,
                       "The set of spec compounds iOS does not ship has changed. Adding one needs a "
                       + "sourced tmax (T-32); removing one is a product decision. Either way, say so "
                       + "here rather than letting the list drift.")

        let extra = shipped.subtracting(spec.compounds.keys)
        XCTAssertEqual(extra, Self.iosOnly,
                       "The set of compounds iOS ships that the LIVE plotter has no entry for has "
                       + "changed. These carry dead-table numbers with nothing to reconcile them to.")

        XCTAssertEqual(shipped.count, 27)
    }

    /// The four non-spec rows keep the dead table's `"Peptide"` category, which is
    /// not in the live vocabulary (`Testosterone`/`Anabolics`/`Orals`/`Support`/
    /// `GLP-1`/`Healing`/`Growth`/`Other`). That is deliberate: it is the marker
    /// that says "these numbers are not spec-backed", and it is asserted so it
    /// cannot be tidied away without a decision.
    func test_theNonSpecRowsAreIdentifiableAsSuch() throws {
        let spec = try loadSpec()
        let liveCategories = Set(spec.compounds.values.map(\.cat))
        XCTAssertFalse(liveCategories.contains("Peptide"),
                       "The live table has grown a 'Peptide' category, so it no longer marks the "
                       + "non-spec rows. Pick another marker.")

        let marked = Set(PlotterCompound.all.filter { $0.category == "Peptide" }.map(\.id))
        XCTAssertEqual(marked, Self.iosOnly)
    }

    // MARK: - The things T-60 deliberately did NOT touch

    /// `tmax` has no counterpart in the spec — the live `pk.js` derives `ka`
    /// analytically and never names one. These values are still the dead table's,
    /// left alone on purpose: deleting them leaves `pkBuildEntries` with no
    /// absorption input, and inventing replacements puts a fabricated number on a
    /// dosing curve. Pinned so the fact stays visible, and so the day someone
    /// sources real ones this test says where they went.
    ///
    /// It also asserts the one property the PK model actually requires of them:
    /// `pkSolveKa` bisects for `ln(ka/ke)/(ka−ke) = tmax`, whose supremum as
    /// `ka → ke` is `1/ke = halfLife/ln2`. A `tmax` at or above that cannot be
    /// solved and the bisection would return a silent nonsense `ka`. The
    /// half-lives just moved under every one of these, so it is checked rather
    /// than assumed.
    func test_tmaxIsUnchangedDeadTableDataAndStillSolvable() throws {
        let fromTheDeadTable: [String: Double] = [
            "test-e": 2.0, "test-c": 2.5, "test-p": 0.5, "test-u": 6.0,
            "npp": 1.0, "nandrolone-d": 3.0, "tren-a": 0.5, "tren-e": 2.0,
            "boldenone": 5.0, "masteron-p": 0.8, "masteron-e": 2.0,
            "bpc157": 0.04, "tb500": 0.25, "cjc-nodac": 0.010, "cjc-dac": 2.0,
            "ipamorelin": 0.042, "ghrp2": 0.021, "ghrp6": 0.021,
            "sermorelin": 0.003, "hgh": 0.125, "pt141": 0.042, "igf1lr3": 0.25,
            "ta1": 0.021, "mt2": 0.042,
            "semaglutide": 1.0, "tirzepatide": 1.0, "retatrutide": 1.0,
        ]
        XCTAssertEqual(Set(fromTheDeadTable.keys), Set(PlotterCompound.all.map(\.id)))

        for c in PlotterCompound.all {
            let expected = try XCTUnwrap(fromTheDeadTable[c.id], "\(c.id) has no pinned tmax")
            XCTAssertEqual(c.tmax, expected, accuracy: 1e-9,
                           "\(c.id): tmax moved. T-60 left these alone by design — if they are "
                           + "being sourced properly now, that is T-42's ka question and this "
                           + "expectation should be rewritten, not quietly updated.")
            XCTAssertLessThan(c.tmax, c.halfLife / log(2.0),
                              "\(c.id): tmax \(c.tmax) is not reachable for a half-life of "
                              + "\(c.halfLife) — pkSolveKa's bisection would return nonsense.")
        }
    }

    /// The plotter's `allTesto` flag — and with it the ng/dL factor T-42 is about
    /// — keys off `category == "Testosterone"`. The categories changed wholesale
    /// in this reconciliation, so the four rows that flag must be pinned, or T-42
    /// would be silently altered by a table edit.
    func test_theTestosteroneCategoryStillSelectsExactlyTheEsters() {
        let testo = PlotterCompound.all.filter { $0.category == "Testosterone" }.map(\.id)
        XCTAssertEqual(Set(testo), ["test-e", "test-c", "test-p", "test-u"],
                       "CyclePlotterViewModel gates CalculatorEngine.testoNgdlFactor on this "
                       + "category. Changing the set changes which charts claim a lab number — "
                       + "which is T-42, not a table edit.")
    }

    /// `PlotterCompound.all[0]` is `CyclePlotterViewModel`'s fallback for an
    /// unknown id, and `test-e` is the line the plotter opens on. The generator
    /// emits rows in an order given explicitly by `spec/plotter-ios-fields.json`
    /// so the reconciliation was a data change and not also a reordering; this is
    /// what says so.
    func test_theOrderStillOpensOnTestE() {
        XCTAssertEqual(PlotterCompound.all.first?.id, "test-e")
    }
}
