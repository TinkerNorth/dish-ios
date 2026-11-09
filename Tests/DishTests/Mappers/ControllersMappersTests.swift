// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// A controller fact with the fields a test does not care about filled in.
private enum ControllerFixture {
    static func pad(
        link: ControllerLink = .usbC,
        battery: Int? = 84,
        destination: DestinationFact? = DestinationFact(name: "Living Room PC", health: .online),
        supported: Bool = true
    ) -> ControllerFact {
        ControllerFact(id: "pad", name: "DualSense", link: link, batteryPercent: battery, destination: destination, supported: supported)
    }
}

/// The Controllers tab (A2, D4).
final class ControllersMappersTests: XCTestCase {

    func testWithNoControllersTheButtonStandsUnderAnInvitation() {
        let state = controllersPageState(controllers: [])
        XCTAssertEqual(state.content, .empty(invitation: "Bind a pad or the on-screen gamepad to your PC to start playing."))
        XCTAssertEqual(state.addTitle, "Add a controller")
        XCTAssertEqual(state.addHint, "Wired, Bluetooth, or on-screen.")
    }

    func testTheToolbarsHeartOpensSupportDish() {
        let state = controllersPageState(controllers: [])
        XCTAssertEqual(state.support, ToolbarLinkState(title: "Support Dish", symbol: "heart.fill", page: .support))
    }

    func testABoundPadNamesItsPCItsLinkAndItsBattery() {
        let state = controllersPageState(controllers: [ControllerFixture.pad()])
        let row = ControllerRowState(
            id: "pad",
            symbol: "gamecontroller",
            name: "DualSense",
            destination: .bound(pcName: "Living Room PC", detail: " · USB-C"),
            dot: DishTheme.success,
            battery: "84%",
            batteryColor: DishTheme.muted,
            page: .controller(id: "pad")
        )
        XCTAssertEqual(state.content, .list([row]))
    }

    func testAPadDishCannotReadSaysSoAndOpensNothing() {
        let row = controllerRow(ControllerFixture.pad(destination: nil, supported: false))
        XCTAssertEqual(row.destination, .note("Not supported"))
        XCTAssertEqual(row.dot, DishTheme.muted)
        XCTAssertNil(row.page, "there is nothing to set on a pad Dish cannot read")
    }

    func testEachLinkHasItsWordAndGlyph() {
        let bluetooth = controllerRow(ControllerFixture.pad(link: .bluetooth))
        let onScreen = controllerRow(ControllerFixture.pad(link: .onScreen, battery: nil))
        XCTAssertEqual(bluetooth.destination, .bound(pcName: "Living Room PC", detail: " · Bluetooth"))
        XCTAssertEqual(bluetooth.symbol, "gamecontroller")
        XCTAssertEqual(onScreen.destination, .bound(pcName: "Living Room PC", detail: " · On-screen"))
        XCTAssertEqual(onScreen.symbol, "iphone")
        XCTAssertNil(onScreen.battery, "the on-screen gamepad has no battery of its own")
    }

    func testAnUnsteadyPCIsCalledOutInPlaceOfTheLink() {
        let row = controllerRow(ControllerFixture.pad(destination: DestinationFact(name: "Office PC", health: .unsteady)))
        XCTAssertEqual(row.destination, .bound(pcName: "Office PC", detail: " · Unsteady"))
        XCTAssertEqual(row.dot, DishTheme.warning)
    }

    func testALostPCReplacesTheDestinationLine() {
        let row = controllerRow(ControllerFixture.pad(destination: DestinationFact(name: "Living Room PC", health: .lost)))
        XCTAssertEqual(row.destination, .note("Connection lost"))
        XCTAssertEqual(row.dot, DishTheme.error)
    }

    func testAnUnboundControllerSaysSo() {
        let row = controllerRow(ControllerFixture.pad(destination: nil))
        XCTAssertEqual(row.destination, .note("Not bound"))
        XCTAssertEqual(row.dot, DishTheme.muted)
    }

    func testALowBatteryTurnsTheErrorColour() {
        XCTAssertEqual(controllerRow(ControllerFixture.pad(battery: 15)).batteryColor, DishTheme.error)
        XCTAssertEqual(controllerRow(ControllerFixture.pad(battery: 16)).batteryColor, DishTheme.muted)
        XCTAssertEqual(controllerRow(ControllerFixture.pad(battery: 12)).battery, "12%")
    }
}
