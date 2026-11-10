// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Discovers Satellite servers advertised over mDNS / Bonjour as the
// `_satellite._udp` service, with the ports and the stable machine id read
// from the TXT record. The browse itself is `BonjourScan`.

import Foundation
import Network

enum MdnsBrowser {
    /// The DNS-SD service type. The trailing dot is required by `NWBrowser`;
    /// the Info.plist declares it under `NSBonjourServices`.
    static let serviceType = "_satellite._udp."
    static let defaultTimeoutMs = BonjourScan.defaultTimeoutMs
    /// `mid` is the satellite's stable machine id (contract §Identity), the
    /// key remembered satellites are stored under.
    static let txtKeys = ["udp", "pair", "http", "mid"]

    /// Browse for `timeoutMs`, resolving every advertised satellite to a
    /// `DiscoveredServer`, and say whether iOS held the browse on the Local
    /// Network policy meanwhile.
    static func discover(timeoutMs: Int = defaultTimeoutMs) async -> BonjourScan.Outcome<DiscoveredServer> {
        await BonjourScan.discover(serviceType: serviceType, txtKeys: txtKeys, timeoutMs: timeoutMs) { name, host, txt in
            let server = makeServer(name: name, host: host, txt: txt)
            return (server.id, server)
        }
    }

    static func makeServer(name: String, host: String, txt: [String: String]) -> DiscoveredServer {
        DiscoveredServer(
            name: name.isEmpty ? host : name,
            ip: host,
            udpPort: Int(txt["udp"] ?? "") ?? defaultSatelliteUdpPort,
            pairPort: Int(txt["pair"] ?? "") ?? defaultSatelliteClientPort,
            httpPort: Int(txt["http"] ?? "") ?? defaultSatelliteClientPort,
            machineId: txt["mid"] ?? "",
            source: .mdns
        )
    }
}
