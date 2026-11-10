// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation
import SwiftUI

/// One fact of a Diagnostics card: the key on the left, the value beside it.
struct FactLine: Equatable, Identifiable {
    let key: String
    let value: String

    var id: String {
        key
    }
}

/// One card: a headline with its dot and chip, then one fact per line.
struct DiagnosticsCardState: Equatable, Identifiable {
    let id: String
    let title: String
    let dot: Color?
    let chip: String?
    let lines: [FactLine]
}

enum DiagnosticsCards: Equatable {
    case empty(String)
    case cards([DiagnosticsCardState])
}

/// The newest lines the page shows.
let recentEventLimit = 30

/// The parts of a value on one line, as the session accessory joins them.
func dotted(_ parts: String...) -> String {
    parts.joined(separator: lineSeparator)
}

// MARK: - The app

func appLines(appVersion: String, localNetwork: LocalNetworkStatus, words: L10n = .app) -> [FactLine] {
    [
        FactLine(key: words.appVersion, value: appVersion),
        FactLine(key: words.protocolKey, value: words.protocolTag(ProtocolConstants.protocolVersion)),
        FactLine(key: words.localNetwork, value: localNetworkText(localNetwork, words: words))
    ]
}

func localNetworkText(_ status: LocalNetworkStatus, words: L10n = .app) -> String {
    switch status {
    case .unknown: words.localNetworkNotAsked
    case .allowed: words.localNetworkAllowed
    case .denied: words.localNetworkDenied
    }
}

// MARK: - A PC

/// The address and the tier, then the session's own account of itself and
/// the data plane's counters, or the word for no session.
func hostLines(_ host: HostDiagnostics, locale: Locale = .current, words: L10n = .app) -> [FactLine] {
    let facts = host.facts
    let opening = [
        FactLine(key: words.address, value: connectionAddressLine(host.summary)),
        FactLine(key: words.linkTier, value: linkTierText(host.summary.kind, words: words))
    ]
    let nothingNegotiated = facts.compat == .unknown && !facts.live
    let negotiation = nothingNegotiated ? [] : [FactLine(key: words.protocolKey, value: protocolText(facts, words: words))]
    guard facts.live else { return opening + negotiation + [FactLine(key: words.session, value: words.noSessionRightNow)] }
    let counters = counterLines(host.counters, locale: locale, words: words)
    return opening + negotiation + sessionLines(facts, locale: locale, words: words) + counters
}

private func sessionLines(_ facts: HostSessionFacts, locale: Locale, words: L10n) -> [FactLine] {
    [
        FactLine(key: words.epoch, value: epochText(facts, words: words)),
        FactLine(key: words.controllers, value: controllersText(facts, words: words)),
        FactLine(key: words.virtualControllers, value: backendText(facts, words: words)),
        FactLine(key: words.roundTrip, value: roundTripText(facts.latency, locale: locale, words: words)),
        FactLine(key: words.missedHeartbeats, value: countText(UInt64(clamping: facts.missedAcks), locale: locale))
    ]
}

func counterLines(_ counters: SessionCounters, locale: Locale = .current, words: L10n = .app) -> [FactLine] {
    [
        FactLine(key: words.sent, value: countText(counters.sent, locale: locale)),
        FactLine(key: words.received, value: countText(counters.received, locale: locale)),
        FactLine(key: words.dropped, value: countText(counters.dropped, locale: locale)),
        FactLine(key: words.replayGuard, value: countText(counters.replayGuard, locale: locale))
    ]
}

/// "1,024" in the locale's digits and grouping, as the catalog's counts
/// come out beside it.
func countText(_ count: UInt64, locale: Locale) -> String {
    String(format: "%llu", locale: locale, count)
}

/// The address line, numeric and untranslated: the satellite's IP and its
/// UDP port.
func connectionAddressLine(_ summary: ConnectionSummary) -> String {
    guard let port = summary.udpPort else { return summary.address }
    return dotted(summary.address, "UDP \(port)")
}

