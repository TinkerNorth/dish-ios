// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI

/// Settings › Setup & help › Diagnostics: what the app sees right now, each
/// PC's session, each controller down to the wire, and the flight recorder.
/// Read-only: every figure is one the rest of the app already acts on, not
/// a second measurement. The source ticks while the page shows.
struct DiagnosticsPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appVersion) private var appVersion

    var body: some View {
        DiagnosticsPageBody(state: diagnosticsPageState(facts: model.shellFacts, appVersion: appVersion), copy: copy)
            .onAppear { model.pageAppeared(.diagnostics) }
            .onDisappear { model.pageDisappeared(.diagnostics) }
    }

    private func copy(_ transcript: String) {
        model.copyToPasteboard(transcript)
    }
}

/// The page over its state, so a preview can draw every state. Copy and
/// Share hand over the same transcript; Copy says so once it has.
struct DiagnosticsPageBody: View {
    let state: DiagnosticsPageState
    let copy: @MainActor (String) -> Void

    @State private var copied = false

    var body: some View {
        List {
            Section {
                ForEach(state.app.lines) { FactRow(line: $0) }
            } header: {
                SectionEyebrow(title: state.app.title, color: DishTheme.muted)
            } footer: {
                SettingsFooter(text: state.intro)
            }
            .listRowBackground(DishTheme.surface)
            DiagnosticsCardsSection(state: state.hosts)
            DiagnosticsCardsSection(state: state.pads)
            if let locks = state.locks {
                DiagnosticsLinesSection(state: locks)
            }
            DiagnosticsEventsSection(state: state.events)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DishTheme.background)
        .navigationTitle(state.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(copied ? state.copied : state.copy, action: copyTranscript)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: state.transcript)
            }
        }
    }

    private func copyTranscript() {
        copy(state.transcript)
        copied = true
    }
}

/// A section of cards: each card a row with its title, dot and chip over
/// its lines, or the word for none.
private struct DiagnosticsCardsSection: View {
    let state: DiagnosticsCardsState

