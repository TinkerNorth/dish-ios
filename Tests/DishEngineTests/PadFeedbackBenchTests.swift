// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import XCTest
@testable import DishEngine

/// The bench on a pad's feedback queue: a test's writes go straight to the
/// pad and are not the game's; while a test holds a surface the game's
/// commands for it are kept and not written, and the test's end writes the
/// game's last value back, or what the pad showed before when the game never
/// set it; the surfaces the test does not hold keep following the game.
@MainActor
final class PadFeedbackBenchTests: XCTestCase {

    private static let idle = PadIdleState(lightbar: BenchColour(red: 9, green: 8, blue: 7), player: 3)
    private static let released = [UInt8](repeating: 0, count: 11)
    private static let gameBlock: [UInt8] = [0x26, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    private func rig(idle: PadIdleState = idle) -> (FeedbackPad, RecordingActuators, PadFeedback) {
        let actuators = RecordingActuators(idle: idle)
        let feedback = PadFeedback(actuators: actuators, queue: DispatchSerialQueue(label: "test.feedback"))
        return (feedback.pad(for: "pad"), actuators, feedback)
    }

    // MARK: - The test's own writes

    func testATestsWritesReachThePadStraightAndAreNotTheGames() {
        let (pad, actuators, feedback) = rig()
        pad.benchWrite(.lightbar(BenchColour(red: 0xFF, green: 0, blue: 0)))
        pad.benchWrite(.rumble(strong: 0, weak: 48000, durationMs: 400))
        pad.benchWrite(.player(2))
        pad.benchWrite(.triggerEffects(left: FeedbackBench.rigidTriggerBlock, right: FeedbackBench.rigidTriggerBlock))
        pad.benchWrite(.triggerRumble(left: 48000, right: 0, durationMs: 400))
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .lightbar("pad", red: 0xFF, green: 0, blue: 0),
            .rumble("pad", strong: 0, weak: 48000, durationMs: 400),
            .playerLeds("pad", player: 2),
            .triggerEffects("pad", left: FeedbackBench.rigidTriggerBlock, right: FeedbackBench.rigidTriggerBlock),
            .triggerRumble("pad", left: 48000, right: 0, durationMs: 400)
        ])
        XCTAssertEqual(feedback.output(for: "pad"), PadOutputReading.none, "the support file counts what the game sent, not the bench")
    }

    // MARK: - State goes back

    func testALightBarTheGameSetGoesBackToTheGamesColour() {
        let (pad, actuators, feedback) = rig()
        pad.post(lightbarRed: 10, green: 20, blue: 30)
        pad.benchBegin(.lightbar)
        pad.benchWrite(.lightbar(BenchColour(red: 0, green: 0, blue: 0xFF)))
        pad.benchEnd(.lightbar)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .lightbar("pad", red: 10, green: 20, blue: 30),
            .lightbar("pad", red: 0, green: 0, blue: 0xFF),
            .lightbar("pad", red: 10, green: 20, blue: 30)
        ])
    }

    func testALightBarTheGameNeverSetGoesBackToWhatThePadShowedBefore() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.lightbar)
        pad.benchWrite(.lightbar(BenchColour(red: 0xFF, green: 0, blue: 0)))
        pad.benchEnd(.lightbar)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .lightbar("pad", red: 0xFF, green: 0, blue: 0),
            .lightbar("pad", red: 9, green: 8, blue: 7)
        ])
    }

    func testThePlayerLedsGoBackToTheGamesPlayerElseThePlayerThePadShowed() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.playerLeds)
        pad.benchWrite(.player(1))
        pad.benchEnd(.playerLeds)
        pad.post(player: 2)
        pad.benchBegin(.playerLeds)
        pad.benchWrite(.player(4))
        pad.benchEnd(.playerLeds)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .playerLeds("pad", player: 1),
            .playerLeds("pad", player: 3),
            .playerLeds("pad", player: 2),
            .playerLeds("pad", player: 4),
            .playerLeds("pad", player: 2)
        ])
    }

    func testTheTriggersGoBackToTheGamesWholeEffectElseLetGo() {
        let (pad, actuators, feedback) = rig()
        let rigid = FeedbackBench.rigidTriggerBlock
        pad.benchBegin(.triggerEffects)
        pad.benchWrite(.triggerEffects(left: rigid, right: rigid))
        pad.benchEnd(.triggerEffects)
        pad.post(triggerEffectsLeft: Self.gameBlock, right: Self.released)
        pad.benchBegin(.triggerEffects)
        pad.benchWrite(.triggerEffects(left: rigid, right: rigid))
        pad.benchEnd(.triggerEffects)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .triggerEffects("pad", left: rigid, right: rigid),
            .triggerEffects("pad", left: Self.released, right: Self.released),
            .triggerEffects("pad", left: Self.gameBlock, right: Self.released),
            .triggerEffects("pad", left: rigid, right: rigid),
            .triggerEffects("pad", left: Self.gameBlock, right: Self.released)
        ])
    }

    // MARK: - The test owns its surface while it runs

    func testWhileATestHoldsTheLightBarTheGamesColourIsKeptAndPutBackAsItEnds() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.lightbar)
        pad.benchWrite(.lightbar(BenchColour(red: 0xFF, green: 0, blue: 0)))
        feedback.queue.sync {}
        pad.post(lightbarRed: 1, green: 2, blue: 3)
        feedback.queue.sync {}
        pad.post(lightbarRed: 4, green: 5, blue: 6)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [.lightbar("pad", red: 0xFF, green: 0, blue: 0)], "the game's colour waits")
        pad.benchEnd(.lightbar)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations.last, .lightbar("pad", red: 4, green: 5, blue: 6), "the newest colour the game sent goes back")
        XCTAssertEqual(feedback.output(for: "pad")?.lightbar.total, 2, "both of the game's colours count as sent")
    }

    func testWhileATestHoldsTheTriggersTheGamesEffectIsKeptAndPutBackAsItEnds() {
        let (pad, actuators, feedback) = rig()
        let rigid = FeedbackBench.rigidTriggerBlock
        pad.benchBegin(.triggerEffects)
        pad.benchWrite(.triggerEffects(left: rigid, right: rigid))
        pad.post(triggerEffectsLeft: Self.released, right: Self.gameBlock)
        pad.benchEnd(.triggerEffects)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .triggerEffects("pad", left: rigid, right: rigid),
            .triggerEffects("pad", left: Self.released, right: Self.gameBlock)
        ])
    }

    func testABuzzSimplyStopsWhenTheGameSaidNothingDuringIt() {
        let (pad, actuators, feedback) = rig()
        pad.post(rumbleStrong: 1000, weak: 2000, durationMs: 500)
        pad.benchBegin(.rumble)
        pad.benchWrite(.rumble(strong: 48000, weak: 48000, durationMs: 400))
        pad.benchEnd(.rumble)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .rumble("pad", strong: 1000, weak: 2000, durationMs: 500),
            .rumble("pad", strong: 48000, weak: 48000, durationMs: 400)
        ], "the buzz runs out on its own; a rumble the game sent before it is not replayed")
    }

    func testARumbleTheGameAskedForDuringABuzzIsPutBackAsItEnds() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.rumble)
        pad.benchWrite(.rumble(strong: 0, weak: 48000, durationMs: 400))
        feedback.queue.sync {}
        pad.post(rumbleStrong: 30000, weak: 10000, durationMs: 500)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [.rumble("pad", strong: 0, weak: 48000, durationMs: 400)], "the buzz holds the motors")
        pad.benchEnd(.rumble)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations.last, .rumble("pad", strong: 30000, weak: 10000, durationMs: 500))
    }

    func testTheSurfacesATestDoesNotHoldKeepFollowingTheGame() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.lightbar)
        pad.post(rumbleStrong: 1, weak: 2, durationMs: 3)
        pad.post(player: 2)
        pad.post(triggerEffectsLeft: Self.gameBlock, right: Self.gameBlock)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [
            .rumble("pad", strong: 1, weak: 2, durationMs: 3),
            .playerLeds("pad", player: 2),
            .triggerEffects("pad", left: Self.gameBlock, right: Self.gameBlock)
        ])
    }

    func testASurfaceFollowsTheGameAgainOnceItsTestEnds() {
        let (pad, actuators, feedback) = rig()
        pad.benchBegin(.playerLeds)
        pad.benchEnd(.playerLeds)
        pad.post(player: 4)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations.last, .playerLeds("pad", player: 4))
    }

    func testAPadThatShowsNoLightBarGetsNothingPaintedBackButBlack() {
        let (pad, actuators, feedback) = rig(idle: .none)
        pad.benchBegin(.lightbar)
        pad.benchEnd(.lightbar)
        feedback.queue.sync {}
        XCTAssertEqual(actuators.actuations, [.lightbar("pad", red: 0, green: 0, blue: 0)], "a pad without a light takes the write as nothing")
    }

    // MARK: - Another source's pad

    func testABenchTestOnAPadAnotherSourceDrivesRunsOnThatSourcesQueue() {
        let own = RecordingActuators()
        let steam = RecordingActuators()
        let steamQueue = DispatchSerialQueue(label: "test.steam")
        let feedback = PadFeedback(actuators: own, queue: DispatchSerialQueue(label: "test.feedback"))
        feedback.drive(slotsPrefixed: "ble:", on: steamQueue, with: steam)
        let pad = feedback.pad(for: "ble:pad")
        pad.benchBegin(.rumble)
        pad.benchWrite(.rumble(strong: 48000, weak: 0, durationMs: 400))
        pad.post(rumbleStrong: 5, weak: 6, durationMs: 7)
        pad.benchEnd(.rumble)
        steamQueue.sync {}
        feedback.queue.sync {}
        XCTAssertEqual(steam.actuations, [
            .rumble("ble:pad", strong: 48000, weak: 0, durationMs: 400),
            .rumble("ble:pad", strong: 5, weak: 6, durationMs: 7)
        ])
        XCTAssertEqual(own.actuations, [])
    }
}
