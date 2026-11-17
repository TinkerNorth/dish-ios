// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// Every control answers the finger (DESIGN.md, "Interaction states"): a
/// tappable thing takes a kit style, is a `RowButton`, or takes a system
/// style that draws its own states; the two styles that show nothing over
/// content with its own colour are used nowhere under `Sources/Dish`.
final class InteractionFeedbackTests: XCTestCase {
    /// `.plain` draws no pressed state; `.borderless` only dims words that
    /// carry no colour of their own, and every word here carries one.
    private static let silentStyles = [".buttonStyle(.plain)", ".buttonStyle(.borderless)"]

    func testNoControlTakesASilentStyle() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/Dish") {
            let offenders = try RepoFiles.offendingLines(in: file) { line in Self.silentStyles.contains { line.contains($0) } }
            XCTAssertEqual(
                offenders,
                [],
                "\(file): a pressed control shows it; take .tile, .capsule or .round, be a RowButton, or take a system style"
            )
        }
    }

    /// A row that opens a page or a link is a `RowButton`, so it washes like
    /// every other row; iOS draws no highlight of its own over a row that
    /// carries the surface colour, and a `NavigationLink` or a `Link` would
    /// stay silent.
    func testARowThatOpensSomethingIsARowButton() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/Dish") {
            let offenders = try RepoFiles.offendingLines(in: file) { line in
                line.contains("NavigationLink(") || line.range(of: #"\bLink\("#, options: .regularExpression) != nil
            }
            XCTAssertEqual(offenders, [], "\(file): a row that opens a page or a link is a RowButton")
        }
    }

    /// A system surface that draws its own buttons: a menu, a swipe, a
    /// dialog, or a control held under a gesture, which answers the finger
    /// with its own held state.
    private static let drawnBySystem = [".contextMenu", ".swipeActions", "confirmationDialog", "DragGesture", "onLongPressGesture"]

    /// The kit's own tappable components each name their style, so a new one
    /// cannot ship silent by forgetting to.
    func testEveryKitButtonNamesItsStyle() throws {
        for file in RepoFiles.swiftFiles(under: "Sources/Dish/UI/Kit") {
            let source = try RepoFiles.read(file)
            let drawsAButton = source.range(of: #"\bButton\("#, options: .regularExpression) != nil
            let styled = source.contains(".buttonStyle(")
            let systemDrawn = Self.drawnBySystem.contains { source.contains($0) }
            XCTAssertTrue(!drawsAButton || styled || systemDrawn, "\(file) draws a Button without naming how it answers the finger")
        }
    }
}
