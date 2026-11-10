// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// The hub with Moonlight hosts beside the satellites: a row per host the
/// records or the pool know, up to four slots bound to one host without
/// eviction, a slot's prior owner of either kind letting go, and the pick
/// kept with the remembered binding.
@MainActor
final class ConnectionHubMoonlightTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suite: String!
    private var store: ConnectionStore!
    private var wifi: WifiConnectionManager!
    private var moonlight: MoonlightConnectionManager!
    private var hub: ConnectionHub!
    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")

    override func setUp() async throws {
        try await super.setUp()
        suite = "dish.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        store = ConnectionStore(defaults: defaults, keyStore: InMemoryKeyStore(), pins: CertPins(file: nil))
        wifi = WifiConnectionManager(store: store, deviceName: testDeviceName)
        moonlight = MoonlightConnectionManager(
            store: MoonlightHostStore(defaults: defaults),
            gateway: ScriptedMoonlightGateway(),
            identity: nil,
            edges: FakeMoonlightEdges(),
            discover: { [] }
        )
        hub = ConnectionHub(wifi: wifi, moonlight: moonlight)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    private func remember(paired: Bool) {
        var record = RememberedMoonlightHost(host: host, paired: paired)
        record.uniqueId = "abc"
        moonlight.store.put(record)
        moonlight.publishRemembered()
    }

    private func satellite(_ suffix: String) -> DiscoveredServer {
        DiscoveredServer(name: "Sat-\(suffix)", ip: "192.0.2.\(suffix)", udpPort: 9876, machineId: "sat-\(suffix)")
    }

    private func bind(_ slotId: String, to connectionId: String) -> Bool {
        hub.bind(slotId: slotId, connectionId: connectionId, capabilities: .none, emulateAs: .xboxWireless)
    }

    func testARememberedHostIsARowWhoseChipReadsItsTrustAndPresence() {
        XCTAssertEqual(hub.connections, [])
        remember(paired: false)
        XCTAssertEqual(hub.connections.map(\.id), [host.id])
        XCTAssertEqual(hub.connections.first?.kind, .moonlight)
        XCTAssertEqual(hub.connections.first?.live, .stale, "no pairing: Needs pairing")
        XCTAssertEqual(hub.connections.first?.name, "PC")
        XCTAssertTrue(ConnectionHub.isMoonlight(host.id))
        XCTAssertFalse(ConnectionHub.isMoonlight("mid:sat"))
        remember(paired: true)
        XCTAssertEqual(hub.connections.first?.live, .saved, "paired and out of sight")
        moonlight.mergeDiscovered(host)
        XCTAssertEqual(hub.connections.first?.live, .ready)
        let sat = satellite("10")
        store.remember(sat)
        wifi.refreshRemembered()
        wifi.register(WifiConnection(id: sat.id, server: sat, tickIntervalNs: .max))
        XCTAssertEqual(hub.connections.map(\.name), ["PC", "Sat-10"], "both kinds, name-sorted")
    }

    func testFourSlotsBindToOneHostWithoutEvictionAndTheRowNamesThemAll() {
        remember(paired: true)
        for slotId in ["a", "b", "c", "d"] {
            XCTAssertTrue(bind(slotId, to: host.id))
        }
        XCTAssertEqual(hub.bindings, ["a": host.id, "b": host.id, "c": host.id, "d": host.id])
        let row = hub.summary(host.id)
        XCTAssertEqual(row?.boundSlotIds, ["a", "b", "c", "d"])
        XCTAssertFalse(row?.hasRoomForAnotherSlot ?? true)
        XCTAssertEqual(moonlight.rememberedBindings.map(\.slotId).sorted(), ["a", "b", "c", "d"], "kept across restarts")
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.auto), "the host's own pick, Auto")
        hub.unbind(slotId: "b")
        XCTAssertEqual(hub.summary(host.id)?.boundSlotIds, ["a", "c", "d"])
        XCTAssertEqual(moonlight.rememberedBindings.map(\.slotId).sorted(), ["a", "c", "d"], "an unbound pad's binding is forgotten")
        hub.forgetBindings(of: host.id)
        XCTAssertEqual(hub.bindings, [:])
        XCTAssertEqual(moonlight.rememberedBindings, [])
    }

    func testBindingToAHostTheRecordsDoNotHoldRemembersInterest() {
        moonlight.mergeDiscovered(host)
        XCTAssertTrue(bind("a", to: host.id))
        XCTAssertEqual(moonlight.store.host(id: host.id)?.paired, false, "binding is durable interest, not trust")
        XCTAssertEqual(hub.summary(host.id)?.boundSlotIds, ["a"])
    }

    func testASlotsPriorOwnerOfEitherKindLetsGo() {
        remember(paired: true)
        let sat = satellite("20")
        let conn = WifiConnection(id: sat.id, server: sat, tickIntervalNs: .max)
        wifi.register(conn)
        XCTAssertTrue(bind("a", to: sat.id))
        XCTAssertEqual(conn.boundSlotIds, ["a"])
        XCTAssertTrue(bind("a", to: host.id))
        XCTAssertEqual(conn.boundSlotIds, [], "the satellite detached when its slot moved to the host")
        XCTAssertEqual(hub.bindings, ["a": host.id])
        XCTAssertTrue(bind("a", to: sat.id))
        XCTAssertEqual(conn.boundSlotIds, ["a"])
        XCTAssertEqual(moonlight.rememberedBindings, [], "the host's remembered binding went when the slot moved back")
        XCTAssertEqual(hub.summary(host.id)?.boundSlotIds, [])
    }

    func testThePickForAMoonlightBindingIsKeptWithIt() {
        remember(paired: true)
        moonlight.setEmulatedType(hostId: host.id, type: MoonlightControllerType.playStation)
        XCTAssertTrue(bind("a", to: host.id))
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.playStation), "the host's pick")
        hub.setEmulatedType(slotId: "a", .switchPro)
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.nintendo))
        hub.setEmulatedType(slotId: "a", .dualShock4)
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.playStation))
        hub.setEmulatedType(slotId: "zz", .xboxWireless)
        XCTAssertEqual(moonlight.rememberedBindings.count, 1, "an unbound slot changes nothing")
    }

    func testThePickOfAPadOnAHostIsTheProtocolsAndAutoReturnsToTheHostsOwn() {
        remember(paired: true)
        moonlight.setEmulatedType(hostId: host.id, type: MoonlightControllerType.playStation)
        XCTAssertTrue(bind("a", to: host.id))
        hub.setMoonlightEmulatedType(slotId: "a", Int(MoonlightControllerType.nintendo))
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.nintendo))
        XCTAssertEqual(hub.hostEmulation(slotId: "a"), HostEmulationFact(type: Int(MoonlightControllerType.nintendo), isOverride: true))
        hub.setMoonlightEmulatedType(slotId: "a", nil)
        XCTAssertEqual(moonlight.rememberedBindings.first?.controllerType, Int(MoonlightControllerType.playStation), "the host's own")
        XCTAssertEqual(hub.hostEmulation(slotId: "a"), HostEmulationFact(type: Int(MoonlightControllerType.playStation), isOverride: false))
        hub.setMoonlightEmulatedType(slotId: "zz", Int(MoonlightControllerType.xbox))
        XCTAssertEqual(moonlight.rememberedBindings.count, 1, "an unbound slot changes nothing")
        XCTAssertNil(hub.hostEmulation(slotId: "zz"))
    }

    func testASatellitesPadHasNoHostEmulationAndTheProtocolsPickLeavesItAlone() {
        let sat = satellite("30")
        wifi.register(WifiConnection(id: sat.id, server: sat, tickIntervalNs: .max))
        XCTAssertTrue(bind("a", to: sat.id))
        hub.setMoonlightEmulatedType(slotId: "a", Int(MoonlightControllerType.nintendo))
        XCTAssertNil(hub.hostEmulation(slotId: "a"))
        XCTAssertEqual(moonlight.rememberedBindings, [])
    }

    func testAHostInThePoolIsARowThatFollowsItsPhase() async {
        remember(paired: true)
        XCTAssertTrue(bind("a", to: host.id))
        moonlight.applyDesired([host.id: [MoonlightPadRequest(
            slotId: "a",
            announced: MoonlightAnnouncedPad(type: 1, capabilities: 1, supportedButtons: 0xF7FF)
        )]])
        await moonlight.awaitQuiet()
        XCTAssertEqual(moonlight.get(host.id)?.phase, .failed(.unreachable))
        XCTAssertEqual(hub.summary(host.id)?.live, .saved, "unreachable this time, remembered as paired")
        XCTAssertEqual(hub.summary(host.id)?.boundSlotIds, ["a"])
        moonlight.forget(hostId: host.id)
        await moonlight.awaitQuiet()
        XCTAssertEqual(hub.connections, [], "a forgotten host leaves no row")
    }
}
