// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation

/// The Add a PC by address sheet: the field, the default port under it,
/// Connect, and what went wrong with the last attempt.
struct AddByAddressSheetState: Equatable {
    let title: String
    let prompt: String
    let placeholder: String
    let footnote: String
    let connect: String
    let connectEnabled: Bool
    /// The spinner while the PC is being reached for.
    let connecting: Bool
    /// The address Dish could not read, or the attempt's failure.
    let error: String?
    let cancel: String
}

/// `rejected` says the model refused the text as an address; `added` is
/// the PC the sheet sent for, whether the pool reaches for it now and why
/// its attempt failed when it did.
func addByAddressSheetState(
    draft: String,
    rejected: Bool,
    added: AddedByAddressFact?,
    words: L10n = .app
) -> AddByAddressSheetState {
    let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    let failure = rejected ? words.invalidAddress : added?.failure.map { connectionFailureText($0, name: typed, words: words) }
    let reaching = added?.reaching ?? false
    let waiting = reaching && failure == nil
    return AddByAddressSheetState(
        title: words.addAPCByAddress,
        prompt: words.enterThePCsAddress,
        placeholder: words.addressExample,
        footnote: words.dishUsesPort(String(defaultSatelliteUdpPort)),
        connect: words.connect,
        connectEnabled: !typed.isEmpty && !waiting,
        connecting: waiting,
        error: failure,
        cancel: words.cancel
    )
}

/// Every failure the pool can report, worded for the person; `name` is the
/// PC's name or address.
func connectionFailureText(_ failure: ConnectionFailure, name: String, words: L10n = .app) -> String {
    switch failure {
    case .identityChanged: words.identityChanged
    case .protocolMismatch: words.differentSatelliteVersion(name)
    case .dishUpdateRequired: words.dishUpdateRequired
    case .satelliteUpdateRequired: words.satelliteUpdateRequired
    case .approvalDeclined: words.operatorDeclined
    case .approvalTimedOut: words.codeExpired
    case .repairNeeded: words.repairNeeded
    case .unreachable: words.couldNotReach(name)
    case .noSharedKey: words.setupNeedsPairing
    case .sessionRefused, .badSessionMaterial, .sessionLinkFailed: words.linkWouldNotOpen
    case .controllerNotApplied: words.pcRefusedTheController
    case .noServersFound: words.noPCsFoundYet
    case .localNetworkDenied: words.cantSeeYourNetwork
    case .pairingRejected: words.pinNotAccepted(name)
    }
}
