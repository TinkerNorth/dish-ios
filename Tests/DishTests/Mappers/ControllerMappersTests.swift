// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The pads a controller page test draws.
private enum PadFixture {
    static let everySwitch = SlotSwitch.allCases.map { ControllerFeatureFact(feature: $0, enabled: true) }

    static func dualSense(
        link: ControllerLink = .usbC,
        battery: Int? = 84,
        destination: DestinationFact? = nil,
        features: [ControllerFeatureFact] = everySwitch
    ) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "DualSense",
            link: link,
            batteryPercent: battery,
            destination: destination,
            family: .dualSense,
            emulateAs: .dualSense,
            features: features
        )
    }

    static func onScreen(bound destination: DestinationFact?) -> ControllerFact {
        ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: destination)
    }

    static func page(_ controller: ControllerFact, paired: [ConnectionFact] = [], pads: [PadDiagnostics] = []) -> ControllerPadState? {
        let state = controllerPageState(controllers: [controller], paired: paired, pads: pads, id: controller.id)
        guard case let .pad(pad) = state.content else { return nil }
        return pad
    }

    /// What the Diagnostics source read for the pad: its rates and how many reports it has sent.
    static func reading(of controller: ControllerFact, rates: PadRates, reports: UInt64 = 100) -> PadDiagnostics {
        PadDiagnostics(controller: controller, rates: rates, reports: reports, wire: nil)
    }
}

/// The paired PCs and the items the tests expect in the strip.
private enum StripItems {
    static let living = ConnectionFact(
        id: "lr",
        name: "Living Room PC",
        address: "192.168.1.24",
        kind: .satellite,
        state: .offline(lastSeen: nil)
    )
    static let openGamepad = RowActionItem(
        action: ControllerAction.openGamepad,
        title: "Open gamepad",
        symbol: RowActionSymbol.open,
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
        symbol: "cursorarrow",
        destructive: false
    )
    static let reconnect = RowActionItem(
        action: ControllerAction.reconnect(connectionId: "lr"),
        title: "Reconnect",
        symbol: RowActionSymbol.connect,
        destructive: false
    )
    static let find = RowActionItem(action: ControllerAction.findPC, title: "Find a PC", symbol: RowActionSymbol.pair, destructive: false)

    static func unbind(_ slotId: String) -> RowActionItem<ControllerAction> {
        RowActionItem(action: .unbind(slotId: slotId), title: "Unbind", symbol: RowActionSymbol.unbind, destructive: true)
    }

    static func bind(_ connectionId: String, _ name: String) -> RowActionItem<ControllerAction> {
        RowActionItem(
            action: .bind(slotId: "pad", connectionId: connectionId),
            title: name,
            symbol: "antenna.radiowaves.left.and.right",
            destructive: false
        )
    }
}

/// The controller page (C1): the pad's info page, with its strip of actions
/// under the card, BINDING, TELEMETRY, Unbind at the foot and Edit on the
/// toolbar.
final class ControllerMappersTests: XCTestCase {

    // MARK: - The page

    func testThePageIsTitledByThePadAndSubtitledByItsBatteryAndLinkWithEditOnTheToolbar() {
        let state = controllerPageState(controllers: [PadFixture.dualSense()], id: "pad")
        XCTAssertEqual(state.title, "DualSense")
        XCTAssertEqual(state.subtitle, "84% battery · USB-C")
        XCTAssertEqual(state.edit, "Edit")
        let noBattery = controllerPageState(controllers: [PadFixture.dualSense(link: .bluetooth, battery: nil)], id: "pad")
        XCTAssertEqual(noBattery.subtitle, "Bluetooth", "a pad that reports no level shows its link alone")
    }

    func testTheOnScreenControllersPageIsWorded() {
        let state = controllerPageState(controllers: [PadFixture.onScreen(bound: nil)], id: "on-screen")
        XCTAssertEqual(state.title, "On-screen gamepad")
        XCTAssertEqual(state.subtitle, "On-screen")
    }

