// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// Two RSA-2048 identities the Moonlight suites play: the dish's (subject
// `CN=NVIDIA GameStream Client`, as the reference clients present it) and a
// host's. dish-mac mints both at run time inside a throwaway file keychain,
// which iOS does not have, and a package test bundle on the simulator has
// no keychain entitlement either, so the two are PKCS#12 fixtures (made
// once with OpenSSL, `-legacy` so Security reads them, passphrase `dish`)
// that `MoonlightIdentityStore.imported` opens in memory.

import Foundation
@testable import DishEngine

enum MoonlightIdentityFixtures {
    static let passphrase = "dish"

    /// The dish's identity, the one a host is asked to pair with.
    static func client() -> MoonlightIdentityStore? {
        imported(clientBlob)
    }

    /// A host's identity: it signs the pairing and presents itself over TLS.
    static func host() -> MoonlightIdentityStore? {
        imported(hostBlob)
    }

    private static func imported(_ fixture: String) -> MoonlightIdentityStore? {
        guard let blob = Data(base64Encoded: fixture) else { return nil }
        return MoonlightIdentityStore.imported(pkcs12: blob, passphrase: passphrase)
    }

    static let clientBlob = """
    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
    """

    static let hostBlob = """
    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
    """
}
