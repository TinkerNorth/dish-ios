// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// A window's room along one way, as SwiftUI's size class gives it.
enum SizeClass: Equatable {
    case compact
    case regular
}

/// Whether a window is on its side: an iPad's window can stand either way
/// on any screen, and its size classes are regular both ways in each.
enum WindowShape: Equatable {
    case portrait
    case landscape
}

/// The window as the scene reads it at its root: the size class across and
/// down, and whether it is on its side. A page lays out from these, never
/// from SwiftUI's own (ViewPurityTests, V13).
struct WindowFacts: Equatable {
    let width: SizeClass
    let height: SizeClass
    let shape: WindowShape

    /// An iPhone held upright: the window before the scene has read it.
    static let phone = WindowFacts(width: .compact, height: .regular, shape: .portrait)
}

/// A class SwiftUI has not given yet is the phone's.
func sizeClass(_ sizeClass: UserInterfaceSizeClass?) -> SizeClass {
    switch sizeClass {
    case .regular: .regular
    case .compact, nil: .compact
    @unknown default: .compact
    }
}

/// Wider than tall is on its side; a square window is not.
func windowShape(_ size: CGSize) -> WindowShape {
    let onItsSide = size.width > size.height
    return onItsSide ? .landscape : .portrait
}

func windowFacts(width: UserInterfaceSizeClass?, height: UserInterfaceSizeClass?, shape: WindowShape) -> WindowFacts {
    WindowFacts(width: sizeClass(width), height: sizeClass(height), shape: shape)
}

/// The scene's reader of the window, at its root: the one place the size
/// classes are read and the window is measured, handed down as
/// `windowFacts` to every page, cover and sheet under it.
struct WindowReader: ViewModifier {
    @Environment(\.horizontalSizeClass) private var width
    @Environment(\.verticalSizeClass) private var height
    @State private var shape = WindowShape.portrait

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: WindowShape.self, of: { windowShape($0.size) }, action: { shape = $0 })
            .environment(\.windowFacts, windowFacts(width: width, height: height, shape: shape))
    }
}
