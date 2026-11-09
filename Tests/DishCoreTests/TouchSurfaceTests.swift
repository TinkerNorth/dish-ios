// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import XCTest
@testable import DishCore

/// The on-screen touchpad and mouse report touches and clicks: two finger
/// slots with fresh ids per contact, the click zones, Left and Right, and a
/// wheel event that rides one sample alone.
final class TouchSurfaceTests: XCTestCase {

    private func after(_ events: TouchSurfaceEvent..., from start: TouchSurfaceState = TouchSurfaceState()) -> TouchSurfaceStep {
        events.reduce(TouchSurfaceStep(state: start, sample: start.sample())) { step, event in
            reduceTouchSurface(step.state, event)
        }
    }

    func testAFreshSurfaceIsTheReleasedSample() {
        XCTAssertEqual(TouchSurfaceState().sample(), .idle)
    }

    func testAFingerIsReportedCentreOriginWithYDownAndAFreshId() {
        let sample = after(.finger(.first, x: 1, y: -0.5)).sample
        XCTAssertEqual(sample.finger0, TouchpadFinger(active: true, id: 1, x: 32767, y: -16383))
        XCTAssertEqual(sample.finger1, TouchpadFinger(active: false, id: 0, x: 0, y: 0))
        XCTAssertFalse(sample.buttonPressed)
    }

    func testAMovingFingerKeepsItsIdAndANewContactBumpsIt() {
        let moved = after(.finger(.first, x: 0, y: 0), .finger(.first, x: 0.5, y: 0))
        XCTAssertEqual(moved.sample.finger0.id, 1)
        let again = after(.lifted(.first), .finger(.first, x: 0, y: 0), from: moved.state)
        XCTAssertEqual(again.sample.finger0.id, 2)
    }

    func testALiftedFingerIsInactive() {
        let sample = after(.finger(.second, x: 0, y: 0), .lifted(.second)).sample
        XCTAssertFalse(sample.finger1.active)
    }

    func testTwoFingersRideTheirOwnSlots() {
        let sample = after(.finger(.first, x: -1, y: 0), .finger(.second, x: 1, y: 0)).sample
        XCTAssertEqual(sample.finger0.x, -32767)
        XCTAssertEqual(sample.finger1.x, 32767)
    }

    func testAClickZoneClicksAndHoldsTheSecondSlotOnItsOwnHalf() {
        let left = after(.clickZone(.left, held: true)).sample
        XCTAssertTrue(left.buttonPressed)
        XCTAssertTrue(left.finger1.active)
        XCTAssertLessThan(left.finger1.x, 0)
        let right = after(.clickZone(.right, held: true)).sample
        XCTAssertGreaterThan(right.finger1.x, 0)
    }

    func testReleasingTheZoneLetsGoOfTheClickAndItsSlot() {
        let sample = after(.clickZone(.right, held: true), .clickZone(.right, held: false)).sample
        XCTAssertFalse(sample.buttonPressed)
        XCTAssertFalse(sample.finger1.active)
    }

    func testAZoneLeavesASecondFingerWhereItIs() {
        let sample = after(.finger(.second, x: 0.2, y: 0.2), .clickZone(.left, held: true), .clickZone(.left, held: false)).sample
        XCTAssertTrue(sample.finger1.active, "the finger is still down")
        XCTAssertEqual(sample.finger1.x, 6553)
    }

    func testAFingerTakingTheZonesSlotKeepsTheClick() {
        let step = after(.clickZone(.left, held: true), .finger(.second, x: 0.2, y: 0))
        XCTAssertTrue(step.sample.buttonPressed)
        let released = after(.clickZone(.left, held: false), from: step.state)
        XCTAssertFalse(released.sample.buttonPressed)
        XCTAssertTrue(released.sample.finger1.active, "the finger keeps the slot")
    }

    func testTheMousesLeftIsTheClickAndRightIsItsOwnButton() {
        XCTAssertTrue(after(.leftButton(held: true)).sample.buttonPressed)
        let right = after(.rightButton(held: true)).sample
        XCTAssertTrue(right.rightPressed)
        XCTAssertFalse(right.buttonPressed)
        XCTAssertEqual(after(.leftButton(held: true), .leftButton(held: false)).sample, .idle)
    }

    func testDraggingTheStripUpOneNotchScrollsUpOnce() {
        let step = after(.scroll(points: -scrollPointsPerNotch))
        XCTAssertEqual(step.sample.scrollV, 120)
        XCTAssertEqual(after(.scroll(points: scrollPointsPerNotch * 2)).sample.scrollV, -240)
    }

    func testTravelShortOfANotchWaitsForTheNextMove() {
        let half = scrollPointsPerNotch / 2
        XCTAssertEqual(after(.scroll(points: -half)).sample.scrollV, 0)
        XCTAssertEqual(after(.scroll(points: -half), .scroll(points: -half)).sample.scrollV, 120)
    }

    func testTheWheelEventRidesOneSampleAlone() {
        let scrolled = after(.scroll(points: -scrollPointsPerNotch))
        XCTAssertEqual(scrolled.state.sample().scrollV, 0, "a resend of the state carries no wheel")
        XCTAssertEqual(after(.finger(.first, x: 0, y: 0), from: scrolled.state).sample.scrollV, 0)
    }

    func testReleasingEverythingLiftsBothSlotsAndKeepsTheirIds() {
        let held = after(.finger(.first, x: 0, y: 0), .clickZone(.right, held: true), .leftButton(held: true), .rightButton(held: true))
        let released = after(.releaseAll, from: held.state)
        XCTAssertFalse(released.sample.finger0.active)
        XCTAssertFalse(released.sample.finger1.active)
        XCTAssertFalse(released.sample.buttonPressed)
        XCTAssertFalse(released.sample.rightPressed)
        XCTAssertEqual(after(.finger(.first, x: 0, y: 0), from: released.state).sample.finger0.id, 2)
    }
}
