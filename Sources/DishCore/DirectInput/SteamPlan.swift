// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// What Dish writes to a Steam Controller on Bluetooth as it reads it, ported
// from dish-mac's `SteamPlan.swift`: the 2015 pad is quieted when Dish starts
// and restored when it stops (its settings persist until it reboots, so a
// release that skipped the restore would strand a mute pad); the 2026 pad
// gets lizard mode off and its IMU on, lizard mode again every few seconds,
// and only a motor stop on release, since its firmware's watchdog turns
// lizard mode back on by itself.

import Foundation

package enum SteamGeneration: Equatable {
    /// The 2015 pad over Bluetooth LE: its packets in segments of report 3.
    case originalOverBluetooth
    /// The 2026 pad: numbered reports, its settings on feature report 1.
    case triton
}

/// One report Dish writes to the pad.
package struct SteamWrite: Equatable {
    package enum Kind: Equatable {
        case feature
        case output
    }

    package let kind: Kind
    package let reportId: UInt8
    /// The report as SDL's drivers hand it to hidapi: its id first.
    package let bytes: [UInt8]

    package init(kind: Kind, reportId: UInt8, bytes: [UInt8]) {
        self.kind = kind
        self.reportId = reportId
        self.bytes = bytes
    }
}

package struct SteamPlan: Equatable {
    package let generation: SteamGeneration

    package init(generation: SteamGeneration) {
        self.generation = generation
    }

    /// Dish starts reading the pad.
    package var onClaim: [SteamWrite] {
        switch generation {
        case .originalOverBluetooth: features(steamBleConfigReports(.quiet))
        case .triton: features([tritonLizardOffReport(), tritonSensorsOnReport()])
        }
    }

    /// Dish stops reading: the pad is given back as it came.
    package var onRelease: [SteamWrite] {
        switch generation {
        case .originalOverBluetooth: features(steamBleConfigReports(.restore))
        case .triton: [SteamWrite(kind: .output, reportId: TritonReportId.hapticRumble, bytes: tritonRumbleReport(left: 0, right: 0))]
        }
    }

    /// Sent every `TritonRumbleRule.lizardRefreshMs` while the pad is read.
    package var refresh: [SteamWrite] {
        switch generation {
        case .originalOverBluetooth: []
        case .triton: features([tritonLizardOffReport()])
        }
    }

    package var refreshesLizardMode: Bool {
        generation == .triton
    }

    /// The 2026 pad has rumble motors; the 2015 pad has none.
    package var rumbles: Bool {
        generation == .triton
    }

    private func features(_ reports: [[UInt8]]) -> [SteamWrite] {
        reports.map { SteamWrite(kind: .feature, reportId: featureReportId, bytes: $0) }
    }

    private var featureReportId: UInt8 {
        switch generation {
        case .originalOverBluetooth: SteamBleLayout.reportId
        case .triton: TritonReportId.controllerFeature
        }
    }
}
