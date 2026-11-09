// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI

/// THIS IPHONE › Name on your PC.
struct DeviceSection: View {
    let state: DeviceSectionState
    let edit: @MainActor () -> Void

    var body: some View {
        Section {
            Button(action: edit) {
                SettingsLinkRow(title: state.nameTitle, value: state.name)
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            SettingsFooter(text: state.footer)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// WHILE STREAMING › Keep screen on, Dim screen after.
struct StreamingSection: View {
    let state: StreamingSectionState
    let actions: SettingsActions

    var body: some View {
        Section {
            Toggle(state.keepScreenOnTitle, isOn: Binding(get: { state.keepScreenOn }, set: { actions.setKeepScreenOn($0) }))
            Picker(state.dimTitle, selection: Binding(get: { state.dimAfter }, set: { actions.setDimAfter($0) })) {
                ForEach(state.options) { Text($0.title).tag($0.delay) }
            }
            .pickerStyle(.navigationLink)
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            SettingsFooter(text: state.footer)
        }
        .foregroundStyle(DishTheme.onSurface)
        .listRowBackground(DishTheme.surface)
    }
}

/// SETUP & HELP › Setup guide.
struct HelpSection: View {
    let state: HelpSectionState
    let openGuide: @MainActor () -> Void

    var body: some View {
        Section {
            Button(action: openGuide) {
                HStack(spacing: DishSpace.s6) {
                    RowGlyph(symbol: state.guideSymbol)
                    SettingsLinkRow(title: state.guide, value: nil)
                }
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// APPEARANCE › System, Light, Dark.
struct AppearanceSection: View {
    let state: AppearanceSectionState
    let select: @MainActor (Appearance) -> Void

    var body: some View {
        Section {
            Picker(state.title, selection: Binding(get: { state.selected }, set: { select($0) })) {
                ForEach(state.options) { Text($0.title).tag($0.appearance) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// ABOUT › Version.
struct AboutSection: View {
    let state: AboutSectionState

    var body: some View {
        Section {
            LabeledContent(state.versionTitle, value: state.version)
                .foregroundStyle(DishTheme.onSurface)
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// A row that pushes: its title, an optional value, and a chevron.
private struct SettingsLinkRow: View {
    let title: String
    let value: String?

    var body: some View {
        HStack {
            Text(title).font(DishFont.body).foregroundStyle(DishTheme.onSurface)
            Spacer()
            if let value {
                Text(value).font(DishFont.body).foregroundStyle(DishTheme.muted)
            }
            Image(systemName: "chevron.right").font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
        .contentShape(Rectangle())
    }
}

/// The explanation under a section.
struct SettingsFooter: View {
    let text: String

    var body: some View {
        Text(text).font(DishFont.detail).foregroundStyle(DishTheme.muted)
    }
}
