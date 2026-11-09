// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The on-screen controller's slot id: the session binds and routes it by
/// this id, as it does a pad iOS sees.
package let onScreenSlotId = "on-screen"

/// Whether the emulated pad's triggers are analog: a Switch Pro's are not,
/// so a rail is a full press there.
package func hasAnalogTriggers(_ pad: EmulatedPad) -> Bool {
    switch pad {
    case .dualSense, .dualShock4, .xboxWireless: true
    case .switchPro: false
    }
}

/// The on-screen controller: the gamepad's, the touchpad's and the mouse's
/// touches through their reducers and out through the slot's own feed.
/// Touches arrive on the main actor, and the resend loop and the phone's
/// motion run there too, so the main thread is the feed's one publishing
/// thread. Input is event-driven; the loop only heals a lost edge (Android's
/// pacing: three ticks 50 ms apart, then a keepalive a second). Nothing on
/// the way allocates or takes a lock.
@MainActor
package final class OnScreenPad {
    private let feed: PadFeed
    private let ticker: any Ticker
    private let sensor: any MotionSensor
    private let now: @MainActor () -> UInt64

    private var pad = OnScreenPadState()
    private var surface = TouchSurfaceState()
    private var padPacer = ResendPacer()
    private var touchPacer = ResendPacer()
    /// What each stream last let through the resend loop; nil until the
    /// stream has sent anything, so a screen never resends what it never sent.
    private var resentReport: GamepadReport?
    private var resentTouch: TouchpadSample?
    private var running = false
    /// Ticks left to heal the release once the screen closed.
    private var drainTicks = 0
    private var side = LandscapeSide.topLeft
    package private(set) var motionRunning = false

    package init(feed: PadFeed, ticker: any Ticker, sensor: any MotionSensor, now: @escaping @MainActor () -> UInt64 = uptimeNs) {
        self.feed = feed
        self.ticker = ticker
        self.sensor = sensor
        self.now = now
    }

    /// Whether this iPhone has the motion sensors the Motion switch needs.
    package var hasMotionSensor: Bool {
        sensor.isAvailable
    }

    // MARK: - The screen

    /// A play screen opened: the resend loop runs.
    package func start() {
        guard !running else { return }
        running = true
        drainTicks = 0
        ticker.start(every: Double(ResendPacer.tickIntervalNs) / 1_000_000_000, tick)
    }

    /// The screen closed: everything held is released, motion stops, and
    /// the loop runs one more burst so a lost release still heals.
    package func stop() {
        guard running else { return }
        running = false
        motion(false)
        releaseEverything()
        drainTicks = ResendPacer.edgeBurstResends
    }

    package func apply(_ event: OnScreenPadEvent) {
        pad = reduceOnScreenPad(pad, event)
        if resentReport == nil { resentReport = .released }
        feed.publishIfChanged(pad.report)
    }

    package func touch(_ event: TouchSurfaceEvent) {
        let step = reduceTouchSurface(surface, event)
        surface = step.state
        if resentTouch == nil { resentTouch = .idle }
        feed.publishTouchpad(step.sample)
    }

    package func useAnalogTriggers(_ analog: Bool) {
        pad.analogTriggers = analog
    }

    /// The phone's motion streams through the feed, or stops.
    package func motion(_ on: Bool) {
        guard on != motionRunning else { return }
        motionRunning = on
        switch on {
        case true: sensor.start(read)
        case false: sensor.stop()
        }
    }

    // MARK: - The loop

    private func releaseEverything() {
        if resentReport != nil { apply(.releaseAll) }
        if resentTouch != nil { touch(.releaseAll) }
    }

    private func tick() {
        let nowNs = now()
        resendPad(nowNs: nowNs)
        resendTouch(nowNs: nowNs)
        guard !running else { return }
        drainTicks -= 1
        guard drainTicks <= 0 else { return }
        ticker.stop()
        resentReport = nil
        resentTouch = nil
    }

    private func resendPad(nowNs: UInt64) {
        guard let last = resentReport else { return }
        let current = pad.report
        resentReport = current
        guard padPacer.resendDue(changed: current != last, nowNs: nowNs) else { return }
        feed.publish(current)
    }

    /// A resend repeats the touch state; a wheel event is never repeated.
    private func resendTouch(nowNs: UInt64) {
        guard let last = resentTouch else { return }
        let current = surface.sample()
        resentTouch = current
        guard touchPacer.resendDue(changed: current != last, nowNs: nowNs) else { return }
        feed.publishTouchpad(current)
    }

    private func read(_ reading: DeviceMotionReading) {
        side = landscapeSide(previous: side, gravityX: reading.gravity.x)
        feed.publishMotion(phoneMotionToWire(reading, side: side))
    }
}
