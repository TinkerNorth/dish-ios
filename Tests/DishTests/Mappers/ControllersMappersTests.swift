// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// A controller fact with the fields a test does not care about filled in.
private enum ControllerFixture {
    static func pad(
        name: String = "DualSense",
        link: ControllerLink = .usbC,
        battery: Int? = 84,
        destination: DestinationFact? = DestinationFact(name: "Living Room PC", health: .online),
        supported: Bool = true
    ) -> ControllerFact {
        ControllerFact(id: "pad", name: name, link: link, batteryPercent: battery, destination: destination, supported: supported)
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
            page: .controller(id: "pad"),
            open: nil
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

    func testTheOnScreenControllerIsWordedAndOffersOpen() {
        let row = controllerRow(ControllerFixture.pad(name: "", link: .onScreen, battery: nil))
        XCTAssertEqual(row.name, "On-screen gamepad")
        XCTAssertEqual(row.open, "Open")
        XCTAssertEqual(row.page, .controller(id: "pad"), "its page is still a row away")
        XCTAssertNil(controllerRow(ControllerFixture.pad()).open, "a pad has no screen to open")
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

    private func row(
        apply: ApplyFact?,
        destination: DestinationFact? = DestinationFact(name: "Living Room PC", health: .lost)
    ) -> ControllerRowState? {
        guard case let .list(rows) = controllersPageState(controllers: [ControllerFixture.pad(destination: destination)], apply: apply)
            .content else
        {
            return nil
        }
        return rows.first
    }

    /// A bind that waits for its link would read lost; the row says what is
    /// happening instead, and a failed apply is shown there (B6).
    func testAnApplyOnTheRowReplacesItsDestinationLine() {
        let running = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .running(.binding)))
        XCTAssertEqual(running?.destination, .note("Applying binding…"))
        XCTAssertEqual(running?.dot, DishTheme.muted)
        let failed = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .failed(.hostUnreachable)))
        XCTAssertEqual(failed?.destination, .note("The PC didn’t answer in time."))
        XCTAssertEqual(failed?.dot, DishTheme.error)
    }

    func testADoneApplyAndAnotherPadsApplyLeaveTheRowAlone() {
        let done = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .done))
        XCTAssertEqual(done?.destination, .note("Connection lost"))
        let other = row(apply: ApplyFact(slotId: "other", connectionId: "lr", progress: .failed(.rejected)))
        XCTAssertEqual(other?.destination, .note("Connection lost"))
        XCTAssertEqual(row(apply: nil)?.destination, .note("Connection lost"))
    }
}
