// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// B4, Destination · 2 of 3: the Satellite PCs on this Wi‑Fi first, then a
/// Moonlight host, a PC by address and the Satellite download. With Local
/// Network off, the refusal and Open Settings stand in for the list.
struct PickPCStep: View {
    let state: PickPCStepState

    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.settingsURL) private var settingsURL

    var body: some View {
        List {
            SetupHeading(title: state.title, detail: state.body)
            Section {
                satelliteList(state.satellite.list)
            } header: {
                SatelliteHeader(section: state.satellite)
            }
            Section {
                MoonlightRow(section: state.moonlight)
                ForEach(state.moonlight.hosts) { host in
                    SetupPCRowView(row: host, pick: model.pickSetupDestination)
                }
                Button(action: addByAddress) {
                    Label(state.byAddress, systemImage: DishSymbol.add)
                }
                Button(action: openSatellite) {
                    Label(state.getSatellite.title, systemImage: DishSymbol.external)
                }
            } footer: {
                Text(state.footnote)
                    .font(DishFont.detail)
            }
            .tint(DishTheme.primary)
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func satelliteList(_ list: SatelliteListState) -> some View {
        switch list {
        case let .rows(rows):
            ForEach(rows) { row in
                SetupPCRowView(row: row, pick: model.pickSetupDestination)
            }
        case let .nothingYet(text):
            Text(text)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.muted)
        case let .refused(refusal):
            SetupRefusalView(refusal: refusal, openSettings: openSettings)
        }
    }

    private func addByAddress() {
        model.pickSetupDestination(.byAddress)
    }

    private func openSatellite() {
        guard let url = state.getSatellite.url else { return }
        openURL(url)
    }

    private func openSettings() {
        guard let settingsURL else { return }
        openURL(settingsURL)
    }
}

private struct SatelliteHeader: View {
    let section: SatelliteSectionState

    var body: some View {
        HStack(spacing: DishSpace.s4) {
            SectionEyebrow(title: section.title, color: DishTheme.muted)
            Chip(text: section.chip.text, tone: section.chip.tone)
            Spacer()
            if let searching = section.searching {
                ProgressView()
                    .controlSize(.mini)
                Text(searching)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
                    .textCase(nil)
            }
        }
    }
}

private struct MoonlightRow: View {
    let section: MoonlightSectionState

    var body: some View {
        HStack(spacing: DishSpace.s6) {
            SetupGlyphTile(symbol: section.symbol)
            VStack(alignment: .leading, spacing: DishSpace.s1) {
                HStack(spacing: DishSpace.s4) {
                    Text(section.title)
                        .font(DishFont.body)
                        .foregroundStyle(DishTheme.onSurface)
                    Chip(text: section.chip.text, tone: section.chip.tone)
                }
                Text(section.body)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A PC Dish heard: its name in mono, the pairing dot and the address.
private struct SetupPCRowView: View {
    let row: SetupPCRow
    let pick: (DestinationPick) -> Void

    var body: some View {
        Button(action: choose) {
            HStack(spacing: DishSpace.s6) {
                SetupGlyphTile(symbol: row.symbol)
                VStack(alignment: .leading, spacing: DishSpace.s1) {
                    Text(row.name)
                        .font(DishFont.mono)
                        .foregroundStyle(DishTheme.onSurface)
                    HStack(spacing: DishSpace.s3) {
                        StatusDot(color: row.dot)
                        Text(row.detail)
                            .font(DishFont.monoDetail)
                            .foregroundStyle(DishTheme.muted)
                    }
                }
                Spacer(minLength: DishSpace.s4)
                Image(systemName: DishSymbol.disclosure)
                    .font(DishFont.detail)
                    .foregroundStyle(DishTheme.muted)
            }
        }
    }

    private func choose() {
        pick(row.pick)
    }
}

/// D3 inside the step: Local Network is off, and the way back on.
private struct SetupRefusalView: View {
    let refusal: SetupRefusalState
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s6) {
            Text(refusal.title)
                .font(DishFont.headline)
                .foregroundStyle(DishTheme.onSurface)
            Text(refusal.body)
                .font(DishFont.detail)
                .foregroundStyle(DishTheme.muted)
            Button(refusal.action, action: openSettings)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
            Text(refusal.path)
                .font(DishFont.caption)
                .foregroundStyle(DishTheme.muted)
        }
        .padding(.vertical, DishSpace.s4)
    }
}

#Preview("Nothing heard") {
    PickPCStep(state: pickPCStepState(PreviewSetup.nothingSeen))
        .environment(PreviewSetup.emptyModel())
}

#Preview("Searching, two PCs") {
    PickPCStep(state: pickPCStepState(PreviewSetup.padsAndPCs))
        .environment(PreviewSetup.emptyModel())
}

#Preview("Local Network off") {
    PickPCStep(state: pickPCStepState(PreviewSetup.refused))
        .environment(PreviewSetup.emptyModel())
}
