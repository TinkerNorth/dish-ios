// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import SwiftUI
import XCTest
@testable import Dish

/// The PCs and controllers a PC page test draws.
private enum PcFixture {
    static let yesterday = FactsFixture.now.addingTimeInterval(-86400)
    static let pad = ControllerFact(id: "pad", name: "DualSense", link: .usbC, batteryPercent: 84, destination: nil)
    static let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)

    static func pc(
        id: String = "lr",
        name: String = "Living Room PC",
        state: ConnectionState = .online(latencyMs: 4, controllers: 2),
        bound: [String] = ["pad", onScreenSlotId],
        version: String? = "2.1.11",
        protocolVersion: Int? = 3,
        features: SatelliteFeaturesFact? = SatelliteFeaturesFact(motion: true, rumble: true)
    ) -> ConnectionFact {
        ConnectionFact(
            id: id,
            name: name,
            address: "192.168.1.24",
            kind: .satellite,
            state: state,
            boundControllerIds: bound,
            satelliteVersion: version,
            protocolVersion: protocolVersion,
            features: features
        )
    }

    static func page(_ pc: ConnectionFact, controllers: [ControllerFact] = [pad, onScreen]) -> PcDetailPageState {
        pcDetailPageState(facts: FactsFixture.shell(controllers: controllers, paired: [pc]), id: pc.id)
    }

    static func detail(_ pc: ConnectionFact, controllers: [ControllerFact] = [pad, onScreen]) -> PcDetailState? {
        guard case let .pc(detail) = page(pc, controllers: controllers).content else { return nil }
        return detail
    }

    static func carried(_ column: CarryColumn) -> [String] {
        column.rows.filter(\.carried).map(\.title)
    }
}

/// A PC's page (D2): the status card, what it carries, the controllers
/// bound to it, its actions, and Forget This PC asking first.
final class PcDetailMappersTests: XCTestCase {

    func testThePageIsTitledByThePCAndAStatusCardNamesItsLinkVersionProtocolAndAddress() throws {
        let page = PcFixture.page(PcFixture.pc())
        XCTAssertEqual(page.title, "Living Room PC")
        let detail = try XCTUnwrap(PcFixture.detail(PcFixture.pc()))
        XCTAssertEqual(detail.id, "lr")
        XCTAssertEqual(detail.status, PcStatusState(
            symbol: satelliteSymbol,
            line: "Online · 4 ms",
            dot: DishTheme.success,
            detail: "Satellite 2.1.11 · Protocol 3 · 192.168.1.24"
        ))
    }

    func testAnOfflinePCSaysWhenItWasSeenAndShowsOnlyWhatItKnows() throws {
        let pc = PcFixture.pc(state: .offline(lastSeen: PcFixture.yesterday), bound: [], version: nil, protocolVersion: nil, features: nil)
        let detail = try XCTUnwrap(PcFixture.detail(pc))
        XCTAssertEqual(detail.status.line, "Offline · seen yesterday")
        XCTAssertEqual(detail.status.dot, DishTheme.muted)
        XCTAssertEqual(detail.status.detail, "192.168.1.24")
        XCTAssertNil(detail.carries, "nothing probed yet")
        let never = PcFixture.pc(state: .offline(lastSeen: nil), version: "2.1.11", protocolVersion: nil)
        XCTAssertEqual(PcFixture.detail(never)?.status.line, "Offline")
        XCTAssertEqual(PcFixture.detail(never)?.status.detail, "Satellite 2.1.11 · 192.168.1.24")
    }

    func testAPCThatRevokedItsKeyNeedsPairing() throws {
        let detail = try XCTUnwrap(PcFixture.detail(PcFixture.pc(state: .needsPairing, protocolVersion: nil)))
        XCTAssertEqual(detail.status.line, "Needs pairing")
        XCTAssertEqual(detail.status.dot, DishTheme.warning)
    }

