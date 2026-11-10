// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// How iOS says it refused this app the local network. iOS has no call that
// asks; it enforces the permission flow by flow, and a Bonjour browse is
// the flow that tells: under the policy the browser waits with the mDNS
// daemon's PolicyDenied error, while the prompt is up and after a refusal
// alike, and it moves to ready once the person allows. dish-mac's gateway
// probe reads the system's dynamic store, which iOS does not offer, so the
// browse is the one reading here.

import Foundation
import Network
import Synchronization

enum LocalNetworkProbe {
    /// `kDNSServiceErr_PolicyDenied` from `dns_sd.h`; the engine does not
    /// import `dnssd` for one constant, and `LocalNetworkProbeTests` pins it.
    static let policyDeniedCode: Int32 = -65570

    /// Whether a path says iOS refused this app the local network.
    static func isLocalNetworkDenial(_ path: NWPath?) -> Bool {
        path?.unsatisfiedReason == .localNetworkDenied
    }

    /// Whether a browser error is the mDNS daemon holding the browse on the
    /// Local Network policy.
    static func isLocalNetworkDenial(_ error: NWError) -> Bool {
        if case let .dns(code) = error { return code == policyDeniedCode }
        return false
    }
}

/// While the permission reads as refused, one long-lived browse that says
/// when it is granted: the browser leaves its policy wait for ready the
/// moment the person allows, in the prompt or in Settings.
final class LocalNetworkWatch: Sendable {
    private let browser = Mutex<NWBrowser?>(nil)

    /// Starts the watch; `granted` runs once, on a background queue, when
    /// the browser goes ready. A second start while one runs is dropped.
    func start(granted: @escaping @Sendable () -> Void) {
        let params = NWParameters()
        params.includePeerToPeer = false
        let started = browser.withLock { slot -> NWBrowser? in
            guard slot == nil else { return nil }
            let fresh = NWBrowser(for: .bonjourWithTXTRecord(type: MdnsBrowser.serviceType, domain: nil), using: params)
            slot = fresh
            return fresh
        }
        guard let started else { return }
        started.stateUpdateHandler = { [weak self] state in
            guard case .ready = state else { return }
            self?.stop()
            granted()
        }
        started.start(queue: .global(qos: .utility))
    }

    func stop() {
        let running = browser.withLock { slot -> NWBrowser? in
            let current = slot
            slot = nil
            return current
        }
        running?.cancel()
    }

    var isRunning: Bool {
        browser.withLock { $0 != nil }
    }
}
