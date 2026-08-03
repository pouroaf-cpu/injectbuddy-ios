import XCTest

/// The sibling `AuditFolderConsistencyTests` was always going to need: the audit folder
/// check asserts that a NAME still points at a FILE, and this asserts that a CITATION
/// still points at a RULE.
///
/// WHY IT EXISTS, and it is not the case it was designed for. It was proposed to catch
/// the *missing text* case — `§5.32` and `§5.33` were cited as settled by the TASKLIST,
/// by the directing side and by a comment inside `AuditFolderConsistencyTests` itself
/// while **no text stood behind either number**. That is §5.31 aimed at the rules list.
///
/// What was actually on disk was worse and nobody had seen it: **two different rules
/// numbered 32 and two numbered 33.** `003e859` wrote 31, 32 and 33 in DESCENDING order
/// — `33, 32, 31` — and `9b7d9b2`, scanning forward past 30 for the next number, did not
/// find them and wrote fresh text for 32 and 33 at the end of the list. Both pairs were
/// real, substantive, and different. Every `§5.32` citation in the repo resolved to a
/// coin flip for a day, including the one inside a test that exists to enforce that very
/// rule.
///
/// So this asserts THREE things, and the third is the one that would have prevented it:
///   1. Every rule number appears EXACTLY ONCE.
///   2. Every `§5.NN` cited anywhere in the repo resolves to a rule that exists.
///   3. The rules are NUMBERED IN ASCENDING ORDER, with no gaps.
///
/// (3) is not tidiness. A human or an agent looking for "the next free number" reads
/// forward and stops at the end; a descending run is invisible to that scan, and it is
/// precisely how the duplicate was created. An ordering defect became a correctness
/// defect in the document every cold session reads first.
///
/// SHOWN RED IN ALL THREE DIRECTIONS BEFORE IT WAS TRUSTED — see the commit that added
/// it. A consistency check that has only ever been green is a check nobody has watched
/// work (§5.24).
final class BoardRuleCitationTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)            // …/Tests/InjectBuddyTests/<this file>
            .deletingLastPathComponent()           // …/Tests/InjectBuddyTests
            .deletingLastPathComponent()           // …/Tests
            .deletingLastPathComponent()           // repo root
    }

    private var boardPath: URL {
        repoRoot.appendingPathComponent("docs/ui-audit/BOARD.md")
    }

    private var decisionsPath: URL {
        repoRoot.appendingPathComponent("docs/DECISIONS-2026-08-02.md")
    }

    // MARK: - Reading the rules

    /// A rule DEFINITION: a line in §5 opening `NN. **`.
    ///
    /// Anchored to the line start and to the bold marker together. Either alone is too
    /// loose — `30. ` also opens ordinary numbered prose elsewhere in the document, and
    /// `**` opens most emphasised sentences in it. Both together is the shape the rules
    /// list actually uses, and the count assertion below fails loudly if that ever stops
    /// being true rather than silently matching nothing.
    private func definedRules(in board: String) throws -> [(number: Int, line: Int)] {
        // §5 only. A `12. **` inside §3's prose is not a rule, and the numbering in the
        // findings sections restarts — reading the whole file would invent conflicts.
        let lines = board.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## 5.") }) else {
            XCTFail("No `## 5.` heading in BOARD.md — the rules section has been renamed "
                    + "or removed, and this check has nothing to read. It is not passing.")
            return []
        }
        // Runs to the next `## ` heading, or to the end of the file.
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex

        var found: [(Int, Int)] = []
        for index in (start + 1)..<end {
            let line = lines[index]
            guard let dot = line.firstIndex(of: "."),
                  line.distance(from: line.startIndex, to: dot) <= 3,
                  let number = Int(line[line.startIndex..<dot]),
                  line[dot...].hasPrefix(". **") else { continue }
            found.append((number, index + 1))          // 1-indexed, for a clickable line
        }
        return found
    }

    /// Every `§5.NN` cited anywhere in the repo, with where it was cited.
    ///
    /// Walks the tree rather than taking a list of files: a citation added to a file
    /// nobody thought to enumerate is exactly the citation that goes stale unnoticed.
    /// `.git`, build output and the audit frames are skipped — nothing in them is prose.
    ///
    /// Takes the matcher rather than owning it: `§5.NN` and `D<n>` are two different
    /// citation series in the same tree, and the walk that finds one must find the other.
    /// The `D` series survived a check written the same hour precisely because the walker
    /// was correct and the matcher was one letter too narrow.
    private func citations(matching match: (String) -> [Int]) throws -> [(number: Int, where_: String)] {
        let skip: Set<String> = [".git", ".build", "DerivedData", "build",
                                 "InjectBuddy.xcodeproj", ".claude"]
        let readable: Set<String> = ["swift", "md", "yml", "yaml", "json", "properties"]

        guard let walker = FileManager.default.enumerator(
            at: repoRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else {
            XCTFail("Could not walk the repository from \(repoRoot.path).")
            return []
        }

        var out: [(Int, String)] = []
        for case let url as URL in walker {
            if skip.contains(url.lastPathComponent) {
                walker.skipDescendants()
                continue
            }
            guard readable.contains(url.pathExtension),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

            let relative = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            for (offset, line) in text.components(separatedBy: .newlines).enumerated() {
                for number in match(line) {
                    out.append((number, "\(relative):\(offset + 1)"))
                }
            }
        }
        return out
    }

    /// `§5.24`, `§5.7` → [24, 7]. A bare `§5` is a reference to the SECTION and is not a
    /// citation of any rule, so it is deliberately not matched.
    static func citedNumbers(in line: String) -> [Int] {
        var numbers: [Int] = []
        var rest = Substring(line)
        while let marker = rest.range(of: "§5.") {
            rest = rest[marker.upperBound...]
            let digits = rest.prefix { $0.isNumber }
            if !digits.isEmpty, let value = Int(digits) { numbers.append(value) }
        }
        return numbers
    }

    // MARK: - The `D` rules

    /// Every `D<n>` written in a line, as citations. Both edges are checked, not just the
    /// leading one: a commit hash like `bd43542` must not yield a citation from the digits
    /// after its lowercase `d`, and `3D` must not read as a citation at all.
    ///
    /// Two digits maximum. A longer run of digits in some future hex blob is not a citation
    /// and should not be reported as a dangling one.
    ///
    /// **No example citation appears in this comment on purpose.** The walker reads every
    /// file in the tree including this one, so a number written here as an illustration is
    /// indistinguishable from a real citation — and the first run of this check failed on
    /// exactly that, in this doc comment. It is the sibling of the probe that became the
    /// defect it was measuring (§5.39): the matcher's own documentation is inside the
    /// corpus the matcher reads.
    static func citedDecisions(in line: String) -> [Int] {
        var numbers: [Int] = []
        let characters = Array(line)
        var index = 0
        while index < characters.count {
            defer { index += 1 }
            guard characters[index] == "D" else { continue }

            // Left edge: start of line, or a character that cannot be part of a word.
            if index > 0 {
                let before = characters[index - 1]
                if before.isLetter || before.isNumber || before == "_" { continue }
            }

            var end = index + 1
            while end < characters.count, characters[end].isNumber, end - index <= 2 { end += 1 }
            guard end > index + 1 else { continue }                 // no digits at all

            // Right edge: a following letter, digit or underscore means this was a word.
            if end < characters.count {
                let after = characters[end]
                if after.isLetter || after.isNumber || after == "_" { continue }
            }

            if let value = Int(String(characters[(index + 1)..<end])) { numbers.append(value) }
        }
        return numbers
    }

    /// The rules, read from the `## The `D` rules` section of `DECISIONS-2026-08-02.md`.
    /// A rule is a `### D<n> — …` heading.
    private func definedDecisions(in decisions: String) -> [(number: Int, line: Int)] {
        let lines = decisions.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.hasPrefix("## The `D` rules") }) else {
            XCTFail("No ``## The `D` rules`` heading in DECISIONS-2026-08-02.md. The section "
                    + "has been renamed or removed and this check has nothing to read. It is "
                    + "NOT passing.")
            return []
        }
        // `### ` does not match `hasPrefix("## ")`, so sub-headings stay inside the section.
        let end = lines[(start + 1)...].firstIndex { $0.hasPrefix("## ") } ?? lines.endIndex

        var found: [(Int, Int)] = []
        for index in (start + 1)..<end where lines[index].hasPrefix("### D") {
            // A heading names exactly one rule; take the first number, so a cross-reference
            // later in the title cannot quietly declare a second.
            if let number = Self.citedDecisions(in: lines[index]).first {
                found.append((number, index + 1))
            }
        }
        return found
    }

    /// The declared extent of the series.
    private static let declaredDecisions = 1...10

    /// Every rule defined exactly once, and the series contiguous over its declared extent.
    ///
    /// The gap assertion carries more weight here than on `§5`. A gap in `§5` is a numbering
    /// hazard; a gap here is a rule nobody has noticed is missing — and a number left free is
    /// a number a future rule is given twice, which is how `§5.32` and `§5.33` came to be
    /// written twice and every citation of them resolved to a coin flip for a day.
    func testDecisionRulesAreCompleteAndEachNumberAppearsOnce() throws {
        let decisions = try String(contentsOf: decisionsPath, encoding: .utf8)
        let rules = definedDecisions(in: decisions)

        // A parser that matches nothing passes everything below it (§5.36), so the floor is
        // stated as a number rather than left implicit.
        XCTAssertEqual(
            rules.count, Self.declaredDecisions.count,
            "Parsed \(rules.count) `D` rules, expected \(Self.declaredDecisions.count). Either "
            + "the section's SHAPE changed — in which case this is the parser failing, not the "
            + "series shrinking — or a rule was added or removed without updating the declared "
            + "extent.")

        var seen: [Int: [Int]] = [:]
        for rule in rules { seen[rule.number, default: []].append(rule.line) }

        let duplicated = seen.filter { $0.value.count > 1 }.sorted { $0.key < $1.key }
        XCTAssertTrue(
            duplicated.isEmpty,
            "These `D` numbers are defined more than once, so every citation of them resolves "
            + "to whichever heading you read first:\n"
            + duplicated.map { "  D\($0.key) at lines "
                               + $0.value.map(String.init).joined(separator: ", ") }
                .joined(separator: "\n"))

        let missing = Set(Self.declaredDecisions).subtracting(seen.keys).sorted()
        XCTAssertTrue(
            missing.isEmpty,
            "No rule defined for \(missing.map { "D\($0)" }.joined(separator: ", ")). A free "
            + "number is one a future rule will be given while an old citation still points "
            + "at it.")

        let stray = seen.keys.filter { !Self.declaredDecisions.contains($0) }.sorted()
        XCTAssertTrue(
            stray.isEmpty,
            "\(stray.map { "D\($0)" }.joined(separator: ", ")) is defined outside the declared "
            + "range. Either the range grew — say so where the series is described — or a "
            + "number was invented.")
    }

    /// Every `D<n>` cited anywhere in the repository resolves to a rule that exists.
    ///
    /// **This is the assertion the series exists under.** `D5` alone is cited in eleven files
    /// and is quoted as the invariant an entire UI suite implements; a citation that resolves
    /// to nothing — or, worse, silently to a different rule after a renumber — is a reader
    /// being told something false by a document that looks authoritative.
    func testEveryDecisionCitationResolves() throws {
        let decisions = try String(contentsOf: decisionsPath, encoding: .utf8)
        let defined = Set(definedDecisions(in: decisions).map(\.number))
        XCTAssertFalse(defined.isEmpty, "No `D` rules parsed — see the sibling test.")

        let cited = try citations(matching: Self.citedDecisions)
        XCTAssertFalse(
            cited.isEmpty,
            "Found NO `D<n>` citations anywhere in the repository. There are dozens, in test "
            + "suites, source comments, the handovers and the board. The walker or the matcher "
            + "is broken, and a check that reads nothing reports success about nothing (§5.36).")

        let dangling = cited.filter { !defined.contains($0.number) }
        XCTAssertTrue(
            dangling.isEmpty,
            "These citations name a `D` rule that does not exist:\n"
            + dangling.sorted { $0.where_ < $1.where_ }
                .map { "  D\($0.number) cited at \($0.where_)" }
                .joined(separator: "\n")
            + "\nIf this appeared after a renumber, the citation is stale — repoint it. Do not "
            + "close it by adding a rule at that number.")
    }

    // MARK: - The assertions

    /// 1 + 3. Every rule number is unique, and they ascend without gaps.
    func testRuleNumbersAreUniqueAndAscend() throws {
        let board = try String(contentsOf: boardPath, encoding: .utf8)
        let rules = try definedRules(in: board)

        // A parser that matches nothing passes every assertion below it. This is the
        // seventh time on this project that a check had to be taught to observe the
        // thing it asserts (§5.36), so the floor is stated as a number.
        XCTAssertGreaterThan(rules.count, 30,
                             "Parsed \(rules.count) rules out of BOARD §5. The list has "
                             + "had 30+ for days, so this is the PARSER failing, not the "
                             + "document shrinking — and a parser that matches nothing "
                             + "makes every other assertion in this file vacuous.")

        var seen: [Int: [Int]] = [:]
        for rule in rules { seen[rule.number, default: []].append(rule.line) }

        let duplicated = seen.filter { $0.value.count > 1 }.sorted { $0.key < $1.key }
        XCTAssertTrue(duplicated.isEmpty,
                      "BOARD §5 defines the same rule number more than once, so every "
                      + "citation of it resolves to a coin flip:\n"
                      + duplicated.map { "  §5.\($0.key) defined at lines "
                                         + $0.value.map(String.init).joined(separator: ", ") }
                          .joined(separator: "\n"))

        // ASCENDING AND CONTIGUOUS. The descending run `33, 32, 31` is what hid the
        // duplicate from the next person scanning for a free number.
        let numbers = rules.map(\.number)
        let sorted = numbers.sorted()
        XCTAssertEqual(numbers, sorted,
                       "BOARD §5's rules are not in ascending order. Someone looking for "
                       + "the next free number reads forward and stops at the end, so an "
                       + "out-of-order run is invisible to that scan — which is exactly "
                       + "how §5.32 and §5.33 came to be written twice.\n"
                       + "  order on disk: \(numbers)")

        if let first = sorted.first, let last = sorted.last {
            let missing = Set(first...last).subtracting(sorted).sorted()
            XCTAssertTrue(missing.isEmpty,
                          "BOARD §5 skips \(missing.map { "§5.\($0)" }.joined(separator: ", ")). "
                          + "A gap is a number a future rule will be given twice.")
        }
    }

    /// 2. Every `§5.NN` cited anywhere in the repo resolves to a rule that exists.
    ///
    /// This is the case the check was proposed for: `§5.32` and `§5.33` were cited as
    /// settled — in the TASKLIST, by the directing side, and in a comment inside
    /// `AuditFolderConsistencyTests` — while no text stood behind either number.
    func testEveryCitationResolvesToARuleThatExists() throws {
        let board = try String(contentsOf: boardPath, encoding: .utf8)
        let defined = Set(try definedRules(in: board).map(\.number))
        XCTAssertFalse(defined.isEmpty, "No rules parsed — see the note in the sibling test.")

        let cited = try citations(matching: Self.citedNumbers)
        XCTAssertFalse(cited.isEmpty,
                       "Found NO `§5.NN` citations anywhere in the repository. There are "
                       + "dozens. The walker or the matcher is broken, and a check that "
                       + "reads nothing reports success about nothing (§5.36).")

        let dangling = cited.filter { !defined.contains($0.number) }
        XCTAssertTrue(dangling.isEmpty,
                      "These citations name a rule BOARD §5 does not define:\n"
                      + dangling.sorted { $0.where_ < $1.where_ }
                          .map { "  §5.\($0.number) cited at \($0.where_)" }
                          .joined(separator: "\n"))
    }
}
