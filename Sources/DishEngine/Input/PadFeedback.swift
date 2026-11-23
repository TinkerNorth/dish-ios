// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What the feedback queue does with each pad's newest command: drive the
/// haptics, the light, the adaptive triggers and the player index. Called on
/// that queue only; the controller bridge's `PadActuators` in production,
/// recorders in tests.
package protocol FeedbackActuators: Sendable {
    func rumble(_ slotId: String, strong: UInt16, weak: UInt16, durationMs: UInt16)
    func lightbar(_ slotId: String, red: UInt8, green: UInt8, blue: UInt8)
    func triggerEffects(_ slotId: String, left: [UInt8], right: [UInt8])
    func playerLeds(_ slotId: String, player: Int)
    /// The trigger motors, which only the bench drives: the satellite's wire
    /// carries no trigger rumble, and a Moonlight host's is folded into the
    /// body's motors.
    func triggerRumble(_ slotId: String, left: UInt16, right: UInt16, durationMs: UInt16)
    /// What the pad shows on its own surfaces now, read as a bench test
    /// takes one, so a surface the game never set gets it back.
    func idleState(_ slotId: String) -> PadIdleState
}

/// What a pad shows on the surfaces a game can set: its light bar's colour,
/// black for a pad without one, which takes a paint as nothing; and the
/// player its LEDs show, 0 for none.
package struct PadIdleState: Equatable {
    package let lightbar: BenchColour
    package let player: Int

    package init(lightbar: BenchColour, player: Int) {
        self.lightbar = lightbar
        self.player = player
    }

    /// A pad that shows nothing: no light, no player.
    package static let none = PadIdleState(lightbar: BenchColour(red: 0, green: 0, blue: 0), player: 0)
}

/// Where the slots another source drives are acted on, by the prefix of
/// their ids: that source's queue and its actuators.
struct FeedbackLane {
    let prefix: String
    let queue: DispatchSerialQueue
    let actuators: any FeedbackActuators
}

/// The pads' feedback: one serial queue at the input queue's quality that
/// owns every actuator, and each slot's record of the commands waiting for it.
@MainActor
package final class PadFeedback {
    package nonisolated let queue: DispatchSerialQueue
    private let actuators: any FeedbackActuators
    /// One per slot, made on first use and kept, so a burst that spans a
    /// routing refresh still drains once.
    private var pads: [String: FeedbackPad] = [:]
    private var lanes: [FeedbackLane] = []

    package init(actuators: any FeedbackActuators, queue: DispatchSerialQueue) {
        self.actuators = actuators
        self.queue = queue
    }

    /// The slots whose ids start with `prefix` drain on `queue` into
    /// `actuators` from now on: one hop from the receive loop to the queue
    /// that owns them.
    package func drive(slotsPrefixed prefix: String, on queue: DispatchSerialQueue, with actuators: any FeedbackActuators) {
        lanes.append(FeedbackLane(prefix: prefix, queue: queue, actuators: actuators))
    }

    /// What reached the slot's actuators so far; nil for a slot never sent feedback.
    package func output(for slotId: String) -> PadOutputReading? {
        pads[slotId]?.output
    }

    package func pad(for slotId: String) -> FeedbackPad {
        if let pad = pads[slotId] {
            return pad
        }
        let lane = lanes.first { slotId.hasPrefix($0.prefix) }
        let pad = FeedbackPad(slotId: slotId, queue: lane?.queue ?? queue, actuators: lane?.actuators ?? actuators)
        pads[slotId] = pad
        return pad
    }
}

