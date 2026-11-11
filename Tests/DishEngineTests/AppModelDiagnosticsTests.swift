// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A model whose diagnostics tick, its rate clock and its pasteboard the
/// test drives, over a LAN with nothing on it.
@MainActor
private struct DiagnosedModel {
    let model: AppModel
    let source: FakeControllerSource
    let ticker = ManualTicker()
    let uptime = ManualUptime()
    let pasteboard = RecordedPasteboard()

    init(_ test: XCTestCase, pads: [ControllerSlot] = []) throws {
        let defaults = try TestDefaults.fresh(test)
        source = FakeControllerSource(slots: pads)
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: source, defaults: defaults),
            network: TestNetwork.stack(defaults: defaults),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker(),
            diagnostics: DiagnosticsSource(ticker: ticker, clockUs: uptime.readMicroseconds),
            pasteboard: pasteboard
        )
    }

    var snapshot: DiagnosticsSnapshot {
        model.shellFacts.diagnostics
    }

    var events: [DiagnosticsEvent] {
        model.shellFacts.diagnosticsEvents
    }
}

extension ManualUptime {
    func readMicroseconds() -> UInt64 {
        nanoseconds / 1000
    }
}

/// Diagnostics through the model: the source reads a snapshot and ticks
/// only while its page shows, the rates come off the pads' records, Copy
/// reaches the pasteboard seam, and the flight recorder follows the
/// controllers as they come.
@MainActor
final class AppModelDiagnosticsTests: XCTestCase {

    private static let dualSense = ControllerSlot(
        id: "pad",
        name: "DualSense Wireless Controller",
        link: .usbC,
        capabilities: ControllerCapabilities(hasMotion: true, hasRumble: true, hasBattery: true),
        battery: BatteryReading(level: 84, state: .discharging),
        family: .dualSense
    )

    private func settled(_ predicate: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return predicate()
    }

    func testTheSourceIsIdleAndEmptyUntilThePageShows() throws {
        let diagnosed = try DiagnosedModel(self, pads: [Self.dualSense])
        XCTAssertEqual(diagnosed.ticker.starts, [])
        XCTAssertEqual(diagnosed.snapshot, DiagnosticsSnapshot())
    }

    func testDiagnosticsAppearingReadsASnapshotAndStartsTheTick() throws {
        let diagnosed = try DiagnosedModel(self, pads: [Self.dualSense])
        diagnosed.model.pageAppeared(.diagnostics)
        XCTAssertEqual(diagnosed.ticker.starts, [1])
        XCTAssertEqual(diagnosed.snapshot.hosts, [], "nothing is paired")
        let pad = try XCTUnwrap(diagnosed.snapshot.pads.first)
        XCTAssertEqual(pad.controller.id, "pad")
        XCTAssertEqual(pad.controller.batteryPercent, 84)
        XCTAssertEqual(pad.rates, PadRates(reportHz: 0, motionHz: 0))
        XCTAssertNil(pad.wire, "unbound, so nothing is on the wire")
        XCTAssertNil(diagnosed.snapshot.locks, "a plain build counts no locks")
    }

    func testATickReadsEachPadsRateOffItsRecord() throws {
        let diagnosed = try DiagnosedModel(self, pads: [Self.dualSense])
        diagnosed.model.pageAppeared(.diagnostics)
        let feed = diagnosed.source.processor.feed(for: "pad")
        for buttons in 1 ... 10 {
            feed.publish(GamepadReport(buttons: UInt16(buttons)))
        }
        diagnosed.uptime.nanoseconds += 1_000_000_000
        diagnosed.ticker.fire()
        XCTAssertEqual(diagnosed.snapshot.pads.first?.rates, PadRates(reportHz: 10, motionHz: 0))
        XCTAssertEqual(diagnosed.snapshot.pads.first?.reports, 10)
    }

    func testATickReadsEachPadsTouchRateOffItsRecord() throws {
        let diagnosed = try DiagnosedModel(self, pads: [Self.dualSense])
        diagnosed.model.pageAppeared(.diagnostics)
        let feed = diagnosed.source.processor.feed(for: "pad")
        for _ in 0 ..< 10 {
            feed.publishTouchpad(TouchpadSample(finger0: .none, finger1: .none, buttonPressed: false))
        }
        diagnosed.uptime.nanoseconds += 1_000_000_000
        diagnosed.ticker.fire()
        XCTAssertEqual(diagnosed.snapshot.pads.first?.rates, PadRates(reportHz: 0, motionHz: 0, touchHz: 10))
    }

