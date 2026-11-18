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

/// The paired PCs a row's Bind to offers, and the menu and swipe items the
/// tests expect.
private enum RowItems {
    static let living = ConnectionFact(
        id: "lr",
        name: "Living Room PC",
        address: "192.168.1.24",
        kind: .satellite,
        state: .online(latencyMs: 4, controllers: 1)
    )
    static let nameless = ConnectionFact(id: "office", name: "", address: "192.168.1.31", kind: .satellite, state: .offline(lastSeen: nil))
    static let openGamepad = RowActionItem(
        action: ControllerAction.openGamepad,
        title: "Open gamepad",
        symbol: RowActionSymbol.open,
        destructive: false
    )
    static let find = RowActionItem(
        action: ControllerAction.findPC,
        title: "Find a PC",
        symbol: RowActionSymbol.pair,
        destructive: false
    )
    static let reconnect = RowActionItem(
        action: ControllerAction.reconnect(connectionId: "lr"),
        title: "Reconnect",
        symbol: RowActionSymbol.connect,
        destructive: false
    )
    static let touchpad = RowActionItem(
        action: ControllerAction.openSurface(slotId: "pad", screen: .touchpad),
        title: "Open touchpad",
        symbol: "rectangle.and.hand.point.up.left",
        destructive: false
    )
    static let mouse = RowActionItem(
        action: ControllerAction.openSurface(slotId: "pad", screen: .mouse),
        title: "Open mouse",
        symbol: "computermouse",
        destructive: false
    )
    static let unbind = RowActionItem(
        action: ControllerAction.unbind(slotId: "pad"),
        title: "Unbind",
        symbol: RowActionSymbol.unbind,
        destructive: true
    )

    static func bind(_ connectionId: String, _ name: String) -> RowActionItem<ControllerAction> {
        RowActionItem(
            action: .bind(slotId: "pad", connectionId: connectionId),
            title: name,
            symbol: "antenna.radiowaves.left.and.right",
            destructive: false
        )
    }
}

/// The Controllers tab (A2, D4).
final class ControllersMappersTests: XCTestCase {

