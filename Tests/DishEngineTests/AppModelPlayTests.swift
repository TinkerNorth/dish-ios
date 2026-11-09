// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A model whose on-screen controller routes to a recorder, with the loop's
/// ticker and the motion sensor in the test's hands.
@MainActor
private struct PlayModel {
    let model: AppModel
    let source = FakeControllerSource()
    let recorder = InputRecorder()
    let ticker = ManualTicker()
    let sensor: FakeMotionSensor
    let bindings = BindingRequests()

    init(_ test: XCTestCase, sensor: FakeMotionSensor = FakeMotionSensor()) throws {
        self.sensor = sensor
        model = try AppModel(
            defaults: TestDefaults.fresh(test),
            bindings: bindings,
            controllerSource: source,
            motionSensor: sensor,
            resendTicker: ticker
        )
        source.processor.route(recorder.route)
    }

    var play: PlayFacts? {
        model.shellFacts.play
    }

    var onScreenController: ControllerFact? {
        model.shellFacts.controllers.first { $0.id == onScreenSlotId }
    }
}

/// The play intents: the screens open and close on the on-screen
/// controller's slot, the pause menu's switches are that slot's own, and
/// Stop gamepad takes it off the controllers.
@MainActor
final class AppModelPlayTests: XCTestCase {

    func testNoScreenAndNoOnScreenControllerUntilOneOpens() throws {
        let played = try PlayModel(self)
        XCTAssertNil(played.play)
        XCTAssertNil(played.onScreenController)
    }

