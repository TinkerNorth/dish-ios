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

    /// A fresh runner may list no simulator by name, and one it created and
    /// booted has gone missing by the time xcodebuild looked, so CI makes its
    /// iPad (the newest iPad Pro 11-inch, on the newest runtime that supports
    /// it) through `scripts/ci-simulator.sh` and runs the UI tests through it
    /// too, which reads the iPad back as booted first.
    func testCIRunsTheUITestsOnAnIPadItCreatedAndReadBack() throws {
        let workflow = try RepoFiles.read(".github/workflows/ios-ci.yml")
        XCTAssertTrue(
            workflow.contains(#"scripts/ci-simulator.sh create "CI iPad" "iPad Pro 11-inch""#),
            "ios-ci.yml makes its iPad an iPad Pro 11-inch, through the script"
        )
        XCTAssertTrue(workflow.contains(#"scripts/ci-simulator.sh run "$IPAD_UDID""#), "the UI tests run on that iPad, through the script")
        XCTAssertTrue(workflow.contains("-only-testing:DishUITests"), "the iPad pass runs the UI bundle alone")
    }

    /// The script creates and boots the device, trusts `simctl list` over
    /// `bootstatus` for whether it is there, and runs xcodebuild once more
    /// only for the two errors the runner produced on its own: the device
    /// gone before xcodebuild looked, and the UI test runner never starting.
    func testTheSimulatorScriptCreatesReadsBackAndRetriesOnlyTheRunnersOwnErrors() throws {
        let script = try RepoFiles.read("scripts/ci-simulator.sh")
        XCTAssertTrue(script.contains("xcrun simctl create"), "the device is created, not assumed")
        XCTAssertTrue(script.contains("xcrun simctl bootstatus"), "and booted")
        XCTAssertTrue(script.contains("xcrun simctl list devices -j"), "and read back from the device list")
        XCTAssertTrue(script.contains(#""Booted available""#), "as booted and available")
        XCTAssertTrue(
            script.contains("Unable to find a device matching the provided destination specifier"),
            "xcodebuild runs again when the device was gone"
        )
        XCTAssertTrue(script.contains("The test runner failed to initialize for UI testing"), "and when the UI test runner never started")
    }

    func testTheLocalGateRunsTheSameIPad() throws {
        let gate = try RepoFiles.read("scripts/ci-local.sh")
        XCTAssertTrue(gate.contains(Self.iPadDestination), "ci-local.sh runs the UI tests on the iPad CI runs them on")
        XCTAssertTrue(gate.contains("-only-testing:DishUITests"))
    }
}
