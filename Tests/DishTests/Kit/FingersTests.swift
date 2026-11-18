// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import SwiftUI
import XCTest
@testable import Dish

/// The fingers on a control: the ledger that keeps them in landing order,
/// the lead finger a one-finger control follows, the hold that lasts while
/// any finger is down, the scroll strip's step and the touchpad's slots.
final class FingersTests: XCTestCase {
    private let origin = CGPoint(x: 0, y: 0)
    private let here = CGPoint(x: 10, y: 20)
    private let there = CGPoint(x: 30, y: 40)

    // MARK: - The ledger

    func testAFingerLandsAtTheBackMovesInPlaceAndLeavesItsPlace() {
        let two = FingerLedger<String>().landed("one", at: here).landed("two", at: there)
        XCTAssertEqual(two.fingers, [Finger(id: 0, location: here), Finger(id: 1, location: there)])
        XCTAssertEqual(two.moved("one", to: origin).fingers, [Finger(id: 0, location: origin), Finger(id: 1, location: there)])
        XCTAssertEqual(two.lifted("one").fingers, [Finger(id: 1, location: there)])
    }

    func testAFingerTheLedgerNeverSawMovesNothing() {
        let one = FingerLedger<String>().landed("one", at: here)
        XCTAssertEqual(one.moved("ghost", to: there), one)
        XCTAssertEqual(one.lifted("ghost"), one)
    }

    func testAFingerLandingAgainOnlyMoves() {
        let one = FingerLedger<String>().landed("one", at: here)
        XCTAssertEqual(one.landed("one", at: there).fingers, [Finger(id: 0, location: there)])
    }

    func testNoFingerTakesALiftedOnesId() {
        let next = FingerLedger<String>().landed("one", at: here).lifted("one").landed("two", at: there)
        XCTAssertEqual(next.fingers, [Finger(id: 1, location: there)])
    }

    // MARK: - One finger

    func testTheLeadFingerIsTheFirstThatLandedThenTheNextInLine() {
        let first = Finger(id: 0, location: here)
        let second = Finger(id: 1, location: there)
        XCTAssertEqual(leadFinger([first, second]), first)
        XCTAssertEqual(leadFinger([second]), second, "the first lifted")
        XCTAssertNil(leadFinger([]))
    }

    func testAButtonIsHeldWhileAnyFingerIsOnIt() {
        XCTAssertFalse(holding([]))
        XCTAssertTrue(holding([Finger(id: 0, location: here)]))
        XCTAssertTrue(holding([Finger(id: 1, location: there)]), "the first finger lifted, the second still holds")
    }

    // MARK: - The scroll strip

    func testTheScrollStripStepsByTheLeadFingersTravelSinceTheLastReport() {
        let landed = Finger(id: 0, location: CGPoint(x: 5, y: 10))
        let moved = Finger(id: 0, location: CGPoint(x: 5, y: 34))
        XCTAssertEqual(scrollStep(from: landed, to: moved), 24)
        XCTAssertEqual(scrollStep(from: moved, to: landed), -24, "up is negative")
    }

    func testANewScrollFingerStartsFromWhereItLandedAndALiftedOneMovedNothing() {
        let first = Finger(id: 0, location: CGPoint(x: 5, y: 10))
        let second = Finger(id: 1, location: CGPoint(x: 5, y: 90))
        XCTAssertEqual(scrollStep(from: nil, to: first), 0)
        XCTAssertEqual(scrollStep(from: first, to: second), 0, "another finger took the lead")
        XCTAssertEqual(scrollStep(from: first, to: nil), 0)
    }

    // MARK: - The touchpad's slots

    private var bothHeld: [SlotFinger] {
        [SlotFinger(id: 0, slot: 0, location: here), SlotFinger(id: 1, slot: 1, location: there)]
    }

    func testAFingerTakesTheLowestFreeSlotAndKeepsItWhileDown() {
        let first = Finger(id: 0, location: here)
        let second = Finger(id: 1, location: there)
        let one = slotFingers([], over: [first], slots: 2)
        let firstSlotted = SlotFinger(id: 0, slot: 0, location: here)
        XCTAssertEqual(one, SlotStep(slotted: [firstSlotted], freed: [], moved: [firstSlotted]))
        let two = slotFingers(one.slotted, over: [first, second], slots: 2)
        XCTAssertEqual(two.slotted, bothHeld)
        XCTAssertEqual(two.moved, [SlotFinger(id: 1, slot: 1, location: there)], "the first finger did not move")
        XCTAssertEqual(two.freed, [])
    }

    func testAMovedFingerIsReportedInItsSlot() {
        let step = slotFingers(bothHeld, over: [Finger(id: 0, location: here), Finger(id: 1, location: origin)], slots: 2)
        XCTAssertEqual(step.moved, [SlotFinger(id: 1, slot: 1, location: origin)])
        XCTAssertEqual(step.freed, [])
    }

    func testAThirdFingerIsLeftOutWhileBothSlotsAreHeld() {
        let fingers = [Finger(id: 0, location: here), Finger(id: 1, location: there), Finger(id: 2, location: origin)]
        let step = slotFingers(bothHeld, over: fingers, slots: 2)
        XCTAssertEqual(step.slotted, bothHeld)
        XCTAssertEqual(step.moved, [])
    }

    func testALiftedFingerFreesItsSlotForTheNextInLine() {
        let step = slotFingers(bothHeld, over: [Finger(id: 1, location: there), Finger(id: 2, location: origin)], slots: 2)
        XCTAssertEqual(step.freed, [0])
        XCTAssertEqual(step.slotted, [SlotFinger(id: 1, slot: 1, location: there), SlotFinger(id: 2, slot: 0, location: origin)])
        XCTAssertEqual(step.moved, [SlotFinger(id: 2, slot: 0, location: origin)], "the second finger kept its slot and its place")
    }

    func testEveryFingerLiftingFreesEverySlot() {
        XCTAssertEqual(slotFingers(bothHeld, over: [], slots: 2), SlotStep(slotted: [], freed: [0, 1], moved: []))
    }
}
