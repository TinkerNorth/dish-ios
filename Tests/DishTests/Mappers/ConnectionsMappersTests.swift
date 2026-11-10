// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The clock and the PCs the Connections tests draw.
private enum ConnectionsFixture {
    static let yesterday = FactsFixture.now.addingTimeInterval(-86400)
    static let settings = URL(string: "app-settings:")

    static func pc(_ name: String, kind: ConnectionKind = .satellite, state: ConnectionState) -> ConnectionFact {
        ConnectionFact(id: name, name: name, address: "192.168.1.40", kind: kind, state: state)
    }

    static func page(_ facts: ShellFacts) -> ConnectionsContent {
        connectionsPageState(facts: facts, settingsURL: settings).content
    }

    static func list(_ facts: ShellFacts) throws -> ConnectionsListState {
        guard case let .list(list) = page(facts) else { throw NotAList() }
        return list
    }
}

/// The page drew an empty state where the test expected sections.
private struct NotAList: Error {}

/// The Connections tab (D1, D3).
final class ConnectionsMappersTests: XCTestCase {

    func testThePageIsTitledAndItsToolbarAddsAPCByAddress() {
        let state = connectionsPageState(facts: FactsFixture.shell(), settingsURL: nil)
        XCTAssertEqual(state.title, "Connections")
        XCTAssertEqual(state.add, "Add a PC by address")
    }

    func testWithLocalNetworkDeniedThePageExplainsAndOpensSettings() {
        let state = ConnectionsFixture.page(FactsFixture.shell(
            paired: [ConnectionsFixture.pc("Office PC", state: .needsPairing)],
            localNetwork: .denied
        ))
        let denied = NetworkDeniedState(
            title: "Dish can’t see your network",
            body: "Local Network is off for Dish, so it can’t find Satellite or send input to your PC. "
                + "Turn it on and Dish picks up where it left off.",
            openSettings: "Open Settings",
            settingsURL: ConnectionsFixture.settings,
            caption: "Settings › Dish › Local Network"
        )
        XCTAssertEqual(state, .denied(denied))
    }

    func testWithNothingPairedOrFoundThePageSaysNoPCsYet() {
        let state = ConnectionsFixture.page(FactsFixture.shell())
        XCTAssertEqual(state, .empty(title: "No PCs yet", body: "Run Satellite on a PC on this Wi‑Fi and it shows up here."))
        XCTAssertEqual(ConnectionsFixture.page(FactsFixture.shell(localNetwork: .allowed)), state)
    }

    func testWhileScanningTheFoundSectionShowsEvenWithNothingFoundYet() throws {
        let list = try ConnectionsFixture.list(FactsFixture.shell(scanning: true))
        XCTAssertNil(list.paired)
        XCTAssertEqual(list.found, FoundSectionState(title: "Found on your Wi‑Fi", searching: "Searching", rows: []))
        XCTAssertEqual(list.moonlightTitle, "Moonlight hosts")
        XCTAssertEqual(list.moonlightHint, "Sunshine, Apollo or Wolf. Input only.")
        XCTAssertEqual(
            list.footnote,
            "Satellite is the fastest path. A Moonlight host works without installing anything new, at a little more latency."
        )
    }

    func testPairedPCsAreWordedByTheirState() throws {
        let list = try ConnectionsFixture.list(FactsFixture.shell(paired: [
            ConnectionsFixture.pc("Living Room PC", state: .online(latencyMs: 4, controllers: 3)),
            ConnectionsFixture.pc("Office PC", state: .offline(lastSeen: ConnectionsFixture.yesterday)),
            ConnectionsFixture.pc("Attic PC", kind: .moonlight, state: .offline(lastSeen: nil))
        ]))
        XCTAssertEqual(list.paired?.title, "Paired")
        XCTAssertEqual(list.paired?.rows.map(\.line), ["Online · 4 ms · 3 controllers", "Offline · seen yesterday", "Offline"])
        XCTAssertEqual(list.paired?.rows.map(\.dot), [DishTheme.success, DishTheme.muted, DishTheme.muted])
        XCTAssertEqual(
            list.paired?.rows.map(\.symbol),
            ["antenna.radiowaves.left.and.right", "antenna.radiowaves.left.and.right", "desktopcomputer"]
        )
        XCTAssertNil(list.found, "not scanning and nothing found")
    }

    func testAFoundPCThatNeedsPairingShowsItsAddressAndOffersPair() throws {
        let list = try ConnectionsFixture.list(FactsFixture.shell(found: [ConnectionsFixture.pc("Den PC", state: .needsPairing)]))
        let row = ConnectionRowState(
            id: "Den PC",
            symbol: "antenna.radiowaves.left.and.right",
            name: "Den PC",
            line: "Needs pairing · 192.168.1.40",
            dot: DishTheme.warning,
            button: ConnectionRowButton(title: "Pair", action: .pair(serverId: "Den PC")),
            page: nil
        )
        XCTAssertEqual(list.found, FoundSectionState(title: "Found on your Wi‑Fi", searching: nil, rows: [row]))
    }

    /// A paired row opens its PC's page; one that is offline offers Connect
    /// and one whose key the PC revoked offers Pair.
    func testPairedRowsOpenTheirPageAndOfferConnectOrPair() throws {
        let list = try ConnectionsFixture.list(FactsFixture.shell(paired: [
            ConnectionsFixture.pc("Living Room PC", state: .online(latencyMs: 4, controllers: 3)),
            ConnectionsFixture.pc("Office PC", state: .offline(lastSeen: nil)),
            ConnectionsFixture.pc("Den PC", state: .needsPairing)
        ]))
        let rows = try XCTUnwrap(list.paired?.rows)
        XCTAssertEqual(rows.map(\.page), [.pcDetail(id: "Living Room PC"), .pcDetail(id: "Office PC"), .pcDetail(id: "Den PC")])
        XCTAssertEqual(rows.map(\.button), [
            nil,
            ConnectionRowButton(title: "Connect", action: .connect(id: "Office PC")),
            ConnectionRowButton(title: "Pair", action: .pair(serverId: "Den PC"))
        ])
    }

    /// A satellite that never advertised a name is known by its address.
    func testANamelessPCIsKnownByItsAddress() {
        let pc = ConnectionFact(id: "wifi:192.168.1.50:9876", name: "", address: "192.168.1.50", kind: .satellite, state: .needsPairing)
        XCTAssertEqual(connectionTitle(pc), "192.168.1.50")
        XCTAssertEqual(connectionRow(pc, now: FactsFixture.now).name, "192.168.1.50")
        XCTAssertEqual(connectionTitle(ConnectionsFixture.pc("Den PC", state: .needsPairing)), "Den PC")
    }

    /// The fleet's ladder has a Bluetooth rung, Android's own gamepad layer;
    /// no PC on iOS is one, and it would draw as the client's own wire.
    func testEachKindOfPCHasItsGlyph() {
        XCTAssertEqual(connectionSymbol(.satellite), satelliteSymbol)
        XCTAssertEqual(connectionSymbol(.moonlight), "desktopcomputer")
        XCTAssertEqual(connectionSymbol(.bluetooth), satelliteSymbol)
    }
}
