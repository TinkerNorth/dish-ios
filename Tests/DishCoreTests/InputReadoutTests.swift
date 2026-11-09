// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The button table is the XUSB word the other clients write.
final class InputReadoutTests: XCTestCase {

    func testTheButtonTableIsTheXusbWordInBitOrder() {
        XCTAssertEqual(WireButton.allCases.map(\.bit), [
            0x0001, 0x0002, 0x0004, 0x0008, 0x0010, 0x0020, 0x0040, 0x0080,
            0x0100, 0x0200, 0x0400, 0x0800, 0x1000, 0x2000, 0x4000, 0x8000
        ])
        XCTAssertEqual(WireButton.micMute.bit, MicMute.buttonBit, "the mic-mute button is the word's one unassigned slot")
    }
}
