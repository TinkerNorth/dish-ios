// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// The end-to-end lane runs the same script a developer runs, against a
/// satellite release pinned by tag, and that satellite stays off the network.
final class E2EWorkflowTests: XCTestCase {

    private static let workflowPath = ".github/workflows/e2e.yml"
    private static let scriptPath = "scripts/e2e_local.sh"

    func testTheLaneRunsTheScriptAgainstATaggedSatellite() throws {
        let workflow = try RepoFiles.read(Self.workflowPath)
        XCTAssertTrue(workflow.contains("run: bash \(Self.scriptPath)"), "CI drives the script a developer runs")
        XCTAssertTrue(workflow.contains("repository: TinkerNorth/satellite"))
        XCTAssertNotNil(
            workflow.range(of: #"SATELLITE_TAG: "[0-9]+\.[0-9]+\.[0-9]+""#, options: .regularExpression),
            "the satellite is a release tag"
        )
        XCTAssertTrue(workflow.contains("ref: ${{ env.SATELLITE_TAG }}"), "the checkout reads the one pin")
        XCTAssertTrue(
            workflow.contains("SATELLITE_REPO: ${{ github.workspace }}/satellite"),
            "the script is told where the checkout landed"
        )
    }

    /// The lane's satellite is hermetic: its isolated home seeds a config
    /// that turns the update check off before the satellite starts, so the
    /// lane never phones GitHub, and satellite 2.1.3's updater crash (31 s
    /// after launch, when that check runs) never reaches it.
    func testTheScriptSeedsTheSatellitesConfigWithTheUpdateCheckOff() throws {
        let script = try RepoFiles.read(Self.scriptPath)
        XCTAssertTrue(script.contains("Library/Application Support/satellite"), "the satellite's config home")
        let seed = try XCTUnwrap(script.range(of: #""autoCheck": false"#), "no update check from a test lane")
        let launch = try XCTUnwrap(script.range(of: #"HOME="${E2E_HOME}" "${SATELLITE_BIN}""#))
        XCTAssertTrue(seed.lowerBound < launch.lowerBound, "seeded before the satellite starts")
        XCTAssertTrue(
            script.contains(#""controllerDbUpdates": false"#),
            "satellite 2.3.0 asks dish.tinkernorth.com for a controller database ten seconds after start unless this is off"
        )
    }
}
