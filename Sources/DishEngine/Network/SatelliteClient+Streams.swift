// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The up-direction streams: each encodes its payload straight into the
/// send's stack buffer through `sendEncrypted`, so no stream builds a `Data`.
/// Called on the bound pad's handler queue, one `sendto` per event.
extension SatelliteClient {

    func sendReport(controllerIndex: Int, report: GamepadReport) {
        let settled = settledProtocolVersion
        let payloadCount = ProtocolConstants.inputPayloadBytes(settledVersion: settled)
        sendEncrypted(msgType: ProtocolConstants.msgInput, payloadCount: payloadCount) { out in
            Encoders.writeInputPayload(
                controllerIndex: UInt8(truncatingIfNeeded: controllerIndex),
                report: report,
                settledVersion: settled,
                into: out
            )
        }
    }

    func sendMotion(controllerIndex: Int, sample: MotionSample, timestampDeltaUs: UInt32) {
        sendEncrypted(msgType: ProtocolConstants.msgMotion, payloadCount: ProtocolConstants.motionPayloadBytes) { out in
            Encoders.writeMotionPayload(
                controllerIndex: UInt8(truncatingIfNeeded: controllerIndex),
                sample: sample,
                timestampDeltaUs: timestampDeltaUs,
                into: out
            )
        }
    }

    /// MSG_BATTERY 0x000B. `level` is 0...100, or
    /// `ProtocolConstants.batteryLevelUnknown` for a status-only reading.
    func sendBattery(controllerIndex: Int, level: UInt8, status: BatteryStatus) {
        sendEncrypted(msgType: ProtocolConstants.msgBattery, payloadCount: ProtocolConstants.batteryPayloadBytes) { out in
            Encoders.writeBatteryPayload(
                controllerIndex: UInt8(truncatingIfNeeded: controllerIndex),
                level: level,
                status: status,
                into: out
            )
        }
    }

    /// MSG_TOUCHPAD 0x000C in the shape the settled version decodes: the
    /// 19-byte POINTER frame from version 2, the 16-byte frame on version 1,
    /// which drops anything longer.
    func sendTouchpad(controllerIndex: Int, sample: TouchpadSample, eventTimeMs: UInt32) {
        let index = UInt8(truncatingIfNeeded: controllerIndex)
        if ProtocolConstants.settledSpeaksV2(settledProtocolVersion) {
            sendEncrypted(msgType: ProtocolConstants.msgTouchpad, payloadCount: 1 + ProtocolConstants.pointerPayloadBytes) { out in
                Encoders.writePointerPayload(controllerIndex: index, sample: sample, eventTimeMs: eventTimeMs, into: out)
            }
        } else {
            sendEncrypted(msgType: ProtocolConstants.msgTouchpad, payloadCount: 1 + ProtocolConstants.touchpadPayloadBytes) { out in
                Encoders.writeTouchpadPayload(controllerIndex: index, sample: sample, eventTimeMs: eventTimeMs, into: out)
            }
        }
    }
}

/// A bound pad's feed sends here, under the controller index the pad holds
/// on this satellite.
extension SatelliteClient: PadSink {
    package func send(_ report: GamepadReport, slot: SlotIndex) {
        sendReport(controllerIndex: slot.value, report: report)
    }

    package func send(_ motion: MotionSample, timestampDeltaUs: UInt32, slot: SlotIndex) {
        sendMotion(controllerIndex: slot.value, sample: motion, timestampDeltaUs: timestampDeltaUs)
    }

    package func send(_ touch: TouchpadSample, eventTimeMs: UInt32, slot: SlotIndex) {
        sendTouchpad(controllerIndex: slot.value, sample: touch, eventTimeMs: eventTimeMs)
    }

    /// A reading that says nothing is not sent: the wire has no "no battery".
    package func send(battery: BatteryReading, slot: SlotIndex) {
        guard let wire = wireBattery(battery) else { return }
        sendBattery(controllerIndex: slot.value, level: wire.level, status: wire.status)
    }
}
