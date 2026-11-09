// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The phone's setup walk as data: Welcome, Input · 1 of 3, the Destination
// step (the Local Network primer while iOS has not been asked, else Pick
// your PC), Review and bind · 3 of 3. Nothing is sent until Bind.

import Foundation

/// One event applied to the walk, with what it asks of the engine. The
/// Local Network status decides which page the Destination step is.
public func reduceSetup(
    _ state: SetupState,
    _ event: SetupEvent,
    localNetwork: LocalNetworkStatus
) -> (state: SetupState, effects: [SetupEffect]) {
    switch event {
    case let .begin(start): (SetupState(start: start), [])
    case .next: continued(state, localNetwork)
    case .back: (steppedBack(state, localNetwork), [])
    case .skip: (state, [.ended(.skipped)])
    case let .pickInput(kind): pickedInput(state, kind, localNetwork)
    case let .localNetworkAnswered(allowed): answered(state, allowed: allowed)
    case let .pickDestination(pick): (pickedDestination(state, pick), [])
    case let .setEmulateAs(pad): (emulating(state, pad), [])
    case let .setMotion(on): (motion(state, on), [])
    case .bind: binding(state)
    }
}

/// The page's Continue: the welcome opens Input, the primer asks iOS. The
/// pages that wait for a pick, and Review, whose way on is Bind, stay.
private func continued(_ state: SetupState, _ localNetwork: LocalNetworkStatus) -> (SetupState, [SetupEffect]) {
    switch state.step {
    case .welcome: (moved(state, to: .input), [])
    case .localNetworkPrimer: primerContinued(state, localNetwork)
    case .input, .pickPC, .review: (state, [])
    }
}

/// iOS puts its question only once; an earlier answer is the answer.
private func primerContinued(_ state: SetupState, _ localNetwork: LocalNetworkStatus) -> (SetupState, [SetupEffect]) {
    switch localNetwork {
    case .unknown: (state, [.askLocalNetwork])
    case .allowed, .denied: enteredDestination(state, localNetwork)
    }
}

/// The Destination step for this status, with a scan when one can be heard.
private func enteredDestination(_ state: SetupState, _ localNetwork: LocalNetworkStatus) -> (SetupState, [SetupEffect]) {
    switch localNetwork {
    case .unknown: (moved(state, to: .localNetworkPrimer), [])
    case .allowed: (moved(state, to: .pickPC), [.scan])
    case .denied: (moved(state, to: .pickPC), [])
    }
}

private func steppedBack(_ state: SetupState, _ localNetwork: LocalNetworkStatus) -> SetupState {
    guard state.canGoBack else { return state }
    switch state.step {
    case .welcome, .input: return moved(state, to: .welcome)
    case .localNetworkPrimer, .pickPC: return moved(state, to: .input)
    case .review: return moved(state, to: destinationPage(localNetwork))
    }
}

private func destinationPage(_ localNetwork: LocalNetworkStatus) -> SetupStep {
    switch localNetwork {
    case .unknown: .localNetworkPrimer
    case .allowed, .denied: .pickPC
    }
}

/// A pick answers Input and opens the Destination step; the emulated pad
/// and motion start from what was picked.
private func pickedInput(_ state: SetupState, _ kind: InputKind, _ localNetwork: LocalNetworkStatus) -> (SetupState, [SetupEffect]) {
    guard state.step == .input else { return (state, []) }
    let pad = kind.defaultEmulation
    var next = state
    next.draft.input = kind
    next.draft.emulateAs = pad
    next.draft.motion = pad.hasMotion
    return enteredDestination(next, localNetwork)
}

/// The answer moves the primer on; an allow heard on Pick your PC (turned
/// on in Settings) looks again.
private func answered(_ state: SetupState, allowed: Bool) -> (SetupState, [SetupEffect]) {
    let effects: [SetupEffect] = allowed ? [.scan] : []
    switch state.step {
    case .localNetworkPrimer: return (moved(state, to: .pickPC), effects)
    case .pickPC: return (state, effects)
    case .welcome, .input, .review: return (state, [])
    }
}

/// Adding by address is offered on the primer too, so either Destination
/// page takes a pick.
private func pickedDestination(_ state: SetupState, _ pick: DestinationPick) -> SetupState {
    switch state.step {
    case .localNetworkPrimer, .pickPC:
        var next = moved(state, to: .review)
        next.draft.destination = pick
        return next
    case .welcome, .input, .review:
        return state
    }
}

/// Another pad brings its own motion default.
private func emulating(_ state: SetupState, _ pad: EmulatedPad) -> SetupState {
    guard state.step == .review else { return state }
    var next = state
    next.draft.emulateAs = pad
    next.draft.motion = pad.hasMotion
    return next
}

private func motion(_ state: SetupState, _ on: Bool) -> SetupState {
    guard state.step == .review else { return state }
    var next = state
    next.draft.motion = on && state.draft.emulateAs.hasMotion
    return next
}

private func binding(_ state: SetupState) -> (SetupState, [SetupEffect]) {
    guard state.step == .review else { return (state, []) }
    return (state, [.bind(state.draft), .ended(.bound)])
}

private func moved(_ state: SetupState, to step: SetupStep) -> SetupState {
    var next = state
    next.step = step
    return next
}
