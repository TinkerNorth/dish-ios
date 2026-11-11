// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The shell's critical path through the real app on the simulator, an
/// iPhone's or an iPad's: a first run rises under the welcome, Skip lands on
/// Controllers, Add a controller opens the first step, and Settings reopens
/// the guide.
@MainActor
final class SetupFlowUITests: XCTestCase {

    /// The headline names the device the test runs on.
    private static let welcomeTitle =
        "Turn your \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") into a wireless PC gamepad"
    private static let inputTitle = "How do you want to play?"
    private static let addController = "Add a controller"

    func testAFirstRunOpensOnTheWelcomeAndSkipLandsOnControllers() {
        let app = ShellUI.launch(welcomeCompleted: false)
        XCTAssertTrue(ShellUI.element(Self.welcomeTitle, in: app).waitForExistence(timeout: 10))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(ShellUI.element(Self.addController, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(ShellUI.tab("Controllers", in: app).isSelected)
    }

    func testACompletedWelcomeOpensOnTheTabs() {
        let app = ShellUI.launch(welcomeCompleted: true)
        XCTAssertTrue(ShellUI.element(Self.addController, in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(ShellUI.element(Self.welcomeTitle, in: app).exists)
    }

    func testAddAControllerOpensTheInputStepAndSkipComesBack() {
        let app = ShellUI.launch(welcomeCompleted: true)
        XCTAssertTrue(ShellUI.element(Self.addController, in: app).waitForExistence(timeout: 10))
        ShellUI.element(Self.addController, in: app).tap()
        XCTAssertTrue(ShellUI.element(Self.inputTitle, in: app).waitForExistence(timeout: 5))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(ShellUI.element(Self.addController, in: app).waitForExistence(timeout: 5))
    }

    func testTheSetupGuideReopensTheWelcomeFromSettings() {
        let app = ShellUI.launch(welcomeCompleted: true)
        XCTAssertTrue(ShellUI.element(Self.addController, in: app).waitForExistence(timeout: 10))
        ShellUI.tab("Settings", in: app).tap()
        let guide = ShellUI.scrolled(to: ShellUI.element("Setup guide", in: app), in: app)
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(ShellUI.element(Self.welcomeTitle, in: app).waitForExistence(timeout: 5))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(ShellUI.tab("Controllers", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(ShellUI.tab("Controllers", in: app).isSelected, "Skip lands on Controllers from anywhere")
    }
}