/// One pad's commands on their way to the feedback queue, the newest of each
/// kind: posted from any thread (a receive loop, the main actor), taken on
/// the queue. A post schedules a drain only when none is pending, so a burst
/// costs one hop and the queue applies its last value.
///
/// The bench drives the pad through the same queue: a test holds its
/// surface there, so a drain keeps the game's command for a held surface
/// without writing it, and the test's end writes back the game's last value
/// for that surface, or what the pad showed as the test began when the game
/// never set it.
package final class FeedbackPad: Sendable {
    package let slotId: String
    private let queue: DispatchSerialQueue
    private let actuators: any FeedbackActuators
    /// Each word holds the newest command packed with the pending bit, zero
    /// once the queue took it: written by the posters, taken by the queue.
    private let rumbleWord = AtomicWord()
    private let lightbarWord = AtomicWord()
    private let playerWord = AtomicWord()
    private let triggerMail = Mailbox<TriggerEffectsBox>()
    /// Each lane's commands from the game as the queue took them: the light
    /// bar's and the player's last is the game's state for that surface.
    private let rumbleTally = LaneTally()
    private let lightbarTally = LaneTally()
    private let playerTally = LaneTally()
    private let triggerTally = LaneTally()
    /// The game's last adaptive-trigger effect, the box the poster made,
    /// kept by the queue as it takes each one.
    private let gameTriggers = ReaderHeld<TriggerEffectsBox>()
    /// The queue's own record of the bench: the surfaces a test holds, one
    /// bit each (`BenchSurface.bit`); what the pad showed as the test that
    /// holds its light bar or player LEDs began; and the game's rumble count
    /// as a buzz began.
    private let held = AtomicWord()
    private let idleLightbar = AtomicWord()
    private let idlePlayer = AtomicWord()
    private let rumbleMark = AtomicWord()

    private static let pending: Int64 = 1 << 62

    package init(slotId: String, queue: DispatchSerialQueue, actuators: any FeedbackActuators) {
        self.slotId = slotId
        self.queue = queue
        self.actuators = actuators
    }

    package func post(rumbleStrong strong: UInt16, weak: UInt16, durationMs: UInt16) {
        let packed = Int64(strong) << 32 | Int64(weak) << 16 | Int64(durationMs)
        guard rumbleWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainRumble() }
    }

    package func post(lightbarRed red: UInt8, green: UInt8, blue: UInt8) {
        let packed = Int64(red) << 16 | Int64(green) << 8 | Int64(blue)
        guard lightbarWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainLightbar() }
    }

    package func post(player: Int) {
        let packed = Int64(UInt32(truncatingIfNeeded: player))
        guard playerWord.exchange(Self.pending | packed) & Self.pending == 0 else { return }
        queue.async { self.drainPlayer() }
    }

    /// One 11-byte DualSense block per trigger, as the game wrote it.
    package func post(triggerEffectsLeft left: [UInt8], right: [UInt8]) {
        guard triggerMail.post(TriggerEffectsBox(left: left, right: right)) else { return }
        queue.async { self.drainTriggerEffects() }
    }

    /// The lanes' accounts, read by the main actor for the support file.
    package var output: PadOutputReading {
        PadOutputReading(
            rumble: rumbleTally.reading,
            lightbar: lightbarTally.reading,
            player: playerTally.reading,
            triggerEffects: triggerTally.reading
        )
    }

    private func drainRumble() {
        let word = rumbleWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        rumbleTally.note(word & ~Self.pending)
        guard !benchHolds(held.loadRelaxed(), .rumble) else { return }
        let motors = rumbleMotors(word)
        actuators.rumble(slotId, strong: motors.strong, weak: motors.weak, durationMs: motors.durationMs)
    }

    private func drainLightbar() {
        let word = lightbarWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        lightbarTally.note(word & ~Self.pending)
        guard !benchHolds(held.loadRelaxed(), .lightbar) else { return }
        paint(lightbarColour(word))
    }

    private func drainPlayer() {
        let word = playerWord.exchange(0)
        guard word & Self.pending != 0 else { return }
        playerTally.note(word & ~Self.pending)
        guard !benchHolds(held.loadRelaxed(), .playerLeds) else { return }
        actuators.playerLeds(slotId, player: packedPlayer(word))
    }

    private func drainTriggerEffects() {
        guard let box = triggerMail.take() else { return }
        triggerTally.note(0)
        gameTriggers.replace(with: box)
        guard !benchHolds(held.loadRelaxed(), .triggerEffects) else { return }
        actuators.triggerEffects(slotId, left: box.left, right: box.right)
    }

    private func paint(_ colour: BenchColour) {
        actuators.lightbar(slotId, red: colour.red, green: colour.green, blue: colour.blue)
    }

    // MARK: - The bench

    /// A test takes the surface: from now until its end the game's commands
    /// for it are kept and not written.
    package func benchBegin(_ surface: BenchSurface) {
        queue.async { self.hold(surface) }
    }

    /// One of a test's writes, straight to the pad: not the game's, so it
    /// is neither counted nor kept.
    package func benchWrite(_ write: BenchWrite) {
        queue.async { self.make(write) }
    }

    /// The test lets the surface go, and what the game set goes back.
    package func benchEnd(_ surface: BenchSurface) {
        queue.async { self.release(surface) }
    }

    private func hold(_ surface: BenchSurface) {
        held.storeRelaxed(held.loadRelaxed() | surface.bit)
        switch surface {
        case .rumble: rumbleMark.storeRelaxed(Int64(bitPattern: rumbleTally.reading.total))
        case .lightbar, .playerLeds: noteIdle(actuators.idleState(slotId))
        case .triggerRumble, .triggerEffects: break
        }
    }

    private func noteIdle(_ idle: PadIdleState) {
        idleLightbar.storeRelaxed(packedColour(idle.lightbar))
        idlePlayer.storeRelaxed(Int64(idle.player))
    }

    private func make(_ write: BenchWrite) {
        switch write {
        case let .rumble(strong, weak, durationMs): actuators.rumble(slotId, strong: strong, weak: weak, durationMs: durationMs)
        case let .triggerRumble(left, right, durationMs): actuators.triggerRumble(slotId, left: left, right: right, durationMs: durationMs)
        case let .lightbar(colour): paint(colour)
        case let .player(player): actuators.playerLeds(slotId, player: player)
        case let .triggerEffects(left, right): actuators.triggerEffects(slotId, left: left, right: right)
        }
    }

    private func release(_ surface: BenchSurface) {
        held.storeRelaxed(held.loadRelaxed() & ~surface.bit)
        switch surface {
        case .rumble: putBackRumble()
        case .triggerRumble: break
        case .lightbar: putBackLightbar()
        case .playerLeds: putBackPlayer()
        case .triggerEffects: putBackTriggers()
        }
    }

    /// The buzz runs out on its own; a rumble the game asked for while it
    /// held the motors starts again.
    private func putBackRumble() {
        let reading = rumbleTally.reading
        let gameLast = reading.total > 0 ? rumbleMotors(reading.packed) : nil
        let countAtStart = UInt64(bitPattern: rumbleMark.loadRelaxed())
        guard let motors = benchRumbleAfterTest(countAtStart: countAtStart, countNow: reading.total, gameLast: gameLast) else { return }
        actuators.rumble(slotId, strong: motors.strong, weak: motors.weak, durationMs: motors.durationMs)
    }

    private func putBackLightbar() {
        let reading = lightbarTally.reading
        let gameLast = reading.total > 0 ? lightbarColour(reading.packed) : nil
        paint(benchRestore(gameLast: gameLast, idle: lightbarColour(idleLightbar.loadRelaxed())))
    }

    private func putBackPlayer() {
        let reading = playerTally.reading
        let gameLast = reading.total > 0 ? packedPlayer(reading.packed) : nil
        actuators.playerLeds(slotId, player: benchRestore(gameLast: gameLast, idle: Int(idlePlayer.loadRelaxed())))
    }

    /// A trigger the game never set lets go.
    private func putBackTriggers() {
        let game = gameTriggers.current
        let released = FeedbackBench.releasedTriggerBlock
        actuators.triggerEffects(
            slotId,
            left: benchRestore(gameLast: game?.left, idle: released),
            right: benchRestore(gameLast: game?.right, idle: released)
        )
    }
}

