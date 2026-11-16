// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// The Lightning note, the word for a pad attached to the device, and the
/// Wired on this iPhone sheet behind the note.
final class AdapterMappersTests: XCTestCase {

    func testAUSBCIPhoneNeedsNoNote() {
        XCTAssertNil(adapterNote(port: .usbC))
    }

    func testALightningIPhonesNoteNamesThePortTheAdapterAndTheWayToTheSheet() {
        XCTAssertEqual(adapterNote(port: .lightning), AdapterNoteState(
            symbol: "bolt.fill",
            title: "Lightning port",
            body: "A wired controller needs Apple’s Lightning to USB Camera Adapter.",
            more: "What you need"
        ))
    }

    func testAnAttachedPadIsWordedByTheDevicesPort() {
        XCTAssertEqual(wiredLinkWord(.usbC), "USB-C")
        XCTAssertEqual(wiredLinkWord(.lightning), "Lightning")
    }

    func testTheSheetDrawsThePhoneTheAdapterAndThePadThenSaysWhatToDo() {
        let state = lightningAdapterSheetState()
        XCTAssertEqual(state.title, "Wired on this iPhone")
        XCTAssertEqual(state.thisIPhone, AdapterTile(symbol: "iphone", label: "This iPhone"))
        XCTAssertEqual(state.adapterLabel, "Adapter")
        XCTAssertEqual(state.controller, AdapterTile(symbol: "gamecontroller", label: "Controller"))
        XCTAssertEqual(state.headline, "This iPhone has a Lightning port.")
        XCTAssertEqual(
            state.body,
            "A Lightning cable alone can’t carry a controller’s input. A wired controller needs Apple’s Lightning to USB Camera Adapter."
        )
        XCTAssertEqual(state.stepsTitle, "What you need")
        XCTAssertEqual(state.steps.map(\.symbol), ["cable.connector", "gamecontroller", "powerplug.fill"])
        XCTAssertEqual(state.steps.map(\.text), [
            "Plug the adapter into the iPhone’s Lightning port.",
            "Plug the controller’s USB cable into the adapter.",
            "Pick the USB 3 adapter and plug a charger into its Lightning port. "
                + "A controller draws more power than the iPhone gives on its own."
        ])
        XCTAssertEqual(state.note, "Bluetooth needs no adapter.")
        XCTAssertEqual(state.adapterLink, PageLink(title: "Apple’s Lightning to USB 3 Camera Adapter", url: DishLinks.lightningAdapter))
        XCTAssertEqual(state.done, "Done")
    }
}
