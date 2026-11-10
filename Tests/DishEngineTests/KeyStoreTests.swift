// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Pairing keys live behind the KeyStore seam: the Keychain in production,
// in memory for tests. iOS never kept one in UserDefaults, so dish-mac's
// migration has nothing to move here.

import XCTest
@testable import DishEngine

final class KeyStoreTests: XCTestCase {

    // MARK: - InMemoryKeyStore contract

    func testInMemoryRoundTrip() {
        let store = InMemoryKeyStore()
        XCTAssertNil(store.pairingKeyHex(for: "mid:a"))
        XCTAssertTrue(store.setPairingKeyHex("aa11", for: "mid:a"))
        XCTAssertEqual(store.pairingKeyHex(for: "mid:a"), "aa11")
        store.setPairingKeyHex("bb22", for: "mid:a")
        XCTAssertEqual(store.pairingKeyHex(for: "mid:a"), "bb22")
        store.removePairingKey(for: "mid:a")
        XCTAssertNil(store.pairingKeyHex(for: "mid:a"))
        // Removing an absent key is a no-op, not a crash.
        store.removePairingKey(for: "mid:a")
    }

    func testInMemoryKeysAreIsolatedPerId() {
        let store = InMemoryKeyStore()
        store.setPairingKeyHex("aa", for: "mid:a")
        store.setPairingKeyHex("bb", for: "wifi:1.2.3.4:9876")
        XCTAssertEqual(store.pairingKeyHex(for: "mid:a"), "aa")
        XCTAssertEqual(store.pairingKeyHex(for: "wifi:1.2.3.4:9876"), "bb")
        store.removePairingKey(for: "mid:a")
        XCTAssertEqual(store.pairingKeyHex(for: "wifi:1.2.3.4:9876"), "bb")
    }

    // MARK: - KeychainKeyStore (skips when the environment refuses Keychain writes)

    func testKeychainRoundTripWhenAvailable() throws {
        let store = KeychainKeyStore()
        // Unique account so parallel/repeated runs never collide; always
        // cleaned up.
        let id = "dish-test:\(UUID().uuidString)"
        defer { store.removePairingKey(for: id) }

        guard store.setPairingKeyHex("cafe01", for: id) else {
            throw XCTSkip("Keychain refused the write in this environment (headless CI?)")
        }
        XCTAssertEqual(store.pairingKeyHex(for: id), "cafe01")
        // Second write must replace, not duplicate.
        XCTAssertTrue(store.setPairingKeyHex("cafe02", for: id))
        XCTAssertEqual(store.pairingKeyHex(for: id), "cafe02")
        store.removePairingKey(for: id)
        XCTAssertNil(store.pairingKeyHex(for: id))
    }

    /// A package test bundle on the simulator has no Keychain entitlement,
    /// so the Keychain refuses every write there; the store says so instead
    /// of claiming a key it did not keep.
    func testAKeychainThatRefusesTheWriteReportsIt() {
        let store = KeychainKeyStore()
        let id = "dish-test:\(UUID().uuidString)"
        defer { store.removePairingKey(for: id) }
        let kept = store.setPairingKeyHex("cafe01", for: id)
        XCTAssertEqual(store.pairingKeyHex(for: id) != nil, kept, "a refused write leaves no key behind")
    }
}
