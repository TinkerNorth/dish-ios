// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The bundle from the facts the Diagnostics page renders: each controller
/// with its record and its path, the hosts as aliases in the page's
/// order, the log with every host renamed, and nothing a person would not
/// hand a stranger: no host's name, no address, no key.
@MainActor
final class DiagnosticsBundleBuilderTests: XCTestCase {

    /// What a PC's row knows that the bundle must not hold.
    private static let denName = "Emir's Den PC"
    private static let denAddress = "192.168.1.24"
    private static let hostName = "Living Room Sunshine"
    private static let hostAddress = "10.0.0.7"

    private static let den = HostDiagnostics(
        summary: ConnectionSummary(id: "sat-den", name: denName, address: denAddress, udpPort: 9876, live: .connected, kind: .satellite),
        facts: HostSessionFacts(
            id: "sat-den",
            live: true,
            offeredProtocol: 4,
            settledProtocol: 4,
            compat: .current,
            appliedEpoch: 1,
            hostEpoch: 1,
            hostBitmap: 1,
            confirmedBitmap: 1,
            backendAvailable: true,
            activeControllers: 1,
            missedAcks: 0,
            latency: LatencySummary(p50RttMs: 4, p99RttMs: 9, samples: 3, capacity: 64)
        ),
        counters: SessionCounters(sent: 10, received: 10, dropped: 0, replayGuard: 10)
    )

    private static let livingRoom = HostDiagnostics(
        summary: ConnectionSummary(id: "moonlight:10.0.0.7", name: hostName, address: hostAddress, live: .saved, kind: .moonlight),
        facts: .resting(id: "moonlight:10.0.0.7"),
        counters: .none,
        moonlight: .resting(info: nil)
    )

    private static let steamPad = ControllerFact(
        id: "ble:pad",
        name: "Valve Steam Controller (2026, Bluetooth)",
        link: .bluetooth,
        batteryPercent: nil,
        destination: DestinationFact(id: "sat-den", name: denName, health: .online),
        source: .bluetooth(vendorId: 0x28DE, productId: 0x1303),
        record: ControllerRecordFact(id: "valve-steam-controller-2026-bluetooth", verification: .verified)
    )

    private static let xboxPad = ControllerFact(
        id: "gc:Xbox Wireless Controller:Xbox One",
        name: "Xbox Wireless Controller",
        link: .bluetooth,
        batteryPercent: 80,
        destination: nil,
        source: .gameController(category: "Xbox One")
    )

