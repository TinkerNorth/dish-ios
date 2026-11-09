// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation
import Synchronization
@testable import DishEngine

/// A value several threads append to and read, for a test to inspect after.
final class Locked<Value: Sendable>: Sendable {
    private let mutex: Mutex<Value>

    init(_ initial: Value) {
        mutex = Mutex(initial)
    }

    func get() -> Value {
        mutex.withLock { $0 }
    }

    func set(_ value: Value) {
        mutex.withLock { $0 = value }
    }

    func mutate(_ body: (inout Value) -> Void) {
        mutex.withLock { body(&$0) }
    }
}

/// Routes that record instead of sending: `processor.route(recorder.route)`
/// gives every pad's feed a sink that writes down what the pad sent, on the
/// thread that sent it, for the test to read.
final class InputRecorder: Sendable {
    /// One thing a pad sent, by device.
    enum Sent: Equatable {
        case report(String, GamepadReport)
        case motion(String, MotionSample)
        case touchpad(String, TouchpadSample)
        case battery(String, BatteryReading)
    }

    /// The switches every recorded route carries.
    let flags: ForwardingFlags
    private let log = Locked<[Sent]>([])

    init(flags: ForwardingFlags = ForwardingFlags()) {
        self.flags = flags
    }

    func route(_ deviceId: String) -> Route? {
        Route(sink: RecordingSink(deviceId: deviceId, log: log), slot: 0, flags: flags)
    }

    var sent: [Sent] {
        log.get()
    }

    var reports: [(id: String, report: GamepadReport)] {
        sent.compactMap { entry in
            guard case let .report(id, report) = entry else { return nil }
            return (id, report)
        }
    }

    var motion: [(id: String, sample: MotionSample)] {
        sent.compactMap { entry in
            guard case let .motion(id, sample) = entry else { return nil }
            return (id, sample)
        }
    }

    var touches: [(id: String, sample: TouchpadSample)] {
        sent.compactMap { entry in
            guard case let .touchpad(id, sample) = entry else { return nil }
            return (id, sample)
        }
    }

    var batteries: [(id: String, reading: BatteryReading)] {
        sent.compactMap { entry in
            guard case let .battery(id, reading) = entry else { return nil }
            return (id, reading)
        }
    }
}

/// One device's recording sink.
private final class RecordingSink: PadSink {
    let deviceId: String
    let log: Locked<[InputRecorder.Sent]>

    init(deviceId: String, log: Locked<[InputRecorder.Sent]>) {
        self.deviceId = deviceId
        self.log = log
    }

    func send(_ report: GamepadReport, slot _: SlotIndex) {
        note(.report(deviceId, report))
    }

    func send(_ motion: MotionSample, slot _: SlotIndex) {
        note(.motion(deviceId, motion))
    }

    func send(_ touch: TouchpadSample, slot _: SlotIndex) {
        note(.touchpad(deviceId, touch))
    }

    func send(battery: BatteryReading, slot _: SlotIndex) {
        note(.battery(deviceId, battery))
    }

    private func note(_ entry: InputRecorder.Sent) {
        log.mutate { $0.append(entry) }
    }
}

/// Actuators that write down what the feedback queue asked of them.
final class RecordingActuators: FeedbackActuators {
    enum Actuation: Equatable {
        case rumble(String, strong: UInt16, weak: UInt16, durationMs: UInt16)
        case lightbar(String, red: UInt8, green: UInt8, blue: UInt8)
        case triggerEffects(String, left: [UInt8], right: [UInt8])
        case playerLeds(String, player: Int)
    }

    private let log = Locked<[Actuation]>([])

    var actuations: [Actuation] {
        log.get()
    }

    func rumble(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16) {
        log.mutate { $0.append(.rumble(slotId, strong: strong, weak: weak, durationMs: durationMs)) }
    }

    func lightbar(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8) {
        log.mutate { $0.append(.lightbar(slotId, red: red, green: green, blue: blue)) }
    }

    func triggerEffects(_ slotId: String, left: [UInt8], right: [UInt8]) {
        log.mutate { $0.append(.triggerEffects(slotId, left: left, right: right)) }
    }

    func playerLeds(_ slotId: String, player: Int) {
        log.mutate { $0.append(.playerLeds(slotId, player: player)) }
    }
}

/// A controller source whose slots the test sets, for the model's tests
/// that cannot build a `GCController`.
@MainActor
@Observable
final class FakeControllerSource: ControllerSource {
    var slots: [ControllerSlot]
    let processor = GamepadInputProcessor()
    let feedback = PadFeedback(actuators: RecordingActuators(), queue: DispatchSerialQueue(label: "test.feedback"))

    init(slots: [ControllerSlot] = []) {
        self.slots = slots
    }
}
