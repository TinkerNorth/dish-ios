// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
@testable import DishEngine

/// A satellite pool over a fresh store with an in-memory key store and a
/// scripted LAN, and a Moonlight manager over a scripted gateway that
/// answers nothing, for the model's tests.
@MainActor
enum TestNetwork {
    static func stack(
        defaults: UserDefaults,
        remembered: [DiscoveredServer] = [],
        lan: [DiscoveredServer] = [],
        keyStore: InMemoryKeyStore = InMemoryKeyStore(),
        moonlight: MoonlightConnectionManager? = nil
    ) -> NetworkStack {
        let store = ConnectionStore(defaults: defaults, keyStore: keyStore, pins: CertPins(file: nil))
        remembered.forEach(store.remember)
        let wifi = WifiConnectionManager(
            store: store,
            deviceName: testDeviceName,
            approvalPolling: .fast,
            discovery: .scripted(lan)
        )
        return NetworkStack(wifi: wifi, moonlight: moonlight ?? scriptedMoonlight(defaults: defaults))
    }

    /// A Moonlight manager over scripted seams that answer nothing and find
    /// no host, so a test that is not about hosts has none in its way.
    static func scriptedMoonlight(defaults: UserDefaults) -> MoonlightConnectionManager {
        MoonlightConnectionManager(
            store: MoonlightHostStore(defaults: defaults),
            gateway: ScriptedMoonlightGateway(),
            identity: nil,
            edges: FakeMoonlightEdges(),
            discover: { [] }
        )
    }

    /// A satellite at a documentation address that answers nothing.
    static func satellite(_ machineId: String, name: String = "Den PC") -> DiscoveredServer {
        DiscoveredServer(name: name, ip: "192.0.2.10", machineId: machineId)
    }
}

@MainActor
func testDeviceName() -> String {
    "Test iPhone"
}

extension WifiConnectionManager.ApprovalPolling {
    /// A poll every 25 ms that gives up after two seconds.
    static let fast = WifiConnectionManager.ApprovalPolling(intervalMs: 25, timeoutMs: 2000)
}

extension WifiConnectionManager.DiscoveryPaths {
    /// A LAN that always answers with `servers` on an open network.
    static func scripted(_ servers: [DiscoveredServer], denied: Bool = false) -> WifiConnectionManager.DiscoveryPaths {
        WifiConnectionManager.DiscoveryPaths { WifiConnectionManager.ScanResult(mdns: servers, localNetworkDenied: denied) }
    }
}
