// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The layering, as the compiler cannot state it: which frameworks each
/// module may import. SwiftPM enforces the module dependency graph; this
/// pins the system frameworks, so the pure core stays pure, the engine stays
/// free of UI, and the UI stays free of IO.
final class ImportBoundariesTests: XCTestCase {

    private struct Layer {
        let directory: String
        let allowed: Set<String>
    }

    private static let layers: [Layer] = [
        // CommonCrypto is Apple's C crypto, pure computation: the AES-ECB
        // block primitive the Moonlight pairing prescribes and CryptoKit lacks.
        Layer(directory: "Sources/DishCore", allowed: ["Foundation", "CryptoKit", "CommonCrypto"]),
        Layer(directory: "Sources/DishKernel", allowed: ["Foundation", "Observation"]),
        Layer(
            directory: "Sources/DishEngine",
            allowed: [
                "Foundation",
                "Observation",
                "os",
                "Synchronization",
                "GameController",
                "CoreHaptics",
                "StoreKit",
                "CoreMotion",
                "Network",
                "Security",
                "CryptoKit",
                "Darwin",
                "DishCore",
                "DishKernel"
            ]
        ),
        Layer(
            directory: "Sources/Dish",
            allowed: ["Foundation", "Observation", "SwiftUI", "UIKit", "AppIntents", "TipKit", "DishCore", "DishEngine", "DishKernel"]
        ),
        Layer(directory: "App/Sources", allowed: ["SwiftUI", "AppIntents", "Dish"])
    ]

    /// The only files of the UI library that may import UIKit: the theme's
    /// dynamic colours, the scene, and the app delegate the scene turns the
    /// window through (UIKit asks a delegate for the orientations it allows).
    private static let uikitFiles: Set = [
        "Sources/Dish/UI/Theme.swift", "Sources/Dish/DishScene.swift", "Sources/Dish/Scene/Orientation.swift"
    ]
    /// Where App Intents may be imported: the intents themselves (an intent
    /// is a navigation event), the scene that hands them their router, and
    /// the app target, which App Intents reads the App Shortcuts from.
    private static let appIntentsHomes = ["Sources/Dish/Intents/", "Sources/Dish/DishScene.swift", "App/Sources/"]
    /// The only files that may import TipKit: the kit's hint, which draws a
    /// hint as TipKit's popover, and the scene's switch for TipKit itself.
    private static let tipKitFiles: Set = ["Sources/Dish/UI/Kit/HintTip.swift", "Sources/Dish/Scene/TipKitTips.swift"]
    private static let kit = "Sources/Dish/UI/Kit"

    func testEveryLayerHasSources() {
        for layer in Self.layers {
            XCTAssertFalse(RepoFiles.swiftFiles(under: layer.directory).isEmpty, "no sources under \(layer.directory)")
        }
    }

    func testEachLayerImportsOnlyItsAllowedModules() throws {
        for layer in Self.layers {
            for file in RepoFiles.swiftFiles(under: layer.directory) {
                let imports = try RepoFiles.imports(of: RepoFiles.read(file))
                let forbidden = imports.filter { !layer.allowed.contains($0) }
                XCTAssertEqual(forbidden, [], "\(file) imports \(forbidden); \(layer.directory) allows \(layer.allowed.sorted())")
            }
        }
    }

    func testTheEngineNeverImportsAUIFramework() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/DishEngine") {
            let imports = try RepoFiles.imports(of: RepoFiles.read(file))
            XCTAssertFalse(imports.contains("SwiftUI") || imports.contains("UIKit"), "\(file) reaches a UI framework")
        }
    }

    func testTheUILayerDoesNoIO() throws {
        let ioModules: Set = [
            "Network", "GameController", "CoreHaptics", "StoreKit", "CoreMotion", "Security", "CryptoKit", "Darwin", "IOKit"
        ]
        for file in RepoFiles.swiftFiles(under: "Sources/Dish") {
            let imports = try Set(RepoFiles.imports(of: RepoFiles.read(file)))
            XCTAssertTrue(imports.isDisjoint(with: ioModules), "\(file) imports an IO framework: \(imports.intersection(ioModules))")
        }
    }

    /// UIKit is the escape hatch of the scene, its orientation delegate and
    /// the theme's dynamic colours.
    func testOnlyTheSceneAndTheThemeImportUIKit() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/Dish") where !Self.uikitFiles.contains(file) {
            let imports = try RepoFiles.imports(of: RepoFiles.read(file))
            XCTAssertFalse(imports.contains("UIKit"), "\(file) imports UIKit; only the scene and the theme may")
        }
    }

    func testAppIntentsStaysWithTheIntentsTheSceneAndTheAppTarget() throws {
        let files = RepoFiles.swiftFiles(under: "Sources/Dish") + RepoFiles.swiftFiles(under: "App/Sources")
        for file in files where !Self.appIntentsHomes.contains(where: { file.hasPrefix($0) }) {
            let imports = try RepoFiles.imports(of: RepoFiles.read(file))
            XCTAssertFalse(imports.contains("AppIntents"), "\(file) imports AppIntents; an intent lives in Sources/Dish/Intents")
        }
    }

    func testTipKitStaysWithTheKitsHintAndTheScenesSwitch() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/Dish") where !Self.tipKitFiles.contains(file) {
            let imports = try RepoFiles.imports(of: RepoFiles.read(file))
            XCTAssertFalse(imports.contains("TipKit"), "\(file) imports TipKit; a page points a hint with .hint(_:)")
        }
    }

    /// A kit component takes values and closures, never the domain: it
    /// imports only SwiftUI and Foundation (and TipKit, for the hint) and
    /// observes no model, so it can be drawn from any page's state.
    func testAKitComponentReadsNoDomain() throws {
        let kit = RepoFiles.swiftFiles(under: Self.kit)
        XCTAssertFalse(kit.isEmpty, "the kit has components")
        let modelEnvironment = try NSRegularExpression(pattern: #"@Environment\(\s*\w+\.self"#)
        for file in kit {
            let source = try RepoFiles.read(file)
            let imports = RepoFiles.imports(of: source)
            XCTAssertEqual(imports.filter { !["Foundation", "SwiftUI", "TipKit"].contains($0) }, [], "\(file) reaches past values")
            let environment = modelEnvironment.firstMatch(in: source, range: NSRange(source.startIndex..., in: source))
            XCTAssertNil(environment, "\(file) reads a model from the environment")
            XCTAssertFalse(source.contains("@Bindable"), "\(file) binds to a model")
        }
    }
}
