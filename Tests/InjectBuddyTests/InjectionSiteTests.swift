import XCTest
@testable import InjectBuddy

/// `dose_log.site` is a SHARED COLUMN, not an iOS field. These tests pin the two things
/// the web can be broken by: the exact strings, and the route each protocol takes.
///
/// The vocabulary here is transcribed from the web's `lib/account-schedule.ts`
/// (`SITES_IM` / `SITES_SUBQ`), which `lib/body-regions.ts` pins the body-map artwork to.
/// The web resolves a pin with `p.sites.indexOf(pin.site)` and DISCARDS anything it does
/// not find — so a mis-spelled label is not a cosmetic difference, it is a dose that
/// vanishes from the rotation while looking perfectly fine in the table.
final class InjectionSiteTests: XCTestCase {

    private func makeDosage(id: String = "p", type: String, config: String = "{}") -> SavedDosage {
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":null,"config":\(config),"start_date":"2026-01-01","is_active":true}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    private func pin(_ protocolId: String, _ day: String, _ site: String?) -> DoseLogPin {
        DoseLogPin(id: UUID().uuidString, protocolId: protocolId,
                   dosedOn: day, drawMl: 0.4, site: site)
    }

    // MARK: - vocabulary

    func testIMTrackMatchesTheWebExactly() {
        XCTAssertEqual(InjectionSite.imTrack,
                       ["L Glute", "R Glute", "L VG", "R VG",
                        "L Quad", "R Quad", "L Delt", "R Delt"])
    }

    func testSubQTrackMatchesTheWebExactly() {
        XCTAssertEqual(InjectionSite.subQTrack,
                       ["Abdomen L", "Abdomen R", "L Love handle",
                        "R Love handle", "L Thigh", "R Thigh"])
    }

    func testEightIMAndSixSubQ() {
        XCTAssertEqual(InjectionSite.imTrack.count, 8)
        XCTAssertEqual(InjectionSite.subQTrack.count, 6)
        XCTAssertEqual(Set(InjectionSite.allKnown).count, 14, "no label may appear in both tracks")
    }

    // MARK: - route, branch for branch against the web's deriveDose

    func testInjectableRoutes() {
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "trt")), .intramuscular)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "eod")), .intramuscular)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "microdose")), .intramuscular)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "peptide")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "semaglutide")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "tirzepatide")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "retatrutide")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "bpc157")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "bpc157blend")), .subcutaneous)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "hcg")), .subcutaneous)
    }

    func testSteroidFormDecidesTheRoute() {
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "steroid")), .intramuscular,
                       "the web defaults an absent form to injectable")
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "steroid",
                                                          config: #"{"form":"injectable"}"#)),
                       .intramuscular)
        XCTAssertEqual(InjectionSite.route(for: makeDosage(type: "steroid",
                                                          config: #"{"form":"oral"}"#)),
                       .oral)
    }

    /// A tablet has no injection site, and neither does a calculator with no schedule.
    /// Both must offer NOTHING rather than defaulting into the IM track.
    func testNoTrackWhereThereIsNoInjection() {
        XCTAssertTrue(InjectionSite.track(for: makeDosage(type: "steroid", config: #"{"form":"oral"}"#)).isEmpty)
        for type in ["bmi", "freetest", "reconstitution", "plotter", "not-a-calculator"] {
            XCTAssertTrue(InjectionSite.track(for: makeDosage(type: type)).isEmpty, type)
            XCTAssertNil(InjectionSite.suggested(for: makeDosage(type: type), pins: []), type)
        }
    }

    // MARK: - rotation

    func testSuggestsOneStepPastTheLastLoggedSite() {
        let d = makeDosage(type: "trt")
        let pins = [pin("p", "2026-07-01", "L Glute"),
                    pin("p", "2026-07-05", "R Glute")]   // newest
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: pins), "L VG")
    }

    func testRotationWrapsAtTheEndOfTheTrack() {
        let d = makeDosage(type: "trt")
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: [pin("p", "2026-07-05", "R Delt")]),
                       "L Glute")
    }

    /// The whole reason this task exists: every pre-existing iOS row has a NULL site.
    /// They must not seed the rotation, and they must not crash it either.
    func testNullSitesAreIgnored() {
        let d = makeDosage(type: "trt")
        let pins = [pin("p", "2026-07-01", "L Quad"),
                    pin("p", "2026-07-09", nil)]         // newest, but says nothing
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: pins), "R Quad")
    }

    /// A label outside this protocol's track — a peptide pin read against a TRT
    /// protocol, or a row whose calculator type changed — must be skipped, not
    /// resolved to index 0. `firstIndex(of:)` returning nil is the web's `indexOf`
    /// returning −1.
    func testLabelsOutsideTheTrackAreIgnored() {
        let d = makeDosage(type: "trt")
        let pins = [pin("p", "2026-07-01", "L Quad"),
                    pin("p", "2026-07-09", "Abdomen L")]
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: pins), "R Quad")
    }

    func testOtherProtocolsHistoryIsNotBorrowed() {
        let d = makeDosage(id: "mine", type: "trt")
        let pins = [pin("theirs", "2026-07-09", "R Delt")]
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: pins, seed: 0), "L Glute",
                       "with no history of ITS OWN, the seed decides")
    }

    /// Two protocols logged for the first time on the same day must not both open on
    /// the same muscle — the web seeds per protocol for exactly this reason.
    func testSeedSeparatesProtocolsWithNoHistory() {
        let d = makeDosage(type: "trt")
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: [], seed: 0), "L Glute")
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: [], seed: 1), "R Glute")
        XCTAssertEqual(InjectionSite.suggested(for: d, pins: [], seed: 9), "R Glute",
                       "seeds wrap rather than trapping")
    }

    /// Whatever the rotation proposes, it is always a label the web can resolve.
    func testEverySuggestionIsInTheWebsVocabulary() {
        for type in ["trt", "eod", "microdose", "steroid", "peptide", "semaglutide",
                     "tirzepatide", "retatrutide", "bpc157", "bpc157blend", "hcg"] {
            for seed in 0..<10 {
                let s = InjectionSite.suggested(for: makeDosage(type: type), pins: [], seed: seed)
                XCTAssertNotNil(s, type)
                XCTAssertTrue(InjectionSite.allKnown.contains(s ?? ""), "\(type) → \(s ?? "nil")")
            }
        }
    }

    // MARK: - the payload

    /// The pin the sheet builds must carry the site under the key PostgREST writes.
    /// `site` absent (not null) when there is none, so a later write cannot blank a
    /// site already on the row.
    func testEncodedPayloadCarriesSiteUnderTheRightKey() throws {
        let d = makeDosage(type: "trt", config: #"{"strength":250,"mgWeek":100,"injPerWeek":2,"mode":"perweek"}"#)
        let withSite = NewDoseLogPin(for: d, dosedOn: "2026-08-03", site: "R Glute")
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(withSite)) as? [String: Any]
        XCTAssertEqual(json?["site"] as? String, "R Glute")
        XCTAssertEqual(json?["dosed_on"] as? String, "2026-08-03")

        let without = NewDoseLogPin(for: d, dosedOn: "2026-08-03")
        let json2 = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(without)) as? [String: Any]
        XCTAssertNil(json2?["site"], "nil must be an ABSENT key, never an explicit null")
    }
}
