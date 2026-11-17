// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The descriptor claims what the pad has AND the user allows: a cap is a
/// promise the matching path lands.
final class DescriptorCapsTests: XCTestCase {

    private let everything = ControllerCapabilities(
        hasMotion: true,
        hasTouchpad: true,
        hasRumble: true,
        hasLightbar: true,
        hasBattery: true,
        hasTriggerEffects: true,
        hasPlayerLeds: true
    )

    func testAFullPadWithEverySwitchOnClaimsEveryActuatorButAudio() {
        let word = descriptorCaps(everything, ForwardingFlags())
        XCTAssertEqual(
            word,
            ProtocolConstants.capAnalogTriggers | ProtocolConstants.capRumble | ProtocolConstants.capMotion
                | ProtocolConstants.capLightbar | ProtocolConstants.capTriggerEffects | ProtocolConstants.capPlayerLeds
        )
        XCTAssertEqual(word & (ProtocolConstants.capMic | ProtocolConstants.capSpeaker | ProtocolConstants.capHapticAudio), 0)
    }

    /// iOS gives apps no pad microphone or speaker, so no descriptor claims
    /// the audio lanes, whatever the pad is.
    func testTheAudioCapsAreNeverClaimed() {
        let word = descriptorCaps(everything, ForwardingFlags())
        XCTAssertEqual(word & (ProtocolConstants.capMic | ProtocolConstants.capSpeaker | ProtocolConstants.capHapticAudio), 0)
    }

    func testAnalogTriggersAreAlwaysClaimed() {
        XCTAssertEqual(descriptorCaps(.none, ForwardingFlags()), ProtocolConstants.capAnalogTriggers)
        XCTAssertEqual(
            descriptorCaps(.none, ForwardingFlags(motion: false, touchpad: false, rumble: false, lightbar: false)),
            ProtocolConstants.capAnalogTriggers
        )
    }

    func testASwitchedOffFeatureIsNotClaimed() {
        XCTAssertEqual(descriptorCaps(everything, ForwardingFlags(motion: false)) & ProtocolConstants.capMotion, 0)
        XCTAssertEqual(descriptorCaps(everything, ForwardingFlags(rumble: false)) & ProtocolConstants.capRumble, 0)
        XCTAssertEqual(descriptorCaps(everything, ForwardingFlags(lightbar: false)) & ProtocolConstants.capLightbar, 0)
    }

    func testMissingHardwareIsNeverClaimedWhateverTheSwitches() {
        let padWithoutImu = ControllerCapabilities(hasRumble: true, hasLightbar: true)
        XCTAssertEqual(descriptorCaps(padWithoutImu, ForwardingFlags()) & ProtocolConstants.capMotion, 0)
        XCTAssertEqual(descriptorCaps(padWithoutImu, ForwardingFlags()) & ProtocolConstants.capTriggerEffects, 0)
        XCTAssertEqual(descriptorCaps(padWithoutImu, ForwardingFlags()) & ProtocolConstants.capPlayerLeds, 0)
    }

    func testTheExtendedButtonsClaimFollowsThePadAloneWithNoSwitch() {
        let everySwitchOff = ForwardingFlags(
            motion: false, touchpad: false, rumble: false, lightbar: false, triggerEffects: false, playerLeds: false
        )
        let elite = ControllerCapabilities(hasExtendedButtons: true)
        XCTAssertNotEqual(descriptorCaps(elite, everySwitchOff) & ProtocolConstants.capExtendedButtons, 0)
        XCTAssertEqual(descriptorCaps(everything, ForwardingFlags()) & ProtocolConstants.capExtendedButtons, 0, "no paddles, no claim")
    }

    /// The adaptive triggers and the player LEDs have switches of their own
    /// here, so a cap is the hardware and its switch, as for the others.
    func testTheFeedbackCapsFollowTheHardwareAndTheirOwnSwitches() {
        let dualSense = ControllerCapabilities(hasTriggerEffects: true, hasPlayerLeds: true)
        let word = descriptorCaps(dualSense, ForwardingFlags(motion: false, touchpad: false, rumble: false, lightbar: false))
        XCTAssertNotEqual(word & ProtocolConstants.capTriggerEffects, 0)
        XCTAssertNotEqual(word & ProtocolConstants.capPlayerLeds, 0)
        let off = descriptorCaps(dualSense, ForwardingFlags(triggerEffects: false, playerLeds: false))
        XCTAssertEqual(off & (ProtocolConstants.capTriggerEffects | ProtocolConstants.capPlayerLeds), 0)
    }

