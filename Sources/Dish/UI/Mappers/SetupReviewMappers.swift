// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import SwiftUI

// MARK: - Binding · 3 of 3

/// One end of the link on the review card.
struct ReviewEndState: Equatable {
    let symbol: String
    let name: String
    /// Nil for a pad that left, whose link is no longer known.
    let detail: String?
    /// The pairing dot; nil on the pad's end.
    let dot: Color?
}

struct EmulateOption: Equatable, Identifiable {
    let pad: EmulatedPad
    let name: String

    var id: EmulatedPad {
        pad
    }
}

/// A capability row: what it is, and whether this binding carries it.
struct CarryRow: Equatable, Identifiable {
    let title: String
    let carried: Bool
    let symbol: String
    let tint: Color
    /// The title's colour: a row not carried is muted.
    let label: Color

    var id: String {
        title
    }
}

struct CarryColumn: Equatable {
    let title: String
    let rows: [CarryRow]
}

struct ReviewStepState: Equatable {
    let title: String
    let body: String
    /// Nil only for a walk that reached Review without the answer.
    let pad: ReviewEndState?
    let pc: ReviewEndState?
    let emulateTitle: String
    let emulateOptions: [EmulateOption]
    let emulateAs: EmulatedPad
    let motionTitle: String
    let motion: Bool
    /// The emulated pad has motion to switch.
    let motionEnabled: Bool
    let footnote: String
    let carriesTitle: String
    let sends: CarryColumn
    let getsBack: CarryColumn
    let primary: String
}

func reviewStepState(_ draft: SetupDraft, _ inputs: SetupInputs, words: L10n = .app) -> ReviewStepState {
    let pad = draft.emulateAs
    return ReviewStepState(
        title: words.reviewAndBind,
        body: words.reviewAndBindBody,
        pad: draft.input.map { reviewPad($0, inputs, words: words) },
        pc: draft.destination.map { reviewPC($0, inputs, words: words) },
        emulateTitle: words.setupEmulateAs,
        emulateOptions: EmulatedPad.allCases.map { EmulateOption(pad: $0, name: emulatedPadName($0, words: words)) },
        emulateAs: pad,
        motionTitle: words.setupMotion,
        motion: draft.motion,
        motionEnabled: pad.hasMotion,
        footnote: paragraph(padCarriesSentence(pad, words: words), words.theOtherPadsAreInTheMenu),
        carriesTitle: words.whatCarries,
        sends: sendsColumn(draft, words: words),
        getsBack: getsBackColumn(pad, words: words),
        primary: words.setupBind
    )
}

// MARK: - The two ends

private func reviewPad(_ input: InputKind, _ inputs: SetupInputs, words: L10n) -> ReviewEndState {
    switch input {
    case let .detectedPad(id, family): seenPad(id: id, family: family, inputs, words: words)
    case .wired: ReviewEndState(symbol: "gamecontroller", name: words.wiredController, detail: words.usbC, dot: nil)
    case .bluetooth: ReviewEndState(symbol: "gamecontroller", name: words.bluetoothController, detail: words.setupBluetooth, dot: nil)
    case .onScreen: ReviewEndState(symbol: "iphone", name: words.onScreenGamepad, detail: words.setupThisIPhone, dot: nil)
    }
}

/// A seen pad by its name, link and battery; one that left by its family.
private func seenPad(id: String, family: EmulatedPad, _ inputs: SetupInputs, words: L10n) -> ReviewEndState {
    guard let pad = inputs.detectedPads.first(where: { $0.id == id }) else {
        return ReviewEndState(symbol: "gamecontroller", name: emulatedPadName(family, words: words), detail: nil, dot: nil)
    }
    let parts = [setupPadLinkWord(pad.link, words: words)] + setupBatteryWord(pad.batteryPercent, words: words)
    return ReviewEndState(symbol: "gamecontroller", name: pad.name, detail: parts.joined(separator: lineSeparator), dot: nil)
}

private func reviewPC(_ pick: DestinationPick, _ inputs: SetupInputs, words: L10n) -> ReviewEndState {
    switch pick {
    case let .satellite(id): foundPC(id: id, symbol: setupPCSymbol(.satellite), inputs, words: words)
    case let .moonlightHost(id): foundPC(id: id, symbol: setupPCSymbol(.moonlightHost), inputs, words: words)
    case .byAddress: addedByAddressPC(inputs, words: words)
    }
}

