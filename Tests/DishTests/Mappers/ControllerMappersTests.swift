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
        features: [ControllerFeatureFact] = everySwitch
    ) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "DualSense",
            link: link,
            batteryPercent: battery,
            destination: nil,
            family: .dualSense,
            emulateAs: emulateAs,
            features: features
        )
    }

    static func page(_ controller: ControllerFact) -> ControllerPadState? {
        guard case let .pad(state) = controllerPageState(controllers: [controller], id: controller.id).content else { return nil }
        return state
    }
}

/// The controller page (C1) without its PC half: the status card, the
/// binding, the pad's switches and why two of them are missing.
final class ControllerMappersTests: XCTestCase {

    func testTheOnScreenControllersPageIsWordedAndOffersOpen() throws {
        let onScreen = ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)
        let state = controllerPageState(controllers: [onScreen], id: "on-screen")
        XCTAssertEqual(state.title, "On-screen gamepad")
        XCTAssertEqual(state.subtitle, "On-screen")
        let page = try XCTUnwrap(PadFixture.page(onScreen))
        XCTAssertEqual(page.open, "Open")
        XCTAssertNil(PadFixture.page(PadFixture.dualSense())?.open, "a pad has no screen to open")
    }

    func testThePageIsTitledByThePadAndSubtitledByItsBatteryAndLink() {
        let state = controllerPageState(controllers: [PadFixture.dualSense()], id: "pad")
        XCTAssertEqual(state.title, "DualSense")
        XCTAssertEqual(state.subtitle, "84% battery · USB-C")
        let noBattery = controllerPageState(controllers: [PadFixture.dualSense(link: .bluetooth, battery: nil)], id: "pad")
        XCTAssertEqual(noBattery.subtitle, "Bluetooth", "a pad that reports no level shows its link alone")
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

    func testTheDestinationIsNotBoundAndCannotBeOpenedYet() throws {
        let binding = try XCTUnwrap(PadFixture.page(PadFixture.dualSense())).binding
        XCTAssertEqual(binding.title, "Binding")
        XCTAssertEqual(binding.destinationTitle, "Destination")
        XCTAssertEqual(binding.destination, "Not bound")
        XCTAssertFalse(binding.destinationEnabled)
    }

    func testEmulateAsOffersEveryTypeAndSelectsThePadsPick() throws {
        let binding = try XCTUnwrap(PadFixture.page(PadFixture.dualSense(emulateAs: .xboxWireless))).binding
        XCTAssertEqual(binding.emulateTitle, "Emulate as")
        XCTAssertEqual(binding.emulateAs, .xboxWireless)
        XCTAssertEqual(binding.emulateOptions.map(\.pad), EmulatedPad.allCases)
        XCTAssertEqual(binding.emulateOptions.map(\.name), ["DualSense", "DualShock 4", "Xbox Wireless", "Switch Pro"])
    }

    func testFunctionsListTheSwitchesThePadHasInTheBoardsOrder() throws {
        let functions = try XCTUnwrap(PadFixture.page(PadFixture.dualSense())?.functions)
        XCTAssertEqual(functions.title, "Functions")
        XCTAssertEqual(functions.rows.map(\.title), ["Motion", "Rumble", "Adaptive triggers", "Light bar", "Player LEDs", "Touchpad"])
        XCTAssertEqual(functions.rows.map(\.feature), SlotSwitch.allCases)
        XCTAssertTrue(functions.rows.allSatisfy(\.isOn))
        XCTAssertEqual(Set(functions.rows.map(\.symbol)).count, functions.rows.count, "each switch has its own glyph")
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
}

private extension PadFamily {
    static let allFamilies: [PadFamily] = [.dualSense, .dualShock4, .xbox, .nintendo, .other]
}
