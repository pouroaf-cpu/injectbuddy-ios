import XCTest
@testable import InjectBuddy

/// **T-53 and T-52 — what a card says, and what a logged dose records.**
///
/// The configs below are not invented. They are the rows the QA account actually holds
/// (`saved_dosages`, queried 2026-08-04) — including the two that rendered as `TRT Dose`
/// twice with nothing under either, which is the defect T-53 exists for. A test written
/// against a plausible config would have passed on the day the real pair was ambiguous.
final class ProtocolSummaryTests: XCTestCase {

    // MARK: helpers

    private func dosage(id: String, type: String, label: String?, config: String) -> SavedDosage {
        let labelJSON = label.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":\(labelJSON),\
        "config":\(config),"start_date":null,"is_active":true}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    /// The pair from the frame. Identical in every key but `mgWeek`.
    private var trtA: SavedDosage {
        dosage(id: "249135d4", type: "trt", label: "TRT Dose", config: """
        {"mode":"perweek","nDays":3.5,"mgWeek":137,"mlDrawn":0.5,"strength":200,
         "esterType":"Testosterone Enanthate","syringeMl":1,"injPerWeek":2}
        """)
    }
    private var trtB: SavedDosage {
        dosage(id: "d94cc62b", type: "trt", label: "TRT Dose", config: """
        {"mode":"perweek","nDays":3.5,"mgWeek":149,"mlDrawn":0.5,"strength":200,
         "esterType":"Testosterone Enanthate","syringeMl":1,"injPerWeek":2}
        """)
    }

    private func titles(_ ds: [SavedDosage]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ds.map {
            ($0.id, ProtocolLabel.split($0.label ?? $0.calculatorType).compound)
        })
    }

    // MARK: - T-53: the two cards that read the same

    /// The whole task in one assertion: the rows the frame showed as two identical
    /// `TRT Dose` cards now render two different lines.
    func testTheTwoTrtProtocolsFromTheFrameNoLongerReadAlike() {
        let ds = [trtA, trtB]
        let lines = ProtocolSummary.lines(for: ds, titles: titles(ds))

        // 137 ÷ 2 injections = 68.5 mg; 149 ÷ 2 = 74.5 mg.
        XCTAssertEqual(lines["249135d4"],
                       "68.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate")
        XCTAssertEqual(lines["d94cc62b"],
                       "74.5 mg · every 3.5 days · 200 mg/mL · Testosterone Enanthate")
        XCTAssertNotEqual(lines["249135d4"], lines["d94cc62b"])
    }

    /// The card's own heading is not repeated in the line. A web-written label already
    /// names the ester; saying it twice is the noise this line exists to avoid.
    func testCompoundIsNotRepeatedWhenTheTitleAlreadyCarriesIt() {
        let d = dosage(id: "web", type: "trt", label: "100mg/wk · Testosterone Enanthate", config: """
        {"mode":"ndays","nDays":3.5,"mgWeek":100,"mlDrawn":0,"strength":230,
         "esterType":"Testosterone Enanthate","syringeMl":1,"injPerWeek":0}
        """)
        let title = ProtocolLabel.split(d.label!).compound
        XCTAssertEqual(title, "Testosterone Enanthate")
        XCTAssertEqual(ProtocolSummary.line(for: d, title: title),
                       "50 mg · every 3.5 days · 230 mg/mL")
    }

    /// **The pair the derived language cannot separate.** Same weekly dose, same
    /// interval, same vial, same ester — but one is saved `perweek` and one `ndays`, so
    /// they are two different rows under the unique index. The line falls back to naming
    /// the keys that differ rather than shipping two cards that read alike.
    func testProtocolsDifferingOnlyInAKeyTheLineDoesNotShowAreStillDistinguished() {
        let perweek = dosage(id: "pw", type: "trt", label: "TRT Dose", config: """
        {"mode":"perweek","mgWeek":100,"strength":200,"injPerWeek":2,
         "esterType":"Testosterone Enanthate"}
        """)
        let ndays = dosage(id: "nd", type: "trt", label: "TRT Dose", config: """
        {"mode":"ndays","mgWeek":100,"strength":200,"nDays":3.5,
         "esterType":"Testosterone Enanthate"}
        """)

        // Both derive 50 mg every 3.5 days from a 200 mg/mL vial — the same line.
        XCTAssertEqual(ProtocolSummary.line(for: perweek, title: "TRT Dose"),
                       ProtocolSummary.line(for: ndays, title: "TRT Dose"))

        let ds = [perweek, ndays]
        let lines = ProtocolSummary.lines(for: ds, titles: titles(ds))
        XCTAssertNotEqual(lines["pw"], lines["nd"])
        XCTAssertTrue(lines["pw"]!.contains("mode perweek"), lines["pw"]!)
        XCTAssertTrue(lines["nd"]!.contains("mode ndays"), lines["nd"]!)
    }

