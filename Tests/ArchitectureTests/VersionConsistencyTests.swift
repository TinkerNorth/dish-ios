// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The version gate: `VERSION` is the single source of truth. `project.yml`
/// carries it as `MARKETING_VERSION`, the changelog's newest heading names it
/// (or `[Unreleased]`), and the Info.plist writes both bundle versions from
/// build settings, never from a literal.
final class VersionConsistencyTests: XCTestCase {

    private func version() throws -> String {
        try RepoFiles.read("VERSION").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func plistValue(after key: String, in plist: String) throws -> String {
        let lines = plist.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let keyIndex = try XCTUnwrap(lines.firstIndex(of: "<key>\(key)</key>"), "Info.plist must write \(key)")
        return lines[keyIndex + 1]
    }

    func testVersionFileIsMajorMinorPatch() throws {
        let version = try version()
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        XCTAssertEqual(parts.count, 3, "VERSION must be MAJOR.MINOR.PATCH (got '\(version)')")
        for part in parts {
            XCTAssertTrue(!part.isEmpty && part.allSatisfy(\.isNumber), "VERSION component '\(part)' must be numeric")
        }
    }

    func testTheBundledThirdPartyNoticeIsTheRepositorysOwn() throws {
        let root = try RepoFiles.read("THIRD_PARTY.md")
        let bundled = try RepoFiles.read("Sources/Dish/Resources/THIRD_PARTY.md")
        XCTAssertEqual(bundled, root, "copy THIRD_PARTY.md to Sources/Dish/Resources when it changes")
    }

    func testTheProjectCarriesTheVersionAsMarketingVersion() throws {
        let project = try RepoFiles.read("project.yml")
        XCTAssertTrue(try project.contains("MARKETING_VERSION: \"\(version())\""), "project.yml must carry VERSION")
    }

    func testTheChangelogsNewestHeadingNamesTheVersionOrIsUnreleased() throws {
        let changelog = try RepoFiles.read("CHANGELOG.md")
        let heading = try XCTUnwrap(changelog.split(separator: "\n").first { $0.hasPrefix("## [") }, "CHANGELOG.md has no release heading")
        let version = try version()
        XCTAssertTrue(
            heading.hasPrefix("## [\(version)]") || heading.hasPrefix("## [Unreleased]"),
            "the newest heading must be [\(version)] or [Unreleased]: \(heading)"
        )
    }

    func testTheInfoPlistWritesBothVersionsFromBuildSettings() throws {
        let plist = try RepoFiles.read("App/Info.plist")
        XCTAssertEqual(try plistValue(after: "CFBundleShortVersionString", in: plist), "<string>$(MARKETING_VERSION)</string>")
        XCTAssertEqual(try plistValue(after: "CFBundleVersion", in: plist), "<string>$(CURRENT_PROJECT_VERSION)</string>")
    }

    /// The newest protocol the code offers, read from the one constant.
    private func codeProtocol() throws -> (offered: Int, floor: Int) {
        let source = try RepoFiles.read("Sources/DishCore/ProtocolConstants.swift")
        func constant(_ name: String) throws -> Int {
            let pattern = name + #"\s*=\s*(\d+)"#
            let match = try XCTUnwrap(source.range(of: pattern, options: .regularExpression), "no \(name) in ProtocolConstants.swift")
            return try XCTUnwrap(Int(source[match].filter(\.isNumber)))
        }
        return try (constant("protocolVersion"), constant("protocolVersionMin"))
    }

    /// A document that names the protocol the client speaks names the code's:
    /// every "protocol N" in these is the offered version or the floor.
    func testTheProtocolDocumentsNameTheProtocolTheCodeSpeaks() throws {
        let code = try codeProtocol()
        for file in ["SECURITY.md", "docs/contract.md", "docs/ARCHITECTURE.md", "CONTRIBUTING.md"] {
            let text = try RepoFiles.read(file)
            let regex = try NSRegularExpression(pattern: #"(?i)\bprotocol (\d+)"#)
            for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                let range = try XCTUnwrap(Range(match.range(at: 1), in: text))
                let number = try XCTUnwrap(Int(text[range]))
                XCTAssertTrue(
                    [code.offered, code.floor].contains(number),
                    "\(file) names protocol \(number); the code offers \(code.offered) and floors at \(code.floor)"
                )
            }
        }
    }

    func testSecurityNamesTheProtocolTheClientOffers() throws {
        let security = try RepoFiles.read("SECURITY.md")
        XCTAssertTrue(try security.contains("protocol \(codeProtocol().offered)"), "SECURITY.md must name the offered protocol")
    }

    /// A ledger row that names a file names one that exists: the Swift files
    /// `Tests/PARITY.md` and `docs/ARCHITECTURE.md` cite are in the tree.
    func testTheSwiftFilesTheDocumentsNameExist() throws {
        let swift = ["Sources", "Tests", "App"].flatMap(RepoFiles.swiftFiles(under:)).map { ($0 as NSString).lastPathComponent }
        let existing = Set(swift + ["Package.swift"])
        let regex = try NSRegularExpression(pattern: #"`(?:[A-Za-z0-9_+]+/)*([A-Za-z0-9_+]+\.swift)`"#)
        for file in ["Tests/PARITY.md", "docs/ARCHITECTURE.md"] {
            let text = try RepoFiles.read(file)
            let names = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range(at: 1), in: text).map { String(text[$0]) }
            }
            // `+Approval.swift` names the extension files of a type: some file ends that way.
            let missing = names.filter { name in
                name.hasPrefix("+") ? !swift.contains { $0.hasSuffix(name) } : !existing.contains(name)
            }
            XCTAssertEqual(missing, [], "\(file) names a Swift file that is not in the tree")
        }
    }
}
