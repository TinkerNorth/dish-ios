// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The readings a report adds to the bundle: the person's words, the
/// device's conditions, each controller path's input and output with the
/// rumble's target, and each host's session and snapshot, a Moonlight
/// host's from its serverinfo without its name.
@MainActor
final class DiagnosticsBundleReadingsTests: XCTestCase {

    private static let xbox = ControllerFact(
        id: "gc:xbox",
        name: "Xbox Wireless Controller",
        link: .bluetooth,
        batteryPercent: nil,
        destination: nil,
        features: [ControllerFeatureFact(feature: .rumble, enabled: true)],
        source: .gameController(category: "Xbox One")
    )

    private static let silentPad = ControllerFact(
        id: "gc:silent",
        name: "8BitDo Lite",
        link: .bluetooth,
        batteryPercent: nil,
        destination: nil,
        source: .gameController(category: "8BitDo")
    )

    private static let rumbled = PadOutputReading(
        rumble: LaneReading(total: 3, packed: Int64(40000) << 32 | Int64(100) << 16 | 50, atMs: 9000),
        lightbar: .none,
        player: LaneReading(total: 1, packed: 2, atMs: 8000),
        triggerEffects: LaneReading(total: 4, packed: 0, atMs: 7000)
    )

    private static let moonlightName = "Living Room Sunshine"

    private func facts(
        controllers: [ControllerFact] = [],
        hosts: [HostDiagnostics] = [],
        paths: [String: PadPathReading] = [:],
        readings: [String: HostReading] = [:],
        report: BundleReport? = nil,
        conditions: BundleConditions = .unknown
    ) -> DiagnosticsBundleFacts {
        DiagnosticsBundleFacts(
            createdAtMs: 0,
            identity: .unknown,
            controllerDb: ControllerDbStatus(bundledVersion: 1, activeVersion: 1, source: .bundled, checksEnabled: true),
            controllers: controllers,
            hosts: hosts,
            events: [],
            report: report,
            conditions: conditions,
            paths: paths,
            hostReadings: readings
        )
    }

    func testTheReportIsThePersonsOwn() {
        let report = BundleReport(category: .audio, text: "No sound", controller: nil)
        XCTAssertEqual(diagnosticsBundle(facts(report: report)).report, report)
    }

    func testTheDeviceCarriesItsConditions() {
        let conditions = BundleConditions(battery: BundleBattery(level: 20, charging: false), thermal: .critical, powerSave: true)
        XCTAssertEqual(diagnosticsBundle(facts(conditions: conditions)).device.conditions, conditions)
    }

    func testABatteryOnItsCableIsOnPowerWhetherChargingOrFull() {
        XCTAssertEqual(bundleBattery(BatteryReading(level: 100, state: .full)), BundleBattery(level: 100, charging: true))
        XCTAssertEqual(bundleBattery(BatteryReading(level: 50, state: .charging)), BundleBattery(level: 50, charging: true))
        XCTAssertEqual(bundleBattery(BatteryReading(level: 50, state: .discharging)), BundleBattery(level: 50, charging: false))
        XCTAssertNil(bundleBattery(nil))
    }

    func testAPathCarriesItsFramesRateLastStateAndLanes() throws {
        let path = PadPathReading(frames: 900, rateHz: 125, last: GamepadReport(buttons: 0x0010, rt: 9), output: Self.rumbled)
        let pad = try XCTUnwrap(diagnosticsBundle(facts(controllers: [Self.xbox], paths: [Self.xbox.id: path])).controllers.first)
        XCTAssertEqual(pad.input, BundleInput(frames: 900, rateHz: 125, last: BundleInputState(GamepadReport(buttons: 0x0010, rt: 9))))
        let output = try XCTUnwrap(pad.output)
        XCTAssertEqual(output.rumbleTarget, .framework)
        XCTAssertEqual(output.rumble, BundleLane(count: 3, last: BundleRumble(strong: 40000, weak: 100, atMs: 9000)))
        XCTAssertEqual(output.lightbar, BundleLane(count: 0, last: nil))
        XCTAssertEqual(output.playerLeds, BundleLane(count: 1, last: BundlePlayer(player: 2, atMs: 8000)))
        XCTAssertEqual(output.triggerEffects, BundleCount(count: 4))
    }

