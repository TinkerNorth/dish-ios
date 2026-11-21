// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// The controller database's words: a pad's record on its page and its
/// card, in the database's strings with English for what a language left
/// out; the verification's chip; and Settings' switch, line and Check now.
final class ControllerDbMappersTests: XCTestCase {

    private static let strings = ControllerStrings(tables: [
        "en": [
            "controller.valve-steam-controller-2026-bluetooth.name": "Valve Steam Controller (2026, Bluetooth)",
            "issue.triton-ble-lag.title": "Input arrives late",
            "issue.triton-ble-lag.body": "Being investigated."
        ],
        "de": ["issue.triton-ble-lag.title": "Eingaben kommen spät an"]
    ])

    private static let record = ControllerRecordFact(
        id: "valve-steam-controller-2026-bluetooth",
        verification: .verified,
        issues: [ControllerIssue(id: "triton-ble-lag", transport: .bluetooth), ControllerIssue(id: "untitled")]
    )

    private func pad(source: PadSource?, record: ControllerRecordFact? = nil) -> ControllerFact {
        ControllerFact(
            id: "pad",
            name: "Valve Steam Controller (2026, Bluetooth)",
            link: .bluetooth,
            batteryPercent: nil,
            destination: nil,
            source: source,
            record: record
        )
    }

    private static let steam = PadSource.bluetooth(vendorId: 0x28DE, productId: 0x1303)

    // MARK: - The record

    func testASteamControllersRecordShowsItsNameItsIdItsChipAndItsIssues() throws {
        let state = try XCTUnwrap(controllerRecordState(pad(source: Self.steam, record: Self.record), strings: Self.strings))
        XCTAssertEqual(state.title, "Controller database")
        XCTAssertEqual(state.lines, [
            FactLine(key: "Name", value: "Valve Steam Controller (2026, Bluetooth)"),
            FactLine(key: "Record", value: "valve-steam-controller-2026-bluetooth"),
            FactLine(key: "Verification", value: "Verified")
        ])
        XCTAssertEqual(state.chip, VerificationChipState(text: "Verified", tone: .success))
        XCTAssertEqual(state.issues, [
            ControllerIssueState(id: "triton-ble-lag", title: "Input arrives late", body: "Being investigated."),
            ControllerIssueState(id: "untitled", title: "Known issue", body: "untitled")
        ])
    }

    func testAPadTheDatabaseLacksSaysSoAndWearsNoChip() throws {
        let state = try XCTUnwrap(controllerRecordState(pad(source: .bluetooth(vendorId: 1, productId: 2)), strings: Self.strings))
        XCTAssertEqual(state.lines, [FactLine(key: "Record", value: "Not in the controller database")])
        XCTAssertNil(state.chip)
        XCTAssertEqual(state.issues, [])
    }

    func testAPadGameControllerReadsShowsNothingFromTheDatabase() {
        XCTAssertNil(controllerRecordState(pad(source: .gameController(category: "Xbox One")), strings: Self.strings))
        XCTAssertEqual(recordLines(pad(source: .gameController(category: "Xbox One")), strings: Self.strings), [])
        XCTAssertNil(controllerRecordState(pad(source: nil), strings: Self.strings), "nor does the on-screen controller")
    }

    func testARecordWhoseNameTheStringsLackShowsItsIdAlone() {
        let lines = recordLines(pad(source: Self.steam, record: Self.record), strings: ControllerStrings(tables: [:]))
        XCTAssertEqual(lines.map(\.key), ["Record", "Verification"])
    }

    func testTheIssuesReadInTheCatalogsLanguageWithEnglishForWhatItLeftOut() {
        let german = ControllerStrings(tables: Self.strings.tables)
        let lines = issueLines(pad(source: Self.steam, record: Self.record), strings: german, words: L10nFixture.language("de"))
        XCTAssertEqual(lines.first, FactLine(key: "Eingaben kommen spät an", value: "Being investigated."))
    }

    func testTheDatabaseIsReadInTheLanguageTheAppResolvedItsOwnWordsIn() {
        let app = L10n.app
        XCTAssertEqual(app.databaseLocale, app.catalog.locale.identifier)
        XCTAssertEqual(
            app.databaseLocale,
            app.catalog.bundle.preferredLocalizations.first ?? "en",
            "the bundle's own pick, as the catalog reads it"
        )
        for language in ["de", "pt-BR", "bs"] {
            XCTAssertEqual(L10nFixture.language(language).databaseLocale, language)
        }
    }

