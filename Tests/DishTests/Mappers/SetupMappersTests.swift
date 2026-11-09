// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import Dish

/// The pads and PCs the setup pages are shown in these tests.
enum SetupFixture {
    static let dualSense = SetupPadInput(id: "pad-1", name: "DualSense", link: .usbC, batteryPercent: 84, family: .dualSense)
    static let xbox = SetupPadInput(id: "pad-2", name: "Xbox Wireless", link: .bluetooth, batteryPercent: nil, family: .xboxWireless)
    static let livingRoom = SetupPCInput(id: "lr", name: "Living Room PC", address: "192.168.1.24", kind: .satellite, paired: false)
    static let office = SetupPCInput(id: "office", name: "Office PC", address: "192.168.1.31", kind: .satellite, paired: true)
    static let den = SetupPCInput(id: "den", name: "Den PC", address: "192.168.1.40", kind: .moonlightHost, paired: false)

    static func inputs(
        pads: [SetupPadInput] = [],
        found: [SetupPCInput] = [],
        scanning: Bool = false,
        localNetwork: LocalNetworkStatus = .allowed
    ) -> SetupInputs {
        SetupInputs(detectedPads: pads, found: found, scanning: scanning, localNetwork: localNetwork)
    }

    static func walk(_ start: SetupStart, _ events: [SetupEvent], localNetwork: LocalNetworkStatus = .allowed) -> SetupState {
        events.reduce(SetupState(start: start)) { reduceSetup($0, $1, localNetwork: localNetwork).state }
    }
}

final class SetupMappersTests: XCTestCase {

    // MARK: - Inputs

    func testThisWaveSeesNoPadsAndHearsNoPCs() {
        let inputs = setupInputs(localNetwork: .unknown)
        XCTAssertEqual(inputs, SetupInputs(detectedPads: [], found: [], scanning: false, localNetwork: .unknown))
    }

    func testTheEntriesOpenTheWalkWhereTheBoardsDo() {
        XCTAssertEqual(setupStart(.firstRun), .welcome)
        XCTAssertEqual(setupStart(.guide), .welcome)
        XCTAssertEqual(setupStart(.addController), .input)
    }

    // MARK: - Chrome

    func testTheWelcomeHasNoTitleNoStepAndNoBackButSkips() {
        let chrome = setupChromeState(SetupState(start: .welcome))
        XCTAssertEqual(chrome, SetupChromeState(title: nil, subtitle: nil, showsBack: false, back: "Back", skip: "Skip"))
    }

    func testInputCountsOneOfThreeWithBackToTheWelcome() {
        let chrome = setupChromeState(SetupFixture.walk(.welcome, [.next]))
        XCTAssertEqual(chrome.title, "Set up Dish")
        XCTAssertEqual(chrome.subtitle, "Input · 1 of 3")
        XCTAssertTrue(chrome.showsBack)
    }

    func testInputOpenedByAddAControllerHasNoBack() {
        let chrome = setupChromeState(SetupState(start: .input))
        XCTAssertEqual(chrome.subtitle, "Input · 1 of 3")
        XCTAssertFalse(chrome.showsBack)
    }

    func testBothDestinationPagesCountTwoOfThree() {
        let primer = SetupFixture.walk(.input, [.pickInput(.wired)], localNetwork: .unknown)
        let pickPC = SetupFixture.walk(.input, [.pickInput(.wired)], localNetwork: .allowed)
        XCTAssertEqual(setupChromeState(primer).subtitle, "Destination · 2 of 3")
        XCTAssertEqual(setupChromeState(pickPC).subtitle, "Destination · 2 of 3")
        XCTAssertTrue(setupChromeState(pickPC).showsBack)
    }

    func testReviewCountsThreeOfThree() {
        let review = SetupFixture.walk(.input, [.pickInput(.wired), .pickDestination(.byAddress)])
        XCTAssertEqual(setupChromeState(review).subtitle, "Binding · 3 of 3")
    }

    // MARK: - Welcome