    private static let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)

    private static let events = [
        DiagnosticsEvent(sequence: 1, atMs: 1000, kind: .linkAppeared, subject: .named(denName), to: .saved),
        DiagnosticsEvent(sequence: 2, atMs: 2000, kind: .linkChanged, subject: .named(denName), from: .connecting, to: .connected),
        DiagnosticsEvent(
            sequence: 3,
            atMs: 3000,
            kind: .padBound,
            subject: .named("Valve Steam Controller (2026, Bluetooth)"),
            host: denName
        ),
        DiagnosticsEvent(sequence: 4, atMs: 4000, kind: .linkRemoved, subject: .named("A PC since forgotten")),
        DiagnosticsEvent(sequence: 5, atMs: 5000, kind: .padUnbound, subject: .onScreenGamepad, host: "A PC since forgotten")
    ]

    private static let facts = DiagnosticsBundleFacts(
        createdAtMs: 1_795_122_251_000,
        identity: DeviceIdentity(appVersion: "1.1.0", appBuild: "7", model: "iPhone18,1", systemVersion: "26.1"),
        controllerDb: ControllerDbStatus(
            bundledVersion: 1,
            activeVersion: 2,
            source: .cache,
            checksEnabled: true,
            lastCheckAtMs: 1_795_122_000_000,
            lastCheckResult: .updated
        ),
        controllers: [steamPad, xboxPad, onScreen],
        hosts: [den, livingRoom],
        events: events
    )

    private let bundle = diagnosticsBundle(DiagnosticsBundleBuilderTests.facts)

    func testTheAppAndTheDeviceAreTheScenesReading() {
        XCTAssertEqual(bundle.app, BundleApp(name: "dish-ios", version: "1.1.0", build: "7"))
        XCTAssertEqual(bundle.device, BundleDevice(model: "iPhone18,1", os: "iOS 26.1"))
    }

    func testTheDatabaseIsTheStatusSettingsShows() {
        XCTAssertEqual(bundle.controllerDb, BundleControllerDb(
            bundledVersion: 1,
            activeVersion: 2,
            source: .cache,
            lastCheckAtMs: 1_795_122_000_000,
            lastCheckResult: .updated
        ))
    }

    func testWithTheSwitchOffTheLastCheckReadsOff() {
        let off = ControllerDbStatus(
            bundledVersion: 1,
            activeVersion: 1,
            source: .bundled,
            checksEnabled: false,
            lastCheckResult: .upToDate
        )
        let facts = DiagnosticsBundleFacts(createdAtMs: 0, identity: .unknown, controllerDb: off, controllers: [], hosts: [], events: [])
        XCTAssertEqual(diagnosticsBundle(facts).controllerDb.lastCheckResult, .off)
    }

    func testASteamControllerCarriesItsRecordItsIdsAndItsPath() {
        XCTAssertEqual(bundle.controllers.first, BundleController(
            record: "valve-steam-controller-2026-bluetooth",
            verification: "verified",
            transport: .bluetooth,
            path: .bluetooth,
            hardware: BundleHardware(vid: "28de", pid: "1303", product: "Valve Steam Controller (2026, Bluetooth)", category: nil),
            bluetooth: .lowEnergy
        ))
    }

    func testAGameControllerPadCarriesNoRecordAndWhatTheFrameworkSaid() {
        XCTAssertEqual(bundle.controllers[1], BundleController(
            record: nil,
            verification: nil,
            transport: .bluetooth,
            path: .gameController,
            hardware: BundleHardware(vid: nil, pid: nil, product: "Xbox Wireless Controller", category: "Xbox One")
        ))
    }

    func testTheOnScreenControllerIsTheVirtualPathWithNoLinkAndNoHardware() {
        XCTAssertEqual(bundle.controllers.count, 3)
        let onScreen = BundleController(record: nil, verification: nil, transport: nil, path: .virtual, hardware: nil)
        XCTAssertEqual(bundle.controllers.last, onScreen)
    }

    func testTheHostsAreAliasesInThePagesOrder() {
        XCTAssertEqual(bundle.hosts, [
            BundleHost(
                alias: "Host 1",
                kind: "satellite",
                version: nil,
                protocolVersion: 4,
                link: "connected",
                grants: BundleGrants(mic: false, speaker: false, hapticAudio: false)
            ),
            BundleHost(
                alias: "Host 2",
                kind: "moonlight",
                version: nil,
                protocolVersion: nil,
                link: "saved",
                grants: BundleGrants(mic: false, speaker: false, hapticAudio: false)
            )
        ])
    }

    func testTheLogNamesAHostByItsAliasAndAHostGoneByNone() {
        XCTAssertEqual(bundle.log.map(\.message), [
            "Host 1: saved",
            "Host 1: connecting -> connected",
            "Valve Steam Controller (2026, Bluetooth) on Host 1",
            "Host",
            "on-screen gamepad on Host"
        ])
        XCTAssertEqual(bundle.log.map(\.tag), ["linkAppeared", "linkChanged", "padBound", "linkRemoved", "padUnbound"])
        XCTAssertEqual(bundle.log.map(\.atMs), [1000, 2000, 3000, 4000, 5000])
    }

    func testTheFileHoldsNoHostsNameNoAddressAndNoKey() throws {
        let text = try XCTUnwrap(String(data: encodeDiagnosticsBundle(bundle), encoding: .utf8))
        let forbidden = [
            Self.denName,
            "Den PC",
            Self.denAddress,
            Self.hostName,
            Self.hostAddress,
            "sat-den",
            "moonlight:",
            "A PC since forgotten",
            "9876"
        ]
        for value in forbidden {
            XCTAssertFalse(text.contains(value), "the bundle holds \(value)")
        }
    }
}
