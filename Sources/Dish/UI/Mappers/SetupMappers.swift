// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation
import SwiftUI

// MARK: - What setup reads

/// What the setup pages read beside the walk itself: the pads iOS sees, the
/// PCs discovery heard, whether it is looking, the Local Network answer,
/// and the PC added by address, by id, once there is one. Plain values, so
/// the pages do not depend on the engine's fact types.
struct SetupInputs: Equatable {
    let detectedPads: [SetupPadInput]
    let found: [SetupPCInput]
    let scanning: Bool
    let localNetwork: LocalNetworkStatus
    let addedByAddress: String?

    init(
        detectedPads: [SetupPadInput],
        found: [SetupPCInput],
        scanning: Bool,
        localNetwork: LocalNetworkStatus,
        addedByAddress: String? = nil
    ) {
        self.detectedPads = detectedPads
        self.found = found
        self.scanning = scanning
        self.localNetwork = localNetwork
        self.addedByAddress = addedByAddress
    }
}

/// How a seen pad reaches the iPhone.
enum SetupPadLink: Equatable {
    case usbC
    case bluetooth
}

struct SetupPadInput: Equatable {
    let id: String
    let name: String
    let link: SetupPadLink
    let batteryPercent: Int?
    let family: EmulatedPad
}

enum SetupPCKind: Equatable {
    case satellite
    case moonlightHost
}

struct SetupPCInput: Equatable {
    let id: String
    let name: String
    let address: String
    let kind: SetupPCKind
    let paired: Bool
}

/// What setup reads from the shell's facts: the pads attached right now,
/// the paired PCs first and then the ones a scan heard, whether a scan runs,
/// and the Local Network status.
func setupInputs(facts: ShellFacts) -> SetupInputs {
    let pairedIds = Set(facts.paired.map(\.id))
    let heard = facts.found.filter { !pairedIds.contains($0.id) }
    let paired = facts.paired.map { setupPCInput($0, paired: true) }
    let found = heard.map { setupPCInput($0, paired: false) }
    return SetupInputs(
        detectedPads: facts.attachedPads.map(setupPadInput),
        found: paired + found,
        scanning: facts.scanning,
        localNetwork: facts.localNetwork,
        addedByAddress: facts.addedByAddress
    )
}

func setupPadInput(_ pad: AttachedPadFact) -> SetupPadInput {
    SetupPadInput(id: pad.id, name: pad.name, link: setupPadLink(pad.link), batteryPercent: pad.batteryPercent, family: pad.family)
}

func setupPadLink(_ link: PadLink) -> SetupPadLink {
    switch link {
    case .usbC: .usbC
    case .bluetooth: .bluetooth
    }
}

func setupPCInput(_ connection: ConnectionFact, paired: Bool) -> SetupPCInput {
    SetupPCInput(
        id: connection.id,
        name: connection.name,
        address: connection.address,
        kind: setupPCKind(connection.kind),
        paired: paired
    )
}

/// The Bluetooth rung of the fleet's ladder is Android's own gamepad
/// layer; no PC on iOS is one, so it reads as the client's own wire.
func setupPCKind(_ kind: ConnectionKind) -> SetupPCKind {
    switch kind {
    case .satellite, .bluetooth: .satellite
    case .moonlight: .moonlightHost
    }
}

/// The step on screen, each with the state its view draws.
enum SetupStepState: Equatable {
    case welcome(WelcomeStepState)
    case input(InputStepState)
    case localNetwork(LocalNetworkStepState)
    case pickPC(PickPCStepState)
    case review(ReviewStepState)
}

/// The whole cover: the toolbar's words and the step under it. Nil while no
/// walk is open, so the cover draws nothing.
struct SetupCoverState: Equatable {
    let chrome: SetupChromeState
    let step: SetupStepState
    /// The readable column the steps stand in; nil fills the screen.
    let column: CGFloat?
}

func setupCoverState(facts: ShellFacts, width: SizeClass, words: L10n = .app) -> SetupCoverState? {
    guard let walk = facts.setup else { return nil }
    let inputs = setupInputs(facts: facts)
    return SetupCoverState(
        chrome: setupChromeState(walk, words: words),
        step: setupStepState(walk, inputs, words: words),
        column: setupColumn(width)
    )
}

/// A phone's screen is the column; an iPad's is too wide to read across.
func setupColumn(_ width: SizeClass) -> CGFloat? {
    switch width {
    case .compact: nil
    case .regular: DishSize.setupColumn
    }
}

func setupStepState(_ walk: SetupState, _ inputs: SetupInputs, words: L10n = .app) -> SetupStepState {
    switch walk.step {
    case .welcome: .welcome(welcomeStepState(words: words))
    case .input: .input(inputStepState(inputs, words: words))
    case .localNetworkPrimer: .localNetwork(localNetworkStepState(words: words))
    case .pickPC: .pickPC(pickPCStepState(inputs, words: words))
    case .review: .review(reviewStepState(walk.draft, inputs, words: words))
    }
}

// MARK: - The cover's chrome

/// The toolbar over every step: the title and the step it counts, Back where
/// the walk has one, and Skip. The welcome draws no title.
struct SetupChromeState: Equatable {
    let title: String?
    let subtitle: String?
    let showsBack: Bool
    let back: String
    let skip: String
}

func setupChromeState(_ walk: SetupState, words: L10n = .app) -> SetupChromeState {
    let onWelcome = walk.step == .welcome
    return SetupChromeState(
        title: onWelcome ? nil : words.setUpDish,
        subtitle: setupSubtitle(walk.step, words: words),
        showsBack: walk.canGoBack,
        back: words.setupBack,
        skip: words.setupSkip
    )
}

