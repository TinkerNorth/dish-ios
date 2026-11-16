// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The pads an edit page test draws.
private enum PadFixture {
    static let everySwitch = SlotSwitch.allCases.map { ControllerFeatureFact(feature: $0, enabled: true) }

    static func dualSense(
        emulateAs: EmulatedPad = .dualSense,
        destination: DestinationFact? = nil,
        features: [ControllerFeatureFact] = everySwitch,
        motion: MotionFact = MotionFact(carries: false, status: nil),
        hostEmulation: HostEmulationFact? = nil
    ) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "DualSense",
            link: .usbC,
            batteryPercent: 84,
            destination: destination,
            family: .dualSense,
            emulateAs: emulateAs,
            features: features,
            motion: motion,
            hostEmulation: hostEmulation
        )
    }

    static let onScreen = ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)

    static func page(_ controller: ControllerFact) -> EditControllerPadState? {
        let state = editControllerPageState(controllers: [controller], id: controller.id)
        guard case let .pad(pad) = state.content else { return nil }
        return pad
    }
}

/// Edit controller: what a pad is set to, pushed from its page's Edit.
final class EditControllerMappersTests: XCTestCase {

    func testThePageIsTitledEditControllerAndSubtitledByThePad() {
        let state = editControllerPageState(controllers: [PadFixture.dualSense()], id: "pad")
        XCTAssertEqual(state.title, "Edit controller")
        XCTAssertEqual(state.subtitle, "DualSense")
        XCTAssertEqual(editControllerPageState(controllers: [PadFixture.onScreen], id: "on-screen").subtitle, "On-screen gamepad")
    }

    func testAPadThatLeftShowsItIsGone() {
        let state = editControllerPageState(controllers: [], id: "pad")
        XCTAssertEqual(state.title, "Edit controller")
        XCTAssertEqual(state.subtitle, "", "no pad to name")
        XCTAssertEqual(state.content, .gone(message: "This controller isn’t connected to your iPhone."))
    }

    /// While the PC applies what was just set, the page says Updating.
    func testUpdatingShowsWhileThePCAppliesWhatWasSet() {
        let applying = DestinationFact(name: "Living Room PC", health: .online, updating: true)
        XCTAssertEqual(PadFixture.page(PadFixture.dualSense(destination: applying))?.updating, "Updating…")
        XCTAssertNil(PadFixture.page(PadFixture.dualSense())?.updating)
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
        XCTAssertNil(PadFixture.page(PadFixture.onScreen)?.deadZones)
    }
}
