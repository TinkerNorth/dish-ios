// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The PC side of the composition root: the satellite pool's manager, the
/// Moonlight hosts' manager and the hub over both, one value, so the root
/// takes the network as one part and a test builds it over a fake LAN, an
/// in-memory key store and a scripted host gateway.
@MainActor
package struct NetworkStack {
    package let wifi: WifiConnectionManager
    package let moonlight: MoonlightConnectionManager
    package let hub: ConnectionHub
    /// The production gateway, handed the identity once the keychain has
    /// minted it; nil over a scripted one.
    let moonlightGateway: MoonlightGateway?

    package init(wifi: WifiConnectionManager, moonlight: MoonlightConnectionManager) {
        self.init(wifi: wifi, moonlight: moonlight, moonlightGateway: nil)
    }

    init(wifi: WifiConnectionManager, moonlight: MoonlightConnectionManager, moonlightGateway: MoonlightGateway?) {
        self.wifi = wifi
        self.moonlight = moonlight
        self.moonlightGateway = moonlightGateway
        hub = ConnectionHub(wifi: wifi, moonlight: moonlight)
    }

    /// The store over `defaults` with its keys in `keyStore` and its pins in
    /// `pins`, the live LAN for both kinds of PC, and the name the satellite
    /// shows for this iPhone. The Moonlight hosts share the pin file, under
    /// their own ids.
    package init(defaults: UserDefaults, keyStore: any KeyStore, pins: CertPins, deviceName: @escaping @MainActor () -> String) {
        let store = ConnectionStore(defaults: defaults, keyStore: keyStore, pins: pins)
        let gateway = MoonlightGateway(identity: nil, pins: pins)
        let moonlight = MoonlightConnectionManager(store: MoonlightHostStore(defaults: defaults), gateway: gateway, identity: nil)
        self.init(wifi: WifiConnectionManager(store: store, deviceName: deviceName), moonlight: moonlight, moonlightGateway: gateway)
    }
}

/// The name the satellite shows for this iPhone: the one the person gave
/// it, else the model's own name, which iOS reports to every app.
func wireDeviceName(_ stored: String) -> String {
    stored.isEmpty ? unnamedDeviceWireName : stored
}

/// What the device's name reads to an app without the user-assigned name
/// entitlement; the satellite's operator sees it, never Dish's UI.
let unnamedDeviceWireName = "iPhone"