/// The fleet's ladder, one word per rung.
func linkTierText(_ kind: ConnectionKind, words: L10n = .app) -> String {
    switch linkTierFor(kind) {
    case .fastest: words.setupFastest
    case .fast: words.setupFast
    case .basic: words.tierBasic
    }
}

/// A PC's chip: where its link stands.
func linkStateText(_ state: LinkState, words: L10n = .app) -> String {
    switch state {
    case .stale: words.setupNeedsPairing
    case .saved: words.offline
    case .ready: words.ready
    case .connecting: words.connecting
    case .connected: words.online
    case .unstable: words.unsteady
    }
}

func linkDot(_ state: LinkState) -> Color {
    switch state {
    case .connected: DishTheme.success
    case .unstable, .stale: DishTheme.warning
    case .connecting: DishTheme.primary
    case .saved, .ready: DishTheme.muted
    }
}

/// The settled version, the offer when it differed, and the standing when
/// the negotiation wants attention.
func protocolText(_ facts: HostSessionFacts, words: L10n = .app) -> String {
    let settled = words.protocolTag(facts.settledProtocol)
    let lowered = facts.offeredProtocol != facts.settledProtocol
    let version = lowered ? words.protocolOffered(settled, facts.offeredProtocol) : settled
    guard let standing = protocolCompatText(facts.compat, words: words) else { return version }
    return dotted(version, standing)
}

/// The word for a negotiation that wants attention; nil when the versions
/// match or nothing was negotiated.
func protocolCompatText(_ compat: ProtocolCompat, words: L10n = .app) -> String? {
    switch compat {
    case .unknown, .current: nil
    case .satelliteUpdateAvailable: words.satelliteUpdateRecommended
    case .satelliteUpdateRequired: words.satelliteUpdateRequired
    case .dishUpdateRequired: words.dishUpdateRequired
    }
}

func agreementText(_ agreement: Agreement, words: L10n = .app) -> String {
    switch agreement {
    case .inStep: words.inStep
    case .diverged: words.outOfStep
    case .unknown: words.waitingForTheFirstHeartbeat
    }
}

func epochText(_ facts: HostSessionFacts, words: L10n = .app) -> String {
    let agreement = agreementText(epochAgreement(hostEpoch: facts.hostEpoch, appliedEpoch: facts.appliedEpoch), words: words)
    guard let host = facts.hostEpoch else { return dotted(words.epochApplied(facts.appliedEpoch), agreement) }
    return dotted(words.epochOnHostAndApplied(host, facts.appliedEpoch), agreement)
}

func indexListText(_ indices: [Int], words: L10n = .app) -> String {
    indices.isEmpty ? words.none : indices.map(String.init).joined(separator: ", ")
}

func controllersText(_ facts: HostSessionFacts, words: L10n = .app) -> String {
    let confirmed = indexListText(bitmapIndices(facts.confirmedBitmap), words: words)
    let agreement = agreementText(bitmapAgreement(hostBitmap: facts.hostBitmap, confirmedBitmap: facts.confirmedBitmap), words: words)
    guard let hostBitmap = facts.hostBitmap else { return dotted(words.controllersConfirmed(confirmed), agreement) }
    let onHost = indexListText(bitmapIndices(hostBitmap), words: words)
    return dotted(words.controllersOnHostAndConfirmed(onHost, confirmed), agreement)
}

func backendText(_ facts: HostSessionFacts, words: L10n = .app) -> String {
    let word = switch hostBackendOf(facts.backendAvailable) {
    case .available: words.available
    case .unavailable: words.unavailable
    case .unknown: words.unknown
    }
    guard let active = facts.activeControllers else { return word }
    return dotted(word, words.inUse(active))
}

/// "12.3 ms" in the locale's digits and separator; the unit is the SI symbol.
func millisecondsText(_ ms: Double, locale: Locale) -> String {
    String(format: "%.1f ms", locale: locale, ms)
}

