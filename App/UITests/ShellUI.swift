// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest

/// Which way a window stands.
enum WindowWay {
    case landscape
    case portrait

    func matches(_ frame: CGRect) -> Bool {
        switch self {
        case .landscape: frame.width > frame.height
        case .portrait: frame.height > frame.width
        }
    }
}

/// What the UI tests share on an iPhone and an iPad: the launch, a
/// remembered PC to launch with, an element by its label, a tab wherever the
/// device draws it, an iPad's sidebar, the walk that binds the on-screen
/// gamepad, its page, and the window's turn.
@MainActor
enum ShellUI {

    /// The app with the welcome seen or not, set through the launch
    /// arguments, which `UserDefaults` reads first.
    /// TipKit's hints stay hidden, so no popover covers what a test taps.
    static func launch(welcomeCompleted: Bool, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_welcome_completed", welcomeCompleted ? "YES" : "NO", "-tips_hidden", "YES"] + extraArguments
        app.launch()
        return app
    }

    /// A remembered satellite with no key, as the store keeps its rows
    /// (JSON under `wifi_list`): the Connections tab lists it as paired, and
    /// with no key nothing reaches for it.
    static let rememberedName = "Test PC"
    static let remembered =
        #"[{"id":"mid:wave-g3","name":"Test PC","ip":"192.0.2.10","udpPort":9876,"pairPort":9443,"httpPort":9443,"machineId":"wave-g3"}]"#

    /// The launch arguments that list the remembered PC, so setup's pick
    /// step and the Connections tab offer it.
    static let withARememberedPC = ["-wifi_list", plistData(remembered)]

    /// An old-style property list's data, which the argument domain reads:
    /// the bytes in hex between angle brackets.
    static func plistData(_ text: String) -> String {
        "<" + Data(text.utf8).map { String(format: "%02x", $0) }.joined() + ">"
    }

    /// Any element labelled `label`, whatever SwiftUI made of it.
    static func element(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Any element whose label starts with `label`: a row whose children are
    /// combined reads its name first.
    static func element(startingWith label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// A tab's button: in the tab bar on an iPhone, and in the bar along the
    /// top on an iPad, which XCUITest does not see as a tab bar.
    static func tab(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// A tab as a row of an iPad's sidebar.
    static func sidebarTab(_ title: String, in app: XCUIApplication) -> XCUIElement {
        app.cells.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Opens an iPad's tabs into their sidebar from the bar along the top,
    /// unless iPadOS kept the sidebar open from an earlier launch.
    static func openTheSidebar(in app: XCUIApplication) {
        XCTAssertTrue(element("Add a controller", in: app).waitForExistence(timeout: 10))
        let alreadyOpen = sidebarTab("Controllers", in: app).exists
        guard !alreadyOpen else { return }
        let toggle = app.buttons.matching(NSPredicate(format: "label == %@", "Toggle sidebar")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
    }

    /// Setup's walk that binds the on-screen gamepad to the remembered PC
    /// (`withARememberedPC`): Add a controller, the on-screen gamepad,
    /// Continue past the Local Network primer while iOS has not been asked
    /// yet, the PC on the pick step, then Bind, which lands on Controllers
    /// with the gamepad listed and bound.
    static func bindTheOnScreenGamepad(in app: XCUIApplication) {
        let add = element("Add a controller", in: app)
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(element("How do you want to play?", in: app).waitForExistence(timeout: 5))
        let onScreen = scrolled(to: app.staticTexts["On-screen gamepad"].firstMatch, in: app)
        onScreen.tap()
        let primer = app.buttons["Continue"].firstMatch
        if primer.waitForExistence(timeout: 5) {
            primer.tap()
        }
        let pc = element(startingWith: rememberedName, in: app)
        XCTAssertTrue(pc.waitForExistence(timeout: 10), "the remembered PC is on the pick step")
        pc.tap()
        let bind = app.buttons["Bind"].firstMatch
        XCTAssertTrue(bind.waitForExistence(timeout: 5))
        bind.tap()
    }

    /// The on-screen gamepad's page, opened from its row on Controllers.
    static func openTheOnScreenGamepadsPage(in app: XCUIApplication) {
        let row = element(startingWith: "On-screen gamepad", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the on-screen gamepad is listed")
        row.tap()
    }

    /// `element` once a few swipes have brought it on screen: a list draws
    /// only the rows it shows, and a pad the simulator sees pushes the ways
    /// in down the input step.
    static func scrolled(to element: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        for _ in 0 ..< 4 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        return element
    }

    // Add a PC by address: on the primer while iOS has not been asked about
    // the Local Network, or on Pick your PC once it has.

    /// Whether the window stands `way` within a few seconds, as the system
    /// turns it with the device.
    static func window(of app: XCUIApplication, turns way: WindowWay) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, !way.matches(app.windows.firstMatch.frame) {
            Thread.sleep(forTimeInterval: 0.25)
        }
        return way.matches(app.windows.firstMatch.frame)
    }
}
