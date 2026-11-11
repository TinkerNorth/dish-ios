// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The satellite and the attempts a pair sheet test draws.
private enum PairFixture {
    static let den = DiscoveredServer(name: "Den PC", ip: "192.168.1.40", machineId: "den")
    static let nameless = DiscoveredServer(ip: "192.168.1.40")

    static func attempt(
        clientPin: String = "4821",
        phase: ReversePairingPhase = .awaiting,
        submitting: Bool = false,
        rejection: PinRejection? = nil,
        rejections: Int = 0,
        elapsedMs: Int = 0
    ) -> PairingAttempt {
        PairingAttempt(
            clientPin: clientPin,
            phase: phase,
            submittingPin: submitting,
            rejection: rejection,
            rejections: rejections,
            elapsedMs: elapsedMs
        )
    }

    static func card(
        _ attempt: PairingAttempt = attempt(),
        server: DiscoveredServer = den,
        deviceName: String = "",
        typed: String = "",
        timeoutMs: Int = 120_000
    ) -> PairCardState? {
        let open = OpenPairing(server: server, attempt: attempt, requestTimeoutMs: timeoutMs)
        guard case let .card(card) = pairSheetState(pairing: open, serverId: server.id, deviceName: deviceName, typed: typed) else {
            return nil
        }
        return card
    }
}

/// The pair sheet (B5): the typed PIN over four cells, the operator request
/// beside it, both paths' outcomes, and Rename this iPhone.
final class PairingMappersTests: XCTestCase {

    func testTheCardNamesThePCAndAsksForItsPin() throws {
        let card = try XCTUnwrap(PairFixture.card(typed: "73"))
        XCTAssertEqual(card.title, "Pair with Den PC")
        XCTAssertEqual(card.prompt, "Enter the PIN Satellite shows on your PC.")
        XCTAssertEqual(card.cells, [
            PinCellState(index: 0, digit: "7", focused: false),
            PinCellState(index: 1, digit: "3", focused: false),
            PinCellState(index: 2, digit: "", focused: true),
            PinCellState(index: 3, digit: "", focused: false)
        ])
        XCTAssertEqual(card.cellStroke, DishTheme.outline)
        XCTAssertTrue(card.fieldEnabled)
        XCTAssertFalse(card.submitting)
        XCTAssertNil(card.pinError)
        XCTAssertEqual(card.pinHint, "Satellite › Pairing › Current PIN")
        XCTAssertEqual(card.orWord, "or")
        XCTAssertEqual(card.rename, "Rename this iPhone")
        XCTAssertEqual(card.renamePlaceholder, "iPhone")
        XCTAssertEqual(card.deviceName, "")
        XCTAssertEqual(card.done, "Done")
        XCTAssertEqual(card.cancel, "Cancel")
    }

    func testTheCellCountComesFromTheEngineAndAFullPinKeepsTheCaretOnTheLastCell() throws {
        let card = try XCTUnwrap(PairFixture.card(typed: "7312"))
        XCTAssertEqual(card.cells.count, pairingPinDigits)
        XCTAssertEqual(card.cells.map(\.digit), ["7", "3", "1", "2"])
        XCTAssertEqual(card.cells.map(\.focused), [false, false, false, true])
        XCTAssertEqual(PairFixture.card(typed: "73a1 2")?.cells.map(\.digit), ["7", "3", "1", "2"], "only digits reach the cells")
    }

    func testTheRequestShowsTheCodeToAcceptOnThePCWhileWaiting() throws {
        let request = try XCTUnwrap(PairFixture.card()?.request)
        XCTAssertEqual(request, PairRequestState(
            title: "Accept on your PC",
            body: "Satellite shows a request from iPhone. Accept it if the code matches.",
            code: "4821",
            status: "Waiting · 2:00",
            statusColor: DishTheme.muted,
            waiting: true,
            retry: nil
        ))
        XCTAssertEqual(
            PairFixture.card(deviceName: "Den iPhone")?.request?.body,
            "Satellite shows a request from Den iPhone. Accept it if the code matches."
        )
    }

    func testTheWaitCountsDownFromWhatTheSatelliteKeepsTheRequestAsTheApprovalPollMovesIt() {
        let waiting = { (elapsedMs: Int, timeoutMs: Int) in
            PairFixture.card(PairFixture.attempt(elapsedMs: elapsedMs), timeoutMs: timeoutMs)?.request?.status
        }
        XCTAssertEqual(waiting(2000, 120_000), "Waiting · 1:58", "B5's own line after the first poll")
        XCTAssertEqual(waiting(60000, 120_000), "Waiting · 1:00")
        XCTAssertEqual(waiting(113_000, 120_000), "Waiting · 0:07")
        XCTAssertEqual(waiting(500, 90000), "Waiting · 1:30", "a poll's remainder rounds up to the second")
        XCTAssertEqual(waiting(120_000, 120_000), "Waiting · 0:00")
        XCTAssertEqual(waiting(130_000, 120_000), "Waiting · 0:00", "never below nothing")
    }

