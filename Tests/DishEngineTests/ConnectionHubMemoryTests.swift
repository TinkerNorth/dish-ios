// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// The hub keeps every binding across restarts: written on bind, kept when
/// the pad leaves or its satellite refuses it, dropped when the user unbinds
/// or forgets the satellite, one record per pad of one kind; and it hands
/// each remembered binding back once per attachment of its pad, when its
/// destination is known here.
@MainActor
final class ConnectionHubMemoryTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: ConnectionStore!
    private var wifi: WifiConnectionManager!
    private var moonlight: MoonlightConnectionManager!
    private var hub: ConnectionHub!
    private let den = DiscoveredServer(name: "Den", ip: "192.0.2.10", udpPort: 9876, machineId: "den")
    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")

    override func setUp() async throws {
        try await super.setUp()
        defaults = try TestDefaults.fresh(self)
        store = ConnectionStore(defaults: defaults, keyStore: InMemoryKeyStore(), pins: CertPins(file: nil))
        wifi = WifiConnectionManager(store: store, deviceName: testDeviceName)
        moonlight = TestNetwork.scriptedMoonlight(defaults: defaults)
        hub = ConnectionHub(wifi: wifi, moonlight: moonlight)
        wifi.register(WifiConnection(id: den.id, server: den, tickIntervalNs: .max))
    }

    private var memory: [RememberedSatelliteBinding] {
        BindingMemoryStore(defaults: defaults).bindings()
    }

    private func rememberHost() {
        moonlight.store.put(RememberedMoonlightHost(host: host, paired: true))
        moonlight.publishRemembered()
    }

    @discardableResult
    private func bind(_ slotId: String, to connectionId: String, pick: EmulatedPad? = nil) -> Bool {
        hub.bind(slotId: slotId, connectionId: connectionId, capabilities: .none, emulateAs: pick ?? .xboxWireless, pick: pick)
    }

    private func due(present: Set<String>) -> [StandingBinding] {
        hub.takeDueStandingBindings(
            present: present,
            satellites: Set(wifi.connections.keys),
            hosts: Set(moonlight.rememberedHosts.map(\.id))
        )
    }

    // MARK: - What is written

    func testABindIsRemembered() {
        bind("pad", to: den.id)
        XCTAssertEqual(memory, [RememberedSatelliteBinding(slotId: "pad", satelliteId: den.id)])
    }

    func testAPadThatLeftOrWasRefusedKeepsItsMemory() {
        bind("pad", to: den.id)
        bind("other", to: den.id)
        hub.release(slotId: "pad")
        hub.release(slotId: "other")
        XCTAssertEqual(hub.bindings, [:])
        XCTAssertEqual(memory.map(\.slotId), ["pad", "other"])
    }

    func testAMoonlightPadThatLeftKeepsItsHostRecord() {
        rememberHost()
        bind("pad", to: host.id)
        hub.release(slotId: "pad")
        XCTAssertEqual(moonlight.rememberedBindings.map(\.slotId), ["pad"])
    }

    func testUnbindingForgetsTheMemory() {
        bind("pad", to: den.id)
        hub.unbind(slotId: "pad")
        XCTAssertEqual(memory, [])
    }

    func testForgettingASatelliteDropsTheBindingsOfPadsPresentAndAbsent() {
        bind("pad", to: den.id)
        bind("gone", to: den.id)
        hub.release(slotId: "gone")
        hub.forgetBindings(of: den.id)
        XCTAssertEqual(hub.bindings, [:])
        XCTAssertEqual(memory, [])
    }

    func testForgettingAHostDropsTheBindingsOfPadsAbsentToo() {
        rememberHost()
        bind("pad", to: host.id)
        bind("gone", to: host.id)
        hub.release(slotId: "gone")
        hub.forgetBindings(of: host.id)
        XCTAssertEqual(moonlight.rememberedBindings, [])
    }

    func testAPadThatMovedBetweenKindsIsRememberedOnlyWhereItIsNow() {
        rememberHost()
        bind("pad", to: den.id)
        bind("pad", to: host.id)
        XCTAssertEqual(memory, [], "the satellite record went")
        XCTAssertEqual(moonlight.rememberedBindings.map(\.slotId), ["pad"])
        bind("pad", to: den.id)
        XCTAssertEqual(moonlight.rememberedBindings, [], "the host record went")
        XCTAssertEqual(memory.map(\.slotId), ["pad"])
    }

    func testAPadRememberedOnAHostAndBoundToASatelliteAfterARestartIsRememberedOnlyThere() {
        rememberHost()
        moonlight.rememberBinding(slotId: "pad", hostId: host.id, controllerType: 1)
        bind("pad", to: den.id)
        XCTAssertEqual(moonlight.rememberedBindings, [], "no prior binding was live, the record still went")
    }

    // MARK: - What is handed back

    func testAStandingBindingIsDueOncePerAttachmentOfItsPad() {
        bind("pad", to: den.id)
        hub.release(slotId: "pad")
        XCTAssertEqual(due(present: []), [], "the pad is not here")
        XCTAssertEqual(due(present: ["pad"]), [StandingBinding(slotId: "pad", connectionId: den.id)])
        XCTAssertEqual(due(present: ["pad"]), [], "tried once while it stays attached")
        XCTAssertEqual(due(present: []), [])
        XCTAssertEqual(due(present: ["pad"]).map(\.slotId), ["pad"], "due again once it returns")
    }

    func testABoundPadIsNeverDue() {
        bind("pad", to: den.id)
        XCTAssertEqual(due(present: ["pad"]), [])
    }

    func testABindingWaitsUntilItsDestinationIsKnown() {
        BindingMemoryStore(defaults: defaults).remember(RememberedSatelliteBinding(slotId: "pad", satelliteId: "mid:loft"))
        XCTAssertEqual(due(present: ["pad"]), [], "no such satellite in the pool yet")
        let loft = DiscoveredServer(name: "Loft", ip: "192.0.2.11", udpPort: 9876, machineId: "loft")
        wifi.register(WifiConnection(id: loft.id, server: loft, tickIntervalNs: .max))
        XCTAssertEqual(due(present: ["pad"]).map(\.connectionId), [loft.id], "an unknown destination was not counted as tried")
    }

    func testAMoonlightBindingIsDueAndKeepsItsOwnPickWhenBoundAgain() {
        rememberHost()
        bind("pad", to: host.id)
        hub.setEmulatedType(slotId: "pad", .switchPro)
        hub.release(slotId: "pad")
        XCTAssertEqual(due(present: ["pad"]), [StandingBinding(slotId: "pad", connectionId: host.id)])
        bind("pad", to: host.id)
        XCTAssertEqual(
            moonlight.rememberedBindings.first?.controllerType,
            Int(MoonlightControllerType.nintendo),
            "the record outlived the release"
        )
    }

    func testAPickMadeBeforeTheBindReachesTheHostsRecord() {
        rememberHost()
        bind("pad", to: host.id, pick: .switchPro)
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.nintendo))
    }
}
