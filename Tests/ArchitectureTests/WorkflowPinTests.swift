// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// Every `uses:` reference in a workflow is a full commit SHA, so a moved tag
/// cannot change what CI runs. This is the rule of the shared
/// `_security.yml` action-pin lint, run here before a push instead of after.
/// A local `./.github/...` reference, a `docker://…@sha256:` digest and the
/// SLSA generator (which only works as a release tag) are the exceptions.
final class WorkflowPinTests: XCTestCase {

    private static let workflows = ".github/workflows"
    private static let slsaGenerator = #"^slsa-framework/slsa-github-generator/\S+@v\d+\.\d+\.\d+$"#
    private static let dockerDigest = #"^docker://[^@]+@sha256:[0-9a-f]{64}$"#
    private static let shaPin = #"@[0-9a-f]{40}(\s|$)"#
    private static let zeroPin = #"@0{40}(\s|$)"#

    private func workflowFiles() throws -> [String] {
        let directory = RepoFiles.url(Self.workflows)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        return names.filter { $0.hasSuffix(".yml") || $0.hasSuffix(".yaml") }.sorted().map { "\(Self.workflows)/\($0)" }
    }

    /// The reference of a `uses:` mapping key, without its trailing comment;
    /// whole-line comments and every other line give nil.
    private static func reference(in rawLine: String) -> String? {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.hasPrefix("#") else { return nil }
        let withoutComment = line.replacingOccurrences(of: #"\s+#.*$"#, with: "", options: .regularExpression)
        let pattern = #"^-?\s*uses:\s+(\S+)"#
        guard let match = withoutComment.range(of: pattern, options: .regularExpression) else { return nil }
        let key = withoutComment[match]
        return key.replacingOccurrences(of: #"^-?\s*uses:\s+"#, with: "", options: .regularExpression)
    }

    private static func isExempt(_ reference: String) -> Bool {
        reference.hasPrefix("./")
            || reference.range(of: dockerDigest, options: .regularExpression) != nil
            || reference.range(of: slsaGenerator, options: .regularExpression) != nil
    }

    private static func isPinned(_ reference: String) -> Bool {
        (reference + " ").range(of: shaPin, options: .regularExpression) != nil
    }

    private func references() throws -> [(file: String, line: Int, reference: String)] {
        try workflowFiles().flatMap { file in
            try RepoFiles.read(file).split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
                Self.reference(in: String(line)).map { (file: file, line: index + 1, reference: $0) }
            }
        }
    }

    func testTheSweepSeesTheWorkflows() throws {
        XCTAssertFalse(try workflowFiles().isEmpty, "no workflow under \(Self.workflows)")
        XCTAssertFalse(try references().isEmpty, "the sweep must see a uses: line")
    }

    func testEveryActionIsPinnedToACommitSha() throws {
        let unpinned = try references().filter { !Self.isExempt($0.reference) && !Self.isPinned($0.reference) }
        XCTAssertEqual(unpinned.map { "\($0.file):\($0.line) \($0.reference)" }, [], "pin every action to a 40-character commit SHA")
    }

    func testNoPinIsTheAllZeroPlaceholder() throws {
        let zeros = try references().filter { ($0.reference + " ").range(of: Self.zeroPin, options: .regularExpression) != nil }
        XCTAssertEqual(zeros.map { "\($0.file):\($0.line)" }, [], "an all-zero pin is a placeholder, not a commit")
    }

    /// GitHub refuses a whole workflow whose `env:` or `with:` is left empty
    /// (a key whose block holds nothing), and runs none of its jobs.
    func testNoMappingIsLeftEmpty() throws {
        var empty: [String] = []
        for file in try workflowFiles() {
            let lines = try RepoFiles.read(file).components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed == "env:" || trimmed == "with:" else { continue }
                let indent = line.prefix { $0 == " " }.count
                let next = lines.dropFirst(index + 1).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
                if next.prefix(while: { $0 == " " }).count <= indent {
                    empty.append("\(file):\(index + 1) \(trimmed)")
                }
            }
        }
        XCTAssertEqual(empty, [], "a mapping with nothing under it fails the whole workflow")
    }

    /// `THIRD_PARTY.md` lists each action at the release its pin's comment
    /// names (`uses: owner/repo@sha # vX.Y.Z`), so the notice cannot drift
    /// from the workflows the way two of its rows once did.
    func testThirdPartyListsEachActionAtItsPinnedRelease() throws {
        let notice = try RepoFiles.read("THIRD_PARTY.md")
        let pattern = try NSRegularExpression(pattern: #"uses:\s+([\w.-]+/[\w.-]+)(?:/[^@\s]*)?@[0-9a-f]{40}\s+#\s+(v\d+\.\d+\.\d+)"#)
        var pinned: [String: String] = [:]
        for file in try workflowFiles() {
            let text = try RepoFiles.read(file)
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let repo = Range(match.range(at: 1), in: text), let version = Range(match.range(at: 2), in: text) {
                    pinned[String(text[repo])] = String(text[version])
                }
            }
        }
        XCTAssertFalse(pinned.isEmpty, "the sweep must see a pinned action")
        for (repo, version) in pinned.sorted(by: { $0.key < $1.key }) {
            let row = notice.split(separator: "\n").first { $0.contains("(https://github.com/\(repo))") }
            XCTAssertNotNil(row, "THIRD_PARTY.md lists no row for \(repo)")
            XCTAssertTrue(row?.contains("| \(version) |") ?? false, "THIRD_PARTY.md must list \(repo) at \(version)")
        }
    }
}
