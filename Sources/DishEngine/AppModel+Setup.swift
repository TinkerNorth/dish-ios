// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The setup cover's intents: each applies the setup machine to the walk and
/// runs what it asks for. The walk's end is the navigation's business; the
/// model only drops the walk when `endSetup` is called.
package extension AppModel {

    func startSetup(_ start: SetupStart) {
        let opened = setup ?? SetupState(start: start)
        apply(.begin(at: start), to: opened)
    }

    func endSetup() {
        setupSource.setState(nil)
    }

    func setupNext() {
        applyToWalk(.next)
    }

    func setupBack() {
        applyToWalk(.back)
    }

    func setupSkip() {
        applyToWalk(.skip)
    }

    func pickSetupInput(_ kind: InputKind) {
        applyToWalk(.pickInput(kind))
    }

    func answerLocalNetwork(allowed: Bool) {
        applyToWalk(.localNetworkAnswered(allowed: allowed))
    }

    func pickSetupDestination(_ pick: DestinationPick) {
        applyToWalk(.pickDestination(pick))
    }

    func setSetupEmulateAs(_ pad: EmulatedPad) {
        applyToWalk(.setEmulateAs(pad))
    }

    func setSetupMotion(_ on: Bool) {
        applyToWalk(.setMotion(on))
    }

    func bindSetup() {
        applyToWalk(.bind)
    }

    private func applyToWalk(_ event: SetupEvent) {
        guard let walk = setup else { return }
        apply(event, to: walk)
    }

    private func apply(_ event: SetupEvent, to walk: SetupState) {
        let step = reduceSetup(walk, event, localNetwork: localNetwork.status)
        setupSource.setState(step.state)
        step.effects.forEach(run)
    }

    private func run(_ effect: SetupEffect) {
        switch effect {
        case .askLocalNetwork: askLocalNetwork()
        case .scan: scanAfterThePrimer()
        case let .bind(draft):
            adoptOnScreen(draft)
            bindDraft(draft)
        case .ended: break
        }
    }

    /// The first browse makes iOS put its question; the walk moves on when
    /// the status leaves unknown.
    private func askLocalNetwork() {
        onboarding.markLocalNetworkPrimed()
        localNetwork.ask()
        awaitLocalNetworkAnswer()
    }

    /// The walk's own scan comes after the question was asked or answered.
    private func scanAfterThePrimer() {
        onboarding.markLocalNetworkPrimed()
        localNetwork.scan()
    }

    private func awaitLocalNetworkAnswer() {
        withObservationTracking {
            _ = localNetwork.status
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.localNetworkAnswered() }
        }
    }

    private func localNetworkAnswered() {
        switch localNetwork.status {
        case .unknown: awaitLocalNetworkAnswer()
        case .allowed: answerLocalNetwork(allowed: true)
        case .denied: answerLocalNetwork(allowed: false)
        }
    }

    /// Review's Bind: the pad the walk names, a pad iOS sees or the on-screen
    /// gamepad, bound to the PC it picked or added by address, with the pick
    /// and the motion switch the walk chose. A way in with no pad yet, and a
    /// Moonlight host, bind nothing.
    private func bindDraft(_ draft: SetupDraft) {
        guard let slotId = draftSlotId(draft.input), let connectionId = draftConnectionId(draft.destination) else { return }
        setEmulatedType(slotId: slotId, draft.emulateAs)
        pads.switches.set(.motion, draft.motion, for: slotId)
        bind(slotId: slotId, to: connectionId)
    }

    /// The slot the draft names; the wired and Bluetooth ways in have no pad yet.
    private func draftSlotId(_ input: InputKind?) -> String? {
        switch input {
        case let .detectedPad(id, _): id
        case .onScreen: onScreenSlotId
        case .wired, .bluetooth, nil: nil
        }
    }

    /// The PC the draft names: the satellite it picked, or the one added by
    /// address; a Moonlight host has no satellite to bind to.
    private func draftConnectionId(_ destination: DestinationPick?) -> String? {
        switch destination {
        case let .satellite(id): id
        case .byAddress: addedByAddress?.id
        case .moonlightHost, nil: nil
        }
    }
}
