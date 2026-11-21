// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The facts the shell draws, each slice from the stores it needs and no
/// other, so a page that reads one re-renders for that slice alone; the
/// whole is for the pages that read across them.
package extension AppModel {

    var controllersFacts: ControllersFacts {
        ControllersFacts(
            controllers: controllerFacts,
            attachedPads: attachedPadFacts,
            apply: applyFact,
            deadzones: pads.deadzones.state,
            port: devicePort
        )
    }

    var connectionsFacts: ConnectionsFacts {
        ConnectionsFacts(
            paired: pairedFacts,
            found: foundFacts,
            scanning: network.wifi.isScanning,
            localNetwork: localNetwork.status,
            now: clock.state,
            addedByAddress: addedByAddressFact
        )
    }

    var sessionFacts: SessionFacts {
        SessionFacts(session: sessionFact, lowPower: lowPower.state)
    }

    var preferencesFacts: PreferencesFacts {
        let streaming = streaming.state
        return PreferencesFacts(
            deviceName: device.state,
            keepScreenOn: streaming.keepScreenOn,
            dimAfter: streaming.dimAfter,
            appearance: appearance.state
        )
    }

    /// The global switches above every pad's own.
    var forwardingFacts: ForwardingFlags {
        pads.features.flags
    }

    /// Where Steam Controllers over Bluetooth stand.
    var steamBluetoothFacts: SteamBluetoothStatus {
        steamBluetoothStatus(enabled: pads.steamSetting.enabled, radio: pads.steam.radio)
    }

    var supportFacts: SupportFacts {
        supportSource.state
    }

    var diagnosticsFacts: DiagnosticsFacts {
        DiagnosticsFacts(snapshot: diagnostics.state, events: diagnosticsLog.state)
    }

    var shellFacts: ShellFacts {
        ShellFacts(
            controllers: controllersFacts,
            connections: connectionsFacts,
            session: sessionFacts,
            preferences: preferencesFacts,
            setup: setup,
            support: supportFacts,
            play: playFacts,
            diagnostics: diagnosticsFacts,
            forwarding: forwardingFacts,
            steamBluetooth: steamBluetoothFacts,
            controllerDb: controllerDbFacts
        )
    }
}
