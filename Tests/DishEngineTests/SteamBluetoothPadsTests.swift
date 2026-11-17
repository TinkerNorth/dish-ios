// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import CoreBluetooth
import DishCore
import XCTest
@testable import DishEngine

/// A Steam Controller's pads, links, writes and claims, through a fake radio
/// on the links' own queue: the simulator has no Bluetooth.
@MainActor
final class SteamBluetoothPadsTests: XCTestCase {

    private static let input2015 = "100F6C33-1735-4313-B402-38567131E5F3"
    private static let input2026 = "100F6C7A-1735-4313-B402-38567131E5F3"
    private static let report = "100F6C34-1735-4313-B402-38567131E5F3"
    private static let rumble = "100F6CB5-1735-4313-B402-38567131E5F3"

    private let pad = UUID()

    private func spinUntil(_ predicate: () -> Bool, _ message: String) {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline, !predicate() {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate(), message)
    }

    /// The pad brought up through SDL's GATT flow, claimed by its first value.
    private func claim(_ rig: SteamRig, on radio: FakeSteamRadio, inputs: [String], first value: [UInt8]) {
        radio.pair([pad])
        radio.say(.poweredOn)
        radio.connected(pad)
        radio.servicesFound(pad)
        radio.characteristicsFound(pad, inputs)
        radio.notify(value, from: pad)
        spinUntil({ rig.pads.slots.map(\.id) == [steamSlotId(pad)] }, "the pad is claimed")
        rig.drain()
    }

    private func claimOriginal(_ rig: SteamRig, on radio: FakeSteamRadio) {
        claim(rig, on: radio, inputs: [Self.input2015, Self.report], first: SteamBlePacketBytes().buttons(0x80).values[0])
    }

    private func claimTriton(_ rig: SteamRig, on radio: FakeSteamRadio) {
        claim(rig, on: radio, inputs: [Self.input2026, Self.report, Self.rumble], first: TritonReportBytes.state(reportId: 0x45).value)
    }

    private func reports(_ rig: SteamRig) -> [GamepadReport] {
        rig.recorder.reports.filter { $0.id == steamSlotId(pad) }.map(\.report)
    }

    // MARK: - The opt-in

    func testNoRadioIsMadeUntilThePersonOptsIn() {
        let rig = SteamRig()
        rig.drain()
        XCTAssertEqual(rig.radios.count, 0, "no CoreBluetooth object, so no Bluetooth question")
        rig.pads.start()
        rig.drain()
        XCTAssertEqual(rig.radios.count, 1)
        rig.pads.start()
        rig.drain()
        XCTAssertEqual(rig.radios.count, 1, "one radio while it runs")
    }

