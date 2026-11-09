// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import GameController
import XCTest
@testable import DishEngine

/// The bridge over GameController's own snapshot pad, which holds values the
/// test sets and attaches like a real one: the sample is taken in the
/// framework's orientation, a connect hands the pad its own input queue
/// before any handler, and the handlers run there, off the main thread.
@MainActor
final class GameControllerInputTests: XCTestCase {

    private func snapshotPad() throws -> (GCController, GCExtendedGamepad) {
        let controller = GCController.withExtendedGamepad()
        return try (controller, XCTUnwrap(controller.extendedGamepad))
    }

    private func input(connected: [GCController] = [], center: NotificationCenter = NotificationCenter()) -> GameControllerInput {
        GameControllerInput(connected: connected, center: center, batteryTicker: ManualTicker())
    }

    private func spinUntil(_ predicate: () -> Bool, message: String) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, !predicate() {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate(), message)
    }

    func testAStickPushedUpIsSampledUpAndTheHomeButtonIsGuide() throws {
        let (_, pad) = try snapshotPad()
        pad.leftThumbstick.setValueForXAxis(-1, yAxis: 1)
        pad.rightThumbstick.setValueForXAxis(1, yAxis: -1)
        pad.buttonHome?.setValue(1)
        pad.buttonA.setValue(1)
        pad.leftTrigger.setValue(1)
        let sample = GameControllerInput.padSample(pad)
        let report = wireReport(sample)
        XCTAssertEqual(sample.pressed, [.guide, .faceA], "the sample's word holds exactly the held buttons")
        XCTAssertEqual(report.ly, 32767, "up on the pad is up on the wire")
        XCTAssertEqual(report.ry, -32767)
        XCTAssertEqual(report.lx, -32767)
        XCTAssertEqual(report.rx, 32767)
        XCTAssertEqual(report.lt, 255)
        XCTAssertEqual(report.buttons, WireButton.guide.bit | WireButton.faceA.bit)
    }

    func testEveryButtonOfThePadSetsItsWireBit() throws {
        let (_, pad) = try snapshotPad()
        let buttons: [(GCControllerButtonInput?, WireButton)] = [
            (pad.buttonA, .faceA), (pad.buttonB, .faceB), (pad.buttonX, .faceX), (pad.buttonY, .faceY),
            (pad.leftShoulder, .leftShoulder), (pad.rightShoulder, .rightShoulder), (pad.buttonMenu, .start), (pad.buttonOptions, .back), (
                pad.leftThumbstickButton,
                .leftThumb
            ), (pad.rightThumbstickButton, .rightThumb)
        ]
        for (input, button) in buttons {
            let held = try XCTUnwrap(input, "the snapshot pad has \(button)")
            held.setValue(1)
            XCTAssertEqual(GameControllerInput.heldButtons(pad), [button], "\(button) alone")
            held.setValue(0)
        }
        let directions: [(Float, Float, WireButton)] = [(0, 1, .dpadUp), (0, -1, .dpadDown), (-1, 0, .dpadLeft), (1, 0, .dpadRight)]
        for (x, y, button) in directions {
            pad.dpad.setValueForXAxis(x, yAxis: y)
            XCTAssertEqual(GameControllerInput.heldButtons(pad), [button], "\(button) alone")
        }
    }

    func testALaunchSweepListsThePadWithItsFamilyAndCapabilities() throws {
        XCTAssertTrue(input().slots.isEmpty, "no pad, no slot")
        let (controller, _) = try snapshotPad()
        let input = input(connected: [controller])
        let slot = try XCTUnwrap(input.slots.first)
        XCTAssertEqual(input.slots.count, 1)
        XCTAssertEqual(slot.id, input.slotId(for: controller))
        XCTAssertEqual(slot.name, controller.vendorName ?? controller.productCategory)
        XCTAssertTrue(slot.readable)
        XCTAssertEqual(slot.link, .bluetooth, "a snapshot pad is not attached to the device")
        XCTAssertFalse(slot.capabilities.hasTriggerEffects, "only a DualSense takes trigger effects")
    }

    func testAConnectHandsThePadItsInputQueueAndADisconnectLetsItGo() throws {
        let center = NotificationCenter()
        let input = input(center: center)
        let (controller, pad) = try snapshotPad()
        center.post(name: .GCControllerDidConnect, object: controller)
        spinUntil({ !input.slots.isEmpty }, message: "the connect attaches the pad")
        let queue = input.handlerQueue(for: input.slotId(for: controller))
        XCTAssertTrue(controller.handlerQueue === queue)
        XCTAssertEqual(queue.label, "com.tinkernorth.dish.input.\(input.slotId(for: controller))")
        XCTAssertEqual(controller.handlerQueue.qos, .userInteractive)
        XCTAssertNotNil(pad.valueChangedHandler)
        center.post(name: .GCControllerDidDisconnect, object: controller)
        spinUntil({ input.slots.isEmpty }, message: "the disconnect detaches it")
        XCTAssertNil(pad.valueChangedHandler, "a gone pad's handler is cleared")
    }

    /// The handler is the framework's to call on the pad's queue; called
    /// here as the framework calls it, it publishes the pad whole.
    func testTheReportHandlerPublishesThePadThroughItsFeed() throws {
        let (controller, pad) = try snapshotPad()
        let input = input(connected: [controller])
        let recorder = InputRecorder()
        input.processor.route(recorder.route)
        pad.leftThumbstick.setValueForXAxis(0, yAxis: 1)
        controller.handlerQueue.sync { pad.valueChangedHandler?(pad, pad.leftThumbstick) }
        XCTAssertEqual(recorder.reports.map(\.report.ly), [32767])
    }

    /// The framework calls a pad's handler for every element that moves:
    /// replayed, the same mapped report over and over goes out once, and
    /// each change goes out once.
    func testAReplayedHandlerSequencePublishesOnlyTheChanges() throws {
        let (controller, pad) = try snapshotPad()
        let input = input(connected: [controller])
        let recorder = InputRecorder()
        input.processor.route(recorder.route)
        input.processor.setDeadzones(deviceId: input.slotId(for: controller), GamepadInputProcessor.Deadzones())
        for leftY: Float in [1, 1, 1, 0, 0, 1] {
            pad.leftThumbstick.setValueForXAxis(0, yAxis: leftY)
            controller.handlerQueue.sync { pad.valueChangedHandler?(pad, pad.leftThumbstick) }
        }
        XCTAssertEqual(recorder.reports.map(\.report.ly), [32767, 0, 32767], "three changes, three reports")
    }

    func testEachControllerGetsAQueueOfItsOwnKeptAcrossAReattach() throws {
        let (first, _) = try snapshotPad()
        let (second, _) = try snapshotPad()
        let input = input(connected: [first, second])
        XCTAssertFalse(first.handlerQueue === second.handlerQueue, "two pads, two queues, so neither waits for the other")
        XCTAssertEqual(input.slots.count, 2, "two identical pads, two slots")
        let queue = first.handlerQueue
        input.attach(first)
        XCTAssertTrue(first.handlerQueue === queue, "a re-attach keeps the pad's queue, so its feed keeps one thread")
        XCTAssertEqual(input.slots.count, 2, "a re-attach replaces the slot, never adds one")
    }

    // MARK: - Identity and family

    func testTwoIdenticalPadsTakeTheLowestFreeOrdinal() {
        XCTAssertEqual(lowestFreeSlotId(base: "gc:x:y", taken: []), "gc:x:y")
        XCTAssertEqual(lowestFreeSlotId(base: "gc:x:y", taken: ["gc:x:y"]), "gc:x:y#1")
        XCTAssertEqual(lowestFreeSlotId(base: "gc:x:y", taken: ["gc:x:y", "gc:x:y#1"]), "gc:x:y#2")
    }

    func testTheNameInASlotIdIsItsVendorOrItsCategory() {
        XCTAssertEqual(padName(fromSlotId: "gc:Xbox Wireless Controller:Xbox One"), "Xbox Wireless Controller")
        XCTAssertEqual(padName(fromSlotId: "gc:DualSense Wireless Controller:DualSense#1"), "DualSense Wireless Controller")
        XCTAssertEqual(
            padName(fromSlotId: "gc:unknown:Nintendo Switch Online N64#2"),
            "Nintendo Switch Online N64",
            "no vendor: the category"
        )
        XCTAssertEqual(padName(fromSlotId: "pad"), "pad", "an id of another shape is its own name")
    }

    func testTheProductCategoryPicksTheFamilyAndTheFamilyItsEmulation() {
        XCTAssertEqual(padFamily(productCategory: GCProductCategoryDualSense, vendorName: nil), .dualSense)
        XCTAssertEqual(padFamily(productCategory: GCProductCategoryDualShock4, vendorName: nil), .dualShock4)
        XCTAssertEqual(padFamily(productCategory: GCProductCategoryXboxOne, vendorName: nil), .xbox)
        XCTAssertEqual(padFamily(productCategory: "Switch Pro Controller", vendorName: nil), .nintendo)
        XCTAssertEqual(padFamily(productCategory: GCProductCategoryMFi, vendorName: "Backbone One"), .other)
        XCTAssertEqual(PadFamily.nintendo.emulatedPad, .switchPro)
        XCTAssertEqual(PadFamily.other.emulatedPad, .xboxWireless)
    }

    // MARK: - Battery

    func testTheBatteryCadenceIsTheSteadySampleEveryThirtySecondsAndTheWatchBetween() {
        let polls = (0 ... 40).compactMap { second in batteryPoll(secondsSinceAttach: second).map { (second, $0) } }
        XCTAssertEqual(polls.filter { $0.1 == .steady }.map(\.0), [1, 31])
        XCTAssertEqual(polls.filter { $0.1 == .watch }.map(\.0), [4, 7, 10, 13, 16, 19, 22, 25, 28, 34, 37, 40])
    }

    func testABatteryLevelBecomesAPercentAndAnUnknownLevelNone() {
        XCTAssertEqual(batteryReading(level: 0.84, state: .charging), BatteryReading(level: 84, state: .charging))
        XCTAssertEqual(batteryReading(level: 1.2, state: .full), BatteryReading(level: 100, state: .full))
        XCTAssertEqual(batteryReading(level: -1, state: .unknown), BatteryReading(level: nil, state: .unknown))
    }

    func testTheWatchForwardsOnlyAChargeStateChangeAndTheSteadySampleAlways() throws {
        let (controller, _) = try snapshotPad()
        let input = input(connected: [controller])
        let id = input.slotId(for: controller)
        let recorder = InputRecorder()
        input.processor.route(recorder.route)
        let discharging = BatteryReading(level: 50, state: .discharging)
        input.forwardBattery(deviceId: id, reading: discharging, poll: .steady)
        input.forwardBattery(deviceId: id, reading: discharging, poll: .watch)
        input.forwardBattery(deviceId: id, reading: BatteryReading(level: 50, state: .charging), poll: .watch)
        input.forwardBattery(deviceId: id, reading: BatteryReading(level: 51, state: .charging), poll: .steady)
        XCTAssertEqual(recorder.batteries.map(\.reading.level), [50, 50, 51])
        XCTAssertEqual(input.slots.first?.battery, BatteryReading(level: 51, state: .charging), "the slot shows the last reading")
    }

    func testTheBatteryClockRunsWhileAPadIsAttached() throws {
        let ticker = ManualTicker()
        let (controller, _) = try snapshotPad()
        let input = GameControllerInput(connected: [controller], center: NotificationCenter(), batteryTicker: ticker)
        XCTAssertEqual(ticker.starts, [1])
        input.detach(controller)
        XCTAssertFalse(ticker.running)
    }
}
