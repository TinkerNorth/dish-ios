// swift-tools-version:6.2
// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import PackageDescription

/// Every target treats warnings as errors (CONTRIBUTING.md, "Zero warnings").
let warningsAreErrors: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "Dish",
    defaultLocalization: "en",
    platforms: [.iOS(.v26)],
    products: [
        // The app target under App/ links `Dish`, the scene, and through it
        // everything below; the lower modules are products too, so a future
        // extension or bench can link just the layer it needs.
        .library(name: "Dish", targets: ["Dish"]),
        .library(name: "DishEngine", targets: ["DishEngine"]),
        .library(name: "DishCore", targets: ["DishCore"]),
        .library(name: "DishKernel", targets: ["DishKernel"])
    ],
    targets: [
        // The pure core: the reducers and the wire. Foundation only. Its
        // resource is the controller database the app was built with, byte
        // for byte as dish-website publishes `/controllers/v1/`: copied, not
        // processed, so the digests in its manifest still hold.
        .target(
            name: "DishCore",
            path: "Sources/DishCore",
            resources: [.copy("Resources/controllers-v1")],
            swiftSettings: warningsAreErrors
        ),
        // The dataflow primitives the engine's stores are built on.
        // Foundation + Observation only.
        .target(
            name: "DishKernel",
            path: "Sources/DishKernel",
            swiftSettings: warningsAreErrors
        ),
        // The headless engine: the stores, the sockets and the controller
        // bridge to come, and the composition root. No SwiftUI or UIKit; the
        // app hands it lifecycle signals and binds to what it publishes.
        .target(
            name: "DishEngine",
            dependencies: ["DishCore", "DishKernel"],
            path: "Sources/DishEngine",
            swiftSettings: warningsAreErrors
        ),
        // The SwiftUI projection: the scene, the shell, the pages, the theme
        // and the localized words. Its resources are the String Catalog and
        // the brand mark.
        .target(
            name: "Dish",
            dependencies: ["DishEngine", "DishCore", "DishKernel"],
            path: "Sources/Dish",
            resources: [.process("Resources")],
            swiftSettings: warningsAreErrors
        ),
        .testTarget(
            name: "DishCoreTests",
            dependencies: ["DishCore"],
            path: "Tests/DishCoreTests",
            swiftSettings: warningsAreErrors
        ),
        .testTarget(
            name: "DishKernelTests",
            dependencies: ["DishKernel"],
            path: "Tests/DishKernelTests",
            swiftSettings: warningsAreErrors
        ),
        .testTarget(
            name: "DishEngineTests",
            dependencies: ["DishCore", "DishEngine", "DishKernel"],
            path: "Tests/DishEngineTests",
            // Read by path, byte for byte: a resource copy would only add a bundle.
            exclude: ["Fixtures"],
            swiftSettings: warningsAreErrors
        ),
        .testTarget(
            name: "DishTests",
            dependencies: ["Dish", "DishCore", "DishEngine"],
            path: "Tests/DishTests",
            swiftSettings: warningsAreErrors
        ),
        // The repository's rules, read from the tree: imports, the package
        // graph, headers, theme tokens, view purity, localization.
        .testTarget(
            name: "ArchitectureTests",
            path: "Tests/ArchitectureTests",
            // Read by path, byte for byte, as DishEngineTests reads its fixtures.
            exclude: ["Fixtures"],
            swiftSettings: warningsAreErrors
        )
    ],
    swiftLanguageModes: [.v6]
)
