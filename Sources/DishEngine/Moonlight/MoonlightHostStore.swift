// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// What the dish remembers about Moonlight hosts, under the fleet's keys: the
// hosts it has paired with or shown durable interest in, the pad bindings
// that put a controller back on its host, and the one client id every
// request carries. The host id is the address, never the uniqueid: a scan
// meets a host before it has been asked who it is and a typed address meets
// it after, so an id built from the answer named one host twice.

import DishCore
import Foundation

/// A Moonlight host (Sunshine, Apollo, Wolf) as discovery or the user named it.
package struct MoonlightHost: Equatable {
    package var name: String
    package var address: String
    package var httpPort: UInt16 = MoonlightProtocol.httpPort
    package var httpsPort: UInt16 = MoonlightProtocol.httpsPort
    /// What the host answered /serverinfo with; empty until asked.
    package var uniqueId = ""
    package var manual = false

    package init(
        name: String,
        address: String,
        httpPort: UInt16 = MoonlightProtocol.httpPort,
        httpsPort: UInt16 = MoonlightProtocol.httpsPort,
        uniqueId: String = "",
        manual: Bool = false
    ) {
        self.name = name
        self.address = address
        self.httpPort = httpPort
        self.httpsPort = httpsPort
        self.uniqueId = uniqueId
        self.manual = manual
    }

    package var id: String {
        MoonlightHostStore.hostId(address: address)
    }

    var endpoint: MoonlightEndpoint {
        MoonlightEndpoint(address: address, httpPort: httpPort, httpsPort: httpsPort)
    }
}

/// One remembered host. `paired` is whether the host ever accepted this
/// device, as opposed to a host the user only added by address or bound to;
/// both belong in the list, only the first is trust.
package struct RememberedMoonlightHost: Equatable, Codable {
    package var id: String
    package var name: String
    package var address: String
    package var httpPort: UInt16 = MoonlightProtocol.httpPort
    package var httpsPort: UInt16 = MoonlightProtocol.httpsPort
    package var uniqueId = ""
    /// The app the session creator settled on, per host: every pad on the host shares the one session.
    package var lastAppId = ""
    package var lastAppName = ""
    /// The emulated-type pick, a CONTROLLER_ARRIVAL type or the Auto sentinel.
    package var emulatedType = Int(MoonlightControllerType.auto)
    package var paired = true

    package var host: MoonlightHost {
        MoonlightHost(name: name, address: address, httpPort: httpPort, httpsPort: httpsPort, uniqueId: uniqueId)
    }

    package init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        address = try values.decode(String.self, forKey: .address)
        httpPort = try values.decodeIfPresent(UInt16.self, forKey: .httpPort) ?? MoonlightProtocol.httpPort
        httpsPort = try values.decodeIfPresent(UInt16.self, forKey: .httpsPort) ?? MoonlightProtocol.httpsPort
        uniqueId = try values.decodeIfPresent(String.self, forKey: .uniqueId) ?? ""
        lastAppId = try values.decodeIfPresent(String.self, forKey: .lastAppId) ?? ""
        lastAppName = try values.decodeIfPresent(String.self, forKey: .lastAppName) ?? ""
        emulatedType = try values.decodeIfPresent(Int.self, forKey: .emulatedType) ?? Int(MoonlightControllerType.auto)
        paired = try values.decodeIfPresent(Bool.self, forKey: .paired) ?? true
    }

    package init(host: MoonlightHost, paired: Bool) {
        id = host.id
        name = host.name
        address = host.address
        httpPort = host.httpPort
        httpsPort = host.httpsPort
        uniqueId = host.uniqueId
        self.paired = paired
    }
}

/// A controller slot kept on its host across restarts.
struct RememberedMoonlightBinding: Equatable, Codable {
    var slotId: String
    var hostId: String
    var controllerType: Int
}

/// The fleet's keys, in the same defaults the satellite rows live in. On
/// the main actor, where every reader of `UserDefaults` in this engine is.
@MainActor
final class MoonlightHostStore {
    static let hostsKey = "moonlight_host_list"
    static let bindingsKey = "moonlight_binding_list"
    static let uniqueIdKey = "moonlight_uniqueid"
    nonisolated static let idPrefix = "moonlight:"
    static let uniqueIdLength = 16

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    nonisolated static func hostId(address: String) -> String {
        idPrefix + address
    }

    // MARK: - Hosts

    func hosts() -> [RememberedMoonlightHost] {
        readHosts()
    }

    func host(id: String) -> RememberedMoonlightHost? {
        hosts().first { $0.id == id }
    }

    func put(_ host: RememberedMoonlightHost) {
        writeHosts(readHosts().filter { $0.id != host.id } + [host])
    }

    func removeHost(id: String) {
        writeHosts(readHosts().filter { $0.id != id })
    }

    // MARK: - Bindings

    func bindings() -> [RememberedMoonlightBinding] {
        readBindings()
    }

    func bindings(forHost hostId: String) -> [RememberedMoonlightBinding] {
        bindings().filter { $0.hostId == hostId }
    }

    func putBinding(_ binding: RememberedMoonlightBinding) {
        writeBindings(readBindings().filter { $0.slotId != binding.slotId } + [binding])
    }

    func removeBinding(slotId: String) {
        writeBindings(readBindings().filter { $0.slotId != slotId })
    }

    // MARK: - The client id

    /// Sixteen hex characters of a random UUID, minted once and kept: the
    /// `uniqueid` a host files this device under.
    func uniqueId() -> String {
        if let stored = defaults.string(forKey: Self.uniqueIdKey), stored.count == Self.uniqueIdLength { return stored }
        let fresh = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(Self.uniqueIdLength))
        defaults.set(fresh, forKey: Self.uniqueIdKey)
        return fresh
    }

    private func readHosts() -> [RememberedMoonlightHost] {
        guard let raw = defaults.data(forKey: Self.hostsKey) else { return [] }
        return (try? JSONDecoder().decode([RememberedMoonlightHost].self, from: raw)) ?? []
    }

    private func writeHosts(_ hosts: [RememberedMoonlightHost]) {
        defaults.set(try? JSONEncoder().encode(hosts), forKey: Self.hostsKey)
    }

    private func readBindings() -> [RememberedMoonlightBinding] {
        guard let raw = defaults.data(forKey: Self.bindingsKey) else { return [] }
        return (try? JSONDecoder().decode([RememberedMoonlightBinding].self, from: raw)) ?? []
    }

    private func writeBindings(_ bindings: [RememberedMoonlightBinding]) {
        defaults.set(try? JSONEncoder().encode(bindings), forKey: Self.bindingsKey)
    }
}
