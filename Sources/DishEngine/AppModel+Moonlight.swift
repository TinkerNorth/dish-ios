// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The Moonlight host that minted a PIN, as its row's card shows it.
package struct MoonlightPinPrompt: Equatable, Identifiable {
    package let host: MoonlightHost
    package let pin: String

    package init(host: MoonlightHost, pin: String) {
        self.host = host
        self.pin = pin
    }

    package var id: String {
        host.id
    }
}

/// The Moonlight hosts' facts the page draws: the hub's rows for them, the
/// scan, the pairings in flight, each session's phase, the apps a probe
/// listed and the app picked per host, the PIN a host is waiting for and
/// the last thing a host had to say.
package struct MoonlightFacts: Equatable {
    package var hosts: [ConnectionSummary] = []
    package var discovered: [MoonlightHost] = []
    package var scanning = false
    package var pairingInFlight: Set<String> = []
    package var phases: [String: MoonlightSessionPhase] = [:]
    package var apps: [String: [MoonlightApp]] = [:]
    package var pickedApps: [String: String] = [:]
    package var pin: MoonlightPinPrompt?
    package var lastEvent: MoonlightConnectionEvent?

    package init(
        hosts: [ConnectionSummary] = [],
        discovered: [MoonlightHost] = [],
        scanning: Bool = false,
        pairingInFlight: Set<String> = [],
        phases: [String: MoonlightSessionPhase] = [:],
        apps: [String: [MoonlightApp]] = [:],
        pickedApps: [String: String] = [:],
        pin: MoonlightPinPrompt? = nil,
        lastEvent: MoonlightConnectionEvent? = nil
    ) {
        self.hosts = hosts
        self.discovered = discovered
        self.scanning = scanning
        self.pairingInFlight = pairingInFlight
        self.phases = phases
        self.apps = apps
        self.pickedApps = pickedApps
        self.pin = pin
        self.lastEvent = lastEvent
    }
}

/// What a Moonlight host's row offers besides Forget; the page words each.
package enum MoonlightRowAction: Equatable {
    case pair
    case rePair
    case disconnect
    case reconnect
    case startSession
    case retry
    case quitApp
}

