// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The play screens' facts and intents: a screen opens on the on-screen
/// controller, always one of the controllers, or lends the phone's touchpad
/// or mouse to the pad the phone was aimed at, and closes releasing what it
/// held. The touches go straight to the aimed slot's feed.
package extension AppModel {

    /// The screen on display, the slot it serves, and the on-screen
    /// controller's switches; nil while no screen is up.
    var playFacts: PlayFacts? {
        guard let screen = playSource.state else { return nil }
        let switches = pads.switches.preferences(for: onScreenSlotId)
        return PlayFacts(
            screen: screen,
            target: playTargetFact,
            destination: destination(slotId: playTarget),
            emulateAs: onScreenEmulateAs,
            rumble: switches.rumble,
            motion: switches.motion,
            motionAvailability: playMotion
        )
    }

    /// The on-screen controller as the Controllers tab lists it, screen or
    /// no screen; its name is the app's to word.
    internal var onScreenFact: [ControllerFact] {
        let switches = pads.switches.preferences(for: onScreenSlotId)
        let carried: [SlotSwitch] = onScreen.hasMotionSensor ? [.motion, .rumble] : [.rumble]
        return [ControllerFact(
            id: onScreenSlotId,
            name: "",
            link: .onScreen,
            batteryPercent: nil,
            destination: destination(slotId: onScreenSlotId),
            emulateAs: onScreenEmulateAs,
            features: carried.map { ControllerFeatureFact(feature: $0, enabled: switches.isOn($0)) },
            motion: motionFact(slotId: onScreenSlotId),
            hostEmulation: network.hub.hostEmulation(slotId: onScreenSlotId)
        )]
    }

    /// What the on-screen gamepad claims on a satellite: the phone's motion
    /// when it has the sensors, the touchpad screen, the Taptic Engine as
    /// its rumble, and the phone's battery.
    internal var onScreenCapabilities: ControllerCapabilities {
        ControllerCapabilities(hasMotion: onScreen.hasMotionSensor, hasTouchpad: true, hasRumble: true, hasBattery: true)
    }

    /// The screens the phone can lend a pad bound to a satellite.
    internal func phoneSurfaces(slotId: String, capabilities: ControllerCapabilities) -> [PlayScreen] {
        guard let connectionId = network.hub.bindings[slotId], let conn = network.wifi.get(connectionId) else { return [] }
        return lentScreens(
            padHasTouchpad: capabilities.hasTouchpad,
            sessionUp: sessionIsUp(network.hub.summary(connectionId)?.live),
            typeOffersDs4: conn.typeOffersDs4(for: slotId),
            hostMouseControl: conn.hostMouseControl
        )
    }

    /// The screen the phone lends the slot right now, for its descriptor.
    internal func phoneSurface(on slotId: String) -> PhoneSurface? {
        guard slotId == playTarget else { return nil }
        switch playSource.state {
        case .touchpad: return .touchpad
        case .mouse: return .mouse
        case .gamepad, nil: return nil
        }
    }

    /// Aim the phone's touchpad or mouse at a pad before its screen opens.
    func aimPlay(at slotId: String) {
        guard playSource.state == nil else { return }
        playTarget = slotId
    }

    func openPlay(_ screen: PlayScreen) {
        switch screen {
        case .gamepad: openGamepad()
        case .touchpad: openTouchpad()
        case .mouse: openMouse()
        }
    }

    func openGamepad() {
        show(.gamepad)
    }

    func openTouchpad() {
        show(.touchpad)
    }

    func openMouse() {
        show(.mouse)
    }

    /// The screen closed: what it held is released and the aim returns to
    /// the on-screen controller.
    func closePlay() {
        guard playSource.state != nil else { return }
        onScreen.stop()
        playSource.setState(nil)
        playTarget = onScreenSlotId
        pushSlotFlags()
    }

    func setPlayRumble(_ on: Bool) {
        setControllerFeature(slotId: onScreenSlotId, .rumble, enabled: on)
    }

    func setPlayMotion(_ on: Bool) {
        setControllerFeature(slotId: onScreenSlotId, .motion, enabled: on)
        syncPlayMotion()
    }

    func setPlayEmulateAs(_ pad: EmulatedPad) {
        pads.types.setType(pad, for: onScreenSlotId)
        onScreen.useAnalogTriggers(hasAnalogTriggers(pad))
        syncPlayMotion()
    }

    /// Stop gamepad: the screen closes and the binding stays.
    func stopOnScreenGamepad() {
        closePlay()
    }

    func onScreenPad(_ event: OnScreenPadEvent) {
        onScreen.apply(event)
    }

    func onScreenTouch(_ event: TouchSurfaceEvent) {
        onScreen.touch(event)
    }

    /// Setup bound the on-screen controller: it takes the emulation and the
    /// Motion switch the walk picked.
    internal func adoptOnScreen(_ draft: SetupDraft) {
        guard draft.input == .onScreen else { return }
        pads.types.setType(draft.emulateAs, for: onScreenSlotId)
        setControllerFeature(slotId: onScreenSlotId, .motion, enabled: draft.motion)
    }

    /// The slot the phone's touches serve, as the play screens word it.
    private var playTargetFact: PlayTarget {
        guard playTarget != onScreenSlotId else { return .onScreen }
        let name = pads.slots.first { $0.id == playTarget }?.name ?? playTarget
        return .pad(id: playTarget, name: name)
    }

    private var onScreenEmulateAs: EmulatedPad {
        pads.types.typeFor(onScreenSlotId) ?? InputKind.onScreen.defaultEmulation
    }

    private var playMotion: PlayMotion {
        guard onScreenEmulateAs.hasMotion else { return .padHasNone }
        guard onScreen.hasMotionSensor else { return .phoneHasNone }
        return .available
    }

    /// A screen opens on the on-screen controller, or on the pad the phone
    /// is aimed at; a screen it replaces releases what it held first.
    private func show(_ screen: PlayScreen) {
        let previous = playSource.state
        guard previous != screen else { return }
        if previous != nil { onScreen.stop() }
        if screen == .gamepad { playTarget = onScreenSlotId }
        onScreen.aimTouch(at: pads.source.processor.feed(for: playTarget))
        onScreen.useAnalogTriggers(hasAnalogTriggers(onScreenEmulateAs))
        playSource.setState(screen)
        onScreen.start()
        syncPlayMotion()
        pushSlotFlags()
    }

    /// The phone's motion runs while the gamepad is on screen, its Motion
    /// switch is on, and the emulated pad and the phone both carry motion.
    private func syncPlayMotion() {
        let onGamepad = playSource.state == .gamepad
        let switchedOn = forwardingFlags(slotId: onScreenSlotId).motion
        let available = playMotion == .available
        onScreen.motion(onGamepad && switchedOn && available)
    }
}