    func testTheWelcomeSaysWhatDishIsWithThreeFeaturesAndTheDownload() {
        let state = welcomeStepState()
        XCTAssertEqual(state.headline, "Turn your iPhone into a wireless PC gamepad")
        XCTAssertEqual(state.intro, "Dish pairs with Satellite on your PC and sends every press over your own Wi‑Fi.")
        XCTAssertEqual(state.features.map(\.symbol), ["gamecontroller", "iphone", "lock.shield"])
        XCTAssertEqual(state.features.map(\.title), ["Bring the controller you own", "Or play on the screen", "Stays on your network"])
        XCTAssertEqual(
            state.features.first?.body,
            "Plug in a wired pad or use one paired to this iPhone. Dish carries it to your PC."
        )
        XCTAssertEqual(state.features.last?.body, "Encrypted and LAN-only. No account, no tracking.")
        XCTAssertEqual(state.primary, "Continue")
        XCTAssertEqual(state.getSatellite.title, "Get Satellite for your PC")
        XCTAssertEqual(state.getSatellite.url?.absoluteString, "https://dish.tinkernorth.com/downloads/satellite")
    }

    // MARK: - Input

    func testWithNoPadSeenTheFoundSectionIsLeftOut() {
        let state = inputStepState(SetupFixture.inputs())
        XCTAssertNil(state.found)
        XCTAssertEqual(state.title, "How do you want to play?")
        XCTAssertEqual(state.body, "Pick an input. Each sets up a little differently.")
    }

    func testTheThreeWaysInWithBestOnWired() {
        let state = inputStepState(SetupFixture.inputs())
        XCTAssertEqual(state.chooseTitle, "Or choose")
        XCTAssertEqual(state.choices.map(\.pick), [.wired, .bluetooth, .onScreen])
        XCTAssertEqual(state.choices.map(\.title), ["Wired controller", "Bluetooth controller", "On-screen gamepad"])
        XCTAssertEqual(state.choices.map(\.body), [
            "Plugged into your iPhone’s USB-C port. Lowest latency.",
            "A pad paired to this iPhone in Settings › Bluetooth.",
            "Touch buttons on the glass."
        ])
        XCTAssertEqual(state.choices.map(\.chip), [ChipState(text: "Best", tone: .success), nil, nil])
        XCTAssertEqual(
            state.footnote,
            "Dish reads any controller iOS supports: DualSense, DualShock 4, Xbox Wireless and Switch Pro."
        )
    }

    func testASeenPadLeadsWithItsLinkAndBatteryAndPicksItself() {
        let state = inputStepState(SetupFixture.inputs(pads: [SetupFixture.dualSense, SetupFixture.xbox]))
        XCTAssertEqual(state.found?.title, "Found on this iPhone")
        XCTAssertEqual(state.found?.pads, [
            SetupPadRow(
                id: "pad-1",
                symbol: "gamecontroller",
                name: "DualSense",
                detail: "Plugged in · USB-C · 84%",
                use: "Use",
                pick: .detectedPad(id: "pad-1", family: .dualSense)
            ),
            SetupPadRow(
                id: "pad-2",
                symbol: "gamecontroller",
                name: "Xbox Wireless",
                detail: "Connected · Bluetooth",
                use: "Use",
                pick: .detectedPad(id: "pad-2", family: .xboxWireless)
            )
        ])
    }

    // MARK: - The Local Network primer

    func testThePrimerExplainsTheQuestionBeforeIOSAsks() {
        let state = localNetworkStepState()
        XCTAssertEqual(state.title, "Let Dish find your PC")
        XCTAssertEqual(
            state.body,
            "Satellite announces itself on your Wi‑Fi. iOS asks before any app looks for devices on your network."
        )
        XCTAssertEqual(state.rows.map(\.title), ["Only this Wi‑Fi", "Nothing pairs without a PIN", "Yours to change later"])
        XCTAssertEqual(state.rows.map(\.body), [
            "Bonjour discovery, the way AirPlay finds a TV.",
            "Satellite shows a 4-digit PIN on your PC.",
            "Settings › Privacy & Security › Local Network"
        ])
        XCTAssertEqual(state.thisIPhone, "This iPhone")
        XCTAssertEqual(state.yourPC, "Your PC")
        XCTAssertEqual(state.primary, "Continue")
        XCTAssertEqual(state.byAddress, "Add my PC by address instead")
    }
}