    func testTheRowsAreTheControllersAndAddAControllerStandsUnderThem() {
        let state = controllersPageState(controllers: [ControllerFixture.pad()])
        XCTAssertEqual(state.rows.map(\.id), ["pad"])
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
            mark: .dot(DishTheme.success),
            battery: "84%",
            batteryColor: DishTheme.muted,
            page: .controller(id: "pad"),
            strip: nil,
            actions: RowActionsState(menu: [.item(RowItems.unbind)], leading: [], trailing: [RowItems.unbind])
        )
        XCTAssertEqual(state.rows, [row])
    }

    /// The row's strip offers what its menu does but Unbind, which stands
    /// alone at the foot of the page: Open gamepad once the on-screen
    /// controller is bound, the screens the phone lends a pad, Find a PC
    /// with nothing paired; a bound pad with nothing to open has none.
    func testTheRowsStripOffersWhatItsMenuDoesButUnbind() {
        let onScreen = controllerRow(ControllerFixture.pad(name: "", link: .onScreen, battery: nil))
        XCTAssertEqual(onScreen.strip, [.item(RowItems.openGamepad)])
        let onScreenWithMouse = ControllerFact(
            id: "on-screen",
            name: "",
            link: .onScreen,
            batteryPercent: nil,
            destination: DestinationFact(id: "lr", name: "Living Room PC", health: .online),
            surfaces: [.mouse]
        )
        let openMouse = RowActionItem(
            action: ControllerAction.openSurface(slotId: "on-screen", screen: .mouse),
            title: "Open mouse",
            symbol: "computermouse",
            destructive: false
        )
        XCTAssertEqual(
            controllerRow(onScreenWithMouse).strip,
            [.item(RowItems.openGamepad), .item(openMouse)],
            "its touchpad is its gamepad's"
        )
        let lent = ControllerFact(
            id: "pad",
            name: "Xbox Wireless Controller",
            link: .bluetooth,
            batteryPercent: 41,
            destination: DestinationFact(id: "lr", name: "Living Room PC", health: .online),
            surfaces: [.touchpad, .mouse]
        )
        XCTAssertEqual(controllerRow(lent).strip, [.item(RowItems.touchpad), .item(RowItems.mouse)])
        XCTAssertEqual(controllerRow(ControllerFixture.pad(destination: nil)).strip, [.item(RowItems.find)])
        XCTAssertNil(controllerRow(ControllerFixture.pad()).strip, "a bound DualSense streams its own trackpad")
        XCTAssertNil(
            controllerRow(ControllerFixture.pad(destination: nil, supported: false)).strip,
            "nothing to offer a pad Dish cannot read"
        )
    }

    func testAPadDishCannotReadSaysSoAndOpensNothing() {
        let row = controllerRow(ControllerFixture.pad(destination: nil, supported: false))
        XCTAssertEqual(row.destination, .note("Not supported"))
        XCTAssertEqual(row.mark, .dot(DishTheme.muted))
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

    /// A row carries no button: the on-screen controller's page is a row
    /// away, like a pad's.
    func testTheOnScreenControllerIsWordedAndHasItsPage() {
        let row = controllerRow(ControllerFixture.pad(name: "", link: .onScreen, battery: nil))
        XCTAssertEqual(row.name, "On-screen gamepad")
        XCTAssertEqual(row.page, .controller(id: "pad"))
    }

    /// A PC being reached for says so in the link's place, with the spinner
    /// for its mark.
    func testAPCBeingReachedForIsCalledOutInPlaceOfTheLink() {
        let row = controllerRow(ControllerFixture.pad(destination: DestinationFact(name: "Office PC", health: .connecting)))
        XCTAssertEqual(row.destination, .bound(pcName: "Office PC", detail: " · Connecting…"))
        XCTAssertEqual(row.mark, .busy)
    }

    func testALostPCReplacesTheDestinationLine() {
        let row = controllerRow(ControllerFixture.pad(destination: DestinationFact(name: "Living Room PC", health: .lost)))
        XCTAssertEqual(row.destination, .note("Connection lost"))
        XCTAssertEqual(row.mark, .dot(DishTheme.error))
    }

    func testAnUnboundControllerSaysSo() {
        let row = controllerRow(ControllerFixture.pad(destination: nil))
        XCTAssertEqual(row.destination, .note("Not bound"))
        XCTAssertEqual(row.mark, .dot(DishTheme.muted))
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
        controllersPageState(controllers: [ControllerFixture.pad(destination: destination)], apply: apply).rows.first
    }

    /// A bind that waits for its link would read lost; the row says what is
    /// happening instead, and a failed apply is shown there (B6).
    func testAnApplyOnTheRowReplacesItsDestinationLine() {
        let running = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .running(.binding)))
        XCTAssertEqual(running?.destination, .note("Applying binding…"))
        XCTAssertEqual(running?.mark, .busy, "the apply spins")
        let failed = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .failed(.hostUnreachable)))
        XCTAssertEqual(failed?.destination, .note("The PC didn’t answer in time."))
        XCTAssertEqual(failed?.mark, .dot(DishTheme.error))
    }

    func testADoneApplyAndAnotherPadsApplyLeaveTheRowAlone() {
        let done = row(apply: ApplyFact(slotId: "pad", connectionId: "lr", progress: .done))
        XCTAssertEqual(done?.destination, .note("Connection lost"))
        let other = row(apply: ApplyFact(slotId: "other", connectionId: "lr", progress: .failed(.rejected)))
        XCTAssertEqual(other?.destination, .note("Connection lost"))
        XCTAssertEqual(row(apply: nil)?.destination, .note("Connection lost"))
    }

    // MARK: - The long-press menu and the swipes

    func testABoundControllerOffersUnbindInItsMenuAndUnderATrailingSwipe() {
        let actions = controllerRowActions(ControllerFixture.pad(), paired: [RowItems.living])
        XCTAssertEqual(actions, RowActionsState(menu: [.item(RowItems.unbind)], leading: [], trailing: [RowItems.unbind]))
    }

    /// Open gamepad raises the gamepad only once a PC is bound to the
    /// on-screen controller: unbound, it would send nowhere.
    func testTheOnScreenControllerOffersOpenGamepadUnderALeadingSwipeOnceBound() {
        let actions = controllerRowActions(ControllerFixture.pad(name: "", link: .onScreen, battery: nil), paired: [])
        XCTAssertEqual(
            actions,
            RowActionsState(
                menu: [.item(RowItems.openGamepad), .item(RowItems.unbind)],
                leading: [RowItems.openGamepad],
                trailing: [RowItems.unbind]
            )
        )
    }

    /// Bind to is a submenu of the PCs whose link is up, each by its name,
    /// or its address when it never advertised one; a resting PC is not
    /// offered, as Android offers none; there is nothing to swipe.
    func testAnUnboundControllerOffersBindToEachActivePC() {
        let faltering = ConnectionFact(
            id: "office",
            name: "",
            address: "192.168.1.31",
            kind: .satellite,
            state: .unsteady(latencyMs: 40, controllers: 0)
        )
        let actions = controllerRowActions(ControllerFixture.pad(destination: nil), paired: [RowItems.living, faltering, RowItems.nameless])
        let bindTo = RowMenuEntry.submenu(
            title: "Bind to",
            symbol: RowActionSymbol.bind,
            items: [RowItems.bind("lr", "Living Room PC"), RowItems.bind("office", "192.168.1.31")]
        )
        XCTAssertEqual(actions, RowActionsState(menu: [bindTo], leading: [], trailing: []))
    }

    /// With PCs paired but none up there is nothing to bind to: the row
    /// finds a PC, as with none paired.
    func testWithOnlyRestingPCsTheRowFindsAPC() {
        let resting = controllerRowActions(ControllerFixture.pad(destination: nil), paired: [RowItems.nameless])
        XCTAssertEqual(resting, RowActionsState(menu: [.item(RowItems.find)], leading: [], trailing: [RowItems.find]))
        XCTAssertEqual(bindableConnections([RowItems.living, RowItems.nameless]).map(\.id), ["lr"])
        XCTAssertTrue(isBindable(.online(latencyMs: 4, controllers: 1)))
        XCTAssertTrue(isBindable(.unsteady(latencyMs: 40, controllers: 1)))
        XCTAssertFalse(isBindable(.connecting))
        XCTAssertFalse(isBindable(.offline(lastSeen: nil)))
        XCTAssertFalse(isBindable(.needsPairing))
    }

    /// With no PC paired, Find a PC leads to the Connections tab, as
    /// Android's Find hosts does; the unbound on-screen controller has no
    /// Open gamepad to offer beside it.
    func testWithNoPairedPCTheRowFindsAPC() {
        let actions = controllerRowActions(ControllerFixture.pad(destination: nil), paired: [])
        XCTAssertEqual(actions, RowActionsState(menu: [.item(RowItems.find)], leading: [], trailing: [RowItems.find]))
        let onScreen = controllerRowActions(ControllerFixture.pad(name: "", link: .onScreen, battery: nil, destination: nil), paired: [])
        XCTAssertEqual(onScreen, actions)
    }

    /// A pad whose PC is lost offers Reconnect ahead of Unbind, in the menu
    /// and under the trailing swipe.
    func testAPadWhosePCIsLostOffersReconnect() {
        let lost = DestinationFact(id: "lr", name: "Living Room PC", health: .lost)
        let actions = controllerRowActions(ControllerFixture.pad(destination: lost), paired: [RowItems.living])
        XCTAssertEqual(actions, RowActionsState(
            menu: [.item(RowItems.reconnect), .item(RowItems.unbind)],
            leading: [],
            trailing: [RowItems.reconnect, RowItems.unbind]
        ))
    }

    /// The touchpad and the mouse the phone can lend a pad are in its menu,
    /// each over the pad's own slot.
    func testTheScreensThePhoneLendsAPadAreInItsMenu() {
        let lent = ControllerFact(
            id: "pad",
            name: "Xbox Wireless Controller",
            link: .bluetooth,
            batteryPercent: 41,
            destination: DestinationFact(id: "lr", name: "Living Room PC", health: .online),
            surfaces: [.touchpad, .mouse]
        )
        let actions = controllerRowActions(lent, paired: [RowItems.living])
        XCTAssertEqual(actions.menu, [.item(RowItems.touchpad), .item(RowItems.mouse), .item(RowItems.unbind)])
        XCTAssertEqual(actions.leading, [], "the swipes keep to Open gamepad and Unbind")
    }

    func testAPadDishCannotReadOffersNothing() {
        let actions = controllerRowActions(ControllerFixture.pad(destination: nil, supported: false), paired: [RowItems.living])
        XCTAssertEqual(actions, .none)
    }

    func testTheRowsOfferThePagesPairedPCs() {
        let state = controllersPageState(controllers: [ControllerFixture.pad(destination: nil)], paired: [RowItems.living])
        let bindTo = RowMenuEntry.submenu(title: "Bind to", symbol: RowActionSymbol.bind, items: [RowItems.bind("lr", "Living Room PC")])
        XCTAssertEqual(state.rows.first?.actions.menu, [bindTo])
    }

    // MARK: - Hints

    /// The heart's hint waits until a pad is listed, so a new person meets
    /// Add a controller's first; the on-screen controller, always listed,
    /// is no pad.
    func testTheHeartsHintWaitsUntilAPadIsListed() {
        let onScreen = ControllerFixture.pad(name: "", link: .onScreen, battery: nil, destination: nil)
        let empty = controllersPageState(controllers: [onScreen])
        XCTAssertEqual(empty.hints, ControllersHints(support: nil, add: hintState(.addController)))
        let listed = controllersPageState(controllers: [ControllerFixture.pad(), onScreen])
        XCTAssertEqual(listed.hints, ControllersHints(support: hintState(.supportDish), add: hintState(.addController)))
    }

    /// A Lightning iPhone hosts no pad over a plain cable: while nothing is
    /// listed the tab carries the note, and Add a controller's hint names
    /// the adapter. A listed pad got in, and setup's Input step carries the
    /// note from there.
    func testOnALightningIPhoneTheTabWithNoPadCarriesTheNoteAndTheHintNamesTheAdapter() {
        let onScreen = ControllerFixture.pad(name: "", link: .onScreen, battery: nil, destination: nil)
        let noPad = controllersPageState(controllers: [onScreen], port: .lightning)
        XCTAssertEqual(noPad.adapter, adapterNote(port: .lightning))
        XCTAssertEqual(noPad.hints.add, hintState(.addController, port: .lightning))
        XCTAssertNil(controllersPageState(controllers: [onScreen]).adapter, "a USB-C iPhone needs no note")
        XCTAssertNil(controllersPageState(controllers: [ControllerFixture.pad(), onScreen], port: .lightning).adapter)
    }

    func testAPadAttachedToALightningIPhoneIsWordedLightning() {
        let row = controllerRow(ControllerFixture.pad(), port: .lightning)
        XCTAssertEqual(row.destination, .bound(pcName: "Living Room PC", detail: " · Lightning"))
        let bluetooth = controllerRow(ControllerFixture.pad(link: .bluetooth), port: .lightning)
        XCTAssertEqual(bluetooth.destination, .bound(pcName: "Living Room PC", detail: " · Bluetooth"), "Bluetooth is not the port")
    }
}
