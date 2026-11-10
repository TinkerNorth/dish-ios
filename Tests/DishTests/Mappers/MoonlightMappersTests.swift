// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// The Moonlight words: the page's rows, a host's trust, dot, status,
/// actions and controllers, and what each of the hosts' events says.
final class MoonlightMappersTests: XCTestCase {

    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")

    private func summary(_ live: LinkState, bound: [String] = [], label: String = "PC") -> ConnectionSummary {
        ConnectionSummary(id: "moonlight:10.0.0.5", name: label, address: "10.0.0.5", live: live, kind: .moonlight, boundSlotIds: bound)
    }

    private func satellite() -> ConnectionSummary {
        ConnectionSummary(id: "mid:1", name: "Desk", live: .ready)
    }

    func testThePageListsKnownHostsThenOnlyTheNewlyDiscovered() {
        let known = [satellite(), summary(.ready)]
        let other = MoonlightHost(name: "", address: "10.0.0.9")
        let rows = moonlightRows(known: known, discovered: [host, other])
        XCTAssertEqual(rows, [.known(summary(.ready)), .discovered(other)], "a discovered host the records know is not listed twice")
        XCTAssertEqual(rows.map(\.key), ["moonlight:10.0.0.5", "moonlight:10.0.0.9"])
        XCTAssertEqual(moonlightHostTitle(other), "10.0.0.9", "a host with no name is shown by its address")
        XCTAssertEqual(moonlightHostTitle(host), "PC")
    }

    func testTheTrustWordIsPairedRememberedOrNotPaired() {
        XCTAssertEqual(moonlightTrustText(.ready), "Paired")
        XCTAssertEqual(moonlightTrustText(.connected), "Paired")
        XCTAssertEqual(moonlightTrustText(.connecting), "Paired")
        XCTAssertEqual(moonlightTrustText(.unstable), "Paired")
        XCTAssertEqual(moonlightTrustText(.saved), "Remembered", "paired and out of sight")
        XCTAssertEqual(moonlightTrustText(.stale), "Not paired")
    }

    func testTheDotIsGreenWhileTheHostAnswersAndNeverAmberAtRest() {
        XCTAssertEqual(moonlightDot(.ready), DishTheme.success)
        XCTAssertEqual(moonlightDot(.connected), DishTheme.success)
        XCTAssertEqual(moonlightDot(.connecting), DishTheme.warning)
        XCTAssertEqual(moonlightDot(.unstable), DishTheme.warning)
        XCTAssertEqual(moonlightDot(.saved), DishTheme.muted, "a host switched off is not a fault")
        XCTAssertEqual(moonlightDot(.stale), DishTheme.muted)
    }

    func testTheControllerCountAppearsOnceAPadIsBound() {
        XCTAssertNil(moonlightControllersText(summary(.ready)))
        XCTAssertEqual(moonlightControllersText(summary(.ready, bound: ["a"])), "1 controller")
        XCTAssertEqual(moonlightControllersText(summary(.connected, bound: ["a", "b", "c"])), "3 controllers")
    }

