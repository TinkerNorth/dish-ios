// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// The Add a PC by address sheet, and the words for every connection failure.
final class AddressMappersTests: XCTestCase {

    private func sheet(
        draft: String = "",
        rejected: Bool = false,
        connecting: Bool = false,
        lastEvent: ConnectionEvent? = nil
    ) -> AddByAddressSheetState {
        addByAddressSheetState(draft: draft, rejected: rejected, connecting: connecting, lastEvent: lastEvent)
    }

    func testTheSheetAsksForAnAddressAndNamesTheDefaultPort() {
        let state = sheet()
        XCTAssertEqual(state.title, "Add a PC by address")
        XCTAssertEqual(state.prompt, "Enter the PC’s IPv4 address. Add a port after a colon when Satellite uses another.")
        XCTAssertEqual(state.placeholder, "192.168.1.50")
        XCTAssertEqual(state.footnote, "Dish uses port 9876 unless you add another.")
        XCTAssertEqual(state.connect, "Connect")
        XCTAssertEqual(state.cancel, "Cancel")
        XCTAssertNil(state.error)
        XCTAssertFalse(state.connecting)
    }

    func testConnectWaitsForSomethingTyped() {
        XCTAssertFalse(sheet(draft: "").connectEnabled)
        XCTAssertFalse(sheet(draft: "   ").connectEnabled)
        XCTAssertTrue(sheet(draft: " 192.168.1.5 ").connectEnabled)
    }

    func testARejectedAddressIsWorded() {
        let state = sheet(draft: "den.local", rejected: true)
        XCTAssertEqual(state.error, "Enter an IPv4 address like 192.168.1.50 (optionally :port)")
        XCTAssertFalse(state.connecting)
        XCTAssertTrue(state.connectEnabled, "a corrected address can be sent again")
    }

    func testWhileConnectingTheSheetSpinsAndTheButtonWaits() {
        let state = sheet(draft: "192.168.1.50", connecting: true)
        XCTAssertTrue(state.connecting)
        XCTAssertFalse(state.connectEnabled)
        XCTAssertNil(state.error)
    }

    func testAFailureOfTheAttemptIsWordedAndStopsTheSpinner() {
        let state = sheet(draft: " 192.168.1.50 ", connecting: true, lastEvent: .failure(.unreachable(detail: "timed out")))
        XCTAssertEqual(state.error, "Couldn’t reach 192.168.1.50. Make sure it’s on and on your network.")
        XCTAssertFalse(state.connecting)
        XCTAssertTrue(state.connectEnabled)
    }

    func testAPairingEventIsNotAnError() {
        let server = DiscoveredServer(ip: "192.168.1.50")
        XCTAssertNil(sheet(draft: "192.168.1.50", connecting: true, lastEvent: .pairingRequired(server)).error)
        XCTAssertNil(sheet(lastEvent: .pairingFailed(serverId: "x", failure: .approvalDeclined)).error, "the pair sheet words its own")
    }

    func testEveryFailureHasItsWords() {
        let name = "192.168.1.50"
        let expected: [(ConnectionFailure, String)] = [
            (.identityChanged, "This satellite's security identity changed. If it was reinstalled, forget it here and pair again."),
            (.protocolMismatch, "192.168.1.50 is running a different Satellite version. Update both, then pair again."),
            (.dishUpdateRequired, "Dish update required"),
            (.satelliteUpdateRequired, "Satellite update required"),
            (.approvalDeclined, "The operator declined the pairing."),
            (.approvalTimedOut, "The code expired before your PC answered."),
            (.repairNeeded, "This satellite no longer recognizes this device. Re-pair needed."),
            (.unreachable(detail: "x"), "Couldn’t reach 192.168.1.50. Make sure it’s on and on your network."),
            (.noSharedKey, "Needs pairing"),
            (.sessionRefused(detail: nil), "The satellite accepted, but the controller link would not open. Try again."),
            (.badSessionMaterial, "The satellite accepted, but the controller link would not open. Try again."),
            (.sessionLinkFailed, "The satellite accepted, but the controller link would not open. Try again."),
            (.controllerNotApplied, "The PC refused the controller."),
            (.noServersFound, "No PCs found yet."),
            (.localNetworkDenied, "Dish can’t see your network"),
            (.pairingRejected(detail: nil), "That PIN wasn’t accepted. Check the code on 192.168.1.50 and try again.")
        ]
        for (failure, text) in expected {
            XCTAssertEqual(connectionFailureText(failure, name: name), text)
        }
    }
}
