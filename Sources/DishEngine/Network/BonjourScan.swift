// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import Network
import os
import Synchronization

/// A bounded Bonjour browse: browse one service type for a window, resolve
/// every advertised endpoint to an IPv4 address, and hand each resolved
/// service to a factory. Every `NWBrowser` and resolution callback runs on a
/// background queue, so the collector's state sits behind one mutex, and
/// the continuation resumes exactly once: when the window closes and every
/// resolution has settled, or when the browser fails. The browse also says
/// whether iOS held it on the Local Network policy when the window closed.
enum BonjourScan {
    static let defaultTimeoutMs = 4000
    /// A resolution that never reaches ready or failed (the host vanished
    /// mid-browse) is reported unresolved after this, so it cannot hold the
    /// scan open.
    static let resolveTimeoutMs = 3000
    static let log = Logger(subsystem: "com.tinkernorth.dish.ios", category: "discovery")

    typealias Factory<Found> = @Sendable (_ name: String, _ host: String, _ txt: [String: String]) -> (id: String, found: Found)

    /// What a browse learned: the services it resolved, and whether the
    /// browser was waiting on the Local Network policy when it ended.
    struct Outcome<Found> {
        let found: [Found]
        let localNetworkDenied: Bool
    }

    /// Never throws; a missing mDNS stack or an empty LAN yields no services.
    static func discover<Found: Sendable>(
        serviceType: String,
        txtKeys: [String],
        timeoutMs: Int = defaultTimeoutMs,
        make: @escaping Factory<Found>
    ) async -> Outcome<Found> {
        await withCheckedContinuation { continuation in
            let params = NWParameters()
            params.includePeerToPeer = false
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: params)
            let collector = BonjourCollector(continuation: continuation, browser: browser, txtKeys: txtKeys, make: make)
            browser.browseResultsChangedHandler = { results, _ in
                results.forEach(collector.handle)
            }
            browser.stateUpdateHandler = collector.browserState
            browser.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
                collector.finish()
            }
        }
    }

    /// The resolving connection's parameters: UDP over IPv4 only. The data
    /// plane dials IPv4 literals, and a dual-stack host would otherwise
    /// resolve to its link-local IPv6 address and be dropped.
    static func resolveParameters() -> NWParameters {
        let params = NWParameters.udp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        return params
    }

    /// A dotted-quad IPv4 string from a resolved endpoint; an IPv6-only
    /// result and an unresolved name are dropped with a log line.
    static func ipv4(from endpoint: NWEndpoint?) -> String? {
        guard case let .hostPort(host, _) = endpoint else { return nil }
        switch host {
        case let .ipv4(addr):
            return addr.debugDescription.components(separatedBy: "%").first
        case let .ipv6(addr):
            log.warning("mDNS result dropped: IPv6-only endpoint \(addr.debugDescription, privacy: .public)")
            return nil
        case let .name(name, _):
            log.warning("mDNS result dropped: unresolved hostname \(name, privacy: .public)")
            return nil
        @unknown default:
            return nil
        }
    }
}

/// Accumulates one browse's resolved services and resumes its continuation
/// exactly once.
private final class BonjourCollector<Found: Sendable>: Sendable {
    private struct State {
        var found: [String: Found] = [:]
        var pending = 0
        var windowClosed = false
        var resumed = false
        var policyWaiting = false
        var connections: [NWConnection] = []
    }

    private let state = Mutex(State())
    private let continuation: CheckedContinuation<BonjourScan.Outcome<Found>, Never>
    private let browser: NWBrowser
    private let txtKeys: [String]
    private let make: BonjourScan.Factory<Found>

    init(
        continuation: CheckedContinuation<BonjourScan.Outcome<Found>, Never>,
        browser: NWBrowser,
        txtKeys: [String],
        make: @escaping BonjourScan.Factory<Found>
    ) {
        self.continuation = continuation
        self.browser = browser
        self.txtKeys = txtKeys
        self.make = make
    }

    /// A browser held on the policy is noted, not ended: iOS reports the
    /// same wait while its prompt is still up, and the browser goes ready
    /// once the person allows. Only the wait in force when the window
    /// closes reads as a refusal. A failed browser ends the browse.
    func browserState(_ browserState: NWBrowser.State) {
        switch browserState {
        case let .waiting(error):
            BonjourScan.log.warning("mDNS browser waiting: \(String(describing: error), privacy: .public)")
            let denial = LocalNetworkProbe.isLocalNetworkDenial(error)
            state.withLock { $0.policyWaiting = denial }
        case .ready:
            state.withLock { $0.policyWaiting = false }
        case let .failed(error):
            BonjourScan.log.warning("mDNS browser failed: \(String(describing: error), privacy: .public)")
            let denial = LocalNetworkProbe.isLocalNetworkDenial(error)
            state.withLock { $0.policyWaiting = denial }
            finish()
        case .setup, .cancelled:
            break
        @unknown default:
            break
        }
    }

