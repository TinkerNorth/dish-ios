// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The pinned release binaries are written twice: `scripts/tools.sh` fetches
/// them for local runs, `.github/workflows/ios-ci.yml` for CI. A version or a
/// digest that moves in one place alone is a gate that passes locally and
/// fails in CI (or the reverse), so the two are compared here.
final class ToolPinTests: XCTestCase {

    private static let script = "scripts/tools.sh"
    private static let workflow = ".github/workflows/ios-ci.yml"

    /// Tools CI must pin; a tool CI does not run (XcodeGen) is compared only
    /// when the workflow names it.
    private static let required = ["SWIFTFORMAT", "SWIFTLINT"]
    private static let optional = ["XCODEGEN"]
    private static let suffixes = ["VERSION", "SHA256"]

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

    private func assertPinned(_ tool: String, in script: String, and workflow: String) {
        for suffix in Self.suffixes {
            let name = "\(tool)_\(suffix)"
            let local = Self.value(of: name, in: script)
            XCTAssertNotNil(local, "\(Self.script) pins no \(name)")
            XCTAssertEqual(Self.value(of: name, in: workflow), local, "\(name) differs between \(Self.script) and \(Self.workflow)")
        }
    }

    func testTheDigestsAreSha256Hex() throws {
        let script = try RepoFiles.read(Self.script)
        for tool in Self.required + Self.optional {
            let digest = try XCTUnwrap(Self.value(of: "\(tool)_SHA256", in: script), "\(tool)_SHA256 is not pinned")
            XCTAssertNotNil(digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression), "\(tool)_SHA256 is not 64 hex digits")
        }
    }

    func testCIPinsTheSameFormatAndLintTools() throws {
        let script = try RepoFiles.read(Self.script)
        let workflow = try RepoFiles.read(Self.workflow)
        for tool in Self.required {
            assertPinned(tool, in: script, and: workflow)
        }
    }

    func testCIPinsTheSameGeneratorWhenItRunsOne() throws {
        let script = try RepoFiles.read(Self.script)
        let workflow = try RepoFiles.read(Self.workflow)
        for tool in Self.optional where workflow.contains("\(tool)_VERSION") {
            assertPinned(tool, in: script, and: workflow)
        }
    }
}
