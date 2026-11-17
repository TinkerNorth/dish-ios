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

    /// A PC typed by its address is on the Connections tab as found, with
    /// Pair, from the moment it is added: an address whose pair sheet was
    /// cancelled still has its row.
    /// The pool reaches for a typed PC at once, so its found row reads
    /// connecting until it answers or fails.
    func testAPCAddedByAddressIsFoundBeforeItIsPaired() {
        let id = "wifi:127.0.0.1:\(fixture.ports.udp)"
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        XCTAssertEqual(fixture.model.shellFacts.found, [ConnectionFact(
            id: id,
            name: "",
            address: "127.0.0.1",
            kind: .satellite,
            state: .connecting
        )])
        fixture.model.cancelPairing(id)
        XCTAssertEqual(fixture.model.shellFacts.found.map(\.id), [id], "cancelling the sheet leaves the row")
        XCTAssertEqual(fixture.model.shellFacts.paired, [])
    }

    func testAPCAddedByAddressThatIsAlreadyPairedIsPairedNotFound() {
        let port = Int(fixture.ports.udp)
        let remembered = DiscoveredServer(name: "Den PC", ip: "127.0.0.1", udpPort: port, source: .manual)
        fixture.network.wifi.store.remember(remembered)
        fixture.network.wifi.refreshRemembered()
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(port)"))
        XCTAssertEqual(fixture.model.shellFacts.found, [])
        XCTAssertEqual(fixture.model.shellFacts.paired.map(\.id), [remembered.id])
    }

    func testAPCThatScanAndAddressBothNameIsListedOnce() async {
        let scanned = await fixture.scan()
        XCTAssertTrue(scanned)
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        let ids = fixture.model.shellFacts.found.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "no PC is listed twice")
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
        XCTAssertEqual(row?.protocolVersion, 4)
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
        XCTAssertNil(fixture.model.connectionsFacts.addedByAddress)
        let id = "wifi:127.0.0.1:\(fixture.ports.udp)"
        fixture.model.recordNotice(.unreachable(detail: "timed out"), for: id)
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        let added = fixture.model.connectionsFacts.addedByAddress
        XCTAssertEqual(added?.id, id)
        XCTAssertNil(added?.failure, "a fresh attempt starts clean")
        XCTAssertEqual(fixture.model.shellFacts.addedByAddress?.id, id, "setup reads the same PC")
    }

    // MARK: - Every step of a connection, on the row

    /// The row reads connecting the moment the person reaches for the PC,
    /// and online once its session is up.
    func testConnectReadsConnectingUntilTheSessionIsUp() async {
        fixture.prePair()
        fixture.model.connect(fixture.serverId)
        XCTAssertEqual(fixture.model.connectionsFacts.paired.first?.state, .connecting)
        let live = await fixture.waitUntil { self.fixture.network.wifi.get(self.fixture.serverId)?.state == .live }
        XCTAssertTrue(live)
        guard case .online = fixture.model.connectionsFacts.paired.first?.state else {
            return XCTFail("online once up: \(String(describing: fixture.model.connectionsFacts.paired.first?.state))")
        }
    }

    /// An attempt the person made that fails leaves why on the PC's row,
    /// with the PC resting; the next attempt clears it at once.
    func testAFailedAttemptLeavesItsNoticeOnTheRowUntilTheNextAttempt() async {
        fixture.prePair()
        fixture.satellite.stop()
        fixture.model.connect(fixture.serverId)
        let noticed = await fixture.waitUntil { self.fixture.model.connectionsFacts.paired.first?.notice != nil }
        XCTAssertTrue(noticed, "the attempt fails and the row says why")
        guard case .offline = fixture.model.connectionsFacts.paired.first?.state else {
            return XCTFail("the PC rests: \(String(describing: fixture.model.connectionsFacts.paired.first?.state))")
        }
        fixture.model.connect(fixture.serverId)
        XCTAssertNil(fixture.model.connectionsFacts.paired.first?.notice, "a fresh attempt starts clean")
    }

    /// The foreground's silent sweep that fails leaves no notice: only an
    /// attempt the person made is worded.
    func testASilentReconnectLeavesNoNotice() async {
        fixture.prePair()
        fixture.satellite.stop()
        fixture.model.enteredForeground()
        let rested = await fixture.waitUntil { self.fixture.network.wifi.get(self.fixture.serverId)?.state == .idle }
        XCTAssertTrue(rested, "the sweep reached for the PC and gave up")
        XCTAssertNil(fixture.model.connectionsFacts.paired.first?.notice)
    }

    /// A session whose acks falter reads unsteady with its pads; Reconnect
    /// on its row closes it and reaches again, the row reading connecting
    /// meanwhile.
    func testAnUnsteadySessionReadsUnsteadyAndReconnectReachesAgain() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        let first = try XCTUnwrap(conn.client)
        first.missedAcks.set(ProtocolConstants.heartbeatMissNotResponding)
        conn.aliveTick()
        guard case let .unsteady(_, controllers) = fixture.model.connectionsFacts.paired.first?.state else {
            return XCTFail("unsteady: \(String(describing: fixture.model.connectionsFacts.paired.first?.state))")
        }
        XCTAssertEqual(controllers, 1)
        fixture.model.reconnect(fixture.serverId)
        XCTAssertEqual(fixture.model.connectionsFacts.paired.first?.state, .connecting)
        let again = await fixture.waitUntil { conn.state == .live && conn.client !== first }
        XCTAssertTrue(again, "a fresh session on a fresh client")
    }

    /// The PC typed by its address reads connecting while the pool reaches
    /// for it, on the found rows and on the sheet's own fact, and settles.
    func testATypedPCReadsConnectingWhileItIsReachedFor() async {
        XCTAssertTrue(fixture.model.addByAddress("127.0.0.1:\(fixture.ports.udp)"))
        XCTAssertEqual(fixture.model.connectionsFacts.addedByAddress?.reaching, true)
        XCTAssertEqual(fixture.model.connectionsFacts.found.first?.state, .connecting)
        let settled = await fixture.waitUntil { self.fixture.model.connectionsFacts.addedByAddress?.reaching == false }
        XCTAssertTrue(settled)
    }

    /// Disconnect on a PC being reached for stops the reach: the row rests
    /// and the accessory, had it shown the PC coming back, lets it go.
    func testDisconnectStopsAReach() {
        fixture.prePair()
        fixture.model.connect(fixture.serverId)
        XCTAssertEqual(fixture.model.reaching.state, [fixture.serverId])
        fixture.model.disconnect(fixture.serverId)
        XCTAssertEqual(fixture.model.reaching.state, [])
        guard case .offline = fixture.model.connectionsFacts.paired.first?.state else { return XCTFail("the PC rests") }
    }

    /// The person's own attempt says why it failed; a silent one only when
    /// the failure needs them, never that the PC was merely off.
    func testOnlyAFailureOfTheConnectionIsTheRowsToWord() {
        XCTAssertFalse(isRowNotice(.controllerNotApplied, attempt: .own), "the apply's word on the pad's row")
        XCTAssertFalse(isRowNotice(.noServersFound, attempt: .own), "the page's empty state")
        XCTAssertFalse(isRowNotice(.localNetworkDenied, attempt: .own), "the page's denied state")
        XCTAssertTrue(isRowNotice(.unreachable(detail: ""), attempt: .own))
        XCTAssertFalse(isRowNotice(.unreachable(detail: ""), attempt: .silent), "a PC that is off is not news")
        XCTAssertFalse(isRowNotice(.noSharedKey, attempt: .silent))
        XCTAssertTrue(isRowNotice(.repairNeeded, attempt: .silent))
        XCTAssertTrue(isRowNotice(.satelliteUpdateRequired, attempt: .silent))
        XCTAssertTrue(isRowNotice(.dataPathBlocked, attempt: .silent))
        XCTAssertTrue(isRowNotice(.sessionReplaced, attempt: .silent))
        XCTAssertTrue(isRowNotice(.identityChanged, attempt: .silent))
        XCTAssertTrue(endsAReach(.unreachable(detail: "")))
        XCTAssertFalse(endsAReach(.controllerNotApplied), "the slot's business, not the link's")
    }

    /// A PUT that did not grant: an identity that changed, no HTTPS answer
    /// at all, or an answer that refused.
    func testAPutThatDidNotGrantIsReadForWhatItWas() {
        XCTAssertEqual(refusedOpenFailure(identityChanged: true, reachable: false, detail: nil), .identityChanged)
        XCTAssertEqual(refusedOpenFailure(identityChanged: false, reachable: false, detail: "timed out"), .unreachable(detail: "timed out"))
        XCTAssertEqual(refusedOpenFailure(identityChanged: false, reachable: true, detail: "busy"), .sessionRefused(detail: "busy"))
    }

    /// A session that opens over HTTPS but never hears an ack over UDP dies,
    /// and the row names the data path the network blocks, with Reconnect;
    /// the retry curve keeps trying behind it and the word stays.
    func testASessionWithNoAcksIsNamedABlockedDataPath() async throws {
        fixture.prePair()
        fixture.satellite.silenceUdp()
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let live = await fixture.waitUntil { self.fixture.network.wifi.get(self.fixture.serverId)?.state == .live }
        XCTAssertTrue(live, "the session opens over REST")
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        XCTAssertEqual(conn.latencySamples, 0, "no ack came back")
        try XCTUnwrap(conn.client).connectionAlive.set(false)
        conn.aliveTick()
        XCTAssertEqual(fixture.model.connectionsFacts.paired.first?.notice, .dataPathBlocked)
        guard case .unsteady = fixture.model.connectionsFacts.paired.first?.state else {
            return XCTFail("parked on the retry window: \(String(describing: fixture.model.connectionsFacts.paired.first?.state))")
        }
        XCTAssertEqual(fixture.model.sessionFacts.session?.phase, .failed(.dataPathBlocked), "the accessory names it on every tab")
    }

    /// Another device's PUT took the session: the row rests and says so, no
    /// silent retry fights it, and Reconnect takes it back.
    func testASessionAnotherDeviceTookIsNamedAndWaitsForThePerson() async throws {
        let live = await fixture.connectPaired()
        XCTAssertTrue(live)
        let conn = try XCTUnwrap(fixture.network.wifi.get(fixture.serverId))
        try XCTUnwrap(conn.client).sessionCloseReason.set(Int(CloseReason.replaced.rawValue))
        conn.aliveTick()
        XCTAssertEqual(fixture.model.connectionsFacts.paired.first?.notice, .sessionReplaced)
        guard case .offline = fixture.model.connectionsFacts.paired.first?.state else { return XCTFail("the row rests") }
        XCTAssertEqual(fixture.network.wifi.retry[fixture.serverId]?.suppressed, true, "no silent retry fights the newer owner")
        fixture.model.reconnect(fixture.serverId)
        XCTAssertNil(fixture.model.connectionsFacts.paired.first?.notice)
        let again = await fixture.waitUntil { conn.state == .live }
        XCTAssertTrue(again)
    }

    /// A bind to a PC that cannot be reached fails as soon as the reach
    /// does, with the PC's own failure on its row.
    func testABindFailsAsSoonAsItsReachDoes() async {
        fixture.prePair()
        fixture.satellite.stop()
        let started = Date()
        fixture.model.bind(slotId: "pad", to: fixture.serverId)
        let failed = await fixture.waitUntil(timeout: 10) { self.fixture.model.bindingProgress == .failed(.hostUnreachable) }
        XCTAssertTrue(failed, "\(fixture.model.bindingProgress)")
        XCTAssertLessThan(Date().timeIntervalSince(started), 10, "well before the fifteen-second budget")
        guard case .unreachable = fixture.model.connectionsFacts.paired.first?.notice else {
            return XCTFail("the PC's own failure: \(String(describing: fixture.model.connectionsFacts.paired.first?.notice))")
        }
    }

    /// A failure is worded while the PC rests, falters or wants a PIN, and
    /// not while it is up or being reached for, when the state says more.
    func testANoticeShowsOnlyWhileThePCRestsOrWantsAPin() {
        let failure = ConnectionFailure.unreachable(detail: "")
        XCTAssertEqual(attemptNotice(failure, live: .saved), failure)
        XCTAssertEqual(attemptNotice(failure, live: .ready), failure)
        XCTAssertEqual(attemptNotice(failure, live: .stale), failure)
        XCTAssertNil(attemptNotice(failure, live: .connecting))
        XCTAssertNil(attemptNotice(failure, live: .connected))
        XCTAssertEqual(attemptNotice(failure, live: .unstable), failure, "a faltering session shows what explains it")
        XCTAssertNil(attemptNotice(nil, live: .saved))
    }
}
