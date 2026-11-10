// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The dish's persistent Moonlight identity: one RSA-2048 key, born in the
// app's keychain so iOS can assemble the SecIdentity that mutual TLS
// presents, and the self-signed certificate around it, generated once and
// used for every host. The pairing signs with the key and hashes the
// certificate's signature bytes; every HTTPS call afterwards authenticates
// with the same key, which is how a host knows a paired client. The store
// carries the certificate and knows where the key lives; `SecKey` and
// `SecIdentity` are not `Sendable`, so each is looked up when a signature or
// a handshake needs it, which is rare.

import DishCore
import Foundation
import Security

final class MoonlightIdentityStore: MoonlightClientIdentity, MoonlightSignatureVerifier, Sendable {
    static let keyTag = Data("com.tinkernorth.dish.ios.moonlight-identity".utf8)
    static let keyLabel = "Dish Moonlight client key"
    static let certificateLabel = "Dish Moonlight client certificate"
    static let keyBits = 2048

    /// Where the private key lives: the app's keychain under the tag, or a
    /// PKCS#12 blob a test imports, since a package test bundle on the
    /// simulator has no keychain entitlement.
    enum Source {
        case keychain
        case pkcs12(blob: Data, passphrase: String)
    }

    let certificateDER: Data
    private let source: Source

    init(certificateDER: Data, source: Source) {
        self.certificateDER = certificateDER
        self.source = source
    }

    var certificatePem: String {
        MoonlightCertificate.pem(fromDer: certificateDER)
    }

    var certificateSignature: Data {
        MoonlightCertificate.signatureBytes(der: certificateDER) ?? Data()
    }

    var fingerprintHex: String {
        MoonlightCertificate.fingerprintHex(der: certificateDER)
    }

    func sign(_ data: Data) -> Data? {
        guard let key = privateKey() else { return nil }
        return SecKeyCreateSignature(key, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, nil) as Data?
    }

    /// The host's RSA-SHA256 signature, checked with the key inside the certificate it sent.
    func verify(certificatePem: String, data: Data, signature: Data) -> Bool {
        guard let der = MoonlightCertificate.der(fromPem: certificatePem),
              let certificate = SecCertificateCreateWithData(nil, der as CFData),
              let publicKey = SecCertificateCopyKey(certificate) else { return false }
        return SecKeyVerifySignature(publicKey, .rsaSignatureMessagePKCS1v15SHA256, data as CFData, signature as CFData, nil)
    }

    /// The identity mutual TLS presents, looked up afresh; nil when neither
    /// the keychain nor the blob yields one.
    func secIdentity() -> SecIdentity? {
        switch source {
        case .keychain: Self.findIdentity()
        case let .pkcs12(blob, passphrase): Self.importIdentity(blob, passphrase: passphrase)
        }
    }

    private func privateKey() -> SecKey? {
        switch source {
        case .keychain: Self.findKey()
        case let .pkcs12(blob, passphrase): Self.importIdentity(blob, passphrase: passphrase).flatMap(Self.privateKey(of:))
        }
    }

    /// The stored identity, or a fresh one minted into the keychain; nil
    /// when the keychain refuses, as it does for a test bundle on the
    /// simulator, which has no entitlement.
    static func loadOrCreate() -> MoonlightIdentityStore? {
        if let certificate = findCertificate(), findKey() != nil {
            return MoonlightIdentityStore(certificateDER: SecCertificateCopyData(certificate) as Data, source: .keychain)
        }
        guard let key = findKey() ?? createKey(),
              let der = MoonlightCertificateMint.selfSigned(privateKey: key),
              let certificate = SecCertificateCreateWithData(nil, der as CFData) else { return nil }
        var add = certificateAttributes()
        add[kSecValueRef] = certificate
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { return nil }
        return MoonlightIdentityStore(certificateDER: der, source: .keychain)
    }

    /// An identity from a PKCS#12 blob: the tests' way in, with no keychain.
    static func imported(pkcs12 blob: Data, passphrase: String) -> MoonlightIdentityStore? {
        guard let identity = importIdentity(blob, passphrase: passphrase) else { return nil }
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else { return nil }
        let der = SecCertificateCopyData(certificate) as Data
        return MoonlightIdentityStore(certificateDER: der, source: .pkcs12(blob: blob, passphrase: passphrase))
    }

    private static func privateKey(of identity: SecIdentity) -> SecKey? {
        var key: SecKey?
        guard SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess else { return nil }
        return key
    }

    private static func findKey() -> SecKey? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: keyTag,
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecReturnRef: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item,
              CFGetTypeID(item) == SecKeyGetTypeID() else { return nil }
        return unsafeDowncast(item, to: SecKey.self)
    }

    private static func findCertificate() -> SecCertificate? {
        let query: [CFString: Any] = [kSecClass: kSecClassCertificate, kSecAttrLabel: certificateLabel, kSecReturnRef: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item,
              CFGetTypeID(item) == SecCertificateGetTypeID() else { return nil }
        return unsafeDowncast(item, to: SecCertificate.self)
    }

    /// iOS pairs a stored certificate with the private key whose public half
    /// it carries, so the identity is a query away once both are in.
    private static func findIdentity() -> SecIdentity? {
        let query: [CFString: Any] = [kSecClass: kSecClassIdentity, kSecAttrLabel: certificateLabel, kSecReturnRef: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let item,
              CFGetTypeID(item) == SecIdentityGetTypeID() else { return nil }
        return unsafeDowncast(item, to: SecIdentity.self)
    }

    /// The key is born inside the keychain: a key merely held in memory is
    /// not one the keychain can pair with the certificate.
    private static func createKey() -> SecKey? {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: keyBits,
            kSecPrivateKeyAttrs: privateKeyAttributes()
        ]
        return SecKeyCreateRandomKey(attributes as CFDictionary, nil)
    }

    /// The private key's keychain attributes: kept, tagged, and readable
    /// after the first unlock on this device only, as the satellites'
    /// pairing keys are; a backup restored elsewhere does not carry it.
    static func privateKeyAttributes() -> [CFString: Any] {
        [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: keyTag,
            kSecAttrLabel: keyLabel,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    /// The certificate's keychain attributes, under the key's accessibility.
    static func certificateAttributes() -> [CFString: Any] {
        [
            kSecClass: kSecClassCertificate,
            kSecAttrLabel: certificateLabel,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }

    private static func importIdentity(_ blob: Data, passphrase: String) -> SecIdentity? {
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: passphrase] as CFDictionary
        guard SecPKCS12Import(blob as CFData, options, &items) == errSecSuccess,
              let first = (items as? [[String: Any]])?.first,
              let identity = first[kSecImportItemIdentity as String] as AnyObject?,
              CFGetTypeID(identity) == SecIdentityGetTypeID() else { return nil }
        return unsafeDowncast(identity, to: SecIdentity.self)
    }
}
