import XCTest
@testable import InjectBuddy

/// What iOS actually PUTS ON THE WIRE for a logged dose.
///
/// `dose_log` has thirteen columns iOS can write and it was writing four:
///
///  • the five display-snapshot columns (`scheduled_on`, `protocol_label`,
///    `compound_label`, `category`, `dose_label`) exist so the history ledger freezes
///    what a dose looked like. NULL makes `DoseHistory.tsx:86-89` fall back to a LIVE
///    protocol lookup, so an iOS-logged row rewrote itself when the protocol was
///    renamed while a web-logged row for the same dose stayed put. **T-59.** (T-52
///    closed `dose_label` first, from this app's engine and editable by the user; the
///    other four come from `DoseSnapshot`, which mirrors the web's derivation.)
///  • the three injection-moment columns (`injection_time`, `injection_timezone`,
///    `injected_at`) exist so the serum curve plots a dose at the hour it happened.
///    NULL parks every iOS dose at noon, in the READER's timezone. **T-51.**
///
/// The column names and value shapes here are transcribed from the web's own writer —
/// `app/api/dose-log/route.ts` and `components/account/dashboard/DashboardContext.tsx`
/// on branch `feature/dosage-status-model` — and cross-checked against the live table.
/// A column name that is merely plausible is the failure this project has already hit
/// twice, and PostgREST answers an unknown column with a 400 that reaches the user as
/// "That dose was not logged", so the names are asserted on the encoded bytes.
final class DoseLogSnapshotTests: XCTestCase {

    // MARK: - fixtures (verbatim production configs, read from saved_dosages)

    private func dosage(id: String = "11111111-1111-1111-1111-111111111111",
                        type: String, label: String?, config: String) -> SavedDosage {
        let labelJSON = label.map { "\"\($0)\"" } ?? "null"
        let json = """
        {"id":"\(id)","calculator_type":"\(type)","label":\(labelJSON),\
        "config":\(config),"start_date":"2026-01-01","is_active":true}
        """.data(using: .utf8)!
        return try! JSONDecoder().decode(SavedDosage.self, from: json)
    }

    private let auckland = TimeZone(identifier: "Pacific/Auckland")!

