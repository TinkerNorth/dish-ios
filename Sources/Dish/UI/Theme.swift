// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import UIKit

/// The palette, shared with every Dish client (the cross-repo token schema
/// in DESIGN.md). Every colour a view draws is one of these names, and each
/// resolves to its dark or light value with the trait collection, which the
/// Appearance setting drives through `preferredColorScheme`.
enum DishTheme {
    static let background = Color(dark: 0x060818, light: 0xF2F4F8)
    static let surface = Color(dark: 0x0C1027, light: 0xFFFFFF)
    static let surfaceDim = Color(dark: 0x131A3A, light: 0xE7ECF6)
    static let primary = Color(dark: 0x4FE3FF, light: 0x0E7C97)
    static let primaryDark = Color(dark: 0x2C93AD, light: 0x0A5E73)
    static let onPrimary = Color(dark: 0x060818, light: 0xFFFFFF)
    static let onSurface = Color(dark: 0xE6ECFF, light: 0x0C1430)
    static let muted = Color(dark: 0x93A0C8, light: 0x5A6680)
    static let outline = Color(dark: 0x4FE3FF, light: 0x0E7C97, alpha: 0.18)
    static let success = Color(dark: 0x22C55E, light: 0x1B873F)
    static let error = Color(dark: 0xFF6B5C, light: 0xC0392B)
    static let warning = Color(dark: 0xF59E0B, light: 0xB7791F)
    static let cardStroke = Color(dark: 0x4FE3FF, light: 0x0E7C97, alpha: 0.12)

    /// The one hue beyond the accent, kept for donations: the tips heart.
    static let pulse = Color(dark: 0xFF6FB5, light: 0xC2417F)
    /// The brand glyphs' fill, from the brand book rather than the UI accent.
    static let brandGlyph = Color(dark: 0x8FCFE3, light: 0x2F7E96)
}

/// The type scale, every name a Dynamic Type style so the words grow with
/// the person's setting. SF Pro for prose, SF Mono for a PC's name, an
/// address, a rate or a latency, as the boards draw them.
enum DishFont {
    /// A cover's headline and a tab's own large title.
    static let largeTitle = Font.largeTitle.bold()
    /// A setup step's question.
    static let title = Font.title.bold()
    /// A row's name.
    static let body = Font.body
    /// A row's name with weight, a feature's name on the welcome.
    static let headline = Font.headline
    /// A row's second line.
    static let detail = Font.footnote
    /// A hint under a list.
    static let caption = Font.caption
    /// A PC's name in a row.
    static let mono = Font.system(.body, design: .monospaced)
    /// A PC's address, a latency, a rate, the session line.
    static let monoDetail = Font.system(.footnote, design: .monospaced)
    /// A section's eyebrow, drawn upper-cased and tracked.
    static let eyebrow = Font.system(.caption, design: .monospaced).weight(.semibold)
}

/// The measures. Every size a kit component sets is one of these names.
enum DishSize {
    /// The glyph tile at the head of a row.
    static let rowGlyph: CGFloat = 40
    /// The tile's corner.
    static let rowGlyphCorner: CGFloat = 10
    /// The glyph inside the tile.
    static let rowGlyphSymbol: CGFloat = 20
    /// The small coloured status dot.
    static let statusDot: CGFloat = 8
    /// The brand mark on the welcome.
    static let welcomeMark: CGFloat = 112
    /// The tracking of a section eyebrow.
    static let eyebrowTracking: CGFloat = 1.4
    /// A hairline.
    static let hairline: CGFloat = 1
}

/// The spacing scale.
enum DishSpace {
    static let s1: CGFloat = 2
    static let s2: CGFloat = 4
    static let s3: CGFloat = 6
    static let s4: CGFloat = 8
    static let s5: CGFloat = 10
    static let s6: CGFloat = 12
    static let s8: CGFloat = 16
    static let s12: CGFloat = 24
    /// A page's inset from the screen's edges.
    static let page: CGFloat = 16
}

extension Color {
    /// A colour that follows the trait collection: `dark` under a dark
    /// appearance, `light` otherwise, both sRGB hex with one alpha.
    init(dark: UInt32, light: UInt32, alpha: Double = 1.0) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: Double) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: CGFloat(alpha)
        )
    }
}

/// A tracked, monospaced, upper-cased section eyebrow in the colour its
/// section asks for: the accent to call a section out, muted otherwise.
struct SectionEyebrow: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(DishFont.eyebrow)
            .tracking(DishSize.eyebrowTracking)
            .foregroundStyle(color)
    }
}

/// The small coloured status dot beside a row's second line.
struct StatusDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: DishSize.statusDot, height: DishSize.statusDot)
    }
}
