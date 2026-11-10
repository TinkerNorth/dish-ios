// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The hot path of one Moonlight session: the pad table and the live sender
// under one lock. Input arrives on the controller callback threads, the
// host's motion requests on the transport's queue, and the table's changes
// on the main actor; all three read and write the same table. What to send
// is decided under the lock and sent outside it, so a sender that takes its
// own lock never nests inside this one.

import DishCore
import Foundation

/// What the link sends on: the control session in production, a recorder in tests.
protocol MoonlightPadSending: AnyObject, Sendable {
    func sendControllerState(_ frame: MoonlightInput.PadFrame)
    func sendControllerArrival(_ arrival: MoonlightInput.PadArrival)
    func sendControllerReplug(number: UInt8, otherPadsMask: UInt16, arrival: MoonlightInput.PadArrival)
    func sendControllerTouch(controller: UInt8, emission: MoonlightTouchEmission)
    func sendControllerMotion(controller: UInt8, type: UInt8, x: Float, y: Float, z: Float)
    func sendControllerBattery(controller: UInt8, state: UInt8, percentage: UInt8)
}

extension MoonlightControlSession: MoonlightPadSending {}

final class MoonlightPadLink: Sendable {
    /// What the lock guards: the table, the live sender, the frames sent per number.
    private struct Held {
        var table = MoonlightPadTable()
        var sender: (any MoonlightPadSending)?
        var sentByNumber = [Int](repeating: 0, count: MoonlightProtocol.maxPads)
    }

    /// A pad to announce on a live sender, decided under the lock.
    private struct Announcement {
        let pad: MoonlightPadTable.Pad
        let mask: UInt16
        let live: any MoonlightPadSending
    }

    /// One frame for a live sender, decided under the lock.
    private struct FrameOut {
        let live: any MoonlightPadSending
        let frame: MoonlightInput.PadFrame
    }

    private let held = TrackedLock(Held(), "moonlight.padLink")
    private let nowNs: @Sendable () -> Int64

    init(nowNs: @escaping @Sendable () -> Int64 = { Int64(DispatchTime.now().uptimeNanoseconds) }) {
        self.nowNs = nowNs
    }

    // MARK: - The table

    var pads: [MoonlightPadTable.Pad] {
        held.withLock { $0.table.pads }
    }

    var activeMask: UInt16 {
        held.withLock { $0.table.activeMask }
    }

    var count: Int {
        held.withLock { $0.table.count }
    }

    var isFull: Bool {
        held.withLock { $0.table.isFull }
    }

    var isLive: Bool {
        held.withLock { $0.sender != nil }
    }

    func pad(for slotId: String) -> MoonlightPadTable.Pad? {
        held.withLock { $0.table.pad(for: slotId) }
    }

    /// The slot behind the number a host event names; a number no session
    /// can carry names none.
    func slot(forController controller: UInt16) -> String? {
        guard controller < UInt16(MoonlightProtocol.maxPads) else { return nil }
        return held.withLock { $0.table.slot(for: UInt8(controller)) }
    }

    func motionWanted(_ slotId: String) -> Bool {
        held.withLock { $0.table.motionWanted(slotId) }
    }

    /// Frames sent for the pad at this number since the link came up.
    func reportsSent(for number: UInt8) -> Int {
        guard Int(number) < MoonlightProtocol.maxPads else { return 0 }
        return held.withLock { $0.sentByNumber[Int(number)] }
    }

    /// Take the lowest free number for the slot, announcing the pad at rest
    /// when the link is live; the pad a slot holds already is kept and not
    /// announced again. Nil when the session carries its four.
    func acquire(_ slotId: String, as wanted: MoonlightAnnouncedPad) -> MoonlightPadTable.Pad? {
        let (pad, announcement) = held.withLock { held -> (MoonlightPadTable.Pad?, Announcement?) in
            let before = held.table.pad(for: slotId)
            let pad = held.table.acquire(slotId, as: wanted)
            guard let pad, before == nil, let live = held.sender else { return (pad, nil) }
            return (pad, Announcement(pad: pad, mask: held.table.activeMask, live: live))
        }
        if let announcement { announce(announcement) }
        return pad
    }

    /// Drop the slot's pad. The frame that names its number with its bit
    /// cleared is the unplug (Wolf drops the pad on that frame and on no
    /// other), and the number is free once it has gone out. Returns how
    /// many pads remain.
    func release(_ slotId: String) -> Int {
        let (remaining, unplug) = held.withLock { held -> (Int, FrameOut?) in
            let number = held.table.release(slotId)
            let remaining = held.table.count
            guard let number, let live = held.sender else { return (remaining, nil) }
            return (remaining, FrameOut(live: live, frame: MoonlightInput.PadFrame(controller: number, activeMask: held.table.activeMask)))
        }
        if let unplug { unplug.live.sendControllerState(unplug.frame) }
        return remaining
    }

