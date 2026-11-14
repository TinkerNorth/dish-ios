// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The trackpad router, ported from dish-mac's tests: by the slot's pick and
/// the pad's model, every pad position lands in at most one wire field and
/// every click in exactly one. iOS sends no pointer frame from a pad, so a
/// mouse pick lands as off.
final class SteamTrackpadsTests: XCTestCase {

    /// Where a pad input can land on the wire.
    private enum WireField: Hashable {
        case rightStick
        case rightThumb
        case finger0
        case finger1
        case surfaceClick
        case leftPadClickBit
        case rightPadClickBit
    }

    private enum Stimulus: CaseIterable {
        case leftPosition
        case rightPosition
        case leftClick
        case rightClick
    }

    private static let picks: [TouchpadPick] = [.stick, .pad, .mouse, .off]
    private static let models: [SteamTrackpads] = [.rightStickByDefault, .twoPads]
    private static let touching = SteamPadSample(active: true, x: 8000, y: 4000, clicked: false)

    private func pads(_ stimulus: Stimulus) -> SteamPads {
        switch stimulus {
        case .leftPosition: SteamPads(left: Self.touching, right: SteamPadSample())
        case .rightPosition: SteamPads(left: SteamPadSample(), right: Self.touching)
        case .leftClick: SteamPads(left: SteamPadSample(active: false, x: 0, y: 0, clicked: true), right: SteamPadSample())
        case .rightClick: SteamPads(left: SteamPadSample(), right: SteamPadSample(active: false, x: 0, y: 0, clicked: true))
        }
    }

    private func fields(_ routed: SteamRouted) -> Set<WireField> {
        var lit: Set<WireField> = []
        if routed.report.rx != 0 || routed.report.ry != 0 { lit.insert(.rightStick) }
        if routed.report.buttons & WireButton.rightThumb.bit != 0 { lit.insert(.rightThumb) }
        if routed.surface.finger0.active { lit.insert(.finger0) }
        if routed.surface.finger1.active { lit.insert(.finger1) }
        if routed.surface.clicked { lit.insert(.surfaceClick) }
        if routed.report.extButtons & ProtocolConstants.extButtonLeftPadClick != 0 { lit.insert(.leftPadClickBit) }
        if routed.report.extButtons & ProtocolConstants.extButtonRightPadClick != 0 { lit.insert(.rightPadClickBit) }
        return lit
    }

    private func route(_ pick: TouchpadPick, _ model: SteamTrackpads, _ stimulus: Stimulus) -> SteamRouted {
        routeSteamTrackpads(pick: pick, trackpads: model, pads: pads(stimulus), report: .released)
    }

    private func expected(_ pick: TouchpadPick, _ model: SteamTrackpads, _ stimulus: Stimulus) -> Set<WireField> {
        let stickless = pick == .stick && model == .twoPads
        let effective: TouchpadPick = stickless || pick == .mouse ? .off : pick
        switch (effective, stimulus) {
        case (.stick, .leftPosition): return []
        case (.stick, .rightPosition): return [.rightStick]
        case (.stick, .leftClick): return [.leftPadClickBit]
        case (.stick, .rightClick): return [.rightThumb]
        case (.pad, .leftPosition): return [.finger0]
        case (.pad, .rightPosition): return [.finger1]
        case (.pad, .leftClick), (.pad, .rightClick): return [.surfaceClick]
        case (.mouse, _), (.off, .leftPosition), (.off, .rightPosition): return []
        case (.off, .leftClick): return [.leftPadClickBit]
        case (.off, .rightClick): return [.rightPadClickBit]
        }
    }

    // MARK: - The invariant

    func testEachPositionLandsInAtMostOneWireFieldAndEachClickInExactlyOne() {
        for pick in Self.picks {
            for model in Self.models {
                for stimulus in Stimulus.allCases {
                    let lit = fields(route(pick, model, stimulus))
                    let label = "\(pick) on \(model), \(stimulus)"
                    XCTAssertEqual(lit, expected(pick, model, stimulus), label)
                    let isClick = stimulus == .leftClick || stimulus == .rightClick
                    if isClick {
                        XCTAssertEqual(lit.count, 1, "\(label): a click lands in exactly one field")
                    } else {
                        XCTAssertLessThanOrEqual(lit.count, 1, "\(label): a position lands in at most one field")
                    }
                }
            }
        }
    }

