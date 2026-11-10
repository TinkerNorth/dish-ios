// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// A model whose LAN is one in-process fake satellite: the scan hears it,
/// the pool reaches it on the loopback, and the pads iOS sees are a fake
/// source's. The key store is in memory and the pins are not persisted.
@MainActor
final class SatelliteModelFixture {
    let satellite: FakeSatellite
    let ports: FakeSatellite.Ports
    let source: FakeControllerSource
    let keyStore = InMemoryKeyStore()
    let network: NetworkStack
    let model: AppModel
    private(set) var events: [ConnectionEvent] = []

    /// The pad most tests bind: a DualSense with every feature.
    static let pad = ControllerSlot(
        id: "pad",
        name: "DualSense Wireless Controller",
        capabilities: ControllerCapabilities(hasMotion: true, hasTouchpad: true, hasRumble: true, hasLightbar: true),
        family: .dualSense
    )

    init(_ test: XCTestCase, pads: [ControllerSlot] = [SatelliteModelFixture.pad], localNetwork: LocalNetworkChoice = .bonjour) throws {
        satellite = try FakeSatellite()
        ports = try satellite.start()
        try satellite.requireHTTPSTransport()
        let defaults = try TestDefaults.fresh(test)
        let server = DiscoveredServer(
            name: "Den PC",
            ip: "127.0.0.1",
            udpPort: Int(ports.udp),
            pairPort: Int(ports.rest),
            httpPort: Int(ports.rest),
            machineId: satellite.machineId
        )
        network = TestNetwork.stack(defaults: defaults, lan: [server], keyStore: keyStore)
        source = FakeControllerSource(slots: pads)
        let access: any LocalNetworkAccess = switch localNetwork {
        case .bonjour: BonjourLocalNetworkAccess(wifi: network.wifi)
        case .recorded: RecordedLocalNetworkAccess()
        }
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: access,
            pads: ControllerStack(source: source, defaults: defaults),
            network: network,
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker()
        )
    }

    enum LocalNetworkChoice {
        case bonjour
        case recorded
    }

    var server: DiscoveredServer {
        DiscoveredServer(
            name: "Den PC",
            ip: "127.0.0.1",
            udpPort: Int(ports.udp),
            pairPort: Int(ports.rest),
            httpPort: Int(ports.rest),
            machineId: satellite.machineId
        )
    }

    var serverId: String {
        server.id
    }

    /// Matching trust on both ends, and the satellite remembered, as a past
    /// pairing leaves them.
    func prePair(keyHex: String = String(repeating: "2e", count: 32)) {
        satellite.pairingKeyHex = keyHex
        keyStore.setPairingKeyHex(keyHex, for: serverId)
        network.wifi.store.remember(server)
        network.wifi.refreshRemembered()
    }

    /// A scan, then the satellite's session up, from a past pairing.
    func connectPaired() async -> Bool {
        prePair()
        model.connect(serverId)
        return await waitUntil { self.network.wifi.get(self.serverId)?.state == .live }
    }

    func scan() async -> Bool {
        model.startScan()
        return await waitUntil { !self.network.wifi.isScanning && self.network.wifi.localNetworkDenied != nil }
    }

    /// Polls every 20 ms; the default is generous because a fresh CI runner
    /// spends seconds on its first session, and a pass costs no waiting.
    func waitUntil(timeout: TimeInterval = 20, _ predicate: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return predicate()
    }

    func tearDown() {
        for id in network.wifi.connections.keys {
            network.wifi.disconnect(id: id)
        }
        satellite.stop()
    }
}
