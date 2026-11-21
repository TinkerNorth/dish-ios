// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import XCTest
@testable import DishEngine

/// The controller data's check against the website through the store: the
/// schedule ten seconds after launch and six hours after each check while
/// in the foreground, the switch that keeps every request on the device,
/// Check now, the manifest's ETag, the download verified and swapped in
/// whole, and every way a check can end leaving the previous set in force.
@MainActor
final class ControllerDbStoreTests: XCTestCase {

    private let gateway = ScriptedControllerDbGateway()
    private let ticker = ManualTicker()
    private let clock = ManualNow()
    private var defaults: UserDefaults!
    private var folder: URL!

    override func setUp() async throws {
        defaults = try TestDefaults.fresh(self)
        folder = freshCacheFolder(self)
    }

    private func store() -> ControllerDbStore {
        let clock = clock
        return ControllerDbStore(
            bundled: BundledControllerDb.load() ?? .empty,
            cache: ControllerDbCache(directory: folder),
            gateway: gateway,
            preferences: ControllerDbPreferenceStore(defaults: defaults),
            ticker: ticker,
            now: { Int64(clock.read().timeIntervalSince1970 * 1000) }
        )
    }

    private var nowMs: Int64 {
        Int64(clock.read().timeIntervalSince1970 * 1000)
    }

    // MARK: - What is in force

    func testTheBundledCopyIsInForceBeforeAnyCheck() {
        let status = store().status
        XCTAssertEqual(status.bundledVersion, 1)
        XCTAssertEqual(status.activeVersion, 1)
        XCTAssertEqual(status.source, .bundled)
        XCTAssertTrue(status.checksEnabled, "the switch is on in a fresh install")
        XCTAssertNil(status.lastCheckResult)
        XCTAssertNil(status.lastCheckAtMs)
    }

    func testTheBundledIndexKnowsTheSteamControllerOverBluetooth() {
        XCTAssertEqual(store().index.record(bluetooth: "28de:1303")?.id, "valve-steam-controller-2026-bluetooth")
    }

    // MARK: - The schedule

    func testTheFirstCheckIsArmedTenSecondsAfterLaunch() {
        store().resume()
        XCTAssertEqual(ticker.starts, [10])
        XCTAssertEqual(gateway.requests, [], "nothing is asked before it is due")
    }

