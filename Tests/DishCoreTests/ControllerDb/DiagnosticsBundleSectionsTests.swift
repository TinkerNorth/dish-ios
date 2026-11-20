// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// The second cut's sections as the file writes them: the person's report,
/// the device's conditions, every controller path's input and output, and
/// each host's session and snapshot. A field a path cannot know is null.
final class DiagnosticsBundleSectionsTests: XCTestCase {

    private static let createdAtMs: Int64 = 1_795_122_251_000

    private static let output = BundleOutput(
        rumble: BundleLane(count: 12, last: BundleRumble(strong: 32768, weak: 0, atMs: 1_795_122_250_000)),
        rumbleTarget: .framework,
        lightbar: BundleLane(count: 2, last: BundleColour(r: 0, g: 0, b: 255, atMs: 1_795_122_249_000)),
        playerLeds: BundleLane(count: 1, last: BundlePlayer(player: 1, atMs: 1_795_122_248_000)),
        triggerEffects: BundleCount(count: 0)
    )

    private static let pad = BundleController(
        record: nil,
        verification: nil,
        transport: .bluetooth,
        path: .gameController,
        hardware: BundleHardware(vid: nil, pid: nil, product: "DualSense Wireless Controller", category: "DualSense"),
        input: BundleInput(
            frames: 12345,
            rateHz: 250,
            last: BundleInputState(buttons: 0x1000, lx: 0, ly: -12, rx: 0, ry: 0, lt: 0, rt: 255, ext: 0)
        ),
        output: output
    )

    private static let onScreen = BundleController(
        record: nil,
        verification: nil,
        transport: nil,
        path: .virtual,
        hardware: nil,
        input: BundleInput(frames: 0, rateHz: nil, last: nil),
        output: output
    )

    private static let steam = BundleController(
        record: "valve-steam-controller-2026-bluetooth",
        verification: "verified",
        transport: .bluetooth,
        path: .bluetooth,
        hardware: BundleHardware(vid: "28de", pid: "1303", product: "Steam Controller", category: nil),
        bluetooth: .lowEnergy
    )

    private static let session = BundleSession(
        slots: [
            BundleSessionSlot(
                index: 0,
                record: nil,
                requestedType: "dualsense",
                appliedType: "dualsense",
                backend: "hidmaestro",
                result: "ok",
                touchpadMode: "ds4"
            )
        ],
        ack: BundleAck(backendAvailable: true, activeControllers: 1, epoch: 12, activeBitmap: 0b1),
        rtt: BundleRtt(p50Ms: 2.1, p99Ms: 4.8, samples: 120),
        sent: BundleSent(input: 12345, motion: 0, battery: 3, pointer: 0, mic: 0, heartbeat: 60),
        received: BundleReceived(
            heartbeatAck: 60,
            rumble: 12,
            lightbar: 2,
            triggerEffects: 0,
            playerLeds: 1,
            micLed: 0,
            speaker: 0,
            haptic: 0,
            sessionClose: 0,
            other: 0
        )
    )

    private static let host = BundleHost(
        alias: "Host 1",
        kind: "satellite",
        version: "2.2.0",
        protocolVersion: 4,
        link: "connected",
        grants: BundleGrants(mic: false, speaker: false, hapticAudio: false),
        session: session,
        snapshot: BundleHostSnapshot(snapshot: .object(["format": .string("satellite-capabilities")]), error: .olderSatellite)
    )

    private static let bundle = DiagnosticsBundle(
        createdAtMs: createdAtMs,
        app: BundleApp(name: "dish-ios", version: "1.1.0", build: "7"),
        device: BundleDevice(
            model: "iPhone18,1",
            os: "iOS 26.1",
            conditions: BundleConditions(battery: BundleBattery(level: 64, charging: true), thermal: .fair, powerSave: false)
        ),
        controllerDb: BundleControllerDb(bundledVersion: 1, activeVersion: 1, source: .bundled, lastCheckAtMs: nil, lastCheckResult: nil),
        controllers: [pad, onScreen, steam],
        hosts: [host],
        log: [],
        report: BundleReport(category: .noFeedback, text: "Returnal never rumbles.", controller: "DualSense Wireless Controller")
    )

