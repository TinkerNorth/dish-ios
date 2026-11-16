// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishEngine

/// The port a model identifier names: iPhones through the 14 Pro and the
/// four late Lightning iPads read Lightning, everything else USB-C, the
/// unknown included.
final class DevicePortTests: XCTestCase {

    func testIPhonesThroughThe14ProHaveLightningAndThe15OnwardsUSBC() {
        for lightning in ["iPhone12,1", "iPhone12,8", "iPhone13,2", "iPhone14,6", "iPhone14,8", "iPhone15,2", "iPhone15,3"] {
            XCTAssertEqual(devicePort(modelIdentifier: lightning), .lightning, lightning)
        }
        for usbC in ["iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,5", "iPhone18,1", "iPhone21,3"] {
            XCTAssertEqual(devicePort(modelIdentifier: usbC), .usbC, usbC)
        }
    }

    func testTheIPadsWithLightningAreTheMini5TheAir3AndThe8thAnd9thIPads() {
        for lightning in ["iPad7,11", "iPad11,1", "iPad11,2", "iPad11,3", "iPad11,4", "iPad11,6", "iPad11,7", "iPad12,1", "iPad12,2"] {
            XCTAssertEqual(devicePort(modelIdentifier: lightning), .lightning, lightning)
        }
        for usbC in ["iPad8,1", "iPad8,12", "iPad13,1", "iPad13,18", "iPad14,1", "iPad15,7", "iPad16,3"] {
            XCTAssertEqual(devicePort(modelIdentifier: usbC), .usbC, usbC)
        }
    }

    func testAnIPodHasLightning() {
        XCTAssertEqual(devicePort(modelIdentifier: "iPod9,1"), .lightning)
    }

    /// The simulator's machine is the Mac's own, and a device the table has
    /// never heard of is a new one, which has USB-C: neither is warned.
    func testWhatTheTableDoesNotKnowReadsAsUSBC() {
        for unknown in ["arm64", "x86_64", "", "iPhone", "iPhone15", "15,4", "Watch7,1", "RealityDevice14,1"] {
            XCTAssertEqual(devicePort(modelIdentifier: unknown), .usbC, unknown)
        }
    }

    func testTheIdentifierIsTakenApartIntoItsFamilyAndNumbers() throws {
        let model = try XCTUnwrap(HardwareModel("iPhone15,4"))
        XCTAssertEqual(model.family, "iPhone")
        XCTAssertEqual(model.generation, 15)
        XCTAssertEqual(model.variant, 4)
        for malformed in ["iPhone15", "iPhone15,", "iPhone15,4,1", "15,4", "iPhone,4", "iPhone15,x"] {
            XCTAssertNil(HardwareModel(malformed), malformed)
        }
    }
}
