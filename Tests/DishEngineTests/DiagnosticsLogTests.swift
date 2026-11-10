// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// A wall clock in milliseconds the test moves by hand.
@MainActor
private final class ManualMilliseconds {
    var now: Int64

    init(_ now: Int64) {
        self.now = now
    }

    func read() -> Int64 {
        now
    }
}

/// The flight recorder: onsets only, the first snapshot as the opening
/// inventory, a bounded store that numbers every line, and a recorder that
/// diffs what the pages render.
@MainActor
final class DiagnosticsLogTests: XCTestCase {

    private func link(_ id: String, _ state: LinkState) -> LinkSnapshot {
        LinkSnapshot(id: id, label: id.capitalized, state: state)
    }

    private func pad(_ id: String, bound: String = "") -> PadSnapshot {
        PadSnapshot(id: id, name: .named(id.capitalized), boundId: bound, boundLabel: bound.capitalized)
    }

    private func summary(_ id: String, _ live: LinkState, boundTo slots: [String] = []) -> ConnectionSummary {
        ConnectionSummary(id: id, name: id.capitalized, live: live, boundSlotIds: slots)
    }

    private func controller(_ id: String, link: ControllerLink = .bluetooth) -> ControllerFact {
        ControllerFact(id: id, name: id.capitalized, link: link, batteryPercent: nil, destination: nil)
    }

    // MARK: - Links

    func testTheFirstSnapshotIsTheOpeningInventory() {
        let events = linkEvents(before: [], after: [link("desk", .saved), link("den", .connected)], atMs: 5)
        XCTAssertEqual(events, [
            DiagnosticsEvent(atMs: 5, kind: .linkAppeared, subject: "Desk", to: .saved),
            DiagnosticsEvent(atMs: 5, kind: .linkAppeared, subject: "Den", to: .connected)
        ])
    }

    func testALinkLogsOnlyWhenItsStateMovesOrItGoes() {
        let before = [link("desk", .connecting), link("den", .connected)]
        let after = [link("desk", .connected)]
        XCTAssertEqual(linkEvents(before: before, after: after, atMs: 9), [
            DiagnosticsEvent(atMs: 9, kind: .linkChanged, subject: "Desk", from: .connecting, to: .connected),
            DiagnosticsEvent(atMs: 9, kind: .linkRemoved, subject: "Den", to: .connected)
        ])
        XCTAssertEqual(linkEvents(before: after, after: after, atMs: 10), [], "a quiet tick logs nothing")
    }

    // MARK: - Pads

    func testAPadLogsItsArrivalItsBindingsAndItsDeparture() {
        XCTAssertEqual(padEvents(before: [], after: [pad("ds")], atMs: 1), [DiagnosticsEvent(atMs: 1, kind: .padAttached, subject: "Ds")])
        XCTAssertEqual(
            padEvents(before: [pad("ds")], after: [pad("ds", bound: "desk")], atMs: 2),
            [DiagnosticsEvent(atMs: 2, kind: .padBound, subject: "Ds", host: "Desk")]
        )
        XCTAssertEqual(
            padEvents(before: [pad("ds", bound: "desk")], after: [pad("ds", bound: "den")], atMs: 3),
            [DiagnosticsEvent(atMs: 3, kind: .padBound, subject: "Ds", host: "Den")],
            "a move is a bind to the new host"
        )
        XCTAssertEqual(
            padEvents(before: [pad("ds", bound: "den")], after: [pad("ds")], atMs: 4),
            [DiagnosticsEvent(atMs: 4, kind: .padUnbound, subject: "Ds", host: "Den")],
            "only losing the host is an unbind, naming the host left"
        )
        XCTAssertEqual(
            padEvents(before: [pad("ds", bound: "den")], after: [], atMs: 5),
            [DiagnosticsEvent(atMs: 5, kind: .padDetached, subject: "Ds", host: "Den")]
        )
    }

    func testTheSnapshotsReadTheShapesThePagesRender() {
        XCTAssertEqual(linkSnapshot(of: summary("desk", .unstable)), link("desk", .unstable))
        XCTAssertEqual(padSnapshot(of: controller("ds"), boundId: nil, bound: nil), pad("ds"))
        let bound = padSnapshot(of: controller("ds"), boundId: "desk", bound: summary("desk", .connected, boundTo: ["ds"]))
        XCTAssertEqual(bound, pad("ds", bound: "desk"))
        let gone = padSnapshot(of: controller("ds"), boundId: "desk", bound: nil)
        XCTAssertEqual(gone.boundLabel, "desk", "the id stands in once the row is gone")
        let onScreen = padSnapshot(of: controller(onScreenSlotId, link: .onScreen), boundId: nil, bound: nil)
        XCTAssertEqual(onScreen.name, .onScreenGamepad, "the on-screen gamepad is the app's to word")
    }

    // MARK: - The store

    func testTheStoreNumbersEveryLineAndKeepsTheNewest() {
        let store = DiagnosticsLogStore()
        store.record([])
        XCTAssertEqual(store.state, [], "nothing to record is no change")
        store.record([
            DiagnosticsEvent(atMs: 1, kind: .padAttached, subject: "A"),
            DiagnosticsEvent(atMs: 1, kind: .padAttached, subject: "B")
        ])
        store.record([DiagnosticsEvent(atMs: 2, kind: .padDetached, subject: "A")])
        XCTAssertEqual(store.state.map(\.sequence), [1, 2, 3])
        XCTAssertEqual(store.state.map(\.subject), ["A", "B", "A"])
        let flood = (0 ..< DiagnosticsLog.capacity).map { DiagnosticsEvent(atMs: Int64($0), kind: .linkRemoved, subject: "x") }
        store.record(flood)
        XCTAssertEqual(store.state.count, DiagnosticsLog.capacity)
        XCTAssertEqual(store.state.first?.subject, "x", "the oldest lines fall off")
        XCTAssertEqual(store.state.last?.sequence, 3 + DiagnosticsLog.capacity)
    }

    // MARK: - The recorder

    func testTheRecorderDiffsTheRowsAndThePadsOnItsOwnClock() {
        let store = DiagnosticsLogStore()
        let clock = ManualMilliseconds(100)
        let recorder = DiagnosticsRecorder(store: store, clock: clock.read)
        recorder.observeLinks([summary("desk", .saved)])
        recorder.observeSlots([pad("ds")])
        clock.now = 200
        recorder.observeLinks([summary("desk", .connected, boundTo: ["ds"])])
        recorder.observeSlots([pad("ds", bound: "desk")])
        recorder.observeSlots([pad("ds", bound: "desk")])
        XCTAssertEqual(store.state.map(\.kind), [.linkAppeared, .padAttached, .linkChanged, .padBound])
        XCTAssertEqual(store.state.map(\.atMs), [100, 100, 200, 200])
        XCTAssertEqual(store.state.last?.host, "Desk")
    }
}
