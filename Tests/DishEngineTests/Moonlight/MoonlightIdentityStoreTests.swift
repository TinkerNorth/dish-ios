// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Security
import XCTest
@testable import DishEngine

/// The dish's Moonlight identity: a certificate iOS parses with the reference
/// subject, minted over a key born in memory here (the keychain the app's
/// copy lives in is not open to a package test bundle on the simulator), a
/// key that signs and a verifier that checks with the certificate's own, an
/// identity mutual TLS can present, and the keychain copy read back the
/// same when the runner has one.
final class MoonlightIdentityStoreTests: XCTestCase {

    private func freshKey() throws -> SecKey {
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048]
        return try XCTUnwrap(SecKeyCreateRandomKey(attributes as CFDictionary, nil), "no RSA keys on this runner")
    }

    func testTheMintedCertificateIsOneIOSParsesWithTheReferenceSubject() throws {
        let der = try XCTUnwrap(MoonlightCertificateMint.selfSigned(privateKey: freshKey()))
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
        XCTAssertEqual(SecCertificateCopySubjectSummary(certificate) as String?, MoonlightCertificateMint.subjectCommonName)
        XCTAssertNotNil(SecCertificateCopyKey(certificate), "the public key is readable")
        let identity = MoonlightIdentityStore(certificateDER: der, source: .keychain)
        XCTAssertEqual(identity.certificateSignature.count, 256, "an RSA-2048 signature")
        XCTAssertEqual(MoonlightCertificate.der(fromPem: identity.certificatePem), der, "the PEM round-trips")
        XCTAssertTrue(identity.certificatePem.hasPrefix("-----BEGIN CERTIFICATE-----\n"))
        XCTAssertEqual(identity.fingerprintHex.count, 64)
    }

    func testAnImportedIdentityCarriesTheReferenceSubjectAndSigns() throws {
        let identity = try XCTUnwrap(MoonlightIdentityFixtures.client())
        let certificate = try XCTUnwrap(SecCertificateCreateWithData(nil, identity.certificateDER as CFData))
        XCTAssertEqual(SecCertificateCopySubjectSummary(certificate) as String?, MoonlightCertificateMint.subjectCommonName)
        let secret = Data((0 ..< 16).map { UInt8($0) })
        let signature = try XCTUnwrap(identity.sign(secret))
        XCTAssertEqual(signature.count, 256)
        XCTAssertTrue(identity.verify(certificatePem: identity.certificatePem, data: secret, signature: signature))
        var forged = signature
        forged[0] ^= 0x01
        XCTAssertFalse(identity.verify(certificatePem: identity.certificatePem, data: secret, signature: forged))
        XCTAssertFalse(identity.verify(certificatePem: "not a certificate", data: secret, signature: signature))
    }

    func testTheVerifierChecksWithTheCertificateItIsHandedNotItsOwn() throws {
        let client = try XCTUnwrap(MoonlightIdentityFixtures.client())
        let host = try XCTUnwrap(MoonlightIdentityFixtures.host())
        let secret = Data((0 ..< 16).map { UInt8($0) })
        let signature = try XCTUnwrap(host.sign(secret))
        XCTAssertTrue(client.verify(certificatePem: host.certificatePem, data: secret, signature: signature))
        XCTAssertFalse(client.verify(certificatePem: client.certificatePem, data: secret, signature: signature), "the wrong key")
    }

    func testAnIdentityMutualTlsCanPresent() throws {
        let identity = try XCTUnwrap(MoonlightIdentityFixtures.client())
        XCTAssertNotNil(identity.secIdentity(), "the key and the certificate came in together")
        XCTAssertNil(MoonlightIdentityStore.imported(pkcs12: Data([0x30, 0x00]), passphrase: "dish"), "not a PKCS#12")
        XCTAssertNil(
            MoonlightIdentityStore.imported(
                pkcs12: Data(base64Encoded: MoonlightIdentityFixtures.clientBlob) ?? Data(),
                passphrase: "wrong"
            ),
            "the wrong passphrase"
        )
    }

    func testTheKeychainItemsStayOnThisDeviceAndOpenAfterTheFirstUnlock() {
        let accessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        let key = MoonlightIdentityStore.privateKeyAttributes()
        XCTAssertEqual(key[kSecAttrAccessible] as? String, accessible, "the key matches the pairing key's accessibility")
        XCTAssertEqual(key[kSecAttrIsPermanent] as? Bool, true)
        let certificate = MoonlightIdentityStore.certificateAttributes()
        XCTAssertEqual(certificate[kSecAttrAccessible] as? String, accessible, "so does the certificate")
    }

    func testTheKeychainCopyIsMintedOnceAndReadBackTheSame() throws {
        guard let first = MoonlightIdentityStore.loadOrCreate() else {
            throw XCTSkip("no keychain on this runner: a package test bundle on the simulator has no keychain access")
        }
        let second = try XCTUnwrap(MoonlightIdentityStore.loadOrCreate())
        XCTAssertEqual(first.certificateDER, second.certificateDER, "the same identity for every host, every launch")
        XCTAssertEqual(first.fingerprintHex, second.fingerprintHex)
        XCTAssertNotNil(first.secIdentity(), "the key was born in the keychain")
    }
}
