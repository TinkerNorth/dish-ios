// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The rules that keep a finding fixed at its cause (CONTRIBUTING, "Zero
/// warnings" and "Shape of the code"): no lint suppressions, no deferred
/// work left as a comment, no mutable statics, no unchecked concurrency, and
/// the shared singletons of UIKit, Foundation and App Intents read only by
/// the scene.
final class NoSuppressionsTests: XCTestCase {

    private static let scene = "Sources/Dish/DishScene.swift"
    private static let singletons = [
        "UIApplication.shared", "UIDevice.current", "UserDefaults.standard", "Bundle.main", "AppDependencyManager.shared"
    ]
    private static let unsafeConcurrency = ["nonisolated(unsafe)", "@unchecked Sendable"]

    private var allSources: [String] {
        RepoFiles.swiftFiles(under: "Sources") + RepoFiles.swiftFiles(under: "Tests")
    }

    func testNoSwiftLintSuppressionAnywhere() throws {
        let marker = "swiftlint:" + "disable"
        for file in allSources {
            let offenders = try RepoFiles.offendingLines(in: file) { $0.contains(marker) }
            XCTAssertEqual(offenders, [], "a lint finding is fixed at its cause, never suppressed")
        }
    }

    func testNoDeferredWorkLeftInAComment() throws {
        for file in allSources where !file.hasSuffix("NoSuppressionsTests.swift") {
            let offenders = try RepoFiles.offendingLines(in: file) { line in
                line.contains("// TODO") || line.contains("// FIXME") || line.contains("// HACK")
            }
            XCTAssertEqual(offenders, [], "deferred work goes in Tests/PARITY.md or an issue, not a comment")
        }
    }

    func testNoMutableStaticsInTheSources() throws {
        for file in RepoFiles.swiftFiles(under: "Sources") {
            let offenders = try RepoFiles.offendingLines(in: file) { line in
                let declaresStaticVar = line.contains("static var ")
                let isAComputedProperty = line.contains("{") && !line.contains("=")
                return declaresStaticVar && !isAComputedProperty
            }
            XCTAssertEqual(offenders, [], "a mutable static is a singleton with the constructor hidden")
        }
    }

    func testUIKitAndFoundationSingletonsAreReadOnlyByTheScene() throws {
        for file in RepoFiles.swiftFiles(under: "Sources") where file != Self.scene {
            let offenders = try RepoFiles.offendingLines(in: file) { line in Self.singletons.contains { line.contains($0) } }
            XCTAssertEqual(offenders, [], "the scene reads the host's singletons and hands values down")
        }
    }

    func testNoUncheckedConcurrencyInTheSources() throws {
        for file in RepoFiles.swiftFiles(under: "Sources") {
            let offenders = try RepoFiles.offendingLines(in: file) { line in Self.unsafeConcurrency.contains { line.contains($0) } }
            XCTAssertEqual(offenders, [], "isolation is stated to the compiler, never promised past it")
        }
    }
}