    private func object() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: encodeDiagnosticsBundle(Self.bundle)) as? [String: Any])
    }

    private func controllers() throws -> [[String: Any]] {
        try XCTUnwrap(object()["controllers"] as? [[String: Any]])
    }

    private func host() throws -> [String: Any] {
        try XCTUnwrap((object()["hosts"] as? [[String: Any]])?.first)
    }

    // MARK: - The report

    func testTheReportIsThePersonsCategoryWordsAndController() throws {
        let report = try XCTUnwrap(object()["report"] as? [String: Any])
        XCTAssertEqual(report["category"] as? String, "noFeedback")
        XCTAssertEqual(report["text"] as? String, "Returnal never rumbles.")
        XCTAssertEqual(report["controller"] as? String, "DualSense Wireless Controller")
    }

    func testTheCategoriesAreTheContractsWords() {
        XCTAssertEqual(
            ReportCategory.allCases.map(\.rawValue),
            ["notRecognised", "noFeedback", "connection", "audio", "other", "question"]
        )
    }

    // MARK: - The device

    func testTheDeviceTellsItsBatteryTemperatureAndPowerSaving() throws {
        let device = try XCTUnwrap(object()["device"] as? [String: Any])
        let battery = try XCTUnwrap(device["battery"] as? [String: Any])
        XCTAssertEqual(battery["level"] as? Int, 64)
        XCTAssertEqual(battery["charging"] as? Bool, true)
        XCTAssertEqual(device["thermal"] as? String, "fair")
        XCTAssertEqual(device["powerSave"] as? Bool, false)
    }

    func testIOSGivesNoWifiSignalAndNoUsbHostSoBothAreNull() throws {
        let device = try XCTUnwrap(object()["device"] as? [String: Any])
        XCTAssertTrue(device["wifi"] is NSNull)
        XCTAssertTrue(device["usbHost"] is NSNull)
    }

    func testADeviceThatSaidNothingIsNullThroughout() throws {
        let data = try JSONEncoder().encode(BundleDevice(model: "iPhone18,1", os: "iOS 26.1"))
        let device = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["battery", "thermal", "powerSave"] {
            XCTAssertTrue(device[key] is NSNull, "\(key) is null")
        }
    }

    // MARK: - Every controller path

    func testAPadCarriesWhatWentInAsCountsRateAndTheLastState() throws {
        let input = try XCTUnwrap(controllers().first?["input"] as? [String: Any])
        XCTAssertEqual(input["frames"] as? Int, 12345)
        XCTAssertEqual(input["rateHz"] as? Int, 250)
        let last = try XCTUnwrap(input["last"] as? [String: Any])
        XCTAssertEqual(last["buttons"] as? String, "1000")
        XCTAssertEqual(last["ly"] as? Int, -12)
        XCTAssertEqual(last["rt"] as? Int, 255)
        XCTAssertEqual(last["ext"] as? String, "00000000")
    }

    func testAPadCarriesWhatCameOutPerLaneWithTheRumblesTarget() throws {
        let output = try XCTUnwrap(controllers().first?["output"] as? [String: Any])
        let rumble = try XCTUnwrap(output["rumble"] as? [String: Any])
        XCTAssertEqual(rumble["count"] as? Int, 12)
        XCTAssertEqual(rumble["target"] as? String, "framework")
        XCTAssertEqual((rumble["last"] as? [String: Any])?["strong"] as? Int, 32768)
        XCTAssertTrue(rumble["lastWrite"] is NSNull, "the framework tells no write")
        XCTAssertEqual((output["lightbar"] as? [String: Any])?["count"] as? Int, 2)
        XCTAssertEqual(((output["lightbar"] as? [String: Any])?["last"] as? [String: Any])?["b"] as? Int, 255)
        XCTAssertEqual(((output["playerLeds"] as? [String: Any])?["last"] as? [String: Any])?["player"] as? Int, 1)
        XCTAssertEqual((output["triggerEffects"] as? [String: Any])?["count"] as? Int, 0)
    }

    func testTheLanesIOSDoesNotCarryAreNull() throws {
        let output = try XCTUnwrap(controllers().first?["output"] as? [String: Any])
        for lane in ["triggerRumble", "micLed", "speaker", "haptics"] {
            XCTAssertTrue(output[lane] is NSNull, "\(lane) is null")
        }
    }

    func testTheOnScreenControllerIsAVirtualPathWithNoLinkAndNoHardware() throws {
        let onScreen = try controllers()[1]
        XCTAssertEqual(onScreen["path"] as? String, "virtual")
        XCTAssertTrue(onScreen["transport"] is NSNull)
        XCTAssertTrue(onScreen["hardware"] is NSNull)
        XCTAssertTrue((onScreen["input"] as? [String: Any])?["rateHz"] is NSNull, "a rate not yet sampled is null")
    }

    func testASteamControllerTellsItsBluetoothProfileAndNeverAnAddress() throws {
        let steam = try controllers()[2]
        XCTAssertEqual(steam["bluetooth"] as? [String: String], ["profile": "ble", "transportLayer": "le"])
        XCTAssertTrue(steam["input"] is NSNull, "a path that cannot know is null")
        XCTAssertTrue(try controllers().first?["bluetooth"] is NSNull, "GameController names no profile")
    }

    // MARK: - The hosts, from both ends

    func testAHostCarriesTheClientsOwnViewOfItsSession() throws {
        let session = try XCTUnwrap(host()["session"] as? [String: Any])
        let slot = try XCTUnwrap((session["slots"] as? [[String: Any]])?.first)
        XCTAssertEqual(slot["index"] as? Int, 0)
        XCTAssertTrue(slot["record"] is NSNull)
        XCTAssertEqual(slot["requestedType"] as? String, "dualsense")
        XCTAssertEqual(slot["backend"] as? String, "hidmaestro")
        XCTAssertEqual(slot["result"] as? String, "ok")
        XCTAssertEqual(slot["touchpadMode"] as? String, "ds4")
        let ack = try XCTUnwrap(session["ack"] as? [String: Any])
        XCTAssertEqual(ack["activeBitmap"] as? String, "0001")
        XCTAssertEqual(ack["epoch"] as? Int, 12)
        XCTAssertEqual((session["rtt"] as? [String: Any])?["samples"] as? Int, 120)
        XCTAssertEqual((session["sent"] as? [String: Any])?["input"] as? Int, 12345)
        XCTAssertEqual((session["received"] as? [String: Any])?["rumble"] as? Int, 12)
    }

    func testAHostCarriesItsSnapshotAndWhyItIsTheClientsCopy() throws {
        let host = try host()
        XCTAssertEqual((host["snapshot"] as? [String: Any])?["format"] as? String, "satellite-capabilities")
        XCTAssertEqual(host["snapshotError"] as? String, "olderSatellite")
    }

    func testAHostWithNoSessionAndNothingAskedIsNullThroughout() throws {
        let bare = BundleHost(
            alias: "Host 2",
            kind: "satellite",
            version: nil,
            protocolVersion: nil,
            link: "saved",
            grants: BundleGrants(mic: false, speaker: false, hapticAudio: false)
        )
        let data = try JSONEncoder().encode(bare)
        let host = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["session", "snapshot", "snapshotError"] {
            XCTAssertTrue(host[key] is NSNull, "\(key) is null")
        }
    }
}