    /// 2026-08-04 21:34:00 +12:00 (NZST) = 2026-08-04T09:34:00Z.
    private var loggedAt: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 4; c.hour = 21; c.minute = 34
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = auckland
        return cal.date(from: c)!
    }

    // MARK: - the wire body

    /// `OwnedDoseLogPin` — not `NewDoseLogPin` — is what is handed to PostgREST.
    func testTheEncodedInsertCarriesEveryColumnUnderTheWebsOwnName() throws {
        let trt = dosage(type: "trt", label: "TRT Dose",
                         config: """
                         {"mode":"perweek","nDays":3.5,"mgWeek":149,"mlDrawn":0.5,\
                         "strength":200,"esterType":"Testosterone Enanthate",\
                         "syringeMl":1,"injPerWeek":2}
                         """)
        let pin = NewDoseLogPin(for: trt, dosedOn: "2026-08-04", site: "R Glute",
                                now: loggedAt, timeZone: auckland)
        let owned = SupabaseBackendClient.OwnedDoseLogPin(pin, userId: "user-uuid")

        let data = try JSONEncoder().encode(owned)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(body.keys), [
            "user_id", "protocol_id", "dosed_on", "scheduled_on",
            "draw_ml", "site",
            "protocol_label", "compound_label", "category", "dose_label",
            "injection_time", "injection_timezone", "injected_at",
        ], "PostgREST rejects the whole insert on one unknown column name.")

        XCTAssertEqual(body["user_id"] as? String, "user-uuid",
                       "dose_log is RLS-scoped to auth.uid(); a write without user_id fails.")
        XCTAssertEqual(body["protocol_id"] as? String, "11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(body["dosed_on"] as? String, "2026-08-04")
        XCTAssertEqual(body["scheduled_on"] as? String, "2026-08-04")
        XCTAssertEqual(body["site"] as? String, "R Glute")

        // The five. The first three are what the web would have written for this same
        // protocol; `dose_label` is this app's own engine (T-52), and 149 mg/wk at 2
        // injections a week is the same 74.5 mg either way.
        XCTAssertEqual(body["protocol_label"] as? String, "TRT Dose")
        XCTAssertEqual(body["compound_label"] as? String, "Test E")
        XCTAssertEqual(body["category"] as? String, "trt")
        XCTAssertEqual(body["dose_label"] as? String, "74.5 mg")

        // The three. IANA identifier, not an offset — see InjectionMoment.
        XCTAssertEqual(body["injection_time"] as? String, "21:34")
        XCTAssertEqual(body["injection_timezone"] as? String, "Pacific/Auckland")
        XCTAssertEqual(body["injected_at"] as? String, "2026-08-04T09:34:00.000Z")
    }

    /// The dashboard and the calendar log from a projected occurrence, never from the
    /// protocol. If the snapshot did not travel on the occurrence those two paths would
    /// still write NULLs — which is exactly the shape T-59 was.
    func testTheOccurrencePathCarriesTheSameSnapshotAsTheProtocolPath() throws {
        let peptide = dosage(type: "peptide", label: "Melanotan II · 800mcg/inj",
                             config: """
                             {"bawMl":2,"doseUnit":"mcg","peptideMg":85,"syringeMl":1,\
                             "dosePerInj":800,"injPerWeek":2,"peptideType":"Melanotan II"}
                             """)
        // A measurement asserts its own preconditions arrived, not only its result:
        // an empty projection would make the comparison below vacuously unrunnable and
        // tell us nothing about the snapshot.
        XCTAssertTrue(peptide.isActive)
        XCTAssertEqual(peptide.startDate, "2026-01-01")
        XCTAssertEqual(peptide.config["injPerWeek"]?.double, 2)
        XCTAssertEqual(DoseProjection.injectionIntervalDays(for: peptide), 3.5)

        let occurrences = DoseProjection.projectedDoses(
            for: [peptide], from: dpParseDay("2026-08-04")!, days: 14)
        XCTAssertFalse(occurrences.isEmpty, "projected nothing over a 14-day window")
        let occurrence = try XCTUnwrap(occurrences.first)

        let fromOccurrence = NewDoseLogPin(for: occurrence, site: "L Thigh",
                                           now: loggedAt, timeZone: auckland)
        let fromProtocol = NewDoseLogPin(for: peptide, dosedOn: occurrence.dayKey,
                                         site: "L Thigh", now: loggedAt, timeZone: auckland)

        XCTAssertEqual(fromOccurrence.protocolLabel, fromProtocol.protocolLabel)
        XCTAssertEqual(fromOccurrence.compoundLabel, fromProtocol.compoundLabel)
        XCTAssertEqual(fromOccurrence.category, fromProtocol.category)
        XCTAssertEqual(fromOccurrence.doseLabel, fromProtocol.doseLabel)

        XCTAssertEqual(fromOccurrence.protocolLabel, "Melanotan II · 800mcg/inj")
        XCTAssertEqual(fromOccurrence.compoundLabel, "Melanotan II")
        XCTAssertEqual(fromOccurrence.category, "peptide")
        XCTAssertEqual(fromOccurrence.doseLabel, "800 mcg")
    }

    // MARK: - compound_label

    func testCompoundLabelFollowsTheEsterThenTheLabelsPrimaryHalf() {
        // esterType wins, abbreviated the web's way
        let trt = dosage(type: "trt", label: "150mg/wk · Testosterone Enanthate",
                         config: #"{"esterType":"Testosterone Enanthate"}"#)
        XCTAssertEqual(DoseSnapshot(for: trt).compoundLabel, "Test E")

        let acetate = dosage(type: "trt", label: "105mg/wk · Testosterone Acetate",
                             config: #"{"esterType":"Testosterone Acetate"}"#)
        XCTAssertEqual(DoseSnapshot(for: acetate).compoundLabel, "Test Acetate")

        // no ester: the dose-first label is re-ordered so the compound leads
        let steroid = dosage(type: "steroid",
                             label: "300 mg/wk · Masteron (Drostanolone) Enanthate",
                             config: #"{"form":"injectable"}"#)
        XCTAssertEqual(DoseSnapshot(for: steroid).compoundLabel,
                       "Masteron (Drostanolone) Enanthate")

        // compound-first label keeps its order
        let peptide = dosage(type: "peptide", label: "Melanotan II · 800mcg/inj",
                             config: #"{"dosePerInj":800}"#)
        XCTAssertEqual(DoseSnapshot(for: peptide).compoundLabel, "Melanotan II")

        // no separator at all
        let plain = dosage(type: "trt", label: "TRT Dose", config: "{}")
        XCTAssertEqual(DoseSnapshot(for: plain).compoundLabel, "TRT Dose")
    }

    /// `CalculatorCatalog.configExtras` writes `esterType: ""` on every microdose save.
    /// `""` is falsy in the JavaScript this ports; a Swift `!= nil` test would take a
    /// branch the web never takes and freeze an EMPTY compound onto those rows.
    func testAnEmptyEsterIsNotAnEster() {
        let micro = dosage(type: "microdose", label: "0mg/wk · Testosterone Cypionate",
                           config: """
                           {"mode":"ndays","nDays":0,"mgWeek":0,"mlDrawn":0.1,\
                           "strength":200,"esterType":"","syringeMl":1,"injPerWeek":2}
                           """)
        XCTAssertEqual(DoseSnapshot(for: micro).compoundLabel, "Test C",
                       "falls through to the label's compound half, not to \"\"")
    }

    // MARK: - protocol_label and category

    func testAnUnlabelledProtocolTakesTheWebsCapitalisedCalculatorName() {
        let d = dosage(type: "trt", label: nil, config: "{}")
        XCTAssertEqual(DoseSnapshot(for: d).protocolLabel, "Trt")
        XCTAssertEqual(DoseSnapshot(for: d).compoundLabel, "Testosterone (TRT) protocol")
    }

    /// `category` is the RAW calculator_type, not a display name. The live column reads
    /// `trt` / `peptide` / `steroid` / `tirzepatide`; the web maps it through its own
    /// CATEGORY table at render time. A pretty name here would sort and filter apart
    /// from every web-written row.
    func testCategoryIsTheRawCalculatorTypeSlug() {
        for type in ["trt", "peptide", "steroid", "tirzepatide", "bpc157"] {
            XCTAssertEqual(DoseSnapshot(for: dosage(type: type, label: "x", config: "{}")).category,
                           type)
        }
    }

    // MARK: - the injection moment

    func testLoggingTodayStampsTheRealLocalTimeAndTheRealInstant() {
        let moment = InjectionMoment.forLog(dosedOn: "2026-08-04",
                                            now: loggedAt, timeZone: auckland)
        XCTAssertEqual(moment.time, "21:34")
        XCTAssertEqual(moment.timezone, "Pacific/Auckland")
        XCTAssertEqual(moment.injectedAt, "2026-08-04T09:34:00.000Z")
    }

    /// The projection labels occurrence days in UTC while the log sheet labels them in
    /// the device zone, and east of UTC those disagree for half of every day (T-82).
    /// A dashboard tap on today must not be demoted to noon by that.
    func testTodayIsRecognisedInEitherDayFrame() {
        let moment = InjectionMoment.forLog(dosedOn: "2026-08-04",
                                            now: loggedAt, timeZone: auckland)
        XCTAssertEqual(moment.time, "21:34", "local frame")

        // 2026-08-04 09:00 NZST is still 2026-08-03 in UTC — the frame DoseProjection uses.
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 4; c.hour = 9; c.minute = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = auckland
        let morning = cal.date(from: c)!
        XCTAssertEqual(dpFormatDay(morning), "2026-08-03", "precondition: the frames differ")

        let utcFramed = InjectionMoment.forLog(dosedOn: "2026-08-03",
                                               now: morning, timeZone: auckland)
        XCTAssertEqual(utcFramed.time, "09:00")
        XCTAssertEqual(utcFramed.injectedAt, "2026-08-03T21:00:00.000Z",
                       "the instant is true whichever frame named the day")
    }

    /// A back-dated log gets the web's own default rather than an invented time.
    func testLoggingAnotherDayFallsBackToNoonInTheUsersZone() {
        let moment = InjectionMoment.forLog(dosedOn: "2026-07-29",
                                            now: loggedAt, timeZone: auckland)
        XCTAssertEqual(moment.time, "12:00")
        XCTAssertEqual(moment.timezone, "Pacific/Auckland")
        // Noon in Auckland on 2026-07-29 (NZST, UTC+12) is 00:00Z the same day.
        XCTAssertEqual(moment.injectedAt, "2026-07-29T00:00:00.000Z")
    }

    /// An IANA identifier and a UTC offset are not interchangeable. The web stores
    /// `Intl.DateTimeFormat().resolvedOptions().timeZone`, and it is what tells a
    /// reader in another country where the injection happened. An offset also freezes
    /// one side of a DST transition: the same zone is +12 in August and +13 in January.
    func testTheZoneIsAnIANANameAndSurvivesDST() {
        var winter = DateComponents()
        winter.year = 2027; winter.month = 1; winter.day = 15; winter.hour = 8; winter.minute = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = auckland
        let summerTime = cal.date(from: winter)!

        let moment = InjectionMoment.forLog(dosedOn: "2027-01-15",
                                            now: summerTime, timeZone: auckland)
        XCTAssertEqual(moment.timezone, "Pacific/Auckland",
                       "a name, not \"+12:00\" and not \"NZST\"")
        XCTAssertEqual(moment.time, "08:00")
        // NZDT in January: UTC+13, so 08:00 local is 19:00Z the PREVIOUS day.
        XCTAssertEqual(moment.injectedAt, "2027-01-14T19:00:00.000Z")
    }

    /// `injection_time` is a Postgres `time`; the route slices whatever it is given to
    /// five characters and validates `^([01]\d|2[0-3]):[0-5]\d$`.
    func testInjectionTimeIsAlwaysFiveCharactersOfHHmm() {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 4; c.hour = 7; c.minute = 5
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = auckland
        let earlyMorning = cal.date(from: c)!

        let moment = InjectionMoment.forLog(dosedOn: "2026-08-04",
                                            now: earlyMorning, timeZone: auckland)
        XCTAssertEqual(moment.time, "07:05", "zero-padded on both halves")
        XCTAssertEqual(moment.time.count, 5)
    }
}
