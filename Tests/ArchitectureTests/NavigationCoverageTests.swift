// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import XCTest

/// Every place the app can be is whole: each `Tab` and `Page` case has its
/// title worded in `ShellMappers`, its `<Name>Page.swift`, a
/// `<Name>MappersTests.swift` for its mapper, and a branch of the shell's
/// switch that draws it; each `Cover` case has its `<Name>Cover.swift` and a
/// branch of the shell's cover switch.
final class NavigationCoverageTests: XCTestCase {

    private static let machine = "Sources/Dish/Navigation/NavigationMachine.swift"
    private static let shellMappers = "Sources/Dish/UI/Mappers/ShellMappers.swift"
    private static let shellView = "Sources/Dish/UI/Shell/ShellView.swift"

    /// Where each switch starts in the source, and what closes it. Adjust a
    /// marker when the shell renames the function or property that holds the
    /// switch.
    private static let tabTitleMarker = "func tabTitle("
    private static let pageTitleMarker = "func pageTitle("
    private static let titleClosing = "\n}"
    /// The root switch is a property of the tab's stack; the pushed pages
    /// and the covers are each drawn by a private view of their own.
    private static let rootMarker = "private var root: some View {"
    private static let pushedMarker = "private struct PageView: View {"
    private static let coverMarker = "private struct ShellCover: View {"
    private static let switchClosing = "\n    }\n"
    private static let structClosing = "\n}\n"

    /// The case names of `enum <name>` in the navigation machine.
    private static func cases(of enumName: String) throws -> [String] {
        let source = try RepoFiles.read(machine)
        let body = try section(of: source, after: "enum \(enumName):", closing: "\n}")
        return body.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("case ") }
            .map { String($0.dropFirst("case ".count).prefix { $0.isLetter || $0.isNumber }) }
    }

    /// The text after `marker` up to the first `closing` that follows it.
    private static func section(of source: String, after marker: String, closing: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: marker), "\(marker) not found")
        let rest = source[start.upperBound...]
        let end = rest.range(of: closing)?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    private static func capitalized(_ name: String) -> String {
        name.prefix(1).uppercased() + name.dropFirst()
    }

    private static func mentions(_ name: String, in text: String, pattern: String) -> Bool {
        let regex = pattern.replacingOccurrences(of: "NAME", with: NSRegularExpression.escapedPattern(for: name))
        return text.range(of: regex, options: .regularExpression) != nil
    }

    private static func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: RepoFiles.url(relativePath).path)
    }

    private var tabs: [String] {
        get throws {
            try Self.cases(of: "Tab")
        }
    }

    private var pages: [String] {
        get throws {
            try Self.cases(of: "Page")
        }
    }

    private var covers: [String] {
        get throws {
            try Self.cases(of: "Cover")
        }
    }

    func testTheSweepSeesEveryTabPageAndCover() throws {
        XCTAssertEqual(try tabs, ["controllers", "connections", "settings"])
        XCTAssertTrue(try pages.contains("deviceName"), "the sweep must read the Page enum")
        XCTAssertEqual(try covers, ["setup", "play", "dim"])
    }

    func testEveryTabAndPageHasAWordedTitle() throws {
        let source = try RepoFiles.read(Self.shellMappers)
        let tabTitles = try Self.section(of: source, after: Self.tabTitleMarker, closing: Self.titleClosing)
        let pageTitles = try Self.section(of: source, after: Self.pageTitleMarker, closing: Self.titleClosing)
        let worded = #"case [^\n]*\.NAME\b[^\n]*: words\.\w+"#
        for name in try tabs {
            XCTAssertTrue(Self.mentions(name, in: tabTitles, pattern: worded), "Tab.\(name) has no L10n title")
        }
        for name in try pages {
            XCTAssertTrue(Self.mentions(name, in: pageTitles, pattern: worded), "Page.\(name) has no L10n title")
        }
    }

    func testEveryTabAndPageHasItsPageAndItsMapperTests() throws {
        for name in try tabs + pages {
            let stem = Self.capitalized(name)
            let page = "Sources/Dish/UI/Pages/\(stem)Page.swift"
            let tests = "Tests/DishTests/Mappers/\(stem)MappersTests.swift"
            XCTAssertTrue(Self.exists(page), "\(name) has no \(page)")
            XCTAssertTrue(Self.exists(tests), "\(name) has no \(tests)")
        }
    }

    func testEveryCoverHasItsView() throws {
        for name in try covers {
            let view = "Sources/Dish/UI/Setup/\(Self.capitalized(name))Cover.swift"
            XCTAssertTrue(Self.exists(view), "Cover.\(name) has no \(view)")
        }
    }

    func testTheShellDrawsEveryTabPageAndCover() throws {
        let source = try RepoFiles.read(Self.shellView)
        let root = try Self.section(of: source, after: Self.rootMarker, closing: Self.switchClosing)
        let pushed = try Self.section(of: source, after: Self.pushedMarker, closing: Self.structClosing)
        let cover = try Self.section(of: source, after: Self.coverMarker, closing: Self.structClosing)
        let drawnByValue = #"\.NAME\b"#
        let drawnByCase = #"case (let )?[^\n]*\.NAME\b"#
        for name in try tabs {
            XCTAssertTrue(Self.mentions(name, in: root, pattern: drawnByValue), "the shell's root does not draw .\(name)")
        }
        for name in try pages {
            XCTAssertTrue(Self.mentions(name, in: pushed, pattern: drawnByCase), "the shell's pushed switch does not draw .\(name)")
        }
        for name in try covers {
            XCTAssertTrue(Self.mentions(name, in: cover, pattern: drawnByCase), "the shell's cover switch does not draw .\(name)")
        }
    }
}
