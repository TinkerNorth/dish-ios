// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import XCTest
@testable import Dish

/// The events the router posted to the navigation.
@MainActor
private final class EventLog {
    private(set) var events: [NavigationEvent] = []

    func record(_ event: NavigationEvent) {
        events.append(event)
    }
}

/// The routers handed to App Intents.
@MainActor
private final class RegistrationLog {
    private(set) var routers: [IntentRouter] = []

    func add(_ router: IntentRouter) {
        routers.append(router)
    }
}

/// The paired PCs the router reads.
private enum PairedPCs {
    static let living = ConnectionFact(id: "lr", name: "Living Room PC", address: "192.168.1.24", kind: .satellite, state: .needsPairing)
    static let nameless = ConnectionFact(
        id: "wifi:192.168.1.50:9876",
        name: "",
        address: "192.168.1.50",
        kind: .satellite,
        state: .offline(lastSeen: nil)
    )

    static func both() -> [ConnectionFact] {
        [living, nameless]
    }

    static func none() -> [ConnectionFact] {
        []
    }
}

/// The App Intents: each one is a navigation event the scene's router
/// posts, and Connect to PC names the paired PCs.
@MainActor
final class IntentsTests: XCTestCase {

    func testEachPlayIntentOpensItsScreen() {
        XCTAssertEqual(OpenGamepadIntent().event, .openPlay(.gamepad))
        XCTAssertEqual(OpenTouchpadIntent().event, .openPlay(.touchpad))
        XCTAssertEqual(OpenMouseIntent().event, .openPlay(.mouse))
    }

    func testDimTheScreenIsTheAccessorysDim() {
        XCTAssertEqual(DimScreenIntent().event, .dim)
    }

    func testConnectToAPCIsTheConnectEventForItsPC() {
        let intent = ConnectToPCIntent(pc: PCEntity(id: "lr", name: "Living Room PC"))
        XCTAssertEqual(intent.event, .connectTo(id: "lr"))
    }

    func testTheRouterPostsEachEventToTheNavigation() {
        let log = EventLog()
        let router = IntentRouter(send: log.record, paired: PairedPCs.none)
        router.post(.openPlay(.gamepad))
        router.post(.connectTo(id: "lr"))
        XCTAssertEqual(log.events, [.openPlay(.gamepad), .connectTo(id: "lr")])
    }

    /// The scene asks on every build; App Intents gets the router once, so
    /// no registration lands while an intent runs.
    func testTheRouterHandsItselfToAppIntentsOnce() {
        let router = IntentRouter(send: EventLog().record, paired: PairedPCs.none)
        let log = RegistrationLog()
        router.register(with: log.add)
        router.register(with: log.add)
        XCTAssertEqual(log.routers.count, 1)
        XCTAssertTrue(log.routers.first === router)
    }

    /// A PC that never advertised a name is named by its address, as its
    /// Connections row is.
    func testTheRouterOffersThePairedPCsByName() {
        let router = IntentRouter(send: EventLog().record, paired: PairedPCs.both)
        XCTAssertEqual(router.pcs, [
            PCEntity(id: "lr", name: "Living Room PC"),
            PCEntity(id: "wifi:192.168.1.50:9876", name: "192.168.1.50")
        ])
    }
}
