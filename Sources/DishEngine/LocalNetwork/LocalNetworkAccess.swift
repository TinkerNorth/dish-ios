// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The seam to iOS's Local Network permission and to discovery: what iOS
/// has answered, a way to make it put its question, and a way to look for
/// PCs on the Wi‑Fi.
@MainActor
package protocol LocalNetworkAccess: AnyObject {
    var status: LocalNetworkStatus { get }
    func ask()
    func scan()
}

/// The production access: the Bonjour scan. iOS has no call that asks for
/// the permission, so `ask()` runs the first browse, which makes iOS put its
/// question, and `scan()` runs it again. The status is what the last scan
/// heard: unknown before any finished, denied while iOS held it on the
/// Local Network policy, allowed otherwise. While denied, a watch browse
/// waits for the person to allow (in the prompt, which may still be up, or
/// in Settings) and scans again the moment they do.
@MainActor
@Observable
package final class BonjourLocalNetworkAccess: LocalNetworkAccess {
    @ObservationIgnored private let wifi: WifiConnectionManager
    @ObservationIgnored private let watch = LocalNetworkWatch()

    package init(wifi: WifiConnectionManager) {
        self.wifi = wifi
    }

    package var status: LocalNetworkStatus {
        localNetworkStatus(denied: wifi.localNetworkDenied)
    }

    package func ask() {
        scan()
    }

    package func scan() {
        wifi.startDiscovery(trigger: .user) { [weak self] in self?.scanFinished(watching: true) }
    }

    /// The scan the watch runs when the browser left the policy wait. It
    /// starts no watch of its own: a scan that still reads denied after
    /// the browser went ready waits for the person's next scan.
    private func rescanAfterTheWatch() {
        wifi.startDiscovery(trigger: .pageOpened) { [weak self] in self?.scanFinished(watching: false) }
    }

    private func scanFinished(watching: Bool) {
        guard wifi.localNetworkDenied == true else { return watch.stop() }
        guard watching else { return }
        watch.start { [weak self] in
            Task { @MainActor [weak self] in self?.rescanAfterTheWatch() }
        }
    }
}

/// The status the last scan's word gives: nil before any scan finished.
func localNetworkStatus(denied: Bool?) -> LocalNetworkStatus {
    switch denied {
    case nil: .unknown
    case true?: .denied
    case false?: .allowed
    }
}

/// An access for tests and previews: it counts what it was asked for and
/// knows nothing, so the status stays unknown.
@MainActor
package final class RecordedLocalNetworkAccess: LocalNetworkAccess {
    package let status = LocalNetworkStatus.unknown
    package private(set) var asks = 0
    package private(set) var scans = 0

    package init() {}

    package func ask() {
        asks += 1
    }

    package func scan() {
        scans += 1
    }
}
