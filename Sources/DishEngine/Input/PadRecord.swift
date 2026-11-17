// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// What a pad last sent, as the main actor reads it.
package struct LatestInput: Equatable {
    package var raw: GamepadReport?
    package var filtered: GamepadReport?
    package var motion: MotionSample?
    package var touch: TouchpadSample?
    package var reports: UInt64 = 0
}

/// A pad's last report, motion sample and touch, written only by the
/// publishing thread and read by the main actor under a seqlock: the writer
/// makes the sequence odd, stores, and makes it even again; a reader keeps a
/// copy only when the sequence was even and unchanged across its loads. The
/// counts are words of their own.
package final class PadRecord: Sendable {
    private static let hasReport: Int64 = 1
    private static let hasMotion: Int64 = 2
    private static let hasTouch: Int64 = 4
    private static let readAttempts = 64

    private let sequence = AtomicWord()
    private let rawLow = AtomicWord()
    private let rawHigh = AtomicWord()
    private let filteredLow = AtomicWord()
    private let filteredHigh = AtomicWord()
    private let motionLow = AtomicWord()
    private let motionHigh = AtomicWord()
    private let touchLow = AtomicWord()
    private let touchHigh = AtomicWord()
    private let present = AtomicWord()
    private let reports = AtomicWord()
    private let motions = AtomicWord()
    private let touches = AtomicWord()

    package init() {}

    package var reportCount: UInt64 {
        UInt64(bitPattern: reports.loadRelaxed())
    }

    package var motionCount: UInt64 {
        UInt64(bitPattern: motions.loadRelaxed())
    }

    package var touchCount: UInt64 {
        UInt64(bitPattern: touches.loadRelaxed())
    }

    func write(raw: GamepadReport, filtered: GamepadReport) {
        let odd = beginWrite()
        rawLow.storeRelaxed(raw.packedLow)
        rawHigh.storeRelaxed(raw.packedHigh)
        filteredLow.storeRelaxed(filtered.packedLow)
        filteredHigh.storeRelaxed(filtered.packedHigh)
        present.storeRelaxed(present.loadRelaxed() | Self.hasReport)
        endWrite(odd)
        reports.storeRelaxed(reports.loadRelaxed() &+ 1)
    }

    func write(motion: MotionSample) {
        let odd = beginWrite()
        motionLow.storeRelaxed(motion.packedLow)
        motionHigh.storeRelaxed(motion.packedHigh)
        present.storeRelaxed(present.loadRelaxed() | Self.hasMotion)
        endWrite(odd)
        motions.storeRelaxed(motions.loadRelaxed() &+ 1)
    }

    func write(touch: TouchpadSample) {
        let odd = beginWrite()
        touchLow.storeRelaxed(touch.packedLow)
        touchHigh.storeRelaxed(touch.packedHigh)
        present.storeRelaxed(present.loadRelaxed() | Self.hasTouch)
        endWrite(odd)
        touches.storeRelaxed(touches.loadRelaxed() &+ 1)
    }

    /// The writer's opening bracket: the sequence goes odd before any store.
    private func beginWrite() -> Int64 {
        let odd = sequence.loadRelaxed() &+ 1
        sequence.storeRelaxed(odd)
        atomicFenceRelease()
        return odd
    }

    /// The closing bracket: even again, released after every store.
    private func endWrite(_ odd: Int64) {
        sequence.store(odd &+ 1)
    }

    /// A consistent copy, or nil when a writer kept the record busy through
    /// every attempt.
    package func read() -> LatestInput? {
        for _ in 0 ..< Self.readAttempts {
            let before = sequence.load()
            if before & 1 == 0 {
                let copy = loadFields()
                atomicFenceAcquire()
                if sequence.loadRelaxed() == before { return copy }
            }
            sched_yield()
        }
        return nil
    }

    private func loadFields() -> LatestInput {
        let flags = present.loadRelaxed()
        var input = LatestInput(reports: reportCount)
        if flags & Self.hasReport != 0 {
            input.raw = GamepadReport(packedLow: rawLow.loadRelaxed(), high: rawHigh.loadRelaxed())
            input.filtered = GamepadReport(packedLow: filteredLow.loadRelaxed(), high: filteredHigh.loadRelaxed())
        }
        if flags & Self.hasMotion != 0 {
            input.motion = MotionSample(packedLow: motionLow.loadRelaxed(), high: motionHigh.loadRelaxed())
        }
        if flags & Self.hasTouch != 0 {
            input.touch = TouchpadSample(packedLow: touchLow.loadRelaxed(), high: touchHigh.loadRelaxed())
        }
        return input
    }
}

