// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// What Dish writes to a Steam Controller on Bluetooth as it starts and
/// stops reading it, ported from dish-mac's tests: SDL's quiet and restore
/// sequences for the 2015 pad, SDL's settings for the 2026 one.
final class SteamPlanTests: XCTestCase {

    private func features(_ reports: [[UInt8]], id: UInt8) -> [SteamWrite] {
        reports.map { SteamWrite(kind: .feature, reportId: id, bytes: $0) }
    }

    func testEachModelNamesItsPlan() {
        XCTAssertEqual(SteamBleModels.original.plan, SteamPlan(generation: .originalOverBluetooth))
        XCTAssertEqual(SteamBleModels.triton.plan, SteamPlan(generation: .triton))
    }

    func testThe2015PadIsQuietedAndRestoredInSegmentsOfReportThree() {
        let plan = SteamPlan(generation: .originalOverBluetooth)
        XCTAssertEqual(plan.onClaim, features(steamBleConfigReports(.quiet), id: 3))
        XCTAssertEqual(plan.onClaim.map(\.bytes.count), [20, 20, 20, 20], "SDL's reset and its sensor enable, a segment each")
        XCTAssertEqual(plan.onRelease, features(steamBleConfigReports(.restore), id: 3))
        XCTAssertEqual(plan.refresh, [], "its settings persist until it reboots")
        XCTAssertFalse(plan.refreshesLizardMode)
        XCTAssertFalse(plan.rumbles, "no motors on the 2015 pad")
    }

    func testThe2026PadTurnsLizardModeOffAndItsImuOnAndRefreshesTheFirst() {
        let plan = SteamPlan(generation: .triton)
        XCTAssertEqual(plan.onClaim, features([tritonLizardOffReport(), tritonSensorsOnReport()], id: 1))
        XCTAssertEqual(plan.refresh, features([tritonLizardOffReport()], id: 1), "the firmware's watchdog turns it back on")
        XCTAssertTrue(plan.refreshesLizardMode)
        XCTAssertTrue(plan.rumbles)
    }

    func testThe2026PadIsReleasedByStoppingItsMotorsAndLettingTheWatchdogRestoreIt() {
        let plan = SteamPlan(generation: .triton)
        let stop = SteamWrite(kind: .output, reportId: 0x80, bytes: tritonRumbleReport(left: 0, right: 0))
        XCTAssertEqual(plan.onRelease, [stop], "SDL sends nothing on close: the watchdog re-enables lizard mode")
    }
}