private func setupSubtitle(_ step: SetupStep, words: L10n) -> String? {
    switch step {
    case .welcome: nil
    case .input: words.setupInputStep
    case .localNetworkPrimer, .pickPC: words.setupDestinationStep
    case .review: words.setupBindingStep
    }
}

// MARK: - Welcome

/// A symbol, a name and the line under it: a welcome feature, a primer row.
struct SetupFeature: Equatable, Identifiable {
    let symbol: String
    let title: String
    let body: String

    var id: String {
        title
    }
}

struct WelcomeStepState: Equatable {
    let headline: String
    let intro: String
    let features: [SetupFeature]
    let primary: String
    let getSatellite: PageLink
}

func welcomeStepState(words: L10n = .app) -> WelcomeStepState {
    WelcomeStepState(
        headline: words.welcomeHeadline,
        intro: words.welcomeIntro,
        features: [
            SetupFeature(symbol: "gamecontroller", title: words.bringTheControllerYouOwn, body: words.bringTheControllerYouOwnBody),
            SetupFeature(symbol: "iphone", title: words.orPlayOnTheScreen, body: words.orPlayOnTheScreenBody),
            SetupFeature(symbol: "lock.shield", title: words.staysOnYourNetwork, body: words.staysOnYourNetworkBody)
        ],
        primary: words.setupContinue,
        getSatellite: PageLink(title: words.getSatelliteForYourPC, url: DishLinks.satellite)
    )
}

// MARK: - Input · 1 of 3

struct ChipState: Equatable {
    let text: String
    let tone: ChipTone
}

/// A pad iOS already sees, with its Use button.
struct SetupPadRow: Equatable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let detail: String
    let use: String
    let pick: InputKind
}

/// One of the three ways in.
struct SetupChoiceRow: Equatable, Identifiable {
    let symbol: String
    let title: String
    let body: String
    let chip: ChipState?
    let pick: InputKind

    var id: String {
        title
    }
}

struct SetupFoundPads: Equatable {
    let title: String
    let pads: [SetupPadRow]
}

struct InputStepState: Equatable {
    let title: String
    let body: String
    /// Nil while iOS sees no pad: the section is left out.
    let found: SetupFoundPads?
    let chooseTitle: String
    let choices: [SetupChoiceRow]
    let footnote: String
}

func inputStepState(_ inputs: SetupInputs, words: L10n = .app) -> InputStepState {
    let pads = inputs.detectedPads.map { setupPadRow($0, words: words) }
    return InputStepState(
        title: words.howDoYouWantToPlay,
        body: words.howDoYouWantToPlayBody,
        found: pads.isEmpty ? nil : SetupFoundPads(title: words.foundOnThisIPhone, pads: pads),
        chooseTitle: words.orChoose,
        choices: [
            SetupChoiceRow(
                symbol: "cable.connector",
                title: words.wiredController,
                body: words.wiredControllerBody,
                chip: ChipState(text: words.setupBest, tone: .success),
                pick: .wired
            ),
            SetupChoiceRow(
                symbol: "antenna.radiowaves.left.and.right",
                title: words.bluetoothController,
                body: words.bluetoothControllerBody,
                chip: nil,
                pick: .bluetooth
            ),
            SetupChoiceRow(symbol: "iphone", title: words.onScreenGamepad, body: words.onScreenGamepadBody, chip: nil, pick: .onScreen)
        ],
        footnote: words.dishReadsAnyController
    )
}

private func setupPadRow(_ pad: SetupPadInput, words: L10n) -> SetupPadRow {
    let state = padState(pad.link, words: words)
    let parts = [state, setupPadLinkWord(pad.link, words: words)] + setupBatteryWord(pad.batteryPercent, words: words)
    return SetupPadRow(
        id: pad.id,
        symbol: "gamecontroller",
        name: pad.name,
        detail: parts.joined(separator: lineSeparator),
        use: words.setupUse,
        pick: .detectedPad(id: pad.id, family: pad.family)
    )
}

private func padState(_ link: SetupPadLink, words: L10n) -> String {
    switch link {
    case .usbC: words.pluggedIn
    case .bluetooth: words.setupConnected
    }
}

func setupPadLinkWord(_ link: SetupPadLink, words: L10n) -> String {
    switch link {
    case .usbC: words.usbC
    case .bluetooth: words.setupBluetooth
    }
}

/// The battery as a line part; nothing when the pad does not report one.
func setupBatteryWord(_ percent: Int?, words: L10n) -> [String] {
    percent.map { [words.setupBattery($0)] } ?? []
}

// MARK: - Destination · 2 of 3: the Local Network primer

struct LocalNetworkStepState: Equatable {
    let thisIPhone: String
    let yourPC: String
    let title: String
    let body: String
    let rows: [SetupFeature]
    let primary: String
    let byAddress: String
}

func localNetworkStepState(words: L10n = .app) -> LocalNetworkStepState {
    LocalNetworkStepState(
        thisIPhone: words.setupThisIPhone,
        yourPC: words.setupYourPC,
        title: words.letDishFindYourPC,
        body: words.letDishFindYourPCBody,
        rows: [
            SetupFeature(symbol: "wifi", title: words.onlyThisWiFi, body: words.onlyThisWiFiBody),
            SetupFeature(symbol: "lock.shield", title: words.nothingPairsWithoutAPIN, body: words.nothingPairsWithoutAPINBody),
            SetupFeature(symbol: "gearshape", title: words.yoursToChangeLater, body: words.yoursToChangeLaterBody)
        ],
        primary: words.setupContinue,
        byAddress: words.addMyPCByAddressInstead
    )
}
