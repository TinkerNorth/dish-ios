// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI

/// The session accessory: the PC, how the link is doing, Dim and Play, or
/// Reconnect once the PC stops responding. While the tab bar is minimized
/// the accessory is inline and carries the short line alone. A nil action
/// leaves its button out.
struct SessionBar: View {
    let state: SessionBarState
    let dim: () -> Void
    let play: (() -> Void)?
    let reconnect: (() -> Void)?

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        switch placement {
        case .some(.inline): SessionBarInline(state: state)
        default: expanded
        }
    }

    @ViewBuilder private var expanded: some View {
        switch state {
        case let .streaming(pcName, line, _, dimTitle, playTitle):
            HStack(spacing: DishSpace.s6) {
                RowGlyph(symbol: satelliteSymbol)
                SessionBarTitles(pcName: pcName, line: line, lineFont: DishFont.monoDetail, lineColor: DishTheme.muted)
                Spacer(minLength: DishSpace.s4)
                SessionRoundButton(title: dimTitle, symbol: "moon.fill", tint: DishTheme.onSurface, fill: DishTheme.surfaceDim, action: dim)
                if let play {
                    SessionRoundButton(
                        title: playTitle,
                        symbol: "play.fill",
                        tint: DishTheme.onPrimary,
                        fill: DishTheme.primary,
                        action: play
                    )
                }
            }
            .padding(.horizontal, DishSpace.s4)
        case let .problem(pcName, line, reconnectTitle):
            HStack(spacing: DishSpace.s6) {
                RowGlyph(symbol: "exclamationmark.triangle.fill", tint: DishTheme.error, fill: DishTheme.errorDim)
                SessionBarTitles(pcName: pcName, line: line, lineFont: DishFont.detail, lineColor: DishTheme.error)
                Spacer(minLength: DishSpace.s4)
                if let reconnect {
                    Button(action: reconnect) {
                        Label(reconnectTitle, systemImage: "arrow.clockwise").font(DishFont.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            }
            .padding(.horizontal, DishSpace.s4)
        }
    }
}

/// The inline accessory: the short line, or the warning alone.
private struct SessionBarInline: View {
    let state: SessionBarState

    var body: some View {
        switch state {
        case let .streaming(_, _, shortLine, _, _):
            Text(shortLine).font(DishFont.monoDetail).foregroundStyle(DishTheme.onSurface)
        case let .problem(_, line, _):
            Text(line).font(DishFont.detail).foregroundStyle(DishTheme.error)
        }
    }
}

/// The PC's name over the status line.
private struct SessionBarTitles: View {
    let pcName: String
    let line: String
    let lineFont: Font
    let lineColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s1) {
            Text(pcName).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
            Text(line).font(lineFont).foregroundStyle(lineColor)
        }
        .lineLimit(1)
    }
}

/// Dim and Play: a glyph in a filled circle, named for VoiceOver.
private struct SessionRoundButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: DishSize.sessionButtonSymbol, height: DishSize.sessionButtonSymbol)
                .foregroundStyle(tint)
                .frame(width: DishSize.sessionButton, height: DishSize.sessionButton)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

/// A tab bar with one empty tab, to host the accessory in a preview.
private struct SessionBarPreview: View {
    let state: SessionBarState

    var body: some View {
        TabView {
            SwiftUI.Tab(tabTitle(.controllers), systemImage: tabSymbol(.controllers)) {
                DishTheme.background.ignoresSafeArea()
            }
        }
        .tabViewBottomAccessory {
            SessionBar(state: state, dim: {}, play: {}, reconnect: {})
        }
    }
}

private let previewWords = L10n.app

#Preview("Streaming") {
    SessionBarPreview(state: .streaming(
        pcName: "Living Room PC",
        line: [previewWords.streaming, previewWords.padCount(3), previewWords.latency(4)].joined(separator: lineSeparator),
        shortLine: [previewWords.padCount(3), previewWords.latency(4)].joined(separator: lineSeparator),
        dim: previewWords.dim,
        play: previewWords.play
    ))
}

#Preview("Stopped responding") {
    SessionBarPreview(state: .problem(pcName: "Living Room PC", line: previewWords.stoppedResponding, reconnect: previewWords.reconnect))
}
