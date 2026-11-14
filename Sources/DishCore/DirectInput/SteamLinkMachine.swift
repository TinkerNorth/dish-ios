// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// One Steam Controller's link as SDL's iOS backend brings it up
// (`src/hidapi/ios/hid.m`): connected locally, Valve's service found, its
// characteristics read, notifications asked for on the input, and the pad
// claimed once a report arrives, which is CoreBluetooth's one sign that the
// notifications are on. A link lost ends the claim with no word to the pad;
// a release gives the pad back first and leaves the connection to the
// central, which lets go once the pad had time to answer. The engine runs
// the effects.

import Foundation

package enum SteamLinkStage: Equatable {
    case connecting
    case discovering
    case readingService
    case subscribing(SteamBleInput)
    case claimed(SteamBleInput)
    case ended
}

package enum SteamLinkEvent: Equatable {
    case connected
    case servicesFound(valve: Bool)
    case characteristicsFound([String])
    case reportArrived
    /// The link went, Bluetooth went off or the permission went away:
    /// nothing more reaches the pad.
    case lost
    /// The person turned Steam Controllers over Bluetooth off.
    case released
}

package enum SteamLinkEffect: Equatable {
    case discoverServices
    case discoverCharacteristics
    case subscribe(String)
    case claim(SteamBleInput)
    case write([SteamWrite])
    case endClaim
    case disconnect
}

package struct SteamLinkStep: Equatable {
    package let stage: SteamLinkStage
    package let effects: [SteamLinkEffect]

    package init(_ stage: SteamLinkStage, _ effects: [SteamLinkEffect] = []) {
        self.stage = stage
        self.effects = effects
    }
}

package func reduceSteamLink(_ stage: SteamLinkStage, _ event: SteamLinkEvent) -> SteamLinkStep {
    switch event {
    case .connected: connectedStep(stage)
    case let .servicesFound(valve): servicesStep(stage, valve: valve)
    case let .characteristicsFound(characteristics): characteristicsStep(stage, characteristics)
    case .reportArrived: reportStep(stage)
    case .lost: lostStep(stage)
    case .released: releasedStep(stage)
    }
}

private func connectedStep(_ stage: SteamLinkStage) -> SteamLinkStep {
    guard stage == .connecting else { return SteamLinkStep(stage) }
    return SteamLinkStep(.discovering, [.discoverServices])
}

/// A peripheral without Valve's service is no Steam Controller to read.
private func servicesStep(_ stage: SteamLinkStage, valve: Bool) -> SteamLinkStep {
    guard stage == .discovering else { return SteamLinkStep(stage) }
    guard valve else { return SteamLinkStep(.ended, [.disconnect]) }
    return SteamLinkStep(.readingService, [.discoverCharacteristics])
}

private func characteristicsStep(_ stage: SteamLinkStage, _ characteristics: [String]) -> SteamLinkStep {
    guard stage == .readingService else { return SteamLinkStep(stage) }
    guard let input = steamBleInput(among: characteristics) else { return SteamLinkStep(.ended, [.disconnect]) }
    return SteamLinkStep(.subscribing(input), [.subscribe(input.characteristic)])
}

private func reportStep(_ stage: SteamLinkStage) -> SteamLinkStep {
    guard case let .subscribing(input) = stage else { return SteamLinkStep(stage) }
    return SteamLinkStep(.claimed(input), [.claim(input), .write(input.model.plan.onClaim)])
}

private func lostStep(_ stage: SteamLinkStage) -> SteamLinkStep {
    switch stage {
    case .claimed: SteamLinkStep(.ended, [.endClaim])
    case .connecting, .discovering, .readingService, .subscribing: SteamLinkStep(.ended)
    case .ended: SteamLinkStep(.ended)
    }
}

private func releasedStep(_ stage: SteamLinkStage) -> SteamLinkStep {
    switch stage {
    case let .claimed(input): SteamLinkStep(.ended, [.write(input.model.plan.onRelease), .endClaim])
    case .connecting, .discovering, .readingService, .subscribing, .ended: SteamLinkStep(.ended)
    }
}
