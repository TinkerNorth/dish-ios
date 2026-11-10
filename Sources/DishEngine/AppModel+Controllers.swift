// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The controllers' facts and intents: the bridge's slots become the
/// Controllers tab's rows and setup's attached pads; the controller page
/// flips a pad's switches and picks what it is emulated as; the dead zones
/// reach each pad's feed as they change.
package extension AppModel {

    /// Every pad iOS lists, readable or not, with its switches, its pick and
    /// the PC it is bound to, then the on-screen controller once it is listed.
    internal var controllerFacts: [ControllerFact] {
        pads.source.slots.map(controllerFact) + onScreenFact
    }

    /// The pads setup can offer: the ones Dish can read.
    internal var attachedPadFacts: [AttachedPadFact] {
        pads.source.slots.filter(\.readable).map { slot in
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
        effectiveFlags(global: pads.features.flags, slot: pads.switches.preferences(for: slotId))
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
        let family = pads.source.slots.first { $0.id == slotId }?.family.emulatedPad
        if pad == family {
            pads.types.clear(slotId)
        } else {
            pads.types.setType(pad, for: slotId)
        }
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
        let switches = pads.switches.preferences(for: slot.id)
        let carried = SlotSwitch.allCases.filter { $0.isCarried(by: slot.capabilities) }
        return ControllerFact(
            id: slot.id,
            name: slot.name,
            link: controllerLink(slot.link),
            batteryPercent: slot.battery?.level,
            destination: destination(slotId: slot.id),
            family: slot.family,
            emulateAs: pads.types.typeFor(slot.id) ?? slot.family.emulatedPad,
            features: carried.map { ControllerFeatureFact(feature: $0, enabled: switches.isOn($0)) },
            supported: slot.readable
        )
    }
}

func controllerLink(_ link: PadLink) -> ControllerLink {
    switch link {
    case .usbC: .usbC
    case .bluetooth: .bluetooth
    }
}
