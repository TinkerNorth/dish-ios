// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The Connections tab through the real app on the simulator: the "+" on its
/// toolbar opens the Add a PC by address sheet and Cancel lowers it, a swipe
/// on a paired PC's row reveals Forget This PC, the tab scans as it opens
/// only once the Local Network primer was seen, and the empty page takes a
/// pull (an iPad's column a Scan) to refresh. The hints are off, so no
/// popover covers what a test taps. A scan shows "Searching" for a few
/// seconds, which a slow runner looks for too late, so a scan is read where
/// it leaves a mark: Diagnostics lists the Local Network as not asked yet
/// until a browse ran, and as allowed once one did, since the simulator
/// enforces no permission.
@MainActor
final class ConnectionsUITests: XCTestCase {

    private static let addByAddress = "Add a PC by address"
    private static let addressExample = "192.168.1.50"
    private static let rememberedName = "Test PC"
    private static let noPCsYet = "No PCs yet"
    private static let localNetworkNotAsked = "Not asked yet"
    private static let localNetworkAllowed = "Allowed"

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

    /// The Connections tab, wherever the device draws its tabs, with the
    /// primer unseen unless a test says so.
    private func launchOnConnections(primed: Bool = false, _ extraArguments: [String] = []) -> XCUIApplication {
        let app = ShellUI.launch(welcomeCompleted: true, localNetworkPrimed: primed, extraArguments: extraArguments)
        let connections = ShellUI.tab("Connections", in: app)
        XCTAssertTrue(connections.waitForExistence(timeout: ShellUI.patience))
        connections.tap()
        return app
    }

    /// Any element labelled with `label` or starting with it.
    private func element(startingWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// The empty page, once it is drawn: no PC answers the simulator.
    private func emptyPage(of app: XCUIApplication) -> XCUIElement {
        let empty = app.staticTexts[Self.noPCsYet].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: ShellUI.patience), "the page is empty when no PC answers")
        return empty
    }

    /// The Local Network's status as Diagnostics lists it, opened from
    /// Settings: where a finished scan leaves its mark.
    private func localNetworkOnDiagnostics(_ status: String, in app: XCUIApplication) -> XCUIElement {
        ShellUI.openDiagnostics(in: app)
        return app.staticTexts[status].firstMatch
    }

    /// iOS asks about the Local Network when Dish first browses, so the
    /// tab's own scan waits for the setup primer that explains why: opened
    /// first (the primer pinned unseen, whatever an earlier test's Scan left
    /// in the defaults), the tab shows its empty page and looks for nothing,
    /// and the Local Network stays not asked yet for longer than a scan takes.
    func testTheTabOpensWithNoScanBeforeThePrimerWasSeen() {
        let app = launchOnConnections(primed: false)
        XCTAssertTrue(emptyPage(of: app).exists)
        let notAsked = localNetworkOnDiagnostics(Self.localNetworkNotAsked, in: app)
        XCTAssertTrue(notAsked.waitForExistence(timeout: ShellUI.patience))
        XCTAssertTrue(ShellUI.stays(notAsked, for: ShellUI.longerThanAScan), "no scan ran as the tab opened")
    }

    /// With the primer seen (its flag is dish-mac's `local_network_primed`)
    /// the tab looks for PCs as it opens: none answers, and the browse
    /// leaves the Local Network allowed.
    func testTheTabScansAsItOpensOnceThePrimerWasSeen() {
        let app = launchOnConnections(primed: true)
        XCTAssertTrue(emptyPage(of: app).exists, "the scan ended with no PC answering")
        let allowed = localNetworkOnDiagnostics(Self.localNetworkAllowed, in: app)
        XCTAssertTrue(allowed.waitForExistence(timeout: ShellUI.patience), "the opening scan ran")
    }

    func testThePlusOnConnectionsOpensAddAPCByAddressAndCancelLowersIt() {
        let app = launchOnConnections()
        XCTAssertTrue(emptyPage(of: app).exists, "the page is drawn before its toolbar is tapped")
        let add = app.buttons[Self.addByAddress].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: ShellUI.patience))
        add.tap()
        let field = app.textFields[Self.addressExample].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: ShellUI.patience))
        XCTAssertTrue(app.buttons["Connect"].firstMatch.waitForExistence(timeout: ShellUI.patience))
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: ShellUI.patience))
        cancel.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: ShellUI.patience), "Cancel lowered the sheet")
        XCTAssertTrue(ShellUI.tab("Connections", in: app).isSelected)
    }

    /// A swipe from the trailing edge of a paired PC's row reveals Forget
    /// This PC on the row itself, which asks before the PC goes.
    func testASwipeOnAPairedRowRevealsForgetThisPC() {
        let app = launchOnConnections(["-wifi_list", Self.plistData(Self.remembered)])
        let row = element(startingWith: Self.rememberedName, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: ShellUI.patience), "the remembered PC is listed as paired")
        row.swipeLeft()
        let forget = app.buttons["Forget This PC"].firstMatch
        XCTAssertTrue(forget.waitForExistence(timeout: ShellUI.patience))
        XCTAssertTrue(app.navigationBars["Connections"].exists, "the swipe revealed the action on the row, not the PC's page")
        forget.tap()
        XCTAssertTrue(app.buttons["Forget"].firstMatch.waitForExistence(timeout: ShellUI.patience), "Forget This PC asks first")
    }

    /// The empty page scrolls, so a pull reaches the refresh: the page comes
    /// back as it was, and the person's own scan leaves the Local Network
    /// allowed.
    func testPullingTheEmptyPageLooksForPCsAgain() throws {
        try XCTSkipIf(
            UIDevice.current.userInterfaceIdiom == .pad,
            "an iPad's list column does not take a pull to refresh on iPadOS 26; its Scan button is tested instead"
        )
        let app = launchOnConnections()
        let empty = emptyPage(of: app)
        // From the empty state itself: on an iPad the list is a column beside
        // the PC's page, and the window's middle is that page.
        let start = empty.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 360)))
        XCTAssertTrue(empty.waitForExistence(timeout: ShellUI.patience), "the page came back as it was")
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(ShellUI.tab("Connections", in: app).isSelected)
        let allowed = localNetworkOnDiagnostics(Self.localNetworkAllowed, in: app)
        XCTAssertTrue(allowed.waitForExistence(timeout: ShellUI.patience), "the pull ran a scan")
    }

    /// On an iPad the list is a column beside the PC's page, which iPadOS 26
    /// does not let a pull refresh; Scan in the column's toolbar looks for
    /// PCs again, which leaves the Local Network allowed.
    func testOnAnIPadScanBesideTheListLooksForPCsAgain() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the phone's list takes a pull instead")
        let app = launchOnConnections()
        let empty = emptyPage(of: app)
        let scan = app.buttons["Scan"].firstMatch
        XCTAssertTrue(scan.waitForExistence(timeout: ShellUI.patience))
        scan.tap()
        XCTAssertTrue(empty.waitForExistence(timeout: ShellUI.patience), "the page came back as it was")
        let allowed = localNetworkOnDiagnostics(Self.localNetworkAllowed, in: app)
        XCTAssertTrue(allowed.waitForExistence(timeout: ShellUI.patience), "Scan ran a scan")
    }
}
