// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Darwin
import DishCore
import Foundation

/// Which way a satellite reached this iPhone: the Bonjour browse, or an
/// address the user typed. dish-mac's legacy UDP beacon needs the multicast
/// entitlement here, so it is not a source (Tests/PARITY.md).
package enum DiscoverySource: String, Codable, Hashable {
    case mdns
    /// Typed in by the user (`DiscoveredServer.manual`): the way in when the
    /// Local Network permission is off or the LAN drops multicast.
    case manual
}

/// A satellite as discovery or the user found it. `id` is the stable key the
/// pool, the store and the bindings use (contract §Identity).
package struct DiscoveredServer: Codable, Hashable, Identifiable {
    package var name = ""
    package var ip = ""
    package var udpPort = defaultSatelliteUdpPort
    /// The HTTPS client API port (TLS, self-signed); pairing and the session
    /// routes share it, and mDNS advertises it under both `pair` and `http`.
    package var pairPort = defaultSatelliteClientPort
    package var httpPort = defaultSatelliteClientPort
    /// The satellite's stable per-install identity from the TXT `mid`; empty
    /// for one that predates it.
    package var machineId = ""
    /// Not a wire field; kept out of `CodingKeys`.
    package var source: DiscoverySource = .mdns

    /// `mid:<machineId>`, which survives a DHCP move; `wifi:<ip>:<udpPort>`
    /// for a satellite that never advertised one.
    package var id: String {
        machineId.isEmpty ? "wifi:\(ip):\(udpPort)" : "mid:\(machineId)"
    }

    package init(
        name: String = "",
        ip: String = "",
        udpPort: Int = defaultSatelliteUdpPort,
        pairPort: Int = defaultSatelliteClientPort,
        httpPort: Int = defaultSatelliteClientPort,
        machineId: String = "",
        source: DiscoverySource = .mdns
    ) {
        self.name = name
        self.ip = ip
        self.udpPort = udpPort
        self.pairPort = pairPort
        self.httpPort = httpPort
        self.machineId = machineId
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case name, ip, udpPort, pairPort, httpPort, machineId
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.ip = try container.decodeIfPresent(String.self, forKey: .ip) ?? ""
        self.udpPort = try container.decodeIfPresent(Int.self, forKey: .udpPort) ?? defaultSatelliteUdpPort
        self.pairPort = try container.decodeIfPresent(Int.self, forKey: .pairPort) ?? defaultSatelliteClientPort
        self.httpPort = try container.decodeIfPresent(Int.self, forKey: .httpPort) ?? defaultSatelliteClientPort
        self.machineId = try container.decodeIfPresent(String.self, forKey: .machineId) ?? ""
    }

    /// An address the user typed: an IPv4 literal, optionally `:udpPort`.
    /// Nil for anything else; a hostname is not resolved here.
    package static func manual(from input: String) -> DiscoveredServer? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard let host = parts.first.map(String.init), isIPv4Literal(host) else { return nil }
        switch parts.count {
        case 1:
            return DiscoveredServer(ip: host, source: .manual)
        case 2:
            guard let port = Int(parts[1]), validPorts.contains(port) else { return nil }
            return DiscoveredServer(ip: host, udpPort: port, source: .manual)
        default:
            return nil
        }
    }
}

private let validPorts = 1 ... 65535

/// The satellite's data-plane port when discovery names none.
package let defaultSatelliteUdpPort = 9876

/// The satellite's HTTPS client API port when discovery names none.
package let defaultSatelliteClientPort = 9443

/// Whether `host` reads as a dotted-quad IPv4 address, as `inet_pton` reads one.
func isIPv4Literal(_ host: String) -> Bool {
    var address = in_addr()
    return !host.isEmpty && host.withCString { inet_pton(AF_INET, $0, &address) } == 1
}

/// A satellite this iPhone paired with, as the store keeps it.
package struct RememberedWifi: Codable, Hashable, Identifiable {
    package let id: String
    var name: String
    var ip: String
    var udpPort: Int
    var pairPort: Int
    var httpPort: Int
    /// The satellite's machine id, so a row that changes address keeps its identity.
    var machineId: String

    init(id: String, name: String, ip: String, udpPort: Int, pairPort: Int, httpPort: Int, machineId: String = "") {
        self.id = id
        self.name = name
        self.ip = ip
        self.udpPort = udpPort
        self.pairPort = pairPort
        self.httpPort = httpPort
        self.machineId = machineId
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.ip = try container.decode(String.self, forKey: .ip)
        self.udpPort = try container.decode(Int.self, forKey: .udpPort)
        self.pairPort = try container.decode(Int.self, forKey: .pairPort)
        self.httpPort = try container.decode(Int.self, forKey: .httpPort)
        self.machineId = try container.decodeIfPresent(String.self, forKey: .machineId) ?? ""
    }

    package func toDiscovered() -> DiscoveredServer {
        DiscoveredServer(name: name, ip: ip, udpPort: udpPort, pairPort: pairPort, httpPort: httpPort, machineId: machineId)
    }
}

/// Where one connection stands, as the rows read it.
package enum LinkState: Equatable {
    /// Paired, and the key was revoked or never stored: the next tap pairs.
    case stale
    /// Paired, not heard on the network now.
    case saved
    /// Paired and heard on the network, no session.
    case ready
    case connecting
    case connected
    /// Live, but the heartbeat acks falter, or the session died and a silent
    /// retry is pending.
    case unstable
}

/// One row of the connections the hub aggregates: a remembered or pooled
/// satellite with its state, its latency and the pads bound to it.
package struct ConnectionSummary: Identifiable, Hashable {
    package let id: String
    package let name: String
    package let address: String
    package let udpPort: Int?
    package let live: LinkState
    /// Median heartbeat round trip halved, nil until measured.
    package let latencyMs: Double?
    package let compat: ProtocolCompat
    package let kind: ConnectionKind
    /// The bound pads in the order of the indices they hold.
    package let boundSlotIds: [String]

    package init(
        id: String,
        name: String,
        address: String = "",
        udpPort: Int? = nil,
        live: LinkState,
        latencyMs: Double? = nil,
        compat: ProtocolCompat = .unknown,
        kind: ConnectionKind = .satellite,
        boundSlotIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.udpPort = udpPort
        self.live = live
        self.latencyMs = latencyMs
        self.compat = compat
        self.kind = kind
        self.boundSlotIds = boundSlotIds
    }

    package var hasRoomForAnotherSlot: Bool {
        boundSlotIds.count < SatelliteSlots.maxPerSatellite
    }

    /// What the row is known by: its name, or its address when it has none.
    package var recordName: String {
        name.isEmpty ? address : name
    }
}
