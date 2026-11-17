// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// One claimed Steam Controller's input on its way out, on the links' queue:
/// each value with its report id put back in front, decoded, its trackpads
/// landed by the slot's pick, and published through the slot's feed once
/// the main actor has handed it over. A report builds nothing: the report
/// buffer and the decoder's carry are made with the reader.
final class SteamPadReader {
    let input: SteamBleInput
    private var report = [UInt8](repeating: 0, count: steamBleReportCapacity)
    private var bleCarry = SteamBleCarry()
    private var tritonCarry = TritonCarry()
    private var feed: PadFeed?
    private var pick: TouchpadPick
    /// The last surface published; lifted until the first touch.
    private var lastSurface = SteamSurface.lifted

    init(input: SteamBleInput) {
        self.input = input
        pick = defaultTrackpadPick(input.model.trackpads, typeOffersDs4: false)
    }

    /// The slot's feed, from the main actor: the next report publishes through it.
    func use(_ fresh: PadFeed) {
        feed = fresh
    }

    /// The slot's trackpad pick from now on, as the main actor resolved it.
    func use(_ fresh: TouchpadPick) {
        pick = fresh
    }

    /// One value of the input characteristic, as CoreBluetooth handed it over.
    func read(_ value: Data) {
        value.withUnsafeBytes { raw in
            report.withUnsafeMutableBufferPointer { buffer in
                guard let length = steamBleInputReport(raw, reportId: input.reportId, into: buffer) else { return }
                publish(decode(UnsafeBufferPointer(rebasing: buffer[..<length])))
            }
        }
    }

    /// The claim ended: nothing the pad last held stays held on the host.
    func release() {
        feed?.publishIfChanged(.released)
        publishSurface(.lifted)
    }

    private func decode(_ report: UnsafeBufferPointer<UInt8>) -> SteamReading? {
        switch input.model.generation {
        case .originalOverBluetooth: decodeSteamControllerBle(report, carry: &bleCarry)
        case .triton: decodeTritonReport(report, carry: &tritonCarry)
        }
    }

    /// The pads land by the pick before the state is published, so the
    /// report the host sees already has the pads' share of it.
    private func publish(_ reading: SteamReading?) {
        guard let reading, let feed else { return }
        switch reading {
        case let .state(state, motion, pads):
            let routed = routeSteamTrackpads(pick: pick, trackpads: input.model.trackpads, pads: pads, report: state)
            feed.publishIfChanged(routed.report)
            if let motion { feed.publishMotion(motion) }
            publishSurface(routed.surface)
        }
    }

    /// The surface goes out when it changed, each finger's id bumped on its
    /// fresh contact.
    private func publishSurface(_ surface: SteamSurface) {
        guard surface != lastSurface, let feed else { return }
        lastSurface = surface
        let ids = feed.advanceTouchIds(finger0Active: surface.finger0.active, finger1Active: surface.finger1.active)
        feed.publishTouchpad(TouchpadSample(
            finger0: TouchpadFinger(active: surface.finger0.active, id: ids.finger0, x: surface.finger0.x, y: surface.finger0.y),
            finger1: TouchpadFinger(active: surface.finger1.active, id: ids.finger1, x: surface.finger1.x, y: surface.finger1.y),
            buttonPressed: surface.clicked
        ))
    }
}
