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
/// walk that lists the on-screen gamepad, Diagnostics, and the waits, which
/// end on a state the app reaches, never on a clock of their own.
@MainActor
enum ShellUI {

    /// How long a test gives the app to reach what it asked for: a page, a
    /// sheet, a scan's end. A wait ends the moment it is met, so a runner
    /// several times slower than a Mac costs nothing but its own time.
    static let patience: TimeInterval = 30

    /// How long a state nothing should change is watched: the app's own scan
    /// browses for a few seconds, so one that was not meant to run would
    /// have left its mark well within this.
    static let longerThanAScan: TimeInterval = 15

    /// The app with the welcome seen or not and the Local Network primer
    /// seen or not, set through the launch arguments, which `UserDefaults`
    /// reads first; both are pinned on every launch, since a test that scans
    /// marks the primer in the simulator's defaults for the launches after
    /// it. TipKit's hints stay hidden, so no popover covers what a test taps.
    static func launch(welcomeCompleted: Bool, localNetworkPrimed: Bool = false, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let onboarding = ["-onboarding_welcome_completed", welcomeCompleted ? "YES" : "NO"]
        let primer = ["-local_network_primed", localNetworkPrimed ? "YES" : "NO"]
        app.launchArguments = onboarding + primer + ["-tips_hidden", "YES"] + extraArguments
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
        XCTAssertTrue(element("Add a controller", in: app).waitForExistence(timeout: patience))
        let alreadyOpen = sidebarTab("Controllers", in: app).exists
        guard !alreadyOpen else { return }
        let toggle = app.buttons.matching(NSPredicate(format: "label == %@", "Toggle sidebar")).firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: patience))
        toggle.tap()
    }

    /// Settings › Diagnostics, which lists the app's facts, the Local
    /// Network's status among them: not asked yet until a scan has run.
    static func openDiagnostics(in app: XCUIApplication) {
        let settings = tab("Settings", in: app)
        XCTAssertTrue(settings.waitForExistence(timeout: patience))
        settings.tap()
        let diagnostics = scrolled(to: element("Diagnostics", in: app), in: app)
        XCTAssertTrue(diagnostics.waitForExistence(timeout: patience))
        diagnostics.tap()
        XCTAssertTrue(element("Local Network", in: app).waitForExistence(timeout: patience))
    }

    /// Setup's walk with the on-screen gamepad and no PC to bind it to: Bind
    /// still lists the gamepad among the controllers, with Open, and lands
    /// on Controllers.
    static func listTheOnScreenGamepad(in app: XCUIApplication) {
        let add = element("Add a controller", in: app)
        XCTAssertTrue(add.waitForExistence(timeout: patience))
        add.tap()
        XCTAssertTrue(element("How do you want to play?", in: app).waitForExistence(timeout: patience))
        let onScreen = scrolled(to: app.staticTexts["On-screen gamepad"].firstMatch, in: app)
        onScreen.tap()
        byAddress(in: app).tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: patience))
        cancel.tap()
        let bind = app.buttons["Bind"].firstMatch
        XCTAssertTrue(bind.waitForExistence(timeout: patience))
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
    /// the Local Network, or on Pick your PC once it has. Whichever step the
    /// input step led to is waited for, not guessed from a clock.
    private static func byAddress(in app: XCUIApplication) -> XCUIElement {
        let primer = app.buttons["Add my PC by address instead"].firstMatch
        let pick = app.buttons["Add a PC by address"].firstMatch
        let eitherStep = NSPredicate { _, _ in primer.exists || pick.exists }
        XCTAssertTrue(holds(eitherStep), "the input step led to the primer or to Pick your PC")
        return primer.exists ? primer : pick
    }

    /// Whether the window comes to stand `way` in time, as the system turns
    /// it with the device.
    static func window(of app: XCUIApplication, turns way: WindowWay) -> Bool {
        holds(NSPredicate { _, _ in way.matches(app.windows.firstMatch.frame) })
    }

    /// Whether `element` comes to read `value` in time; XCUITest reads a
    /// switch a beat after the tap moved it.
    static func settles(_ element: XCUIElement, to value: String) -> Bool {
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [reached], timeout: patience) == .completed
    }

    /// Whether `element` is still there once `span` has passed: an inverted
    /// expectation, for a state nothing should change.
    static func stays(_ element: XCUIElement, for span: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        gone.isInverted = true
        return XCTWaiter().wait(for: [gone], timeout: span) == .completed
    }

    /// Whether `predicate` comes to hold within the patience.
    private static func holds(_ predicate: NSPredicate) -> Bool {
        let held = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [held], timeout: patience) == .completed
    }
}
