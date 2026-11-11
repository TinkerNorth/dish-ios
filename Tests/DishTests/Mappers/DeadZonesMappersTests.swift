// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// A controller's Dead zones page: the stick and trigger flats as sliders
/// over the desktops' 0 to 30 percent travel, with their readouts and the
/// reset.
final class DeadZonesMappersTests: XCTestCase {

    private static let pad = ControllerFact(id: "pad", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil)

    private func card(_ zones: [String: DeadzoneSetting] = [:]) throws -> DeadZonesCardState {
        let state = deadZonesPageState(id: "pad", controllers: [Self.pad], zones: zones)
        guard case let .pad(card) = state.content else { throw XCTSkip("the pad is listed, so its card is drawn") }
        return card
    }

    func testAPadNeverTunedReadsTheDefaultsOnBothSliders() throws {
        let card = try card()
        XCTAssertEqual(card.stick, DeadZoneSliderState(label: "Stick dead zone", percent: 10, readout: "10%", maxPercent: 30))
        XCTAssertEqual(card.trigger, DeadZoneSliderState(label: "Trigger dead zone", percent: 5, readout: "5%", maxPercent: 30))
    }

    func testATunedPadReadsItsStoredPercents() throws {
        let tuned = DeadzoneSetting(stickPercent: 20, triggerPercent: 12)
        let card = try card(["pad": tuned])
        XCTAssertEqual(card.stick.percent, 20)
        XCTAssertEqual(card.stick.readout, "20%")
        XCTAssertEqual(card.trigger.percent, 12)
        XCTAssertEqual(card.trigger.readout, "12%")
    }

    func testAnotherPadsTuningIsNotThisPads() throws {
        let card = try card(["elsewhere": DeadzoneSetting(stickPercent: 25, triggerPercent: 25)])
        XCTAssertEqual(card.stick.percent, 10)
    }

    func testThePageIsTitledAndSubtitledAndTheResetNamesThePad() {
        let state = deadZonesPageState(id: "pad", controllers: [Self.pad], zones: [:])
        XCTAssertEqual(state.title, "Dead zones")
        XCTAssertEqual(state.subtitle, "DualSense")
        XCTAssertEqual(state.footnote, "Overrides are stored per device and take effect immediately.")
        guard case let .pad(card) = state.content else { return XCTFail("the pad is listed") }
        XCTAssertEqual(card.reset, "Reset to defaults")
        XCTAssertEqual(card.resetHint, "Reset dead zones for DualSense")
    }

    func testAPadThatLeftShowsItIsGone() {
        let state = deadZonesPageState(id: "gone", controllers: [Self.pad], zones: [:])
        XCTAssertEqual(state.title, "Dead zones")
        XCTAssertEqual(state.subtitle, "")
        XCTAssertEqual(state.content, .gone(message: "This controller isn’t connected to your iPhone."))
    }

    func testAnUnnamedPadIsNamedByItsKind() {
        let onScreen = ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: nil)
        let state = deadZonesPageState(id: "on-screen", controllers: [onScreen], zones: [:])
        XCTAssertEqual(state.subtitle, "On-screen gamepad")
    }
}
