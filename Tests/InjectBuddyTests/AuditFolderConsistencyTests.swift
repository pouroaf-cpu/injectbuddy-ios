import XCTest

/// A frame table that names a file, and a folder that holds one.
///
/// The `2026-08-02-current` README listed `IB2245743` and `IB2245744` for two AX5
/// frames after those files had been superseded by `IB2245746` and `IB2245747`, and it
/// never listed `IB2245748` at all. So the README named serials that were not in the
/// folder, and the folder held a frame the README did not know about. Nobody's harness
/// ran this check; it was caught by a human reading the table against a checkout.
///
/// That is the same class as the stale Documents directory and the byte-identical
/// "refresh": **a name that outlives its content**. This project's whole evidence chain
/// — serial, log row, commit SHA — is worth exactly what the link between a name and a
/// file is worth.
///
/// BOTH DIRECTIONS, deliberately. The failure that actually happened was
/// table-names-a-missing-file; the other one, folder-holds-an-unlisted-file, is just as
/// reachable and is how `IB2245748` went unlisted for a day. Checking only the
/// direction that bit us is how the next one gets through.
///
/// Runs as a unit test rather than a script so it cannot be a step someone forgets:
/// `#filePath` locates the repo at compile time, which is the same trick that lets this
/// run in CI without knowing the checkout path.
final class AuditFolderConsistencyTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)            // …/Tests/InjectBuddyTests/<this file>
            .deletingLastPathComponent()           // …/Tests/InjectBuddyTests
            .deletingLastPathComponent()           // …/Tests
            .deletingLastPathComponent()           // repo root
    }

    /// Every `*-current` folder, so a future dated folder is covered the day it is
    /// created rather than the day someone remembers to add it here.
    private func currentFolders() throws -> [URL] {
        let auditRoot = repoRoot.appendingPathComponent("docs/ui-audit")
        let entries = try FileManager.default.contentsOfDirectory(
            at: auditRoot, includingPropertiesForKeys: [.isDirectoryKey])
        return entries
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasSuffix("-current") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// The folders that existed when the serial rule landed, ENUMERATED.
    ///
    /// Not "folders dated before 2026-08-02". A date predicate is evaluated at runtime,
    /// so the exempt set is closed only by CONVENTION: a folder named
    /// `2026-07-30-something` created next week satisfies it and walks straight out of
    /// the rule, and the innocent version — someone reorganising an old capture into a
    /// new folder — is likelier than the adversarial one. A literal list is closed by
    /// construction. Nothing can join it without someone editing this array.
    ///
    /// The general test, and it is what separates this from narrowing an assertion
    /// until it passes: **an exemption is safe when the exempted set cannot grow.** Ask
    /// what could join it tomorrow. Here: nothing. See BOARD §5.32.
    ///
    /// These frames are NOT backfilled with serials, deliberately. They have no
    /// reliable per-frame capture time, and issuing serials now would manufacture a
    /// provenance that never existed — T17's reasoning with the sign flipped, since an
    /// in-image stamp was refused for mutating evidence in order to label it. A
    /// documented gap is honest; an invented serial is a number that looks issued and
    /// was not.
    private static let preSerialFolders: Set<String> = [
        "2026-08-01-current",
    ]

    /// Folders the serial rule applies to: everything not in the grandfathered list.
    private func serialisedFolders() throws -> [URL] {
        try currentFolders().filter { !Self.preSerialFolders.contains($0.lastPathComponent) }
    }

    /// ...and the exemption is asserted from the other end. If a grandfathered folder
    /// ever gains serialised rows it has joined the rule and must be covered; without
    /// this, the list is a place coverage can quietly leak out of.
    func testPreSerialFoldersReallyArePreSerial() throws {
        let present = Set(try currentFolders().map { $0.lastPathComponent })
        for name in Self.preSerialFolders {
            guard present.contains(name) else {
                XCTFail("`preSerialFolders` names \(name) and there is no such folder. A "
                        + "grandfather clause for something that is not there exempts nothing "
                        + "and hides that it exempts nothing.")
                continue
            }
            let rows = try frameTableFiles(in: repoRoot
                .appendingPathComponent("docs/ui-audit").appendingPathComponent(name))
            XCTAssertTrue(rows.isEmpty,
                          "\(name) is grandfathered out of the serial rule and yet lists "
                          + "\(rows.count) serialised frame(s). It is no longer pre-serial, so "
                          + "it is no longer exempt — remove it from `preSerialFolders`.")
        }
    }

    func testEveryFrameTableRowNamesAFileThatExists() throws {
        let folders = try serialisedFolders()
        XCTAssertFalse(folders.isEmpty,
                       "No serialised *-current folders found — the check would pass by "
                       + "looking at nothing.")

        for folder in folders {
            let listed = try frameTableFiles(in: folder)
            XCTAssertFalse(listed.isEmpty,
                           "\(folder.lastPathComponent): README has no frame-table rows. "
                           + "Either the table is gone or the parser no longer matches it — "
                           + "and a parser that matches nothing passes silently.")

            for (serial, filename) in listed {
                let path = folder.appendingPathComponent(filename)
                XCTAssertTrue(FileManager.default.fileExists(atPath: path.path),
                              "\(folder.lastPathComponent): README lists \(serial) as "
                              + "`\(filename)` and that file is not in the folder. A README "
                              + "naming a serial that is not there is what the log exists to "
                              + "make detectable.")
            }
        }
    }

    func testEveryFrameInTheFolderAppearsInTheTable() throws {
        for folder in try serialisedFolders() {
            let listed = Set(try frameTableFiles(in: folder).map(\.filename))
            let onDisk = try FileManager.default
                .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension.lowercased() == "png" }
                .map(\.lastPathComponent)

            for filename in onDisk {
                XCTAssertTrue(listed.contains(filename),
                              "\(folder.lastPathComponent): `\(filename)` is in the folder and "
                              + "not in the README's frame table. An unlisted frame is one "
                              + "nobody can trace to a capture event, a commit or a defect.")
            }
        }
    }

    // MARK: - Parsing

    /// Rows of the form `| IB2245749 | \`06-calculator-trt-IB2245749.png\` | … |`.
    ///
    /// ONLY the frame table. The README also names superseded serials in prose —
    /// "supersedes IB2245740", "compare against IB2245730" — and those files are
    /// deliberately not in the folder, so a check that scanned every `IB\d{7}` in the
    /// document would fail on the correct behaviour and get switched off.
    private func frameTableFiles(in folder: URL) throws -> [(serial: String, filename: String)] {
        let readme = folder.appendingPathComponent("README.md")
        let text = try String(contentsOf: readme, encoding: .utf8)
        let pattern = #"^\|\s*(IB\d{7})\s*\|\s*`([^`]+\.png)`\s*\|"#
        let re = try NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map {
            (ns.substring(with: $0.range(at: 1)), ns.substring(with: $0.range(at: 2)))
        }
    }
}