    func testCarryingListsEachBoundControllerOnItsSlot() throws {
        let detail = try XCTUnwrap(PcFixture.detail(PcFixture.pc()))
        XCTAssertEqual(detail.carrying, CarryingState(
            title: "Carrying · 2 of 4",
            rows: [
                CarriedControllerState(id: "pad", name: "DualSense", slot: "Slot 1"),
                CarriedControllerState(id: onScreenSlotId, name: "On-screen gamepad", slot: "Slot 2")
            ],
            empty: nil
        ))
    }

    func testCarryingNothingSaysSoAndAControllerDishNoLongerListsIsAPlainController() throws {
        let empty = try XCTUnwrap(PcFixture.detail(PcFixture.pc(bound: [])))
        XCTAssertEqual(empty.carrying, CarryingState(title: "Carrying · 0 of 4", rows: [], empty: "Nothing bound yet"))
        let gone = try XCTUnwrap(PcFixture.detail(PcFixture.pc(bound: ["ghost"]), controllers: []))
        XCTAssertEqual(gone.carrying.rows, [CarriedControllerState(id: "ghost", name: "Controller", slot: "Slot 1")])
    }

    func testWhatCarriesFollowsTheSatellitesCapabilities() throws {
        let both = try XCTUnwrap(PcFixture.detail(PcFixture.pc())?.carries)
        XCTAssertEqual(both.title, "What carries")
        XCTAssertEqual(both.sends.title, "Sends to PC")
        XCTAssertEqual(both.getsBack.title, "Gets back")
        XCTAssertEqual(PcFixture.carried(both.sends), ["Buttons, sticks", "Motion", "Touchpad", "Battery"])
        XCTAssertEqual(PcFixture.carried(both.getsBack), ["Rumble", "Trigger effects", "Light bar"])
        let neither = try XCTUnwrap(PcFixture.detail(PcFixture.pc(features: SatelliteFeaturesFact(motion: false, rumble: false)))?.carries)
        XCTAssertEqual(PcFixture.carried(neither.sends), ["Buttons, sticks", "Touchpad", "Battery"])
        XCTAssertEqual(PcFixture.carried(neither.getsBack), [])
        XCTAssertEqual(neither.getsBack.rows.map(\.title), ["Rumble", "Trigger effects", "Light bar", "Speaker"])
    }

    func testTheActionsFollowTheLink() {
        XCTAssertEqual(PcFixture.detail(PcFixture.pc())?.actions, [
            PcActionState(action: .repair, title: "Re-pair"),
            PcActionState(action: .disconnect, title: "Disconnect")
        ])
        XCTAssertEqual(PcFixture.detail(PcFixture.pc(state: .offline(lastSeen: nil)))?.actions, [
            PcActionState(action: .repair, title: "Re-pair"),
            PcActionState(action: .connect, title: "Connect")
        ])
        XCTAssertEqual(PcFixture.detail(PcFixture.pc(state: .needsPairing))?.actions, [PcActionState(action: .repair, title: "Re-pair")])
    }

    func testForgetAsksFirstAndNamesWhatStops() throws {
        let detail = try XCTUnwrap(PcFixture.detail(PcFixture.pc()))
        XCTAssertEqual(detail.forget, ForgetPcState(
            button: "Forget This PC",
            title: "Forget This PC",
            message: "Its pairing key is deleted. 2 controllers stop streaming, and you’ll need the PIN again.",
            confirm: "Forget",
            cancel: "Cancel"
        ))
        XCTAssertEqual(
            PcFixture.detail(PcFixture.pc(bound: ["pad"]))?.forget.message,
            "Its pairing key is deleted. 1 controller stops streaming, and you’ll need the PIN again."
        )
        XCTAssertEqual(PcFixture.detail(PcFixture.pc(bound: []))?.forget.message, "Its pairing key is deleted. You’ll need the PIN again.")
    }

    func testANamelessPCIsTitledByItsAddress() {
        XCTAssertEqual(PcFixture.page(PcFixture.pc(name: "")).title, "192.168.1.24")
    }

    func testAPCThatWasForgottenIsGoneUnderTheGenericTitle() {
        let page = pcDetailPageState(facts: FactsFixture.shell(), id: "lr")
        XCTAssertEqual(page.title, "PC")
        XCTAssertEqual(page.content, .gone(message: "This PC is no longer remembered."))
    }
}
