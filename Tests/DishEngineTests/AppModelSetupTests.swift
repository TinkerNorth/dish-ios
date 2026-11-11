// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A Local Network seam whose status a test sets.
@MainActor
private final class AnsweredLocalNetworkAccess: LocalNetworkAccess {
    var status: LocalNetworkStatus
    private(set) var asks = 0
    private(set) var scans = 0

    init(status: LocalNetworkStatus) {
        self.status = status
    }

    func ask() {
        asks += 1
    }

    func scan() {
        scans += 1
    }
}

/// The setup intents through the model: each applies the machine to the
/// model's walk and runs what it asks for.
@MainActor
final class AppModelSetupTests: XCTestCase {

    private let pad = InputKind.detectedPad(id: "pad-1", family: .dualSense)
    private let den = DestinationPick.satellite(id: "mid:den")

    private func model(_ access: AnsweredLocalNetworkAccess) throws -> AppModel {
        let defaults = try TestDefaults.fresh(self)
        let source = FakeControllerSource(slots: [ControllerSlot(id: "pad-1", name: "DualSense", family: .dualSense)])
        return AppModel(
            onboarding: OnboardingPreferenceStore(defaults: defaults),
            appearance: AppearancePreferenceStore(defaults: defaults),
            device: DevicePreferenceStore(defaults: defaults),
            streaming: StreamingPreferenceStore(defaults: defaults),
            clock: ClockSource(ticker: ManualTicker(), now: Date.init),
            localNetwork: access,
            pads: ControllerStack(source: source, defaults: defaults),
            network: TestNetwork.stack(defaults: defaults, remembered: [TestNetwork.satellite("den")]),
            tips: RecordedTipStore(shelf: .success([])),
            motionSensor: FakeMotionSensor(),
            resendTicker: ManualTicker()
        )
    }

    private func freshModel() throws -> AppModel {
        try AppModel(defaults: TestDefaults.fresh(self))
    }

    func testAFreshModelHasNoWalk() throws {
        XCTAssertNil(try freshModel().setup)
    }

    func testStartingSetupOpensAWalkAtItsStart() throws {
        let model = try freshModel()
        model.startSetup(.welcome)
        XCTAssertEqual(model.setup, SetupState(start: .welcome))
        model.startSetup(.input)
        XCTAssertEqual(model.setup, SetupState(start: .input), "a second start opens a fresh walk")
    }

    func testEndingSetupDropsTheWalk() throws {
        let model = try freshModel()
        model.startSetup(.welcome)
        model.endSetup()
        XCTAssertNil(model.setup)
    }

    func testIntentsWithoutAWalkDoNothing() throws {
        let access = AnsweredLocalNetworkAccess(status: .unknown)
        let model = try model(access)
        model.setupNext()
        model.setupBack()
        model.setupSkip()
        model.pickSetupInput(.wired)
        model.answerLocalNetwork(allowed: true)
        model.pickSetupDestination(.byAddress)
        model.setSetupEmulateAs(.switchPro)
        model.setSetupMotion(true)
        model.bindSetup()
        XCTAssertNil(model.setup)
        XCTAssertEqual(access.asks + access.scans, 0)
        XCTAssertEqual(model.network.hub.bindings, [:])
    }

    func testNextAndBackWalkTheSteps() throws {
        let model = try freshModel()
        model.startSetup(.welcome)
        model.setupNext()
        XCTAssertEqual(model.setup?.step, .input)
        model.setupBack()
        XCTAssertEqual(model.setup?.step, .welcome)
    }

    func testSkipKeepsTheWalkForTheNavigationToLower() throws {
        let model = try freshModel()
        model.startSetup(.input)
        model.setupSkip()
        XCTAssertEqual(model.setup, SetupState(start: .input))
    }

    func testPickingAnInputReadsTheLocalNetworkStatus() throws {
        let unasked = try model(AnsweredLocalNetworkAccess(status: .unknown))
        unasked.startSetup(.input)
        unasked.pickSetupInput(pad)
        XCTAssertEqual(unasked.setup?.step, .localNetworkPrimer)

        let access = AnsweredLocalNetworkAccess(status: .allowed)
        let allowed = try model(access)
        allowed.startSetup(.input)
        allowed.pickSetupInput(pad)
        XCTAssertEqual(allowed.setup?.step, .pickPC)
        XCTAssertEqual(access.scans, 1, "the scan reached the seam")
    }

    func testThePrimersContinueAsksIOSAndTheAnswerScans() throws {
        let access = AnsweredLocalNetworkAccess(status: .unknown)
        let model = try model(access)
        model.startSetup(.input)
        model.pickSetupInput(pad)
        model.setupNext()
        XCTAssertEqual(access.asks, 1)
        access.status = .allowed
        model.answerLocalNetwork(allowed: true)
        XCTAssertEqual(model.setup?.step, .pickPC)
        XCTAssertEqual(access.scans, 1)
    }

