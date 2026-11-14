// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controllers' facts and intents: the pads' slots become the
/// Controllers tab's rows and setup's attached pads; the controller page
/// flips a pad's switches, picks what it is emulated as and what a Steam
/// Controller's trackpads are; the dead zones reach each pad's feed as they
/// change; Settings flips the global switches and the Steam Controllers.
package extension AppModel {

    /// Every pad iOS lists, readable or not, with its switches, its pick and
    /// the PC it is bound to, then the on-screen controller once it is listed.
    internal var controllerFacts: [ControllerFact] {
        pads.slots.map(controllerFact) + onScreenFact
    }

    /// The pads setup can offer: the ones Dish can read.
    internal var attachedPadFacts: [AttachedPadFact] {
        pads.slots.filter(\.readable).map { slot in
            AttachedPadFact(
                id: slot.id,
                name: slot.name,
                family: slot.family.emulatedPad,
                link: slot.link,
                batteryPercent: slot.battery?.level
            )
        }
    }

    /// The switches in force for a pad: the global ones and its own.
    func forwardingFlags(slotId: String) -> ForwardingFlags {
        effectiveFlags(global: pads.features.flags, slot: slotPreferencesInForce(slotId))
    }

    /// A pad's own switches; a Steam Controller's touchpad is on while its
    /// trackpad pick puts anything on the surface.
    private func slotPreferencesInForce(_ slotId: String) -> SlotPreferences {
        let stored = pads.switches.preferences(for: slotId)
        guard let pick = trackpadPick(slotId: slotId) else { return stored }
        return stored.with(.touchpad, pick.carriesSurface)
    }

    /// A Steam Controller's pick in force: the one chosen where its model
    /// offers it, else its model's default, held to the touchpad of the pad
    /// it is emulated as. Nil for every other pad.
    internal func trackpadPick(slotId: String) -> TouchpadPick? {
        guard let slot = pads.slots.first(where: { $0.id == slotId }), slot.trackpads != .none else { return nil }
        let emulated = pads.types.typeFor(slotId) ?? slot.family.emulatedPad
        return effectiveTrackpadPick(
            stored: pads.trackpads.pick(for: slotId),
            trackpads: slot.trackpads,
            typeOffersDs4: emulated.hasTouchpad
        )
    }

    /// A Steam Controller's trackpads from now on: its route, its
    /// descriptor and its link's router follow.
    func setTrackpadPick(slotId: String, _ pick: TouchpadPick) {
        pads.trackpads.setPick(pick, for: slotId)
        refreshRouting()
    }

    /// On makes the radio, which asks iOS for Bluetooth the first time; off
    /// gives every Steam Controller back.
    func setSteamControllersOverBluetooth(_ on: Bool) {
        pads.steamSetting.setEnabled(on)
        switch on {
        case true: pads.steam.start()
        case false: pads.steam.stop()
        }
    }

    /// The person opted in before this launch.
    internal func resumeSteamControllers() {
        guard pads.steamSetting.enabled else { return }
        pads.steam.start()
    }

    /// Each Steam Controller's link routes its trackpads by the pick in force.
    internal func pushTrackpadPicks() {
        for slot in pads.steam.slots {
            guard let pick = trackpadPick(slotId: slot.id) else { continue }
            pads.steam.useTrackpadPick(pick, slotId: slot.id)
        }
    }

    /// A switch moves the pad's route and, while bound, its descriptor.
    func setControllerFeature(slotId: String, _ feature: SlotSwitch, enabled: Bool) {
        pads.switches.set(feature, enabled, for: slotId)
        refreshRouting()
    }

    /// The family's own pick is no pick: the stored entry goes, so a pad
    /// follows its family again. A pad on a Moonlight host is re-announced
    /// by the converge the routing refresh asks for.
    func setEmulatedType(slotId: String, _ pad: EmulatedPad) {
        network.hub.setEmulatedType(slotId: slotId, pad)
        let family = pads.slots.first { $0.id == slotId }?.family.emulatedPad
        if pad == family {
            pads.types.clear(slotId)
        } else {
            pads.types.setType(pad, for: slotId)
        }
        refreshRouting()
    }

    /// A global switch moves every pad's route and, while bound, its descriptor.
    func setRumbleForwarded(_ on: Bool) {
        pads.features.setRumble(on)
        refreshRouting()
    }

    func setTouchpadForwarded(_ on: Bool) {
        pads.features.setTouchpad(on)
        refreshRouting()
    }

    func setMotionForwarded(_ on: Bool) {
        pads.features.setMotion(on)
        refreshRouting()
    }

    func setLightbarMode(_ mode: LightbarMode) {
        pads.features.setLightbarMode(mode)
        refreshRouting()
    }

    func setStickDeadzone(percent: Int, slotId: String) {
        let current = pads.deadzones.zones(for: slotId)
        pads.deadzones.setZones(current.withStickPercent(percent), for: slotId)
        applyDeadzones(slotId: slotId)
    }

    func setTriggerDeadzone(percent: Int, slotId: String) {
        let current = pads.deadzones.zones(for: slotId)
        pads.deadzones.setZones(current.withTriggerPercent(percent), for: slotId)
        applyDeadzones(slotId: slotId)
    }

    /// The pad's tuning is forgotten; the defaults apply again.
    func resetDeadzones(slotId: String) {
        pads.deadzones.reset(slotId)
        applyDeadzones(slotId: slotId)
    }

    /// Every stored tuning reaches the processor before any pad's first
    /// report; a pad never tuned reads the defaults from its feed's start.
    internal func applyStoredDeadzones() {
        for slotId in pads.deadzones.state.keys {
            applyDeadzones(slotId: slotId)
        }
    }

    private func applyDeadzones(slotId: String) {
        pads.source.processor.setDeadzones(deviceId: slotId, processorZones(pads.deadzones.zones(for: slotId)))
    }

    private func controllerFact(_ slot: ControllerSlot) -> ControllerFact {
        let switches = slotPreferencesInForce(slot.id)
        let carried = offeredSwitches(slot)
        return ControllerFact(
            id: slot.id,
            name: slot.name,
            link: controllerLink(slot.link),
            batteryPercent: slot.battery?.level,
            destination: destination(slotId: slot.id),
            family: slot.family,
            emulateAs: pads.types.typeFor(slot.id) ?? slot.family.emulatedPad,
            features: carried.map { ControllerFeatureFact(feature: $0, enabled: switches.isOn($0)) },
            supported: slot.readable,
            motion: motionFact(slotId: slot.id),
            hostEmulation: network.hub.hostEmulation(slotId: slot.id),
            trackpads: trackpadsFact(slot)
        )
    }

    /// The switches the pad has the hardware for; a Steam Controller's
    /// trackpads are its pick instead of the Touchpad switch.
    private func offeredSwitches(_ slot: ControllerSlot) -> [SlotSwitch] {
        let carried = SlotSwitch.allCases.filter { $0.isCarried(by: slot.capabilities) }
        guard slot.trackpads != .none else { return carried }
        return carried.filter { $0 != .touchpad }
    }

    private func trackpadsFact(_ slot: ControllerSlot) -> TrackpadsFact? {
        guard let pick = trackpadPick(slotId: slot.id) else { return nil }
        return TrackpadsFact(choices: trackpadPickChoices(slot.trackpads), pick: pick)
    }

    /// Whether the pad's PC carries motion now, and what its satellite said
    /// of it the last time it applied the pad.
    internal func motionFact(slotId: String) -> MotionFact {
        guard let connectionId = network.hub.bindings[slotId] else { return MotionFact(carries: false, status: nil) }
        let status = network.wifi.motionStatus.statusFor(SlotKey(connectionId: connectionId, slotId: slotId))
        return MotionFact(carries: sessionIsUp(network.hub.summary(connectionId)?.live), status: status)
    }
}

func controllerLink(_ link: PadLink) -> ControllerLink {
    switch link {
    case .usbC: .usbC
    case .bluetooth: .bluetooth
    }
}