    func testTheRowOffersTheWayOutOfWhereTheSessionStands() {
        XCTAssertEqual(moonlightRowActions(summary(.connected), phase: .streaming), [.disconnect])
        XCTAssertEqual(moonlightRowActions(summary(.connecting), phase: .launching), [], "a session coming up is left alone")
        XCTAssertEqual(moonlightRowActions(summary(.unstable), phase: .failed(.dropped)), [.reconnect])
        XCTAssertEqual(moonlightRowActions(summary(.ready), phase: .failed(.hostEnded)), [.startSession])
        XCTAssertEqual(moonlightRowActions(summary(.ready), phase: .failed(.appAlreadyRunning)), [.quitApp, .retry])
        XCTAssertEqual(moonlightRowActions(summary(.ready), phase: .failed(.resumeFailed)), [.quitApp, .retry])
        XCTAssertEqual(moonlightRowActions(summary(.ready), phase: .failed(.launchRejected)), [.retry])
        XCTAssertEqual(moonlightRowActions(summary(.saved), phase: .failed(.unreachable)), [.retry])
        XCTAssertEqual(moonlightRowActions(summary(.stale), phase: .failed(.trustLost)), [.rePair])
        XCTAssertEqual(moonlightRowActions(summary(.stale), phase: .failed(.hostReplaced)), [.rePair])
        XCTAssertEqual(moonlightRowActions(summary(.stale), phase: .failed(.notPaired)), [.pair])
        XCTAssertEqual(moonlightRowActions(summary(.stale), phase: nil), [.pair], "never paired: Pair now")
        XCTAssertEqual(moonlightRowActions(summary(.ready), phase: nil), [], "the bindings drive a paired host")
        XCTAssertEqual(moonlightRowActions(summary(.saved), phase: .idle), [])
        XCTAssertEqual(moonlightActionText(.quitApp, host: "PC"), "Close the app on PC")
        XCTAssertEqual(moonlightActionText(.pair, host: "PC"), "Pair now")
        XCTAssertEqual(moonlightActionText(.rePair, host: "PC"), "Re-pair")
        XCTAssertEqual(moonlightActionText(.disconnect, host: "PC"), "Disconnect")
        XCTAssertEqual(moonlightActionText(.reconnect, host: "PC"), "Reconnect")
        XCTAssertEqual(moonlightActionText(.startSession, host: "PC"), "Start a session")
        XCTAssertEqual(moonlightActionText(.retry, host: "PC"), "Retry")
    }

