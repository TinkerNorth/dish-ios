// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import Dish

final class SetupDestinationMappersTests: XCTestCase {

    func testNothingHeardAndNotLookingSaysNothingWasFoundYet() {
        let state = pickPCStepState(SetupFixture.inputs())
        XCTAssertEqual(state.title, "Pick your PC")
        XCTAssertEqual(state.body, "PCs running Satellite on this Wi‑Fi show up here.")
        XCTAssertEqual(state.satellite.title, "Satellite")
        XCTAssertEqual(state.satellite.chip, ChipState(text: "Fastest", tone: .success))
        XCTAssertNil(state.satellite.searching)
        XCTAssertEqual(state.satellite.list, .nothingYet("No PCs found yet."))
    }

    func testWhileLookingTheSectionSaysSearching() {
        let state = pickPCStepState(SetupFixture.inputs(scanning: true))
        XCTAssertEqual(state.satellite.searching, "Searching")
        XCTAssertEqual(state.satellite.list, .nothingYet("No PCs found yet."))
    }

    func testFoundSatellitesAreRowsWithTheirPairingAndAddress() {
        let inputs = SetupFixture.inputs(found: [SetupFixture.livingRoom, SetupFixture.office, SetupFixture.den], scanning: true)
        let state = pickPCStepState(inputs)
        XCTAssertEqual(state.satellite.list, .rows([
            SetupPCRow(
                id: "lr",
                symbol: "desktopcomputer",
                name: "Living Room PC",
                detail: "Needs pairing · 192.168.1.24",
                dot: DishTheme.warning,
                pick: .satellite(id: "lr"),
                pairServerId: "lr"
            ),
            SetupPCRow(
                id: "office",
                symbol: "desktopcomputer",
                name: "Office PC",
                detail: "Paired · 192.168.1.31",
                dot: DishTheme.success,
                pick: .satellite(id: "office"),
                pairServerId: nil
            )
        ]))
    }

    func testFoundMoonlightHostsSitUnderTheMoonlightRow() {
        let state = pickPCStepState(SetupFixture.inputs(found: [SetupFixture.livingRoom, SetupFixture.den]))
        XCTAssertEqual(state.moonlight.title, "Use a Moonlight host")
        XCTAssertEqual(state.moonlight.symbol, "display")
        XCTAssertEqual(state.moonlight.hosts.map(\.symbol), ["display"])
        XCTAssertEqual(state.moonlight.chip, ChipState(text: "Fast", tone: .primary))
        XCTAssertEqual(state.moonlight.body, "Sunshine, Apollo or Wolf. No Satellite needed.")
        XCTAssertEqual(state.moonlight.hosts.map(\.pick), [.moonlightHost(id: "den")])
        XCTAssertEqual(state.moonlight.hosts.map(\.detail), ["Needs pairing · 192.168.1.40"])
        XCTAssertEqual(state.moonlight.hosts.map(\.pairServerId), [nil], "a Moonlight host pairs its own way")
    }

    func testNoMoonlightHostHeardLeavesTheRowAlone() {
        XCTAssertEqual(pickPCStepState(SetupFixture.inputs()).moonlight.hosts, [])
    }

    func testADeniedLocalNetworkShowsTheRefusalInPlaceOfTheListAndStopsSearching() {
        let inputs = SetupFixture.inputs(found: [SetupFixture.livingRoom], scanning: true, localNetwork: .denied)
        let state = pickPCStepState(inputs)
        XCTAssertNil(state.satellite.searching)
        XCTAssertEqual(state.satellite.list, .refused(SetupRefusalState(
            title: "Dish can’t see your network",
            body: "Local Network is off for Dish, so it can’t find Satellite or send input to your PC. "
                + "Turn it on and Dish picks up where it left off.",
            action: "Open Settings",
            path: "Settings › Dish › Local Network"
        )))
    }

    func testAnUnaskedLocalNetworkStillListsWhatWasHeard() {
        let state = pickPCStepState(SetupFixture.inputs(found: [SetupFixture.office], localNetwork: .unknown))
        XCTAssertEqual(state.satellite.list, .rows([
            SetupPCRow(
                id: "office",
                symbol: "desktopcomputer",
                name: "Office PC",
                detail: "Paired · 192.168.1.31",
                dot: DishTheme.success,
                pick: .satellite(id: "office"),
                pairServerId: nil
            )
        ]))
    }

    func testAPCAddedByAddressIsListedByItsAddressBeforeItHasAName() {
        let state = pickPCStepState(SetupFixture.inputs(found: [SetupFixture.typed]))
        XCTAssertEqual(state.satellite.list, .rows([
            SetupPCRow(
                id: "wifi:192.168.1.50:9876",
                symbol: "desktopcomputer",
                name: "192.168.1.50",
                detail: "Needs pairing · 192.168.1.50",
                dot: DishTheme.warning,
                pick: .satellite(id: "wifi:192.168.1.50:9876"),
                pairServerId: "wifi:192.168.1.50:9876"
            )
        ]))
    }

    func testTheOtherWaysToAPCAndTheFootnote() {
        let state = pickPCStepState(SetupFixture.inputs())
        XCTAssertEqual(state.byAddress, "Add a PC by address")
        XCTAssertEqual(state.getSatellite.title, "Get Satellite for your PC")
        XCTAssertEqual(state.getSatellite.url, DishLinks.satellite)
        XCTAssertEqual(state.footnote, "Don’t see your PC? Start Satellite on it and check that both are on the same Wi‑Fi.")
    }
}
