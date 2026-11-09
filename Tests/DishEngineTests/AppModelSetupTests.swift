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
    private let den = DestinationPick.satellite(id: "den")

    private func model(_ access: AnsweredLocalNetworkAccess, bindings: BindingRequests = BindingRequests()) throws -> AppModel {
        try AppModel(defaults: TestDefaults.fresh(self), localNetwork: access, bindings: bindings)
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
        let bindings = BindingRequests()
        let model = try model(access, bindings: bindings)
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
        XCTAssertEqual(bindings.requests, [])
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

    func testBindRecordsTheDraftOnce() throws {
        let bindings = BindingRequests()
        let model = try model(AnsweredLocalNetworkAccess(status: .allowed), bindings: bindings)
        model.startSetup(.input)
        model.pickSetupInput(pad)
        model.pickSetupDestination(den)
        model.bindSetup()
        XCTAssertEqual(bindings.requests, [SetupDraft(input: pad, destination: den, emulateAs: .dualSense, motion: true)])
    }
}
