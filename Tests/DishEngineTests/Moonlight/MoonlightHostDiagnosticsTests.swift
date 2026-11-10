// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// A Moonlight host's row in the Diagnostics source: resting on its probe
/// until a connection exists this run, then read off the connection.
@MainActor
final class MoonlightHostDiagnosticsTests: XCTestCase {
    private var moonlight: MoonlightConnectionManager!
    private var store: ConnectionStore!
    private var model: AppModel!
    private let host = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")
    private let xbox = MoonlightAnnouncedPad(type: MoonlightControllerType.xbox, capabilities: 0x03, supportedButtons: 0xF7FF)

    override func setUp() async throws {
        try await super.setUp()
        let defaults = try TestDefaults.fresh(self)
        moonlight = TestNetwork.scriptedMoonlight(defaults: defaults)
        var record = RememberedMoonlightHost(host: host, paired: true)
        record.uniqueId = "abc"
        moonlight.store.put(record)
        moonlight.publishRemembered()
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: FakeControllerSource(slots: []), defaults: defaults),
            network: TestNetwork.stack(defaults: defaults, moonlight: moonlight),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker(),
            diagnostics: DiagnosticsSource(ticker: ManualTicker())
        )
        store = model.network.wifi.store
    }

    private func serverInfo(currentGame: Int) throws -> MoonlightServerInfo {
        try XCTUnwrap(MoonlightXml.serverInfo(
            "<root status_code=\"200\"><hostname>PC</hostname><uniqueid>abc</uniqueid><currentgame>\(currentGame)</currentgame></root>"
        ))
    }

    private var hosts: [HostDiagnostics] {
        model.diagnostics.refresh()
        return model.diagnostics.state.hosts
    }

    func testARememberedHostRestsOnItsProbeUntilAConnectionExists() throws {
        XCTAssertEqual(hosts.map(\.id), [host.id])
        XCTAssertEqual(hosts.first?.summary.kind, .moonlight)
        XCTAssertEqual(hosts.first?.moonlight, .resting(info: nil))
        XCTAssertEqual(hosts.first?.facts, .resting(id: host.id), "no satellite session behind a Moonlight row")

        let info = try serverInfo(currentGame: 3)
        moonlight.noteFacts(host.id, info)
        XCTAssertEqual(hosts.first?.moonlight, .resting(info: info), "what the probe said, with no session to read")
    }

    func testAConnectionsPhasePadsAndReportsAreReadOffIt() {
        let connection = moonlight.findOrCreate(host)
        XCTAssertNotNil(connection.acquirePad("a", as: xbox))
        let facts = hosts.first?.moonlight
        XCTAssertEqual(facts?.phase, .idle)
        XCTAssertNil(facts?.appName)
        XCTAssertNil(facts?.controlRoundTripMs, "no control link yet")
        XCTAssertEqual(facts?.pads, [MoonlightPadFacts(number: 0, slotId: "a", type: MoonlightControllerType.xbox, reports: 0)])
    }

    func testASatelliteRowCarriesNoMoonlightFacts() {
        let sat = DiscoveredServer(name: "Sat", ip: "192.0.2.10", udpPort: 9876, machineId: "sat-10")
        store.remember(sat)
        model.network.wifi.register(WifiConnection(id: sat.id, server: sat, tickIntervalNs: .max))
        let satellite = hosts.first { $0.summary.kind == .satellite }
        XCTAssertNotNil(satellite)
        XCTAssertNil(satellite?.moonlight)
    }
}
