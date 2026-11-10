// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The Connections tab through the real app on the simulator: the "+" on its
/// toolbar opens the Add a PC by address sheet, and Cancel lowers it.
@MainActor
final class ConnectionsUITests: XCTestCase {

    private static let addByAddress = "Add a PC by address"
    private static let addressExample = "192.168.1.50"

    private func launchOnTheTabs() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_welcome_completed", "YES"]
        app.launch()
        return app
    }

    func testThePlusOnConnectionsOpensAddAPCByAddressAndCancelLowersIt() {
        let app = launchOnTheTabs()
        XCTAssertTrue(app.tabBars.buttons["Connections"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Connections"].tap()
        let add = app.buttons[Self.addByAddress].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields[Self.addressExample].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Connect"].firstMatch.exists)
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Connections"].isSelected)
    }
}
