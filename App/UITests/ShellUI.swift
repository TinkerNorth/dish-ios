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

/// What the UI tests share on an iPhone and an iPad: the launch, an element
/// by its label, a tab wherever the device draws it, an iPad's sidebar, the
/// walk that lists the on-screen gamepad, and the window's turn.
@MainActor
enum ShellUI {

    /// The app with the welcome seen or not, set through the launch
    /// arguments, which `UserDefaults` reads first.
    static func launch(welcomeCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding_welcome_completed", welcomeCompleted ? "YES" : "NO"]
        app.launch()
        return app
    }

    /// Any element labelled `label`, whatever SwiftUI made of it.
    static func element(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
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

    /// Setup's walk with the on-screen gamepad and no PC to bind it to: Bind
    /// still lists the gamepad among the controllers, with Open, and lands
    /// on Controllers.
    static func listTheOnScreenGamepad(in app: XCUIApplication) {
        let add = element("Add a controller", in: app)
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(element("How do you want to play?", in: app).waitForExistence(timeout: 5))
        let onScreen = scrolled(to: app.staticTexts["On-screen gamepad"].firstMatch, in: app)
        onScreen.tap()
        byAddress(in: app).tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        let bind = app.buttons["Bind"].firstMatch
        XCTAssertTrue(bind.waitForExistence(timeout: 5))
        bind.tap()
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

    /// Add a PC by address: on the primer while iOS has not been asked about
    /// the Local Network, or on Pick your PC once it has.
    private static func byAddress(in app: XCUIApplication) -> XCUIElement {
        let primer = app.buttons["Add my PC by address instead"].firstMatch
        let pick = app.buttons["Add a PC by address"].firstMatch
        let onThePrimer = primer.waitForExistence(timeout: 5)
        return onThePrimer ? primer : pick
    }

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