    /// One browse result: the TXT keys asked for, then the endpoint resolved
    /// to a host.
    func handle(_ result: NWBrowser.Result) {
        guard case let .service(name, _, _, _) = result.endpoint else { return }
        let txt = txtEntries(result.metadata)
        let accepted = state.withLock { current -> Bool in
            guard !current.windowClosed, !current.resumed else { return false }
            current.pending += 1
            current.policyWaiting = false
            return true
        }
        guard accepted else { return }
        resolve(result.endpoint) { [self] host in
            settle(name: name, host: host, txt: txt)
        }
    }

    private func txtEntries(_ metadata: NWBrowser.Result.Metadata) -> [String: String] {
        guard case let .bonjour(record) = metadata else { return [:] }
        var txt: [String: String] = [:]
        for key in txtKeys {
            if case let .string(value) = record.getEntry(for: key) { txt[key] = value }
        }
        return txt
    }

    private func settle(name: String, host: String?, txt: [String: String]) {
        let made = host.map { make(name, $0, txt) }
        let done = state.withLock { current -> Bool in
            if let made { current.found[made.id] = made.found }
            current.pending -= 1
            return current.windowClosed && current.pending == 0
        }
        if done { finish() }
    }

    /// A throwaway `NWConnection` to resolve the service endpoint to an
    /// address, reported once: ready, failed, cancelled or the deadline.
    private func resolve(_ endpoint: NWEndpoint, completion: @escaping @Sendable (String?) -> Void) {
        let connection = NWConnection(to: endpoint, using: BonjourScan.resolveParameters())
        state.withLock { $0.connections.append(connection) }
        let report = ReportOnce(connection: connection, completion: completion)
        connection.stateUpdateHandler = report.connectionState
        connection.start(queue: .global(qos: .userInitiated))
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(BonjourScan.resolveTimeoutMs)) {
            report.report(nil)
        }
    }

    /// When the window closes and every resolution has settled, or on
    /// failure. The first close cancels the browser and every pending
    /// connection, so a wedged one fails fast instead of holding the scan.
    func finish() {
        let step = state.withLock { current -> FinishStep in
            let firstClose = !current.windowClosed
            current.windowClosed = true
            if current.resumed { return .already }
            if current.pending > 0 { return .waitForResolutions(firstClose: firstClose, current.connections) }
            current.resumed = true
            let outcome = BonjourScan.Outcome(found: Array(current.found.values), localNetworkDenied: current.policyWaiting)
            return .resume(outcome, current.connections)
        }
        switch step {
        case .already:
            return
        case let .waitForResolutions(firstClose, connections):
            guard firstClose else { return }
            browser.cancel()
            connections.forEach { $0.cancel() }
        case let .resume(outcome, connections):
            browser.cancel()
            connections.forEach { $0.cancel() }
            BonjourScan.log.info("mDNS browse: \(outcome.found.count) found, denied \(outcome.localNetworkDenied)")
            continuation.resume(returning: outcome)
        }
    }

    private enum FinishStep {
        case already
        case waitForResolutions(firstClose: Bool, [NWConnection])
        case resume(BonjourScan.Outcome<Found>, [NWConnection])
    }
}

/// One resolution's report, made once whichever end comes first.
private final class ReportOnce: Sendable {
    private let reported = Atomic<Bool>(false)
    private let connection: NWConnection
    private let completion: @Sendable (String?) -> Void

    init(connection: NWConnection, completion: @escaping @Sendable (String?) -> Void) {
        self.connection = connection
        self.completion = completion
    }

    func connectionState(_ state: NWConnection.State) {
        switch state {
        case .ready:
            report(BonjourScan.ipv4(from: connection.currentPath?.remoteEndpoint))
        case let .failed(error):
            BonjourScan.log.warning("mDNS resolve failed: \(String(describing: error), privacy: .public)")
            report(nil)
        case .cancelled:
            report(nil)
        case let .waiting(error):
            BonjourScan.log.warning("mDNS resolve waiting: \(String(describing: error), privacy: .public)")
        case .setup, .preparing:
            break
        @unknown default:
            break
        }
    }

    func report(_ ip: String?) {
        guard !reported.exchange(true, ordering: .acquiringAndReleasing) else { return }
        connection.cancel()
        completion(ip)
    }
}