    func testBluetoothsEveryWordReachesThePadsAndAStopForgetsIt() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        XCTAssertNil(rig.pads.radio, "before Bluetooth's first word")
        for state in [SteamRadioState.waiting, .poweredOn, .poweredOff, .unsupported, .denied, .restricted] {
            radio.say(state)
            spinUntil({ rig.pads.radio == state }, "\(state)")
        }
        rig.pads.stop()
        XCTAssertNil(rig.pads.radio)
    }

    func testCoreBluetoothsStateReadsAsTheLinksWordWithItsRefusalSplitByWhy() {
        XCTAssertEqual(steamRadioState(.poweredOn, authorization: .allowedAlways), .poweredOn)
        XCTAssertEqual(steamRadioState(.poweredOff, authorization: .allowedAlways), .poweredOff)
        XCTAssertEqual(steamRadioState(.unsupported, authorization: .notDetermined), .unsupported)
        XCTAssertEqual(steamRadioState(.unauthorized, authorization: .denied), .denied)
        XCTAssertEqual(steamRadioState(.unauthorized, authorization: .restricted), .restricted)
        XCTAssertEqual(steamRadioState(.unknown, authorization: .notDetermined), .waiting, "the question is up")
        XCTAssertEqual(steamRadioState(.resetting, authorization: .allowedAlways), .waiting)
    }

    // MARK: - The 2015 pad

    func testAPaired2015PadIsSubscribedQuietedAndItsSegmentsReachTheFeed() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        XCTAssertEqual(Array(radio.calls.prefix(4)), [
            .connect(pad), .discoverServices(pad), .discoverCharacteristics(pad), .subscribe(pad, Self.input2015)
        ])
        let quiet = steamBleConfigReports(.quiet).map { Array($0.dropFirst()) }
        XCTAssertEqual(radio.writes(to: Self.report, of: pad), quiet, "SDL's reset and sensor enable, each a 19-byte segment")
        let slot = try XCTUnwrap(rig.pads.slots.first)
        XCTAssertEqual(slot.name, "Valve Steam Controller (Bluetooth)")
        XCTAssertEqual(slot.link, .bluetooth)
        XCTAssertEqual(slot.trackpads, .rightStickByDefault)
        XCTAssertFalse(slot.capabilities.hasRumble, "no motors")
        XCTAssertTrue(slot.capabilities.hasExtendedButtons)
        let packet = SteamBlePacketBytes().buttons(0x0010).stick(x: 10000, y: -20000).rightPad(x: 0, y: 0).accel(1, 2, 3)
        XCTAssertEqual(packet.values.count, 2, "a packet over two segments")
        for value in packet.values {
            radio.notify(value, from: pad)
        }
        XCTAssertEqual(reports(rig).last, GamepadReport(buttons: WireButton.faceY.bit, lx: 10000, ly: -20000))
    }

    func testThe2015PadsRightTrackpadIsItsRightStickUntilPickedOtherwise() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        let rightPad = SteamBlePacketBytes().buttons(0x100000).rightPad(x: 0, y: 8000)
        rightPad.values.forEach { radio.notify($0, from: pad) }
        XCTAssertEqual(reports(rig).last?.ry, 7727, "the right pad, rotated back square, is the right stick")
        rig.pads.useTrackpadPick(.off, slotId: steamSlotId(pad))
        rig.drain()
        SteamBlePacketBytes().buttons(0x140000).rightPad(x: 0, y: 8000).values.forEach { radio.notify($0, from: pad) }
        XCTAssertEqual(reports(rig).last, GamepadReport(extButtons: ProtocolConstants.extButtonRightPadClick), "off: only the click")
    }

    // MARK: - The 2026 pad

    func testThe2026PadTurnsLizardModeOffAtTheClaimAndEveryThreeSeconds() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        XCTAssertEqual(Array(radio.calls.prefix(4)).last, .subscribe(pad, Self.input2026))
        let lizardOff = Array(tritonLizardOffReport().dropFirst())
        let sensorsOn = Array(tritonSensorsOnReport().dropFirst())
        XCTAssertEqual(radio.writes(to: Self.report, of: pad), [lizardOff, sensorsOn])
        rig.clock.advance(by: 2999, on: rig.queue)
        XCTAssertEqual(radio.writes(to: Self.report, of: pad).count, 2)
        rig.clock.advance(by: 1, on: rig.queue)
        XCTAssertEqual(radio.writes(to: Self.report, of: pad), [lizardOff, sensorsOn, lizardOff], "the watchdog would bring it back")
        rig.clock.advance(by: 3000, on: rig.queue)
        XCTAssertEqual(radio.writes(to: Self.report, of: pad).count, 4)
    }

    func testThe2026PadsReportsDecodeWithTheirExtraButtonsOnTheWire() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        var state = TritonReportBytes.state(0x0000_0001 | 0x0000_0080, reportId: 0x45)
        state.setLe16(10, -8000)
        state.setLe16(14, 12000)
        radio.notify(state.value, from: pad)
        XCTAssertEqual(
            reports(rig).last,
            GamepadReport(buttons: WireButton.faceA.bit, lx: -8000, rx: 12000, extButtons: ProtocolConstants.extButtonRightPaddle1),
            "R4 is SDL's right paddle 1"
        )
    }

    func testThe2026PadsRumbleIsWrittenEveryFortyMillisecondsWhileItRunsAndStopsWithIt() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        let feedback = rig.source.feedback.pad(for: steamSlotId(pad))
        let level = Array(tritonRumbleReport(left: 0x8000, right: 0x4000).dropFirst())
        let still = Array(tritonRumbleReport(left: 0, right: 0).dropFirst())
        feedback.post(rumbleStrong: 0x8000, weak: 0x4000, durationMs: 500)
        rig.drain()
        XCTAssertEqual(radio.writes(to: Self.rumble, of: pad), [level], "report 0x80 past its id, on its own characteristic")
        rig.clock.advance(by: 40, on: rig.queue)
        rig.clock.advance(by: 40, on: rig.queue)
        XCTAssertEqual(radio.writes(to: Self.rumble, of: pad), [level, level, level], "inside the firmware's safety stop")
        feedback.post(rumbleStrong: 0, weak: 0, durationMs: 0)
        rig.drain()
        rig.clock.advance(by: 200, on: rig.queue)
        XCTAssertEqual(radio.writes(to: Self.rumble, of: pad), [level, level, level, still], "the stop goes out once")
    }

    func testThe2026PadsTrackpadsAreTheTouchpadOncePickedSo() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        rig.pads.useTrackpadPick(.pad, slotId: steamSlotId(pad))
        rig.drain()
        var touched = TritonReportBytes.state(0x0200_0000, reportId: 0x45)
        touched.setLe16(18, 0)
        touched.setLe16(20, 1000)
        radio.notify(touched.value, from: pad)
        let touch = try XCTUnwrap(rig.recorder.touches.last?.sample)
        XCTAssertEqual(touch.finger0, TouchpadFinger(active: true, id: 1, x: -16384, y: -1000), "the left pad on the surface's left half")
        XCTAssertFalse(touch.finger1.active)
    }

    // MARK: - The claim's life

    func testADisconnectEndsTheClaim() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        radio.lose(pad)
        spinUntil({ rig.pads.slots.isEmpty }, "the pad leaves the list")
        XCTAssertNil(rig.source.processor.latestInput(steamSlotId(pad)), "its feed is gone")
    }

    func testAPadThatWakesAgainGetsANewClaim() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        radio.lose(pad)
        spinUntil({ rig.pads.slots.isEmpty }, "the pad went to sleep")
        rig.clock.advance(by: 5000, on: rig.queue)
        XCTAssertEqual(radio.calls.filter { $0 == .connect(pad) }.count, 2, "the next look finds it connected again")
        radio.connected(pad)
        radio.servicesFound(pad)
        radio.characteristicsFound(pad, [Self.input2015, Self.report])
        radio.notify(SteamBlePacketBytes().buttons(0x80).values[0], from: pad)
        spinUntil({ rig.pads.slots.count == 1 }, "a new claim")
        XCTAssertEqual(radio.writes(to: Self.report, of: pad).count, 8, "quieted again: it rebooted")
    }

    func testBluetoothTurnedOffEndsEveryClaim() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimTriton(rig, on: radio)
        radio.say(.poweredOff)
        spinUntil({ rig.pads.slots.isEmpty && rig.pads.radio == .poweredOff }, "no pad without Bluetooth")
    }

    func testThePermissionTakenAwayEndsEveryClaim() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        radio.say(.denied)
        spinUntil({ rig.pads.slots.isEmpty && rig.pads.radio == .denied }, "no pad without the permission")
        XCTAssertEqual(radio.writes(to: Self.report, of: pad).count, 4, "nothing more reaches a pad out of reach")
    }

    func testAPeripheralWithoutValvesServiceIsLetGoWithNoClaim() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        radio.pair([pad])
        radio.say(.poweredOn)
        radio.connected(pad)
        radio.servicesFound(pad, valve: false)
        XCTAssertEqual(radio.calls.last, .disconnect(pad))
        rig.clock.advance(by: 5000, on: rig.queue)
        XCTAssertEqual(radio.calls.last, .connect(pad), "looked for again, as SDL looks")
    }

    func testTurningItOffGivesThe2015PadBackAndLetsTheCentralGoOnceThePadHadTimeToAnswer() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        rig.pads.stop()
        XCTAssertEqual(rig.pads.slots, [], "the list empties at once")
        rig.drain()
        let restore = steamBleConfigReports(.restore).map { Array($0.dropFirst()) }
        XCTAssertEqual(Array(radio.writes(to: Self.report, of: pad).suffix(3)), restore, "SDL's close sequence")
        XCTAssertFalse(radio.calls.contains(.close))
        rig.clock.advance(by: 1000, on: rig.queue)
        XCTAssertEqual(radio.calls.last, .close)
    }

    func testARadioLettingItsPadsAnswerAfterAStopTakesNoNewPad() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        rig.pads.stop()
        rig.drain()
        radio.pair([pad])
        radio.say(.poweredOn)
        XCTAssertFalse(radio.calls.contains(.connect(pad)), "nothing is quieted that no stop would give back")
    }

    // MARK: - The battery rule

    func testAPadWithNoReadingOfItsOwnSendsTheDevicesBatteryOnTheCadence() throws {
        let rig = SteamRig()
        let radio = try rig.started()
        claimOriginal(rig, on: radio)
        rig.batteryTicker.fire()
        XCTAssertEqual(rig.recorder.batteries.map(\.id), [steamSlotId(pad)])
        XCTAssertEqual(rig.recorder.batteries.last?.reading, rig.device.reading, "the iPhone's battery")
        radio.lose(pad)
        spinUntil({ rig.pads.slots.isEmpty }, "the pad left")
        XCTAssertFalse(rig.batteryTicker.running, "no cadence without the pad")
    }
}

/// The Steam pads over a fake radio, a clock the test moves, and a recorder
/// as every pad's route.
@MainActor
private final class SteamRig {
    let source = FakeControllerSource()
    let radios = FakeSteamRadios()
    let clock = ManualSteamClock()
    let recorder = InputRecorder()
    let device = FakeDeviceBattery(BatteryReading(level: 40, state: .discharging))
    let batteryTicker = ManualTicker()
    let pads: SteamBluetoothPads

    init() {
        let radios = radios
        pads = SteamBluetoothPads(
            processor: source.processor,
            feedback: source.feedback,
            makeRadio: { radios.make($0, $1) },
            clock: clock,
            batteryTicker: batteryTicker,
            deviceBattery: device
        )
        source.processor.route(recorder.route)
    }

    var queue: DispatchSerialQueue {
        pads.links.queue
    }

    /// Everything posted to the links' queue so far has run.
    func drain() {
        queue.sync {}
    }

    func started() throws -> FakeSteamRadio {
        pads.start()
        drain()
        return try XCTUnwrap(radios.last)
    }
}
