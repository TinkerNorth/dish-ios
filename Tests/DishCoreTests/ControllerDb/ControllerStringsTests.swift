// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest

/// The database's words: the locale's own table, else its language's, else
/// English; a strings file is a flat object of string to string.
final class ControllerStringsTests: XCTestCase {

    private let strings = ControllerStrings(tables: [
        "en": ["issue.a.title": "Late", "issue.a.body": "Being investigated.", "controller.pad.name": "Pad"],
        "de": ["issue.a.title": "Spät"],
        "pt-BR": ["issue.a.title": "Atrasado"]
    ])

    func testTheLocalesOwnTableComesFirst() {
        XCTAssertEqual(strings.text("issue.a.title", locale: "de"), "Spät")
    }

    func testAKeyTheLocaleLeftOutReadsInEnglish() {
        XCTAssertEqual(strings.text("issue.a.body", locale: "de"), "Being investigated.")
    }

    func testARegionReadsItsLanguagesTable() {
        XCTAssertEqual(strings.text("issue.a.title", locale: "de-AT"), "Spät")
        XCTAssertEqual(strings.text("issue.a.title", locale: "pt"), "Atrasado")
        XCTAssertEqual(strings.text("issue.a.title", locale: "pt_PT"), "Atrasado")
    }

    func testALocaleWithNoTableReadsInEnglish() {
        XCTAssertEqual(strings.text("issue.a.title", locale: "ja"), "Late")
    }

    func testAKeyNoTableHasIsNil() {
        XCTAssertNil(strings.text("issue.b.title", locale: "en"))
    }

    func testTheNamedKeysFollowTheContract() {
        XCTAssertEqual(strings.controllerName("pad", locale: "fr"), "Pad")
        XCTAssertEqual(strings.issueTitle("a", locale: "de"), "Spät")
        XCTAssertEqual(strings.issueBody("a", locale: "de"), "Being investigated.")
    }

    func testAStringsFileIsAFlatObject() throws {
        let table = try decodeControllerStrings(ControllerDbFixtures.german).get()
        XCTAssertEqual(table["issue.triton-ble-lag.title"], "Eingaben kommen spät an")
    }

    func testAValueThatIsNotAStringRefusesTheFile() {
        XCTAssertEqual(decodeControllerStrings(Data(#"{ "a": "b", "c": 1 }"#.utf8)), .failure(.badJson))
    }

    func testAFileThatIsNotAnObjectIsRefused() {
        XCTAssertEqual(decodeControllerStrings(Data(#"["a"]"#.utf8)), .failure(.badJson))
        XCTAssertEqual(decodeControllerStrings(Data("nope".utf8)), .failure(.badJson))
    }

    func testEveryBundledLocaleParsesAndEnglishNamesBothSteamControllers() throws {
        let files = BundledControllerDb.files()
        for locale in ControllerStrings.locales {
            let data = try XCTUnwrap(files[ControllerDbFiles.strings(locale)], "strings/\(locale).json is bundled")
            XCTAssertNoThrow(try decodeControllerStrings(data).get(), locale)
        }
        let english = try decodeControllerStrings(XCTUnwrap(files[ControllerDbFiles.strings("en")])).get()
        XCTAssertEqual(english["controller.valve-steam-controller-bluetooth.name"], "Valve Steam Controller (Bluetooth)")
        XCTAssertEqual(english["controller.valve-steam-controller-2026-bluetooth.name"], "Valve Steam Controller (2026, Bluetooth)")
    }
}
