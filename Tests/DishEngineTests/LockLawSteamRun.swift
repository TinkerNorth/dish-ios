// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

#if LOCK_STATS
import Darwin
import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The Steam Controllers' run for `LockLawTests`: a claimed 2026 pad's
/// values delivered on the links' queue as CoreBluetooth delivers them, each
/// decoded and sent through a live `SatelliteClient`, and a satellite's
/// rumble drained on the same queue into the pad's writes.
@MainActor
struct LockLawSteamRun {
    let snapshot: LockStatsSnapshot
    let uplinks: UInt32
    let rumbles: Int

    private static let input = "100F6C7A-1735-4313-B402-38567131E5F3"
    private static let report = "100F6C34-1735-4313-B402-38567131E5F3"
    private static let rumble = "100F6CB5-1735-4313-B402-38567131E5F3"
    private static let frames = 500
    private static let rumbleEvery = 50

    static func run() throws -> LockLawSteamRun {
        let (fd, port) = try XCTUnwrap(DataPlaneTestHelpers.bindLoopbackSocket())
        defer { close(fd) }
        let client = try XCTUnwrap(DataPlaneTestHelpers.makeClient(port: port))
        defer { client.closeSocket() }
        let source = FakeControllerSource()
        let radios = FakeSteamRadios()
        let pads = SteamBluetoothPads(
            processor: source.processor,
            feedback: source.feedback,
            makeRadio: { radios.make($0, $1) },
            clock: ManualSteamClock(),
            batteryTicker: ManualTicker()
        )
        source.processor.route { _ in Route(sink: client, slot: 0, flags: ForwardingFlags()) }
        let pad = UUID()
        let radio = try claimed(pad, pads: pads, radios: radios)
        resetLockStats()
        let feedback = source.feedback.pad(for: steamSlotId(pad))
        for frame in 0 ..< frames {
            let state = TritonReportBytes.state(UInt32(frame % 2), reportId: 0x45, imuTick: UInt32(frame + 1))
            radio.notify(state.value, from: pad)
            if frame % rumbleEvery == 0 { feedback.post(rumbleStrong: 30000, weak: 10000, durationMs: 100) }
        }
        pads.links.queue.sync {}
        return LockLawSteamRun(snapshot: lockStatsSnapshot(), uplinks: client.sendCounter, rumbles: radio.writes(to: rumble, of: pad).count)
    }

    /// The pad brought up through SDL's GATT flow, claimed and handed its feed.
    private static func claimed(_ pad: UUID, pads: SteamBluetoothPads, radios: FakeSteamRadios) throws -> FakeSteamRadio {
        pads.start()
        pads.links.queue.sync {}
        let radio = try XCTUnwrap(radios.last)
        radio.pair([pad])
        radio.say(.poweredOn)
        radio.connected(pad)
        radio.servicesFound(pad)
        radio.characteristicsFound(pad, [input, report, rumble])
        radio.notify(TritonReportBytes.state(reportId: 0x45).value, from: pad)
        let giveUp = Date().addingTimeInterval(2)
        while pads.slots.isEmpty, Date() < giveUp {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertFalse(pads.slots.isEmpty, "the pad is claimed")
        pads.links.queue.sync {}
        return radio
    }
}
#endif
