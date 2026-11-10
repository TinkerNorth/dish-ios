// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// The Moonlight hosts page as data: its empty states, a known host's row
/// with its line, status, app picker, actions and menu, a discovered host's
/// row, the PIN card in the row that asked for it, the last word a host
/// said, and the add-by-address form.
final class MoonlightHostsMappersTests: XCTestCase {

    private let pc = MoonlightHost(name: "PC", address: "10.0.0.5", uniqueId: "abc")

    private func summary(_ live: LinkState, bound: [String] = []) -> ConnectionSummary {
        ConnectionSummary(id: pc.id, name: "PC", address: "10.0.0.5", live: live, kind: .moonlight, boundSlotIds: bound)
    }

    private func onlyRow(_ facts: MoonlightFacts) throws -> MoonlightHostRowState {
        guard case let .rows(rows) = moonlightList(facts), rows.count == 1 else { throw NotOneRow() }
        return rows[0]
    }

    private struct NotOneRow: Error {}

    // MARK: - Empty

    func testAnEmptyListLooksWhileTheSweepRuns() {
        let facts = MoonlightFacts(scanning: true)
        XCTAssertEqual(moonlightList(facts), .looking(
            title: "Looking for Moonlight hosts",
            body: "Scanning your network for hosts advertising GameStream. They appear here as they answer."
        ))
        XCTAssertEqual(moonlightHostsPageState(facts, draft: "").hosts.searching, "Searching")
    }

    func testAnEmptyListAfterTheSweepOffersSunshine() {
        guard case let .nothing(nothing) = moonlightList(MoonlightFacts()) else { return XCTFail("nothing found") }
        XCTAssertEqual(nothing.title, "No Moonlight hosts found")
        XCTAssertEqual(
            nothing.body,
            "A PC appears here once Sunshine, Apollo or Wolf is running on it and both machines are on the same network."
        )
        XCTAssertEqual(nothing.getSunshine, PageLink(title: "Get Sunshine", url: URL(string: "https://github.com/LizardByte/Sunshine")))
        XCTAssertNil(moonlightHostsPageState(MoonlightFacts(), draft: "").hosts.searching)
    }

    // MARK: - A known host

    func testAKnownHostsRowSaysItsKindTrustAddressAndControllers() throws {
        let row = try onlyRow(MoonlightFacts(hosts: [summary(.saved, bound: ["a", "b"])]))
        XCTAssertEqual(row.id, pc.id)
        XCTAssertEqual(row.symbol, "desktopcomputer")
        XCTAssertEqual(row.title, "PC")
        XCTAssertEqual(row.kindLine, "Moonlight host (Sunshine, Apollo or Wolf)")
        XCTAssertEqual(row.line, "Remembered · 10.0.0.5 · 2 controllers")
        XCTAssertEqual(row.dot, DishTheme.muted)
        XCTAssertNil(row.statusLine)
        XCTAssertNil(row.app, "no probe has listed apps yet")
        XCTAssertNil(row.pin)
        XCTAssertEqual(row.actions, [], "the bindings drive a paired host")
        let ready = try onlyRow(MoonlightFacts(hosts: [summary(.ready)]))
        XCTAssertEqual(ready.line, "Paired · 10.0.0.5", "no controllers, no count")
        XCTAssertEqual(ready.dot, DishTheme.success)
    }

    func testForgetAsksFirstInTheHostsName() throws {
        let row = try onlyRow(MoonlightFacts(hosts: [summary(.ready)]))
        XCTAssertEqual(row.menu, MoonlightRowMenuState(
            label: "More actions for PC",
            forget: "Forget",
            confirmTitle: "Forget PC?",
            confirmMessage: "Dish deletes its pairing and you will need the PIN again. "
                + "PC keeps its own record of this device until you remove it there.",
            cancel: "Cancel"
        ))
    }

    func testAKnownHostsActionsFollowItsSessionAndWaitOutAPairing() throws {
        var facts = MoonlightFacts(hosts: [summary(.ready)], phases: [pc.id: .failed(.appAlreadyRunning)])
        let row = try onlyRow(facts)
        XCTAssertEqual(row.actions.map(\.kind), [.quitApp, .retry])
        XCTAssertEqual(row.actions.map(\.title), ["Close the app on PC", "Retry"])
        XCTAssertEqual(row.actions.map(\.enabled), [true, true])
        XCTAssertEqual(row.statusLine, "Another device is using PC")
        facts.pairingInFlight = [pc.id]
        XCTAssertEqual(try onlyRow(facts).actions.map(\.enabled), [false, false], "nothing runs while a pairing is in flight")
    }

    func testANeverPairedHostOffersPairNow() throws {
        let row = try onlyRow(MoonlightFacts(hosts: [summary(.stale)]))
        XCTAssertEqual(row.actions, [MoonlightActionState(kind: .pair, title: "Pair now", enabled: true)])
        XCTAssertEqual(row.statusLine, "Not paired yet")
        XCTAssertEqual(row.line, "Not paired · 10.0.0.5")
    }

    // MARK: - The app picker