// MARK: - The lanes' packing

/// A rumble command as its word packs it: strong, weak, then the duration.
private func rumbleMotors(_ word: Int64) -> BenchMotors {
    BenchMotors(
        strong: UInt16(truncatingIfNeeded: word >> 32),
        weak: UInt16(truncatingIfNeeded: word >> 16),
        durationMs: UInt16(truncatingIfNeeded: word)
    )
}

/// A light-bar colour as its word packs it: red, green, then blue.
private func lightbarColour(_ word: Int64) -> BenchColour {
    BenchColour(
        red: UInt8(truncatingIfNeeded: word >> 16),
        green: UInt8(truncatingIfNeeded: word >> 8),
        blue: UInt8(truncatingIfNeeded: word)
    )
}

private func packedColour(_ colour: BenchColour) -> Int64 {
    Int64(colour.red) << 16 | Int64(colour.green) << 8 | Int64(colour.blue)
}

private func packedPlayer(_ word: Int64) -> Int {
    Int(Int32(truncatingIfNeeded: word))
}

/// One trigger-effects command as the mailbox carries it.
package final class TriggerEffectsBox: Sendable {
    package let left: [UInt8]
    package let right: [UInt8]

    package init(left: [UInt8], right: [UInt8]) {
        self.left = left
        self.right = right
    }
}

