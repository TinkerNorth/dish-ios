// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// Report a problem through the model: Preview writes the file the mail
/// will carry, Continue in Mail hands the mail app one message to support
/// under the category's subject, and the file holds the person's words,
/// the device's conditions and every controller path, input and output.
@MainActor
final class AppModelReportTests: XCTestCase {

    private static let steam2026 = ControllerSlot(
        id: "ble:pad",
        name: "Valve Steam Controller (2026, Bluetooth)",
        capabilities: ControllerCapabilities(hasMotion: true, hasTouchpad: true, hasRumble: true, hasExtendedButtons: true),
        trackpads: .twoPads,
        source: .bluetooth(vendorId: 0x28DE, productId: 0x1303)
    )

    private static let xbox = ControllerSlot(
        id: "gc:Xbox Wireless Controller:Xbox One",
        name: "Xbox Wireless Controller",
        capabilities: ControllerCapabilities(hasRumble: true, hasBattery: true),
        family: .xbox,
        source: .gameController(category: "Xbox One")
    )

    private static let mail = ReportMail(category: "No rumble or feedback", body: "It never rumbles.\n\nthe summary")

    private let mailer = RecordedDiagnosticsMailer()
    private var diagnosticsFolder: URL!
    private var source: FakeControllerSource!

    override func setUp() async throws {
        diagnosticsFolder = freshCacheFolder(self)
    }

    private func model(
        _ pads: [ControllerSlot],
        battery: BatteryReading? = nil,
        conditions: any DeviceConditions = InertDeviceConditions()
    ) throws -> AppModel {
        let defaults = try TestDefaults.fresh(self)
        source = FakeControllerSource(slots: pads)
        return AppModel(
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
            diagnostics: DiagnosticsSource(ticker: ManualTicker()),
            deviceBattery: FakeDeviceBattery(battery),
            controllerDb: .offline(defaults: defaults),
            identity: DeviceIdentity(appVersion: "1.1.0", appBuild: "7", model: "iPhone18,1", systemVersion: "26.1"),
            mailer: mailer,
            diagnosticsFolder: diagnosticsFolder,
            deviceConditions: conditions
        )
    }

    private func draft(
        _ category: ReportCategory = .noFeedback,
        text: String = "It never rumbles.",
        controller: String? = nil
    ) -> ReportDraft {
        ReportDraft(category: category, text: text, controllerId: controller)
    }

    private func sentFile() throws -> [String: Any] {
        let file = try XCTUnwrap(mailer.mails.first?.attachment)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    }

    private func controller(_ object: [String: Any], path: String) throws -> [String: Any] {
        let controllers = try XCTUnwrap(object["controllers"] as? [[String: Any]])
        return try XCTUnwrap(controllers.first { $0["path"] as? String == path })
    }

    // MARK: - The mail

    func testContinueInMailHandsTheMailAppOneMessageToSupportUnderTheCategory() async throws {
        let model = try model([Self.steam2026])
        await model.continueReport(draft(), mail: Self.mail).value
        let mail = try XCTUnwrap(mailer.mails.first)
        XCTAssertEqual(mailer.mails.count, 1)
        XCTAssertEqual(mail.recipient, "support@tinkernorth.com")
        XCTAssertEqual(mail.subject, "Dish support: No rumble or feedback · Dish for iOS 1.1.0 on iPhone18,1")
        XCTAssertEqual(mail.body, "It never rumbles.\n\nthe summary")
        XCTAssertEqual(mail.attachment.deletingLastPathComponent().standardizedFileURL, diagnosticsFolder.standardizedFileURL)
        XCTAssertTrue(mail.attachment.lastPathComponent.hasPrefix("dish-diagnostics-dish-ios-"))
        XCTAssertEqual(mail.attachment.pathExtension, "json")
    }

    func testTheFileCarriesThePersonsReportAndTheirPadByItsRecord() async throws {
        let model = try model([Self.steam2026])
        await model.continueReport(draft(controller: Self.steam2026.id), mail: Self.mail).value
        let report = try XCTUnwrap(sentFile()["report"] as? [String: Any])
        XCTAssertEqual(report["category"] as? String, "noFeedback")
        XCTAssertEqual(report["text"] as? String, "It never rumbles.")
        XCTAssertEqual(report["controller"] as? String, "valve-steam-controller-2026-bluetooth")
    }

    func testAPadNoRecordMatchedGoesByItsName() async throws {
        let model = try model([Self.xbox])
        await model.continueReport(draft(controller: Self.xbox.id), mail: Self.mail).value
        XCTAssertEqual(try (sentFile()["report"] as? [String: Any])?["controller"] as? String, "Xbox Wireless Controller")
    }

    func testTheOnScreenControllerGoesByItsSlot() async throws {
        let model = try model([])
        await model.continueReport(draft(controller: onScreenSlotId), mail: Self.mail).value
        XCTAssertEqual(try (sentFile()["report"] as? [String: Any])?["controller"] as? String, "on-screen")
    }

    func testAReportAboutNoControllerSaysNull() async throws {
        let model = try model([Self.xbox])
        await model.continueReport(draft(.question, text: "Does it work with a Switch pad?"), mail: Self.mail).value
        let report = try XCTUnwrap(sentFile()["report"] as? [String: Any])
        XCTAssertEqual(report["category"] as? String, "question")
        XCTAssertTrue(report["controller"] is NSNull)
    }

    // MARK: - Preview

    func testPreviewWritesTheFileAndShowsItsText() async throws {
        let model = try model([Self.xbox])
        await model.previewReport(draft()).value
        guard case let .ready(made, prepared) = model.reportFacts.preparation else {
            return XCTFail("expected a prepared file, got \(model.reportFacts.preparation)")
        }
        XCTAssertEqual(made, draft())
        XCTAssertTrue(prepared.text.contains("\"text\" : \"It never rumbles.\""))
        XCTAssertEqual(try String(contentsOf: prepared.file, encoding: .utf8), prepared.text)
        XCTAssertTrue(mailer.mails.isEmpty, "a preview sends nothing")
    }

