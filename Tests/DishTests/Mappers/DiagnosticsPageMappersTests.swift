// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// The Diagnostics page as one state from the model's facts: the app's own
/// lines, a card per PC and per controller or the word for none, the lock
/// statistics only in a build that counts them, the recorder's newest
/// lines, and the transcript Copy and Share hand over.
final class DiagnosticsPageMappersTests: XCTestCase {

    private let english = Locale(identifier: "en_US")

    private func utc() throws -> TimeZone {
        try XCTUnwrap(TimeZone(identifier: "UTC"))
    }

    private func page(_ facts: ShellFacts) throws -> DiagnosticsPageState {
        try diagnosticsPageState(facts: facts, appVersion: "0.1.0", locale: english, timeZone: utc())
    }

    private func host(_ live: LinkState = .saved) -> HostDiagnostics {
        let summary = ConnectionSummary(id: "sat", name: "Den PC", address: "10.0.0.2", udpPort: 9876, live: live)
        return HostDiagnostics(summary: summary, facts: .resting(id: "sat"), counters: .none)
    }

    private func pad(_ destination: DestinationFact? = nil, supported: Bool = true) -> PadDiagnostics {
        let controller = ControllerFact(
            id: "pad",
            name: "DualSense",
            link: .usbC,
            batteryPercent: 84,
            destination: destination,
            family: .dualSense,
            emulateAs: .dualSense,
            supported: supported
        )
        return PadDiagnostics(controller: controller, rates: PadRates(reportHz: 250, motionHz: 0), reports: 12, wire: nil)
    }

    private static let emptyTranscript = """
    Dish
    App version: 0.1.0
    Protocol: v3
    Local Network: Not asked yet

    Connections
    No PCs yet. Pair one on the Connections tab and its session shows here.

    Controllers
    No controllers connected

    Events
    No events yet.
    """

    func testNothingSeenSaysSoAndTheTranscriptStillCarriesTheApp() throws {
        let state = try page(FactsFixture.shell())
        XCTAssertEqual(state.title, "Diagnostics")
        XCTAssertEqual(state.intro, "Each host’s session, each controller down to the wire, and a log of what changed.")
        XCTAssertEqual(state.app.title, "Dish")
        XCTAssertEqual(state.app.lines.map(\.key), ["App version", "Protocol", "Local Network"])
        XCTAssertEqual(state.hosts.title, "Connections")
        XCTAssertEqual(state.hosts.cards, .empty("No PCs yet. Pair one on the Connections tab and its session shows here."))
        XCTAssertEqual(state.pads.title, "Controllers")
        XCTAssertEqual(state.pads.cards, .empty("No controllers connected"))
        XCTAssertNil(state.locks, "a plain build counts no locks")
        XCTAssertEqual(state.events.title, "Events")
        XCTAssertEqual(state.events.content, .empty("No events yet."))
        XCTAssertEqual(state.events.note, "Newest first. The log covers this run of Dish and is not saved.")
        XCTAssertEqual(state.copy, "Copy")
        XCTAssertEqual(state.copied, "Copied")
        XCTAssertEqual(state.transcript, Self.emptyTranscript)
    }

    func testAPCsCardCarriesItsDotItsChipAndItsLines() throws {
        let state = try page(FactsFixture.shell(diagnostics: DiagnosticsSnapshot(hosts: [host()])))
        guard case let .cards(cards) = state.hosts.cards else { return XCTFail("a PC is a card") }
        let card = try XCTUnwrap(cards.first)
        XCTAssertEqual(card.id, "sat")
        XCTAssertEqual(card.title, "Den PC")
        XCTAssertEqual(card.dot, DishTheme.muted)
        XCTAssertEqual(card.chip, "Offline")
        XCTAssertEqual(card.lines, hostLines(host(), locale: english))
        XCTAssertTrue(state.transcript.contains("Connections\nDen PC · Offline\nAddress: 10.0.0.2 · UDP 9876\n"), state.transcript)
    }

    func testAControllersCardWearsItsHealthAsItsDotAndChip() throws {
        let online = pad(DestinationFact(name: "Den PC", health: .online))
        let lost = pad(DestinationFact(name: "Den PC", health: .lost))
        let state = try page(FactsFixture.shell(diagnostics: DiagnosticsSnapshot(pads: [online, lost, pad(), pad(supported: false)])))
        guard case let .cards(cards) = state.pads.cards else { return XCTFail("a controller is a card") }
        XCTAssertEqual(cards.map(\.title), ["DualSense", "DualSense", "DualSense", "DualSense"])
        XCTAssertEqual(cards.map(\.chip), ["Online", "Connection lost", "Not bound", "Not supported"])
        XCTAssertEqual(cards.map(\.dot), [DishTheme.success, DishTheme.error, DishTheme.muted, DishTheme.muted])
        XCTAssertEqual(cards.first?.lines, padLines(online))
    }

    func testTheLockStatisticsShowOnlyInABuildThatCounts() throws {
        let lock = LockFact(lock: "satellite.latency", role: .heartbeat, acquisitions: 42, contended: 1, waitMaxNs: 0, holdMaxNs: 0)
        let state = try page(FactsFixture.shell(diagnostics: DiagnosticsSnapshot(locks: [lock])))
        XCTAssertEqual(state.locks, DiagnosticsSectionState(
            title: "Lock statistics",
            lines: [FactLine(key: "satellite.latency · Heartbeat", value: "42 taken · 1 contended")]
        ))
        let block = "\nLock statistics\nsatellite.latency · Heartbeat: 42 taken · 1 contended\n"
        XCTAssertTrue(state.transcript.contains(block), state.transcript)
        let counted = try page(FactsFixture.shell(diagnostics: DiagnosticsSnapshot(locks: [])))
        let nothingTaken = DiagnosticsSectionState(title: "Lock statistics", lines: [])
        XCTAssertEqual(counted.locks, nothingTaken, "a counting build with nothing taken yet")
    }

    func testTheRecorderShowsNewestFirstAndTheTranscriptCopiesOldestFirst() throws {
        let events = [
            DiagnosticsEvent(sequence: 1, atMs: 3_600_000, kind: .linkRemoved, subject: "Desk"),
            DiagnosticsEvent(sequence: 2, atMs: 3_661_000, kind: .padDetached, subject: "Pad")
        ]
        let state = try diagnosticsPageState(
            facts: FactsFixture.shell(diagnosticsEvents: events),
            appVersion: "0.1.0",
            locale: Locale(identifier: "en_GB"),
            timeZone: utc()
        )
        XCTAssertEqual(state.events.content, .lines([
            DiagnosticsEventLine(id: 2, text: "01:01:01  Pad: detached"),
            DiagnosticsEventLine(id: 1, text: "01:00:00  Desk: removed")
        ]))
        XCTAssertTrue(state.transcript.hasSuffix("Events\n01:00:00  Desk: removed\n01:01:01  Pad: detached"), state.transcript)
    }
}
