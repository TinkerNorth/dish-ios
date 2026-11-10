// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// Dish runs on an iPhone and an iPad, and what that takes is written in
/// four places: the project's device family, the Info.plist's orientations
/// for each device, and the iPad destination the UI tests run on in CI and
/// in the local gate. A change to one alone is caught here.
final class DeviceFamilyTests: XCTestCase {

    private static let iPadDestination = "platform=iOS Simulator,name=iPad Pro 11-inch (M5)"
    private static let allFour: Set = [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight"
    ]
    private static let uprightOrOnItsSide: Set = [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationLandscapeLeft",
        "UIInterfaceOrientationLandscapeRight"
    ]

    private func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: RepoFiles.url("App/Info.plist"))
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func orientations(_ key: String) throws -> Set<String> {
        try Set(XCTUnwrap(infoPlist()[key] as? [String], "Info.plist lists no \(key)"))
    }

    func testTheAppTargetsTheIPhoneAndTheIPad() throws {
        let project = try RepoFiles.read("project.yml")
        XCTAssertTrue(project.contains(#"TARGETED_DEVICE_FAMILY: "1,2""#), "project.yml builds for the iPhone (1) and the iPad (2)")
    }

    /// The iPad turns every way, as iPadOS asks of an app that shares the
    /// screen; the iPhone stands upright and lies on its side for play.
    func testAnIPadTurnsAllFourWaysAndAnIPhoneStandsUprightOrLiesOnItsSide() throws {
        XCTAssertEqual(try orientations("UISupportedInterfaceOrientations~ipad"), Self.allFour)
        XCTAssertEqual(try orientations("UISupportedInterfaceOrientations"), Self.uprightOrOnItsSide)
    }

    /// A fresh runner may list no simulator by name, so CI creates its iPad
    /// (the newest iPad Pro 11-inch on the newest runtime) and runs the UI
    /// tests on it by id.
    func testCIRunsTheUITestsOnAnIPadToo() throws {
        let workflow = try RepoFiles.read(".github/workflows/ios-ci.yml")
        XCTAssertTrue(workflow.contains(#"startswith("iPad Pro 11-inch")"#), "ios-ci.yml makes its iPad an iPad Pro 11-inch")
        XCTAssertTrue(workflow.contains("xcrun simctl create"), "the runner's iPad is created and booted, not assumed")
        XCTAssertTrue(workflow.contains(#"-destination "$IPAD_DESTINATION""#), "the UI tests run on that iPad")
        XCTAssertTrue(workflow.contains("-only-testing:DishUITests"), "the iPad pass runs the UI bundle alone")
    }

    func testTheLocalGateRunsTheSameIPad() throws {
        let gate = try RepoFiles.read("scripts/ci-local.sh")
        XCTAssertTrue(gate.contains(Self.iPadDestination), "ci-local.sh runs the UI tests on the iPad CI runs them on")
        XCTAssertTrue(gate.contains("-only-testing:DishUITests"))
    }
}
