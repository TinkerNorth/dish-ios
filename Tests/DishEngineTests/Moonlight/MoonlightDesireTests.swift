// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore
@testable import DishEngine

/// What the bindings ask of every host, and how a host reads as a row.
final class MoonlightDesireTests: XCTestCase {

    private let dualSense = ControllerCapabilities(
        hasMotion: true,
        hasTouchpad: true,
        hasRumble: true,
        hasLightbar: true,
        hasBattery: true,
        hasTriggerEffects: true,
        hasPlayerLeds: true
    )
    private let hostId = "moonlight:10.0.0.5"

    private func slot(_ id: String, _ capabilities: ControllerCapabilities) -> ControllerSlot {
        ControllerSlot(id: id, name: id, capabilities: capabilities, family: .dualSense)
    }

    func testTheRequestResolvesThePickAgainstThePadAndFoldsTheSwitchesTheHostReads() {
        let auto = MoonlightDesire.request(
            slotId: "ds",
            capabilities: dualSense,
            storedType: Int(MoonlightControllerType.auto),
            flags: ForwardingFlags()
        )
        XCTAssertEqual(auto.slotId, "ds")
        XCTAssertEqual(auto.announced.type, MoonlightControllerType.playStation, "Auto with motion is a PlayStation pad")
        XCTAssertEqual(auto.announced.capabilities, 0xFF)
        XCTAssertEqual(auto.announced.supportedButtons, 0x10F7FF)
        let motionOff = MoonlightDesire.request(
            slotId: "ds",
            capabilities: dualSense,
            storedType: Int(MoonlightControllerType.auto),
            flags: ForwardingFlags(motion: false)
        )
        XCTAssertEqual(motionOff.announced.type, MoonlightControllerType.xbox, "the motion switch folds in before Auto resolves")
        XCTAssertEqual(motionOff.announced.capabilities & (MoonlightCapability.gyro | MoonlightCapability.accelerometer), 0)
        let touchesKept = MoonlightDesire.request(
            slotId: "ds",
            capabilities: dualSense,
            storedType: Int(MoonlightControllerType.playStation),
            flags: ForwardingFlags(touchpad: false)
        )
        XCTAssertEqual(
            touchesKept.announced.capabilities & MoonlightCapability.touchpad,
            0,
            "no touchpad on a pad whose touches are kept back"
        )
        XCTAssertEqual(touchesKept.announced.supportedButtons, 0xF7FF)
        let plain = MoonlightDesire.request(
            slotId: "xb",
            capabilities: ControllerCapabilities(hasRumble: true),
            storedType: 0,
            flags: ForwardingFlags()
        )
        XCTAssertEqual(plain.announced.type, MoonlightControllerType.xbox, "a stored 0 reads as Auto, and without motion Auto is Xbox")
        XCTAssertEqual(plain.announced.capabilities, MoonlightCapability.analogTriggers | MoonlightCapability.rumble)
    }

    func testTheProtocolsTypeForEachPadTheAppOffers() {
        XCTAssertEqual(MoonlightDesire.controllerType(.dualSense), MoonlightControllerType.playStation)
        XCTAssertEqual(MoonlightDesire.controllerType(.dualShock4), MoonlightControllerType.playStation)
        XCTAssertEqual(MoonlightDesire.controllerType(.xboxWireless), MoonlightControllerType.xbox)
        XCTAssertEqual(MoonlightDesire.controllerType(.switchPro), MoonlightControllerType.nintendo)
        XCTAssertEqual(MoonlightDesire.controllerType(.dualSenseEdge), MoonlightControllerType.playStation, "the protocol has no Edge")
    }

