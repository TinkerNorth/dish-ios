// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation

/// The pages of the setup cover, in walking order. The primer and Pick your
/// PC are both the Destination step; the primer stands in while iOS has not
/// been asked about the Local Network.
public enum SetupStep: Equatable, Sendable {
    case welcome
    case input
    case localNetworkPrimer
    case pickPC
    case review
}

/// Where a walk opens: the welcome on a first run or the guide, Input for
/// "Add a controller".
public enum SetupStart: Equatable, Sendable {
    case welcome
    case input
}

/// The pad a binding emulates on the PC.
public enum EmulatedPad: CaseIterable, Hashable, Sendable {
    case dualSense
    case dualShock4
    case xboxWireless
    case switchPro
    /// The DualSense with the four paddles the extended-buttons word carries
    /// (protocol 4).
    case dualSenseEdge

    /// The pad carries motion, so the Motion switch means something.
    public var hasMotion: Bool {
        switch self {
        case .dualSense, .dualShock4, .switchPro, .dualSenseEdge: true
        case .xboxWireless: false
        }
    }
}

/// What the person plays with: a pad iOS already sees (with the family it
/// belongs to), or one of the three ways in.
public enum InputKind: Equatable, Sendable {
    case detectedPad(id: String, family: EmulatedPad)
    case wired
    case bluetooth
    case onScreen

    /// The pad a fresh binding emulates: a seen pad its own family, anything
    /// else an Xbox Wireless, which every game reads.
    public var defaultEmulation: EmulatedPad {
        switch self {
        case let .detectedPad(_, family): family
        case .wired, .bluetooth, .onScreen: .xboxWireless
        }
    }
}

/// Where the input goes: a Satellite or a Moonlight host Dish found, or a PC
/// added by its address.
public enum DestinationPick: Equatable, Sendable {
    case satellite(id: String)
    case moonlightHost(id: String)
    case byAddress
}

/// Every answer of the walk; nothing reaches the PC until Bind.
public struct SetupDraft: Equatable, Sendable {
    public internal(set) var input: InputKind?
    public internal(set) var destination: DestinationPick?
    public internal(set) var emulateAs: EmulatedPad
    /// Motion is sent; never on for a pad without it.
    public internal(set) var motion: Bool

    public init(
        input: InputKind? = nil,
        destination: DestinationPick? = nil,
        emulateAs: EmulatedPad = .xboxWireless,
        motion: Bool = false
    ) {
        self.input = input
        self.destination = destination
        self.emulateAs = emulateAs
        self.motion = motion
    }
}

/// How a walk came to its end: a binding was asked for, or Skip.
public enum SetupEnding: Equatable, Sendable {
    case bound
    case skipped
}

public enum SetupEvent: Equatable, Sendable {
    /// Open a fresh walk, dropping any answers.
    case begin(at: SetupStart)
    /// The page's Continue.
    case next
    case back
    case skip
    case pickInput(InputKind)
    /// iOS answered the Local Network question.
    case localNetworkAnswered(allowed: Bool)
    case pickDestination(DestinationPick)
    case setEmulateAs(EmulatedPad)
    case setMotion(Bool)
    case bind
}

/// What the walk asks of the engine, as data.
public enum SetupEffect: Equatable, Sendable {
    /// Let iOS put its Local Network question.
    case askLocalNetwork
    /// Look for PCs on the Wi‑Fi.
    case scan
    /// The one write: bind the draft.
    case bind(SetupDraft)
    case ended(SetupEnding)
}

public struct SetupState: Equatable, Sendable {
    public internal(set) var step: SetupStep
    public internal(set) var draft: SetupDraft
    /// The page the walk opened on, which decides whether Input has a Back.
    public let start: SetupStart

    public init(start: SetupStart) {
        self.start = start
        draft = SetupDraft()
        switch start {
        case .welcome: step = .welcome
        case .input: step = .input
        }
    }

    /// The step the subtitle counts, 1 to 3; nil on the welcome.
    public var stepNumber: Int? {
        switch step {
        case .welcome: nil
        case .input: 1
        case .localNetworkPrimer, .pickPC: 2
        case .review: 3
        }
    }

    /// The page has a way back: not the welcome, and not Input when the walk
    /// opened there.
    public var canGoBack: Bool {
        switch step {
        case .welcome: false
        case .input: start == .welcome
        case .localNetworkPrimer, .pickPC, .review: true
        }
    }
}
