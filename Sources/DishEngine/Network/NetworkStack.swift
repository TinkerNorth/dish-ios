// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The satellite side of the composition root: the pool's manager and the
/// hub over it, one value, so the root takes the network as one part and a
/// test builds it over a fake LAN and an in-memory key store.
@MainActor
package struct NetworkStack {
    package let wifi: WifiConnectionManager
    package let hub: ConnectionHub

    package init(wifi: WifiConnectionManager) {
        self.wifi = wifi
        hub = ConnectionHub(wifi: wifi)
    }

    /// The store over `defaults` with its keys in `keyStore` and its pins in
    /// `pins`, the live LAN,
    /// and the name the satellite shows for this iPhone.
    package init(defaults: UserDefaults, keyStore: any KeyStore, pins: CertPins, deviceName: @escaping @MainActor () -> String) {
        let store = ConnectionStore(defaults: defaults, keyStore: keyStore, pins: pins)
        self.init(wifi: WifiConnectionManager(store: store, deviceName: deviceName))
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