    func testTheControllerPageTicksTheSameSourceWhileItShows() throws {
        let diagnosed = try DiagnosedModel(self, pads: [Self.dualSense])
        diagnosed.model.pageAppeared(.controller)
        XCTAssertEqual(diagnosed.ticker.starts, [1])
        XCTAssertEqual(diagnosed.snapshot.pads.first?.controller.id, "pad")
        diagnosed.model.pageDisappeared(.controller)
        XCTAssertFalse(diagnosed.ticker.running)
    }

    func testDiagnosticsDisappearingStopsTheTick() throws {
        let diagnosed = try DiagnosedModel(self)
        diagnosed.model.pageAppeared(.diagnostics)
        XCTAssertTrue(diagnosed.ticker.running)
        diagnosed.model.pageDisappeared(.diagnostics)
        XCTAssertFalse(diagnosed.ticker.running)
    }

    func testCopyReachesThePasteboardSeam() throws {
        let diagnosed = try DiagnosedModel(self)
        diagnosed.model.copyToPasteboard("the report")
        XCTAssertEqual(diagnosed.pasteboard.copies, ["the report"])
    }

    func testTheRecorderLogsAPadAsItComesAndGoes() async throws {
        let diagnosed = try DiagnosedModel(self)
        XCTAssertEqual(diagnosed.events, [], "nothing paired and nothing attached is an empty inventory")
        diagnosed.source.slots = [Self.dualSense]
        let attached = await settled { diagnosed.events.map(\.kind) == [.padAttached] }
        XCTAssertTrue(attached, "\(diagnosed.events)")
        XCTAssertEqual(diagnosed.events.first?.subject, "DualSense Wireless Controller")
        diagnosed.source.slots = []
        let detached = await settled { diagnosed.events.map(\.kind) == [.padAttached, .padDetached] }
        XCTAssertTrue(detached, "\(diagnosed.events)")
    }

    func testTheOnScreenGamepadIsLoggedAsItself() async throws {
        let diagnosed = try DiagnosedModel(self)
        diagnosed.model.openPlay(.gamepad)
        let listed = await settled { diagnosed.events.map(\.kind) == [.padAttached] }
        XCTAssertTrue(listed, "\(diagnosed.events)")
        XCTAssertEqual(diagnosed.events.first?.subject, .onScreenGamepad)
        diagnosed.model.closePlay()
    }
}

/// Diagnostics over a live satellite: the session's card carries its
/// counters and its round trips, the bound pad its side of the wire, and
/// the recorder its link coming up and the pad binding.
@MainActor
final class AppModelDiagnosticsSessionTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        try await super.setUp()
        fixture = try SatelliteModelFixture(self)
    }

    override func tearDown() async throws {
        fixture?.model.pageDisappeared(.diagnostics)
        fixture?.tearDown()
        fixture = nil
        try await super.tearDown()
    }

    func testALiveSessionTellsItsCountersAndItsBoundPad() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let applied = await fixture.waitUntil { self.fixture.model.bindingProgress == .done }
        XCTAssertTrue(applied)
        let measured = await fixture.waitUntil(timeout: 8) { self.fixture.model.shellFacts.session?.latencyMs != nil }
        XCTAssertTrue(measured, "the window seeds from the heartbeat acks")
        fixture.model.pageAppeared(.diagnostics)
        let host = try XCTUnwrap(fixture.model.shellFacts.diagnostics.hosts.first)
        XCTAssertEqual(host.summary.name, "Den PC")
        XCTAssertTrue(host.facts.live)
        XCTAssertEqual(host.facts.settledProtocol, ProtocolConstants.protocolVersion)
        XCTAssertGreaterThan(host.counters.sent, 0, "the heartbeat left at once")
        XCTAssertGreaterThan(host.counters.received, 0, "its ack came back")
        XCTAssertEqual(host.counters.replayGuard, host.counters.received, "every datagram so far was fresh")
        XCTAssertGreaterThan(host.facts.latency.samples, 0)
        let pad = try XCTUnwrap(fixture.model.shellFacts.diagnostics.pads.first)
        XCTAssertEqual(pad.controller.destination?.name, "Den PC")
        XCTAssertEqual(pad.wire?.controllerIndex, 0)
        XCTAssertEqual(pad.wire?.confirmed, true)
        let kinds = fixture.model.shellFacts.diagnosticsEvents.map(\.kind)
        XCTAssertTrue(kinds.contains(.linkChanged), "the link came up: \(kinds)")
        XCTAssertTrue(kinds.contains(.padBound), "the pad bound: \(kinds)")
    }
}
