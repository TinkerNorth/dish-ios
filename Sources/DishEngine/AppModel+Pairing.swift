// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The open pairing card: its satellite, where its pairing stands, and how
/// long the satellite keeps an operator request before it expires.
package struct OpenPairing: Equatable {
    package let server: DiscoveredServer
    package let attempt: PairingAttempt
    package let requestTimeoutMs: Int

    package init(
        server: DiscoveredServer,
        attempt: PairingAttempt,
        requestTimeoutMs: Int = WifiConnectionManager.ApprovalPolling.standard.timeoutMs
    ) {
        self.server = server
        self.attempt = attempt
        self.requestTimeoutMs = requestTimeoutMs
    }
}

/// Pairing a satellite, both paths at once as the desktops' pairing sheet
/// runs them: the operator request is filed with a fresh client PIN the
/// moment the card opens, and the typed PIN stays usable beside it;
/// whichever lands first opens the session and stops the other.
package extension AppModel {

    /// Each satellite's pairing as the card shows it.
    var pairingAttempts: [String: PairingAttempt] {
        network.wifi.pairingAttempts.state
    }

    /// The card to draw, or nil when none is open or its attempt ended (a
    /// session took over, or it was cancelled).
    var openPairing: OpenPairing? {
        guard let server = pairingTarget, let attempt = pairingAttempts[server.id] else { return nil }
        return OpenPairing(server: server, attempt: attempt, requestTimeoutMs: network.wifi.approvalPolling.timeoutMs)
    }

    /// A row's Pair: the card opens and an operator request is filed.
    func beginPairing(serverId: String) {
        guard let server = network.wifi.knownServer(serverId) else { return }
        beginPairing(server)
    }

    internal func beginPairing(_ server: DiscoveredServer) {
        closeCard(otherThan: server.id)
        network.wifi.pairWithClientPin(server, clientPin: PairingClient.generateClientPin())
        pairingTarget = server
    }

    /// The PIN the satellite shows, typed into the card.
    func submitPin(_ serverId: String, pin: String) {
        guard let server = network.wifi.knownServer(serverId) else { return }
        network.wifi.pairWithPin(server, pin: pin)
    }

    /// After a decline or an expiry: the old request stops and a new code is filed.
    func newCode(_ serverId: String) {
        network.wifi.cancelApproval(serverId)
        beginPairing(serverId: serverId)
    }

    /// The card closed: no poll and no typed PIN outlive it.
    func cancelPairing(_ serverId: String) {
        network.wifi.cancelApproval(serverId)
        if pairingTarget?.id == serverId {
            pairingTarget = nil
        }
    }

    /// Rename this iPhone on the card: the satellite shows the new name, so
    /// a request it already holds is filed again under it.
    func renameThisIPhone(_ serverId: String, to name: String) {
        setDeviceName(name)
        guard pairingAttempts[serverId]?.phase == .awaiting else { return }
        newCode(serverId)
    }

    private func closeCard(otherThan id: String) {
        guard let open = pairingTarget, open.id != id else { return }
        cancelPairing(open.id)
    }
}