    var body: some View {
        Section {
            switch state.cards {
            case let .empty(note): EmptyNote(text: note)
            case let .cards(cards): ForEach(cards) { DiagnosticsCardView(card: $0) }
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// A section of plain lines: the lock statistics.
private struct DiagnosticsLinesSection: View {
    let state: DiagnosticsSectionState

    var body: some View {
        Section {
            ForEach(state.lines) { FactRow(line: $0) }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// The recorder's newest lines, newest first, in mono.
private struct DiagnosticsEventsSection: View {
    let state: DiagnosticsEventsState

    var body: some View {
        Section {
            switch state.content {
            case let .empty(note): EmptyNote(text: note)
            case let .lines(lines): ForEach(lines) { EventRow(line: $0) }
            }
        } header: {
            SectionEyebrow(title: state.title, color: DishTheme.muted)
        } footer: {
            SettingsFooter(text: state.note)
        }
        .listRowBackground(DishTheme.surface)
    }
}

/// One card: the headline with its dot and chip, then its lines.
private struct DiagnosticsCardView: View {
    let card: DiagnosticsCardState

    var body: some View {
        VStack(alignment: .leading, spacing: DishSpace.s4) {
            HStack(spacing: DishSpace.s4) {
                if let dot = card.dot {
                    StatusDot(color: dot)
                }
                Text(card.title).font(DishFont.headline).foregroundStyle(DishTheme.onSurface)
                Spacer()
                if let chip = card.chip {
                    Text(chip).font(DishFont.monoDetail).foregroundStyle(DishTheme.muted)
                }
            }
            ForEach(card.lines) { FactRow(line: $0) }
        }
        .padding(.vertical, DishSpace.s2)
    }
}

/// One fact: the key muted on the left, the value in mono on the right.
private struct FactRow: View {
    let line: FactLine

    var body: some View {
        LabeledContent {
            Text(line.value)
                .font(DishFont.monoDetail)
                .foregroundStyle(DishTheme.onSurface)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        } label: {
            Text(line.key).font(DishFont.detail).foregroundStyle(DishTheme.muted)
        }
    }
}

private struct EventRow: View {
    let line: DiagnosticsEventLine

    var body: some View {
        Text(line.text)
            .font(DishFont.monoDetail)
            .foregroundStyle(DishTheme.onSurface)
            .textSelection(.enabled)
    }
}

/// The word for a section with nothing in it.
private struct EmptyNote: View {
    let text: String

    var body: some View {
        Text(text).font(DishFont.detail).foregroundStyle(DishTheme.muted)
    }
}

#Preview("Diagnostics") {
    let den = ConnectionSummary(id: "sat", name: "Den PC", address: "192.168.1.24", udpPort: 9876, live: .connected, latencyMs: 4.2)
    let facts = HostSessionFacts(
        id: "sat",
        live: true,
        offeredProtocol: 3,
        settledProtocol: 3,
        compat: .current,
        appliedEpoch: 4,
        hostEpoch: 4,
        hostBitmap: 0b1,
        confirmedBitmap: 0b1,
        backendAvailable: true,
        activeControllers: 1,
        missedAcks: 0,
        latency: LatencySummary(p50RttMs: 8.4, p99RttMs: 15.1, samples: 12, capacity: 64)
    )
    let counters = SessionCounters(sent: 1820, received: 920, dropped: 1, replayGuard: 920)
    let pad = ControllerFact(
        id: "pad",
        name: "DualSense Wireless Controller",
        link: .usbC,
        batteryPercent: 84,
        destination: DestinationFact(name: "Den PC", health: .online),
        family: .dualSense,
        emulateAs: .dualSense,
        features: [ControllerFeatureFact(feature: .motion, enabled: true)]
    )
    let wire = SlotWireFacts(controllerIndex: 0, type: 2, caps: 0x0007, touchpad: .pad, confirmed: true, streaming: .yes)
    let diagnostics = DiagnosticsSnapshot(
        hosts: [HostDiagnostics(summary: den, facts: facts, counters: counters)],
        pads: [PadDiagnostics(controller: pad, rates: PadRates(reportHz: 250, motionHz: 120), reports: 4210, wire: wire)]
    )
    let events = [
        DiagnosticsEvent(sequence: 1, atMs: 1_800_000_000_000, kind: .linkAppeared, subject: "Den PC", to: .saved),
        DiagnosticsEvent(sequence: 2, atMs: 1_800_000_004_000, kind: .padAttached, subject: "DualSense Wireless Controller"),
        DiagnosticsEvent(sequence: 3, atMs: 1_800_000_009_000, kind: .linkChanged, subject: "Den PC", from: .connecting, to: .connected),
        DiagnosticsEvent(sequence: 4, atMs: 1_800_000_009_000, kind: .padBound, subject: "DualSense Wireless Controller", host: "Den PC")
    ]
    let shell = previewFacts(localNetwork: .allowed, diagnostics: diagnostics, events: events)
    NavigationStack {
        DiagnosticsPageBody(state: diagnosticsPageState(facts: shell, appVersion: "0.1.0"), copy: { _ in })
    }
}

#Preview("Nothing seen") {
    let shell = previewFacts(localNetwork: .unknown, diagnostics: DiagnosticsSnapshot(), events: [])
    NavigationStack {
        DiagnosticsPageBody(state: diagnosticsPageState(facts: shell, appVersion: "0.1.0"), copy: { _ in })
    }
}

/// The shell's facts with only what Diagnostics reads filled in, for the previews.
private func previewFacts(localNetwork: LocalNetworkStatus, diagnostics: DiagnosticsSnapshot, events: [DiagnosticsEvent]) -> ShellFacts {
    ShellFacts(
        controllers: [],
        attachedPads: [],
        paired: [],
        found: [],
        scanning: false,
        session: nil,
        localNetwork: localNetwork,
        preferences: PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system),
        now: Date(timeIntervalSince1970: 1_800_000_000),
        setup: nil,
        diagnostics: diagnostics,
        diagnosticsEvents: events
    )
}
