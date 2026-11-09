// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The seam to the pads attached to this iPhone: the slots it lists, the
/// processor that owns each pad's feed, and the queue that drives the pads'
/// actuators. `GameControllerInput` is the production source; a test that
/// cannot build a `GCController` hands the model a source of its own.
@MainActor
package protocol ControllerSource: AnyObject {
    var slots: [ControllerSlot] { get }
    var processor: GamepadInputProcessor { get }
    var feedback: PadFeedback { get }
}