    func testThePrimerBeingAnsweredMarksItSeenSoTheConnectionsTabMayScan() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .unknown))
        XCTAssertFalse(model.onboarding.state.localNetworkPrimed)
        model.startSetup(.input)
        model.pickSetupInput(pad)
        XCTAssertFalse(model.onboarding.state.localNetworkPrimed, "reading the primer is not asking")
        model.setupNext()
        XCTAssertTrue(model.onboarding.state.localNetworkPrimed)
    }

    /// Settings › Setup guide, with iOS asked already, walks past the
    /// primer straight to Pick your PC, whose scan is the question's answer.
    func testAGuideWalkedAfterIOSWasAskedMarksTheQuestionExplainedToo() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .allowed))
        model.startSetup(.welcome)
        model.setupNext()
        model.pickSetupInput(pad)
        XCTAssertEqual(model.setup?.step, .pickPC)
        XCTAssertTrue(model.onboarding.state.localNetworkPrimed)
    }

    func testPickingAPCAndEditingTheDraftReachReview() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .allowed))
        model.startSetup(.input)
        model.pickSetupInput(pad)
        model.pickSetupDestination(den)
        model.setSetupEmulateAs(.switchPro)
        model.setSetupMotion(false)
        XCTAssertEqual(model.setup?.step, .review)
        XCTAssertEqual(model.setup?.draft, SetupDraft(input: pad, destination: den, emulateAs: .switchPro, motion: false))
    }

    /// Review's Bind binds the pad it names to the satellite it picked,
    /// with the walk's pick and motion switch, and reaches for the satellite.
    func testBindBindsTheDetectedPadToThePickedSatelliteWithTheWalksChoices() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .allowed))
        model.startSetup(.input)
        model.pickSetupInput(pad)
        model.pickSetupDestination(den)
        model.setSetupEmulateAs(.switchPro)
        model.setSetupMotion(false)
        model.bindSetup()
        XCTAssertEqual(model.network.hub.bindings, ["pad-1": "mid:den"])
        XCTAssertEqual(model.pads.types.typeFor("pad-1"), .switchPro)
        XCTAssertFalse(model.pads.switches.preferences(for: "pad-1").isOn(.motion))
        XCTAssertEqual(model.bindingProgress, .running(.binding), "no session yet, so the bind waits for the link")
        XCTAssertEqual(model.network.wifi.get("mid:den")?.state, .linking, "the satellite is reached for")
    }

    /// Review's Bind of the on-screen gamepad lists it and binds its own
    /// slot to the satellite, with the pick the walk chose.
    func testBindOfTheOnScreenGamepadBindsItsSlotToThePickedSatellite() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .allowed))
        model.startSetup(.input)
        model.pickSetupInput(.onScreen)
        model.pickSetupDestination(den)
        model.setSetupEmulateAs(.dualSense)
        model.bindSetup()
        XCTAssertEqual(model.network.hub.bindings, [onScreenSlotId: "mid:den"])
        XCTAssertEqual(model.shellFacts.controllers.map(\.id), ["pad-1", onScreenSlotId], "the on-screen gamepad joins the controllers")
        XCTAssertEqual(model.pads.types.typeFor(onScreenSlotId), .dualSense)
        XCTAssertEqual(model.bindingProgress, .running(.binding))
    }

    /// A PC added by address on the primer is the one Bind binds to.
    func testBindOfAPCAddedByAddressBindsThePadToIt() throws {
        let model = try model(AnsweredLocalNetworkAccess(status: .unknown))
        model.startSetup(.input)
        model.pickSetupInput(pad)
        model.pickSetupDestination(.byAddress)
        XCTAssertEqual(model.setup?.step, .review)
        XCTAssertTrue(model.addByAddress("192.0.2.77"))
        model.bindSetup()
        XCTAssertEqual(model.network.hub.bindings, ["pad-1": "wifi:192.0.2.77:9876"])
        XCTAssertEqual(model.bindingProgress, .running(.binding))
    }

    /// A way in with no pad yet, a destination with no PC yet, and a
    /// Moonlight host each bind nothing.
    func testBindWithoutAPadOrAPCBindsNothing() throws {
        let noPad = try model(AnsweredLocalNetworkAccess(status: .allowed))
        noPad.startSetup(.input)
        noPad.pickSetupInput(.wired)
        noPad.pickSetupDestination(den)
        noPad.bindSetup()
        XCTAssertEqual(noPad.network.hub.bindings, [:])

        let noAddress = try model(AnsweredLocalNetworkAccess(status: .allowed))
        noAddress.startSetup(.input)
        noAddress.pickSetupInput(.onScreen)
        noAddress.pickSetupDestination(.byAddress)
        noAddress.bindSetup()
        XCTAssertEqual(noAddress.network.hub.bindings, [:])

        let moonlight = try model(AnsweredLocalNetworkAccess(status: .allowed))
        moonlight.startSetup(.input)
        moonlight.pickSetupInput(pad)
        moonlight.pickSetupDestination(.moonlightHost(id: "den"))
        moonlight.bindSetup()
        XCTAssertEqual(moonlight.network.hub.bindings, [:])
        XCTAssertEqual(moonlight.bindingProgress, .idle)
    }
}
