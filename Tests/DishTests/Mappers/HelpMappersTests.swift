// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import Dish

/// Help & FAQ: the desktops' sections in their order, reworded for an
/// iPhone, every question with its answer whole, the walk-through and the
/// two links.
final class HelpMappersTests: XCTestCase {

    private let state = helpPageState()

    private var entries: [HelpEntryState] {
        state.sections.flatMap(\.entries)
    }

    private func answer(to question: String) throws -> String {
        try XCTUnwrap(entries.first { $0.question == question }, question).answer
    }

    func testTheSectionsAreTheDesktopsInTheirOrder() {
        XCTAssertEqual(state.title, "Help & FAQ")
        XCTAssertEqual(state.sections.map(\.title), ["CONCEPTS", "BEST PERFORMANCE", "TROUBLESHOOTING", "ABOUT DISH"])
        XCTAssertEqual(state.sections.map(\.entries.count), [4, 3, 6, 3])
        XCTAssertEqual(state.linksTitle, "LINKS")
    }

    func testEveryQuestionHasItsAnswer() {
        XCTAssertEqual(entries.first?.question, "What is Dish?")
        XCTAssertEqual(Set(entries.map(\.question)).count, entries.count, "no question twice")
        XCTAssertFalse(entries.contains { $0.answer.isEmpty })
    }

    func testNoAnswerSpeaksOfADesktop() {
        for entry in entries {
            for desktop in ["tray", "udev", "menu bar", "window", "this PC", "Click"] {
                XCTAssertFalse(entry.answer.contains(desktop), "\(entry.question) says \(desktop)")
            }
        }
    }

    func testControllersPairInBluetoothSettings() throws {
        XCTAssertEqual(
            try answer(to: "How do I connect a controller?"),
            "Pair it with this iPhone in Settings › Bluetooth, or plug it in with a cable. Apps can’t pair Bluetooth devices, "
                + "so Dish leaves that to iOS. Once iOS sees the controller, it appears on the Controllers tab."
        )
    }

    func testTheLocalNetworkIsAskedOnce() throws {
        let network = try answer(to: "Dish can’t see my network.")
        XCTAssertTrue(network.hasPrefix("iOS asks once whether Dish may use the local network"))
        XCTAssertTrue(network.contains("Settings › Privacy & Security › Local Network"))
    }

    func testTheDimIsThereBecauseIOSSuspendsABackgroundedDish() throws {
        let screen = try answer(to: "Why does Dish keep the screen on?")
        XCTAssertTrue(screen.hasPrefix("iOS suspends an app you leave, and a suspended Dish stops forwarding."))
        XCTAssertTrue(screen.contains("dims it instead of locking"))
    }

    func testAnAnswerSplitAcrossKeysReadsAsOneParagraph() throws {
        XCTAssertEqual(
            try answer(to: "What’s the best setup for low latency?"),
            "Put the PC on wired Ethernet and this iPhone on 5 GHz Wi-Fi, both on the same router. Dish sends input as small UDP packets "
                + "over your local network, so a fast LAN keeps the delay tiny."
        )
        let motion = try answer(to: "Motion (gyro aim) isn’t working.")
        XCTAssertTrue(motion.contains("(DualSense, DualShock 4, Switch Pro), and a PlayStation-style controller type on the slot."))
    }

    func testTheWalkThroughAndTheLinks() {
        XCTAssertEqual(state.subline, "How Dish works, and what to try when it doesn’t")
        XCTAssertEqual(state.walkThrough, "Walk me through setup")
        XCTAssertEqual(state.links.map(\.title), ["Privacy policy", "View source on GitHub"])
        XCTAssertEqual(state.links.map(\.url), [DishLinks.privacy, DishLinks.source])
    }
}
