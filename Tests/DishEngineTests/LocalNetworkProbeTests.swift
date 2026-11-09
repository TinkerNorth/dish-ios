// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import dnssd
import Foundation
import Network
import Synchronization
import XCTest
@testable import DishEngine

/// How iOS says it refused this app the local network: the mDNS daemon's
/// PolicyDenied on the browser, and a path whose unsatisfied reason says so.
final class LocalNetworkProbeTests: XCTestCase {

    func testThePolicyCodeIsTheDaemonsOwn() {
        XCTAssertEqual(LocalNetworkProbe.policyDeniedCode, Int32(kDNSServiceErr_PolicyDenied))
    }

    func testTheDaemonsPolicyRefusalIsALocalNetworkDenialAndOtherErrorsAreNot() {
        XCTAssertTrue(LocalNetworkProbe.isLocalNetworkDenial(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))))
        XCTAssertFalse(LocalNetworkProbe.isLocalNetworkDenial(.dns(DNSServiceErrorType(kDNSServiceErr_NoSuchRecord))))
        XCTAssertFalse(LocalNetworkProbe.isLocalNetworkDenial(.posix(.ECONNREFUSED)))
    }

    func testANilPathIsNotADenial() {
        XCTAssertFalse(LocalNetworkProbe.isLocalNetworkDenial(nil as NWPath?))
    }

    func testANeverAskedScanIsUnknownAWaitingOneDeniedAndAnOpenOneAllowed() {
        XCTAssertEqual(localNetworkStatus(denied: nil), .unknown)
        XCTAssertEqual(localNetworkStatus(denied: true), .denied)
        XCTAssertEqual(localNetworkStatus(denied: false), .allowed)
    }

    /// The probe this mapping rests on: what a `_satellite._udp` browse
    /// reports on this runtime. The iOS 26.5 simulator does not enforce the
    /// Local Network permission (there is no switch for it, and `simctl
    /// privacy` has no such service), so the browser goes straight to ready
    /// and never waits on the policy; a device under a refusal holds it in
    /// `.waiting(.dns(kDNSServiceErr_PolicyDenied))`, which the scan maps to
    /// denied. Pinned so a runtime that starts enforcing it here fails loudly.
    func testOnThisRuntimeTheBrowserGoesReadyAndIsNeverHeldOnThePolicy() {
        let seen = Locked<[String]>([])
        let ready = expectation(description: "ready")
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: MdnsBrowser.serviceType, domain: nil), using: NWParameters())
        browser.stateUpdateHandler = { state in
            seen.mutate { $0.append(String(describing: state)) }
            if case .ready = state { ready.fulfill() }
            if case let .waiting(error) = state, LocalNetworkProbe.isLocalNetworkDenial(error) {
                XCTFail("held on the Local Network policy: \(error)")
            }
        }
        browser.start(queue: .global())
        wait(for: [ready], timeout: 5)
        browser.cancel()
        XCTAssertEqual(seen.get().first, "ready", "the states seen: \(seen.get())")
    }
}