    func testTheDesireNamesOnlyMoonlightBindingsWhosePadIsPresent() {
        let desired = MoonlightDesire.desiredPads(
            bindings: ["ds": hostId, "xb": "mid:sat", "gone": hostId, "nin": "moonlight:10.0.0.9"],
            hostIds: [hostId],
            slots: [slot("ds", dualSense), slot("xb", ControllerCapabilities()), slot("nin", ControllerCapabilities())],
            bindingTypes: ["ds": Int(MoonlightControllerType.nintendo)],
            hostTypes: { _ in Int(MoonlightControllerType.playStation) },
            preferences: ["ds": SlotPreferences(rumble: false)],
            global: ForwardingFlags()
        )
        XCTAssertEqual(desired.keys.sorted(), [hostId], "a satellite binding, an absent pad and an unknown host ask nothing")
        XCTAssertEqual(desired[hostId]?.map(\.slotId), ["ds"])
        XCTAssertEqual(
            desired[hostId]?.first?.announced.type,
            MoonlightControllerType.nintendo,
            "the type the pad's binding holds beats the host's own"
        )
        XCTAssertEqual(desired[hostId]?.first?.announced.capabilities, 0x47, "Nintendo sits on the Xbox ceiling; rumble is a hardware fact")
        let hostPick = MoonlightDesire.desiredPads(
            bindings: ["ds": hostId],
            hostIds: [hostId],
            slots: [slot("ds", dualSense)],
            bindingTypes: [:],
            hostTypes: { _ in Int(MoonlightControllerType.playStation) },
            preferences: [:],
            global: ForwardingFlags()
        )
        XCTAssertEqual(hostPick[hostId]?.first?.announced.type, MoonlightControllerType.playStation)
        let motionOff = MoonlightDesire.desiredPads(
            bindings: ["ds": hostId],
            hostIds: [hostId],
            slots: [slot("ds", dualSense)],
            bindingTypes: [:],
            hostTypes: { _ in Int(MoonlightControllerType.auto) },
            preferences: ["ds": SlotPreferences(motion: false)],
            global: ForwardingFlags()
        )
        XCTAssertEqual(
            motionOff[hostId]?.first?.announced.type,
            MoonlightControllerType.xbox,
            "the slot's own switch, under the global one"
        )
    }

    func testTheRowsChipFollowsThePhaseThenTheTrust() {
        XCTAssertEqual(MoonlightDesire.linkState(phase: .streaming, paired: true, verified: false, discovered: false), .connected)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .launching, paired: true, verified: false, discovered: false), .connecting)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .rtsp(.play), paired: true, verified: false, discovered: false), .connecting)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .failed(.dropped), paired: true, verified: true, discovered: true), .unstable)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .failed(.trustLost), paired: true, verified: true, discovered: true), .stale)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .failed(.hostReplaced), paired: true, verified: false, discovered: true), .stale)
        XCTAssertEqual(
            MoonlightDesire.linkState(phase: .idle, paired: false, verified: false, discovered: true),
            .stale,
            "no pairing: Needs pairing"
        )
        XCTAssertEqual(MoonlightDesire.linkState(phase: .idle, paired: true, verified: false, discovered: true), .ready)
        XCTAssertEqual(
            MoonlightDesire.linkState(phase: .idle, paired: true, verified: true, discovered: false),
            .ready,
            "proved this process"
        )
        XCTAssertEqual(MoonlightDesire.linkState(phase: .idle, paired: true, verified: false, discovered: false), .saved)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .failed(.unreachable), paired: true, verified: false, discovered: false), .saved)
        XCTAssertEqual(MoonlightDesire.linkState(phase: .failed(.launchRejected), paired: true, verified: true, discovered: true), .ready)
    }

    func testTheSummaryCarriesTheHostsNameAddressAndEveryBoundSlot() {
        let summary = MoonlightDesire.summary(
            host: MoonlightHost(name: "", address: "10.0.0.5"),
            phase: .streaming,
            roundTripMs: 9,
            paired: true,
            verified: true,
            discovered: true,
            boundSlotIds: ["a", "b"]
        )
        XCTAssertEqual(summary.id, "moonlight:10.0.0.5")
        XCTAssertEqual(summary.name, "", "the engine vends the name as advertised, empty or not")
        XCTAssertEqual(summary.address, "10.0.0.5")
        XCTAssertNil(summary.udpPort, "a Moonlight host has no satellite port")
        XCTAssertEqual(summary.recordName, "10.0.0.5", "the log names a host with no name by its address")
        XCTAssertEqual(summary.live, .connected)
        XCTAssertEqual(summary.kind, .moonlight)
        XCTAssertEqual(summary.boundSlotIds, ["a", "b"])
        XCTAssertEqual(summary.latencyMs, 4.5, "half the control link's round trip, as the satellite's figure is one way")
        XCTAssertTrue(summary.hasRoomForAnotherSlot)
        let full = MoonlightDesire.summary(
            host: MoonlightHost(name: "PC", address: "10.0.0.5"),
            phase: .idle,
            roundTripMs: nil,
            paired: true,
            verified: false,
            discovered: false,
            boundSlotIds: ["a", "b", "c", "d"]
        )
        XCTAssertFalse(full.hasRoomForAnotherSlot)
        XCTAssertNil(full.latencyMs)
        let satellite = ConnectionSummary(id: "mid:1", name: "Desk", live: .ready, boundSlotIds: ["a"])
        XCTAssertEqual(satellite.kind, .satellite)
        XCTAssertTrue(satellite.hasRoomForAnotherSlot, "a satellite carries four pads")
    }
}
