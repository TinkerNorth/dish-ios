// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// A Steam Controller on Bluetooth LE as SDL's iOS backend reaches it
/// (`src/hidapi/ios/hid.m`): the pads by name, Valve's service and its
/// characteristics, each value's report id put back in front, the writes
/// past their ids on the characteristics their kinds name, and the Settings
/// row's state from what Bluetooth says.
final class SteamBleGattTests: XCTestCase {

    private static let input2015 = "100F6C33-1735-4313-B402-38567131E5F3"
    private static let input2026 = "100F6C7A-1735-4313-B402-38567131E5F3"
    private static let input2026Timestamped = "100F6C7C-1735-4313-B402-38567131E5F3"
    private static let report = "100F6C34-1735-4313-B402-38567131E5F3"

    private func inputReport(_ value: [UInt8], reportId: UInt8, capacity: Int = steamBleReportCapacity) -> [UInt8]? {
        var report = [UInt8](repeating: 0, count: capacity)
        let length = value.withUnsafeBytes { raw in
            report.withUnsafeMutableBufferPointer { steamBleInputReport(raw, reportId: reportId, into: $0) }
        }
        return length.map { Array(report.prefix($0)) }
    }

    // MARK: - Finding them

    func testValvesUuidsAreSdls() {
        XCTAssertEqual(SteamBleUuid.service, "100F6C32-1735-4313-B402-38567131E5F3")
        XCTAssertEqual(SteamBleUuid.report, Self.report)
        XCTAssertEqual(SteamBleUuid.output(0x80), "100F6CB5-1735-4313-B402-38567131E5F3", "an output report sits 0x35 past its id")
        XCTAssertEqual(SteamBleUuid.deviceInformation, "180A", "what SDL retrieves the connected pads by")
    }

    func testBothPadsNamesStartWithSteamAndNothingElseIsOne() {
        XCTAssertTrue(isSteamControllerName("SteamController"))
        XCTAssertTrue(isSteamControllerName("Steam Ctrl 1A2B"))
        XCTAssertFalse(isSteamControllerName("Xbox Wireless Controller"))
        XCTAssertFalse(isSteamControllerName("steamcontroller"), "SDL's prefix is case-sensitive")
        XCTAssertFalse(isSteamControllerName(nil))
    }

    func testEachInputCharacteristicNamesItsModelAndTheIdPutBackInFront() throws {
        let original = try XCTUnwrap(steamBleInput(among: [Self.input2015]))
        XCTAssertEqual(original.reportId, 0x03)
        XCTAssertEqual(original.model, SteamBleModels.original)
        XCTAssertEqual(original.model.productId, 0x1106)
        let triton = try XCTUnwrap(steamBleInput(among: [Self.input2026]))
        XCTAssertEqual(triton.reportId, 0x45)
        XCTAssertEqual(triton.model, SteamBleModels.triton)
        XCTAssertEqual(triton.model.productId, 0x1303)
        XCTAssertEqual(try XCTUnwrap(steamBleInput(among: [Self.input2026Timestamped])).reportId, 0x47)
    }

    func testTheLastInputTheServiceListsWinsAsInSdl() {
        let listed = [Self.input2026Timestamped, Self.report, Self.input2026]
        XCTAssertEqual(steamBleInput(among: listed)?.reportId, 0x45)
        XCTAssertNil(steamBleInput(among: [Self.report, SteamBleUuid.output(0x80)]), "no input, no pad")
    }

    func testEachModelsTrackpadsAreItsOwn() {
        XCTAssertEqual(SteamBleModels.original.trackpads, .rightStickByDefault)
        XCTAssertEqual(SteamBleModels.triton.trackpads, .twoPads)
        XCTAssertEqual(SteamBleModels.original.name, "Valve Steam Controller (Bluetooth)", "dish-mac's model row")
        XCTAssertEqual(SteamBleModels.triton.name, "Valve Steam Controller (2026, Bluetooth)")
    }

    // MARK: - The values

    func testAValueGetsItsReportIdBackInFrontAsSdlsIosBackendHandsItOn() {
        XCTAssertEqual(inputReport([0xC0, 1, 2, 3], reportId: 0x03), [0x03, 0xC0, 1, 2, 3])
        XCTAssertEqual(inputReport([], reportId: 0x45), [0x45])
        XCTAssertNil(inputReport([1, 2, 3, 4], reportId: 0x45, capacity: 4), "a value too long to hold is dropped")
    }

    func testA2015SegmentAsCoreBluetoothDeliversItDecodesOnceItsIdIsBack() throws {
        let packet = SteamBlePacketBytes().buttons(0x80)
        let value = try XCTUnwrap(packet.values.first)
        XCTAssertEqual(value.count, 19, "the header and 18 bytes")
        var carry = SteamBleCarry()
        let report = try XCTUnwrap(inputReport(value, reportId: 0x03))
        guard case let .state(state, _, _) = decodeBleReport(report, carry: &carry) else { return XCTFail("no state") }
        XCTAssertEqual(state.buttons, WireButton.faceA.bit)
    }

    func testA2026StateReportAsCoreBluetoothDeliversItIsFortyFiveBytes() throws {
        let value = TritonReportBytes.state(0x0000_0001, reportId: 0x45).value
        XCTAssertEqual(value.count, 45)
        let report = try XCTUnwrap(inputReport(value, reportId: 0x45))
        guard case let .state(state, _, _) = TritonReportBytes(bytes: report).decode() else { return XCTFail("no state") }
        XCTAssertEqual(state.buttons, WireButton.faceA.bit)
    }

    // MARK: - The writes

    func testAFeatureReportGoesToTheReportCharacteristicPastItsId() {
        let quiet = SteamWrite(kind: .feature, reportId: 0x03, bytes: [0x03, 0xC0, 0x81, 0x00])
        XCTAssertEqual(steamBleCharacteristic(for: quiet), Self.report)
        XCTAssertEqual(steamBleValue(of: quiet), [0xC0, 0x81, 0x00])
        let lizard = SteamWrite(kind: .feature, reportId: 0x01, bytes: tritonLizardOffReport())
        XCTAssertEqual(steamBleValue(of: lizard).count, 63, "the 64-byte report past its id")
    }

    func testTheRumbleReportGoesToItsOwnCharacteristicPastItsId() {
        let rumble = SteamWrite(kind: .output, reportId: 0x80, bytes: tritonRumbleReport(left: 0x1234, right: 0xABCD))
        XCTAssertEqual(steamBleCharacteristic(for: rumble), "100F6CB5-1735-4313-B402-38567131E5F3")
        XCTAssertEqual(steamBleValue(of: rumble), [0x00, 0x00, 0x00, 0x34, 0x12, 0x00, 0xCD, 0xAB, 0x00])
    }

    // MARK: - The row's state

    func testTheRowIsOffUntilThePersonOptsInWhateverBluetoothSays() {
        for radio in [nil, SteamRadioState.poweredOn, .denied, .unsupported] {
            XCTAssertEqual(steamBluetoothStatus(enabled: false, radio: radio), .off)
        }
    }

    func testEachWordOfBluetoothsIsItsOwnState() {
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: nil), .waiting, "before Bluetooth's first word")
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .waiting), .waiting)
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .poweredOn), .on)
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .poweredOff), .bluetoothOff)
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .unsupported), .unsupported)
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .denied), .refused)
        XCTAssertEqual(steamBluetoothStatus(enabled: true, radio: .restricted), .restricted)
    }
}
