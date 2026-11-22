// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import DishEngine
import XCTest
@testable import Dish

/// Report a problem as one state: the draft a problem and a question start
/// from, the six categories, the controllers by name, what the file holds,
/// the actions waiting for a category and for the file in the works, the
/// preview of this very draft, and the mail with the person's words first.
final class ReportMappersTests: XCTestCase {

    private let english = Locale(identifier: "en_US")

    private static let steam = ControllerFact(
        id: "ble:pad",
        name: "Valve Steam Controller (2026, Bluetooth)",
        link: .bluetooth,
        batteryPercent: nil,
        destination: DestinationFact(name: "Den PC", health: .online),
        source: .bluetooth(vendorId: 0x28DE, productId: 0x1303),
        record: ControllerRecordFact(id: "valve-steam-controller-2026-bluetooth", verification: .verified)
    )

    private static let onScreen = ControllerFact(id: onScreenSlotId, name: "", link: .onScreen, batteryPercent: nil, destination: nil)

    private static let strings = ControllerStrings(tables: ["en": [
        "controller.valve-steam-controller-2026-bluetooth.name": "Valve Steam Controller (2026, Bluetooth)"
    ]])

    private static let database = ControllerDbFacts(
        status: ControllerDbStatus(
            bundledVersion: 1,
            activeVersion: 3,
            source: .cache,
            checksEnabled: true,
            lastCheckAtMs: 1_795_122_251_000,
            lastCheckResult: .updated
        ),
        strings: strings
    )

    private func facts(
        _ controllers: [ControllerFact] = [ReportMappersTests.onScreen, ReportMappersTests.steam],
        preparation: ReportPreparation = .idle
    ) -> ReportFacts {
        ReportFacts(controllers: controllers, localNetwork: .allowed, controllerDb: Self.database, preparation: preparation)
    }

    private func page(
        _ start: ReportStart = .problem,
        facts: ReportFacts? = nil,
        draft: ReportDraftState = ReportDraftState(category: .noFeedback, text: "It never rumbles.", controllerId: "ble:pad"),
        words: L10n = .app
    ) throws -> ReportPageState {
        try reportPageState(
            start: start,
            facts: facts ?? self.facts(),
            draft: draft,
            appVersion: "1.1.0",
            locale: english,
            timeZone: XCTUnwrap(TimeZone(identifier: "UTC")),
            words: words
        )
    }

    // MARK: - Where the draft starts

    func testAProblemStartsWithNoCategoryAndTheFirstPadConnected() {
        XCTAssertEqual(initialReportDraft(.problem, facts: facts()), ReportDraftState(category: nil, text: "", controllerId: "ble:pad"))
    }

    func testAQuestionStartsOnTheQuestion() {
        XCTAssertEqual(initialReportDraft(.question, facts: facts()).category, .question)
    }

    func testWithNoPadConnectedNoControllerIsPicked() {
        XCTAssertNil(initialReportDraft(.problem, facts: facts([Self.onScreen])).controllerId)
    }

    // MARK: - The form

    func testTheTitleIsTheEntryTheReportOpenedFrom() throws {
        XCTAssertEqual(try page(.problem).title, "Report a problem")
        XCTAssertEqual(try page(.question).title, "Ask a question")
    }

    func testTheSixCategoriesAreWordedInTheContractsOrder() throws {
        XCTAssertEqual(try page().categories.map(\.label), [
            "Controller not recognised",
            "No rumble or feedback",
            "Connection or latency",
            "Audio",
            "Something else",
            "A question"
        ])
    }

    func testNothingPickedYetOffersChooseOneFirst() throws {
        let state = try page(draft: ReportDraftState(category: nil, text: "", controllerId: nil))
        XCTAssertEqual(state.categories.first, ReportChoice(value: nil, label: "Choose one"))
        XCTAssertEqual(state.categories.count, 7)
    }

    func testTheControllersAreNoneThenEachByItsName() throws {
        XCTAssertEqual(try page().controllers.map(\.label), ["None", "On-screen gamepad", "Valve Steam Controller (2026, Bluetooth)"])
        XCTAssertEqual(try page().controllers.map(\.value), [nil, onScreenSlotId, "ble:pad"])
    }

