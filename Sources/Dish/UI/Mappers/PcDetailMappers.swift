// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The card at the head of a PC's page: the glyph, how the link stands,
/// and the satellite's version, protocol and address.
struct PcStatusState: Equatable {
    let symbol: String
    let line: String
    let dot: Color
    let detail: String
}

/// One controller the PC carries, on its index.
struct CarriedControllerState: Equatable, Identifiable {
    let id: String
    let name: String
    let slot: String
}

/// CARRYING · 3 OF 4: the controllers bound to the PC, or that none is.
struct CarryingState: Equatable {
    let title: String
    let rows: [CarriedControllerState]
    /// Nil while something is bound.
    let empty: String?
}

/// WHAT CARRIES: each way, from the satellite's capabilities.
struct PcCarriesState: Equatable {
    let title: String
    let sends: CarryColumn
    let getsBack: CarryColumn
}

/// The page's actions besides Forget.
enum PcAction: Equatable {
    case repair
    case connect
    case disconnect
}

struct PcActionState: Equatable, Identifiable {
    let action: PcAction
    let title: String

    var id: PcAction {
        action
    }
}

/// Forget This PC, and the dialog that asks first.
struct ForgetPcState: Equatable {
    let button: String
    let title: String
    let message: String
    let confirm: String
    let cancel: String
}

/// A paired PC's page (D2).
struct PcDetailState: Equatable {
    let id: String
    let status: PcStatusState
    let carrying: CarryingState
    /// Nil until the satellite was probed.
    let carries: PcCarriesState?
    let actions: [PcActionState]
    let forget: ForgetPcState
}

enum PcDetailContent: Equatable {
    case pc(PcDetailState)
    /// The PC was forgotten while its page was open.
    case gone(message: String)
}

struct PcDetailPageState: Equatable {
    let title: String
    let content: PcDetailContent
}

func pcDetailPageState(facts: ShellFacts, id: String, words: L10n = .app) -> PcDetailPageState {
    guard let pc = facts.paired.first(where: { $0.id == id }) else {
        return PcDetailPageState(title: pageTitle(.pcDetail(id: id), words: words), content: .gone(message: words.pcNoLongerRemembered))
    }
    return PcDetailPageState(title: connectionTitle(pc), content: .pc(pcDetailState(pc, facts: facts, words: words)))
}

private func pcDetailState(_ pc: ConnectionFact, facts: ShellFacts, words: L10n) -> PcDetailState {
    PcDetailState(
        id: pc.id,
        status: PcStatusState(
            symbol: connectionSymbol(pc.kind),
            line: statusLine(pc, now: facts.now, words: words),
            dot: connectionDot(pc.state),
            detail: statusDetail(pc, words: words)
        ),
        carrying: carrying(pc, controllers: facts.controllers, words: words),
        carries: pc.features.map { carries($0, words: words) },
        actions: pcActions(pc.state, words: words),
        forget: forgetState(bound: pc.boundControllerIds.count, words: words)
    )
}

/// "Online · 4 ms", when the PC was last seen, or that it wants a PIN; the
/// pads it carries have their own section.
private func statusLine(_ pc: ConnectionFact, now: Date, words: L10n) -> String {
    switch pc.state {
    case let .online(latencyMs, _): [words.online, words.latency(latencyMs)].joined(separator: lineSeparator)
    case .offline: connectionLine(pc, now: now, words: words)
    case .needsPairing: words.setupNeedsPairing
    }
}

/// "Satellite 2.1.11 · Protocol 3 · 192.168.1.24", with what is known.
private func statusDetail(_ pc: ConnectionFact, words: L10n) -> String {
    let version = [pc.satelliteVersion.map(words.satelliteVersion)].compactMap(\.self)
    let protocolVersion = [pc.protocolVersion.map(words.protocolVersion)].compactMap(\.self)
    return (version + protocolVersion + [pc.address]).joined(separator: lineSeparator)
}

/// Each bound controller by the name its row carries, on its index; a
/// controller Dish no longer lists is a plain controller.
private func carrying(_ pc: ConnectionFact, controllers: [ControllerFact], words: L10n) -> CarryingState {
    let rows = pc.boundControllerIds.enumerated().map { index, slotId in
        CarriedControllerState(id: slotId, name: carriedName(slotId, controllers: controllers, words: words), slot: words.slot(index + 1))
    }
    let title = [words.carrying, words.countOf(rows.count, SatelliteSlots.maxPerSatellite)].joined(separator: lineSeparator)
    return CarryingState(title: title, rows: rows, empty: rows.isEmpty ? words.nothingBoundYet : nil)
}

private func carriedName(_ slotId: String, controllers: [ControllerFact], words: L10n) -> String {
    guard let controller = controllers.first(where: { $0.id == slotId }) else { return words.controller }
    return controllerName(controller, words: words)
}

/// Buttons, sticks, the touchpad and the battery always go; motion while
/// the satellite's motion backend is up. Rumble, the trigger effects and
/// the light bar come back while its feedback path is; the speaker never
/// does on iOS.
private func carries(_ features: SatelliteFeaturesFact, words: L10n) -> PcCarriesState {
    PcCarriesState(
        title: words.whatCarries,
        sends: CarryColumn(title: words.sendsToPC, rows: [
            carryRow(words.buttonsSticks, carried: true),
            carryRow(words.setupMotion, carried: features.motion),
            carryRow(words.carriesTouchpad, carried: true),
            carryRow(words.carriesBattery, carried: true)
        ]),
        getsBack: CarryColumn(title: words.getsBack, rows: [
            carryRow(words.carriesRumble, carried: features.rumble),
            carryRow(words.triggerEffects, carried: features.rumble),
            carryRow(words.lightBar, carried: features.rumble),
            carryRow(words.carriesSpeaker, carried: false)
        ])
    )
}

/// Re-pair always; Disconnect while the session is up, Connect while the
/// PC rests, and neither while its key was revoked, since a connect would
/// only fail.
private func pcActions(_ state: ConnectionState, words: L10n) -> [PcActionState] {
    let repair = PcActionState(action: .repair, title: words.repair)
    switch state {
    case .online: return [repair, PcActionState(action: .disconnect, title: words.disconnect)]
    case .offline: return [repair, PcActionState(action: .connect, title: words.connect)]
    case .needsPairing: return [repair]
    }
}

/// Forget asks first and names what stops: the controllers the PC carries.
private func forgetState(bound: Int, words: L10n) -> ForgetPcState {
    let stops = bound > 0 ? words.controllersStopStreaming(bound) : words.youNeedThePinAgain
    return ForgetPcState(
        button: words.forgetThisPC,
        title: words.forgetThisPC,
        message: paragraph(words.pairingKeyIsDeleted, stops),
        confirm: words.forget,
        cancel: words.cancel
    )
}
