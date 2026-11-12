// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The Settings tab's global switches through the real app: Forwarded
/// features lists Motion, Rumble and Touchpad as switches that stand on
/// until the person turns them off, and the light bar as a picker.
@MainActor
final class SettingsUITests: XCTestCase {

    private func launchOnSettings() -> XCUIApplication {
        let app = ShellUI.launch(welcomeCompleted: true)
        let settings = ShellUI.tab("Settings", in: app)
        XCTAssertTrue(settings.waitForExistence(timeout: ShellUI.patience))
        settings.tap()
        return app
    }

    /// The switch whose label starts with `title`: its detail line shares the label.
    private func forwardedSwitch(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.switches.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    func testForwardedFeaturesStandOnAndRumbleTurnsOffAndBackOn() {
        let app = launchOnSettings()
        let rumble = ShellUI.scrolled(to: forwardedSwitch("Rumble", in: app), in: app)
        XCTAssertTrue(rumble.waitForExistence(timeout: ShellUI.patience))
        XCTAssertEqual(rumble.value as? String, "1", "a fresh install forwards everything")
        flip(rumble)
        XCTAssertTrue(ShellUI.settles(rumble, to: "0"))
        flip(rumble)
        XCTAssertTrue(ShellUI.settles(rumble, to: "1"))
    }

    /// A tap on the switch itself: the last 51 points of the row before its
    /// 16-point inset, whatever the row's width, so 40 points in from the
    /// trailing edge is its middle on an iPhone and on an iPad either way up.
    private func flip(_ element: XCUIElement) {
        let trailingEdge = element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        trailingEdge.withOffset(CGVector(dx: -40, dy: 0)).tap()
    }

    func testTheLightBarPickerOffersFollowGameAndOff() {
        let app = launchOnSettings()
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Light bar")).firstMatch
        let lightBar = ShellUI.scrolled(to: picker, in: app)
        XCTAssertTrue(lightBar.waitForExistence(timeout: ShellUI.patience))
        lightBar.tap()
        XCTAssertTrue(app.buttons["Follow game"].firstMatch.waitForExistence(timeout: ShellUI.patience))
        XCTAssertTrue(app.buttons["Off"].firstMatch.waitForExistence(timeout: ShellUI.patience))
    }
}