/// The PC added by address, named once Dish knows it as a paired
/// satellite; until then the generic PC, still to pair.
private func addedByAddressPC(_ inputs: SetupInputs, words: L10n) -> ReviewEndState {
    guard let id = inputs.addedByAddress, inputs.found.contains(where: { $0.id == id }) else {
        return ReviewEndState(symbol: "network", name: words.aPCByAddress, detail: words.setupNeedsPairing, dot: DishTheme.warning)
    }
    return foundPC(id: id, symbol: setupPCSymbol(.satellite), inputs, words: words)
}

/// A PC that went quiet keeps its place as "Your PC", still to be paired.
private func foundPC(id: String, symbol: String, _ inputs: SetupInputs, words: L10n) -> ReviewEndState {
    let pc = inputs.found.first { $0.id == id }
    let paired = pc?.paired ?? false
    return ReviewEndState(
        symbol: symbol,
        name: pc.map(setupPCTitle) ?? words.setupYourPC,
        detail: setupPairingWord(paired, words: words),
        dot: setupPairingDot(paired)
    )
}

// MARK: - What each pad carries

func emulatedPadName(_ pad: EmulatedPad, words: L10n = .app) -> String {
    switch pad {
    case .dualSense: words.dualSense
    case .dualShock4: words.dualShock4
    case .xboxWireless: words.xboxWireless
    case .switchPro: words.switchPro
    case .dualSenseEdge: words.dualSenseEdge
    }
}

private func padCarriesSentence(_ pad: EmulatedPad, words: L10n) -> String {
    switch pad {
    case .dualSense: words.dualSenseCarries
    case .dualShock4: words.dualShock4Carries
    case .xboxWireless: words.xboxWirelessCarries
    case .switchPro: words.switchProCarries
    case .dualSenseEdge: words.dualSenseEdgeCarries
    }
}

/// What an emulated pad carries beyond buttons, sticks, battery and rumble,
/// which every pad does. No pad gets its speaker back: iOS gives apps no
/// way to play into a controller.
struct PadCarries: Equatable {
    let touchpad: Bool
    let triggerEffects: Bool
    let lightBar: Bool
}

func padCarries(_ pad: EmulatedPad) -> PadCarries {
    switch pad {
    case .dualSense, .dualSenseEdge: PadCarries(touchpad: true, triggerEffects: true, lightBar: true)
    case .dualShock4: PadCarries(touchpad: true, triggerEffects: false, lightBar: true)
    case .xboxWireless, .switchPro: PadCarries(touchpad: false, triggerEffects: false, lightBar: false)
    }
}

/// Motion is sent only while the pad has it and the switch is on.
private func sendsColumn(_ draft: SetupDraft, words: L10n) -> CarryColumn {
    let carries = padCarries(draft.emulateAs)
    let motion = draft.emulateAs.hasMotion && draft.motion
    return CarryColumn(title: words.sendsToPC, rows: [
        carryRow(words.buttonsSticks, carried: true),
        carryRow(words.setupMotion, carried: motion),
        carryRow(words.carriesTouchpad, carried: carries.touchpad),
        carryRow(words.carriesBattery, carried: true)
    ])
}

private func getsBackColumn(_ pad: EmulatedPad, words: L10n) -> CarryColumn {
    let carries = padCarries(pad)
    return CarryColumn(title: words.getsBack, rows: [
        carryRow(words.carriesRumble, carried: true),
        carryRow(words.triggerEffects, carried: carries.triggerEffects),
        carryRow(words.lightBar, carried: carries.lightBar),
        carryRow(words.carriesSpeaker, carried: false)
    ])
}

/// A capability row, green and checked while carried; the PC's page draws
/// them too.
func carryRow(_ title: String, carried: Bool) -> CarryRow {
    CarryRow(
        title: title,
        carried: carried,
        symbol: carried ? "checkmark" : "minus",
        tint: carried ? DishTheme.success : DishTheme.muted,
        label: carried ? DishTheme.onSurface : DishTheme.muted
    )
}