// MARK: - The record's packing: each value as two words, bit for bit

private func field(_ value: Int16, at shift: Int64) -> Int64 {
    Int64(UInt16(bitPattern: value)) << shift
}

private func int16(_ word: Int64, at shift: Int64) -> Int16 {
    Int16(bitPattern: UInt16(truncatingIfNeeded: word >> shift))
}

extension GamepadReport {
    var packedLow: Int64 {
        Int64(buttons) | Int64(lt) << 16 | Int64(rt) << 24 | field(lx, at: 32) | field(ly, at: 48)
    }

    var packedHigh: Int64 {
        field(rx, at: 0) | field(ry, at: 16) | Int64(extButtons) << 32
    }

    init(packedLow low: Int64, high: Int64) {
        self.init(
            buttons: UInt16(truncatingIfNeeded: low),
            lt: UInt8(truncatingIfNeeded: low >> 16),
            rt: UInt8(truncatingIfNeeded: low >> 24),
            lx: int16(low, at: 32),
            ly: int16(low, at: 48),
            rx: int16(high, at: 0),
            ry: int16(high, at: 16),
            extButtons: UInt32(truncatingIfNeeded: high >> 32)
        )
    }
}

extension MotionSample {
    var packedLow: Int64 {
        field(gyroX, at: 0) | field(gyroY, at: 16) | field(gyroZ, at: 32) | field(accelX, at: 48)
    }

    var packedHigh: Int64 {
        field(accelY, at: 0) | field(accelZ, at: 16)
    }

    init(packedLow low: Int64, high: Int64) {
        self.init(
            gyroX: int16(low, at: 0),
            gyroY: int16(low, at: 16),
            gyroZ: int16(low, at: 32),
            accelX: int16(low, at: 48),
            accelY: int16(high, at: 0),
            accelZ: int16(high, at: 16)
        )
    }
}

extension TouchpadSample {
    var packedLow: Int64 {
        field(finger0.x, at: 0) | field(finger0.y, at: 16) | field(finger1.x, at: 32) | field(finger1.y, at: 48)
    }

    var packedHigh: Int64 {
        (finger0.active ? 1 : 0) | Int64(finger0.id) << 1 | (finger1.active ? 1 << 9 : 0) | Int64(finger1.id) << 10
            | (buttonPressed ? 1 << 18 : 0)
    }

    init(packedLow low: Int64, high: Int64) {
        self.init(
            finger0: TouchpadFinger(
                active: high & 1 != 0,
                id: UInt8(truncatingIfNeeded: high >> 1),
                x: int16(low, at: 0),
                y: int16(low, at: 16)
            ),
            finger1: TouchpadFinger(
                active: high & 1 << 9 != 0,
                id: UInt8(truncatingIfNeeded: high >> 10),
                x: int16(low, at: 32),
                y: int16(low, at: 48)
            ),
            buttonPressed: high & 1 << 18 != 0
        )
    }
}

extension GamepadInputProcessor.Deadzones {
    var packed: Int64 {
        field(stickFlat, at: 0) | Int64(triggerFlat) << 16
    }

    init(packed word: Int64) {
        self.init(stickFlat: int16(word, at: 0), triggerFlat: UInt8(truncatingIfNeeded: word >> 16))
    }
}
