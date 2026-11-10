// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A PIN's digits in a row of cells: the satellite's PIN as it is typed,
/// the caret's cell outlined in the focus colour, or any code shown whole.
/// It draws what it is handed and takes no touches of its own; the field
/// over it owns the typing.
struct PinCells: View {
    let cells: [PinCellState]
    let stroke: Color
    let focusStroke: Color
    let ink: Color

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            ForEach(cells) { cell in
                Text(cell.digit)
                    .font(DishFont.pinDigit)
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .frame(width: DishSize.pinCell, height: DishSize.pinCell)
                    .background(RoundedRectangle(cornerRadius: DishSize.pinCellCorner, style: .continuous).fill(DishTheme.surface))
                    .overlay(
                        RoundedRectangle(cornerRadius: DishSize.pinCellCorner, style: .continuous)
                            .stroke(
                                cell.focused ? focusStroke : stroke,
                                lineWidth: cell.focused ? DishSize.padHeldStroke : DishSize.padStroke
                            )
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    PinCells(cells: pinCells("73"), stroke: DishTheme.outline, focusStroke: DishTheme.primary, ink: DishTheme.onSurface)
        .padding()
        .background(DishTheme.background)
}
