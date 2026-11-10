// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The Diagnostics page's lines, from the facts the engine vends: a PC's
/// session and its counters, a controller's rates and its side of the
/// wire, the app's own facts, the lock statistics and the recorder's lines.
final class DiagnosticsMappersTests: XCTestCase {

    private let english = Locale(identifier: "en_US")
    private static let noSamples = LatencySummary(p50RttMs: nil, p99RttMs: nil, samples: 0, capacity: 64)
    private static let counters = SessionCounters(sent: 1200, received: 600, dropped: 2, replayGuard: 600)

    private func summary(_ live: LinkState = .connected, kind: ConnectionKind = .satellite) -> ConnectionSummary {
        ConnectionSummary(id: "sat", name: "Den PC", address: "10.0.0.2", udpPort: 9876, live: live, kind: kind)
    }

    private func liveFacts(
        hostEpoch: Int? = 4,
        hostBitmap: UInt16? = 0b1,
        backend: Bool? = true,
        active: Int? = 1,
        latency: LatencySummary = noSamples
    ) -> HostSessionFacts {
        HostSessionFacts(
            id: "sat",
            live: true,
            offeredProtocol: 3,
            settledProtocol: 3,
            compat: .current,
            appliedEpoch: 4,
            hostEpoch: hostEpoch,
            hostBitmap: hostBitmap,
            confirmedBitmap: 0b1,
            backendAvailable: backend,
            activeControllers: active,
            missedAcks: 0,
            latency: latency
        )
    }

