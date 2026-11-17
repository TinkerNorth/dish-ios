// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// How a control that stands on its own answers the finger (DESIGN.md,
/// "Interaction states"): the pressed wash over its own surface, a slight
/// shrink, the pointer's highlight on an iPad, and the fade of one that is
/// disabled. A list row that opens a page is a `RowButton` instead.
struct PressStyle<Surface: Shape>: ButtonStyle {
    /// The shape the wash fills: the control's own.
    let surface: Surface

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(surface.fill(DishTheme.pressWash).opacity(layerOpacity(shown: configuration.isPressed)))
            .scaleEffect(pressedScale(pressed: configuration.isPressed))
            .opacity(controlOpacity(enabled: isEnabled))
            .animation(pressAnimation(pressed: configuration.isPressed), value: configuration.isPressed)
            .hoverEffect(.highlight)
            .contentShape(surface)
    }
}

extension ButtonStyle where Self == PressStyle<RoundedRectangle> {
    /// A tile that stands on its own: the action strip's.
    static var tile: PressStyle<RoundedRectangle> {
        PressStyle(surface: RoundedRectangle(cornerRadius: DishSize.actionTileCorner))
    }
}

extension ButtonStyle where Self == PressStyle<Capsule> {
    /// A capsule that stands on its own: Add a controller.
    static var capsule: PressStyle<Capsule> {
        PressStyle(surface: Capsule())
    }
}

extension ButtonStyle where Self == PressStyle<Circle> {
    /// A round button: the session accessory's Dim.
    static var round: PressStyle<Circle> {
        PressStyle(surface: Circle())
    }
}

/// A list row that opens a page: the whole cell washes while the finger is
/// down, as iOS highlights a cell, and keeps its place. A companion beside
/// the row (a PC row's Pair or Connect) or under it (a controller's action
/// strip) shares the cell and keeps its own taps and its own feedback.
struct RowButton<Label: View, Companion: View>: View {
    private let action: @MainActor () -> Void
    private let label: Label
    private let companion: RowCompanion<Companion>

    @State private var pressed = false

    /// A row with a button at its trailing edge.
    init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label, @ViewBuilder trailing: () -> Companion) {
        self.action = action
        self.label = label()
        companion = .trailing(trailing())
    }

    /// A row with a strip under it.
    init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label, @ViewBuilder below: () -> Companion) {
        self.action = action
        self.label = label()
        companion = .below(below())
    }

    var body: some View {
        arranged
            .listRowBackground(RowSurface(pressed: pressed))
    }

    @ViewBuilder private var arranged: some View {
        switch companion {
        case .none:
            button
        case let .trailing(view):
            HStack(spacing: DishSpace.s6) {
                button
                view
            }
        case let .below(view):
            VStack(alignment: .leading, spacing: DishSpace.s4) {
                button
                view
            }
        }
    }

    private var button: some View {
        Button(action: action) { label }
            .buttonStyle(RowPressStyle(pressed: $pressed))
    }
}

extension RowButton where Companion == EmptyView {
    /// A row that is the whole cell.
    init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
        companion = .none
    }
}

/// What shares a `RowButton`'s cell.
private enum RowCompanion<Companion: View> {
    case none
    case trailing(Companion)
    case below(Companion)
}

/// The row's own press: the pointer's highlight and the disabled fade on
/// the row, and the finger reported to the `RowButton`, which washes the cell.
private struct RowPressStyle: ButtonStyle {
    @Binding var pressed: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(controlOpacity(enabled: isEnabled))
            .contentShape(Rectangle())
            .hoverEffect(.highlight)
            .onChange(of: configuration.isPressed) { _, isPressed in pressed = isPressed }
    }
}

extension View {
    /// A split list's row beside its detail: the row the detail shows is
    /// tinted, as iOS marks a sidebar's open row.
    func selectedRow(_ selected: Bool) -> some View {
        listRowBackground(RowSurface(pressed: false, selected: selected))
    }
}

/// The cell's surface: tinted while its page is the one open beside a
/// split's list, washed while the finger is down.
private struct RowSurface: View {
    let pressed: Bool
    var selected = false

    var body: some View {
        ZStack {
            DishTheme.surface
            Rectangle().fill(DishTheme.primaryFill).opacity(layerOpacity(shown: selected))
            Rectangle().fill(DishTheme.pressWash).opacity(layerOpacity(shown: pressed))
        }
        .animation(pressAnimation(pressed: pressed), value: pressed)
    }
}

/// A state's layer shows whole or not at all: the wash while the finger is
/// down, the tint while the row is the one open.
func layerOpacity(shown: Bool) -> Double {
    shown ? 1 : 0
}

/// A control that stands on its own shrinks a little under the finger.
func pressedScale(pressed: Bool) -> CGFloat {
    pressed ? DishMotion.pressScale : 1
}

/// The wash comes quickly and goes slowly enough for a tap to show.
func pressAnimation(pressed: Bool) -> Animation {
    pressed ? DishMotion.pressIn : DishMotion.pressOut
}

/// A disabled control fades; an enabled one is whole.
func controlOpacity(enabled: Bool) -> Double {
    enabled ? 1 : DishOpacity.disabled
}