    func testTheStatusLineSaysWhyTheSessionIsNotUpWhenTheWordDoesNot() {
        XCTAssertNil(moonlightStatusLine(summary(.connected), phase: .streaming))
        XCTAssertNil(moonlightStatusLine(summary(.connecting), phase: .rtsp(.play)))
        XCTAssertNil(moonlightStatusLine(summary(.ready), phase: nil))
        XCTAssertEqual(moonlightStatusLine(summary(.stale), phase: nil), "Not paired yet")
        XCTAssertEqual(moonlightStatusLine(summary(.stale), phase: .failed(.notPaired)), "Not paired yet")
        XCTAssertEqual(moonlightStatusLine(summary(.stale), phase: .failed(.trustLost)), "PC no longer recognises this device")
        XCTAssertEqual(moonlightStatusLine(summary(.stale), phase: .failed(.hostReplaced)), "PC was reset")
        XCTAssertEqual(moonlightStatusLine(summary(.saved), phase: .failed(.unreachable)), "PC is not answering")
        XCTAssertEqual(moonlightStatusLine(summary(.unstable), phase: .failed(.dropped)), "Session on PC ended")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.hostEnded)), "PC ended the session")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.appAlreadyRunning)), "Another device is using PC")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.resumeFailed)), "Could not rejoin the session on PC")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.launchRejected)), "PC refused the session")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.rtspRejected)), "Could not finish the session on PC")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.controlLost)), "Could not finish the session on PC")
        XCTAssertEqual(moonlightStatusLine(summary(.ready), phase: .failed(.noApps)), "No apps on this host")
        XCTAssertNil(moonlightStatusLine(summary(.ready), phase: .failed(.appRemoved)), "the notice names the app")
        XCTAssertEqual(
            moonlightStatusLine(summary(.saved, label: ""), phase: .failed(.unreachable)),
            "10.0.0.5 is not answering",
            "a host with no name by its address"
        )
    }

    func testThePairingEventsAreWordedAndTheHostsOwnWordsAreQuoted() {
        XCTAssertNil(moonlightNotice(for: .pairingPinReady(host: host, pin: "0451")), "the PIN is its row's card")
        let paired = moonlightNotice(for: .paired(host))
        XCTAssertEqual(paired?.severity, .success)
        XCTAssertEqual(paired?.title, "Paired with PC")
        XCTAssertEqual(paired?.body, "Dish starts a session on this host as soon as a controller is bound to it.")
        XCTAssertEqual(paired?.key, "moonlight.pair")
        let refusedPin = moonlightNotice(for: .pairingFailed(
            host: host,
            reason: MoonlightPairingFailure(
                phase: 1,
                kind: .noCertificate,
                httpStatus: 200,
                hostSaid: "A pairing session with this uniqueid already exists"
            )
        ))
        XCTAssertEqual(refusedPin?.severity, .error)
        XCTAssertEqual(refusedPin?.title, "PC did not accept the PIN")
        XCTAssertEqual(refusedPin?.body, "A pairing session with this uniqueid already exists", "the host's own words")
        let wrongPin = moonlightNotice(for: .pairingFailed(
            host: host,
            reason: MoonlightPairingFailure(phase: 3, kind: .hostNotAuthentic, httpStatus: 200, hostSaid: "")
        ))
        XCTAssertEqual(wrongPin?.body, "Check that the code went into the right host, then try again.")
        let noIdentity = moonlightNotice(for: .pairingFailed(
            host: host,
            reason: MoonlightPairingFailure(phase: 1, kind: .noIdentity, httpStatus: 0, hostSaid: "")
        ))
        XCTAssertEqual(noIdentity?.body, "Dish has no pairing identity yet. Try again in a moment.")
    }

    func testEverySessionEventIsWordedAndOneNoticePerHostIsKept() {
        let busy = moonlightNotice(for: .appAlreadyRunning(host: host, resumable: false))
        XCTAssertEqual(busy?.title, "Another device is using PC")
        XCTAssertEqual(
            busy?.body,
            "PC is running an app for another device and will not hand it over. Close it to start a new one, or try again later."
        )
        XCTAssertEqual(busy?.quitHost, host, "the way out is to close that app")
        XCTAssertEqual(busy?.key, "moonlight.moonlight:10.0.0.5", "one notice per host")
        XCTAssertEqual(moonlightNotice(for: .rejoinRefused(host))?.quitHost, host)
        XCTAssertEqual(
            moonlightNotice(for: .rejoinRefused(host))?.body,
            "The host has a session but would not hand it back. Close the app on PC and start a new one."
        )
        XCTAssertEqual(
            moonlightNotice(for: .launchRefused(host: host, message: "Unauthorized"))?.title,
            "PC refused the session: Unauthorized"
        )
        XCTAssertEqual(moonlightNotice(for: .launchRefused(host: host, message: ""))?.title, "PC refused the session")
        XCTAssertEqual(
            moonlightNotice(for: .launchRefused(host: host, message: ""))?.body,
            "Add the controller anyway and Dish will try again the next time you use it."
        )
        XCTAssertNil(moonlightNotice(for: .launchRefused(host: host, message: ""))?.quitHost)
    }

    func testTheSessionsFailuresAndTheHostsOwnEndingsAreWorded() {
        XCTAssertEqual(moonlightNotice(for: .setupFailed(host))?.title, "Could not finish the session on PC")
        XCTAssertEqual(
            moonlightNotice(for: .setupFailed(host))?.body,
            "The app started but the stream did not come up, so Dish closed it again."
        )
        XCTAssertEqual(
            moonlightNotice(for: .hostFull(host))?.body,
            "A session carries four controllers at most, and PC already has four. Unbind one to make room."
        )
        XCTAssertEqual(moonlightNotice(for: .hostFull(host))?.title, "PC is full")
        XCTAssertEqual(moonlightNotice(for: .endedByHost(host))?.severity, .info)
        XCTAssertEqual(
            moonlightNotice(for: .endedByHost(host))?.body,
            "The app closed on the host. Start a new session to keep using this controller."
        )
        XCTAssertEqual(moonlightNotice(for: .hostReplaced(host))?.title, "PC was reset")
        XCTAssertEqual(
            moonlightNotice(for: .hostReplaced(host))?.body,
            "This host has a new identity, so the old pairing no longer works. Pair again to start a session."
        )
        XCTAssertEqual(moonlightNotice(for: .appCloseRequested(host))?.title, "Asked PC to close the app it is running.")
        XCTAssertEqual(moonlightNotice(for: .noHostAnswered(address: "10.0.0.9"))?.title, "No Moonlight host answered at 10.0.0.9.")
        XCTAssertEqual(moonlightNotice(for: .noHostAnswered(address: "10.0.0.9"))?.key, "moonlight.add")
        XCTAssertEqual(moonlightNotice(for: .noAppsAvailable(host))?.title, "No apps available on PC.")
        XCTAssertEqual(
            moonlightNotice(for: .appRemoved(host: host, appName: "Steam"))?.title,
            "Steam is no longer on PC. Pick another app."
        )
    }
}
