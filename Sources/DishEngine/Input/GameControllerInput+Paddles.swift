// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation
import GameController

/// The back paddles of `GameControllerInput`: an Xbox Elite's four, read
/// with the pad's report into the extended-buttons word.
extension GameControllerInput {

    /// An Xbox Elite's paddles, by the labels on the pad.
    struct PaddleInputs {
        let one: GCControllerButtonInput
        let two: GCControllerButtonInput
        let three: GCControllerButtonInput
        let four: GCControllerButtonInput
    }

    /// GameController names paddles on its Xbox profile alone, and leaves
    /// them nil on a pad that has none.
    nonisolated static func paddleInputs(_ pad: GCExtendedGamepad) -> PaddleInputs? {
        guard let xbox = pad as? GCXboxGamepad,
              let one = xbox.paddleButton1,
              let two = xbox.paddleButton2,
              let three = xbox.paddleButton3,
              let four = xbox.paddleButton4 else { return nil }
        return PaddleInputs(one: one, two: two, three: three, four: four)
    }

    /// The paddles held, as the extended-buttons word.
    nonisolated static func heldPaddles(_ paddles: PaddleInputs?) -> UInt32 {
        guard let paddles else { return 0 }
        let rightUpper = paddles.one.isPressed ? ProtocolConstants.extButtonRightPaddle1 : 0
        let rightLower = paddles.two.isPressed ? ProtocolConstants.extButtonRightPaddle2 : 0
        let leftUpper = paddles.three.isPressed ? ProtocolConstants.extButtonLeftPaddle1 : 0
        let leftLower = paddles.four.isPressed ? ProtocolConstants.extButtonLeftPaddle2 : 0
        return rightUpper | rightLower | leftUpper | leftLower
    }
}
