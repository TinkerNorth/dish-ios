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
}