    /// The slot's pad as another pad under its number. On a live link the
    /// host unplugs the number and plugs the new pad in, then hears it at
    /// rest; before, only the table changes and the install announces it.
    func reannounce(_ slotId: String, as wanted: MoonlightAnnouncedPad) -> MoonlightPadTable.Pad? {
        let (pad, replug) = held.withLock { held -> (MoonlightPadTable.Pad?, Announcement?) in
            let pad = held.table.reannounce(slotId, as: wanted)
            guard let pad, let live = held.sender else { return (pad, nil) }
            return (pad, Announcement(pad: pad, mask: held.table.activeMask, live: live))
        }
        if let replug {
            let others = replug.mask & ~(UInt16(1) << UInt16(replug.pad.number))
            replug.live.sendControllerReplug(number: replug.pad.number, otherPadsMask: others, arrival: replug.pad.arrival)
            replug.live.sendControllerState(MoonlightInput.PadFrame(controller: replug.pad.number, activeMask: replug.mask))
        }
        return pad
    }

    // MARK: - The session

    /// Adopt a connected session: every held pad is announced on it, at rest.
    func install(_ live: any MoonlightPadSending) {
        let (pads, mask) = held.withLock { held -> ([MoonlightPadTable.Pad], UInt16) in
            held.sender = live
            return (held.table.pads, held.table.activeMask)
        }
        for pad in pads {
            announce(Announcement(pad: pad, mask: mask, live: live))
        }
    }

    /// The session is gone: the pads stay claimed, what the host asked of
    /// or was told about them is forgotten, the counts start over.
    func clear() {
        held.withLock { held in
            held.sender = nil
            held.table.forgetHostState()
            held.sentByNumber = [Int](repeating: 0, count: MoonlightProtocol.maxPads)
        }
    }

    private func announce(_ announcement: Announcement) {
        announcement.live.sendControllerArrival(announcement.pad.arrival)
        announcement.live.sendControllerState(MoonlightInput.PadFrame(controller: announcement.pad.number, activeMask: announcement.mask))
    }

    // MARK: - HOT PATH (controller callback threads)

    func sendReport(_ slotId: String, _ report: GamepadReport) {
        let out = held.withLock { held -> FrameOut? in
            guard let live = held.sender, let frame = held.table.frame(slotId, report: report) else { return nil }
            held.sentByNumber[Int(frame.controller)] += 1
            return FrameOut(live: live, frame: frame)
        }
        guard let out else { return }
        out.live.sendControllerState(out.frame)
    }

    func sendTouchpad(_ slotId: String, sample: TouchpadSample) {
        let out = held.withLock { held -> (any MoonlightPadSending, MoonlightPadTable.TouchOut)? in
            guard let live = held.sender, let touch = held.table.touch(slotId, sample: sample) else { return nil }
            if touch.replay != nil { held.sentByNumber[Int(touch.controller)] += 1 }
            return (live, touch)
        }
        guard let out else { return }
        if let replay = out.1.replay { out.0.sendControllerState(replay) }
        for emission in out.1.emissions {
            out.0.sendControllerTouch(controller: out.1.controller, emission: emission)
        }
    }

    func sendMotion(_ slotId: String, _ sample: MotionSample) {
        let out = held.withLock { held -> (any MoonlightPadSending, [MoonlightPadTable.MotionOut])? in
            guard let live = held.sender else { return nil }
            return (live, held.table.motion(slotId, sample: sample, nowNs: nowNs()))
        }
        guard let out else { return }
        for packet in out.1 {
            out.0.sendControllerMotion(controller: packet.controller, type: packet.type, x: packet.x, y: packet.y, z: packet.z)
        }
    }

    func sendBattery(_ slotId: String, level: UInt8, status: BatteryStatus) {
        let out = held.withLock { held -> (any MoonlightPadSending, MoonlightPadTable.BatteryOut)? in
            guard let live = held.sender, let battery = held.table.battery(slotId, level: level, status: status) else { return nil }
            return (live, battery)
        }
        guard let out else { return }
        out.0.sendControllerBattery(controller: out.1.controller, state: out.1.state, percentage: out.1.percentage)
    }

    /// MOTION_EVENT from the host, on the transport's queue.
    func onMotionRequest(controller: UInt16, rateHz: UInt16, type: UInt8) {
        guard controller < UInt16(MoonlightProtocol.maxPads) else { return }
        held.withLock { $0.table.onMotionRequest(controller: UInt8(controller), rateHz: rateHz, type: type) }
    }
}

/// One pad on a Moonlight host, as the routing table targets it: the slot's
/// input onto the host's link, which knows the pad's number; the index the
/// route carries is that number, for the record, and nothing reads it here.
final class MoonlightPadSink: PadSink {
    let link: MoonlightPadLink
    let slotId: String

    init(link: MoonlightPadLink, slotId: String) {
        self.link = link
        self.slotId = slotId
    }

    func send(_ report: GamepadReport, slot _: SlotIndex) {
        link.sendReport(slotId, report)
    }

    /// The host paces motion itself, per pad and type; the satellite's
    /// timestamp delta has no field on this wire.
    func send(_ motion: MotionSample, timestampDeltaUs _: UInt32, slot _: SlotIndex) {
        link.sendMotion(slotId, motion)
    }

    func send(_ touch: TouchpadSample, eventTimeMs _: UInt32, slot _: SlotIndex) {
        link.sendTouchpad(slotId, sample: touch)
    }

    /// A reading without a level says the percentage is unknown; the state still goes.
    func send(battery: BatteryReading, slot _: SlotIndex) {
        let level = battery.level.map { UInt8(clamping: $0) } ?? MoonlightBatteryState.percentageUnknown
        link.sendBattery(slotId, level: level, status: wireBatteryStatus(battery.state))
    }
}
