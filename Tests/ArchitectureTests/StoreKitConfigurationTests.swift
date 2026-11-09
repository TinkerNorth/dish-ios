// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// The simulator sells the three tips: `App/Dish.storekit` declares them as
/// consumables under the identifiers `TipTier` asks for, and the scheme's run
/// action uses it.
final class StoreKitConfigurationTests: XCTestCase {

    private static let configuration = "App/Dish.storekit"
    private static let tips: Set = [
        "com.tinkernorth.dish.ios.tip.small",
        "com.tinkernorth.dish.ios.tip.medium",
        "com.tinkernorth.dish.ios.tip.large"
    ]

    private func products() throws -> [[String: Any]] {
        let json = try RepoFiles.read(Self.configuration)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        return try XCTUnwrap(root["products"] as? [[String: Any]], "the configuration lists its products")
    }

    func testTheConfigurationSellsTheThreeTipsAsConsumables() throws {
        let products = try products()
        let consumables = products.filter { $0["type"] as? String == "Consumable" }
        XCTAssertEqual(Set(consumables.compactMap { $0["productID"] as? String }), Self.tips)
        XCTAssertEqual(products.count, Self.tips.count, "tips are the only products")
    }

    func testTheSchemeRunsWithTheConfiguration() throws {
        let project = try RepoFiles.read("project.yml")
        XCTAssertTrue(project.contains("storeKitConfiguration: \(Self.configuration)"), "project.yml's run action names the configuration")
    }
}
