// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import UIKit

/// Sees every touch in a window and recognizes none, so nothing under it
/// is delayed or cancelled.
final class TouchWatcher: UIGestureRecognizer {
    var onTouch: @MainActor () -> Void = {}

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        onTouch()
        state = .failed
    }
}

/// The brightness the dim leaves while it is up.
let dimmedBrightness: CGFloat = 0.01

/// What the dim does to the screen's brightness: `set` it, if at all, and
/// `keep` what to give back.
struct BrightnessMove: Equatable {
    let set: CGFloat?
    let keep: CGFloat?
}

/// Dimming keeps the brightness found and sets the floor, once; waking sets
/// what was kept, once; anything else moves nothing.
func brightnessMove(dimmed: Bool, kept: CGFloat?, current: CGFloat) -> BrightnessMove {
    switch (dimmed, kept) {
    case (true, nil): BrightnessMove(set: dimmedBrightness, keep: current)
    case let (false, before?): BrightnessMove(set: before, keep: nil)
    case (true, .some): BrightnessMove(set: nil, keep: kept)
    case (false, nil): BrightnessMove(set: nil, keep: nil)
    }
}

/// Applies the brightness move to the screen and keeps what it is told to.
@MainActor
final class ScreenDimmer {
    private var kept: CGFloat?

    func apply(_ dimmed: Bool, to screen: UIScreen) {
        let move = brightnessMove(dimmed: dimmed, kept: kept, current: screen.brightness)
        kept = move.keep
        if let brightness = move.set {
            screen.brightness = brightness
        }
    }
}