    func testTheFileIsDescribedInPlainWordsWithWhatItNeverHolds() throws {
        let state = try page()
        XCTAssertEqual(state.holdsTitle, "The file will hold")
        XCTAssertEqual(state.holds.count, 7)
        XCTAssertEqual(state.holds.first, "Your words and the category you picked")
        XCTAssertEqual(state.holds[4], "Your answers on each controller’s tests", "the bench's answers ride the file")
        XCTAssertEqual(
            state.never,
            "The file holds this page and its log, never pairing keys, fingerprints, IP addresses, Wi-Fi names or PC names."
        )
        XCTAssertEqual(state.prompt, "What happened, and what did you expect?")
    }

    // MARK: - The actions

    func testWithACategoryPickedBothActionsAreOpen() throws {
        let state = try page()
        XCTAssertTrue(state.actionsEnabled)
        XCTAssertEqual(state.draft, ReportDraft(category: .noFeedback, text: "It never rumbles.", controllerId: "ble:pad"))
        XCTAssertNil(state.status)
    }

    func testWithNoCategoryNeitherActionIsOpen() throws {
        let state = try page(draft: ReportDraftState(category: nil, text: "words", controllerId: nil))
        XCTAssertFalse(state.actionsEnabled)
        XCTAssertNil(state.draft)
        XCTAssertNil(state.mail)
    }

    func testWhileTheFileIsInTheWorksTheActionsWaitAndSaySo() throws {
        let draft = ReportDraft(category: .noFeedback, text: "It never rumbles.", controllerId: "ble:pad")
        let state = try page(facts: facts(preparation: .preparing(draft)))
        XCTAssertFalse(state.actionsEnabled)
        XCTAssertEqual(state.status, "Asking your PCs and writing the file…")
    }

    func testAFileThatCouldNotBeWrittenSaysSo() throws {
        let draft = ReportDraft(category: .noFeedback, text: "x", controllerId: nil)
        let state = try page(facts: facts(preparation: .failed(draft)))
        XCTAssertEqual(state.status, "The file could not be written. Try again.")
        XCTAssertTrue(state.actionsEnabled, "the person may try again")
    }

    // MARK: - The preview

    func testThePreviewIsTheFileMadeForThisVeryDraft() throws {
        let draft = ReportDraft(category: .noFeedback, text: "It never rumbles.", controllerId: "ble:pad")
        let prepared = PreparedReport(file: URL(fileURLWithPath: "/tmp/x.json"), text: "{ \"bundle\" : 1 }")
        XCTAssertEqual(try page(facts: facts(preparation: .ready(draft, prepared))).file, "{ \"bundle\" : 1 }")
    }

    func testAPreviewOfAnEarlierDraftIsNotShown() throws {
        let earlier = ReportDraft(category: .noFeedback, text: "earlier", controllerId: "ble:pad")
        let prepared = PreparedReport(file: URL(fileURLWithPath: "/tmp/x.json"), text: "{}")
        XCTAssertNil(try page(facts: facts(preparation: .ready(earlier, prepared))).file)
    }

    func testNothingPreviewedShowsNoFile() throws {
        XCTAssertNil(try page().file)
    }

    // MARK: - The mail

    func testTheMailPutsThePersonsWordsFirstThenTheSummaryThenTheSentence() throws {
        let mail = try XCTUnwrap(try page().mail)
        XCTAssertEqual(mail.category, "No rumble or feedback")
        XCTAssertEqual(mail.body, """
        It never rumbles.

        Dish
        App version: 1.1.0
        Protocol: v4
        Local Network: Allowed
        Controller database: Version 3, downloaded
        Built-in version: v1
        Last check: Updated · Nov 19, 2026 at 9:04\u{202F}PM

        Controllers
        On-screen gamepad
        Valve Steam Controller (2026, Bluetooth)
        Name: Valve Steam Controller (2026, Bluetooth)
        Record: valve-steam-controller-2026-bluetooth
        Verification: Verified

        The file holds this page and its log, never pairing keys, fingerprints, IP addresses, Wi-Fi names or PC names.
        """)
    }

    func testTheMailNamesNoPC() throws {
        let body = try XCTUnwrap(try page().mail?.body)
        XCTAssertFalse(body.contains("Den PC"), body)
    }

    func testAMailWithNoWordsOpensOnTheSummary() throws {
        let body = try XCTUnwrap(try page(draft: ReportDraftState(category: .question, text: "", controllerId: nil)).mail?.body)
        XCTAssertTrue(body.hasPrefix("Dish\n"), body)
    }

    func testTheSubjectsCategoryIsInThePersonsLanguage() throws {
        let german = try page(words: L10nFixture.language("de"))
        XCTAssertEqual(german.mail?.category, "Keine Vibration oder Rückmeldung")
    }
}
