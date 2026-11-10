// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The play screens' facts and intents: the on-screen controller is a slot
/// of its own, listed among the controllers once opened or bound; a play
/// screen opens on it and closes releasing everything it held; the pause
/// menu flips its Rumble and Motion and picks what it is emulated as; Stop
/// gamepad takes it off the list. The touches go straight to its feed.
package extension AppModel {

    /// The screen on display and the on-screen controller's switches.
    internal var playFacts: PlayFacts? {
        guard let screen = playSource.state else { return nil }
        let switches = pads.switches.preferences(for: onScreenSlotId)
        return PlayFacts(
            screen: screen,
            emulateAs: onScreenEmulateAs,
            rumble: switches.rumble,
            motion: switches.motion,
            motionAvailability: playMotion
        )
    }

    /// The on-screen controller as the Controllers tab lists it; its name is
    /// the app's to word.
    internal var onScreenFact: [ControllerFact] {
        guard onScreenListed.state else { return [] }
        let switches = pads.switches.preferences(for: onScreenSlotId)
        let carried: [SlotSwitch] = onScreen.hasMotionSensor ? [.motion, .rumble] : [.rumble]
        return [ControllerFact(
            id: onScreenSlotId,
            name: "",
            link: .onScreen,
            batteryPercent: nil,
            destination: destination(slotId: onScreenSlotId),
            emulateAs: onScreenEmulateAs,
            features: carried.map { ControllerFeatureFact(feature: $0, enabled: switches.isOn($0)) }
        )]
    }

    /// What the on-screen gamepad claims on a satellite: the phone's motion
    /// when it has the sensors, the touchpad screen, and the Taptic Engine
    /// as its rumble.
    internal var onScreenCapabilities: ControllerCapabilities {
        ControllerCapabilities(hasMotion: onScreen.hasMotionSensor, hasTouchpad: true, hasRumble: true)
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

    /// The screen closed: everything it held is released, and the loop heals
    /// that release before it stops.
    func closePlay() {
        guard playSource.state != nil else { return }
        onScreen.stop()
        playSource.setState(nil)
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

    /// Stop gamepad: the screen closes, the on-screen controller lets its
    /// PC go and leaves the controllers, so nothing routes it any more.
    func stopOnScreenGamepad() {
        closePlay()
        onScreenListed.setState(false)
        unbind(slotId: onScreenSlotId)
    }

    func onScreenPad(_ event: OnScreenPadEvent) {
        onScreen.apply(event)
    }

    func onScreenTouch(_ event: TouchSurfaceEvent) {
        onScreen.touch(event)
    }

    /// Setup bound the on-screen controller: it joins the controllers with
    /// the emulation and the Motion switch the walk picked.
    internal func adoptOnScreen(_ draft: SetupDraft) {
        guard draft.input == .onScreen else { return }
        onScreenListed.setState(true)
        pads.types.setType(draft.emulateAs, for: onScreenSlotId)
        setControllerFeature(slotId: onScreenSlotId, .motion, enabled: draft.motion)
    }

    private var onScreenEmulateAs: EmulatedPad {
        pads.types.typeFor(onScreenSlotId) ?? InputKind.onScreen.defaultEmulation
    }

    private var playMotion: PlayMotion {
        guard onScreenEmulateAs.hasMotion else { return .padHasNone }
        guard onScreen.hasMotionSensor else { return .phoneHasNone }
        return .available
    }

    /// A screen opens on the on-screen controller; moving from another
    /// screen releases what that one held first.
    private func show(_ screen: PlayScreen) {
        let previous = playSource.state
        guard previous != screen else { return }
        if previous != nil { onScreen.stop() }
        onScreenListed.setState(true)
        onScreen.useAnalogTriggers(hasAnalogTriggers(onScreenEmulateAs))
        playSource.setState(screen)
        onScreen.start()
        syncPlayMotion()
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
