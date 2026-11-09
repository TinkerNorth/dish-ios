// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import SwiftUI

// MARK: - Destination · 2 of 3: Pick your PC

/// A PC Dish heard, picked by a tap.
struct SetupPCRow: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let detail: String
    let dot: Color
    let pick: DestinationPick
}

/// Local Network is off: in place of the list, why, and the way to Settings.
struct SetupRefusalState: Equatable {
    let title: String
    let body: String
    let action: String
    let path: String
}

enum SatelliteListState: Equatable {
    case rows([SetupPCRow])
    case nothingYet(String)
    case refused(SetupRefusalState)
}

struct SatelliteSectionState: Equatable {
    let title: String
    let chip: ChipState
    /// "Searching" while discovery looks; nil otherwise.
    let searching: String?
    let list: SatelliteListState
}

struct MoonlightSectionState: Equatable {
    let symbol: String
    let title: String
    let chip: ChipState
    let body: String
    let hosts: [SetupPCRow]
}

struct PickPCStepState: Equatable {
    let title: String
    let body: String
    let satellite: SatelliteSectionState
    let moonlight: MoonlightSectionState
    let byAddress: String
    let getSatellite: PageLink
    let footnote: String
}

func pickPCStepState(_ inputs: SetupInputs, words: L10n = .app) -> PickPCStepState {
    let refused = inputs.localNetwork == .denied
    let searching = inputs.scanning && !refused
    let hosts = inputs.found.filter { $0.kind == .moonlightHost }
    return PickPCStepState(
        title: words.pickYourPC,
        body: words.pickYourPCBody,
        satellite: SatelliteSectionState(
            title: words.setupSatellite,
            chip: ChipState(text: words.setupFastest, tone: .success),
            searching: searching ? words.setupSearching : nil,
            list: satelliteList(inputs, words: words)
        ),
        moonlight: MoonlightSectionState(
            symbol: setupPCSymbol(.moonlightHost),
            title: words.useAMoonlightHost,
            chip: ChipState(text: words.setupFast, tone: .primary),
            body: words.useAMoonlightHostBody,
            hosts: hosts.map { setupPCRow($0, words: words) }
        ),
        byAddress: words.addAPCByAddress,
        getSatellite: PageLink(title: words.getSatelliteForYourPC, url: DishLinks.satellite),
        footnote: words.dontSeeYourPC
    )
}

private func satelliteList(_ inputs: SetupInputs, words: L10n) -> SatelliteListState {
    let satellites = inputs.found.filter { $0.kind == .satellite }
    switch inputs.localNetwork {
    case .denied: return .refused(setupRefusal(words: words))
    case .unknown, .allowed: break
    }
    guard !satellites.isEmpty else { return .nothingYet(words.noPCsFoundYet) }
    return .rows(satellites.map { setupPCRow($0, words: words) })
}

private func setupRefusal(words: L10n) -> SetupRefusalState {
    SetupRefusalState(
        title: words.setupCantSeeYourNetwork,
        body: words.setupCantSeeYourNetworkBody,
        action: words.setupOpenSettings,
        path: words.setupLocalNetworkSettingsPath
    )
}

private func setupPCRow(_ pc: SetupPCInput, words: L10n) -> SetupPCRow {
    let pairing = setupPairingWord(pc.paired, words: words)
    return SetupPCRow(
        id: pc.id,
        symbol: setupPCSymbol(pc.kind),
        name: pc.name,
        detail: [pairing, pc.address].joined(separator: lineSeparator),
        dot: setupPairingDot(pc.paired),
        pick: destinationPick(pc)
    )
}

func setupPCSymbol(_ kind: SetupPCKind) -> String {
    switch kind {
    case .satellite: "desktopcomputer"
    case .moonlightHost: "display"
    }
}

private func destinationPick(_ pc: SetupPCInput) -> DestinationPick {
    switch pc.kind {
    case .satellite: .satellite(id: pc.id)
    case .moonlightHost: .moonlightHost(id: pc.id)
    }
}

func setupPairingWord(_ paired: Bool, words: L10n) -> String {
    paired ? words.setupPaired : words.setupNeedsPairing
}

func setupPairingDot(_ paired: Bool) -> Color {
    paired ? DishTheme.success : DishTheme.warning
}
