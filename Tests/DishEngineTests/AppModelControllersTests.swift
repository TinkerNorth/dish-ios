// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The bridge's slots become the shell's facts, and the controller page's
/// intents reach the stores and the pads' feeds.
@MainActor
final class AppModelControllersTests: XCTestCase {

    private let dualSense = ControllerSlot(
        id: "gc:Sony:DualSense",
        name: "DualSense Wireless Controller",
        link: .usbC,
        capabilities: ControllerCapabilities(
            hasMotion: true,
            hasTouchpad: true,
            hasRumble: true,
            hasLightbar: true,
            hasBattery: true,
            hasTriggerEffects: true,
            hasPlayerLeds: true
        ),
        battery: BatteryReading(level: 84, state: .charging),
        family: .dualSense
    )

    private let xbox = ControllerSlot(
        id: "gc:Microsoft:Xbox",
        name: "Xbox Wireless Controller",
        capabilities: ControllerCapabilities(hasRumble: true, hasBattery: true),
        family: .xbox
    )

    private let remote = ControllerSlot(id: "gc:Apple:Remote", name: "Siri Remote", readable: false)

    private func model(_ slots: [ControllerSlot]) throws -> (AppModel, FakeControllerSource) {
        let source = FakeControllerSource(slots: slots)
        return try (AppModel(defaults: TestDefaults.fresh(self), controllerSource: source), source)
    }

    func testNoPadNoControllerAndNoAttachedPad() throws {
        let (model, _) = try model([])
        XCTAssertEqual(model.shellFacts.controllers, [])
        XCTAssertEqual(model.shellFacts.attachedPads, [])
    }

    func testEveryListedPadIsAControllerWithTheSwitchesItsHardwareCarries() throws {
        let (model, _) = try model([dualSense, xbox, remote])
        let controllers = model.shellFacts.controllers
        XCTAssertEqual(controllers.map(\.id), [dualSense.id, xbox.id, remote.id])
        let first = try XCTUnwrap(controllers.first)
        XCTAssertEqual(first.name, "DualSense Wireless Controller")
        XCTAssertEqual(first.link, .usbC)
        XCTAssertEqual(first.batteryPercent, 84)
        XCTAssertNil(first.destination, "nothing is bound until the network wave binds it")
        XCTAssertEqual(first.family, .dualSense)
        XCTAssertEqual(first.emulateAs, .dualSense, "the family's own type")
        XCTAssertEqual(first.features.map(\.feature), SlotSwitch.allCases)
        XCTAssertTrue(first.features.allSatisfy(\.enabled))
        XCTAssertEqual(controllers[1].features.map(\.feature), [.rumble])
        XCTAssertEqual(controllers[1].emulateAs, .xboxWireless)
        XCTAssertFalse(controllers[2].supported, "a pad without the extended profile is listed, not read")
    }

    func testSetupIsOfferedTheReadablePadsWithTheirFamilies() throws {
        let (model, _) = try model([dualSense, remote])
        XCTAssertEqual(model.shellFacts.attachedPads, [
            AttachedPadFact(id: dualSense.id, name: dualSense.name, family: .dualSense, link: .usbC, batteryPercent: 84)
        ])
    }

    func testTheFactsFollowTheSourcesSlots() throws {
        let (model, source) = try model([])
        source.slots = [xbox]
        XCTAssertEqual(model.shellFacts.controllers.map(\.id), [xbox.id])
    }

    func testAFlippedSwitchIsTheControllersFactAndItsFlags() throws {
        let (model, _) = try model([dualSense])
        model.setControllerFeature(slotId: dualSense.id, .rumble, enabled: false)
        let rumble = model.shellFacts.controllers.first?.features.first { $0.feature == .rumble }
        XCTAssertEqual(rumble?.enabled, false)
        XCTAssertFalse(model.forwardingFlags(slotId: dualSense.id).rumble)
        XCTAssertTrue(model.forwardingFlags(slotId: dualSense.id).motion)
    }

