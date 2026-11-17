// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// The hardware the scene reads the port from: the simulated device's
/// identifier when the simulator names one, else the machine the kernel
/// names.
final class DeviceModelTests: XCTestCase {

    func testTheSimulatedDeviceWinsOverTheMacsOwnMachine() {
        XCTAssertEqual(hardwareModel(machine: "arm64", simulated: "iPhone15,2"), "iPhone15,2")
        XCTAssertEqual(hardwareModel(machine: "iPhone15,2", simulated: nil), "iPhone15,2")
    }

    func testTheKernelNamesTheMachine() {
        let machine = unameMachine()
        XCTAssertFalse(machine.isEmpty)
        XCTAssertTrue(machine.allSatisfy { $0.isLetter || $0.isNumber || $0 == "," || $0 == "_" }, machine)
    }

    func testTheSimulatorsKeyIsTheOneXcodeSets() {
        XCTAssertEqual(simulatedModelKey, "SIMULATOR_MODEL_IDENTIFIER")
    }
}