    /// A `calculator_type` this build has no calculator for — production holds
    /// `femalehrt`, `oilblend` and `bioavailability` today. Nothing can be derived, so
    /// the line would be empty and two such rows would collide at "" — the exact failure
    /// under a different cause. The keys still separate them.
    func testUnknownCalculatorTypesAreStillToldApart() {
        let a = dosage(id: "a", type: "femalehrt", label: "HRT", config: #"{"dose":2,"unit":"mg"}"#)
        let b = dosage(id: "b", type: "femalehrt", label: "HRT", config: #"{"dose":4,"unit":"mg"}"#)
        XCTAssertEqual(ProtocolSummary.line(for: a), "")

        let ds = [a, b]
        let lines = ProtocolSummary.lines(for: ds, titles: titles(ds))
        XCTAssertEqual(lines["a"], "dose 2")
        XCTAssertEqual(lines["b"], "dose 4")
    }

    /// Two rows of DIFFERENT families that read alike are separated by the family, not
    /// by a list of every key they happen not to share.
    func testDifferentCalculatorTypesAreSeparatedByTheType() {
        let a = dosage(id: "a", type: "femalehrt", label: "Protocol", config: "{}")
        let b = dosage(id: "b", type: "oilblend", label: "Protocol", config: "{}")
        let ds = [a, b]
        let lines = ProtocolSummary.lines(for: ds, titles: titles(ds))
        XCTAssertEqual(lines["a"], "femalehrt")
        XCTAssertEqual(lines["b"], "oilblend")
    }

    /// One unit convention across the list: per injection, everywhere. The frame had
    /// `350mcg/inj` next to `300 mg/wk` next to a blank.
    func testEveryFamilyStatesThePerInjectionDose() {
        let peptide = dosage(id: "p", type: "peptide", label: "TB-500 (Thymosin Beta-4) · 350mcg/inj", config: """
        {"bawMl":3,"doseUnit":"mcg","peptideMg":25,"syringeMl":1,
         "dosePerInj":350,"injPerWeek":4,"peptideType":"TB-500 (Thymosin Beta-4)"}
        """)
        XCTAssertEqual(ProtocolSummary.amount(for: peptide), DoseAmount(value: 350, unit: "mcg"))
        XCTAssertEqual(ProtocolSummary.line(for: peptide, title: "TB-500 (Thymosin Beta-4)"),
                       "350 mcg · every 1.75 days · 25 mg in 3 mL")

        let glp1 = dosage(id: "g", type: "retatrutide", label: nil, config: #"{"conc":10,"dose":4}"#)
        XCTAssertEqual(ProtocolSummary.amount(for: glp1), DoseAmount(value: 4, unit: "mg"))

        let hcg = dosage(id: "h", type: "hcg", label: nil,
                         config: #"{"vialIU":5000,"bacWaterMl":2,"dose":500}"#)
        XCTAssertEqual(ProtocolSummary.amount(for: hcg), DoseAmount(value: 500, unit: "IU"))
    }

    /// A blend puts two compounds in one barrel. There is no single amount, so none is
    /// invented — and the log sheet shows no amount field rather than a half-true one.
    func testABlendHasNoSingleDoseAmount() {
        let blend = dosage(id: "b", type: "bpc157blend", label: nil, config: """
        {"bpcVial":10,"bpcWater":2,"bpcDose":250,"tbVial":10,"tbWater":2,"tbDose":500}
        """)
        XCTAssertNil(ProtocolSummary.amount(for: blend))
    }

    /// The mode gate is shared with the volume. A steroid row saved `perweek` is one
    /// this build's `evaluate` does not run, and it already refuses to state a volume —
    /// so it must not state a dose either.
    func testAModeThisBuildDoesNotEvaluateStatesNoDoseAndNoVolume() {
        let masteron = dosage(id: "m", type: "steroid",
                              label: "300 mg/wk · Masteron (Drostanolone) Enanthate", config: """
        {"tab":"10","dose":"","form":"injectable","mode":"perweek","slug":"masteron","nDays":3.5,
         "split":"1","mgWeek":300,"mlDrawn":0.75,"esterKey":"enanthate","strength":200,
         "syringeMl":1,"injPerWeek":2}
        """)
        XCTAssertNil(ProtocolSummary.amount(for: masteron))
        XCTAssertNil(DoseVolume.perInjectionMl(for: masteron))
        // Still says something: the line is not empty just because the dose is unknown.
        XCTAssertEqual(ProtocolSummary.line(for: masteron, title: "Masteron (Drostanolone) Enanthate"),
                       "every 3.5 days · 200 mg/mL")
    }

    // MARK: - T-52: the amount that is written

    /// The plan, untouched. `draw_ml` must be byte-identical to what this app already
    /// writes — the last iOS row on this protocol carried 0.373 — and `dose_label`, which
    /// used to be NULL, now states the dose.
    func testLoggingThePlanRecordsThePlan() {
        let pin = NewDoseLogPin(for: trtB, dosedOn: "2026-08-04")
        XCTAssertEqual(pin.doseLabel, "74.5 mg")
        XCTAssertEqual(pin.drawMl ?? 0, 0.3725, accuracy: 0.00001)
    }

    /// **The defect, closed.** Half the dose is half the millilitres — recorded as half,
    /// not as the plan. Before this, both columns said a full injection.
    func testAnAdjustedAmountIsRecordedAndScalesTheVolume() {
        let half = NewDoseLogPin(for: trtB, dosedOn: "2026-08-04",
                                 amount: DoseAmount(value: 37.25, unit: "mg"))
        XCTAssertEqual(half.doseLabel, "37.25 mg")
        XCTAssertEqual(half.drawMl ?? 0, 0.18625, accuracy: 0.00001)

        let over = NewDoseLogPin(for: trtB, dosedOn: "2026-08-04",
                                 amount: DoseAmount(value: 100, unit: "mg"))
        XCTAssertEqual(over.doseLabel, "100 mg")
        XCTAssertEqual(over.drawMl ?? 0, 0.5, accuracy: 0.00001)
    }

    /// An amount in the wrong unit can only come from a caller pairing an amount with the
    /// wrong protocol. Scaling across units would write a dose out by a thousand, so the
    /// amount is refused and the plan stands.
    func testAnAmountInTheWrongUnitIsRefusedRatherThanConverted() {
        let pin = NewDoseLogPin(for: trtB, dosedOn: "2026-08-04",
                                amount: DoseAmount(value: 350, unit: "mcg"))
        XCTAssertEqual(pin.doseLabel, "74.5 mg")
        XCTAssertEqual(pin.drawMl ?? 0, 0.3725, accuracy: 0.00001)
    }

    /// The dashboard and the calendar log the plan, and they hold occurrences rather than
    /// protocols. They must still fill `dose_label` — a third log path writing NULL is how
    /// the column came to be empty on every iOS row in the first place.
    func testTheProjectedLogPathAlsoCarriesTheDose() {
        let occurrences = DoseProjection.projectedDoses(
            for: [trtB.withStart("2026-08-03")],
            from: dpParseDay("2026-08-03")!, days: 7)
        XCTAssertFalse(occurrences.isEmpty, "nothing projected — the fixture is wrong, not the code")
        let pin = NewDoseLogPin(for: occurrences[0])
        XCTAssertEqual(pin.doseLabel, "74.5 mg")
    }

    // MARK: - formatting

    func testNumbersAreTrimmedNotPadded() {
        XCTAssertEqual(ProtocolSummary.trim(68.5), "68.5")
        XCTAssertEqual(ProtocolSummary.trim(200), "200")
        XCTAssertEqual(ProtocolSummary.trim(1.0769230769), "1.08")
        XCTAssertEqual(ProtocolSummary.trim(0), "0")
        XCTAssertEqual(ProtocolSummary.trim(.nan), "—")
    }

    /// The unit is never separated from the value.
    func testTheUnitTravelsWithTheValue() {
        XCTAssertEqual(DoseAmount(value: 0.25, unit: "mL").labelled, "0.25 mL")
        XCTAssertEqual(DoseAmount(value: 74.5, unit: "mg").labelled, "74.5 mg")
    }
}

private extension SavedDosage {
    /// `start_date` is decoded, not settable at construction in the fixture above.
    func withStart(_ day: String) -> SavedDosage {
        var copy = self
        copy.startDate = day
        return copy
    }
}
