// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The tab bar, the session accessory and what the scene does with the
/// screen, from the engine's facts.
final class ShellMappersTests: XCTestCase {

    func testTheTabsAreControllersConnectionsAndSettingsWithTheirSymbols() {
        let items = tabItems(facts: FactsFixture.shell())
        XCTAssertEqual(items.map(\.tab), [.controllers, .connections, .settings])
        XCTAssertEqual(items.map(\.title), ["Controllers", "Connections", "Settings"])
        XCTAssertEqual(items.map(\.symbol), ["gamecontroller", "antenna.radiowaves.left.and.right", "gearshape"])
        XCTAssertEqual(items.map(\.badge), [nil, nil, nil])
    }

    func testConnectionsWearsABadgeWhileTheSessionsPCStoppedResponding() {
        let items = tabItems(facts: FactsFixture.shell(session: FactsFixture.stopped))
        XCTAssertEqual(items.map(\.badge), [nil, 1, nil])
        XCTAssertEqual(items.map(\.badgeCount), [0, 1, 0])
    }

    func testTheBadgeIsOnlyForAPCThatStoppedResponding() {
        XCTAssertNil(connectionsBadge(session: nil))
        XCTAssertNil(connectionsBadge(session: FactsFixture.streaming()))
        XCTAssertEqual(connectionsBadge(session: FactsFixture.stopped), 1)
    }

    func testThereIsNoSessionBarWhileNothingStreams() {
        XCTAssertNil(sessionBarState(nil))
    }

    func testAStreamingSessionNamesItsPCPadsAndLatency() {
        XCTAssertEqual(
            sessionBarState(FactsFixture.streaming()),
            .streaming(pcName: "Living Room PC", line: "Streaming · 3 pads · 4 ms", shortLine: "3 pads · 4 ms", dim: "Dim", play: "Play")
        )
    }

    func testASessionWithNoLatencyYetLeavesItOut() {
        XCTAssertEqual(
            sessionBarState(FactsFixture.streaming(pads: 2, latencyMs: nil)),
            .streaming(pcName: "Living Room PC", line: "Streaming · 2 pads", shortLine: "2 pads", dim: "Dim", play: "Play")
        )
    }

    func testAPCThatStoppedRespondingOffersReconnect() {
        XCTAssertEqual(
            sessionBarState(FactsFixture.stopped),
            .problem(pcName: "Living Room PC", line: "Stopped responding", reconnect: "Reconnect")
        )
    }

    func testTheScreenStaysOnOnlyWhileStreamingWithKeepScreenOn() {
        let off = PreferencesFacts(deviceName: "", keepScreenOn: false, dimAfter: .twentySeconds, appearance: .system)
        XCTAssertFalse(idleTimerDisabled(facts: FactsFixture.shell()), "nothing streams")
        XCTAssertTrue(idleTimerDisabled(facts: FactsFixture.shell(session: FactsFixture.streaming())))
        XCTAssertTrue(idleTimerDisabled(facts: FactsFixture.shell(session: FactsFixture.stopped)), "Reconnect is still on screen")
        XCTAssertFalse(idleTimerDisabled(facts: FactsFixture.shell(session: FactsFixture.streaming(), preferences: off)))
    }

    func testTheAppearanceSettingPicksTheColourScheme() {
        XCTAssertNil(colorScheme(for: .system))
        XCTAssertEqual(colorScheme(for: .light), .light)
        XCTAssertEqual(colorScheme(for: .dark), .dark)
    }

    func testAPushedControllerPageFallsBackToTheGenericTitle() {
        XCTAssertEqual(pageTitle(.controller(id: "pad")), "Controller")
        XCTAssertEqual(pageTitle(.deviceName), "Name on your PC")
    }

    func testTheHelpSupportLicensesAndDiagnosticsPagesAreTitled() {
        XCTAssertEqual(pageTitle(.help), "Help & FAQ")
        XCTAssertEqual(pageTitle(.support), "Support Dish")
        XCTAssertEqual(pageTitle(.licenses), "Open source licenses")
        XCTAssertEqual(pageTitle(.diagnostics), "Diagnostics")
    }

    func testAPushedPCPageFallsBackToTheGenericTitle() {
        XCTAssertEqual(pageTitle(.pcDetail(id: "den")), "PC")
    }

    /// The model's card names the sheet the shell raises; none closes it.
    func testTheModelsCardNamesTheSheetToRaise() {
        let server = DiscoveredServer(name: "Den PC", ip: "192.168.1.40", machineId: "den")
        XCTAssertEqual(pairingSheetId(OpenPairing(server: server, attempt: PairingAttempt(phase: .awaiting))), "mid:den")
        XCTAssertNil(pairingSheetId(nil))
    }
}