    private func controller(
        destination: DestinationFact? = nil,
        link: ControllerLink = .bluetooth,
        battery: Int? = nil,
        features: [SlotSwitch] = [],
        supported: Bool = true
    ) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "DualSense Wireless Controller",
            link: link,
            batteryPercent: battery,
            destination: destination,
            family: .dualSense,
            emulateAs: .dualSense,
            features: features.map { ControllerFeatureFact(feature: $0, enabled: true) },
            supported: supported
        )
    }

    private func pad(
        _ controller: ControllerFact,
        rates: PadRates = PadRates(reportHz: 0, motionHz: 0),
        reports: UInt64 = 0,
        wire: SlotWireFacts? = nil
    ) -> PadDiagnostics {
        PadDiagnostics(controller: controller, rates: rates, reports: reports, wire: wire)
    }

    // MARK: - A PC

    func testARestingPCShowsItsAddressItsTierAndNoSession() {
        let host = HostDiagnostics(summary: summary(.saved), facts: .resting(id: "sat"), counters: .none)
        XCTAssertEqual(hostLines(host, locale: english), [
            FactLine(key: "Address", value: "10.0.0.2 · UDP 9876"),
            FactLine(key: "Link tier", value: "Fastest"),
            FactLine(key: "Session", value: "No session right now")
        ])
    }

    func testALivePCTellsItsWholeStoryWithItsCounters() {
        let lines = hostLines(HostDiagnostics(summary: summary(), facts: liveFacts(), counters: Self.counters), locale: english)
        XCTAssertEqual(lines.map(\.key), [
            "Address", "Link tier", "Protocol", "Epoch", "Controllers", "Virtual controllers", "Round trip", "Missed heartbeats",
            "Sent", "Received", "Dropped", "Replay guard"
        ])
        XCTAssertEqual(lines[2].value, "v3")
        XCTAssertEqual(lines[3].value, "on the host: 4 · applied: 4 · in step")
        XCTAssertEqual(lines[4].value, "on the host: 0 · confirmed: 0 · in step")
        XCTAssertEqual(lines[5].value, "available · 1 in use")
        XCTAssertEqual(lines[6].value, "no samples yet")
        XCTAssertEqual(lines[7].value, "0")
        XCTAssertEqual(lines[8].value, "1,200")
        XCTAssertEqual(lines[9].value, "600")
        XCTAssertEqual(lines[10].value, "2")
        XCTAssertEqual(lines[11].value, "600")
    }

    func testBeforeTheFirstAckThePCSaysSo() {
        let facts = liveFacts(hostEpoch: nil, hostBitmap: nil, backend: nil, active: nil)
        XCTAssertEqual(epochText(facts), "applied: 4 · waiting for the first heartbeat")
        XCTAssertEqual(controllersText(facts), "confirmed: 0 · waiting for the first heartbeat")
        XCTAssertEqual(backendText(facts), "unknown")
    }

    func testDriftReadsOutOfStep() {
        let facts = liveFacts(hostEpoch: 5, hostBitmap: 0b11)
        XCTAssertEqual(epochText(facts), "on the host: 5 · applied: 4 · out of step")
        XCTAssertEqual(controllersText(facts), "on the host: 0, 1 · confirmed: 0 · out of step")
        XCTAssertEqual(indexListText([]), "none")
    }

    func testTheProtocolLineNamesTheOfferAndTheStandingWhenTheyMatter() {
        let lowered = HostSessionFacts(
            id: "sat",
            live: true,
            offeredProtocol: 3,
            settledProtocol: 1,
            compat: .satelliteUpdateAvailable,
            appliedEpoch: 0,
            hostEpoch: nil,
            hostBitmap: nil,
            confirmedBitmap: 0,
            backendAvailable: nil,
            activeControllers: nil,
            missedAcks: 0,
            latency: Self.noSamples
        )
        XCTAssertEqual(protocolText(lowered), "v1 (offered v3) · Satellite update recommended")
        XCTAssertEqual(protocolText(liveFacts()), "v3")
        XCTAssertNil(protocolCompatText(.unknown))
        XCTAssertNil(protocolCompatText(.current))
        XCTAssertEqual(protocolCompatText(.satelliteUpdateRequired), "Satellite update required")
        XCTAssertEqual(protocolCompatText(.dishUpdateRequired), "Dish update required")
    }

    func testTheRoundTripLineCarriesTheThreeFiguresAndTheFill() {
        let latency = LatencySummary(p50RttMs: 12.0, p99RttMs: 40.25, samples: 5, capacity: 64)
        XCTAssertEqual(roundTripText(latency, locale: english), "12.0 ms p50 · 40.2 ms p99 · 6.0 ms one way · 5 of 64 pings")
        XCTAssertEqual(
            roundTripText(latency, locale: Locale(identifier: "de_DE")),
            "12,0 ms p50 · 40,2 ms p99 · 6,0 ms one way · 5 of 64 pings"
        )
    }

    func testEachKindOfPCHasItsTier() {
        XCTAssertEqual(linkTierText(.satellite), "Fastest")
        XCTAssertEqual(linkTierText(.moonlight), "Fast")
        XCTAssertEqual(linkTierText(.bluetooth), "Basic")
    }

    func testEveryLinkStateHasItsChipAndItsDot() {
        XCTAssertEqual(linkStateText(.stale), "Needs pairing")
        XCTAssertEqual(linkStateText(.saved), "Offline")
        XCTAssertEqual(linkStateText(.ready), "Ready")
        XCTAssertEqual(linkStateText(.connecting), "Connecting…")
        XCTAssertEqual(linkStateText(.connected), "Online")
        XCTAssertEqual(linkStateText(.unstable), "Unsteady")
        XCTAssertEqual(linkDot(.connected), DishTheme.success)
        XCTAssertEqual(linkDot(.unstable), DishTheme.warning)
        XCTAssertEqual(linkDot(.stale), DishTheme.warning)
        XCTAssertEqual(linkDot(.connecting), DishTheme.primary)
        XCTAssertEqual(linkDot(.saved), DishTheme.muted)
        XCTAssertEqual(linkDot(.ready), DishTheme.muted)
    }

    // MARK: - A controller

    func testAnUnboundPadShowsItsLinkItsRateItsTypeAndNoBinding() {
        XCTAssertEqual(padLines(pad(controller())), [
            FactLine(key: "Connection", value: "Bluetooth"),
            FactLine(key: "Input rate", value: "0 Hz · 0 reports"),
            FactLine(key: "Type", value: "DualSense"),
            FactLine(key: "Binding", value: "Not bound")
        ])
    }

    func testABoundPadReadsItsRatesItsBatteryItsBindingAndTheWire() {
        let online = DestinationFact(name: "Den PC", health: .online)
        let bound = controller(destination: online, link: .usbC, battery: 84, features: [.motion, .rumble])
        let wire = SlotWireFacts(
            controllerIndex: 0,
            type: 2,
            caps: ProtocolConstants.capRumble | ProtocolConstants.capMotion,
            touchpad: .pad,
            confirmed: true,
            streaming: .yes
        )
        let lines = padLines(pad(bound, rates: PadRates(reportHz: 250, motionHz: 120), reports: 1024, wire: wire))
        XCTAssertEqual(lines.map(\.key), [
            "Connection", "Input rate", "Motion rate", "Type", "Battery", "Binding", "Controller index", "Confirmed by host", "Streaming",
            "Advertised", "Touchpad on the wire"
        ])
        XCTAssertEqual(lines.map(\.value), [
            "USB-C", "250 Hz · 1,024 reports", "120 Hz", "DualSense", "84%", "Den PC · Satellite", "0", "yes", "yes",
            "Rumble · Motion", "pad"
        ])
    }

    func testABoundPadWithoutADescriptorIsNotDeclaredYet() {
        let bound = controller(destination: DestinationFact(name: "Den PC", health: .unsteady))
        XCTAssertEqual(bindingLines(pad(bound)), [
            FactLine(key: "Binding", value: "Den PC · Satellite"),
            FactLine(key: "On the wire", value: "Not declared to the host yet")
        ])
    }

    func testEveryHealthHasItsWordAndTheOnScreenGamepadItsName() {
        XCTAssertEqual(healthText(controller(supported: false)), "Not supported")
        XCTAssertEqual(healthText(controller()), "Not bound")
        XCTAssertEqual(healthText(controller(destination: DestinationFact(name: "Den PC", health: .online))), "Online")
        XCTAssertEqual(healthText(controller(destination: DestinationFact(name: "Den PC", health: .unsteady))), "Unsteady")
        XCTAssertEqual(healthText(controller(destination: DestinationFact(name: "Den PC", health: .lost))), "Connection lost")
        let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)
        XCTAssertEqual(padCard(pad(onScreen)).title, "On-screen gamepad")
        XCTAssertEqual(padLines(pad(onScreen)).first, FactLine(key: "Connection", value: "On-screen"))
    }

    func testEveryWireWordIsSpelled() {
        XCTAssertEqual(streamingText(.unknown), "waiting for the first heartbeat")
        XCTAssertEqual(streamingText(.no), "no")
        XCTAssertEqual(advertisedText(0), "nothing")
        XCTAssertEqual(
            advertisedText(0xFFFF),
            "Analog triggers · Rumble · Motion · Light bar · Adaptive triggers · Player LEDs · Microphone · Speaker · Haptic audio"
        )
        XCTAssertEqual(wireTouchpadText(.off), "off")
        XCTAssertEqual(wireTouchpadText(.mouse), "mouse")
    }

    // MARK: - The app

    func testTheAppLinesNameTheVersionsAndTheLocalNetwork() {
        XCTAssertEqual(appLines(appVersion: "0.1.0", localNetwork: .allowed), [
            FactLine(key: "App version", value: "0.1.0"),
            FactLine(key: "Protocol", value: "v3"),
            FactLine(key: "Local Network", value: "Allowed")
        ])
        XCTAssertEqual(localNetworkText(.unknown), "Not asked yet")
        XCTAssertEqual(localNetworkText(.denied), "Denied")
    }

    func testTheLockStatisticsNameEachLockItsRoleAndItsCounts() {
        let latency = LockFact(lock: "satellite.latency", role: .heartbeat, acquisitions: 42, contended: 1, waitMaxNs: 0, holdMaxNs: 0)
        let routing = LockFact(lock: "routing.table", role: .main, acquisitions: 3, contended: 0, waitMaxNs: 0, holdMaxNs: 0)
        XCTAssertEqual(lockLines([latency, routing]), [
            FactLine(key: "satellite.latency · Heartbeat", value: "42 taken · 1 contended"),
            FactLine(key: "routing.table · Main", value: "3 taken · 0 contended")
        ])
        XCTAssertEqual(ThreadRole.allCases.map { threadRoleText($0) }, ["Input", "Receive", "Heartbeat", "Feedback", "Main", "Other"])
    }

    // MARK: - The events

    func testEveryEventKindHasItsLine() {
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .linkAppeared, subject: "Desk", to: .saved)), "Desk: appeared, Offline")
        XCTAssertEqual(
            eventText(DiagnosticsEvent(atMs: 0, kind: .linkChanged, subject: "Desk", from: .connecting, to: .connected)),
            "Desk: Connecting… → Online"
        )
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .linkRemoved, subject: "Desk")), "Desk: removed")
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .padAttached, subject: "Pad")), "Pad: attached")
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .padDetached, subject: "Pad")), "Pad: detached")
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .padBound, subject: "Pad", host: "Desk")), "Pad: bound to Desk")
        XCTAssertEqual(eventText(DiagnosticsEvent(atMs: 0, kind: .padUnbound, subject: "Pad", host: "Desk")), "Pad: unbound from Desk")
        XCTAssertEqual(
            eventText(DiagnosticsEvent(atMs: 0, kind: .padAttached, subject: .onScreenGamepad)),
            "On-screen gamepad: attached",
            "the on-screen gamepad is the app's to word"
        )
    }

    func testALineLeadsWithTheLocalTimeAndTheTranscriptKeepsTheOrder() throws {
        let utc = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let british = Locale(identifier: "en_GB")
        let first = DiagnosticsEvent(sequence: 1, atMs: 3_600_000, kind: .linkRemoved, subject: "Desk")
        let second = DiagnosticsEvent(sequence: 2, atMs: 3_661_000, kind: .padDetached, subject: "Pad")
        XCTAssertEqual(eventTimeText(first.atMs, locale: british, timeZone: utc), "01:00:00")
        XCTAssertEqual(eventLine(first, locale: british, timeZone: utc), "01:00:00  Desk: removed")
        XCTAssertEqual(
            eventsTranscript([first, second], locale: british, timeZone: utc),
            "01:00:00  Desk: removed\n01:01:01  Pad: detached"
        )
    }

    func testThePageShowsTheNewestThirtyNewestFirst() {
        let events = (1 ... 40).map { DiagnosticsEvent(sequence: $0, atMs: Int64($0), kind: .linkRemoved, subject: "x") }
        let shown = recentEvents(events)
        XCTAssertEqual(shown.count, 30)
        XCTAssertEqual(shown.first?.sequence, 40)
        XCTAssertEqual(shown.last?.sequence, 11)
    }
}
