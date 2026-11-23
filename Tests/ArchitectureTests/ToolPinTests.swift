// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// `scripts/tools.sh` is the one place a toolchain pin lives: the Xcode CI
/// selects and the release binaries the gates fetch, each with a SHA-256.
/// Workflows pin nothing of their own (they call the scripts that source it);
/// what documents repeat of it is compared here, so a pin that moves in one
/// place alone fails a test and not a release.
final class ToolPinTests: XCTestCase {

    private static let script = "scripts/tools.sh"
    private static let tools = ["SWIFTFORMAT", "SWIFTLINT", "XCODEGEN"]

    /// The value of `NAME` written as `NAME="value"` or `NAME: value`
    /// (optionally quoted) on a line of `text`.
    private static func value(of name: String, in text: String) -> String? {
        let pattern = "^\\s*" + name + #"\s*[:=]\s*"?([^"\s#]+)"?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else { return nil }
        let whole = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: whole)
            .flatMap { Range($0.range(at: 1), in: text) }
            .map { String(text[$0]) }
    }

    private func pin(_ name: String) throws -> String {
        try XCTUnwrap(Self.value(of: name, in: RepoFiles.read(Self.script)), "\(Self.script) pins no \(name)")
    }

    private func workflows() throws -> [(name: String, text: String)] {
        let directory = RepoFiles.url(".github/workflows")
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".yml") }
            .sorted()
            .map { try ($0, RepoFiles.read(".github/workflows/\($0)")) }
    }

    func testTheDigestsAreSha256Hex() throws {
        for tool in Self.tools {
            let digest = try pin("\(tool)_SHA256")
            XCTAssertNotNil(digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression), "\(tool)_SHA256 is not 64 hex digits")
        }
    }

    func testNoWorkflowRepeatsAToolPin() throws {
        for (name, text) in try workflows() {
            for tool in Self.tools {
                XCTAssertNil(
                    Self.value(of: "\(tool)_VERSION", in: text),
                    "\(name) repeats \(tool)_VERSION; scripts/tools.sh is the only place"
                )
                XCTAssertNil(
                    Self.value(of: "\(tool)_SHA256", in: text),
                    "\(name) repeats \(tool)_SHA256; scripts/tools.sh is the only place"
                )
            }
        }
    }

    func testEveryAppleJobSelectsTheXcodeByTheScript() throws {
        for (name, text) in try workflows() {
            XCTAssertFalse(
                text.contains("/Applications/Xcode.app"),
                "\(name) selects the image's default Xcode; use scripts/select-xcode.sh"
            )
            if text.contains("macos-26") {
                XCTAssertTrue(text.contains("scripts/select-xcode.sh"), "\(name) runs on macos-26 and must select the pinned Xcode")
            }
        }
    }

    func testTheGeneratorsMinimumVersionIsThePin() throws {
        let project = try RepoFiles.read("project.yml")
        XCTAssertEqual(Self.value(of: "minimumXcodeGenVersion", in: project), try pin("XCODEGEN_VERSION"))
    }

    func testThirdPartyNamesTheToolsAtTheirPinnedVersions() throws {
        let notice = try RepoFiles.read("THIRD_PARTY.md")
        let rows = [
            ("[SwiftFormat](https://github.com/nicklockwood/SwiftFormat)", "SWIFTFORMAT"),
            ("[SwiftLint](https://github.com/realm/SwiftLint)", "SWIFTLINT"),
            ("[XcodeGen](https://github.com/yonaskolb/XcodeGen)", "XCODEGEN")
        ]
        for (link, tool) in rows {
            let version = try pin("\(tool)_VERSION")
            XCTAssertTrue(notice.contains("| \(link) | \(version) |"), "THIRD_PARTY.md must list \(link) at \(version)")
        }
    }

    func testContributingNamesTheToolsAndTheXcodeAtTheirPinnedVersions() throws {
        let text = try RepoFiles.read("CONTRIBUTING.md").replacingOccurrences(of: "\n", with: " ")
        let named = try [
            "SwiftFormat \(pin("SWIFTFORMAT_VERSION"))",
            "SwiftLint \(pin("SWIFTLINT_VERSION"))",
            "XcodeGen \(pin("XCODEGEN_VERSION"))",
            "Xcode \(pin("XCODE_VERSION"))"
        ]
        for phrase in named {
            XCTAssertTrue(text.contains(phrase), "CONTRIBUTING.md must say \"\(phrase)\"")
        }
    }
}
