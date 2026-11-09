// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController

/// The motion and touchpad streams of `GameControllerInput`.
extension GameControllerInput {

    // MARK: - Motion

    /// Pads with `sensorsRequireManualActivation` stay silent until the
    /// sensors are switched on; pads that manage their own need no opt-in.
    /// Nonisolated like every handler install, since the closure runs on the
    /// input queue.
    nonisolated static func installMotionHandler(controller: GCController, feed: PadFeed) {
        guard let motion = controller.motion else { return }
        if motion.sensorsRequireManualActivation {
            motion.sensorsActive = true
        }
        motion.valueChangedHandler = { motion in
            pushMotion(motion: motion, feed: feed)
        }
    }

    /// A surface the pad lacks is sent as zeros rather than a stale reading;
    /// a pad with neither surface sends nothing.
    nonisolated static func pushMotion(motion: GCMotion, feed: PadFeed) {
        let haveGyro = motion.hasRotationRate
        let haveAccel = motion.hasGravityAndUserAcceleration
        guard haveGyro || haveAccel else { return }
        let rate = motion.rotationRate
        let gravity = motion.gravity
        let userAccel = motion.userAcceleration
        let sample = gcMotionToWire(
            rotationRateRad: haveGyro ? MotionAxes(x: rate.x, y: rate.y, z: rate.z) : .zero,
            gravity: haveAccel ? MotionAxes(x: gravity.x, y: gravity.y, z: gravity.z) : .zero,
            userAccel: haveAccel ? MotionAxes(x: userAccel.x, y: userAccel.y, z: userAccel.z) : .zero
        )
        feed.publishMotion(sample)
    }

    // MARK: - Touchpad

    /// GameController has no per-finger touch-down event, so each of the
    /// three inputs re-reads the whole touchpad, as the report path does.
    /// The three handlers share one closure made here, not per touch.
    nonisolated static func installTouchpadHandlers(pad: GCExtendedGamepad, feed: PadFeed) {
        guard let touchpad = touchpadInputs(pad) else { return }
        let rebuild: () -> Void = {
            pushTouchpad(touchpad: touchpad, feed: feed)
        }
        touchpad.primary.valueChangedHandler = { _, _, _ in rebuild() }
        touchpad.secondary.valueChangedHandler = { _, _, _ in rebuild() }
        touchpad.button.valueChangedHandler = { _, _, _ in rebuild() }
    }

    /// A finger is down when its pad reads non-zero, which is the only signal
    /// the framework exposes.
    nonisolated static func pushTouchpad(touchpad: TouchpadInputs, feed: PadFeed) {
        let primary = touchpad.primary
        let secondary = touchpad.secondary
        let finger0Active = primary.xAxis.value != 0 || primary.yAxis.value != 0
        let finger1Active = secondary.xAxis.value != 0 || secondary.yAxis.value != 0
        let position0 = gcTouchpadAxisToWire(x: primary.xAxis.value, y: primary.yAxis.value)
        let position1 = gcTouchpadAxisToWire(x: secondary.xAxis.value, y: secondary.yAxis.value)
        let ids = feed.advanceTouchIds(finger0Active: finger0Active, finger1Active: finger1Active)
        let sample = TouchpadSample(
            finger0: TouchpadFinger(active: finger0Active, id: ids.finger0, x: position0.x, y: position0.y),
            finger1: TouchpadFinger(active: finger1Active, id: ids.finger1, x: position1.x, y: position1.y),
            buttonPressed: touchpad.button.isPressed
        )
        feed.publishTouchpad(sample)
    }
}
