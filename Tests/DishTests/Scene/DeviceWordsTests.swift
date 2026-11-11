// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import UIKit
import XCTest
@testable import Dish

/// The catalog's device variations reach the words: an iPad reads "iPad"
/// where an iPhone reads "iPhone", through the same `L10n` members. The
/// scheme runs these on an iPhone, and a run on an iPad's simulator reads
/// the other form.
@MainActor
final class DeviceWordsTests: XCTestCase {

    private var device: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    func testTheWelcomeHeadlineAndTheDeviceRowsNameTheDeviceTheyRunOn() {
        let words = L10n.app
        XCTAssertEqual(words.thisIPhone, "This \(device)")
        XCTAssertEqual(words.renameThisIPhone, "Rename this \(device)")
        XCTAssertEqual(words.iPhone, device)
        XCTAssertEqual(words.controllerGone, "This controller isn’t connected to your \(device).")
    }

    func testAFormatThatNamesTheDeviceKeepsItsPlaceholder() {
        XCTAssertEqual(deviceNameText("", words: .app), device)
        XCTAssertEqual(deviceNameText("Den", words: .app), "Den")
    }
}
