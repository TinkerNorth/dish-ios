// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The remembered satellites, their pairing keys and their TOFU pins. Rows,
/// the device id and the last sightings live in `UserDefaults`, as dish-mac
/// keeps them; pairing keys live in the injected `KeyStore` (the Keychain
/// in production); pins live in `CertPins`, which the TLS delegate reads off
/// the main actor. Rows are keyed on `DiscoveredServer.id` (contract
/// §Identity): a satellite that never advertised a machine id is keyed by
/// its address until it does, and its ghost row then collapses into the
/// stable one. Pins are keyed by host, the one thing the TLS layer knows at
/// verify time, and follow a satellite that moves address.
package final class ConnectionStore {
    private let defaults: UserDefaults
    private let keyStore: any KeyStore
    /// The TOFU pins, shared with the TLS delegate.
    package let pins: CertPins

    private static let deviceIdKey = "deviceId"
    private static let wifiListKey = "wifi_list"
    private static let lastSeenPrefix = "wifi_last_seen:"

    package init(defaults: UserDefaults, keyStore: any KeyStore, pins: CertPins) {
        self.defaults = defaults
        self.keyStore = keyStore
        self.pins = pins
    }

    /// The satellite bindings kept across restarts, over the same defaults.
    @MainActor
    var bindingMemory: BindingMemoryStore {
        BindingMemoryStore(defaults: defaults)
    }

    // MARK: - Device id

    /// Stable per-install id, made once. Not a secret: it rides every REST
    /// call in `X-Device-Id`.
    func getOrCreateDeviceId() -> String {
        if let existing = defaults.string(forKey: Self.deviceIdKey) { return existing }
        let fresh = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        defaults.set(fresh, forKey: Self.deviceIdKey)
        return fresh
    }

    // MARK: - Remembered servers

    func remembered() -> [RememberedWifi] {
        guard let data = defaults.data(forKey: Self.wifiListKey),
              let list = try? JSONDecoder().decode([RememberedWifi].self, from: data) else { return [] }
        return list
    }

    /// Insert or refresh a satellite under its stable id. A result without a
    /// machine id only refreshes a stable row at its address; one with a
    /// machine id collapses the legacy ghosts at its address, carrying their
    /// key forward; a known satellite at a new address takes its pin along.
    func remember(_ server: DiscoveredServer) {
        if isBlank(server.machineId), refreshKnownBox(server) { return }
        let id = server.id
        if !isBlank(server.machineId) {
            collapseLegacyGhosts(server, stableId: id)
        }
        var list = remembered()
        let oldIp = list.first { $0.id == id }?.ip
        migratePinOnAddressChange(oldIp: oldIp, newIp: server.ip)
        list.removeAll { $0.id == id }
        list.append(RememberedWifi(
            id: id,
            name: server.name,
            ip: server.ip,
            udpPort: server.udpPort,
            pairPort: server.pairPort,
            httpPort: server.httpPort,
            machineId: server.machineId
        ))
        persist(list)
    }

    /// Re-point remembered rows at a scan's addresses, so a reconnect after
    /// a DHCP move finds the satellite. Never adds a satellite.
    func refreshFromDiscovery(_ discovered: [DiscoveredServer]) {
        let rows = remembered()
        let knownIds = Set(rows.map(\.id))
        for server in discovered where !isBlank(server.machineId) {
            let upgradesLegacyRow = rows.contains { row in
                isBlank(row.machineId) && row.ip == server.ip && row.udpPort == server.udpPort
            }
            if knownIds.contains(server.id) || upgradesLegacyRow { remember(server) }
        }
    }

    /// The row, its key, its pin and its last sighting all go.
    func forget(_ id: String) {
        var list = remembered()
        if let row = list.first(where: { $0.id == id }) {
            forgetCertPin(host: row.ip)
        }
        list.removeAll { $0.id == id }
        persist(list)
        keyStore.removePairingKey(for: id)
        defaults.removeObject(forKey: Self.lastSeenPrefix + id)
    }

    private func persist(_ list: [RememberedWifi]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: Self.wifiListKey)
    }

    /// A stable row at this address takes a machine-id-less result's name
    /// and ports in place, so no ghost is minted beside it.
    private func refreshKnownBox(_ server: DiscoveredServer) -> Bool {
        var list = remembered()
        guard let index = list.firstIndex(where: { row in
            !isBlank(row.machineId) && row.ip == server.ip && row.udpPort == server.udpPort
        }) else { return false }
        var refreshed = list[index]
        refreshed.name = server.name
        refreshed.pairPort = server.pairPort
        refreshed.httpPort = server.httpPort
        if refreshed != list[index] {
            list[index] = refreshed
            persist(list)
        }
        return true
    }

    /// Every legacy row at the address hands its key to the stable id (the
    /// stable row's own key wins) and goes.
    private func collapseLegacyGhosts(_ server: DiscoveredServer, stableId: String) {
        let list = remembered()
        let ghosts = list.filter { row in
            isBlank(row.machineId) && row.ip == server.ip && row.udpPort == server.udpPort
        }
        guard !ghosts.isEmpty else { return }
        for ghost in ghosts {
            if sharedKey(for: stableId) == nil, let ghostKey = sharedKey(for: ghost.id) {
                setSharedKey(ghostKey, for: stableId)
            }
            keyStore.removePairingKey(for: ghost.id)
        }
        let ghostIds = Set(ghosts.map(\.id))
        persist(list.filter { !ghostIds.contains($0.id) })
    }

    /// The pin follows the box; a pin already trusted at the new address
    /// stays, and the old address's pin always goes.
    private func migratePinOnAddressChange(oldIp: String?, newIp: String) {
        guard let oldIp, oldIp != newIp else { return }
        if certPin(host: newIp) == nil, let oldPin = certPin(host: oldIp) {
            setCertPin(host: newIp, fingerprintHex: oldPin)
        }
        forgetCertPin(host: oldIp)
    }

    private func isBlank(_ string: String) -> Bool {
        string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Last sighting

    /// When a session with the satellite was last up, for an offline row.
    func lastSeen(_ id: String) -> Date? {
        let seconds = defaults.double(forKey: Self.lastSeenPrefix + id)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    func markSeen(_ id: String, at moment: Date) {
        defaults.set(moment.timeIntervalSince1970, forKey: Self.lastSeenPrefix + id)
    }

    // MARK: - Pairing keys (hex, in the key store)

    func sharedKey(for id: String) -> String? {
        keyStore.pairingKeyHex(for: id)
    }

    func setSharedKey(_ keyHex: String, for id: String) {
        keyStore.setPairingKeyHex(keyHex, for: id)
    }

    /// Only the key goes (a terminal 401, a close-notify `unpaired`): the row
    /// stays so it can read "Needs pairing".
    func forgetKey(for id: String) {
        keyStore.removePairingKey(for: id)
    }

    // MARK: - TOFU pins (SHA-256 fingerprint hex, by host)

    func certPin(host: String) -> String? {
        pins.pin(host: host)
    }

    func setCertPin(host: String, fingerprintHex: String) {
        pins.setPin(host: host, fingerprintHex: fingerprintHex)
    }

    func forgetCertPin(host: String) {
        pins.forget(host: host)
    }
}
