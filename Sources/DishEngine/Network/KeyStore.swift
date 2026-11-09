// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import Foundation
import os
import Security
import Synchronization

/// Storage for per-satellite pairing keys (64-char hex), keyed by the stable
/// satellite id (`mid:<machineId>` or `wifi:<ip>:<port>`). The pairing key
/// is the trust root of the protocol, so production keeps it in the
/// Keychain; tests inject the in-memory store. Safe from any thread.
package protocol KeyStore: Sendable {
    /// The stored key, or nil when absent or unreadable.
    func pairingKeyHex(for id: String) -> String?
    /// Insert or replace a key; false when the backing store refused it.
    @discardableResult
    func setPairingKeyHex(_ keyHex: String, for id: String) -> Bool
    /// Removing an absent key is a no-op.
    func removePairingKey(for id: String)
}

/// One generic-password item per satellite under Dish's service, readable
/// after the first unlock and never migrated to another device.
package final class KeychainKeyStore: KeyStore {
    static let service = "com.tinkernorth.dish.ios.pairing-key"

    private static let log = Logger(subsystem: "com.tinkernorth.dish.ios", category: "keystore")

    package init() {}

    package func pairingKeyHex(for id: String) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Self.log.error("keychain read failed (\(status, privacy: .public))")
            }
            return nil
        }
        guard let data = item as? Data, let hex = String(data: data, encoding: .utf8), !hex.isEmpty else { return nil }
        return hex
    }

    @discardableResult
    package func setPairingKeyHex(_ keyHex: String, for id: String) -> Bool {
        let payload = Data(keyHex.utf8)
        var add = baseQuery(for: id)
        add[kSecValueData as String] = payload
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        var status = SecItemAdd(add as CFDictionary, nil)
        if status == errSecDuplicateItem {
            status = SecItemUpdate(baseQuery(for: id) as CFDictionary, [kSecValueData as String: payload] as CFDictionary)
        }
        if status != errSecSuccess {
            Self.log.error("keychain write failed (\(status, privacy: .public))")
        }
        return status == errSecSuccess
    }

    package func removePairingKey(for id: String) {
        let status = SecItemDelete(baseQuery(for: id) as CFDictionary)
        if status != errSecSuccess, status != errSecItemNotFound {
            Self.log.error("keychain delete failed (\(status, privacy: .public))")
        }
    }

    private func baseQuery(for id: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: id
        ]
    }
}

/// The same contract over a dictionary, for tests and the loopback driver,
/// which run without a Keychain entitlement.
package final class InMemoryKeyStore: KeyStore {
    private let keys = Mutex<[String: String]>([:])

    package init() {}

    package func pairingKeyHex(for id: String) -> String? {
        keys.withLock { $0[id] }
    }

    @discardableResult
    package func setPairingKeyHex(_ keyHex: String, for id: String) -> Bool {
        keys.withLock { $0[id] = keyHex }
        return true
    }

    package func removePairingKey(for id: String) {
        keys.withLock { $0[id] = nil }
    }
}
