// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// The Settings tab's switches through the real app: Forwarded features lists
/// Motion, Rumble and Touchpad as switches that stand on until the person
/// turns them off, and the light bar as a picker; Steam Controllers over
/// Bluetooth stand off until the person opts in.
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

    /// How long a flip holds the switch down. A switch takes a touch only once
    /// its press has begun, about a frame after the touch lands; XCUITest's
    /// tap lifts after 50 ms, and on a slow runner the press had not begun by
    /// then. The flip holds ten times as long.
    private static let pressHold: TimeInterval = 0.5

    /// A press on the switch itself: the last 63 points of the row before its
    /// 14-point inset on an iPhone and its 18-point inset on an iPad, so 40
    /// points in from the trailing edge lands on it at either row width.
    private func flip(_ element: XCUIElement) {
        let trailingEdge = element.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
        trailingEdge.withOffset(CGVector(dx: -40, dy: 0)).press(forDuration: Self.pressHold)
    }

    /// Off on a fresh install, so the app never asks for Bluetooth unasked.
    func testSteamControllersOverBluetoothStandOffOnAFreshInstall() {
        let app = launchOnSettings()
        let steam = ShellUI.scrolled(to: forwardedSwitch("Read over Bluetooth", in: app), in: app)
        XCTAssertTrue(steam.waitForExistence(timeout: ShellUI.patience))
        XCTAssertEqual(steam.value as? String, "0")
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