func roundTripText(_ latency: LatencySummary, locale: Locale = .current, words: L10n = .app) -> String {
    guard latency.samples > 0, let p50 = latency.p50RttMs, let p99 = latency.p99RttMs else { return words.noSamplesYet }
    let figures = words.roundTripFigures(
        millisecondsText(p50, locale: locale),
        millisecondsText(p99, locale: locale),
        millisecondsText(p50 / 2, locale: locale)
    )
    return dotted(figures, words.pingsOf(latency.samples, latency.capacity))
}

// MARK: - A controller

/// The link, the rates, the type and the battery, then the binding and its
/// side of the wire.
func padLines(_ pad: PadDiagnostics, words: L10n = .app) -> [FactLine] {
    let controller = pad.controller
    let opening = [
        FactLine(key: words.connection, value: linkWord(controller.link, words: words)),
        FactLine(key: words.inputRate, value: rateText(hz: pad.rates.reportHz, reports: pad.reports, words: words))
    ]
    let motion = carriesMotion(controller) ? [FactLine(key: words.motionRate, value: words.hertz(pad.rates.motionHz))] : []
    let type = [FactLine(key: words.type, value: emulatedPadName(controller.emulateAs, words: words))]
    let battery = controller.batteryPercent.map { [FactLine(key: words.carriesBattery, value: words.batteryPercent($0))] } ?? []
    return opening + motion + type + battery + bindingLines(pad, words: words)
}

/// Whether the pad has motion to measure: it carries the Motion switch.
func carriesMotion(_ controller: ControllerFact) -> Bool {
    controller.features.contains { $0.feature == .motion }
}

func rateText(hz: Int, reports: UInt64, words: L10n = .app) -> String {
    dotted(words.hertz(hz), words.reportsCount(Int(clamping: reports)))
}

/// The health the card wears: how the PC answers while bound, else why
/// there is no PC to answer.
func healthText(_ controller: ControllerFact, words: L10n = .app) -> String {
    guard controller.supported else { return words.notSupported }
    guard let destination = controller.destination else { return words.notBound }
    switch destination.health {
    case .online: return words.online
    case .unsteady: return words.unsteady
    case .lost: return words.connectionLost
    }
}

/// The PC the pad is bound to, then what its descriptor declared and what
/// the host said back.
func bindingLines(_ pad: PadDiagnostics, words: L10n = .app) -> [FactLine] {
    guard let destination = pad.controller.destination else { return [FactLine(key: words.binding, value: words.notBound)] }
    let binding = FactLine(key: words.binding, value: dotted(destination.name, words.setupSatellite))
    guard let wire = pad.wire else { return [binding, FactLine(key: words.onTheWire, value: words.notDeclaredToTheHostYet)] }
    return [
        binding,
        FactLine(key: words.controllerIndex, value: String(wire.controllerIndex)),
        FactLine(key: words.confirmedByHost, value: wire.confirmed ? words.yes : words.no),
        FactLine(key: words.streaming, value: streamingText(wire.streaming, words: words)),
        FactLine(key: words.advertised, value: advertisedText(wire.caps, words: words)),
        FactLine(key: words.touchpadOnTheWire, value: wireTouchpadText(wire.touchpad, words: words))
    ]
}

func streamingText(_ streaming: Streaming, words: L10n = .app) -> String {
    switch streaming {
    case .yes: words.yes
    case .no: words.no
    case .unknown: words.waitingForTheFirstHeartbeat
    }
}

func wireCapText(_ cap: WireCap, words: L10n = .app) -> String {
    switch cap {
    case .analogTriggers: words.analogTriggers
    case .rumble: words.carriesRumble
    case .motion: words.setupMotion
    case .lightbar: words.lightBar
    case .triggerEffects: words.adaptiveTriggers
    case .playerLeds: words.playerLeds
    case .mic: words.microphone
    case .speaker: words.carriesSpeaker
    case .hapticAudio: words.hapticAudio
    }
}

func advertisedText(_ caps: UInt16, words: L10n = .app) -> String {
    let names = advertisedCaps(caps).map { wireCapText($0, words: words) }
    return names.isEmpty ? words.nothing : names.joined(separator: lineSeparator)
}

