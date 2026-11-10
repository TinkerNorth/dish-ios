// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// Which way the window may turn, for each cover on each device: an iPhone
/// stands upright and lies on its side for play; an iPad follows the device
/// on every screen, because iPadOS turns its window with the device and
/// refuses an app that shares the screen a turn of its own.
final class ScreenOrientationTests: XCTestCase {

    private static let everyCover: [Cover?] = [nil, .setup(.firstRun), .setup(.addController), .setup(.guide), .dim]
        + PlayScreen.allCases.map { .play($0) }

    func testOnAnIPhonePlayIsLandscapeAndEveryOtherScreenPortrait() {
        for screen in PlayScreen.allCases {
            XCTAssertEqual(screenOrientation(for: .play(screen), idiom: .phone), .landscape)
        }
        for cover in [Cover.setup(.firstRun), .dim, nil] {
            XCTAssertEqual(screenOrientation(for: cover, idiom: .phone), .portrait)
        }
    }

    func testOnAnIPadEveryScreenFollowsTheDevicePlayIncluded() {
        for cover in Self.everyCover {
            XCTAssertEqual(screenOrientation(for: cover, idiom: .pad), .any, String(describing: cover))
        }
    }
}
