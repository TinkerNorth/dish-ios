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
        emulateAs: EmulatedPad = .dualSense,
        destination: DestinationFact? = nil,
        features: [ControllerFeatureFact] = everySwitch,
        motion: MotionFact = MotionFact(carries: false, status: nil),
        hostEmulation: HostEmulationFact? = nil
    ) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "DualSense",
            link: link,
            batteryPercent: battery,
            destination: destination,
            family: .dualSense,
            emulateAs: emulateAs,
            features: features,
            motion: motion,
            hostEmulation: hostEmulation
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

    static func pc(_ id: String, _ name: String, state: ConnectionState) -> ConnectionFact {
        ConnectionFact(id: id, name: name, address: "192.168.1.31", kind: .satellite, state: state)
    }

    static func unbind(_ slotId: String) -> RowActionItem<ControllerAction> {
        RowActionItem(action: .unbind(slotId: slotId), title: "Unbind", symbol: RowActionSymbol.unbind, destructive: true)
    }
}

/// The controller page (C1): what the pad is set to, over where it sends,
/// with Unbind at the foot; what it offers to do is its row's.
final class ControllerMappersTests: XCTestCase {

    // MARK: - The page

    func testThePageIsTitledByThePadAndSubtitledByItsBatteryAndLink() {
        let state = controllerPageState(controllers: [PadFixture.dualSense()], id: "pad")
        XCTAssertEqual(state.title, "DualSense")
        XCTAssertEqual(state.subtitle, "84% battery · USB-C")
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
            mark: .dot(DishTheme.muted)
        ))
    }

    func testOnALightningIPhoneAnAttachedPadIsWordedLightning() {
        let state = controllerPageState(controllers: [PadFixture.dualSense()], port: .lightning, id: "pad")
        XCTAssertEqual(state.subtitle, "84% battery · Lightning")
        guard case let .pad(pad) = state.content else { return XCTFail("the pad's page") }
        XCTAssertEqual(pad.status.line, "Lightning · DualSense · 84%")
    }

    func testAPadThatLeftShowsItIsGoneUnderTheGenericTitle() {
        let state = controllerPageState(controllers: [], id: "pad")
        XCTAssertEqual(state.title, "Controller")
        XCTAssertEqual(state.subtitle, "", "no pad, no battery or link to word")
        XCTAssertEqual(state.content, .gone(message: "This controller isn’t connected to your iPhone."))
    }

    func testEachFamilyHasItsWord() {
        XCTAssertEqual(
            PadFamily.allFamilies.map { padFamilyName($0) },
            ["DualSense", "DualShock 4", "Xbox Wireless", "Nintendo", "Controller"]
        )
    }

    // MARK: - Binding and the foot

    func testABoundPadNamesItsPCWithItsMarkAndOffersUnbindAtTheFoot() throws {
        let online = DestinationFact(name: "Living Room PC", health: .online)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: online)))
        XCTAssertEqual(page.binding.title, "Binding")
        XCTAssertEqual(page.binding.destinationTitle, "Destination")
        XCTAssertEqual(page.binding.destination, .bound(pcName: "Living Room PC", mark: .dot(DishTheme.success)))
        XCTAssertNil(page.binding.hint)
        XCTAssertEqual(page.status.mark, .dot(DishTheme.success))
        XCTAssertEqual(page.unbind, PadFixture.unbind("pad"))
    }

    func testAPadWhosePCIsLostWearsTheError() throws {
        let lost = DestinationFact(id: "lr", name: "Living Room PC", health: .lost)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: lost)))
        XCTAssertEqual(page.binding.destination, .bound(pcName: "Living Room PC", mark: .dot(DishTheme.error)))
        XCTAssertEqual(page.status.mark, .dot(DishTheme.error))
    }

    /// A PC being reached for marks the card and the destination with the spinner.
    func testAPCBeingReachedForSpinsOnTheCardAndTheDestination() throws {
        let reaching = DestinationFact(id: "lr", name: "Living Room PC", health: .connecting)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: reaching)))
        XCTAssertEqual(page.status.mark, .busy)
        XCTAssertEqual(page.binding.destination, .bound(pcName: "Living Room PC", mark: .busy))
    }

    /// Unbound, the page says so and offers no Unbind; the destination row
    /// opens the PCs whose link is up; with none up, Find a PC and the footer
    /// says what to do on the Connections tab: connect one, or pair one when
    /// none is paired.
    func testAnUnboundPadPicksAmongTheActivePCsOrFindsOne() throws {
        let living = PadFixture.pc("lr", "Living Room PC", state: .online(latencyMs: 4, controllers: 0))
        let office = PadFixture.pc("office", "", state: .offline(lastSeen: nil))
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(), paired: [living, office]))
        XCTAssertEqual(page.binding.destination, .unbound(note: "Not bound"))
        XCTAssertEqual(
            page.binding.picker,
            .choices([BindChoice(id: "lr", name: "Living Room PC", current: false)]),
            "a resting PC is not offered"
        )
        XCTAssertNil(page.binding.hint)
        XCTAssertNil(page.unbind)
        let resting = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(), paired: [office]))
        XCTAssertEqual(resting.binding.picker, .findPC("Find a PC"))
        XCTAssertEqual(resting.binding.hint, "Connect a PC on the Connections tab to bind this controller.")
        let alone = try XCTUnwrap(PadFixture.page(PadFixture.dualSense()))
        XCTAssertEqual(alone.binding.picker, .findPC("Find a PC"))
        XCTAssertEqual(alone.binding.hint, "Pair a PC on the Connections tab to bind this controller.")
    }

    /// Bound, the destination row still opens the active PCs, the current
    /// one checked, so the pad can be sent elsewhere from here.
    func testABoundPadCanBeSentToAnotherActivePCFromItsPage() throws {
        let living = PadFixture.pc("lr", "Living Room PC", state: .online(latencyMs: 4, controllers: 1))
        let den = PadFixture.pc("den", "Den PC", state: .unsteady(latencyMs: 40, controllers: 0))
        let bound = DestinationFact(id: "lr", name: "Living Room PC", health: .online)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: bound), paired: [living, den]))
        XCTAssertEqual(page.binding.picker, .choices([
            BindChoice(id: "lr", name: "Living Room PC", current: true),
            BindChoice(id: "den", name: "Den PC", current: false)
        ]))
        XCTAssertNil(page.binding.hint)
        let lost = DestinationFact(id: "lr", name: "Living Room PC", health: .lost)
        let alone = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: lost)))
        XCTAssertEqual(alone.binding.picker, .findPC("Find a PC"), "nothing up to send the pad to")
        XCTAssertNil(alone.binding.hint, "the pad is bound; the footer speaks to an unbound one")
    }

    func testTheOnScreenControllerOffersUnbindOnceBound() throws {
        let living = DestinationFact(id: "lr", name: "Living Room PC", health: .online)
        XCTAssertEqual(try XCTUnwrap(PadFixture.page(PadFixture.onScreen(bound: living))).unbind, PadFixture.unbind("on-screen"))
        XCTAssertNil(try XCTUnwrap(PadFixture.page(PadFixture.onScreen(bound: nil))).unbind)
    }

    /// The row's strip offers what its menu does, in the row's order, but
    /// Unbind, which takes the binding away, stands alone at the foot.
    func testTheOffersAreTheRowsMenuWithUnbindApart() {
        let unbind = PadFixture.unbind("pad")
        let touchpad = RowActionItem(
            action: ControllerAction.openSurface(slotId: "pad", screen: .touchpad),
            title: "Open touchpad",
            symbol: "rectangle.and.hand.point.up.left",
            destructive: false
        )
        let reconnect = RowActionItem(
            action: ControllerAction.reconnect(connectionId: "lr"),
            title: "Reconnect",
            symbol: RowActionSymbol.connect,
            destructive: false
        )
        let menu: [RowMenuEntry<ControllerAction>] = [.item(touchpad), .item(reconnect), .item(unbind)]
        let offers = controllerOffers(RowActionsState(menu: menu, leading: [], trailing: [reconnect, unbind]))
        XCTAssertEqual(offers.strip, [.item(touchpad), .item(reconnect)])
        XCTAssertEqual(offers.unbind, unbind)
        let alone = controllerOffers(RowActionsState(menu: [.item(unbind)], leading: [], trailing: [unbind]))
        XCTAssertNil(alone.strip, "nothing but Unbind leaves no strip")
        XCTAssertEqual(alone.unbind, unbind)
        XCTAssertEqual(controllerOffers(.none), ControllerOffers(strip: nil, unbind: nil))
    }

    /// While the PC applies the pad's settings, BINDING says Updating; at
    /// rest it says nothing.
    func testUpdatingShowsWhileThePCAppliesThePadsSettings() throws {
        let applying = DestinationFact(name: "Living Room PC", health: .online, updating: true)
        let page = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: applying)))
        XCTAssertEqual(page.updating, "Updating…")
        let settled = DestinationFact(name: "Living Room PC", health: .online)
        XCTAssertNil(PadFixture.page(PadFixture.dualSense(destination: settled))?.updating)
        XCTAssertNil(PadFixture.page(PadFixture.dualSense())?.updating, "nothing bound, nothing applied")
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

    // MARK: - Emulate as

    func testEmulateAsOffersEveryTypeAndSelectsThePadsPick() throws {
        let emulate = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(emulateAs: .xboxWireless))).emulate
        XCTAssertEqual(emulate.title, "Emulate as")
        XCTAssertEqual(emulate.emulateAs, .xboxWireless)
        XCTAssertEqual(emulate.options.map(\.pad), EmulatedPad.allCases)
        XCTAssertEqual(emulate.options.map(\.name), ["DualSense", "DualShock 4", "Xbox Wireless", "Switch Pro"])
    }

    func testAPadBoundToAHostOffersTheProtocolsFourInPlaceOfDishsPads() throws {
        let hostEmulation = HostEmulationFact(type: Int(MoonlightControllerType.nintendo), isOverride: true)
        let destination = DestinationFact(name: "Study PC", health: .online)
        let controller = PadFixture.dualSense(destination: destination, hostEmulation: hostEmulation)
        let host = try XCTUnwrap(PadFixture.page(controller)?.emulate.host)
        XCTAssertEqual(host.options.map(\.label), ["Auto", "Xbox", "PlayStation", "Nintendo"])
        XCTAssertEqual(host.selection, 3)
        XCTAssertEqual(host.detail, "Dish asks Study PC to plug in this controller. Some hosts override the choice.")
        let auto = HostEmulationFact(type: Int(MoonlightControllerType.auto), isOverride: false)
        let following = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(destination: destination, hostEmulation: auto))?.emulate.host)
        XCTAssertNil(following.selection)
        XCTAssertEqual(following.detail, "Auto sends PlayStation for this controller.", "the DualSense has motion")
        let plain = PadFixture.dualSense(destination: destination, features: [], hostEmulation: auto)
        XCTAssertEqual(
            try XCTUnwrap(PadFixture.page(plain)?.emulate.host).detail,
            "Auto sends Xbox for this controller.",
            "no gyroscope, no PlayStation"
        )
    }

    func testAPadOnASatelliteOrBoundToNoneKeepsDishsFourPads() {
        XCTAssertNil(PadFixture.page(PadFixture.dualSense())?.emulate.host)
        let onSatellite = PadFixture.dualSense(destination: DestinationFact(name: "Den", health: .online))
        XCTAssertNil(PadFixture.page(onSatellite)?.emulate.host)
    }

    // MARK: - Functions

    func testFunctionsListTheSwitchesThePadHasInTheBoardsOrder() throws {
        let functions = try XCTUnwrap(PadFixture.page(PadFixture.dualSense())?.functions)
        XCTAssertEqual(functions.title, "Functions")
        XCTAssertEqual(functions.rows.map(\.title), ["Motion", "Rumble", "Adaptive triggers", "Light bar", "Player LEDs", "Touchpad"])
        XCTAssertEqual(functions.rows.map(\.feature), SlotSwitch.allCases)
        XCTAssertTrue(functions.rows.allSatisfy(\.isOn))
        XCTAssertEqual(Set(functions.rows.map(\.symbol)).count, functions.rows.count, "each switch has its own glyph")
    }

    func testOnlyTheMotionRowCarriesTheSatellitesWord() throws {
        let functions = try XCTUnwrap(PadFixture.page(PadFixture.dualSense())?.functions)
        XCTAssertNotNil(functions.rows.first { $0.feature == .motion }?.status)
        XCTAssertTrue(functions.rows.filter { $0.feature != .motion }.allSatisfy { $0.status == nil })
    }

    func testTheMotionRowReadsEachStateOfTheGyroChipAndOnlyTheSatellitesFaultsWarn() throws {
        func status(_ motion: MotionFact, on: Bool = true, features: [ControllerFeatureFact]? = nil) throws -> MotionRowStatus {
            let all = features ?? [ControllerFeatureFact(feature: .motion, enabled: on)]
            let controller = PadFixture.dualSense(features: all, motion: motion)
            let rows = try XCTUnwrap(PadFixture.page(controller)?.functions).rows
            return try XCTUnwrap(rows.first { $0.feature == .motion }?.status)
        }
        let sinks = MotionBackendStatus(sinkSupportedForType: true, backendOk: true)
        XCTAssertEqual(try status(MotionFact(carries: true, status: sinks)), MotionRowStatus(text: "Motion: streaming", warns: false))
        XCTAssertEqual(try status(MotionFact(carries: true, status: nil)).text, "Motion: streaming", "no word yet reads as fine")
        XCTAssertEqual(try status(MotionFact(carries: false, status: nil)), MotionRowStatus(text: "Motion: not sent", warns: false))
        XCTAssertEqual(try status(MotionFact(carries: true, status: sinks), on: false).text, "Motion: turned off")
        let noSink = MotionBackendStatus(sinkSupportedForType: false, backendOk: true)
        XCTAssertEqual(
            try status(MotionFact(carries: true, status: noSink)),
            MotionRowStatus(text: "Motion: host can’t receive", warns: true)
        )
        let broken = MotionBackendStatus(sinkSupportedForType: true, backendOk: false)
        XCTAssertEqual(
            try status(MotionFact(carries: true, status: broken)),
            MotionRowStatus(text: "Motion: server can’t deliver", warns: true)
        )
    }

    func testEveryMotionIndicatorStateHasItsLine() {
        let lines = [MotionIndicatorState.unavailable, .userDisabled, .notForwarded, .noHostSink, .backendBroken, .forwarding]
            .map { motionRowStatus($0).text }
        XCTAssertEqual(Set(lines).count, 6)
        XCTAssertEqual(motionRowStatus(.unavailable).text, "Motion: no gyroscope")
        XCTAssertFalse(motionRowStatus(.unavailable).warns)
    }

    func testASwitchTheUserTurnedOffReadsOffAndAMissingOneIsLeftOut() throws {
        let features = [ControllerFeatureFact(feature: .rumble, enabled: false)]
        let functions = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(features: features))?.functions)
        XCTAssertEqual(functions.rows.map(\.feature), [.rumble])
        XCTAssertEqual(functions.rows.map(\.isOn), [false])
    }

    func testAPadWithNoSwitchesHasNoFunctionsSection() {
        XCTAssertNil(PadFixture.page(PadFixture.dualSense(features: []))?.functions)
    }

    func testTheFootnoteSaysWhyTheMicrophoneAndSpeakerAreMissing() throws {
        let pad = try XCTUnwrap(PadFixture.page(PadFixture.dualSense()))
        XCTAssertEqual(pad.footnote, "Microphone and controller speaker aren’t open to apps on iOS, so Dish leaves them out.")
    }

    // MARK: - Dead zones

    func testAPadOffersItsDeadZonesPage() {
        XCTAssertEqual(PadFixture.page(PadFixture.dualSense())?.deadZones, "Dead zones")
    }

    func testTheOnScreenGamepadHasNoDeadZonesToTune() {
        XCTAssertNil(PadFixture.page(PadFixture.onScreen(bound: nil))?.deadZones)
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