func wireTouchpadText(_ touchpad: WireTouchpad, words: L10n = .app) -> String {
    switch touchpad {
    case .off: words.offWord
    case .pad: words.padWord
    case .mouse: words.mouseWord
    }
}

// MARK: - The lock statistics

/// One line per lock and thread role: the lock and the role as the key, the
/// counts as the value.
func lockLines(_ locks: [LockFact], words: L10n = .app) -> [FactLine] {
    locks.map { lock in
        FactLine(
            key: dotted(lock.lock, threadRoleText(lock.role, words: words)),
            value: words.lockCounts(Int(clamping: lock.acquisitions), Int(clamping: lock.contended))
        )
    }
}

func threadRoleText(_ role: ThreadRole, words: L10n = .app) -> String {
    switch role {
    case .input: words.roleInput
    case .receive: words.roleReceive
    case .heartbeat: words.roleHeartbeat
    case .feedback: words.roleFeedback
    case .main: words.roleMain
    case .other: words.roleOther
    }
}

// MARK: - The events

/// A PC or a pad by its name; the on-screen gamepad by the app's word for it.
func subjectText(_ subject: DiagnosticsSubject, words: L10n = .app) -> String {
    switch subject {
    case let .named(name): name
    case .onScreenGamepad: words.onScreenGamepad
    }
}

func eventText(_ event: DiagnosticsEvent, words: L10n = .app) -> String {
    let subject = subjectText(event.subject, words: words)
    switch event.kind {
    case .linkAppeared: return words.eventLinkAppeared(subject, linkStateText(event.to, words: words))
    case .linkChanged: return words.eventLinkChanged(
            subject,
            linkStateText(event.from, words: words),
            linkStateText(event.to, words: words)
        )
    case .linkRemoved: return words.eventLinkRemoved(subject)
    case .padAttached: return words.eventPadAttached(subject)
    case .padDetached: return words.eventPadDetached(subject)
    case .padBound: return words.eventPadBound(subject, event.host)
    case .padUnbound: return words.eventPadUnbound(subject, event.host)
    }
}

/// The wall-clock time of a line in the locale's medium time style.
func eventTimeText(_ atMs: Int64, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    return formatter.string(from: Date(timeIntervalSince1970: Double(atMs) / 1000))
}

func eventLine(_ event: DiagnosticsEvent, locale: Locale = .current, timeZone: TimeZone = .current, words: L10n = .app) -> String {
    "\(eventTimeText(event.atMs, locale: locale, timeZone: timeZone))  \(eventText(event, words: words))"
}

/// The whole log, oldest first, for the transcript.
func eventsTranscript(
    _ events: [DiagnosticsEvent],
    locale: Locale = .current,
    timeZone: TimeZone = .current,
    words: L10n = .app
) -> String {
    events.map { eventLine($0, locale: locale, timeZone: timeZone, words: words) }.joined(separator: "\n")
}

/// The newest `limit` lines, newest first, as the page shows them.
func recentEvents(_ events: [DiagnosticsEvent], limit: Int = recentEventLimit) -> [DiagnosticsEvent] {
    Array(events.suffix(limit).reversed())
}

// MARK: - The cards

func hostCard(_ host: HostDiagnostics, locale: Locale = .current, words: L10n = .app) -> DiagnosticsCardState {
    DiagnosticsCardState(
        id: host.id,
        title: host.summary.recordName,
        dot: linkDot(host.summary.live),
        chip: linkStateText(host.summary.live, words: words),
        lines: hostLines(host, locale: locale, words: words)
    )
}

/// A controller's card wears its health as the dot and the chip, as its
/// row on the Controllers tab does.
func padCard(_ pad: PadDiagnostics, words: L10n = .app) -> DiagnosticsCardState {
    DiagnosticsCardState(
        id: pad.id,
        title: controllerName(pad.controller, words: words),
        dot: destinationDot(pad.controller.destination?.health),
        chip: healthText(pad.controller, words: words),
        lines: padLines(pad, words: words)
    )
}