    func testTheStatusCardNamesThePadItsLinkItsFamilyAndItsBattery() throws {
        let pad = try XCTUnwrap(PadFixture.page(PadFixture.dualSense()))
        XCTAssertEqual(pad.status, ControllerStatusState(
            symbol: "gamecontroller",
            title: "DualSense",
            line: "USB-C · DualSense · 84%",
            dot: DishTheme.muted
        ))
    }

    func testOnALightningIPhoneAnAttachedPadIsWordedLightning() {
        let state = controllerPageState(controllers: [PadFixture.dualSense()], port: .lightning, id: "pad")
        XCTAssertEqual(state.subtitle, "84% battery · Lightning")
        guard case let .pad(pad) = state.content else { return XCTFail("the pad's page") }
        XCTAssertEqual(pad.status.line, "Lightning · DualSense · 84%")
    }

    func testAPadThatLeftShowsItIsGoneUnderTheGenericTitleWithNothingToEdit() {
        let state = controllerPageState(controllers: [], id: "pad")
        XCTAssertEqual(state.title, "Controller")
        XCTAssertEqual(state.subtitle, "", "no pad, no battery or link to word")
        XCTAssertEqual(state.content, .gone(message: "This controller isn’t connected to your iPhone."))
        XCTAssertNil(state.edit)
    }

    func testEachFamilyHasItsWord() {
        XCTAssertEqual(
            PadFamily.allFamilies.map { padFamilyName($0) },
            ["DualSense", "DualShock 4", "Xbox Wireless", "Nintendo", "Controller"]
        )
    }

    // MARK: - The strip and the foot

    /// Open gamepad is in the strip only once a PC is bound to the on-screen
    /// controller: unbound, it would send nowhere.
    func testTheOnScreenControllerOffersOpenGamepadInItsStripOnceBound() throws {
        let living = DestinationFact(id: "lr", name: "Living Room PC", health: .online)
        let bound = try XCTUnwrap(PadFixture.page(PadFixture.onScreen(bound: living)))
        XCTAssertEqual(bound.actions.strip, [.item(StripItems.openGamepad)])
        XCTAssertEqual(bound.actions.unbind, StripItems.unbind("on-screen"))
        let unbound = try XCTUnwrap(PadFixture.page(PadFixture.onScreen(bound: nil)))
        XCTAssertEqual(unbound.actions.strip, [.item(StripItems.find)], "nothing to send to yet, and nothing paired to bind to")
        XCTAssertNil(unbound.actions.unbind)
    }

    /// A pad with no touchpad of its own, bound to a satellite that grants
    /// the mouse, gets the phone's touchpad and mouse in its strip, each
    /// over the pad's own slot.
    func testTheScreensThePhoneLendsAPadAreInItsStrip() throws {
        let lent = ControllerFact(
            id: "pad",
            name: "Xbox Wireless Controller",
            link: .bluetooth,
            batteryPercent: 41,
            destination: DestinationFact(id: "lr", name: "Living Room PC", health: .online),
            family: .xbox,
            surfaces: [.touchpad, .mouse]
        )
        let page = try XCTUnwrap(PadFixture.page(lent))
        XCTAssertEqual(page.actions.strip, [.item(StripItems.touchpad), .item(StripItems.mouse)])
        XCTAssertEqual(page.actions.unbind, StripItems.unbind("pad"))
    }

