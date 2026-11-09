// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The shell's critical path through the real app on the simulator: a first
/// run rises under the welcome, Skip lands on Controllers, Add a controller
/// opens the first step, and Settings reopens the guide. The onboarding flag
/// is set through the launch arguments, which `UserDefaults` reads first.
@MainActor
final class SetupFlowUITests: XCTestCase {

    private static let welcomeTitle = "Turn your iPhone into a wireless PC gamepad"
    private static let inputTitle = "How do you want to play?"
    private static let addController = "Add a controller"

    private func launch(welcomeCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_welcome_completed", welcomeCompleted ? "YES" : "NO"]
        app.launch()
        return app
    }

    /// Any element labelled `label`, whatever SwiftUI made of it.
    private func element(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func testAFirstRunOpensOnTheWelcomeAndSkipLandsOnControllers() {
        let app = launch(welcomeCompleted: false)
        XCTAssertTrue(element(Self.welcomeTitle, in: app).waitForExistence(timeout: 10))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(element(Self.addController, in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Controllers"].isSelected)
    }

    func testACompletedWelcomeOpensOnTheTabs() {
        let app = launch(welcomeCompleted: true)
        XCTAssertTrue(element(Self.addController, in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(element(Self.welcomeTitle, in: app).exists)
    }

    func testAddAControllerOpensTheInputStepAndSkipComesBack() {
        let app = launch(welcomeCompleted: true)
        XCTAssertTrue(element(Self.addController, in: app).waitForExistence(timeout: 10))
        element(Self.addController, in: app).tap()
        XCTAssertTrue(element(Self.inputTitle, in: app).waitForExistence(timeout: 5))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(element(Self.addController, in: app).waitForExistence(timeout: 5))
    }

    func testTheSetupGuideReopensTheWelcomeFromSettings() {
        let app = launch(welcomeCompleted: true)
        XCTAssertTrue(element(Self.addController, in: app).waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(element("Setup guide", in: app).waitForExistence(timeout: 5))
        element("Setup guide", in: app).tap()
        XCTAssertTrue(element(Self.welcomeTitle, in: app).waitForExistence(timeout: 5))
        app.buttons["Skip"].firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Controllers"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Controllers"].isSelected, "Skip lands on Controllers from anywhere")
    }
}