    func testOpeningTheGamepadShowsItAndListsTheOnScreenController() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        XCTAssertEqual(played.play?.screen, .gamepad)
        let controller = try XCTUnwrap(played.onScreenController)
        XCTAssertEqual(controller.link, .onScreen)
        XCTAssertNil(controller.batteryPercent)
        XCTAssertEqual(controller.features.map(\.feature), [.motion, .rumble])
        XCTAssertTrue(played.ticker.running, "the resend loop runs while a screen is up")
    }

    func testEachScreenOpensByItsOwnIntentAndByTheDispatcher() throws {
        let played = try PlayModel(self)
        played.model.openTouchpad()
        XCTAssertEqual(played.play?.screen, .touchpad)
        played.model.openMouse()
        XCTAssertEqual(played.play?.screen, .mouse)
        for screen in PlayScreen.allCases {
            played.model.openPlay(screen)
            XCTAssertEqual(played.play?.screen, screen)
        }
    }

    func testATouchOnTheGamepadReachesTheOnScreenSlotsRoute() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.onScreenPad(.press(.faceB))
        XCTAssertEqual(played.recorder.reports.map(\.id), [onScreenSlotId])
        XCTAssertEqual(played.recorder.reports.last?.report.buttons, WireButton.faceB.bit)
    }

    func testTheOnScreenControllerSendsWithoutDeadZones() throws {
        let played = try PlayModel(self)
        played.model.onScreenPad(.stick(.left, x: 0.02, y: 0))
        XCTAssertEqual(played.recorder.reports.last?.report.lx, 655)
    }

    func testTheMouseSendsTouchesThroughTheSamePath() throws {
        let played = try PlayModel(self)
        played.model.openMouse()
        played.model.onScreenTouch(.rightButton(held: true))
        XCTAssertEqual(played.recorder.touches.last?.sample.rightPressed, true)
    }

    func testClosingReleasesWhatTheScreenHeldAndDropsTheScreen() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.onScreenPad(.press(.faceA))
        played.model.closePlay()
        XCTAssertNil(played.play)
        XCTAssertEqual(played.recorder.reports.last?.report, .released)
        XCTAssertNotNil(played.onScreenController, "closing keeps the controller listed")
    }

    func testClosingWithNoScreenUpDoesNothing() throws {
        let played = try PlayModel(self)
        played.model.closePlay()
        XCTAssertEqual(played.recorder.sent, [])
    }

    func testMovingToAnotherScreenReleasesWhatTheGamepadHeld() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.onScreenPad(.press(.faceA))
        played.model.openTouchpad()
        XCTAssertEqual(played.recorder.reports.last?.report, .released)
        XCTAssertEqual(played.play?.screen, .touchpad)
        XCTAssertTrue(played.ticker.running)
    }

    func testRumbleAndMotionAreTheOnScreenSlotsOwnSwitches() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.setPlayRumble(false)
        played.model.setPlayMotion(false)
        XCTAssertEqual(played.play?.rumble, false)
        XCTAssertEqual(played.play?.motion, false)
        XCTAssertFalse(played.model.forwardingFlags(slotId: onScreenSlotId).rumble, "the return path gates on it")
        let features = try XCTUnwrap(played.onScreenController?.features)
        XCTAssertEqual(features.map(\.enabled), [false, false])
    }

    func testEmulateAsPicksThePadThePCSeesAndAnXboxPadHasNoMotion() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        XCTAssertEqual(played.play?.emulateAs, .xboxWireless)
        XCTAssertEqual(played.play?.motionAvailability, .padHasNone)
        played.model.setPlayEmulateAs(.dualSense)
        XCTAssertEqual(played.play?.emulateAs, .dualSense)
        XCTAssertEqual(played.onScreenController?.emulateAs, .dualSense)
        XCTAssertEqual(played.play?.motionAvailability, .available)
    }

    func testAPhoneWithoutMotionSensorsSaysSoAndOffersNoMotionSwitch() throws {
        let played = try PlayModel(self, sensor: FakeMotionSensor(available: false))
        played.model.setPlayEmulateAs(.dualSense)
        played.model.openGamepad()
        XCTAssertEqual(played.play?.motionAvailability, .phoneHasNone)
        XCTAssertEqual(played.onScreenController?.features.map(\.feature), [.rumble])
    }

    func testMotionRunsOnTheGamepadWhileItsSwitchIsOnAndThePadCarriesIt() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        XCTAssertFalse(played.sensor.running, "an Xbox pad has no motion")
        played.model.setPlayEmulateAs(.dualSense)
        XCTAssertTrue(played.sensor.running)
        played.sensor.feed(phoneAtRestTopLeft)
        XCTAssertEqual(played.recorder.motion.map(\.id), [onScreenSlotId])
        played.model.setPlayMotion(false)
        XCTAssertFalse(played.sensor.running)
        played.model.setPlayMotion(true)
        played.model.openMouse()
        XCTAssertFalse(played.sensor.running, "the mouse carries no motion")
        played.model.openGamepad()
        played.model.closePlay()
        XCTAssertFalse(played.sensor.running)
    }

    func testASwitchProMakesTheRailsDigital() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.setPlayEmulateAs(.switchPro)
        played.model.onScreenPad(.trigger(.right, railY: 0.9))
        XCTAssertEqual(played.recorder.reports.last?.report.rt, 255)
    }

    func testStopGamepadClosesTheScreenAndTakesTheControllerOffTheList() throws {
        let played = try PlayModel(self)
        played.model.openGamepad()
        played.model.onScreenPad(.press(.faceA))
        played.model.stopOnScreenGamepad()
        XCTAssertNil(played.play)
        XCTAssertNil(played.onScreenController)
        XCTAssertEqual(played.recorder.reports.last?.report, .released)
    }

    func testSetupBindingTheOnScreenGamepadListsItWithTheWalksPicks() throws {
        let played = try PlayModel(self)
        played.model.startSetup(.input)
        played.model.pickSetupInput(.onScreen)
        played.model.answerLocalNetwork(allowed: true)
        played.model.pickSetupDestination(.byAddress)
        played.model.setSetupEmulateAs(.dualShock4)
        played.model.setSetupMotion(false)
        played.model.bindSetup()
        let controller = try XCTUnwrap(played.onScreenController)
        XCTAssertEqual(controller.emulateAs, .dualShock4)
        XCTAssertEqual(controller.features.first { $0.feature == .motion }?.enabled, false)
    }

    func testSetupBindingAPadLeavesTheOnScreenControllerOff() throws {
        let played = try PlayModel(self)
        played.model.startSetup(.input)
        played.model.pickSetupInput(.wired)
        played.model.answerLocalNetwork(allowed: true)
        played.model.pickSetupDestination(.byAddress)
        played.model.bindSetup()
        XCTAssertNil(played.onScreenController)
    }

    func testTheOnScreenSlotsRumbleIsGatedByItsSwitchOnTheReturnPath() throws {
        let played = try PlayModel(self)
        let actuators = RecordingActuators()
        let feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        played.model.setPlayRumble(false)
        let bound = SatellitePadKey(connectionId: "sat", controllerIndex: 0)
        let off = BoundSlotRoute(slotId: onScreenSlotId, flags: played.model.forwardingFlags(slotId: onScreenSlotId))
        let routes = FeedbackRoutes(
            connectionId: "sat",
            snapshot: RoutingSnapshot(bySatellitePad: [bound: off]),
            global: ForwardingFlags(),
            feedback: feedback
        )
        routes.rumble(controllerIndex: 0, strong: 40000, weak: 0, durationMs: 100)
        played.model.setPlayRumble(true)
        let on = BoundSlotRoute(slotId: onScreenSlotId, flags: played.model.forwardingFlags(slotId: onScreenSlotId))
        let live = FeedbackRoutes(
            connectionId: "sat",
            snapshot: RoutingSnapshot(bySatellitePad: [bound: on]),
            global: ForwardingFlags(),
            feedback: feedback
        )
        live.rumble(controllerIndex: 0, strong: 40000, weak: 0, durationMs: 100)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [.rumble(onScreenSlotId, strong: 40000, weak: 0, durationMs: 100)])
    }
}