    func testAPadWithoutMotorsRumblesNothing() throws {
        let path = PadPathReading(frames: 0, rateHz: nil, last: nil, output: .none)
        let pad = try XCTUnwrap(diagnosticsBundle(facts(controllers: [Self.silentPad], paths: [Self.silentPad.id: path])).controllers.first)
        XCTAssertEqual(pad.output?.rumbleTarget, BundleRumbleTarget.none)
    }

    func testAPathNotReadIsNull() throws {
        let pad = try XCTUnwrap(diagnosticsBundle(facts(controllers: [Self.xbox])).controllers.first)
        XCTAssertNil(pad.input)
        XCTAssertNil(pad.output)
    }

    func testTheRumbleTargetFollowsThePath() {
        XCTAssertEqual(rumbleTarget(path: .virtual, hasRumble: true), .phone)
        XCTAssertEqual(rumbleTarget(path: .gameController, hasRumble: true), .framework)
        XCTAssertEqual(rumbleTarget(path: .gameController, hasRumble: false), BundleRumbleTarget.none)
        XCTAssertEqual(rumbleTarget(path: .bluetooth, hasRumble: true), .directBle)
    }

    func testAHostCarriesItsReadingAndASatellitesVersion() throws {
        let host = HostDiagnostics(
            summary: ConnectionSummary(id: "sat", name: "Den PC", address: "10.0.0.2", udpPort: 9876, live: .connected, kind: .satellite),
            facts: .resting(id: "sat"),
            counters: .none
        )
        let session = BundleSession(slots: [], ack: nil, rtt: nil, sent: nil, received: nil)
        let snapshot = BundleHostSnapshot(snapshot: .object([:]), error: .timeout)
        let reading = HostReading(version: "2.2.0", session: session, snapshot: snapshot)
        let entry = try XCTUnwrap(diagnosticsBundle(facts(hosts: [host], readings: ["sat": reading])).hosts.first)
        XCTAssertEqual(entry.version, "2.2.0")
        XCTAssertEqual(entry.session, session)
        XCTAssertEqual(entry.snapshot, snapshot)
    }

    func testWhateverTheHostAnsweredNamesItByItsAlias() throws {
        let host = HostDiagnostics(
            summary: ConnectionSummary(id: "sat", name: "Den PC", address: "10.0.0.2", udpPort: 9876, live: .connected, kind: .satellite),
            facts: .resting(id: "sat"),
            counters: .none
        )
        let answered = JSONValue.object(["requester": .string("Den PC at 10.0.0.2")])
        let reading = HostReading(session: nil, snapshot: BundleHostSnapshot(snapshot: answered, error: nil))
        let entry = try XCTUnwrap(diagnosticsBundle(facts(hosts: [host], readings: ["sat": reading])).hosts.first)
        XCTAssertEqual(entry.snapshot.snapshot, .object(["requester": .string("Host 1 at Host 1")]))
    }

    func testAMoonlightSessionCarriesItsPadsRoundTripAndReports() throws {
        let facts = MoonlightHostDiagnostics(
            phase: .streaming,
            appName: "Desktop",
            controlRoundTripMs: 6,
            info: nil,
            pads: [MoonlightPadFacts(number: 0, slotId: "gc:xbox", type: 1, reports: 40)]
        )
        let session = try XCTUnwrap(moonlightSessionBundle(facts, records: ["gc:xbox": "microsoft-xbox"]))
        XCTAssertEqual(session.slots, [
            BundleSessionSlot(
                index: 0,
                record: "microsoft-xbox",
                requestedType: "1",
                appliedType: nil,
                backend: nil,
                result: nil,
                touchpadMode: nil
            )
        ])
        XCTAssertEqual(session.rtt, BundleRtt(p50Ms: 6, p99Ms: nil, samples: nil))
        XCTAssertEqual(session.sent?.input, 40)
        XCTAssertNil(session.received, "the client counts no host messages")
    }

    func testAnIdleMoonlightHostHasNoSession() {
        XCTAssertNil(moonlightSessionBundle(.resting(info: nil), records: [:]))
    }
}
