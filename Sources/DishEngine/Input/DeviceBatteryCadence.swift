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

/// The battery cadence of the pads with no battery of their own, the
/// on-screen controller and a Steam Controller over Bluetooth: one tick a
/// second while any of them is listed, each its own 30 s cadence from when
/// it came, and each poll sends its host the device's battery through the
/// processor's funnel.
@MainActor
final class DeviceBatteryCadence {
    private let ticker: any Ticker
    private let device: any DeviceBattery
    private let processor: GamepadInputProcessor
    private var seconds: [String: Int] = [:]
    private var lastState: [String: BatteryChargeState] = [:]

    init(ticker: any Ticker, device: any DeviceBattery, processor: GamepadInputProcessor) {
        self.ticker = ticker
        self.device = device
        self.processor = processor
    }

    func start(_ slotId: String) {
        guard seconds[slotId] == nil else { return }
        seconds[slotId] = 0
        lastState.removeValue(forKey: slotId)
        guard seconds.count == 1 else { return }
        ticker.start(every: 1) { [weak self] in self?.tick() }
    }

    func stop(_ slotId: String) {
        guard seconds.removeValue(forKey: slotId) != nil else { return }
        lastState.removeValue(forKey: slotId)
        guard seconds.isEmpty else { return }
        ticker.stop()
    }

    private func tick() {
        for (slotId, current) in seconds {
            let next = current + 1
            seconds[slotId] = next
            guard let poll = batteryPoll(secondsSinceAttach: next) else { continue }
            send(poll, for: slotId)
        }
    }

    private func send(_ poll: BatteryPoll, for slotId: String) {
        let routed = routeBattery(pad: nil, device: device.reading)
        guard let sent = batteryToSend(routed.wire, poll: poll, lastState: lastState[slotId]) else { return }
        lastState[slotId] = sent.state
        processor.publishBattery(deviceId: slotId, reading: sent)
    }
}