    func testThe2015RightStickStaysCentredAndNoR3OutsideStickMode() {
        let padsDown = SteamPads(left: Self.touching, right: SteamPadSample(active: true, x: 9000, y: -9000, clicked: true))
        let stale = GamepadReport(rx: 1234, ry: -1234)
        for pick in [TouchpadPick.pad, .mouse, .off] {
            let routed = routeSteamTrackpads(pick: pick, trackpads: .rightStickByDefault, pads: padsDown, report: stale)
            XCTAssertEqual(routed.report.rx, 0, "\(pick)")
            XCTAssertEqual(routed.report.ry, 0, "\(pick)")
            XCTAssertEqual(routed.report.buttons & WireButton.rightThumb.bit, 0, "\(pick): the click is not R3")
        }
    }

    func testThe2026PadHasARealRightStickTheRouterLeavesAlone() {
        let padsDown = SteamPads(left: Self.touching, right: SteamPadSample(active: true, x: 9000, y: -9000, clicked: true))
        let real = GamepadReport(buttons: WireButton.rightThumb.bit, rx: 1234, ry: -1234)
        for pick in Self.picks {
            let routed = routeSteamTrackpads(pick: pick, trackpads: .twoPads, pads: padsDown, report: real)
            XCTAssertEqual(routed.report.rx, 1234, "\(pick)")
            XCTAssertEqual(routed.report.ry, -1234, "\(pick)")
            XCTAssertNotEqual(routed.report.buttons & WireButton.rightThumb.bit, 0, "\(pick): the stick's own click stays")
        }
    }

    // MARK: - Each composition

    func testStickModeIsTheRightPadAsTheRightStickUpPositive() {
        let pads = SteamPads(left: SteamPadSample(), right: SteamPadSample(active: true, x: 9659, y: 2588, clicked: true))
        let routed = routeSteamTrackpads(pick: .stick, trackpads: .rightStickByDefault, pads: pads, report: .released)
        XCTAssertEqual(routed.report.rx, 9659)
        XCTAssertEqual(routed.report.ry, 2588, "the stick is up-positive, as the wire is")
        XCTAssertEqual(routed.report.buttons, WireButton.rightThumb.bit)
        XCTAssertEqual(routed.surface, .lifted)
        var lifted = pads
        lifted.right.active = false
        XCTAssertEqual(routeSteamTrackpads(pick: .stick, trackpads: .rightStickByDefault, pads: lifted, report: .released).report.rx, 0)
    }

    func testPadModeSplitsTheSurfaceLeftAndRightAndNegatesYOntoTheWire() {
        let pads = SteamPads(
            left: SteamPadSample(active: true, x: -32768, y: 32767, clicked: false),
            right: SteamPadSample(active: true, x: 32767, y: -32768, clicked: true)
        )
        let routed = routeSteamTrackpads(pick: .pad, trackpads: .twoPads, pads: pads, report: .released)
        XCTAssertEqual(routed.surface.finger0, TouchpadFinger(active: true, id: 0, x: -32768, y: -32767))
        XCTAssertEqual(routed.surface.finger1, TouchpadFinger(active: true, id: 1, x: 32767, y: 32767), "-(-32768) clamps")
        XCTAssertTrue(routed.surface.clicked, "either click is the surface's")
        XCTAssertEqual(routed.report.extButtons, 0)
        let centred = SteamPads(left: SteamPadSample(active: true, x: 0, y: 0, clicked: false), right: SteamPadSample())
        let halves = routeSteamTrackpads(pick: .pad, trackpads: .twoPads, pads: centred, report: .released)
        XCTAssertEqual(halves.surface.finger0.x, -16384, "the left pad's centre is the left half's")
        XCTAssertFalse(halves.surface.finger1.active)
    }

    func testAMousePickRoutesAsOffSinceIOSSendsNoPointerFrameFromAPad() {
        let pads = SteamPads(
            left: SteamPadSample(active: true, x: 100, y: 0, clicked: true),
            right: SteamPadSample(active: true, x: 5000, y: 6000, clicked: true)
        )
        for model in Self.models {
            let mouse = routeSteamTrackpads(pick: .mouse, trackpads: model, pads: pads, report: .released)
            let off = routeSteamTrackpads(pick: .off, trackpads: model, pads: pads, report: .released)
            XCTAssertEqual(mouse, off, "\(model)")
        }
    }

