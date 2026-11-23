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

    // MARK: the shared security and release-hardening workflows

    private func workflow(_ name: String) throws -> String {
        try RepoFiles.read(".github/workflows/\(name)")
    }

    private func env(_ name: String, in text: String) -> String? {
        Self.value(of: name, in: text)
    }

    /// `scripts/tools.sh` runs the scanners at the versions and digests the shared
    /// `_security.yml` installs on Linux (the digests differ: the Mac assets).
    func testToolsShPinsTheScannersTheSharedSecurityWorkflowPins() throws {
        let security = try workflow("_security.yml")
        for name in ["OSV_SCANNER_VERSION", "GITLEAKS_VERSION", "PYYAML_VERSION"] {
            let local = try pin(name)
            XCTAssertEqual(env(name, in: security), local, "scripts/tools.sh and _security.yml pin one \(name)")
        }
        for name in ["OSV_SCANNER_SHA256", "GITLEAKS_SHA256"] {
            let digest = try pin(name)
            XCTAssertNotNil(digest.range(of: "^[0-9a-f]{64}$", options: .regularExpression), "\(name) is not 64 hex digits")
        }
    }

    func testThirdPartyNamesTheScannersAndReleaseToolsTheWorkflowsPin() throws {
        let notice = try RepoFiles.read("THIRD_PARTY.md")
        let security = try workflow("_security.yml")
        let harden = try workflow("_release_harden.yml")
        let pins = [
            ("OSV-Scanner", env("OSV_SCANNER_VERSION", in: security)),
            ("gitleaks", env("GITLEAKS_VERSION", in: security)),
            ("cosign", env("COSIGN_VERSION", in: harden)),
            ("Syft", env("SYFT_VERSION", in: harden)),
            ("Grype", env("GRYPE_VERSION", in: harden))
        ]
        for (name, version) in pins {
            let row = notice.split(separator: "\n").first { $0.hasPrefix("| [\(name)](") }
            XCTAssertNotNil(version, "\(name) is pinned in a shared workflow")
            let shown = version ?? "?"
            XCTAssertTrue(
                row?.contains("| \(shown) |") ?? false,
                "a shared workflow pins \(name) \(shown): edit THIRD_PARTY.md and its copy"
            )
        }
    }

    func testTheSharedWorkflowsAreCalledNotCopied() throws {
        let release = try workflow("release.yml")
        let security = try workflow("security.yml")
        let ci = try workflow("ios-ci.yml")
        XCTAssertTrue(security.contains("uses: ./.github/workflows/_security.yml"))
        XCTAssertTrue(release.contains("uses: ./.github/workflows/_security.yml"), "the tag re-runs the gates")
        XCTAssertTrue(release.contains("uses: ./.github/workflows/_release_harden.yml"), "the tag hardens through the shared workflow")
        XCTAssertTrue(ci.contains("uses: ./.github/workflows/_release_harden.yml"), "pull requests dry-run the same workflow")
        XCTAssertTrue(ci.contains("dry-run: true"))
        for (name, text) in try workflows() where !name.hasPrefix("_") {
            XCTAssertFalse(text.contains("cosign sign-blob"), "\(name): signing is the shared workflow's, not inline")
            XCTAssertFalse(text.contains("TODO_REPLACE_WITH_UPSTREAM_SHA256"), "\(name): no unpinned-tool branch")
            XCTAssertFalse(text.contains("anchore/"), "\(name): Grype and Syft are the shared workflow's pinned binaries")
        }
    }

    /// The provenance recipe names the generator's commit; it is the one `release.yml` pins.
    func testSecurityNamesTheGeneratorCommitReleaseYmlPins() throws {
        let release = try workflow("release.yml")
        let pattern = #"generator_generic_slsa3\.yml@([0-9a-f]{40})"#
        let found = release.range(of: pattern, options: .regularExpression)
        let pinned = try XCTUnwrap(found.map { String(release[$0].suffix(40)) }, "release.yml pins the SLSA generator by commit")
        let security = try RepoFiles.read("SECURITY.md")
        let named = security.contains("generator_generic_slsa3.yml@\(pinned)")
        XCTAssertTrue(named, "SECURITY.md must name the generator commit release.yml pins, \(pinned)")
    }

    func testTheDocumentsCarryTheBundleRecipeAndNotTheOldOne() throws {
        for file in ["SECURITY.md", "CONTRIBUTING.md"] {
            let text = try RepoFiles.read(file)
            XCTAssertTrue(text.contains("_release_harden.yml@refs/tags/"), "\(file) names the signing workflow's identity")
            XCTAssertTrue(text.contains(".sigstore.json"), "\(file) verifies a bundle per file")
            XCTAssertFalse(text.contains("--signature"), "\(file) still carries the .sig and .crt recipe")
            XCTAssertFalse(text.contains("certificate-identity-regexp"), "\(file) still carries the regular-expression identity")
            XCTAssertFalse(text.contains("slsa-verifier verify-artifact"), "\(file): slsa-verifier refuses a generator pinned by commit")
        }
    }
}