    func testAnEmulatedTypeIsPickedAndTheFamilysOwnClearsThePick() throws {
        let (model, _) = try model([dualSense])
        model.setEmulatedType(slotId: dualSense.id, .xboxWireless)
        XCTAssertEqual(model.shellFacts.controllers.first?.emulateAs, .xboxWireless)
        XCTAssertEqual(model.pads.types.typeFor(dualSense.id), .xboxWireless)
        model.setEmulatedType(slotId: dualSense.id, .dualSense)
        XCTAssertEqual(model.shellFacts.controllers.first?.emulateAs, .dualSense)
        XCTAssertNil(model.pads.types.typeFor(dualSense.id), "the family's own type is no pick")
    }

    func testTheDeadZonesReachThePadsFeedAsTheyChange() throws {
        let (model, source) = try model([dualSense])
        let recorder = InputRecorder()
        source.processor.route(recorder.route)
        let feed = source.processor.feed(for: dualSense.id)
        model.setStickDeadzone(percent: 30, slotId: dualSense.id)
        feed.publish(GamepadReport(lx: 9000))
        model.resetDeadzones(slotId: dualSense.id)
        feed.publish(GamepadReport(lx: 9000))
        model.setTriggerDeadzone(percent: 30, slotId: dualSense.id)
        feed.publish(GamepadReport(lt: 60))
        XCTAssertEqual(recorder.reports.map(\.report), [GamepadReport(), GamepadReport(lx: 9000), GamepadReport()])
        XCTAssertEqual(model.pads.deadzones.zones(for: dualSense.id).triggerPercent, 30)
    }

    func testStoredDeadZonesReachThePadFromItsFirstReport() throws {
        let defaults = try TestDefaults.fresh(self)
        DeadzonePreferenceStore(defaults: defaults).setZones(DeadzoneSetting(stickFlat: 20000, triggerFlat: 0), for: "pad")
        let source = FakeControllerSource()
        _ = AppModel(defaults: defaults, controllerSource: source)
        let recorder = InputRecorder()
        source.processor.route(recorder.route)
        source.processor.feed(for: "pad").publish(GamepadReport(lx: 15000))
        XCTAssertEqual(recorder.reports.map(\.report.lx), [0])
    }

    func testEachTunedPadsDeadZonesAreFactsAndAResetForgetsThem() throws {
        let (model, _) = try model([dualSense])
        XCTAssertEqual(model.shellFacts.deadzones, [:], "a pad never tuned has no entry, so it reads the defaults")
        model.setStickDeadzone(percent: 20, slotId: dualSense.id)
        model.setTriggerDeadzone(percent: 12, slotId: dualSense.id)
        XCTAssertEqual(model.shellFacts.deadzones[dualSense.id]?.stickPercent, 20)
        XCTAssertEqual(model.shellFacts.deadzones[dualSense.id]?.triggerPercent, 12)
        model.resetDeadzones(slotId: dualSense.id)
        XCTAssertEqual(model.shellFacts.deadzones, [:])
    }

    func testTheGlobalSwitchesAreFactsAndOverrideEveryPadsOwn() throws {
        let (model, _) = try model([dualSense])
        XCTAssertEqual(model.shellFacts.forwarding, ForwardingFlags(), "a fresh install has everything on")
        model.setRumbleForwarded(false)
        model.setTouchpadForwarded(false)
        model.setMotionForwarded(false)
        model.setLightbarMode(.off)
        XCTAssertEqual(
            model.shellFacts.forwarding,
            ForwardingFlags(motion: false, touchpad: false, rumble: false, lightbar: false, triggerEffects: true, playerLeds: true)
        )
        let flags = model.forwardingFlags(slotId: dualSense.id)
        XCTAssertFalse(flags.rumble)
        XCTAssertFalse(flags.touchpad)
        XCTAssertFalse(flags.motion)
        XCTAssertFalse(flags.lightbar)
        XCTAssertTrue(flags.triggerEffects, "the pad's own switch still decides what has no global one")
        model.setRumbleForwarded(true)
        XCTAssertTrue(model.forwardingFlags(slotId: dualSense.id).rumble)
    }

    func testTheGlobalSwitchesAreKeptUnderTheDesktopsKeys() throws {
        let defaults = try TestDefaults.fresh(self)
        let model = AppModel(defaults: defaults, controllerSource: FakeControllerSource())
        model.setRumbleForwarded(false)
        model.setLightbarMode(.off)
        XCTAssertEqual(defaults.object(forKey: "feature_rumble_enabled") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "feature_lightbar_mode"), "off")
    }
}
