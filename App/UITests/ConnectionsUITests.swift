// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The Connections tab through the real app on the simulator: the "+" on its
/// toolbar opens the Add a PC by address sheet and Cancel lowers it, a swipe
/// on a paired PC's row reveals Forget This PC, and the empty page takes a
/// pull to refresh. The hints are off, so no popover covers what a test taps.
@MainActor
final class ConnectionsUITests: XCTestCase {

    private static let addByAddress = "Add a PC by address"
    private static let addressExample = "192.168.1.50"
    private static let rememberedName = "Test PC"

    /// One remembered satellite with no key, as the store keeps its rows
    /// (JSON under `wifi_list`): the tab lists it as paired, and with no key
    /// nothing reaches for it.
    private static let remembered =
        #"[{"id":"mid:wave-g3","name":"Test PC","ip":"192.0.2.10","udpPort":9876,"pairPort":9443,"httpPort":9443,"machineId":"wave-g3"}]"#

    /// An old-style property list's data, which the argument domain reads:
    /// the bytes in hex between angle brackets.
    private static func plistData(_ text: String) -> String {
        "<" + Data(text.utf8).map { String(format: "%02x", $0) }.joined() + ">"
    }

    /// The Connections tab, wherever the device draws its tabs.
    private func launchOnConnections(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = ShellUI.launch(welcomeCompleted: true, extraArguments: extraArguments)
        let connections = ShellUI.tab("Connections", in: app)
        XCTAssertTrue(connections.waitForExistence(timeout: 10))
        connections.tap()
        return app
    }

    /// Any element labelled with `label` or starting with it.
    private func element(startingWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    func testThePlusOnConnectionsOpensAddAPCByAddressAndCancelLowersIt() {
        let app = launchOnConnections()
        let add = app.buttons[Self.addByAddress].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields[Self.addressExample].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Connect"].firstMatch.exists)
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 2))
        XCTAssertTrue(ShellUI.tab("Connections", in: app).isSelected)
    }

    /// A swipe from the trailing edge of a paired PC's row reveals Forget
    /// This PC on the row itself, which asks before the PC goes.
    func testASwipeOnAPairedRowRevealsForgetThisPC() {
        let app = launchOnConnections(["-wifi_list", Self.plistData(Self.remembered)])
        let row = element(startingWith: Self.rememberedName, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the remembered PC is listed as paired")
        row.swipeLeft()
        let forget = app.buttons["Forget This PC"].firstMatch
        XCTAssertTrue(forget.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Connections"].exists, "the swipe revealed the action on the row, not the PC's page")
        forget.tap()
        XCTAssertTrue(app.buttons["Forget"].firstMatch.waitForExistence(timeout: 5), "Forget This PC asks first")
    }

    /// The empty page scrolls, so a pull reaches the refresh: the scan runs
    /// ("Searching") and the page comes back as it was.
    func testPullingTheEmptyPageLooksForPCsAgain() {
        let app = launchOnConnections()
        let empty = app.staticTexts["No PCs yet"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 20), "the opening scan ends on the empty page when no PC answers")
        // From the empty state itself: on an iPad the list is a column beside
        // the PC's page, and the window's middle is that page.
        let start = empty.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 360)))
        XCTAssertTrue(app.staticTexts["Searching"].firstMatch.waitForExistence(timeout: 5), "the pull ran a scan")
        XCTAssertTrue(empty.waitForExistence(timeout: 20))
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(ShellUI.tab("Connections", in: app).isSelected)
    }
}