    func testTheTouchpadModeIsThePadRenderOnlyWhenPresentAndOn() {
        let withPad = ControllerCapabilities(hasTouchpad: true)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags()), .ds4)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(touchpad: false)), .off)
        XCTAssertEqual(descriptorTouchpadMode(.none, ForwardingFlags()), .off)
    }

    // MARK: - The type a pad is emulated as

    private func catalog() throws -> CatalogDTO {
        try JSONDecoder().decode(CatalogDTO.self, from: Data(FakeSatelliteRest.catalogJSON.utf8))
    }

    /// The pad render needs a type that offers it; a pad's own touchpad is
    /// never the host's mouse on its own, whatever the host grants, so no
    /// session asks for the mouse while no mouse screen is open.
    func testAPadsOwnTouchpadIsThePadRenderOrOff() {
        let withPad = ControllerCapabilities(hasTouchpad: true)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(), typeOffersDs4: true), .ds4)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(), typeOffersDs4: false), .off, "no ds4 render")
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(), typeOffersDs4: false, hostMouseControl: true), .off)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(), typeOffersDs4: true, hostMouseControl: true), .ds4)
        XCTAssertEqual(descriptorTouchpadMode(withPad, ForwardingFlags(touchpad: false), hostMouseControl: true), .off, "switched off")
    }

    /// A screen the phone lends a slot comes first: the mouse needs the
    /// host's grant, the touchpad a type with one, and a pad with no
    /// touchpad of its own carries either.
    func testAScreenThePhoneLendsASlotDeclaresItself() {
        let mouse = ForwardingFlags(phoneSurface: .mouse)
        let touchpad = ForwardingFlags(phoneSurface: .touchpad)
        XCTAssertEqual(descriptorTouchpadMode(.none, mouse, hostMouseControl: true), .mouse)
        XCTAssertEqual(descriptorTouchpadMode(.none, mouse, hostMouseControl: false), .off, "the host grants no mouse")
        XCTAssertEqual(descriptorTouchpadMode(.none, touchpad, typeOffersDs4: true), .ds4)
        XCTAssertEqual(descriptorTouchpadMode(.none, touchpad, typeOffersDs4: false), .off, "the type renders no touchpad")
        let own = ControllerCapabilities(hasTouchpad: true)
        XCTAssertEqual(
            descriptorTouchpadMode(own, ForwardingFlags(touchpad: false, phoneSurface: .mouse), hostMouseControl: true),
            .mouse,
            "the lent screen passes the pad's own switch"
        )
    }

    func testTheCatalogsWordOnTheTypesTouchpad() throws {
        XCTAssertTrue(typeOffersDs4Touchpad(in: nil, type: 2), "no catalog refuses nothing")
        let catalog = try JSONDecoder().decode(CatalogDTO.self, from: Data(FakeSatelliteRest.catalogJSON.utf8))
        XCTAssertTrue(typeOffersDs4Touchpad(in: catalog, type: 1), "the DualShock 4 type offers the pad render")
        XCTAssertFalse(typeOffersDs4Touchpad(in: catalog, type: 0), "the Xbox type has no touchpad")
        XCTAssertTrue(typeOffersDs4Touchpad(in: catalog, type: 9), "a type the catalog does not name refuses nothing")
    }

    func testEachFamilyIsEmulatedAsItself() throws {
        let types = try catalog()
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSense), 2)
        XCTAssertEqual(preferredControllerType(in: types, for: .dualShock4), 1)
        XCTAssertEqual(preferredControllerType(in: types, for: .xboxWireless), 0)
    }

    func testAPickTheCatalogDoesNotEmulateTakesTheFirstOfferedType() throws {
        var types = try catalog()
        XCTAssertEqual(preferredControllerType(in: types, for: .switchPro), 3)
        types.controllerTypes.removeAll { $0.emulates?.sdlType == "switchpro" }
        XCTAssertEqual(preferredControllerType(in: types, for: .switchPro), 0)
    }

    func testAFamilyTheCatalogDoesNotEmulateFallsBackInOrder() throws {
        var types = try catalog()
        types.controllerTypes.removeAll { $0.emulates?.sdlType == "ps5" }
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSense), 1, "a DualSense settles for the DualShock 4 type")
        types.controllerTypes.removeAll { $0.emulates?.sdlType == "ps4" }
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSense), 0, "then for whatever is first")
    }

    func testALegacyCatalogWithoutEmulatesTakesTheFirstType() throws {
        var types = try catalog()
        for index in types.controllerTypes.indices {
            types.controllerTypes[index].emulates = nil
        }
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSense), 0)
    }

    func testTheDualSenseEdgeIsItsOwnTypeWhereOfferedAndTheDualSensesWhereNot() throws {
        var types = try catalog()
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSenseEdge), Int(ProtocolConstants.controllerTypeDualSenseEdge))
        types.controllerTypes.removeAll { $0.id == Int(ProtocolConstants.controllerTypeDualSenseEdge) }
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSenseEdge), 2, "a satellite before protocol 4 has the DualSense")
        types.controllerTypes.removeAll { $0.emulates?.sdlType == "ps5" }
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSenseEdge), 1, "then the DualShock 4")
    }

    /// The Edge is a `ps5` pad too, listed after the DualSense, so a
    /// DualSense lands on the DualSense and no family lands on the Edge.
    func testNoFamilyIsEmulatedAsTheDualSenseEdge() throws {
        let types = try catalog()
        XCTAssertEqual(preferredControllerType(in: types, for: .dualSense), 2)
        for family in [PadFamily.dualSense, .dualShock4, .xbox, .nintendo, .other] {
            let type = preferredControllerType(in: types, for: family.emulatedPad)
            XCTAssertNotEqual(type, Int(ProtocolConstants.controllerTypeDualSenseEdge), "\(family) is never the Edge unasked")
        }
    }

    func testNoCatalogMeansTheLegacyXboxTarget() {
        XCTAssertEqual(preferredControllerType(in: nil, for: .dualSense), Int(ProtocolConstants.controllerTypeXbox))
        XCTAssertEqual(preferredControllerType(in: CatalogDTO(), for: .xboxWireless), Int(ProtocolConstants.controllerTypeXbox))
    }
}