    /// A bound pad whose PC answers and lends it nothing has no strip: the
    /// card, BINDING and Unbind at the foot are its page.
    func testABoundPadWithNothingToOpenHasNoStripAndUnbindAtTheFoot() throws {
        let online = DestinationFact(name: "Living Room PC", health: .online)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: online)))
        XCTAssertNil(page.actions.strip, "a DualSense streams its own trackpad, and the gamepad is the on-screen controller's")
        XCTAssertEqual(page.actions.unbind, StripItems.unbind("pad"))
        XCTAssertEqual(page.binding.destination, .bound(pcName: "Living Room PC", dot: DishTheme.success))
        XCTAssertNil(page.binding.hint)
        XCTAssertEqual(page.status.dot, DishTheme.success)
    }

    func testAPadWhosePCIsLostOffersReconnectInItsStrip() throws {
        let lost = DestinationFact(id: "lr", name: "Living Room PC", health: .lost)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: lost)))
        XCTAssertEqual(page.actions.strip, [.item(StripItems.reconnect)])
        XCTAssertEqual(page.actions.unbind, StripItems.unbind("pad"))
        XCTAssertEqual(page.binding.destination, .bound(pcName: "Living Room PC", dot: DishTheme.error))
        XCTAssertEqual(page.status.dot, DishTheme.error)
    }

    /// Bind to is a menu of the paired PCs, each by its name, or its address
    /// when it never advertised one.
    func testAnUnboundPadOffersBindToEachPairedPCInItsStrip() throws {
        let office = ConnectionFact(id: "office", name: "", address: "192.168.1.31", kind: .satellite, state: .needsPairing)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(), paired: [StripItems.living, office]))
        let bindTo = RowMenuEntry.submenu(
            title: "Bind to",
            symbol: RowActionSymbol.bind,
            items: [StripItems.bind("lr", "Living Room PC"), StripItems.bind("office", "192.168.1.31")]
        )
        XCTAssertEqual(page.actions.strip, [bindTo])
        XCTAssertNil(page.actions.unbind)
        XCTAssertEqual(page.binding.title, "Binding")
        XCTAssertEqual(page.binding.destinationTitle, "Destination")
        XCTAssertEqual(page.binding.destination, .unbound(note: "Not bound"))
        XCTAssertNil(page.binding.hint, "there is a PC to bind to")
    }

    /// With no PC paired there is nothing to bind to: Find a PC leads to the
    /// Connections tab, as Android's Find hosts does, and the footer says why.
    func testWithNoPairedPCTheStripFindsAPCAndTheFooterSaysWhy() throws {
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense()))
        XCTAssertEqual(page.actions.strip, [.item(StripItems.find)])
        XCTAssertEqual(page.binding.destination, .unbound(note: "Not bound"))
        XCTAssertEqual(page.binding.hint, "Pair a PC on the Connections tab to bind this controller.")
    }

    /// The page offers what the row's menu does, in the row's order, but
    /// Unbind, which takes the binding away, stands alone at the foot.
    func testThePageDrawsTheRowsMenuAsItsStripWithUnbindAtTheFoot() {
        let unbind = StripItems.unbind("pad")
        let menu: [RowMenuEntry<ControllerAction>] = [.item(StripItems.touchpad), .item(StripItems.reconnect), .item(unbind)]
        let actions = controllerPageActions(RowActionsState(menu: menu, leading: [], trailing: [StripItems.reconnect, unbind]))
        XCTAssertEqual(actions.strip, [.item(StripItems.touchpad), .item(StripItems.reconnect)])
        XCTAssertEqual(actions.unbind, unbind)
        let alone = controllerPageActions(RowActionsState(menu: [.item(unbind)], leading: [], trailing: [unbind]))
        XCTAssertNil(alone.strip, "nothing but Unbind leaves no strip")
        XCTAssertEqual(alone.unbind, unbind)
        XCTAssertEqual(controllerPageActions(.none), ControllerPageActions(strip: nil, unbind: nil))
    }

    // MARK: - The apply

    private func apply(_ progress: ApplyProgress, slotId: String = "pad") -> ApplyRowState? {
        let fact = ApplyFact(slotId: slotId, connectionId: "lr", progress: progress)
        let state = controllerPageState(controllers: [PadFixture.dualSense()], apply: fact, id: "pad")
        guard case let .pad(pad) = state.content else { return nil }
        return pad.apply
    }

    func testTheApplyIsDrawnInlineWhileItRunsAndWhenItEnds() {
        let applying = ApplyRowState(text: "Applying binding…", color: DishTheme.muted, spinner: true, retry: nil, connectionId: "lr")
        XCTAssertEqual(apply(.running(.binding)), applying)
        XCTAssertEqual(apply(.running(.applyingOnHost)), applying)
        XCTAssertEqual(
            apply(.done),
            ApplyRowState(text: "Binding applied", color: DishTheme.success, spinner: false, retry: nil, connectionId: "lr")
        )
        XCTAssertEqual(
            apply(.failed(.rejected)),
            ApplyRowState(
                text: "The PC refused the controller.",
                color: DishTheme.error,
                spinner: false,
                retry: "Try again",
                connectionId: "lr"
            )
        )
        XCTAssertNil(apply(.idle), "nothing in flight")
        XCTAssertNil(apply(.done, slotId: "other"), "another pad's apply")
    }

    func testEachApplyFailureHasItsWords() {
        XCTAssertEqual(apply(.failed(.hostUnreachable))?.text, "The PC didn’t answer in time.")
        XCTAssertEqual(apply(.failed(.padGone))?.text, "The controller left before the binding was applied.")
        XCTAssertEqual(apply(.failed(.cancelled))?.text, "Binding cancelled.")
        XCTAssertEqual(apply(.failed(.padGone))?.retry, "Try again")
    }

    // MARK: - Telemetry

    func testTelemetryNamesTheReportMotionAndTouchRatesOfAPadThatReports() throws {
        let pad = PadFixture.dualSense()
        let reading = PadFixture.reading(of: pad, rates: PadRates(reportHz: 500, motionHz: 250, touchHz: 120))
        let telemetry = try XCTUnwrap(PadFixture.page(pad, pads: [reading])?.telemetry)
        XCTAssertEqual(telemetry.title, "Telemetry")
        XCTAssertEqual(telemetry.rows, [
            TelemetryRowState(id: "gamepad", label: "Gamepad", value: "500 Hz"),
            TelemetryRowState(id: "motion", label: "Motion", value: "250 Hz"),
            TelemetryRowState(id: "touch", label: "Touch", value: "120 Hz")
        ])
    }

    func testTelemetryLeavesOutTheStreamsAPadHasNoHardwareFor() throws {
        let xbox = PadFixture.dualSense(features: [ControllerFeatureFact(feature: .rumble, enabled: true)])
        let reading = PadFixture.reading(of: xbox, rates: PadRates(reportHz: 125, motionHz: 0, touchHz: 0))
        let telemetry = try XCTUnwrap(PadFixture.page(xbox, pads: [reading])?.telemetry)
        XCTAssertEqual(telemetry.rows.map(\.label), ["Gamepad"])
        XCTAssertEqual(telemetry.rows.map(\.value), ["125 Hz"])
    }

    func testTelemetryIsDrawnOnlyForAPadThatHasReported() {
        let pad = PadFixture.dualSense()
        XCTAssertNil(PadFixture.page(pad)?.telemetry, "nothing read for the pad yet")
        let silent = PadFixture.reading(of: pad, rates: PadRates(reportHz: 0, motionHz: 0), reports: 0)
        XCTAssertNil(PadFixture.page(pad, pads: [silent])?.telemetry, "a pad with no report has no rate to show")
        let other = PadFixture.reading(
            of: ControllerFact(id: "else", name: "x", link: .usbC, batteryPercent: nil, destination: nil),
            rates: PadRates(reportHz: 9, motionHz: 0)
        )
        XCTAssertNil(PadFixture.page(pad, pads: [other])?.telemetry, "another pad's rates are not this pad's")
    }

    func testTheOnScreenGamepadShowsItsTelemetryToo() throws {
        let onScreen = PadFixture.onScreen(bound: nil)
        let reading = PadFixture.reading(of: onScreen, rates: PadRates(reportHz: 60, motionHz: 0))
        let telemetry = try XCTUnwrap(PadFixture.page(onScreen, pads: [reading])?.telemetry)
        XCTAssertEqual(telemetry.rows.map(\.value), ["60 Hz"])
    }
}

private extension PadFamily {
    static let allFamilies: [PadFamily] = [.dualSense, .dualShock4, .xbox, .nintendo, .other]
}
