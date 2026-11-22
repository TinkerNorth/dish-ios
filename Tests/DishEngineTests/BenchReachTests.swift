// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import GameController
import XCTest
@testable import DishEngine

/// What each path carries to the bench: a GameController pad's motors by
/// the haptic localities it reports and its light bar, player LEDs and
/// adaptive triggers as its capabilities say; the 2026 Steam Controller's
/// two motors and the 2015 pad's none; the phone's one actuator for the
/// on-screen controller; the sticks of every pad Dish reads. And the
/// framework's values the bench puts back, read the way the game's writes
/// set them.
final class BenchReachTests: XCTestCase {

    // MARK: - A GameController pad's motors

    func testThePadsHandlesAreItsBodyMotorsAndItsTriggersItsTriggerMotors() {
        let all: Set<GCHapticsLocality> = [.default, .all, .handles, .leftHandle, .rightHandle, .triggers, .leftTrigger, .rightTrigger]
        XCTAssertEqual(hapticMotors(all), [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor])
    }

    func testTheStrongMotorIsTheLeftHandleAndTheWeakTheRight() {
        XCTAssertEqual(hapticMotors([.leftHandle]), [.strongMotor])
        XCTAssertEqual(hapticMotors([.rightHandle]), [.weakMotor])
    }

    func testAPadThatReportsOnlyTheGuaranteedLocalitiesReachesNoMotorItsRumbleDrives() {
        XCTAssertEqual(hapticMotors([.default, .all]), [], "the game's rumble drives the two handles, so neither alone is a motor here")
        XCTAssertEqual(hapticMotors([.default, .all, .handles]), [])
        XCTAssertEqual(hapticMotors([]), [])
    }

    // MARK: - Each path's reach

    func testADualSenseReachesEveryItemGameControllerOffers() {
        let capabilities = ControllerCapabilities(
            hasRumble: true,
            hasLightbar: true,
            hasTriggerEffects: true,
            hasPlayerLeds: true,
            motors: [.strongMotor, .weakMotor]
        )
        let slot = ControllerSlot(id: "gc:Sony:DualSense", name: "DualSense", capabilities: capabilities)
        XCTAssertEqual(benchReach(slot), [.strongMotor, .weakMotor, .lightbar, .playerLeds, .adaptiveTriggers, .sticks])
    }

    func testAnXboxPadWithImpulseTriggersReachesItsFourMotorsAndItsSticks() {
        let capabilities = ControllerCapabilities(
            hasRumble: true,
            motors: [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor]
        )
        let slot = ControllerSlot(id: "gc:Microsoft:Xbox", name: "Xbox Wireless Controller", capabilities: capabilities)
        XCTAssertEqual(benchReach(slot), [.strongMotor, .weakMotor, .leftTriggerMotor, .rightTriggerMotor, .sticks])
    }

    func testAPadDishCannotReadReachesNothing() {
        let slot = ControllerSlot(id: "gc:Apple:Remote", name: "Siri Remote", readable: false)
        XCTAssertEqual(benchReach(slot), [])
    }

    func testThe2026SteamControllerReachesItsTwoMotorsAndThe2015PadNone() {
        let triton = steamSlot(UUID(), SteamBleModels.triton)
        let original = steamSlot(UUID(), SteamBleModels.original)
        XCTAssertEqual(benchReach(triton), [.strongMotor, .weakMotor, .sticks])
        XCTAssertEqual(benchReach(original), [.sticks], "the 2015 pad has no motors its writer drives")
    }

    func testTheOnScreenControllerReachesThePhonesOneActuatorWhereThePhoneHasOne() {
        XCTAssertEqual(onScreenBenchReach(phoneHaptics: true), [.oneActuator])
        XCTAssertEqual(onScreenBenchReach(phoneHaptics: false), [], "and its sticks are the gamepad screen's, which covers the bench")
    }

    // MARK: - What the framework shows, read back

    @MainActor
    func testAPlayerIndexReadsBackAsThePlayerItLights() {
        let indices: [GCControllerPlayerIndex] = [.index1, .index2, .index3, .index4, .indexUnset]
        XCTAssertEqual(indices.map(GameControllerInput.player(of:)), [1, 2, 3, 4, 0])
        for player in 0 ... 4 {
            XCTAssertEqual(
                GameControllerInput.player(of: GameControllerInput.playerIndex(for: player)),
                player,
                "player \(player) round-trips"
            )
        }
    }

    @MainActor
    func testALightsColourReadsBackInTheBytesTheGameWroteIt() {
        for byte: UInt8 in [0, 1, 127, 128, 200, 255] {
            let written = GCColor(red: Float(byte) / 255, green: 0, blue: 1)
            XCTAssertEqual(GameControllerInput.benchColour(written), BenchColour(red: byte, green: 0, blue: 255), "byte \(byte)")
        }
    }

    func testTheBenchsRigidBlockPlaysFullResistanceFromTheTopOfTheTravel() {
        XCTAssertEqual(DualSenseTriggerEffect.decode(FeedbackBench.rigidTriggerBlock), .feedback(startPosition: 0, strength: 1))
        XCTAssertEqual(DualSenseTriggerEffect.decode(FeedbackBench.releasedTriggerBlock), .off)
    }
}
