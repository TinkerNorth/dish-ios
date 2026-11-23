// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// What the mail app is handed when a pad is bound to a satellite with a
/// name and an address and another to a Moonlight host known by its link-
/// local address: the facts the page words the body from name the hosts
/// only as each pad's destination, which the body leaves out
/// (`ReportMappersTests`), and the subject and the attachment's name carry
/// neither host. The share sheet, where no mail account is set up, is
/// handed the attachment alone (`DiagnosticsMailComposer.shareSheet`).
@MainActor
final class AppModelReportMailTests: XCTestCase {

    static let canaries = ["CANARY-PC-NAME", "192.0.2.77", "fe80::c0ff:ee77", "CANARY-PC-NAME-ML"]

    private let satellite = DiscoveredServer(name: "CANARY-PC-NAME", ip: "192.0.2.77", machineId: "canary")
    private let moonlight = MoonlightHost(name: "CANARY-PC-NAME-ML", address: "fe80::c0ff:ee77", uniqueId: "ml")
    private let toSatellite = ControllerSlot(id: "pad", name: "DualSense", capabilities: .none, family: .dualSense)
    private let toMoonlight = ControllerSlot(id: "pad-ml", name: "Xbox Wireless Controller", capabilities: .none, family: .xbox)
    private let mailer = RecordedDiagnosticsMailer()
    private var model: AppModel!

    override func setUp() async throws {
        let defaults = try TestDefaults.fresh(self)
        let hosts = MoonlightHostStore(defaults: defaults)
        hosts.put(RememberedMoonlightHost(host: moonlight, paired: true))
        hosts.putBinding(RememberedMoonlightBinding(
            slotId: toMoonlight.id,
            hostId: moonlight.id,
            controllerType: Int(MoonlightControllerType.xbox)
        ))
        model = AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: RecordedLocalNetworkAccess(),
            pads: ControllerStack(source: FakeControllerSource(slots: [toSatellite, toMoonlight]), defaults: defaults),
            network: TestNetwork.stack(defaults: defaults, remembered: [satellite]),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker(),
            diagnostics: DiagnosticsSource(ticker: ManualTicker()),
            controllerDb: .offline(defaults: defaults),
            identity: DeviceIdentity(appVersion: "1.1.0", appBuild: "7", model: "iPhone18,1", systemVersion: "26.1"),
            mailer: mailer,
            diagnosticsFolder: freshCacheFolder(self)
        )
        model.bind(slotId: toSatellite.id, to: satellite.id)
    }

    override func tearDown() async throws {
        await model.network.moonlight.awaitQuiet()
        model = nil
    }

    private func bound() async -> Bool {
        for _ in 0 ..< 200 where model.network.hub.bindings.count < 2 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return model.network.hub.bindings.count == 2
    }

    func testTheReportsFactsNameEachHostOnlyAsAPadsDestination() async {
        let both = await bound()
        XCTAssertTrue(both)
        let destinations = model.reportFacts.controllers.compactMap(\.destination).map(\.name).sorted()
        XCTAssertEqual(destinations, ["CANARY-PC-NAME", "CANARY-PC-NAME-ML"])
    }

    func testTheSubjectAndTheAttachmentsNameCarryNoHost() async throws {
        let both = await bound()
        XCTAssertTrue(both)
        let draft = ReportDraft(category: .connection, text: "It drops.", controllerId: toSatellite.id)
        await model.continueReport(draft, mail: ReportMail(category: "Connection or latency", body: "It drops.")).value
        let mail = try XCTUnwrap(mailer.mails.first)
        XCTAssertEqual(mail.subject, "Dish support: Connection or latency · Dish for iOS 1.1.0 on iPhone18,1")
        for canary in Self.canaries {
            XCTAssertFalse(mail.subject.contains(canary), canary)
            XCTAssertFalse(mail.attachment.lastPathComponent.contains(canary), canary)
        }
    }
}
