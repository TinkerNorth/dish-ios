// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
@testable import DishEngine

/// A radio a test drives by hand, as FakeSteamGatt drives dish-android's
/// link: it writes down what the links asked of it, and delivers Bluetooth's
/// word on the links' queue, as CoreBluetooth calls back there.
final class FakeSteamRadio: SteamRadio, Sendable {
    enum Call: Equatable {
        case connect(UUID)
        case disconnect(UUID)
        case discoverServices(UUID)
        case discoverCharacteristics(UUID)
        case subscribe(UUID, String)
        case write(UUID, String, [UInt8])
        case close
    }

    private let events: any SteamRadioEvents
    private let queue: DispatchSerialQueue
    private let log = Locked<[Call]>([])
    private let paired = Locked<[UUID]>([])

    init(events: any SteamRadioEvents, queue: DispatchSerialQueue) {
        self.events = events
        self.queue = queue
    }

    var calls: [Call] {
        log.get()
    }

    /// What the links wrote to one characteristic of the pad, in order.
    func writes(to characteristic: String, of pad: UUID) -> [[UInt8]] {
        calls.compactMap { call in
            guard case let .write(written, target, value) = call, written == pad, target == characteristic else { return nil }
            return value
        }
    }

    // MARK: - What the links ask, on their queue

    func connectedSteamControllers() -> [UUID] {
        paired.get()
    }

    func connect(_ pad: UUID) {
        note(.connect(pad))
    }

    func disconnect(_ pad: UUID) {
        note(.disconnect(pad))
    }

    func discoverServices(of pad: UUID) {
        note(.discoverServices(pad))
    }

    func discoverCharacteristics(of pad: UUID) {
        note(.discoverCharacteristics(pad))
    }

    func subscribe(_ pad: UUID, to characteristic: String) {
        note(.subscribe(pad, characteristic))
    }

    func write(_ value: [UInt8], to characteristic: String, of pad: UUID) {
        note(.write(pad, characteristic, value))
    }

    func close() {
        note(.close)
    }

    private func note(_ call: Call) {
        log.mutate { $0.append(call) }
    }

    // MARK: - The test's hand, each word delivered on the links' queue

    /// The pads the system has connected, which the next poll finds.
    func pair(_ pads: [UUID]) {
        paired.set(pads)
    }

    func say(_ state: SteamRadioState) {
        queue.sync { events.radioChanged(state) }
    }

    func connected(_ pad: UUID) {
        queue.sync { events.connected(pad) }
    }

    func lose(_ pad: UUID) {
        queue.sync { events.lost(pad) }
    }

    func servicesFound(_ pad: UUID, valve: Bool = true) {
        queue.sync { events.servicesFound(pad, valve: valve) }
    }

    func characteristicsFound(_ pad: UUID, _ characteristics: [String]) {
        queue.sync { events.characteristicsFound(pad, characteristics) }
    }

    func notify(_ value: [UInt8], from pad: UUID) {
        queue.sync { events.received(Data(value), from: pad) }
    }
}

/// Makes the radios the links ask for and keeps each, so a test can count
/// them and drive the last.
final class FakeSteamRadios: Sendable {
    private let made = Locked<[FakeSteamRadio]>([])

    var count: Int {
        made.get().count
    }

    var last: FakeSteamRadio? {
        made.get().last
    }

    func make(_ events: any SteamRadioEvents, _ queue: DispatchSerialQueue) -> any SteamRadio {
        let radio = FakeSteamRadio(events: events, queue: queue)
        made.mutate { $0.append(radio) }
        return radio
    }
}

/// The links' time as the test moves it: what `after` set waits for
/// `advance`, which runs each piece of work as it falls due, in order and on
/// the links' queue, the work it sets included.
final class ManualSteamClock: SteamClock, Sendable {
    private struct Due {
        let atMs: Int64
        let order: Int
        let work: @Sendable () -> Void
    }

    private let now = Locked<Int64>(1000)
    private let pending = Locked<[Due]>([])
    private let orders = Locked<Int>(0)

    func nowMs() -> Int64 {
        now.get()
    }

    func after(ms: Int64, _ work: @escaping @Sendable () -> Void) {
        orders.mutate { $0 += 1 }
        let due = Due(atMs: now.get() + ms, order: orders.get(), work: work)
        pending.mutate { $0.append(due) }
    }

    func advance(by ms: Int64, on queue: DispatchSerialQueue) {
        let target = now.get() + ms
        while let next = takeNext(dueBy: target) {
            now.set(next.atMs)
            queue.sync(execute: next.work)
        }
        now.set(target)
    }

    private func takeNext(dueBy target: Int64) -> Due? {
        var taken: Due?
        pending.mutate { list in
            let due = list.indices.filter { list[$0].atMs <= target }
            guard let first = due.min(by: { (list[$0].atMs, list[$0].order) < (list[$1].atMs, list[$1].order) }) else { return }
            taken = list.remove(at: first)
        }
        return taken
    }
}
