// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// A Steam Controller on Bluetooth LE as SDL's iOS backend reaches it through
// CoreBluetooth (`src/hidapi/ios/hid.m`): a peripheral the system has
// connected whose name starts "Steam", Valve's GATT service
// 100F6C32-1735-4313-B402-38567131E5F3, the 2015 pad's segments on 100F6C33,
// the 2026 pad's report 0x45 on 100F6C7A or 0x47 on 100F6C7C, each value
// without its report id, the feature reports on 100F6C34 and each output
// report on the characteristic 0x35 past its id. The two model rows are
// dish-mac's Bluetooth rows (`DirectModels.swift`).

import Foundation

/// Valve's characteristics are `100F6Cxx-1735-4313-B402-38567131E5F3`.
private func valveUuid(_ short: Int) -> String {
    let hex = String(short, radix: 16, uppercase: true)
    return "100F6C\(hex)-1735-4313-B402-38567131E5F3"
}

package enum SteamBleUuid {
    package static let service = valveUuid(0x32)
    /// Where every feature report is written.
    package static let report = valveUuid(0x34)
    /// SDL's iOS backend retrieves the connected pads by the system's Device
    /// Information service, which every HID-over-GATT device serves.
    package static let deviceInformation = "180A"
    /// An output report's characteristic sits this far past its id.
    static let outputOffset = 0x35

    /// The characteristic an output report is written to.
    package static func output(_ reportId: UInt8) -> String {
        valveUuid(Int(reportId) + outputOffset)
    }
}

/// One of Valve's Bluetooth identities and what Dish reads of it.
package struct SteamBleModel: Equatable {
    package let productId: UInt16
    /// The product's name, never translated.
    package let name: String
    package let generation: SteamGeneration

    package var plan: SteamPlan {
        SteamPlan(generation: generation)
    }

    /// The 2015 pad's right trackpad is its right stick by default; the 2026
    /// pad has two trackpads beside a real right stick.
    package var trackpads: SteamTrackpads {
        switch generation {
        case .originalOverBluetooth: .rightStickByDefault
        case .triton: .twoPads
        }
    }
}

package enum SteamBleModels {
    package static let original = SteamBleModel(
        productId: 0x1106,
        name: "Valve Steam Controller (Bluetooth)",
        generation: .originalOverBluetooth
    )
    package static let triton = SteamBleModel(productId: 0x1303, name: "Valve Steam Controller (2026, Bluetooth)", generation: .triton)
}

/// An input characteristic of Valve's service, the report id SDL's iOS
/// backend puts back in front of each of its values, and the model that
/// reports on it.
package struct SteamBleInput: Equatable {
    package let characteristic: String
    package let reportId: UInt8
    package let model: SteamBleModel
}

package let steamBleInputs = [
    SteamBleInput(characteristic: valveUuid(0x33), reportId: SteamBleLayout.reportId, model: SteamBleModels.original),
    SteamBleInput(characteristic: valveUuid(0x7A), reportId: TritonReportId.stateBle, model: SteamBleModels.triton),
    SteamBleInput(characteristic: valveUuid(0x7C), reportId: TritonReportId.stateTimestamp, model: SteamBleModels.triton)
]

/// The input among the service's characteristics, in the order the pad
/// lists them: SDL's iOS backend keeps the last it meets.
package func steamBleInput(among characteristics: [String]) -> SteamBleInput? {
    characteristics.compactMap(steamBleInput(named:)).last
}

private func steamBleInput(named characteristic: String) -> SteamBleInput? {
    steamBleInputs.first { $0.characteristic == characteristic }
}

/// SDL's iOS backend takes a connected peripheral whose name starts so:
/// the 2015 pad's "SteamController" and the 2026 pad's "Steam Ctrl".
package func isSteamControllerName(_ name: String?) -> Bool {
    name?.hasPrefix("Steam") == true
}

/// The longest report a value becomes with its id in front: the 2026 pad's
/// 45-byte state and its id, with room to spare.
package let steamBleReportCapacity = 64

/// The value as SDL's iOS backend hands it to its drivers, its report id
/// put back in front, written into `report`; its length, or nil for a value
/// too long to hold.
package func steamBleInputReport(
    _ value: UnsafeRawBufferPointer,
    reportId: UInt8,
    into report: UnsafeMutableBufferPointer<UInt8>
) -> Int? {
    let length = value.count + 1
    guard length <= report.count else { return nil }
    report[0] = reportId
    for index in 0 ..< value.count {
        report[index + 1] = value[index]
    }
    return length
}

/// Where a write goes: a feature report to the report characteristic, an
/// output report to its own.
package func steamBleCharacteristic(for write: SteamWrite) -> String {
    switch write.kind {
    case .feature: SteamBleUuid.report
    case .output: SteamBleUuid.output(write.reportId)
    }
}

/// What goes on the air: the report past its id, as SDL's iOS backend
/// writes both kinds.
package func steamBleValue(of write: SteamWrite) -> [UInt8] {
    Array(write.bytes.dropFirst())
}

// MARK: - Whether Dish may reach them

/// What Bluetooth tells Dish: CoreBluetooth's state, its refusal split by
/// whether the person can lift it.
package enum SteamRadioState: Equatable {
    /// iOS has not answered yet: the question is up, or Bluetooth is resetting.
    case waiting
    case poweredOn
    case poweredOff
    case unsupported
    case denied
    case restricted
}

/// Whether the central's peripherals outlive Bluetooth's word: below powered
/// on CoreBluetooth has disconnected them all, and below powered off the
/// objects themselves are spent (`CBCentralManager.h`), so a pad is retrieved
/// afresh once Bluetooth is back.
package func steamRadioKeepsPeripherals(_ radio: SteamRadioState) -> Bool {
    switch radio {
    case .poweredOn: true
    case .waiting, .poweredOff, .unsupported, .denied, .restricted: false
    }
}

/// Where Steam Controllers over Bluetooth stand, as the Settings row says.
package enum SteamBluetoothStatus: Equatable {
    case off
    case waiting
    case on
    case bluetoothOff
    case unsupported
    case refused
    case restricted
}

/// Off until the person opts in; then whatever Bluetooth says, waiting for
/// its first word.
package func steamBluetoothStatus(enabled: Bool, radio: SteamRadioState?) -> SteamBluetoothStatus {
    guard enabled else { return .off }
    guard let radio else { return .waiting }
    switch radio {
    case .waiting: return .waiting
    case .poweredOn: return .on
    case .poweredOff: return .bluetoothOff
    case .unsupported: return .unsupported
    case .denied: return .refused
    case .restricted: return .restricted
    }
}
