// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The Controllers tab's facts and its pages': the pads, the bind in
/// flight, each pad's dead zones and the device's port.
package struct ControllersFacts: Equatable {
    package let controllers: [ControllerFact]
    /// The pads attached to this iPhone right now, bound or not; setup
    /// offers them first.
    package let attachedPads: [AttachedPadFact]
    /// The bind in flight or just ended; nil while there is none.
    package let apply: ApplyFact?
    /// The dead zones of each pad tuned; a pad with no entry reads the defaults.
    package let deadzones: [String: DeadzoneSetting]
    /// The port this device hosts a wired pad through, read by the scene.
    package let port: DevicePort

    package init(
        controllers: [ControllerFact],
        attachedPads: [AttachedPadFact] = [],
        apply: ApplyFact? = nil,
        deadzones: [String: DeadzoneSetting] = [:],
        port: DevicePort = .usbC
    ) {
        self.controllers = controllers
        self.attachedPads = attachedPads
        self.apply = apply
        self.deadzones = deadzones
        self.port = port
    }
}

/// The Connections tab's facts and its pages': the PCs, the scan, the
/// Local Network status, the clock that words a last sighting, and the PC
/// typed by its address.
package struct ConnectionsFacts: Equatable {
    package let paired: [ConnectionFact]
    package let found: [ConnectionFact]
    /// Whether discovery is looking right now.
    package let scanning: Bool
    package let localNetwork: LocalNetworkStatus
    /// The wall clock, moving once a minute while a page that words a time
    /// is on screen.
    package let now: Date
    /// The PC added by its address this run; nil until one is.
    package let addedByAddress: AddedByAddressFact?

    package init(
        paired: [ConnectionFact] = [],
        found: [ConnectionFact] = [],
        scanning: Bool = false,
        localNetwork: LocalNetworkStatus = .unknown,
        now: Date,
        addedByAddress: AddedByAddressFact? = nil
    ) {
        self.paired = paired
        self.found = found
        self.scanning = scanning
        self.localNetwork = localNetwork
        self.now = now
        self.addedByAddress = addedByAddress
    }
}

/// The session accessory's facts: the link on every tab and the low-power
/// countdown.
package struct SessionFacts: Equatable {
    /// Nil while nothing streams and nothing is being brought back.
    package let session: SessionFact?
    package let lowPower: LowPowerFact

    package init(session: SessionFact? = nil, lowPower: LowPowerFact = .idle) {
        self.session = session
        self.lowPower = lowPower
    }
}

/// Diagnostics' facts: the snapshot re-read while a page shows, and the
/// flight recorder's lines, oldest first.
package struct DiagnosticsFacts: Equatable {
    package let snapshot: DiagnosticsSnapshot
    package let events: [DiagnosticsEvent]

    package init(snapshot: DiagnosticsSnapshot = DiagnosticsSnapshot(), events: [DiagnosticsEvent] = []) {
        self.snapshot = snapshot
        self.events = events
    }
}

/// Everything the shell draws from, in one value, for the pages that read
/// across the slices; a page reads the slice it maps. The app's mappers
/// word it, the engine never does.
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
    /// The PC added by its address this run; nil until one is.
    package let addedByAddress: AddedByAddressFact?
    /// The dead zones of each pad tuned; a pad with no entry reads the defaults.
    package let deadzones: [String: DeadzoneSetting]
    /// The global switches above every pad's own.
    package let forwarding: ForwardingFlags
    /// The port this device hosts a wired pad through, read by the scene.
    package let port: DevicePort
    /// The low-power countdown while a session streams.
    package let lowPower: LowPowerFact
    /// Where Steam Controllers over Bluetooth stand.
    package let steamBluetooth: SteamBluetoothStatus

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
        addedByAddress: AddedByAddressFact? = nil,
        deadzones: [String: DeadzoneSetting] = [:],
        forwarding: ForwardingFlags = ForwardingFlags(),
        port: DevicePort = .usbC,
        lowPower: LowPowerFact = .idle,
        steamBluetooth: SteamBluetoothStatus = .off
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
        self.steamBluetooth = steamBluetooth
        self.port = port
        self.lowPower = lowPower
    }

    /// The whole from its slices.
    package init(
        controllers: ControllersFacts,
        connections: ConnectionsFacts,
        session: SessionFacts,
        preferences: PreferencesFacts,
        setup: SetupState?,
        support: SupportFacts,
        play: PlayFacts?,
        diagnostics: DiagnosticsFacts,
        forwarding: ForwardingFlags,
        steamBluetooth: SteamBluetoothStatus = .off
    ) {
        self.init(
            controllers: controllers.controllers,
            attachedPads: controllers.attachedPads,
            paired: connections.paired,
            found: connections.found,
            scanning: connections.scanning,
            session: session.session,
            localNetwork: connections.localNetwork,
            preferences: preferences,
            now: connections.now,
            setup: setup,
            support: support,
            play: play,
            diagnostics: diagnostics.snapshot,
            diagnosticsEvents: diagnostics.events,
            apply: controllers.apply,
            addedByAddress: connections.addedByAddress,
            deadzones: controllers.deadzones,
            forwarding: forwarding,
            port: controllers.port,
            lowPower: session.lowPower,
            steamBluetooth: steamBluetooth
        )
    }

    package var controllersFacts: ControllersFacts {
        ControllersFacts(controllers: controllers, attachedPads: attachedPads, apply: apply, deadzones: deadzones, port: port)
    }

    package var connectionsFacts: ConnectionsFacts {
        ConnectionsFacts(
            paired: paired,
            found: found,
            scanning: scanning,
            localNetwork: localNetwork,
            now: now,
            addedByAddress: addedByAddress
        )
    }

    package var sessionFacts: SessionFacts {
        SessionFacts(session: session, lowPower: lowPower)
    }

    package var diagnosticsFacts: DiagnosticsFacts {
        DiagnosticsFacts(snapshot: diagnostics, events: diagnosticsEvents)
    }
}