    func testEachVerificationHasItsWordAndItsTone() {
        let chips = ControllerVerification.allCases.map { verificationChip($0) }
        XCTAssertEqual(chips.map(\.text), ["Verified", "Imported", "Reported by players", "Layout guessed", "Problems reported"])
        XCTAssertEqual(chips.map(\.tone), [.success, .primary, .primary, .warning, .warning])
    }

    // MARK: - The data

    private static let bundled = ControllerDbStatus(bundledVersion: 1, activeVersion: 1, source: .bundled, checksEnabled: true)

    func testTheVersionSaysWhereItCameFrom() {
        XCTAssertEqual(databaseVersionText(Self.bundled), "Version 1, built in")
        let cached = ControllerDbStatus(bundledVersion: 1, activeVersion: 4, source: .cache, checksEnabled: true)
        XCTAssertEqual(databaseVersionText(cached), "Version 4, downloaded")
    }

    func testEachResultHasItsWord() {
        let words = ControllerDbCheckResult.allCases.map { checkResultText($0) }
        XCTAssertEqual(words, ["Up to date", "Updated", "No connection", "The download did not verify", "Checks are off"])
    }

    func testBeforeTheFirstCheckItSaysSoAndWithTheSwitchOffItSaysOff() {
        XCTAssertEqual(lastCheckText(Self.bundled), "Not checked yet")
        let off = ControllerDbStatus(
            bundledVersion: 1,
            activeVersion: 1,
            source: .bundled,
            checksEnabled: false,
            lastCheckResult: .upToDate
        )
        XCTAssertEqual(lastCheckText(off), "Checks are off")
    }

    func testDiagnosticsWithNoCheckYetGivesNoTime() {
        XCTAssertEqual(controllerDbLines(Self.bundled).last, FactLine(key: "Last check", value: "Not checked yet"))
    }

    // MARK: - Settings

    func testSettingsOffersTheSwitchInThePolicysWordsAndCheckNow() {
        XCTAssertEqual(controllerDbSection(Self.bundled), ControllerDbSectionState(
            title: "Controller database",
            toggleTitle: "Check for controller updates automatically",
            isOn: true,
            line: "Version 1, built in · Not checked yet",
            checkNow: "Check now",
            canCheckNow: true,
            footer: "Dish asks dish.tinkernorth.com for a newer list of the controllers it knows. It fetches data, never code, and sends nothing about you."
        ))
    }

    func testACheckUnderWaySaysSoAndCannotBeTappedAgain() {
        let checking = ControllerDbStatus(bundledVersion: 1, activeVersion: 1, source: .bundled, checksEnabled: true, checking: true)
        let section = controllerDbSection(checking)
        XCTAssertEqual(section.checkNow, "Checking…")
        XCTAssertFalse(section.canCheckNow)
    }

    func testWithTheSwitchOffCheckNowIsNotOffered() {
        let off = ControllerDbStatus(bundledVersion: 1, activeVersion: 1, source: .bundled, checksEnabled: false)
        let section = controllerDbSection(off)
        XCTAssertFalse(section.isOn)
        XCTAssertFalse(section.canCheckNow)
        XCTAssertEqual(section.line, "Version 1, built in · Checks are off")
    }

    func testTheLabelsAreThePrivacyPolicysInEveryLanguage() {
        let labels = [
            "bs": ("Automatski provjeravaj ažuriranja kontrolera", "Provjeri sada"),
            "de": ("Automatisch nach Controller-Updates suchen", "Jetzt prüfen"),
            "es": ("Buscar actualizaciones de mandos automáticamente", "Comprobar ahora"),
            "fr": ("Rechercher les mises à jour des manettes automatiquement", "Vérifier maintenant"),
            "pt-BR": ("Verificar atualizações de controles automaticamente", "Verificar agora")
        ]
        for (language, label) in labels {
            let words = L10nFixture.language(language)
            XCTAssertEqual(words.checkForControllerUpdatesAutomatically, label.0, language)
            XCTAssertEqual(words.checkNow, label.1, language)
        }
    }
}
