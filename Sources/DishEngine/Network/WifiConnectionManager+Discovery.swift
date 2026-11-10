// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

extension WifiConnectionManager {

    /// The LAN as one call: the Bonjour browse for `_satellite._udp`, which
    /// also says whether iOS held it on the Local Network policy. dish-mac's
    /// legacy beacon needs the multicast entitlement here (Tests/PARITY.md).
    /// The app runs the live path; tests script a LAN.
    package struct DiscoveryPaths {
        let scan: @Sendable () async -> ScanResult

        package static let live = DiscoveryPaths {
            let mdns = await MdnsBrowser.discover()
            return ScanResult(mdns: mdns.found, localNetworkDenied: mdns.localNetworkDenied)
        }
    }

    /// Who asked for a scan. Only the user's own scan says it heard nothing;
    /// the one a page runs as it opens lets its empty state speak instead.
    enum ScanTrigger {
        case user
        case pageOpened
    }

    /// One scan's results, and whether iOS refused this app the local
    /// network while it ran.
    package struct ScanResult {
        let mdns: [DiscoveredServer]
        let localNetworkDenied: Bool

        package init(mdns: [DiscoveredServer], localNetworkDenied: Bool = false) {
            self.mdns = mdns
            self.localNetworkDenied = localNetworkDenied
        }

        /// One row per stable id, by name.
        var merged: [DiscoveredServer] {
            mergeDiscovered(mdns)
        }

        /// What the scan tells the user: a refusal first, since nothing heard
        /// can be reached; else that nothing answered; nil when something was
        /// heard on an open network.
        var failure: ConnectionFailure? {
            if localNetworkDenied { return .localNetworkDenied }
            return merged.isEmpty ? .noServersFound : nil
        }
    }

    /// Run the discovery path and adopt what it heard. One scan at a time;
    /// `finished` runs on the main actor once the scan is adopted.
    func startDiscovery(trigger: ScanTrigger = .user, finished: (@MainActor () -> Void)? = nil) {
        guard markScanStarted() else { return }
        let paths = discovery
        Task { [weak self] in
            let scan = await paths.scan()
            self?.adoptScan(scan, trigger: trigger)
            finished?()
        }
    }

    /// Publish a finished scan, re-home remembered satellites whose address
    /// moved, and point idle pool entries at their current endpoint.
    private func adoptScan(_ scan: ScanResult, trigger: ScanTrigger) {
        let merged = scan.merged
        Self.discoveryLog.info("discovery scan: mdns=\(scan.mdns.count) denied=\(scan.localNetworkDenied)")
        publishScan(merged, localNetworkDenied: scan.localNetworkDenied)
        store.refreshFromDiscovery(merged)
        refreshRemembered()
        rehomeIdleConnections(to: merged)
        if trigger == .user, let failure = scan.failure {
            emit(.failure(failure))
        }
    }

    private func rehomeIdleConnections(to merged: [DiscoveredServer]) {
        for server in merged {
            guard let conn = connections[server.id], conn.state == .idle else { continue }
            conn.updateServer(server)
        }
    }
}

/// One row per stable id, tagged as heard over Bonjour, by name.
func mergeDiscovered(_ mdns: [DiscoveredServer]) -> [DiscoveredServer] {
    var byId: [String: DiscoveredServer] = [:]
    for var server in mdns {
        server.source = .mdns
        byId[server.id] = server
    }
    return byId.values.sorted { $0.name < $1.name }
}
