// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import UIKit
import XCTest
@testable import Dish

/// The app delegate's answer, the mask for each orientation, and the device
/// the scene reads it for.
@MainActor
final class OrientationLockTests: XCTestCase {

    func testEachOrientationHasItsMask() {
        XCTAssertEqual(interfaceMask(.portrait), .portrait)
        XCTAssertEqual(interfaceMask(.landscape), .landscape)
        XCTAssertEqual(interfaceMask(.any), .all)
    }

    func testAnIPadIsAPadAndEveryOtherIdiomAPhone() {
        XCTAssertEqual(deviceIdiom(.pad), .pad)
        for idiom in [UIUserInterfaceIdiom.phone, .unspecified, .tv, .carPlay, .mac, .vision] {
            XCTAssertEqual(deviceIdiom(idiom), .phone, "idiom \(idiom.rawValue)")
        }
    }

    func testTheLockAnswersEveryWayOnAnIPadAndUprightOrOnItsSideOnAnIPhone() {
        let lock = OrientationLock()
        XCTAssertEqual(lock.mask, .portrait, "an iPhone's answer before the scene speaks")
        lock.follow(screenOrientation(for: nil, idiom: .pad))
        XCTAssertEqual(lock.mask, .all)
        lock.follow(screenOrientation(for: .play(.gamepad), idiom: .pad))
        XCTAssertEqual(lock.mask, .all, "an iPad's play follows the device too")
        lock.follow(screenOrientation(for: .play(.gamepad), idiom: .phone))
        XCTAssertEqual(lock.mask, .landscape)
        lock.follow(screenOrientation(for: .dim, idiom: .phone))
        XCTAssertEqual(lock.mask, .portrait)
    }
}
