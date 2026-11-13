// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the host is sent at one poll, given what the route chose and the
/// charge state last sent: the steady sample always, the watch only when the
/// state changed. Nil sends nothing.
func batteryToSend(_ wire: BatteryReading?, poll: BatteryPoll, lastState: BatteryChargeState?) -> BatteryReading? {
    guard let wire else { return nil }
    let changed = lastState != wire.state
    switch poll {
    case .steady: return wire
    case .watch: return changed ? wire : nil
    }
}

/// The on-screen controller's battery cadence, the one a pad with no battery
/// of its own keeps: it runs while the controller is listed, and each poll
/// sends its host the device's battery through the processor's funnel.
@MainActor
final class OnScreenBattery {
    private let ticker: any Ticker
    private let device: any DeviceBattery
    private let processor: GamepadInputProcessor
    private var seconds: Int?
    private var lastState: BatteryChargeState?

    init(ticker: any Ticker, device: any DeviceBattery, processor: GamepadInputProcessor) {
        self.ticker = ticker
        self.device = device
        self.processor = processor
    }

    func start() {
        guard seconds == nil else { return }
        seconds = 0
        lastState = nil
        ticker.start(every: 1) { [weak self] in self?.tick() }
    }

    func stop() {
        guard seconds != nil else { return }
        seconds = nil
        ticker.stop()
    }

    private func tick() {
        guard let current = seconds else { return }
        let next = current + 1
        seconds = next
        guard let poll = batteryPoll(secondsSinceAttach: next) else { return }
        send(poll)
    }

    private func send(_ poll: BatteryPoll) {
        let routed = routeBattery(pad: nil, device: device.reading)
        guard let sent = batteryToSend(routed.wire, poll: poll, lastState: lastState) else { return }
        lastState = sent.state
        processor.publishBattery(deviceId: onScreenSlotId, reading: sent)
    }
}