    func testTheAppPickerListsAutoThenEachAppAndNotesWhatAutoStarts() throws {
        var facts = MoonlightFacts(hosts: [summary(.ready)])
        facts.apps = [pc.id: [
            MoonlightApp(id: "1", title: "Desktop", hdrSupported: false),
            MoonlightApp(id: "2", title: "", hdrSupported: false)
        ]]
        let picker = try XCTUnwrap(try onlyRow(facts).app)
        XCTAssertEqual(picker.label, "App")
        XCTAssertEqual(
            picker.options,
            [AppOption(id: "", title: "Auto"), AppOption(id: "1", title: "Desktop"), AppOption(id: "2", title: "2")]
        )
        XCTAssertEqual(picker.selection, "")
        XCTAssertEqual(picker.note, "Without a pick, Dish starts whatever PC lists first.")
        facts.pickedApps = [pc.id: "1"]
        let picked = try XCTUnwrap(try onlyRow(facts).app)
        XCTAssertEqual(picked.selection, "1")
        XCTAssertNil(picked.note)
    }

    func testAHostWhoseProbeListedNoAppsHasNoPicker() {
        XCTAssertNil(appPicker(pc.id, host: "PC", facts: MoonlightFacts(apps: [pc.id: []])))
        XCTAssertNil(appPicker(pc.id, host: "PC", facts: MoonlightFacts()))
    }

    // MARK: - A discovered host

    func testAHostOnlyAScanKnowsIsNotPairedAndHasNothingToForget() throws {
        var facts = MoonlightFacts(discovered: [pc])
        let row = try onlyRow(facts)
        XCTAssertEqual(row.line, "Not paired · 10.0.0.5")
        XCTAssertEqual(row.dot, DishTheme.muted)
        XCTAssertEqual(row.actions, [MoonlightActionState(kind: .pair, title: "Pair now", enabled: true)])
        XCTAssertNil(row.menu)
        facts.pairingInFlight = [pc.id]
        XCTAssertEqual(try onlyRow(facts).actions, [MoonlightActionState(kind: .pair, title: "Pairing", enabled: false)])
    }

    // MARK: - The PIN card

    func testThePinShowsInTheRowOfTheHostThatMintedIt() throws {
        let prompt = MoonlightPinPrompt(host: pc, pin: "0451")
        let row = try onlyRow(MoonlightFacts(hosts: [summary(.stale)], pin: prompt))
        XCTAssertEqual(row.pin, MoonlightPinCardState(
            title: "Pair with PC",
            cells: ["0", "4", "5", "1"],
            prompt: "Type 0451 into the Moonlight or Sunshine page on PC.",
            waiting: "Waiting for the host to accept the PIN",
            cancel: "Cancel",
            newCode: "New code"
        ))
        XCTAssertEqual(try onlyRow(MoonlightFacts(discovered: [pc], pin: prompt)).pin?.cells, ["0", "4", "5", "1"])
        XCTAssertNil(pinCard(on: "moonlight:other", prompt), "another host's row shows no card")
    }

    // MARK: - The page

    func testThePageIsTitledScansAndListsUnderFound() {
        let state = moonlightHostsPageState(MoonlightFacts(), draft: "")
        XCTAssertEqual(state.title, "Moonlight hosts")
        XCTAssertEqual(state.scan, "Scan")
        XCTAssertEqual(state.hosts.title, "Found on your Wi‑Fi")
        XCTAssertNil(state.notice, "nothing said since the page opened")
    }

    func testTheLastWordAHostSaidIsTheNoticeWithItsWayOut() throws {
        let busy = moonlightHostsPageState(MoonlightFacts(lastEvent: .appAlreadyRunning(host: pc, resumable: false)), draft: "")
        let notice = try XCTUnwrap(busy.notice)
        XCTAssertEqual(notice.title, "Another device is using PC")
        XCTAssertEqual(notice.symbol, "exclamationmark.triangle")
        XCTAssertEqual(notice.tint, DishTheme.warning)
        XCTAssertEqual(notice.quit, MoonlightQuitAction(title: "Close the app on PC", hostId: pc.id))
        let paired = try XCTUnwrap(moonlightHostsPageState(MoonlightFacts(lastEvent: .paired(pc)), draft: "").notice)
        XCTAssertEqual(paired.symbol, "checkmark.circle")
        XCTAssertEqual(paired.tint, DishTheme.success)
        XCTAssertNil(paired.quit)
        let unanswered = try XCTUnwrap(moonlightHostsPageState(MoonlightFacts(lastEvent: .noHostAnswered(address: "10.0.0.9")), draft: "")
            .notice)
        XCTAssertEqual(unanswered.symbol, "xmark.octagon")
        XCTAssertEqual(unanswered.tint, DishTheme.error)
        let ended = try XCTUnwrap(moonlightHostsPageState(MoonlightFacts(lastEvent: .endedByHost(pc)), draft: "").notice)
        XCTAssertEqual(ended.symbol, "info.circle")
        XCTAssertNil(
            moonlightHostsPageState(MoonlightFacts(lastEvent: .pairingPinReady(host: pc, pin: "0451")), draft: "").notice,
            "the PIN is its row's card, not a notice"
        )
    }

    func testTheAddFormTakesAnAddressOnceSomethingIsTyped() {
        let empty = moonlightHostsPageState(MoonlightFacts(), draft: "").add
        XCTAssertEqual(empty, MoonlightAddHostState(
            heading: "Add a host by address",
            message: "Enter the host IP address or hostname. Dish uses the standard Moonlight ports.",
            placeholder: "Host IP or name",
            add: "Add",
            canAdd: false
        ))
        XCTAssertFalse(moonlightAddHostState(draft: "   ").canAdd, "blank once trimmed")
        XCTAssertTrue(moonlightAddHostState(draft: "pc.local").canAdd)
        XCTAssertTrue(moonlightAddHostState(draft: " 10.0.0.9 ").canAdd)
    }
}
