// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import XCTest
@testable import Dish

/// The fingers on a control: the ledger that keeps them in landing order
/// and reports their lifts, the lead finger a one-finger control follows,
/// the hold that lasts while any finger is down, a tap, the scroll strip's
/// step and the touchpad's slots.
final class FingersTests: XCTestCase {
    private let origin = CGPoint(x: 0, y: 0)
    private let here = CGPoint(x: 10, y: 20)
    private let there = CGPoint(x: 30, y: 40)

    /// A finger as a test reads it: landed where it is, at second zero.
    private func finger(_ id: Int, at location: CGPoint) -> Finger {
        Finger(id: id, location: location, origin: location, landedAt: 0)
    }

    // MARK: - The ledger

    func testAFingerLandsAtTheBackMovesInPlaceAndLeavesItsPlace() {
        let two = FingerLedger<String>().landed("one", at: here, time: 0).landed("two", at: there, time: 0)
        XCTAssertEqual(two.fingers, [finger(0, at: here), finger(1, at: there)])
        let moved = two.moved("one", to: origin).fingers
        XCTAssertEqual(moved, [Finger(id: 0, location: origin, origin: here, landedAt: 0), finger(1, at: there)], "it keeps its origin")
        XCTAssertEqual(two.lifted("one", at: here, time: 1).ledger.fingers, [finger(1, at: there)])
        XCTAssertEqual(two.cancelled("one").fingers, [finger(1, at: there)])
    }

    func testAFingerTheLedgerNeverSawMovesNothing() {
        let one = FingerLedger<String>().landed("one", at: here, time: 0)
        XCTAssertEqual(one.moved("ghost", to: there), one)
        XCTAssertEqual(one.lifted("ghost", at: there, time: 1), LedgerLift(ledger: one, lift: nil))
        XCTAssertEqual(one.cancelled("ghost"), one)
    }

    func testAFingerLandingAgainOnlyMoves() {
        let one = FingerLedger<String>().landed("one", at: here, time: 0)
        XCTAssertEqual(one.landed("one", at: there, time: 5).fingers, [Finger(id: 0, location: there, origin: here, landedAt: 0)])
    }

    func testNoFingerTakesALiftedOnesId() {
        let next = FingerLedger<String>().landed("one", at: here, time: 0).cancelled("one").landed("two", at: there, time: 1)
        XCTAssertEqual(next.fingers, [Finger(id: 1, location: there, origin: there, landedAt: 1)])
    }

    func testALiftSaysWhereTheFingerCameFromAndHowLongItStayed() {
        let one = FingerLedger<String>().landed("one", at: here, time: 2).moved("one", to: origin)
        XCTAssertEqual(one.lifted("one", at: there, time: 2.5).lift, FingerLift(origin: here, lifted: there, held: 0.5))
    }

    // MARK: - A tap

    func testATapStaysPutAndLiftsInTime() {
        XCTAssertTrue(isTap(FingerLift(origin: here, lifted: CGPoint(x: 18, y: 20), held: 0.15), slop: 12, window: 0.2))
        XCTAssertFalse(isTap(FingerLift(origin: here, lifted: CGPoint(x: 23, y: 20), held: 0.15), slop: 12, window: 0.2), "it slid")
        XCTAssertFalse(isTap(FingerLift(origin: here, lifted: here, held: 0.3), slop: 12, window: 0.2), "it lingered")
        XCTAssertTrue(isTap(FingerLift(origin: here, lifted: CGPoint(x: 22, y: 20), held: 0.2), slop: 12, window: 0.2), "the edges count")
    }

    // MARK: - One finger

    func testTheLeadFingerIsTheFirstThatLandedThenTheNextInLine() {
        let first = finger(0, at: here)
        let second = finger(1, at: there)
        XCTAssertEqual(leadFinger([first, second]), first)
        XCTAssertEqual(leadFinger([second]), second, "the first lifted")
        XCTAssertNil(leadFinger([]))
    }

    func testAButtonIsHeldWhileAnyFingerIsOnIt() {
        XCTAssertFalse(holding([]))
        XCTAssertTrue(holding([finger(0, at: here)]))
        XCTAssertTrue(holding([finger(1, at: there)]), "the first finger lifted, the second still holds")
    }

    // MARK: - The scroll strip

    func testTheScrollStripStepsByTheLeadFingersTravelSinceTheLastReport() {
        let landed = finger(0, at: CGPoint(x: 5, y: 10))
        let moved = finger(0, at: CGPoint(x: 5, y: 34))
        XCTAssertEqual(scrollStep(from: landed, to: moved), 24)
        XCTAssertEqual(scrollStep(from: moved, to: landed), -24, "up is negative")
    }

    func testANewScrollFingerStartsFromWhereItLandedAndALiftedOneMovedNothing() {
        let first = finger(0, at: CGPoint(x: 5, y: 10))
        let second = finger(1, at: CGPoint(x: 5, y: 90))
        XCTAssertEqual(scrollStep(from: nil, to: first), 0)
        XCTAssertEqual(scrollStep(from: first, to: second), 0, "another finger took the lead")
        XCTAssertEqual(scrollStep(from: first, to: nil), 0)
    }

    // MARK: - The touchpad's slots

    private var bothHeld: [SlotFinger] {
        [SlotFinger(id: 0, slot: 0, location: here), SlotFinger(id: 1, slot: 1, location: there)]
    }

    func testAFingerTakesTheLowestFreeSlotAndKeepsItWhileDown() {
        let first = finger(0, at: here)
        let second = finger(1, at: there)
        let one = slotFingers([], over: [first], slots: 2)
        let firstSlotted = SlotFinger(id: 0, slot: 0, location: here)
        XCTAssertEqual(one, SlotStep(slotted: [firstSlotted], freed: [], moved: [firstSlotted]))
        let two = slotFingers(one.slotted, over: [first, second], slots: 2)
        XCTAssertEqual(two.slotted, bothHeld)
        XCTAssertEqual(two.moved, [SlotFinger(id: 1, slot: 1, location: there)], "the first finger did not move")
        XCTAssertEqual(two.freed, [])
    }

    func testAMovedFingerIsReportedInItsSlot() {
        let step = slotFingers(bothHeld, over: [finger(0, at: here), finger(1, at: origin)], slots: 2)
        XCTAssertEqual(step.moved, [SlotFinger(id: 1, slot: 1, location: origin)])
        XCTAssertEqual(step.freed, [])
    }

    func testAThirdFingerIsLeftOutWhileBothSlotsAreHeld() {
        let fingers = [finger(0, at: here), finger(1, at: there), finger(2, at: origin)]
        let step = slotFingers(bothHeld, over: fingers, slots: 2)
        XCTAssertEqual(step.slotted, bothHeld)
        XCTAssertEqual(step.moved, [])
    }

    func testALiftedFingerFreesItsSlotForTheNextInLine() {
        let step = slotFingers(bothHeld, over: [finger(1, at: there), finger(2, at: origin)], slots: 2)
        XCTAssertEqual(step.freed, [0])
        XCTAssertEqual(step.slotted, [SlotFinger(id: 1, slot: 1, location: there), SlotFinger(id: 2, slot: 0, location: origin)])
        XCTAssertEqual(step.moved, [SlotFinger(id: 2, slot: 0, location: origin)], "the second finger kept its slot and its place")
    }

    func testEveryFingerLiftingFreesEverySlot() {
        XCTAssertEqual(slotFingers(bothHeld, over: [], slots: 2), SlotStep(slotted: [], freed: [0, 1], moved: []))
    }
}
