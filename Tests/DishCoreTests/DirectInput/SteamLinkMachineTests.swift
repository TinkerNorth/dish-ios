// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// One Steam Controller's link as SDL's iOS backend brings it up: connected,
/// Valve's service found, its characteristics read, the input subscribed,
/// claimed on its first report; lost with no word to the pad, released with
/// the pad given back first.
final class SteamLinkMachineTests: XCTestCase {

    private static let input2015 = "100F6C33-1735-4313-B402-38567131E5F3"
    private static let input2026 = "100F6C7A-1735-4313-B402-38567131E5F3"
    private static let report = "100F6C34-1735-4313-B402-38567131E5F3"

    private var original: SteamBleInput {
        steamBleInputs[0]
    }

    private var triton: SteamBleInput {
        steamBleInputs[1]
    }

    func testAConnectedPadIsAskedForItsServices() {
        XCTAssertEqual(reduceSteamLink(.connecting, .connected), SteamLinkStep(.discovering, [.discoverServices]))
    }

    func testValvesServiceIsReadAndAPeripheralWithoutItLetGo() {
        XCTAssertEqual(
            reduceSteamLink(.discovering, .servicesFound(valve: true)),
            SteamLinkStep(.readingService, [.discoverCharacteristics])
        )
        XCTAssertEqual(reduceSteamLink(.discovering, .servicesFound(valve: false)), SteamLinkStep(.ended, [.disconnect]))
    }

    func testTheInputTheServiceListsIsSubscribedAndAServiceWithoutOneLetGo() {
        XCTAssertEqual(
            reduceSteamLink(.readingService, .characteristicsFound([Self.input2015, Self.report])),
            SteamLinkStep(.subscribing(original), [.subscribe(Self.input2015)])
        )
        XCTAssertEqual(reduceSteamLink(.readingService, .characteristicsFound([Self.report])), SteamLinkStep(.ended, [.disconnect]))
    }

    func testTheFirstReportClaimsThePadAndQuietsIt() {
        XCTAssertEqual(
            reduceSteamLink(.subscribing(original), .reportArrived),
            SteamLinkStep(.claimed(original), [.claim(original), .write(SteamBleModels.original.plan.onClaim)])
        )
        XCTAssertEqual(
            reduceSteamLink(.subscribing(triton), .reportArrived),
            SteamLinkStep(.claimed(triton), [.claim(triton), .write(SteamBleModels.triton.plan.onClaim)]),
            "lizard mode off and the IMU on"
        )
    }

    func testAReportBeforeTheSubscriptionOrAfterTheClaimMovesNothing() {
        for stage in [SteamLinkStage.connecting, .discovering, .readingService, .claimed(original), .ended] {
            XCTAssertEqual(reduceSteamLink(stage, .reportArrived), SteamLinkStep(stage), "\(stage)")
        }
    }

    func testAnEventOutOfTurnMovesNothing() {
        XCTAssertEqual(reduceSteamLink(.claimed(original), .connected), SteamLinkStep(.claimed(original)))
        XCTAssertEqual(reduceSteamLink(.connecting, .servicesFound(valve: true)), SteamLinkStep(.connecting))
        XCTAssertEqual(reduceSteamLink(.discovering, .characteristicsFound([Self.input2026])), SteamLinkStep(.discovering))
    }

    func testALostLinkEndsItsClaimWithNoWordToThePad() {
        XCTAssertEqual(reduceSteamLink(.claimed(triton), .lost), SteamLinkStep(.ended, [.endClaim]))
        for stage in [SteamLinkStage.connecting, .discovering, .readingService, .subscribing(original), .ended] {
            XCTAssertEqual(reduceSteamLink(stage, .lost), SteamLinkStep(.ended), "\(stage): there is no claim to end")
        }
    }

    func testAReleaseGivesTheClaimedPadBackFirstAndLeavesTheConnectionToTheCentral() {
        XCTAssertEqual(
            reduceSteamLink(.claimed(original), .released),
            SteamLinkStep(.ended, [.write(SteamBleModels.original.plan.onRelease), .endClaim])
        )
        XCTAssertEqual(
            reduceSteamLink(.claimed(triton), .released),
            SteamLinkStep(.ended, [.write(SteamBleModels.triton.plan.onRelease), .endClaim]),
            "the motors stop; the watchdog brings lizard mode back"
        )
        for stage in [SteamLinkStage.connecting, .discovering, .readingService, .subscribing(triton), .ended] {
            XCTAssertEqual(reduceSteamLink(stage, .released), SteamLinkStep(.ended), "\(stage): nothing was changed on the pad")
        }
    }
}
