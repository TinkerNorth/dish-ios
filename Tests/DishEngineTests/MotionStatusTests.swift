// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The satellite's motion word per binding: recorded from each apply's
/// `motion` object while the pad's slot is live, replaced by the next apply,
/// and gone with the binding, the pad's release and the satellite's Forget.
@MainActor
final class MotionStatusTests: XCTestCase {

    private var wifi: WifiConnectionManager!
    private var hub: ConnectionHub!
    private var conn: WifiConnection!
    private let den = DiscoveredServer(name: "Den", ip: "192.0.2.10", udpPort: 9876, machineId: "den")
    private var key: SlotKey {
        SlotKey(connectionId: den.id, slotId: "pad")
    }

    override func setUp() async throws {
        try await super.setUp()
        let defaults = try TestDefaults.fresh(self)
        let store = ConnectionStore(defaults: defaults, keyStore: InMemoryKeyStore(), pins: CertPins(file: nil))
        wifi = WifiConnectionManager(store: store, deviceName: testDeviceName)
        hub = ConnectionHub(wifi: wifi)
        conn = WifiConnection(id: den.id, server: den, tickIntervalNs: .max)
        wifi.register(conn)
        bindPad()
    }

    private func bindPad() {
        hub.bind(slotId: "pad", connectionId: den.id, capabilities: .none, emulateAs: .dualSense)
    }

    private func applied(sink: Bool, backend: Bool, result: String = "ok") throws -> ControllerApplyDto {
        let motion = "{\"sinkSupportedForType\":\(sink),\"backendOk\":\(backend)}"
        let json = "{\"ctrlIdx\":0,\"result\":\"\(result)\",\"appliedType\":2,\"motion\":\(motion)}"
        return try JSONDecoder().decode(ControllerApplyDto.self, from: Data(json.utf8))
    }

    func testAnAppliedSlotRecordsTheSatellitesMotionWord() throws {
        try wifi.recordSlotOutcome(applied(sink: true, backend: false), index: 0, conn: conn)
        XCTAssertEqual(wifi.motionStatus.statusFor(key), MotionBackendStatus(sinkSupportedForType: true, backendOk: false))
    }

    func testTheNextApplyReplacesTheWord() throws {
        try wifi.recordSlotOutcome(applied(sink: false, backend: true), index: 0, conn: conn)
        try wifi.recordSlotOutcome(applied(sink: true, backend: true), index: 0, conn: conn)
        XCTAssertEqual(wifi.motionStatus.statusFor(key), MotionBackendStatus(sinkSupportedForType: true, backendOk: true))
    }

    func testARefusedApplyRecordsNoWord() throws {
        try wifi.recordSlotOutcome(applied(sink: true, backend: true, result: "noSlots"), index: 0, conn: conn)
        XCTAssertNil(wifi.motionStatus.statusFor(key))
    }

    func testAReleasedPadHasNoWord() throws {
        try wifi.recordSlotOutcome(applied(sink: true, backend: true), index: 0, conn: conn)
        hub.release(slotId: "pad")
        XCTAssertNil(wifi.motionStatus.statusFor(key), "the pad left")
    }

    func testAnUnboundPadHasNoWord() throws {
        try wifi.recordSlotOutcome(applied(sink: true, backend: true), index: 0, conn: conn)
        hub.unbind(slotId: "pad")
        XCTAssertNil(wifi.motionStatus.statusFor(key), "the user let it go")
    }

    func testAPadMovedToAnotherPCLeavesNoWordOnTheFirst() throws {
        let loft = DiscoveredServer(name: "Loft", ip: "192.0.2.11", udpPort: 9876, machineId: "loft")
        wifi.register(WifiConnection(id: loft.id, server: loft, tickIntervalNs: .max))
        try wifi.recordSlotOutcome(applied(sink: true, backend: true), index: 0, conn: conn)
        hub.bind(slotId: "pad", connectionId: loft.id, capabilities: .none, emulateAs: .dualSense)
        XCTAssertNil(wifi.motionStatus.statusFor(key))
    }

    func testForgettingTheSatelliteDropsItsWords() throws {
        try wifi.recordSlotOutcome(applied(sink: true, backend: true), index: 0, conn: conn)
        wifi.forget(id: den.id)
        XCTAssertEqual(wifi.motionStatus.state, [:])
    }
}
