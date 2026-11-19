// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The diagnostics bundle, built from the facts the Diagnostics page already
// renders and nothing else: the app and the device, the controller data,
// each pad Dish reads with its record, the hosts as aliases, and the flight
// recorder. A host is "Host 1", "Host 2" in the order the page lists them,
// in the log too; its name, its address and its keys have no field to go
// in. Pure: the model hands in the facts and writes the file.

import DishCore
import Foundation

/// The facts one bundle is made from, as the model read them.
package struct DiagnosticsBundleFacts: Equatable {
    package let createdAtMs: Int64
    package let identity: DeviceIdentity
    package let controllerDb: ControllerDbStatus
    package let controllers: [ControllerFact]
    package let hosts: [HostDiagnostics]
    package let events: [DiagnosticsEvent]

    package init(
        createdAtMs: Int64,
        identity: DeviceIdentity,
        controllerDb: ControllerDbStatus,
        controllers: [ControllerFact],
        hosts: [HostDiagnostics],
        events: [DiagnosticsEvent]
    ) {
        self.createdAtMs = createdAtMs
        self.identity = identity
        self.controllerDb = controllerDb
        self.controllers = controllers
        self.hosts = hosts
        self.events = events
    }
}

package func diagnosticsBundle(_ facts: DiagnosticsBundleFacts) -> DiagnosticsBundle {
    let aliases = hostAliases(facts.hosts)
    return DiagnosticsBundle(
        createdAtMs: facts.createdAtMs,
        app: BundleApp(name: DiagnosticsApp.name, version: facts.identity.appVersion, build: facts.identity.appBuild),
        device: BundleDevice(model: facts.identity.model, os: "\(DiagnosticsApp.systemName) \(facts.identity.systemVersion)"),
        controllerDb: bundleControllerDb(facts.controllerDb),
        controllers: facts.controllers.compactMap(bundleController),
        hosts: facts.hosts.enumerated().map { bundleHost($1, alias: hostAlias($0)) },
        log: facts.events.map { bundleLogLine($0, aliases: aliases) }
    )
}

/// "Host 1" for the first host the page lists.
package func hostAlias(_ offset: Int) -> String {
    "Host \(offset + 1)"
}

/// What the log calls a host whose row is gone: never its name.
package let unlistedHostAlias = "Host"

/// Each host's alias by the label the flight recorder knows it by.
private func hostAliases(_ hosts: [HostDiagnostics]) -> [String: String] {
    var aliases: [String: String] = [:]
    for (offset, host) in hosts.enumerated() where aliases[host.summary.recordName] == nil {
        aliases[host.summary.recordName] = hostAlias(offset)
    }
    return aliases
}

/// The switch off is a result of its own, whatever the last check said.
private func bundleControllerDb(_ status: ControllerDbStatus) -> BundleControllerDb {
    BundleControllerDb(
        bundledVersion: status.bundledVersion,
        activeVersion: status.activeVersion,
        source: status.source,
        lastCheckAtMs: status.lastCheckAtMs,
        lastCheckResult: status.checksEnabled ? status.lastCheckResult : .off
    )
}

/// A pad a reader made; the on-screen controller is the app's own and has
/// no hardware to tell of.
private func bundleController(_ controller: ControllerFact) -> BundleController? {
    guard let source = controller.source else { return nil }
    return BundleController(
        record: controller.record?.id,
        verification: controller.record?.verification.rawValue,
        transport: bundleTransport(controller.link),
        path: bundlePath(source),
        hardware: bundleHardware(source, product: controller.name)
    )
}

private func bundleTransport(_ link: ControllerLink) -> ControllerTransport {
    switch link {
    case .usbC: .usb
    case .bluetooth, .onScreen: .bluetooth
    }
}

private func bundlePath(_ source: PadSource) -> BundlePath {
    switch source {
    case .gameController: .gameController
    case .bluetooth: .bluetooth
    }
}

private func bundleHardware(_ source: PadSource, product: String) -> BundleHardware {
    switch source {
    case let .gameController(category):
        BundleHardware(vid: nil, pid: nil, product: product, category: category)
    case let .bluetooth(vendorId, productId):
        BundleHardware(vid: String(format: "%04x", vendorId), pid: String(format: "%04x", productId), product: product, category: nil)
    }
}

private func bundleHost(_ host: HostDiagnostics, alias: String) -> BundleHost {
    BundleHost(
        alias: alias,
        kind: connectionKindWord(host.summary.kind),
        version: host.moonlight?.info?.appVersion,
        protocolVersion: hostProtocol(host),
        link: linkStateWord(host.summary.live),
        grants: BundleGrants(mic: false, speaker: false, hapticAudio: false)
    )
}

/// The protocol a satellite's session settled on; nil while none is up, and
/// for a Moonlight host, whose protocol has no version of Dish's.
private func hostProtocol(_ host: HostDiagnostics) -> Int? {
    switch host.summary.kind {
    case .satellite, .bluetooth: host.facts.live ? host.facts.settledProtocol : nil
    case .moonlight: nil
    }
}

func connectionKindWord(_ kind: ConnectionKind) -> String {
    switch kind {
    case .satellite: "satellite"
    case .moonlight: "moonlight"
    case .bluetooth: "bluetooth"
    }
}

func linkStateWord(_ state: LinkState) -> String {
    switch state {
    case .stale: "stale"
    case .saved: "saved"
    case .ready: "ready"
    case .connecting: "connecting"
    case .connected: "connected"
    case .unstable: "unstable"
    }
}

/// One recorder line in the maintainers' words: its kind as the tag, then
/// who it is about, a host by its alias.
private func bundleLogLine(_ event: DiagnosticsEvent, aliases: [String: String]) -> BundleLogLine {
    BundleLogLine(atMs: event.atMs, tag: eventTag(event.kind), message: eventMessage(event, aliases: aliases))
}

private func eventMessage(_ event: DiagnosticsEvent, aliases: [String: String]) -> String {
    let host = aliases[event.host] ?? unlistedHostAlias
    switch event.kind {
    case .linkAppeared: return "\(alias(of: event.subject, aliases: aliases)): \(linkStateWord(event.to))"
    case .linkChanged: return "\(alias(of: event.subject, aliases: aliases)): \(linkStateWord(event.from)) -> \(linkStateWord(event.to))"
    case .linkRemoved: return alias(of: event.subject, aliases: aliases)
    case .padAttached: return padWord(event.subject)
    case .padDetached, .padBound, .padUnbound: return event.host.isEmpty ? padWord(event.subject) : "\(padWord(event.subject)) on \(host)"
    }
}

/// A link's subject is a host: its alias, never its name.
private func alias(of subject: DiagnosticsSubject, aliases: [String: String]) -> String {
    switch subject {
    case let .named(name): aliases[name] ?? unlistedHostAlias
    case .onScreenGamepad: unlistedHostAlias
    }
}

/// A pad by the name its vendor gave it; the on-screen controller by its role.
private func padWord(_ subject: DiagnosticsSubject) -> String {
    switch subject {
    case let .named(name): name
    case .onScreenGamepad: "on-screen gamepad"
    }
}

private func eventTag(_ kind: DiagnosticsEventKind) -> String {
    switch kind {
    case .linkAppeared: "linkAppeared"
    case .linkChanged: "linkChanged"
    case .linkRemoved: "linkRemoved"
    case .padAttached: "padAttached"
    case .padDetached: "padDetached"
    case .padBound: "padBound"
    case .padUnbound: "padUnbound"
    }
}
