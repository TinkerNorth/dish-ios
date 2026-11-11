// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController

/// MSG_BATTERY is a fixed 30 s cadence; the first sample waits for the
/// controller-add to settle.
let kBatteryPollIntervalSec = 30
let kBatteryFirstReportDelaySec = 1
/// `GCDeviceBattery` has no change notification, so a charging transition
/// is caught by this faster read-only poll.
let kBatteryStateWatchIntervalSec = 3

/// What the battery cadence does at one second of a pad's attachment.
enum BatteryPoll: Equatable {
    /// The steady 30 s sample: always forwarded, an unchanged value too.
    case steady
    /// The charging-state watch: forwarded only when the state changed.
    case watch
}

/// The steady sample one second after the attach and every 30 s after it;
/// the watch every 3 s from just past the first sample, so the first
/// sample has set the state it compares against.
func batteryPoll(secondsSinceAttach seconds: Int) -> BatteryPoll? {
    let sinceFirst = seconds - kBatteryFirstReportDelaySec
    guard sinceFirst >= 0 else { return nil }
    if sinceFirst % kBatteryPollIntervalSec == 0 { return .steady }
    let watching = sinceFirst >= kBatteryStateWatchIntervalSec && sinceFirst % kBatteryStateWatchIntervalSec == 0
    return watching ? .watch : nil
}

/// A controller's own `GCDeviceBattery` as a reading: `level` 0...1 to a
/// percentage, a negative level (unknown) to none.
func batteryReading(level: Float, state: GCDeviceBattery.State) -> BatteryReading {
    BatteryReading(level: batteryPercent(level), state: batteryChargeState(state))
}

func batteryChargeState(_ state: GCDeviceBattery.State) -> BatteryChargeState {
    switch state {
    case .discharging: .discharging
    case .charging: .charging
    case .full: .full
    case .unknown: .unknown
    @unknown default: .unknown
    }
}

/// The battery cadence of `GameControllerInput`: one main-actor tick a
/// second while any pad is attached. Each sample weighs the pad's own
/// battery against the device's (`routeBattery`): the card keeps the pad's,
/// and the host is sent the lower, or the device's for a pad without one.
extension GameControllerInput {

    func startBatteryClock(deviceId: String) {
        batteryClocks[deviceId] = 0
        lastBatteryState.removeValue(forKey: deviceId)
        guard batteryClocks.count == 1 else { return }
        batteryTicker.start(every: 1) { [weak self] in self?.tickBattery() }
    }

    func stopBatteryClock(deviceId: String) {
        batteryClocks.removeValue(forKey: deviceId)
        lastBatteryState.removeValue(forKey: deviceId)
        guard batteryClocks.isEmpty else { return }
        batteryTicker.stop()
    }

    private func tickBattery() {
        for (deviceId, seconds) in batteryClocks {
            let next = seconds + 1
            batteryClocks[deviceId] = next
            guard let poll = batteryPoll(secondsSinceAttach: next) else { continue }
            emitBattery(deviceId: deviceId, poll: poll)
        }
    }

    /// Reads the pad's own battery, none for a pad without one, and forwards
    /// it as the poll says.
    func emitBattery(deviceId: String, poll: BatteryPoll) {
        guard let controller = controllersById[deviceId] else { return }
        let pad = controller.battery.map { batteryReading(level: $0.batteryLevel, state: $0.batteryState) }
        forwardBattery(deviceId: deviceId, pad: pad, poll: poll)
    }

    /// The card takes the pad's own reading and the host the routed one: the
    /// steady sample always, the watch only when the charge state the host
    /// is sent changed.
    func forwardBattery(deviceId: String, pad: BatteryReading?, poll: BatteryPoll) {
        let routed = routeBattery(pad: pad, device: deviceBattery.reading)
        guard let sent = batteryToSend(routed.wire, poll: poll, lastState: lastBatteryState[deviceId]) else { return }
        lastBatteryState[deviceId] = sent.state
        if let display = routed.display, let index = slots.firstIndex(where: { $0.id == deviceId }) {
            updateBattery(display, at: index)
        }
        processor.publishBattery(deviceId: deviceId, reading: sent)
    }
}
