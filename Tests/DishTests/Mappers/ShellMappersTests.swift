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

    func testTheDeadZonesPageIsTitled() {
        XCTAssertEqual(pageTitle(.deadZones(id: "pad")), "Dead zones")
    }

    func testTheMoonlightHostsPageIsTitledAsItsConnectionsRow() {
        XCTAssertEqual(pageTitle(.moonlightHosts), "Moonlight hosts")
    }
}

/// The shell on a regular width (an iPad): which tabs split into a list and
/// the page it opens, what a row does in each, and what the detail column
/// shows.
final class ShellSplitMappersTests: XCTestCase {

    private static let pad = ControllerFact(id: "pad", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil)
    private static let den = ConnectionFact(id: "den", name: "Den PC", address: "192.168.1.40", kind: .satellite, state: .needsPairing)

    func testOnARegularWidthControllersAndConnectionsSplitAndSettingsKeepsItsStack() {
        XCTAssertEqual(Tab.allCases.map { tabLayout($0, width: .regular) }, [.split, .split, .stack])
    }

    func testOnACompactWidthEveryTabKeepsItsStack() {
        XCTAssertEqual(Tab.allCases.map { tabLayout($0, width: .compact) }, [.stack, .stack, .stack])
    }

    func testARowPushesFromAStackAndIsSelectedBesideASplitsList() {
        XCTAssertEqual(rowOpening(.controller(id: "pad"), layout: .stack), .push(.controller(id: "pad")))
        XCTAssertEqual(rowOpening(.pcDetail(id: "den"), layout: .split), .select(.pcDetail(id: "den")))
    }

    func testOnlyASplitsListSelectsThePageBesideIt() {
        let selection = Binding<Page?>.constant(.controller(id: "pad"))
        XCTAssertNil(listSelection(selection, layout: .stack), "a stack's rows push")
        XCTAssertEqual(listSelection(selection, layout: .split)?.wrappedValue, .controller(id: "pad"))
    }

    func testARowWithNoPageOpensNothingInEitherLayout() {
        XCTAssertEqual(rowOpening(nil, layout: .stack), .inert)
        XCTAssertEqual(rowOpening(nil, layout: .split), .inert)
    }

    func testTheDetailIsThePageTheListOpened() {
        XCTAssertEqual(
            tabDetailState(.controllers, opened: .controller(id: "pad"), facts: FactsFixture.shell()),
            .page(.controller(id: "pad"))
        )
        XCTAssertEqual(
            tabDetailState(.controllers, opened: .support, facts: FactsFixture.shell()),
            .page(.support),
            "the heart opens beside the list"
        )
    }

    func testBeforeAControllerIsOpenedTheDetailInvitesAPick() {
        let state = tabDetailState(.controllers, opened: nil, facts: FactsFixture.shell(controllers: [Self.pad]))
        XCTAssertEqual(state, .pick(title: "Pick a controller", symbol: "gamecontroller"))
    }

    func testBeforeAPCIsOpenedTheDetailInvitesAPick() {
        let state = tabDetailState(.connections, opened: nil, facts: FactsFixture.shell(paired: [Self.den]))
        XCTAssertEqual(state, .pick(title: "Pick a PC", symbol: satelliteSymbol))
    }

    func testWithNothingToOpenTheDetailStaysBlank() {
        XCTAssertEqual(tabDetailState(.controllers, opened: nil, facts: FactsFixture.shell()), .blank)
        let unreadable = ControllerFact(id: "pad", name: "Pad", link: .bluetooth, batteryPercent: nil, destination: nil, supported: false)
        let onlyUnreadable = FactsFixture.shell(controllers: [unreadable])
        XCTAssertEqual(tabDetailState(.controllers, opened: nil, facts: onlyUnreadable), .blank, "a pad Dish cannot read opens nothing")
        let onlyFound = FactsFixture.shell(found: [Self.den])
        XCTAssertEqual(tabDetailState(.connections, opened: nil, facts: onlyFound), .blank, "a PC found but not paired opens nothing")
        XCTAssertEqual(tabDetailState(.settings, opened: nil, facts: FactsFixture.shell(controllers: [Self.pad])), .blank)
    }
}
