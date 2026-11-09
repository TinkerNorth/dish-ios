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
        .library(name: "DishKernel", targets: ["DishKernel"])
    ],
    targets: [
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
            dependencies: ["DishKernel"],
            path: "Sources/DishEngine",
            swiftSettings: warningsAreErrors
        ),
        // The SwiftUI projection: the scene, the shell, the pages, the theme
        // and the localized words. Its resources are the String Catalog and
        // the brand mark.
        .target(
            name: "Dish",
            dependencies: ["DishEngine", "DishKernel"],
            path: "Sources/Dish",
            resources: [.process("Resources")],
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
            dependencies: ["DishEngine", "DishKernel"],
            path: "Tests/DishEngineTests",
            swiftSettings: warningsAreErrors
        ),
        .testTarget(
            name: "DishTests",
            dependencies: ["Dish", "DishEngine"],
            path: "Tests/DishTests",
            swiftSettings: warningsAreErrors
        )
    ],
    swiftLanguageModes: [.v6]
)