    func testOffPutsBothClicksOnTheExtendedButtonsWordAndNothingElse() {
        let pads = SteamPads(
            left: SteamPadSample(active: true, x: 100, y: 100, clicked: true),
            right: SteamPadSample(active: true, x: 100, y: 100, clicked: true)
        )
        let routed = routeSteamTrackpads(pick: .off, trackpads: .rightStickByDefault, pads: pads, report: .released)
        XCTAssertEqual(routed.report.extButtons, ProtocolConstants.extButtonLeftPadClick | ProtocolConstants.extButtonRightPadClick)
        XCTAssertEqual(routed.surface, .lifted)
        XCTAssertEqual(routed.report.rx, 0)
    }

    func testTheRouterKeepsTheReportsOtherFieldsAndAddsToItsWord() {
        let report = GamepadReport(buttons: 0x00F0, lt: 9, rt: 8, lx: 1, ly: 2, extButtons: ProtocolConstants.extButtonMisc1)
        let pads = SteamPads(left: SteamPadSample(active: false, x: 0, y: 0, clicked: true), right: SteamPadSample())
        let routed = routeSteamTrackpads(pick: .off, trackpads: .twoPads, pads: pads, report: report)
        XCTAssertEqual(routed.report.buttons, 0x00F0)
        XCTAssertEqual([routed.report.lt, routed.report.rt], [9, 8])
        XCTAssertEqual([routed.report.lx, routed.report.ly], [1, 2])
        XCTAssertEqual(routed.report.extButtons, ProtocolConstants.extButtonMisc1 | ProtocolConstants.extButtonLeftPadClick)
    }

    // MARK: - The pick's ladder

    func testTheChoicesPerModelLeaveTheMouseOut() {
        XCTAssertEqual(trackpadPickChoices(.none), [], "a pad without trackpads has no picker")
        XCTAssertEqual(trackpadPickChoices(.rightStickByDefault), [.stick, .pad, .off])
        XCTAssertEqual(trackpadPickChoices(.twoPads), [.pad, .off], "a real right stick leaves no room for the pick")
    }

    func testTheDefaultsAreTheStickOnThe2015PadAndTheTypesTouchpadOnThe2026Pad() {
        XCTAssertEqual(defaultTrackpadPick(.rightStickByDefault, typeOffersDs4: true), .stick)
        XCTAssertEqual(defaultTrackpadPick(.rightStickByDefault, typeOffersDs4: false), .stick)
        XCTAssertEqual(defaultTrackpadPick(.twoPads, typeOffersDs4: true), .pad)
        XCTAssertEqual(defaultTrackpadPick(.twoPads, typeOffersDs4: false), .off)
        XCTAssertEqual(defaultTrackpadPick(.none, typeOffersDs4: true), .off)
    }

    func testTheEffectivePickIsTheStoredOneTheModelOffersHeldToWhatThePathCarries() {
        XCTAssertEqual(effectiveTrackpadPick(stored: nil, trackpads: .rightStickByDefault, typeOffersDs4: true), .stick)
        XCTAssertEqual(effectiveTrackpadPick(stored: .pad, trackpads: .rightStickByDefault, typeOffersDs4: true), .pad)
        XCTAssertEqual(
            effectiveTrackpadPick(stored: .pad, trackpads: .rightStickByDefault, typeOffersDs4: false),
            .off,
            "no surface on the type, no pad, never the stick instead"
        )
        XCTAssertEqual(
            effectiveTrackpadPick(stored: .stick, trackpads: .twoPads, typeOffersDs4: true),
            .pad,
            "a pick the model does not offer falls to its default"
        )
        XCTAssertEqual(effectiveTrackpadPick(stored: nil, trackpads: .twoPads, typeOffersDs4: false), .off)
        XCTAssertEqual(effectiveTrackpadPick(stored: .off, trackpads: .twoPads, typeOffersDs4: true), .off)
    }

    func testAStoredMousePickReadsAsNoPick() {
        for model in Self.models {
            for offers in [true, false] {
                XCTAssertEqual(
                    effectiveTrackpadPick(stored: .mouse, trackpads: model, typeOffersDs4: offers),
                    effectiveTrackpadPick(stored: nil, trackpads: model, typeOffersDs4: offers),
                    "\(model), the type has a touchpad: \(offers)"
                )
            }
        }
    }

    func testOnlyThePadPickPutsAnythingOnTheSurface() {
        XCTAssertTrue(TouchpadPick.pad.carriesSurface)
        XCTAssertTrue(TouchpadPick.mouse.carriesSurface, "the satellite's own mouse routing")
        XCTAssertFalse(TouchpadPick.stick.carriesSurface)
        XCTAssertFalse(TouchpadPick.off.carriesSurface)
    }
}
