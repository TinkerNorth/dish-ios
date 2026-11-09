// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

@MainActor
final class BindingRequestsTests: XCTestCase {

    func testRequestsAreKeptInTheOrderTheyCame() {
        let bindings = BindingRequests()
        let wired = SetupDraft(input: .wired, destination: .byAddress)
        let screen = SetupDraft(input: .onScreen, destination: .satellite(id: "den"))
        bindings.record(wired)
        bindings.record(screen)
        XCTAssertEqual(bindings.requests, [wired, screen])
    }
}
