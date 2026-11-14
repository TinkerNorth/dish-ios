// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the Steam Controllers ask of Bluetooth, on the links' queue alone:
/// CoreBluetooth's central in the app, a test's radio in the tests. A pad is
/// known by its peripheral's identifier, and a characteristic by its UUID.
package protocol SteamRadio: AnyObject {
    /// The paired Steam Controllers the system has connected.
    func connectedSteamControllers() -> [UUID]
    func connect(_ pad: UUID)
    func disconnect(_ pad: UUID)
    func discoverServices(of pad: UUID)
    func discoverCharacteristics(of pad: UUID)
    func subscribe(_ pad: UUID, to characteristic: String)
    func write(_ value: [UInt8], to characteristic: String, of pad: UUID)
    /// Lets go of the central; nothing is called back after.
    func close()
}

/// What Bluetooth tells the Steam Controllers' links, called on their queue.
package protocol SteamRadioEvents: AnyObject, Sendable {
    func radioChanged(_ state: SteamRadioState)
    func connected(_ pad: UUID)
    /// The link went: disconnected, or the connection failed.
    func lost(_ pad: UUID)
    func servicesFound(_ pad: UUID, valve: Bool)
    func characteristicsFound(_ pad: UUID, _ characteristics: [String])
    /// A value of the input characteristic the pad was subscribed to.
    func received(_ value: Data, from pad: UUID)
}

/// Makes the radio when the person opts in, on the links' queue, which its
/// callbacks are delivered on.
package typealias SteamRadioFactory = @Sendable (_ events: any SteamRadioEvents, _ queue: DispatchSerialQueue) -> any SteamRadio

/// The links' time: the uptime clock and the queue's own timers in the app,
/// a test's hand in the tests.
package protocol SteamClock: Sendable {
    func nowMs() -> Int64
    /// Runs `work` on the links' queue once `ms` have passed.
    func after(ms: Int64, _ work: @escaping @Sendable () -> Void)
}

/// The production clock: the uptime clock and `asyncAfter` on the queue.
package struct QueueClock: SteamClock {
    let queue: DispatchSerialQueue

    package init(queue: DispatchSerialQueue) {
        self.queue = queue
    }

    package func nowMs() -> Int64 {
        Int64(uptimeNs() / 1_000_000)
    }

    package func after(ms: Int64, _ work: @escaping @Sendable () -> Void) {
        queue.asyncAfter(deadline: .now() + .milliseconds(Int(ms)), execute: work)
    }
}

/// SDL's iOS backend looks for newly connected pads at most every five
/// seconds (`updateConnectedSteamControllers`).
let steamPollMs: Int64 = 5000

/// A release's writes are answered by the pad before the central lets go:
/// CoreBluetooth may drop a command still pending when its connection is
/// cancelled.
let steamReleaseGraceMs: Int64 = 1000

/// A Steam Controller's slot id: its peripheral's identifier, stable for
/// this app on this device.
let steamSlotIdPrefix = "ble:"

func steamSlotId(_ pad: UUID) -> String {
    steamSlotIdPrefix + pad.uuidString
}

func steamPad(slotId: String) -> UUID? {
    guard slotId.hasPrefix(steamSlotIdPrefix) else { return nil }
    return UUID(uuidString: String(slotId.dropFirst(steamSlotIdPrefix.count)))
}
