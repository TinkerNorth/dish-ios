// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// C5, the low-power dim: its words, the clock from the shell's facts, and
/// the session card the accessory's own line fills.
final class DimMappersTests: XCTestCase {

    private let living = DestinationFact(name: "Living Room PC", health: .online)

    func testTheDimWordsItsEyebrowItsWakeAndItsFootnote() {
        let state = dimCoverState(facts: FactsFixture.shell())
        XCTAssertEqual(state.eyebrow, "Low power")
        XCTAssertEqual(state.wake, "Tap to wake")
        XCTAssertEqual(state.footnote, "Streaming continues while dimmed. Keep Dish open: iOS pauses apps you leave.")
    }

    func testTheClockIsTheShellsNowInHoursAndMinutes() {
        let state = dimCoverState(facts: FactsFixture.shell())
        XCTAssertEqual(state.clock, FactsFixture.now.formatted(date: .omitted, time: .shortened))
        XCTAssertFalse(state.clock.isEmpty)
    }

    func testWithNoSessionThereIsNoCard() {
        XCTAssertNil(dimCoverState(facts: FactsFixture.shell()).card)
    }

    func testTheCardCarriesTheAccessorysLine() {
        let card = dimCoverState(facts: FactsFixture.shell(session: FactsFixture.streaming())).card
        XCTAssertEqual(card?.pcName, "Living Room PC")
        XCTAssertEqual(card?.line, "Streaming · 3 pads · 4 ms")
        XCTAssertEqual(card?.dot, DishTheme.success)
        XCTAssertEqual(card?.lineColor, DishTheme.dimText)
    }

    func testAStoppedSessionTurnsTheCardToTheError() {
        let card = dimCoverState(facts: FactsFixture.shell(session: FactsFixture.stopped)).card
        XCTAssertEqual(card?.line, "Stopped responding")
        XCTAssertEqual(card?.dot, DishTheme.error)
        XCTAssertEqual(card?.lineColor, DishTheme.error)
    }

    func testTheCardListsTheBoundControllersThatReportALevel() {
        let controllers = [
            ControllerFact(id: "ds", name: "DualSense", link: .usbC, batteryPercent: 84, destination: living),
            ControllerFact(id: "xbox", name: "Xbox Wireless", link: .bluetooth, batteryPercent: 41, destination: living),
            ControllerFact(id: "loose", name: "Loose pad", link: .bluetooth, batteryPercent: 90, destination: nil),
            ControllerFact(id: "on-screen", name: "", link: .onScreen, batteryPercent: nil, destination: living)
        ]
        let card = dimCoverState(facts: FactsFixture.shell(controllers: controllers, session: FactsFixture.streaming())).card
        XCTAssertEqual(card?.pads, [
            DimPadRow(id: "ds", name: "DualSense", battery: "84%"),
            DimPadRow(id: "xbox", name: "Xbox Wireless", battery: "41%")
        ])
    }
}
