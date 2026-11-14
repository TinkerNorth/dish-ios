// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import Observation

/// The Steam Controllers paired to this iPhone over Bluetooth, which
/// GameController never vends: off until the person opts in, with no
/// CoreBluetooth object before, then each pad its links claim a slot with
/// its feed and the device's battery on the 30 s cadence, since SDL's iOS
/// backend reads no battery from either pad. The links run on a queue of
/// their own (`SteamLinks`), which the pads' rumble drains on too.
@MainActor
@Observable
package final class SteamBluetoothPads {
    package private(set) var slots: [ControllerSlot] = []
    /// What Bluetooth last said; nil while off, and until it first speaks.
    package private(set) var radio: SteamRadioState?
    package private(set) var running = false
    @ObservationIgnored package let links: SteamLinks
    @ObservationIgnored private let processor: GamepadInputProcessor
    @ObservationIgnored private let battery: DeviceBatteryCadence

    /// `makeRadio` is called only once the person opts in; `clock` is the
    /// queue's own unless a test hands in one.
    package init(
        processor: GamepadInputProcessor,
        feedback: PadFeedback,
        makeRadio: @escaping SteamRadioFactory = { CoreBluetoothRadio(events: $0, queue: $1) },
        clock: (any SteamClock)? = nil,
        batteryTicker: any Ticker = TimerTicker(),
        deviceBattery: any DeviceBattery = InertDeviceBattery()
    ) {
        let queue = ThreadRole.input.queue(label: "com.tinkernorth.dish.input.steam", qos: .userInteractive)
        links = SteamLinks(queue: queue, makeRadio: makeRadio, clock: clock ?? QueueClock(queue: queue))
        self.processor = processor
        battery = DeviceBatteryCadence(ticker: batteryTicker, device: deviceBattery, processor: processor)
        feedback.drive(slotsPrefixed: steamSlotIdPrefix, on: queue, with: links)
    }

    /// Makes the radio, which asks iOS for Bluetooth the first time.
    package func start() {
        guard !running else { return }
        running = true
        links.start(owner: self)
    }

    /// Every pad leaves the list now; the links give each back.
    package func stop() {
        guard running else { return }
        running = false
        radio = nil
        for slot in slots {
            letGo(slot.id)
        }
        slots = []
        links.stop()
    }

    /// The slot's trackpad pick from now on.
    package func useTrackpadPick(_ pick: TouchpadPick, slotId: String) {
        guard let pad = steamPad(slotId: slotId) else { return }
        links.use(pick, for: pad)
    }

    // MARK: - What the links tell

    func radioChanged(_ state: SteamRadioState) {
        guard running else { return }
        radio = state
    }

    func claimed(_ pad: UUID, _ input: SteamBleInput) {
        guard running else { return }
        let slot = steamSlot(pad, input.model)
        slots.removeAll { $0.id == slot.id }
        slots.append(slot)
        links.use(processor.feed(for: slot.id), for: pad)
        battery.start(slot.id)
    }

    func ended(_ pad: UUID) {
        let id = steamSlotId(pad)
        guard slots.contains(where: { $0.id == id }) else { return }
        slots.removeAll { $0.id == id }
        letGo(id)
    }

    private func letGo(_ slotId: String) {
        processor.remove(deviceId: slotId)
        battery.stop(slotId)
    }
}

/// A claimed pad as the list shows it: its model's name, on Bluetooth, with
/// its IMU, its trackpads, the 2026 pad's motors and the extended buttons
/// both fill, and no battery of its own.
func steamSlot(_ pad: UUID, _ model: SteamBleModel) -> ControllerSlot {
    ControllerSlot(
        id: steamSlotId(pad),
        name: model.name,
        link: .bluetooth,
        capabilities: ControllerCapabilities(hasMotion: true, hasTouchpad: true, hasRumble: model.plan.rumbles, hasExtendedButtons: true),
        family: .other,
        trackpads: model.trackpads
    )
}
