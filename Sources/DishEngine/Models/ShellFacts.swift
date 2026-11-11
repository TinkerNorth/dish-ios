// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// Everything the shell draws from, in one value: the app's mappers word
/// it, the engine never does.
package struct ShellFacts: Equatable {
    package let controllers: [ControllerFact]
    /// The pads attached to this iPhone right now, bound or not; setup
    /// offers them first. Empty until the controller bridge lands.
    package let attachedPads: [AttachedPadFact]
    package let paired: [ConnectionFact]
    package let found: [ConnectionFact]
    /// Whether discovery is looking right now.
    package let scanning: Bool
    /// Nil while nothing streams.
    package let session: SessionFact?
    package let localNetwork: LocalNetworkStatus
    package let preferences: PreferencesFacts
    /// The wall clock, moving once a minute while a page that words a time
    /// is on screen.
    package let now: Date
    /// The setup walk on screen; nil while the cover is down.
    package let setup: SetupState?
    /// Support Dish: what the App Store sells and where a tip stands.
    package let support: SupportFacts
    /// The play screen on display; nil while none is.
    package let play: PlayFacts?
    /// What the Diagnostics page reads, re-read while it shows.
    package let diagnostics: DiagnosticsSnapshot
    /// The flight recorder's lines, oldest first.
    package let diagnosticsEvents: [DiagnosticsEvent]
    /// The bind in flight or just ended; nil while there is none.
    package let apply: ApplyFact?
    /// The PC added by its address this run, by id; nil until one is.
    package let addedByAddress: String?
    /// The dead zones of each pad tuned; a pad with no entry reads the defaults.
    package let deadzones: [String: DeadzoneSetting]
    /// The global switches above every pad's own.
    package let forwarding: ForwardingFlags

    package init(
        controllers: [ControllerFact],
        attachedPads: [AttachedPadFact],
        paired: [ConnectionFact],
        found: [ConnectionFact],
        scanning: Bool,
        session: SessionFact?,
        localNetwork: LocalNetworkStatus,
        preferences: PreferencesFacts,
        now: Date,
        setup: SetupState?,
        support: SupportFacts = .initial,
        play: PlayFacts? = nil,
        diagnostics: DiagnosticsSnapshot = DiagnosticsSnapshot(),
        diagnosticsEvents: [DiagnosticsEvent] = [],
        apply: ApplyFact? = nil,
        addedByAddress: String? = nil,
        deadzones: [String: DeadzoneSetting] = [:],
        forwarding: ForwardingFlags = ForwardingFlags()
    ) {
        self.controllers = controllers
        self.attachedPads = attachedPads
        self.paired = paired
        self.found = found
        self.scanning = scanning
        self.session = session
        self.localNetwork = localNetwork
        self.preferences = preferences
        self.now = now
        self.setup = setup
        self.support = support
        self.play = play
        self.diagnostics = diagnostics
        self.diagnosticsEvents = diagnosticsEvents
        self.apply = apply
        self.addedByAddress = addedByAddress
        self.deadzones = deadzones
        self.forwarding = forwarding
    }
}