    func testContinueAfterAPreviewSendsTheFilePreviewed() async throws {
        let model = try model([Self.xbox])
        await model.previewReport(draft()).value
        guard case let .ready(_, previewed) = model.reportFacts.preparation else { return XCTFail("no preview") }
        await model.continueReport(draft(), mail: Self.mail).value
        XCTAssertEqual(mailer.mails.first?.attachment, previewed.file)
    }

    func testADraftChangedSinceThePreviewIsANewFile() async throws {
        let model = try model([Self.xbox])
        await model.previewReport(draft(text: "first")).value
        await model.continueReport(draft(text: "second"), mail: Self.mail).value
        XCTAssertEqual(try (sentFile()["report"] as? [String: Any])?["text"] as? String, "second")
    }

    func testNothingIsPreparedUntilAsked() throws {
        XCTAssertEqual(try model([]).reportFacts.preparation, .idle)
    }

    // MARK: - The device

    func testTheDeviceTellsItsBatteryTemperatureAndPowerSaving() async throws {
        let conditions = FixedDeviceConditions(thermal: .serious, lowPowerMode: true)
        let model = try model([], battery: BatteryReading(level: 41, state: .charging), conditions: conditions)
        await model.continueReport(draft(), mail: Self.mail).value
        let device = try XCTUnwrap(sentFile()["device"] as? [String: Any])
        XCTAssertEqual((device["battery"] as? [String: Any])?["level"] as? Int, 41)
        XCTAssertEqual((device["battery"] as? [String: Any])?["charging"] as? Bool, true)
        XCTAssertEqual(device["thermal"] as? String, "serious")
        XCTAssertEqual(device["powerSave"] as? Bool, true)
        XCTAssertTrue(device["wifi"] is NSNull, "iOS gives an app no Wi-Fi signal")
    }

    func testTheThermalStatesAreTheContractsWords() {
        XCTAssertEqual(bundleThermal(.nominal), .nominal)
        XCTAssertEqual(bundleThermal(.fair), .fair)
        XCTAssertEqual(bundleThermal(.serious), .serious)
        XCTAssertEqual(bundleThermal(.critical), .critical)
    }

    // MARK: - Every controller path

    func testTheOnScreenControllerIsTheVirtualPathAndRumblesThePhone() async throws {
        let model = try model([])
        await model.continueReport(draft(), mail: Self.mail).value
        let onScreen = try controller(sentFile(), path: "virtual")
        XCTAssertTrue(onScreen["transport"] is NSNull)
        XCTAssertEqual(((onScreen["output"] as? [String: Any])?["rumble"] as? [String: Any])?["target"] as? String, "phone")
    }

    func testAPadCarriesTheFramesItPublishedAndTheLastOfThem() async throws {
        let model = try model([Self.xbox])
        let report = GamepadReport(buttons: 0x1000, lt: 0, rt: 200, lx: 0, ly: 0, rx: 0, ry: 0)
        source.processor.feed(for: Self.xbox.id).publish(report)
        source.processor.feed(for: Self.xbox.id).publish(GamepadReport(buttons: 0x1000, lt: 0, rt: 255, lx: 0, ly: 0, rx: 0, ry: 0))
        await model.continueReport(draft(), mail: Self.mail).value
        let input = try XCTUnwrap(controller(sentFile(), path: "gameController")["input"] as? [String: Any])
        XCTAssertEqual(input["frames"] as? Int, 2)
        XCTAssertEqual((input["last"] as? [String: Any])?["rt"] as? Int, 255)
        XCTAssertEqual((input["last"] as? [String: Any])?["buttons"] as? String, "1000")
    }

    func testAPadCarriesWhatReachedItsActuatorsPerLane() async throws {
        let model = try model([Self.xbox])
        let pad = source.feedback.pad(for: Self.xbox.id)
        pad.post(rumbleStrong: 32768, weak: 512, durationMs: 100)
        pad.post(lightbarRed: 0, green: 0, blue: 255)
        source.feedback.queue.sync {}
        await model.continueReport(draft(), mail: Self.mail).value
        let output = try XCTUnwrap(controller(sentFile(), path: "gameController")["output"] as? [String: Any])
        let rumble = try XCTUnwrap(output["rumble"] as? [String: Any])
        XCTAssertEqual(rumble["count"] as? Int, 1)
        XCTAssertEqual(rumble["target"] as? String, "framework")
        XCTAssertEqual((rumble["last"] as? [String: Any])?["strong"] as? Int, 32768)
        XCTAssertEqual((rumble["last"] as? [String: Any])?["weak"] as? Int, 512)
        XCTAssertEqual(((output["lightbar"] as? [String: Any])?["last"] as? [String: Any])?["b"] as? Int, 255)
        XCTAssertEqual((output["playerLeds"] as? [String: Any])?["count"] as? Int, 0)
        XCTAssertTrue((output["playerLeds"] as? [String: Any])?["last"] is NSNull, "a lane never driven has no last")
    }

    func testASteamControllerIsDishsOwnBluetoothPath() async throws {
        let model = try model([Self.steam2026])
        await model.continueReport(draft(), mail: Self.mail).value
        let steam = try controller(sentFile(), path: "bluetooth")
        XCTAssertEqual(steam["bluetooth"] as? [String: String], ["profile": "ble", "transportLayer": "le"])
        XCTAssertEqual(((steam["output"] as? [String: Any])?["rumble"] as? [String: Any])?["target"] as? String, "directBle")
    }
}
