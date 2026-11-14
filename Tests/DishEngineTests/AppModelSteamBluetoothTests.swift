// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Steam Controllers over Bluetooth through the model: off on a fresh
/// install with no radio made, on through the Settings intent and remembered,
/// a claimed pad one of the controllers with its trackpads in place of the
/// Touchpad switch, and its pick stored and in force.
@MainActor
final class AppModelSteamBluetoothTests: XCTestCase {

    private static let input2015 = "100F6C33-1735-4313-B402-38567131E5F3"
    private static let input2026 = "100F6C7A-1735-4313-B402-38567131E5F3"
    private static let report = "100F6C34-1735-4313-B402-38567131E5F3"

    private let radios = FakeSteamRadios()
    private let pad = UUID()

    private func model(_ defaults: UserDefaults) -> AppModel {
        let radios = radios
        return AppModel(
            defaults: defaults,
            controllerSource: FakeControllerSource(),
            steamRadio: { radios.make($0, $1) },
            steamClock: ManualSteamClock()
        )
    }

    private func spinUntil(_ predicate: () -> Bool, _ message: String) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, !predicate() {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate(), message)
    }

    private func drain(_ model: AppModel) {
        model.pads.steam.links.queue.sync {}
    }

    /// A pad claimed through SDL's GATT flow, its first value the claim.
    private func claim(_ model: AppModel, inputs: [String], first value: [UInt8]) throws {
        let radio = try XCTUnwrap(radios.last)
        radio.pair([pad])
        radio.say(.poweredOn)
        radio.connected(pad)
        radio.servicesFound(pad)
        radio.characteristicsFound(pad, inputs)
        radio.notify(value, from: pad)
        spinUntil({ model.shellFacts.controllers.contains { $0.id == steamSlotId(pad) } }, "the pad is a controller")
    }

    private func optedIn() throws -> AppModel {
        let model = try model(TestDefaults.fresh(self))
        model.setSteamControllersOverBluetooth(true)
        drain(model)
        return model
    }

    func testAFreshInstallMakesNoRadioAndTheRowReadsOff() throws {
        let model = try model(TestDefaults.fresh(self))
        drain(model)
        XCTAssertEqual(radios.count, 0, "nobody without a Steam Controller is asked for Bluetooth")
        XCTAssertEqual(model.shellFacts.steamBluetooth, .off)
    }

    func testTurningItOnMakesTheRadioWaitsForBluetoothAndIsRemembered() throws {
        let defaults = try TestDefaults.fresh(self)
        let model = model(defaults)
        model.setSteamControllersOverBluetooth(true)
        drain(model)
        XCTAssertEqual(radios.count, 1, "turning it on is what asks iOS for Bluetooth")
        XCTAssertEqual(model.shellFacts.steamBluetooth, .waiting)
        XCTAssertEqual(defaults.object(forKey: "steam_bluetooth_enabled") as? Bool, true)
        try XCTUnwrap(radios.last).say(.poweredOn)
        spinUntil({ model.shellFacts.steamBluetooth == .on }, "Bluetooth's word is the row's")
    }

    func testTurningItOffAgainReadsOffAndIsRemembered() throws {
        let defaults = try TestDefaults.fresh(self)
        let model = model(defaults)
        model.setSteamControllersOverBluetooth(true)
        model.setSteamControllersOverBluetooth(false)
        XCTAssertEqual(model.shellFacts.steamBluetooth, .off)
        XCTAssertEqual(defaults.object(forKey: "steam_bluetooth_enabled") as? Bool, false)
    }

    func testAnOptInFromAnEarlierLaunchMakesTheRadioAtLaunch() throws {
        let defaults = try TestDefaults.fresh(self)
        defaults.set(true, forKey: "steam_bluetooth_enabled")
        let model = model(defaults)
        drain(model)
        XCTAssertEqual(radios.count, 1)
    }

    func testAClaimedPadIsAControllerWithItsTrackpadsInPlaceOfTheTouchpadSwitch() throws {
        let model = try optedIn()
        try claim(model, inputs: [Self.input2015, Self.report], first: SteamBlePacketBytes().buttons(0x80).values[0])
        let fact = try XCTUnwrap(model.shellFacts.controllers.first { $0.id == steamSlotId(pad) })
        XCTAssertEqual(fact.name, "Valve Steam Controller (Bluetooth)")
        XCTAssertEqual(fact.link, .bluetooth)
        XCTAssertNil(fact.batteryPercent, "SDL reads no battery from it")
        XCTAssertEqual(fact.emulateAs, .xboxWireless, "a pad no catalog type names")
        XCTAssertEqual(fact.features.map(\.feature), [.motion], "no motors, and its trackpads are the pick")
        XCTAssertEqual(fact.trackpads, TrackpadsFact(choices: [.stick, .pad, .off], pick: .stick))
        XCTAssertEqual(model.shellFacts.attachedPads.map(\.id), [steamSlotId(pad)], "setup offers it")
        XCTAssertFalse(model.forwardingFlags(slotId: steamSlotId(pad)).touchpad, "the right stick puts nothing on the surface")
    }

    func testThe2026PadsPickDefaultsToTheEmulatedPadsTouchpad() throws {
        let model = try optedIn()
        try claim(model, inputs: [Self.input2026, Self.report], first: TritonReportBytes.state(reportId: 0x45).value)
        let id = steamSlotId(pad)
        XCTAssertEqual(model.shellFacts.controllers.first { $0.id == id }?.trackpads?.pick, .off, "an Xbox pad has no touchpad")
        model.setEmulatedType(slotId: id, .dualSense)
        XCTAssertEqual(model.shellFacts.controllers.first { $0.id == id }?.trackpads?.pick, .pad)
        XCTAssertTrue(model.forwardingFlags(slotId: id).touchpad)
        XCTAssertEqual(model.shellFacts.controllers.first { $0.id == id }?.features.map(\.feature), [.motion, .rumble])
    }

    func testAPickIsStoredInTheWiresWordsAndHeldToTheEmulatedPad() throws {
        let defaults = try TestDefaults.fresh(self)
        let model = model(defaults)
        model.setSteamControllersOverBluetooth(true)
        drain(model)
        try claim(model, inputs: [Self.input2015, Self.report], first: SteamBlePacketBytes().buttons(0x80).values[0])
        let id = steamSlotId(pad)
        model.setTrackpadPick(slotId: id, .pad)
        let stored = try XCTUnwrap(defaults.string(forKey: "touchpad_mode_preferences"))
        XCTAssertEqual(TrackpadPickStore.parse(stored), [id: .pad])
        XCTAssertEqual(model.shellFacts.controllers.first { $0.id == id }?.trackpads?.pick, .off, "an Xbox pad has no surface to land on")
        model.setEmulatedType(slotId: id, .dualShock4)
        XCTAssertEqual(model.shellFacts.controllers.first { $0.id == id }?.trackpads?.pick, .pad)
    }
}