    func testADeclineAndAnExpiryOfferTryAgain() throws {
        let declined = try XCTUnwrap(PairFixture.card(PairFixture.attempt(phase: .declined))?.request)
        XCTAssertEqual(declined.status, "The operator declined the pairing.")
        XCTAssertEqual(declined.statusColor, DishTheme.error)
        XCTAssertFalse(declined.waiting)
        XCTAssertEqual(declined.retry, "Try again")
        let expired = try XCTUnwrap(PairFixture.card(PairFixture.attempt(phase: .timedOut))?.request)
        XCTAssertEqual(expired.status, "The code expired before your PC answered.")
        XCTAssertEqual(expired.statusColor, DishTheme.muted)
        XCTAssertEqual(expired.retry, "Try again")
    }

    func testApprovalIdentityAndVersionEndTheRequestWithoutANewCode() throws {
        let approved = try XCTUnwrap(PairFixture.card(PairFixture.attempt(phase: .approved)))
        XCTAssertEqual(approved.request?.status, "Approved, connecting")
        XCTAssertEqual(approved.request?.statusColor, DishTheme.success)
        XCTAssertEqual(approved.request?.waiting, true)
        XCTAssertNil(approved.request?.retry)
        XCTAssertFalse(approved.fieldEnabled, "the session is taking over")
        let identity = try XCTUnwrap(PairFixture.card(PairFixture.attempt(phase: .identityChanged))?.request)
        XCTAssertEqual(
            identity.status,
            "This satellite's security identity changed. If it was reinstalled, forget it here and pair again."
        )
        XCTAssertEqual(identity.statusColor, DishTheme.error)
        XCTAssertNil(identity.retry)
        let version = try XCTUnwrap(PairFixture.card(PairFixture.attempt(phase: .versionMismatch))?.request)
        XCTAssertEqual(version.status, "Den PC is running a different Satellite version. Update both, then pair again.")
        XCTAssertNil(version.retry)
    }

    func testNoRequestFiledLeavesTheRequestOut() {
        XCTAssertNil(PairFixture.card(PairFixture.attempt(phase: .idle))?.request)
    }

    func testAWrongPinIsWordedAndTheCellsTurnRed() throws {
        let once = try XCTUnwrap(PairFixture.card(PairFixture.attempt(rejection: .wrongPin, rejections: 1)))
        XCTAssertEqual(once.pinError, "That PIN wasn’t accepted. Check the code on Den PC and try again.")
        XCTAssertEqual(once.cellStroke, DishTheme.error)
        XCTAssertTrue(once.fieldEnabled, "the next try is open")
        let thrice = try XCTUnwrap(PairFixture.card(PairFixture.attempt(rejection: .wrongPin, rejections: 3)))
        XCTAssertEqual(
            thrice.pinError,
            "That PIN wasn’t accepted. Check the code on Den PC and try again. The code changes if the Satellite screen was refreshed."
        )
    }

    func testEachRejectionHasItsWords() {
        XCTAssertEqual(PairFixture.card(PairFixture.attempt(rejection: .pending))?.pinError, "Den PC hasn’t approved the pairing yet.")
        XCTAssertEqual(
            PairFixture.card(PairFixture.attempt(rejection: .versionMismatch))?.pinError,
            "Den PC is running a different Satellite version. Update both, then pair again."
        )
        XCTAssertEqual(
            PairFixture.card(PairFixture.attempt(rejection: .unreachable))?.pinError,
            "Couldn’t reach Den PC. Make sure it’s on and on your network."
        )
        XCTAssertEqual(
            PairFixture.card(PairFixture.attempt(rejection: .identityChanged))?.pinError,
            "This satellite's security identity changed. If it was reinstalled, forget it here and pair again."
        )
    }

    func testWhileThePinIsOnItsWayTheFieldWaits() throws {
        let card = try XCTUnwrap(PairFixture.card(PairFixture.attempt(submitting: true)))
        XCTAssertFalse(card.fieldEnabled)
        XCTAssertTrue(card.submitting)
    }

    func testANamelessPCIsCalledByItsAddress() {
        XCTAssertEqual(PairFixture.card(server: PairFixture.nameless)?.title, "Pair with 192.168.1.40")
        XCTAssertEqual(
            PairFixture.card(PairFixture.attempt(rejection: .wrongPin, rejections: 1), server: PairFixture.nameless)?.pinError,
            "That PIN wasn’t accepted. Check the code on 192.168.1.40 and try again."
        )
    }

    func testACardForAnotherPCOrNoneHasEnded() {
        XCTAssertEqual(pairSheetState(pairing: nil, serverId: "mid:den", deviceName: "", typed: ""), .ended)
        let open = OpenPairing(server: PairFixture.den, attempt: PairFixture.attempt())
        XCTAssertEqual(pairSheetState(pairing: open, serverId: "mid:other", deviceName: "", typed: ""), .ended)
    }
}
