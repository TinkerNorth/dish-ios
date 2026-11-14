// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One Steam Controller's link inside `SteamLinks`: where it stands, its
/// reader once claimed, and its rumble between host commands.
final class SteamLink {
    let pad: UUID
    /// Unique across the run, so a timer the link set fires into nothing
    /// once the link has gone, whatever came after it.
    let serial: Int
    var stage = SteamLinkStage.connecting
    var reader: SteamPadReader?
    var rumble = TritonRumble()
    var resending = false

    init(pad: UUID, serial: Int) {
        self.pad = pad
        self.serial = serial
    }
}

/// The Steam Controllers paired over Bluetooth, read on a queue of their
/// own, which every CoreBluetooth callback is delivered on and which is
/// this actor's executor, as `PadActuators` is the feedback queue's: SDL's
/// iOS backend (`src/hidapi/ios/hid.m`) with each decision a `DishCore`
/// reducer's. The radio is made only when the person opts in. A value goes
/// from the radio's callback through the decoder to the pad's feed with no
/// lock, no hop and no allocation of Dish's own; a pad's rumble drains here
/// from its feedback, one hop from the receive loop.
package actor SteamLinks: SteamRadioEvents, FeedbackActuators {
    package nonisolated let queue: DispatchSerialQueue
    private let makeRadio: SteamRadioFactory
    private let clock: any SteamClock
    private var radio: (any SteamRadio)?
    /// Between a start and a stop; a radio letting its pads answer after a
    /// stop takes no new pad.
    private var running = false
    private weak var owner: SteamBluetoothPads?
    private var links: [UUID: SteamLink] = [:]
    private var serials = 0
    /// Bumped on each start and stop, so a stop's late close spares a start.
    private var opened = 0
    /// Bumped whenever Bluetooth's word changes, so one poll runs at a time.
    private var polls = 0

    package nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    package init(queue: DispatchSerialQueue, makeRadio: @escaping SteamRadioFactory, clock: any SteamClock) {
        self.queue = queue
        self.makeRadio = makeRadio
        self.clock = clock
    }

    // MARK: - The main actor's side

    /// The person opted in: the radio is made, and iOS asks for Bluetooth.
    package nonisolated func start(owner: SteamBluetoothPads) {
        queue.async { self.assumeIsolated { $0.open(owner) } }
    }

    /// The person opted out: every claimed pad is given back, and the radio
    /// goes once the pads had time to answer.
    package nonisolated func stop() {
        queue.async { self.assumeIsolated { $0.close() } }
    }

    package nonisolated func use(_ feed: PadFeed, for pad: UUID) {
        queue.async { self.assumeIsolated { $0.links[pad]?.reader?.use(feed) } }
    }

    package nonisolated func use(_ pick: TouchpadPick, for pad: UUID) {
        queue.async { self.assumeIsolated { $0.links[pad]?.reader?.use(pick) } }
    }

    // MARK: - Bluetooth's side

    package nonisolated func radioChanged(_ state: SteamRadioState) {
        assumeIsolated { $0.follow(state) }
    }

    package nonisolated func connected(_ pad: UUID) {
        assumeIsolated { $0.advance(pad, .connected) }
    }

    package nonisolated func lost(_ pad: UUID) {
        assumeIsolated { $0.advance(pad, .lost) }
    }

    package nonisolated func servicesFound(_ pad: UUID, valve: Bool) {
        assumeIsolated { $0.advance(pad, .servicesFound(valve: valve)) }
    }

    package nonisolated func characteristicsFound(_ pad: UUID, _ characteristics: [String]) {
        assumeIsolated { $0.advance(pad, .characteristicsFound(characteristics)) }
    }

    package nonisolated func received(_ value: Data, from pad: UUID) {
        assumeIsolated { $0.receive(value, from: pad) }
    }

    // MARK: - The feedback queue's side, which drains here

    package nonisolated func rumble(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16) {
        assumeIsolated { $0.rumbleNow(slotId, strong: strong, weak: weak, durationMs: durationMs) }
    }

    /// Neither pad has a light bar, adaptive triggers or player LEDs, so no
    /// route carries these to one.
    package nonisolated func lightbar(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8) {}

    package nonisolated func triggerEffects(_ slotId: String, left: [UInt8], right: [UInt8]) {}

    package nonisolated func playerLeds(_ slotId: String, player: Int) {}

    // MARK: - On the queue

    /// A stop's radio still letting its pads answer goes at once.
    private func open(_ fresh: SteamBluetoothPads) {
        radio?.close()
        opened += 1
        polls += 1
        running = true
        owner = fresh
        radio = makeRadio(self, queue)
    }

    private func close() {
        opened += 1
        polls += 1
        running = false
        owner = nil
        for pad in Array(links.keys) {
            advance(pad, .released)
        }
        let closing = opened
        clock.after(ms: steamReleaseGraceMs) { [weak self] in self?.assumeIsolated { $0.letGo(closing) } }
    }

    private func letGo(_ closing: Int) {
        guard opened == closing else { return }
        radio?.close()
        radio = nil
    }

    /// Powered on, the paired pads are looked for at once and every few
    /// seconds after; any other word ends every link.
    private func follow(_ state: SteamRadioState) {
        polls += 1
        guard running else { return }
        tellOwner { $0.radioChanged(state) }
        switch state {
        case .poweredOn: poll(polls)
        case .waiting, .poweredOff, .unsupported, .denied, .restricted: loseAll()
        }
    }

    private func poll(_ round: Int) {
        guard polls == round, let radio else { return }
        for pad in radio.connectedSteamControllers() where links[pad] == nil {
            adopt(pad, on: radio)
        }
        clock.after(ms: steamPollMs) { [weak self] in self?.assumeIsolated { $0.poll(round) } }
    }

    private func adopt(_ pad: UUID, on radio: any SteamRadio) {
        serials += 1
        links[pad] = SteamLink(pad: pad, serial: serials)
        radio.connect(pad)
    }

    private func loseAll() {
        for pad in Array(links.keys) {
            advance(pad, .lost)
        }
    }

    private func advance(_ pad: UUID, _ event: SteamLinkEvent) {
        guard let link = links[pad] else { return }
        let step = reduceSteamLink(link.stage, event)
        link.stage = step.stage
        for effect in step.effects {
            run(effect, on: link)
        }
        if step.stage == .ended { links.removeValue(forKey: pad) }
    }

    private func run(_ effect: SteamLinkEffect, on link: SteamLink) {
        switch effect {
        case .discoverServices: radio?.discoverServices(of: link.pad)
        case .discoverCharacteristics: radio?.discoverCharacteristics(of: link.pad)
        case let .subscribe(characteristic): radio?.subscribe(link.pad, to: characteristic)
        case let .claim(input): claim(link, input)
        case let .write(writes): send(writes, to: link.pad)
        case .endClaim: endClaim(link)
        case .disconnect: radio?.disconnect(link.pad)
        }
    }

    /// The first report claims the pad, as SDL's iOS backend reads it as the
    /// sign its notifications are on.
    private func receive(_ value: Data, from pad: UUID) {
        guard let link = links[pad] else { return }
        if link.reader == nil { advance(pad, .reportArrived) }
        link.reader?.read(value)
    }

    private func claim(_ link: SteamLink, _ input: SteamBleInput) {
        link.reader = SteamPadReader(input: input)
        let pad = link.pad
        tellOwner { $0.claimed(pad, input) }
        guard input.model.plan.refreshesLizardMode else { return }
        scheduleRefresh(link)
    }

    private func endClaim(_ link: SteamLink) {
        link.reader?.release()
        link.reader = nil
        link.rumble = TritonRumble()
        let pad = link.pad
        tellOwner { $0.ended(pad) }
    }

    private func send(_ writes: [SteamWrite], to pad: UUID) {
        for write in writes {
            radio?.write(steamBleValue(of: write), to: steamBleCharacteristic(for: write), of: pad)
        }
    }

    /// In order on the main queue, so a claim and its end arrive as they happened.
    private func tellOwner(_ tell: @escaping @Sendable @MainActor (SteamBluetoothPads) -> Void) {
        let told = owner
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let told else { return }
                tell(told)
            }
        }
    }

    // MARK: - The 2026 pad's timers

    private func scheduleRefresh(_ link: SteamLink) {
        let pad = link.pad
        let serial = link.serial
        clock.after(ms: TritonRumbleRule.lizardRefreshMs) { [weak self] in self?.assumeIsolated { $0.refresh(pad, serial) } }
    }

    /// The firmware's watchdog turns lizard mode back on unless it is told
    /// again.
    private func refresh(_ pad: UUID, _ serial: Int) {
        guard let link = links[pad], link.serial == serial, case let .claimed(input) = link.stage else { return }
        send(input.model.plan.refresh, to: pad)
        scheduleRefresh(link)
    }

    /// The 2015 pad has no motors; a pad not claimed takes nothing.
    private func rumbleNow(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16) {
        guard let pad = steamPad(slotId: slotId), let link = links[pad], case let .claimed(input) = link.stage else { return }
        guard input.model.plan.rumbles else { return }
        sendRumble(link.rumble.command(strong: strong, weak: weak, durationMs: durationMs, nowMs: clock.nowMs()), to: pad)
        guard link.rumble.running, !link.resending else { return }
        link.resending = true
        scheduleResend(link)
    }

    private func scheduleResend(_ link: SteamLink) {
        let pad = link.pad
        let serial = link.serial
        clock.after(ms: TritonRumbleRule.resendMs) { [weak self] in self?.assumeIsolated { $0.resend(pad, serial) } }
    }

    /// The level again inside the firmware's safety stop, and the stop once
    /// its hold ends.
    private func resend(_ pad: UUID, _ serial: Int) {
        guard let link = links[pad], link.serial == serial else { return }
        if let report = link.rumble.tick(nowMs: clock.nowMs()) { sendRumble(report, to: pad) }
        guard link.rumble.running else {
            link.resending = false
            return
        }
        scheduleResend(link)
    }

    private func sendRumble(_ report: [UInt8], to pad: UUID) {
        send([SteamWrite(kind: .output, reportId: TritonReportId.hapticRumble, bytes: report)], to: pad)
    }
}
