// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import Foundation

/// What the play and dim previews are drawn over: the boards' session and
/// pads. Previews only.
enum FactsPreview {
    static let session = SessionFact(pcName: "Living Room PC", pads: 3, latencyMs: 4, phase: .streaming)

    static let preferences = PreferencesFacts(deviceName: "", keepScreenOn: true, dimAfter: .twentySeconds, appearance: .system)

    static let living = DestinationFact(name: "Living Room PC", health: .online)

    static let controllers = [
        ControllerFact(id: "ds", name: "DualSense", link: .usbC, batteryPercent: 84, destination: living),
        ControllerFact(id: "xbox", name: "Xbox Wireless", link: .bluetooth, batteryPercent: 41, destination: living)
    ]

    static func playing(_ screen: PlayScreen, emulateAs: EmulatedPad = .xboxWireless) -> ShellFacts {
        let play = PlayFacts(screen: screen, emulateAs: emulateAs, rumble: true, motion: true, motionAvailability: .padHasNone)
        return facts(play: play)
    }

    static func facts(play: PlayFacts? = nil, session: SessionFact? = FactsPreview.session) -> ShellFacts {
        ShellFacts(
            controllers: controllers,
            attachedPads: [],
            paired: [],
            found: [],
            scanning: false,
            session: session,
            localNetwork: .allowed,
            preferences: preferences,
            now: Date(timeIntervalSince1970: 1_800_000_000),
            setup: nil,
            play: play
        )
    }
}

extension PlayActions {
    /// Controls that do nothing, for a preview.
    @MainActor static let preview = PlayActions(
        pad: { _ in },
        touch: { _ in },
        open: { _ in },
        setRumble: { _ in },
        setMotion: { _ in },
        setEmulateAs: { _ in },
        stop: {}
    )
}