/// One output lane's account: the game's commands its queue took, the last
/// one packed as the lane packs it, and when; a command a bench test held
/// counts as taken, since the test's end writes the last one. One writer,
/// the lane's queue, so a count is a load and a store, as a pad's record is.
final class LaneTally: Sendable {
    private let count = AtomicWord()
    private let last = AtomicWord()
    private let atMs = AtomicWord()

    func note(_ packed: Int64) {
        last.storeRelaxed(packed)
        atMs.storeRelaxed(wallClockMilliseconds())
        count.storeRelaxed(count.loadRelaxed() &+ 1)
    }

    var reading: LaneReading {
        LaneReading(total: UInt64(bitPattern: count.loadRelaxed()), packed: last.loadRelaxed(), atMs: atMs.loadRelaxed())
    }
}

/// A lane's account as the main actor read it.
package struct LaneReading: Equatable {
    /// The game's commands the lane took so far.
    package let total: UInt64
    /// The last command, packed as its lane packs it; meaningless while
    /// none was handed over.
    package let packed: Int64
    package let atMs: Int64

    package init(total: UInt64, packed: Int64, atMs: Int64) {
        self.total = total
        self.packed = packed
        self.atMs = atMs
    }

    package static let none = LaneReading(total: 0, packed: 0, atMs: 0)
}

/// Every lane of one pad's feedback, as the main actor read it.
package struct PadOutputReading: Equatable {
    package let rumble: LaneReading
    package let lightbar: LaneReading
    package let player: LaneReading
    package let triggerEffects: LaneReading

    package init(rumble: LaneReading, lightbar: LaneReading, player: LaneReading, triggerEffects: LaneReading) {
        self.rumble = rumble
        self.lightbar = lightbar
        self.player = player
        self.triggerEffects = triggerEffects
    }

    package static let none = PadOutputReading(rumble: .none, lightbar: .none, player: .none, triggerEffects: .none)

    /// The lanes as the support file writes them, unpacked as each lane
    /// packed its command.
    package func bundle(target: BundleRumbleTarget, write: BundleWrite? = nil) -> BundleOutput {
        BundleOutput(
            rumble: BundleLane(count: rumble.total, last: lastOf(rumble) { packed, atMs in
                BundleRumble(strong: UInt16(truncatingIfNeeded: packed >> 32), weak: UInt16(truncatingIfNeeded: packed >> 16), atMs: atMs)
            }),
            rumbleTarget: target,
            rumbleWrite: write,
            lightbar: BundleLane(count: lightbar.total, last: lastOf(lightbar) { packed, atMs in
                BundleColour(
                    r: UInt8(truncatingIfNeeded: packed >> 16),
                    g: UInt8(truncatingIfNeeded: packed >> 8),
                    b: UInt8(truncatingIfNeeded: packed),
                    atMs: atMs
                )
            }),
            playerLeds: BundleLane(count: player.total, last: lastOf(player) { packed, atMs in
                BundlePlayer(player: Int(Int32(truncatingIfNeeded: packed)), atMs: atMs)
            }),
            triggerEffects: BundleCount(count: triggerEffects.total)
        )
    }
}

/// A lane's last command unpacked, or nil while it has had none.
private func lastOf<Last>(_ lane: LaneReading, _ unpack: (Int64, Int64) -> Last) -> Last? {
    guard lane.total > 0 else { return nil }
    return unpack(lane.packed, lane.atMs)
}
