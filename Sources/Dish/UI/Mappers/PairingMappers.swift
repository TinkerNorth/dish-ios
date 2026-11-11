// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// The rejection that earns the refresh hint: by then the likeliest cause is
/// a satellite screen that re-drew and minted a new code.
private let refreshHintRejections = 3

/// One cell of a PIN: its digit or empty, and whether the caret sits in it.
struct PinCellState: Equatable, Identifiable {
    let index: Int
    let digit: String
    let focused: Bool

    var id: Int {
        index
    }
}

/// The operator request: the code to accept on the PC and where it stands.
struct PairRequestState: Equatable {
    let title: String
    let body: String
    let code: String
    let status: String
    let statusColor: Color
    /// The spinner beside the status.
    let waiting: Bool
    /// Try again, once the request was declined or expired.
    let retry: String?
}

/// The pair sheet's card: the typed PIN over its cells and its error, the
/// operator request beside it, and Rename this iPhone.
struct PairCardState: Equatable {
    let title: String
    let prompt: String
    let cells: [PinCellState]
    let cellStroke: Color
    let fieldEnabled: Bool
    /// The spinner while a typed PIN is on its way.
    let submitting: Bool
    let pinError: String?
    let pinHint: String
    let orWord: String
    /// Nil while no operator request is filed.
    let request: PairRequestState?
    let rename: String
    let renamePlaceholder: String
    /// The stored name the rename field starts from; empty while there is none.
    let deviceName: String
    let done: String
    let cancel: String
}

/// The pair sheet for one PC: its card, or nothing once the attempt ended
/// and the sheet is lowering.
enum PairSheetState: Equatable {
    case card(PairCardState)
    case ended
}

func pairSheetState(pairing: OpenPairing?, serverId: String, deviceName: String, typed: String, words: L10n = .app) -> PairSheetState {
    guard let pairing, pairing.server.id == serverId else { return .ended }
    let name = serverTitle(pairing.server)
    let attempt = pairing.attempt
    let pinError = attempt.rejection.map { pinRejectionText($0, name: name, rejections: attempt.rejections, words: words) }
    let typingOpen = !attempt.submittingPin && attempt.phase != .approved
    return .card(PairCardState(
        title: words.pairWith(name),
        prompt: words.enterThePinSatelliteShows,
        cells: pinCells(typed),
        cellStroke: pinError == nil ? DishTheme.outline : DishTheme.error,
        fieldEnabled: typingOpen,
        submitting: attempt.submittingPin,
        pinError: pinError,
        pinHint: words.currentPinPath,
        orWord: words.orWord,
        request: pairRequestState(attempt, name: name, deviceName: deviceName, timeoutMs: pairing.requestTimeoutMs, words: words),
        rename: words.renameThisIPhone,
        renamePlaceholder: words.iPhone,
        deviceName: deviceName,
        done: words.done,
        cancel: words.cancel
    ))
}

/// A satellite's name, or its address when it never advertised one.
func serverTitle(_ server: DiscoveredServer) -> String {
    server.name.isEmpty ? server.ip : server.name
}

/// The request's half, absent while none is filed. Only a decline and an
/// expiry offer a new code: a changed identity or another protocol version
/// ends the request in a way no new code rescues.
func pairRequestState(
    _ attempt: PairingAttempt,
    name: String,
    deviceName: String,
    timeoutMs: Int,
    words: L10n = .app
) -> PairRequestState? {
    let left = remainingText(timeoutMs - attempt.elapsedMs)
    guard let line = requestStatusLine(attempt.phase, name: name, left: left, words: words) else { return nil }
    let device = deviceName.isEmpty ? words.iPhone : deviceName
    return PairRequestState(
        title: words.acceptOnYourPC,
        body: paragraph(words.satelliteShowsARequestFrom(device), words.acceptItIfTheCodeMatches),
        code: attempt.clientPin,
        status: line.text,
        statusColor: line.color,
        waiting: line.waiting,
        retry: line.offersNewCode ? words.tryAgain : nil
    )
}

/// One status line of the operator request.
private struct RequestStatusLine {
    let text: String
    let color: Color
    let waiting: Bool
    let offersNewCode: Bool
}

private func requestStatusLine(_ phase: ReversePairingPhase, name: String, left: String, words: L10n) -> RequestStatusLine? {
    switch phase {
    case .idle:
        nil
    case .awaiting:
        RequestStatusLine(text: words.waitingWithTimeLeft(left), color: DishTheme.muted, waiting: true, offersNewCode: false)
    case .approved:
        RequestStatusLine(text: words.approvedConnecting, color: DishTheme.success, waiting: true, offersNewCode: false)
    case .declined:
        RequestStatusLine(text: words.operatorDeclined, color: DishTheme.error, waiting: false, offersNewCode: true)
    case .timedOut:
        RequestStatusLine(text: words.codeExpired, color: DishTheme.muted, waiting: false, offersNewCode: true)
    case .identityChanged:
        RequestStatusLine(text: words.identityChanged, color: DishTheme.error, waiting: false, offersNewCode: false)
    case .versionMismatch:
        RequestStatusLine(
            text: words.differentSatelliteVersion(name),
            color: DishTheme.error,
            waiting: false,
            offersNewCode: false
        )
    }
}

/// Why the typed PIN did not pair, with the refresh hint from the third
/// rejection on.
func pinRejectionText(_ rejection: PinRejection, name: String, rejections: Int, words: L10n = .app) -> String {
    let reason = switch rejection {
    case .wrongPin: words.pinNotAccepted(name)
    case .pending: words.notApprovedYet(name)
    case .versionMismatch: words.differentSatelliteVersion(name)
    case .unreachable: words.couldNotReach(name)
    case .identityChanged: words.identityChanged
    }
    let addsHint = rejections >= refreshHintRejections
    return addsHint ? paragraph(reason, words.codeChangesOnRefresh) : reason
}

/// The satellite's cells, as many as its PIN has digits, each with its
/// typed digit or empty; the caret sits in the next empty one, or the last.
func pinCells(_ typed: String) -> [PinCellState] {
    let digits = Array(pinDigits(typed))
    let caret = min(digits.count, pairingPinDigits - 1)
    return (0 ..< pairingPinDigits).map { index in
        PinCellState(index: index, digit: index < digits.count ? String(digits[index]) : "", focused: index == caret)
    }
}

/// The digits typed, at most as many as a PIN has, so the field can never
/// hold more.
func pinDigits(_ typed: String) -> String {
    String(typed.filter(isASCIIDigit).prefix(pairingPinDigits))
}

/// A whole PIN, ready to send.
func isWholePin(_ pin: String) -> Bool {
    pin.count == pairingPinDigits && pin.allSatisfy(isASCIIDigit)
}

private func isASCIIDigit(_ character: Character) -> Bool {
    character.isASCII && character.isNumber
}

/// What is left of the request as the board counts it, "1:58": whole
/// seconds rounded up, as a countdown reads (it shows 0:00 only once the
/// time is out), and never below nothing.
func remainingText(_ milliseconds: Int) -> String {
    let seconds = (max(milliseconds, 0) + 999) / 1000
    let digits = String(format: "%02d", seconds % secondsPerMinute)
    return "\(seconds / secondsPerMinute):\(digits)"
}

private let secondsPerMinute = 60
