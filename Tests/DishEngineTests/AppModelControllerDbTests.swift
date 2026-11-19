// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The controller database through the model: a Steam Controller over
/// Bluetooth carries its record and the issues it shows here, a pad
/// GameController reads carries none, the check is armed at launch and
/// only in the foreground, Settings' intents reach the store, and Email
/// diagnostics writes the bundle and hands the mail seam one message.
@MainActor
final class AppModelControllerDbTests: XCTestCase {

    private static let steam2026 = ControllerSlot(
        id: "ble:pad",
        name: "Valve Steam Controller (2026, Bluetooth)",
        capabilities: ControllerCapabilities(hasMotion: true, hasTouchpad: true, hasRumble: true, hasExtendedButtons: true),
        trackpads: .twoPads,
        source: .bluetooth(vendorId: 0x28DE, productId: 0x1303)
    )

    private static let unknownOverBluetooth = ControllerSlot(
        id: "ble:other",
        name: "A pad",
        source: .bluetooth(vendorId: 0x1234, productId: 0x5678)
    )

    private static let xbox = ControllerSlot(
        id: "gc:Xbox Wireless Controller:Xbox One",
        name: "Xbox Wireless Controller",
        capabilities: ControllerCapabilities(hasRumble: true, hasBattery: true),
        family: .xbox,
        source: .gameController(category: "Xbox One")
    )

    private let gateway = ScriptedControllerDbGateway()
    private let ticker = ManualTicker()
    private let mailer = RecordedDiagnosticsMailer()
    private var folder: URL!
    private var diagnosticsFolder: URL!

    override func setUp() async throws {
        folder = freshCacheFolder(self)
        diagnosticsFolder = freshCacheFolder(self)
    }

    private func model(_ pads: [ControllerSlot], cached: [String: Data]? = nil) throws -> AppModel {
        let defaults = try TestDefaults.fresh(self)
        let cache = ControllerDbCache(directory: folder)
        if let cached { XCTAssertTrue(cache.replaceAll(cached)) }
        let store = ControllerDbStore(
            bundled: BundledControllerDb.load() ?? .empty,
            cache: cache,
            gateway: gateway,
            preferences: ControllerDbPreferenceStore(defaults: defaults),
            ticker: ticker
        )
        return AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: FakeControllerSource(slots: pads), defaults: defaults),
            network: TestNetwork.stack(defaults: defaults),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker(),
            diagnostics: DiagnosticsSource(ticker: ManualTicker()),
            controllerDb: store,
            identity: DeviceIdentity(appVersion: "1.1.0", appBuild: "7", model: "iPhone18,1", systemVersion: "26.1"),
            mailer: mailer,
            diagnosticsFolder: diagnosticsFolder
        )
    }

    private func fact(_ model: AppModel, _ id: String) throws -> ControllerFact {
        try XCTUnwrap(model.controllersFacts.controllers.first { $0.id == id })
    }

    // MARK: - A pad's record

    func testASteamControllerOverBluetoothCarriesItsRecord() throws {
        let model = try model([Self.steam2026])
        let record = try fact(model, Self.steam2026.id).record
        XCTAssertEqual(record, ControllerRecordFact(id: "valve-steam-controller-2026-bluetooth", verification: .verified))
        XCTAssertEqual(try fact(model, Self.steam2026.id).source, .bluetooth(vendorId: 0x28DE, productId: 0x1303))
    }

    func testAPadGameControllerReadsCarriesNoRecord() throws {
        let model = try model([Self.xbox])
        XCTAssertNil(try fact(model, Self.xbox.id).record)
        XCTAssertEqual(try fact(model, Self.xbox.id).source, .gameController(category: "Xbox One"))
    }

    func testAPadOverBluetoothTheDatabaseDoesNotKnowCarriesNoRecord() throws {
        XCTAssertNil(try fact(model([Self.unknownOverBluetooth]), Self.unknownOverBluetooth.id).record)
    }

    func testAPadShowsOnlyTheIssuesOnBluetooth() throws {
        let model = try model([Self.steam2026], cached: ControllerDbFixtures.publishedFiles(version: 2))
        let record = try XCTUnwrap(fact(model, Self.steam2026.id).record)
        XCTAssertEqual(record.issues.map(\.id), ["triton-ble-lag"], "the USB issue is not this pad's")
    }

    func testTheFactsCarryTheStatusAndTheStringsInForce() throws {
        let model = try model([], cached: ControllerDbFixtures.publishedFiles(version: 2))
        let facts = model.shellFacts.controllerDb
        XCTAssertEqual(facts.status.activeVersion, 2)
        XCTAssertEqual(facts.status.source, .cache)
        XCTAssertEqual(facts.strings.issueTitle("triton-ble-lag", locale: "de"), "Eingaben kommen spät an")
    }

    // MARK: - The schedule and Settings

    func testTheCheckIsArmedAtLaunchAndOnlyInTheForeground() throws {
        let model = try model([])
        XCTAssertEqual(ticker.starts, [10])
        model.enteredBackground()
        XCTAssertFalse(ticker.running)
        model.enteredForeground()
        XCTAssertTrue(ticker.running)
    }

    func testTheSwitchIsSettingsIntent() throws {
        let model = try model([])
        model.setControllerDbChecks(false)
        XCTAssertFalse(model.controllerDbFacts.status.checksEnabled)
        XCTAssertFalse(ticker.running)
    }

    func testCheckNowIsSettingsIntent() async throws {
        let model = try model([])
        model.checkControllerDbNow()
        await model.controllerDb.settle()
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil)])
        XCTAssertEqual(model.controllerDbFacts.status.lastCheckResult, .offline)
    }

    // MARK: - Email diagnostics

    func testEmailDiagnosticsHandsTheMailAppOneMessageToSupport() throws {
        let model = try model([Self.steam2026])
        model.emailDiagnostics(body: "the summary")
        let mail = try XCTUnwrap(mailer.mails.first)
        XCTAssertEqual(mailer.mails.count, 1)
        XCTAssertEqual(mail.recipient, "support@tinkernorth.com")
        XCTAssertEqual(mail.subject, "Dish diagnostics: Dish for iOS 1.1.0 on iPhone18,1")
        XCTAssertEqual(mail.body, "the summary")
        XCTAssertEqual(mail.attachment.deletingLastPathComponent().standardizedFileURL, diagnosticsFolder.standardizedFileURL)
        XCTAssertTrue(mail.attachment.lastPathComponent.hasPrefix("dish-diagnostics-dish-ios-"))
        XCTAssertEqual(mail.attachment.pathExtension, "json")
    }

    func testTheAttachmentIsTheBundleOfThePadsAndTheData() throws {
        let model = try model([Self.steam2026])
        model.emailDiagnostics(body: "")
        let file = try XCTUnwrap(mailer.mails.first?.attachment)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(object["bundle"] as? Int, 1)
        let controllers = try XCTUnwrap(object["controllers"] as? [[String: Any]])
        XCTAssertEqual(controllers.first?["record"] as? String, "valve-steam-controller-2026-bluetooth")
        XCTAssertEqual((object["controllerDb"] as? [String: Any])?["activeVersion"] as? Int, 1)
        XCTAssertEqual((object["device"] as? [String: String])?["model"], "iPhone18,1")
    }
}