    func testADueCheckAsksForTheManifestThenArmsTheNextSixHoursOut() async {
        let store = store()
        store.resume()
        ticker.fire()
        await store.settle()
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil)])
        XCTAssertEqual(ticker.starts, [10, 21600])
        XCTAssertEqual(store.status.lastCheckResult, .offline)
        XCTAssertEqual(store.status.lastCheckAtMs, nowMs)
    }

    func testNothingIsArmedInTheBackground() {
        let store = store()
        store.resume()
        store.pause()
        XCTAssertFalse(ticker.running)
    }

    func testBackInTheForegroundTheNextCheckCountsFromTheLastOne() async {
        let store = store()
        store.resume()
        ticker.fire()
        await store.settle()
        store.pause()
        clock.date = clock.date.addingTimeInterval(3600)
        store.resume()
        XCTAssertEqual(ticker.starts.last, 18000, "five hours are left of the six")
    }

    // MARK: - The switch

    func testWithTheSwitchOffNoRequestLeavesTheDevice() async {
        let store = store()
        store.setChecksEnabled(false)
        store.resume()
        ticker.fire()
        store.checkNow()
        store.pause()
        store.resume()
        ticker.fire()
        await store.settle()
        XCTAssertEqual(gateway.requests, [], "no schedule, no Check now and no return to the foreground asks anything")
        XCTAssertFalse(ticker.running)
        XCTAssertEqual(store.status.lastCheckResult, .off)
    }

    func testTheSwitchIsRemembered() {
        store().setChecksEnabled(false)
        XCTAssertFalse(store().status.checksEnabled)
        XCTAssertEqual(defaults.object(forKey: ControllerDbPreferenceStore.checksEnabledKey) as? Bool, false)
    }

    func testTurningTheSwitchOffStopsTheArmedCheck() {
        let store = store()
        store.resume()
        store.setChecksEnabled(false)
        XCTAssertFalse(ticker.running)
    }

    func testTurningTheSwitchBackOnArmsTheNextCheck() {
        let store = store()
        store.resume()
        store.setChecksEnabled(false)
        store.setChecksEnabled(true)
        XCTAssertTrue(ticker.running)
        XCTAssertEqual(ticker.starts.last, 10)
    }

    // MARK: - Check now

    func testCheckNowAsksWhateverTheSchedule() async {
        let store = store()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil)])
    }

    func testACheckUnderWayShowsAndASecondTapAsksNothingMore() async {
        let store = store()
        store.checkNow()
        XCTAssertTrue(store.status.checking)
        store.checkNow()
        await store.settle()
        XCTAssertFalse(store.status.checking)
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil)])
    }

    // MARK: - The manifest

    func testANotModifiedManifestIsUpToDate() async {
        gateway.answer(manifest: .notModified)
        let store = store()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(store.status.lastCheckResult, .upToDate)
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil)])
    }

    func testAManifestNoNewerIsUpToDateAndItsETagIsSentNextTime() async throws {
        let bundledManifest = try XCTUnwrap(BundledControllerDb.files()[ControllerDbFiles.manifest])
        gateway.answer(manifest: .body(bundledManifest, etag: "\"v1\""))
        let store = store()
        store.checkNow()
        await store.settle()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(store.status.lastCheckResult, .upToDate)
        XCTAssertEqual(gateway.requests, [.manifest(etag: nil), .manifest(etag: "\"v1\"")])
    }

    func testAManifestThatIsNotOneIsInvalid() async {
        gateway.answer(manifest: .body(Data("<html>".utf8), etag: nil))
        let store = store()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(store.status.lastCheckResult, .invalid)
    }

    // MARK: - The download

    func testANewerVersionIsDownloadedVerifiedAndPutInForceWhole() async {
        gateway.serve(Self.published)
        let store = store()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(store.status.lastCheckResult, .updated)
        XCTAssertEqual(store.status.activeVersion, 2)
        XCTAssertEqual(store.status.source, .cache)
        XCTAssertNil(
            store.index.record(bluetooth: "28de:1106"),
            "the newer set replaces the bundled one, record by record it is not merged"
        )
        XCTAssertEqual(store.index.record(bluetooth: "28de:1303")?.issues.map(\.id), ["triton-ble-lag", "triton-usb-only"])
        let asked = gateway.requests
        XCTAssertEqual(asked.first, .manifest(etag: nil))
        XCTAssertEqual(Set(asked.dropFirst()), [.file("controllers.json"), .file("strings/en.json"), .file("strings/de.json")])
    }

    func testTheDownloadedSetIsInForceAtTheNextLaunch() async {
        gateway.serve(Self.published)
        let first = store()
        first.checkNow()
        await first.settle()
        let next = store()
        XCTAssertEqual(next.status.activeVersion, 2)
        XCTAssertEqual(next.status.source, .cache)
    }

    func testAFileThatDoesNotMatchTheManifestLeavesTheBundledSetInForce() async {
        var published = Self.published
        published[ControllerDbFiles.strings("de")] = Data("{}".utf8)
        gateway.serve(published)
        let checked = store()
        checked.checkNow()
        await checked.settle()
        XCTAssertEqual(checked.status.lastCheckResult, .invalid)
        XCTAssertEqual(checked.status.activeVersion, 1)
        XCTAssertEqual(store().status.source, .bundled, "nothing was written")
    }

    func testAFileThatDoesNotArriveIsOfflineAndLeavesTheSetInForce() async {
        var published = Self.published
        published[ControllerDbFiles.strings("de")] = nil
        gateway.serve(published)
        let store = store()
        store.checkNow()
        await store.settle()
        XCTAssertEqual(store.status.lastCheckResult, .offline)
        XCTAssertEqual(store.status.activeVersion, 1)
    }

    func testACacheSomeoneChangedIsNotUsed() async throws {
        gateway.serve(Self.published)
        let first = store()
        first.checkNow()
        await first.settle()
        try Data("{}".utf8).write(to: folder.appendingPathComponent(ControllerDbFiles.controllers))
        XCTAssertEqual(store().status.source, .bundled)
    }

    private static let published = ControllerDbFixtures.publishedFiles(version: 2)
}
