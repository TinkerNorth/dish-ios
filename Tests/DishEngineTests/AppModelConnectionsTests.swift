// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The Connections tab through the model: what a scan heard becomes the
/// found PCs and the Local Network status, a paired satellite reads online
/// with its latency and pads, a disconnect rests it, a Forget self-unpairs
/// and drops it, and a typed address is read before anything is sent.
@MainActor
final class AppModelConnectionsTests: XCTestCase {

    private var fixture: SatelliteModelFixture!

    override func setUp() async throws {
        fixture = try SatelliteModelFixture(self)
    }

    override func tearDown() async throws {
        fixture?.tearDown()
        fixture = nil
    }

    func testBeforeAnyScanNothingIsFoundAndTheStatusIsUnknown() {
        let facts = fixture.model.shellFacts
        XCTAssertEqual(facts.paired, [])
        XCTAssertEqual(facts.found, [])
        XCTAssertFalse(facts.scanning)
        XCTAssertEqual(facts.localNetwork, .unknown)
    }

    func testAScanFindsTheSatelliteThatWantsPairingAndTheNetworkIsAllowed() async {
        let scanned = await fixture.scan()
        XCTAssertTrue(scanned)
        let facts = fixture.model.shellFacts
        XCTAssertEqual(facts.localNetwork, .allowed)
        XCTAssertEqual(facts.found, [ConnectionFact(
            id: fixture.serverId,
            name: "Den PC",
            address: "127.0.0.1",
            kind: .satellite,
            state: .needsPairing
        )])
        XCTAssertEqual(facts.paired, [])
    }

    /// Pull to refresh on Connections holds its spinner until discovery has
    /// adopted the scan, so it lets go with the PCs it heard on the page.
    func testPullToRefreshReturnsOnceTheScanIsAdopted() async {
        await fixture.model.refreshConnections()
        let facts = fixture.model.shellFacts
        XCTAssertFalse(facts.scanning, "the spinner stays while the scan runs")
        XCTAssertEqual(facts.found.map(\.name), ["Den PC"])
    }

    func testAScanHeldOnThePolicyReadsDenied() async throws {
        let defaults = try TestDefaults.fresh(self)
        let wifi = WifiConnectionManager(
            store: ConnectionStore(defaults: defaults, keyStore: InMemoryKeyStore(), pins: CertPins(file: nil)),
            deviceName: testDeviceName,
            discovery: .scripted([], denied: true)
        )
        let access = BonjourLocalNetworkAccess(wifi: wifi)
        access.ask()
        let answered = await fixture.waitUntil { access.status != .unknown }
        XCTAssertTrue(answered)
        XCTAssertEqual(access.status, .denied)
    }

    func testAPairedSatelliteReadsOnlineWithItsLatencyAndPads() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let measured = await fixture.waitUntil(timeout: 8) {
            self.fixture.network.wifi.get(self.fixture.serverId)?.latencyOneWayMs != nil
        }
        XCTAssertTrue(measured, "the alive tick publishes the heartbeat window")
        guard case let .online(latencyMs, controllers) = fixture.model.shellFacts.paired.first?.state else {
            return XCTFail("a live satellite reads online: \(fixture.model.shellFacts.paired)")
        }
        XCTAssertGreaterThanOrEqual(latencyMs, 0)
        XCTAssertEqual(controllers, 1)
        XCTAssertEqual(fixture.model.shellFacts.found, [], "a paired satellite is not found again")
    }

    func testADisconnectedSatelliteReadsOfflineSinceItsSession() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.disconnect(fixture.serverId)
        guard case let .offline(lastSeen) = fixture.model.shellFacts.paired.first?.state else {
            return XCTFail("a rested satellite reads offline")
        }
        XCTAssertNotNil(lastSeen, "the session's end is its last sighting")
    }

    func testForgetSelfUnpairsAndDropsTheRowTheKeyAndThePin() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        XCTAssertNotNil(fixture.network.wifi.store.certPin(host: "127.0.0.1"))
        fixture.model.forget(fixture.serverId)
        XCTAssertEqual(fixture.model.shellFacts.paired, [])
        XCTAssertNil(fixture.keyStore.pairingKeyHex(for: fixture.serverId))
        XCTAssertNil(fixture.network.wifi.store.certPin(host: "127.0.0.1"))
        let unpaired = await fixture.waitUntil { !self.fixture.satellite.unpairCalls.isEmpty }
        XCTAssertTrue(unpaired, "the satellite heard DELETE /api/pair")
    }

    func testATypedAddressIsReadBeforeAnythingIsSent() {
        XCTAssertFalse(fixture.model.addByAddress("den.local"))
        XCTAssertTrue(fixture.network.wifi.connections.isEmpty)
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        XCTAssertNotNil(fixture.network.wifi.get("wifi:127.0.0.1:\(fixture.ports.udp)"))
    }

    func testStartScanGoesThroughTheLocalNetworkSeam() throws {
        let recorded = try SatelliteModelFixture(self, localNetwork: .recorded)
        defer { recorded.tearDown() }
        recorded.model.startScan()
        XCTAssertEqual((recorded.model.localNetwork as? RecordedLocalNetworkAccess)?.scans, 1)
    }

    /// A paired satellite's row carries what its page shows: the pads it
    /// carries, its version and protocol, and what it can carry each way.
    func testAPairedSatellitesRowCarriesItsPadsVersionProtocolAndFeatures() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let applied = await fixture.waitUntil { self.fixture.satellite.appliedControllers.count == 1 }
        XCTAssertTrue(applied)
        let row = fixture.model.shellFacts.paired.first
        XCTAssertEqual(row?.boundControllerIds, ["pad"])
        XCTAssertEqual(row?.satelliteVersion, "1.6.0")
        XCTAssertEqual(row?.protocolVersion, 3)
        XCTAssertEqual(row?.features, SatelliteFeaturesFact(motion: true, rumble: true))
    }

    /// A rested satellite's row keeps its version but has no protocol or
    /// pads to show.
    func testARestedSatellitesRowHasNoProtocolOrPads() async {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.disconnect(fixture.serverId)
        let row = fixture.model.shellFacts.paired.first
        XCTAssertEqual(row?.boundControllerIds, [])
        XCTAssertEqual(row?.satelliteVersion, "1.6.0", "the probe is remembered")
        XCTAssertNil(row?.protocolVersion)
    }

    /// The PC typed by its address is published, so setup's Bind and Review
    /// know which PC it is, and a fresh attempt starts with no stale failure.
    func testATypedAddressIsPublishedAndStartsAFreshAttempt() {
        XCTAssertNil(fixture.model.shellFacts.addedByAddress)
        fixture.model.lastConnectionEvent = .failure(.noServersFound)
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        XCTAssertEqual(fixture.model.shellFacts.addedByAddress, "wifi:127.0.0.1:\(fixture.ports.udp)")
        XCTAssertNil(fixture.model.lastConnectionEvent)
    }
}
