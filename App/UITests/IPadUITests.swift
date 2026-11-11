// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The iPad through the real app: its tabs open into a sidebar, and the play
/// cover takes the iPad's own orientation, which iPadOS turns with the
/// device: on its side the gamepad fills the screen, upright it stands along
/// the bottom. An iPhone has neither, so these tests skip there.
@MainActor
final class IPadUITests: XCTestCase {

    override func setUp() async throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the sidebar and the iPad's turning are an iPad's")
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() async throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testTheSidebarListsTheThreeTabs() {
        let app = ShellUI.launch(welcomeCompleted: true)
        ShellUI.openTheSidebar(in: app)
        for title in ["Controllers", "Connections", "Settings"] {
            XCTAssertTrue(ShellUI.sidebarTab(title, in: app).waitForExistence(timeout: 5), "\(title) is in the sidebar")
        }
        XCTAssertTrue(ShellUI.sidebarTab("Controllers", in: app).isSelected)
        ShellUI.sidebarTab("Settings", in: app).tap()
        let guide = ShellUI.scrolled(to: ShellUI.element("Setup guide", in: app), in: app)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
    }

    func testThePlayCoverOpensOnTheIPadsSideAndStandsAlongTheBottomUpright() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = ShellUI.launch(welcomeCompleted: true)
        ShellUI.listTheOnScreenGamepad(in: app)
        let open = app.buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        open.tap()
        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 5))
        XCTAssertTrue(ShellUI.window(of: app, turns: .landscape), "the play cover opens on the iPad's side")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(ShellUI.window(of: app, turns: .portrait), "iPadOS turns the window with the device")
        XCTAssertGreaterThan(pause.frame.minY, app.windows.firstMatch.frame.midY, "upright, the gamepad stands along the bottom")
    }
}
