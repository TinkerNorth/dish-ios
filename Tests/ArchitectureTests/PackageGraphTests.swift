// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The dependency arrows point one way: core and kernel depend on nothing,
/// the engine on both, the UI library on all three. Read from the manifest's
/// text, so a dependency added in the wrong direction fails here before
/// anyone reads the diff. The app has no third-party package.
final class PackageGraphTests: XCTestCase {

    /// One `.target(...)` / `.executableTarget(...)` / `.testTarget(...)`
    /// block of the manifest, by name.
    private struct TargetBlock {
        let name: String
        let body: String

        var dependencies: [String]? {
            guard let start = body.range(of: "dependencies: [") else { return nil }
            let list = String(body[start.upperBound...].prefix { $0 != "]" })
            return Self.entries(in: list)
        }

        private static func entries(in list: String) -> [String] {
            let regex = try? NSRegularExpression(pattern: #""([^"]+)""#)
            let whole = NSRange(list.startIndex..., in: list)
            return regex?.matches(in: list, range: whole).compactMap { match in
                Range(match.range(at: 1), in: list).map { String(list[$0]) }
            } ?? []
        }

        var treatsWarningsAsErrors: Bool {
            body.contains("swiftSettings: warningsAreErrors")
        }
    }

    private var blocks: [TargetBlock] = []
    private var manifest = ""
    private var project = ""

    override func setUpWithError() throws {
        manifest = try RepoFiles.read("Package.swift")
        project = try RepoFiles.read("project.yml")
        blocks = Self.targetBlocks(in: manifest)
    }

    /// Splits the manifest into target blocks by walking parentheses, so a
    /// nested `.process("Resources")` cannot end a block early.
    private static func targetBlocks(in manifest: String) -> [TargetBlock] {
        let openers = [".target(", ".executableTarget(", ".testTarget("]
        var blocks: [TargetBlock] = []
        var searchStart = manifest.startIndex
        while let opener = openers.compactMap({ manifest.range(of: $0, range: searchStart ..< manifest.endIndex) })
            .min(by: { $0.lowerBound < $1.lowerBound })
        {
            let body = balancedBody(of: manifest, from: opener.upperBound)
            if let name = targetName(in: body) {
                blocks.append(TargetBlock(name: name, body: body))
            }
            searchStart = opener.upperBound
        }
        return blocks
    }

    private static func balancedBody(of manifest: String, from start: String.Index) -> String {
        var depth = 1
        var index = start
        while index < manifest.endIndex, depth > 0 {
            if manifest[index] == "(" { depth += 1 }
            if manifest[index] == ")" { depth -= 1 }
            index = manifest.index(after: index)
        }
        return String(manifest[start ..< index])
    }

    private static func targetName(in body: String) -> String? {
        guard let start = body.range(of: "name: \"") else { return nil }
        return String(body[start.upperBound...].prefix { $0 != "\"" })
    }

    private func block(_ name: String) -> TargetBlock? {
        let found = blocks.first { $0.name == name }
        XCTAssertNotNil(found, "Package.swift declares no target named \(name)")
        return found
    }

    private func manifestLines() -> [String] {
        manifest.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    /// Every `.testTarget(` name of the manifest, in declaration order.
    private func testTargetNames() -> [String] {
        var names: [String] = []
        var searchStart = manifest.startIndex
        while let opener = manifest.range(of: ".testTarget(", range: searchStart ..< manifest.endIndex) {
            let body = Self.balancedBody(of: manifest, from: opener.upperBound)
            Self.targetName(in: body).map { names.append($0) }
            searchStart = opener.upperBound
        }
        return names
    }

    /// The test targets the scheme lists, as the names after `DishPackage/`.
    private func schemeTestTargets() -> [String] {
        let marker = "- package: DishPackage/"
        return project.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(marker) }
            .map { String($0.dropFirst(marker.count)) }
    }

    func testCoreAndKernelDependOnNothing() {
        XCTAssertNil(block("DishCore")?.dependencies)
        XCTAssertNil(block("DishKernel")?.dependencies)
    }

    func testTheEngineDependsOnCoreAndKernelOnly() {
        XCTAssertEqual(block("DishEngine")?.dependencies, ["DishCore", "DishKernel"])
    }

    func testTheUILibraryDependsOnTheEngineCoreAndKernelOnly() {
        XCTAssertEqual(block("Dish")?.dependencies, ["DishEngine", "DishCore", "DishKernel"])
    }

    func testThereAreNoThirdPartyPackages() {
        let packages = manifestLines().filter { $0.contains(".package(") }
        XCTAssertEqual(packages, [], "Dish has no third-party dependency")
    }

    func testEveryTargetTreatsWarningsAsErrors() {
        XCTAssertGreaterThan(blocks.count, 5, "the sweep must see every target")
        for block in blocks {
            XCTAssertTrue(block.treatsWarningsAsErrors, "\(block.name) must build with warnings as errors")
        }
    }

    func testNothingSuppressesWarningsOrPassesUnsafeFlags() {
        XCTAssertFalse(manifest.contains("-suppress-warnings"), "warnings are fixed, never silenced")
        XCTAssertFalse(manifest.contains("unsafeFlags"), "no target passes raw compiler flags")
    }

    func testTheLanguageModeIsSwiftSix() {
        XCTAssertTrue(manifest.contains("swiftLanguageModes: [.v6]"))
    }

    func testThePackageTargetsIOSTwentySix() {
        XCTAssertTrue(manifest.contains("platforms: [.iOS(.v26)]"))
    }

    func testTheManifestToolsVersionIsSixPointTwo() {
        XCTAssertEqual(manifestLines().first, "// swift-tools-version:6.2")
    }

    func testTheProjectDeploysToTheManifestsIOSVersion() {
        let deployment = project.range(of: #"deploymentTarget:\s*\n\s*iOS: "26\.0""#, options: .regularExpression)
        XCTAssertNotNil(deployment, "project.yml must deploy to iOS 26.0, the manifest's .v26")
    }

    /// One `xcodebuild test` runs every test target of the package, so the
    /// scheme lists them all and nothing else.
    func testTheSchemeRunsEveryTestTarget() {
        let testTargets = testTargetNames()
        XCTAssertGreaterThan(testTargets.count, 2, "the sweep must see the test targets")
        XCTAssertEqual(schemeTestTargets().sorted(), testTargets.sorted())
    }

    /// The UI tests live in the project, not the package: the scheme runs
    /// them beside the package's suites.
    func testTheSchemeRunsTheUITestsBesideThePackagesSuites() throws {
        let project = try RepoFiles.read("project.yml")
        XCTAssertTrue(project.contains("  DishUITests:\n    type: bundle.ui-testing"), "project.yml declares the UI test bundle")
        XCTAssertTrue(project.contains("        - DishUITests\n"), "the DishApp scheme lists the UI tests")
    }
}