/// The Moonlight half of the composition root: the bindings folded into
/// what each host is asked to carry, the hosts' feedback wired to the pads,
/// the PIN prompt, and the intents the app raises.
package extension AppModel {
    /// The hosts' events reach the model, and a pool or records change
    /// moves the pads' routes and the desire.
    internal func wireMoonlight() {
        network.moonlight.onEvent = { [weak self] event in self?.handleMoonlight(event) }
        network.moonlight.onPoolChanged = { [weak self] in self?.moonlightChanged() }
    }

    /// The Moonlight hosts page's facts.
    var moonlightFacts: MoonlightFacts {
        let moonlight = network.moonlight
        return MoonlightFacts(
            hosts: network.hub.connections.filter { $0.kind == .moonlight },
            discovered: moonlight.discoveredHosts,
            scanning: moonlight.isScanning,
            pairingInFlight: moonlight.pairingInFlight,
            phases: moonlight.connections.mapValues(\.phase),
            apps: moonlight.hostApps,
            pickedApps: Dictionary(uniqueKeysWithValues: moonlight.rememberedHosts.map { ($0.id, $0.lastAppId) }),
            pin: moonlightPin,
            lastEvent: lastMoonlightEvent
        )
    }

    private func moonlightChanged() {
        moonlightFeedback.wire(network.moonlight.connections)
        refreshRouting()
    }

    /// The desire follows the bindings, the pads present, the picks, the
    /// switches and the hosts known, and converges only when it changed, so
    /// a failed session is not re-attempted by every unrelated change.
    /// The pads a host may be asked to carry: every pad iOS lists, and the
    /// on-screen gamepad while it is one of the controllers. The desire
    /// reads a slot's id and capabilities alone.
    private var moonlightCarriableSlots: [ControllerSlot] {
        guard onScreenListed.state else { return pads.source.slots }
        return pads.source.slots + [ControllerSlot(id: onScreenSlotId, name: "", capabilities: onScreenCapabilities)]
    }

    internal func refreshMoonlightDesire() {
        let moonlight = network.moonlight
        let types = Dictionary(uniqueKeysWithValues: moonlight.rememberedHosts.map { ($0.id, $0.emulatedType) })
        let desired = MoonlightDesire.desiredPads(
            bindings: network.hub.bindings,
            hostIds: Set(types.keys).union(moonlight.connections.keys),
            slots: moonlightCarriableSlots,
            bindingTypes: Dictionary(moonlight.rememberedBindings.map { ($0.slotId, $0.controllerType) }) { _, last in last },
            hostTypes: { types[$0] ?? Int(MoonlightControllerType.auto) },
            preferences: pads.switches.state,
            global: pads.features.flags
        )
        guard desired != lastDesired else { return }
        lastDesired = desired
        moonlight.applyDesired(desired)
    }

    /// The PIN prompt follows the pairing: shown when minted, gone once the
    /// host paired or refused. Every event is kept for the page to word.
    private func handleMoonlight(_ event: MoonlightConnectionEvent) {
        lastMoonlightEvent = event
        switch event {
        case let .pairingPinReady(host, pin):
            moonlightPin = MoonlightPinPrompt(host: host, pin: pin)
        case let .paired(host), let .pairingFailed(host, _):
            if moonlightPin?.host.id == host.id { moonlightPin = nil }
        case .hostReplaced, .appAlreadyRunning, .rejoinRefused, .launchRefused, .setupFailed, .hostFull, .endedByHost,
             .appCloseRequested, .noHostAnswered, .noAppsAvailable, .appRemoved:
            break
        }
    }

    // MARK: - Intents

    /// The controller page's Emulate as for a pad on a Moonlight host: the
    /// protocol's own type, or nil for the host's own.
    func setMoonlightEmulatedType(slotId: String, _ type: Int?) {
        network.hub.setMoonlightEmulatedType(slotId: slotId, type)
        refreshRouting()
    }

    /// Pair with a host: without a PIN when it already trusts this device,
    /// else the PIN prompt follows.
    func pairMoonlight(_ hostId: String) {
        guard let host = network.moonlight.hostFor(hostId) else { return }
        let moonlight = network.moonlight
        Task { @MainActor in _ = await moonlight.pairHost(host) }
    }

    func cancelMoonlightPairing(_ hostId: String) {
        network.moonlight.cancelPairing(hostId: hostId)
        if moonlightPin?.host.id == hostId { moonlightPin = nil }
    }

    /// The PIN card's New code: the exchange in flight ends and another begins.
    func newMoonlightCode(_ hostId: String) {
        cancelMoonlightPairing(hostId)
        pairMoonlight(hostId)
    }

    /// False for an address that is blank once trimmed; anything else is
    /// probed, and a host that does not answer is told as an event.
    @discardableResult
    func addMoonlightHost(_ text: String) -> Bool {
        guard let address = moonlightAddress(from: text) else { return false }
        network.moonlight.addManualHost(address)
        return true
    }

    /// The Moonlight hosts page's own browse, nothing of the satellites'.
    func scanMoonlightHosts() {
        network.moonlight.startDiscovery()
    }

    /// Leaving the Moonlight hosts page ends the pairing its PIN card waits
    /// on, and drops the last word the page showed.
    func leftMoonlightHosts() {
        lastMoonlightEvent = nil
        guard let prompt = moonlightPin else { return }
        cancelMoonlightPairing(prompt.host.id)
    }

    /// Ask the host to close the app it runs; the way past a session somebody else holds.
    func quitMoonlightApp(_ hostId: String) {
        guard let host = network.moonlight.hostFor(hostId) else { return }
        network.moonlight.quitHostApp(host)
    }

    func retryMoonlightSessions() {
        network.moonlight.retrySessions()
    }

    /// Stop the host's session for now; its pads stay bound and the next
    /// use opens it again.
    func disconnectMoonlightHost(_ hostId: String) {
        network.moonlight.disconnect(hostId: hostId)
    }

    /// Forget This PC for a host: every pad bound there lets go, then the
    /// record, the pin and a live session's app go with it.
    func forgetMoonlightHost(_ hostId: String) {
        network.hub.forgetBindings(of: hostId)
        network.moonlight.forget(hostId: hostId)
        refreshRouting()
    }

    /// The app a host's session starts, picked for the host: every pad on it shares the one session.
    func setMoonlightApp(_ hostId: String, appId: String, appName: String) {
        network.moonlight.rememberApp(hostId: hostId, appId: appId, appName: appName)
    }

    /// The page's pick, by the id the host listed; the record keeps the
    /// title beside it, and Auto (no id) clears both.
    func pickMoonlightApp(_ hostId: String, appId: String) {
        let title = network.moonlight.hostApps[hostId]?.first { $0.id == appId }?.title ?? ""
        setMoonlightApp(hostId, appId: appId, appName: title)
    }

    /// A host row's button, dispatched to its intent.
    func performMoonlight(_ action: MoonlightRowAction, hostId: String) {
        switch action {
        case .pair, .rePair: pairMoonlight(hostId)
        case .disconnect: disconnectMoonlightHost(hostId)
        case .reconnect, .startSession, .retry: retryMoonlightSessions()
        case .quitApp: quitMoonlightApp(hostId)
        }
    }
}

/// A typed Moonlight address, trimmed; nil when nothing is left.
package func moonlightAddress(from text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
