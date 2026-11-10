// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.
//
// The fake satellite's TLS identity. dish-mac mints a certificate at run
// time inside a throwaway file keychain, which iOS does not have, and a
// package test bundle on the simulator has no Keychain entitlement either
// (SecItemAdd answers errSecMissingEntitlement). `SecPKCS12Import` builds an
// in-memory `SecIdentity` without one, so the fake carries two self-signed
// P-256 identities as PKCS#12 fixtures (made once with OpenSSL, `-legacy`
// so Security reads them, passphrase `fake`), and alternate instances
// present the two, so a pin taken from one is refused by the next.

import CryptoKit
import Foundation
import Security

/// One instance's certificate, and its identity imported afresh for each
/// listener: a `SecIdentity` is not `Sendable`, the fixture is.
final class FakeSatelliteIdentity: Sendable {
    let certificateDER: Data
    private let fixture: String

    init(certificateDER: Data, fixture: String) {
        self.certificateDER = certificateDER
        self.fixture = fixture
    }

    /// SHA-256 of the DER: the TOFU pin the client side computes.
    var fingerprintSHA256Hex: String {
        FakeSatelliteCrypto.hexString(Data(SHA256.hash(data: certificateDER)))
    }

    func secIdentity() -> SecIdentity? {
        try? FakeSatelliteCertificateMint.importIdentity(fixture)
    }
}

enum FakeSatelliteCertificateError: Error {
    case importFailed(OSStatus)
    case noCertificate
}

enum FakeSatelliteCertificateMint {
    /// The fixture for instance `number`: odd and even instances differ.
    static func mint(number: Int) throws -> FakeSatelliteIdentity {
        let fixture = number.isMultiple(of: 2) ? FakeSatelliteFixtures.identityB : FakeSatelliteFixtures.identityA
        let identity = try importIdentity(fixture)
        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else {
            throw FakeSatelliteCertificateError.noCertificate
        }
        return FakeSatelliteIdentity(certificateDER: SecCertificateCopyData(certificate) as Data, fixture: fixture)
    }

    static func importIdentity(_ fixture: String) throws -> SecIdentity {
        guard let blob = Data(base64Encoded: fixture) else { throw FakeSatelliteCertificateError.importFailed(errSecDecode) }
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: FakeSatelliteFixtures.passphrase] as CFDictionary
        let status = SecPKCS12Import(blob as CFData, options, &items)
        guard status == errSecSuccess, let first = (items as? [[String: Any]])?.first,
              let identityRef = first[kSecImportItemIdentity as String] as AnyObject?,
              CFGetTypeID(identityRef) == SecIdentityGetTypeID() else
        {
            throw FakeSatelliteCertificateError.importFailed(status)
        }
        return unsafeDowncast(identityRef, to: SecIdentity.self)
    }
}

/// Two self-signed P-256 identities (CN fake-satellite-a and -b).
enum FakeSatelliteFixtures {
    static let passphrase = "fake"

    static let identityA = """
    MIIDegIBAzCCAzgGCSqGSIb3DQEHAaCCAykEggMlMIIDITCCAhcGCSqGSIb3DQEHBqCCAggwggIEAgEAMIIB/QYJKoZIhvcNAQcBMBwGCiqGSIb3DQEMAQYw\
    DgQIL1OHWvBO2s8CAggAgIIB0GLuYuJiGh8nL39NhCwKs4C5ZfN3LQNodh9y4lz2F6a5dTjV05rqINjJ7JuYtVRo8qMSsDzX+Q5rdYtsLbv7nny0mnLkCgKM\
    IEu3XOOn+QVYg9fNw8DeyjBqgUQOhxqZnWgZbVClhn8syOcHUaci9SWrAnJbhpWXQZThyPLSMJatA3cFVqlWg5NPrv+GvCklXJnsrz85EuPcFqtYUUkv2vtz\
    41GRBqeh8JB5aDkq2SE0Z7yON21V8jHkoDz+N3CpA+rlO5DPPz7UEb674Q9j1WYOOk32sH4tkmN8d4N8GP3SyxE9rdK4bEesBlbAibml6jWvqkw+YDWfZhRX\
    JdB13PQb85S6VlEDxzT5k9UiLfB9+ZqtvcanupquFdMGeVel9Xe/hV+nAbXCTf+/19sRpNOsyq7kGvaI9L8NzRi6bnN4QVlors+RF1h/L+gwSkJaWP3n5+Yb\
    2PZuzbGQ6VIIj7JRPH1Ky6b0VtHmCdH/Pzqgo9GF818fNkiTrELIMgBte7mG6Qg8avSprF0TRj11qPoGE4ckzYfxUOG6zrMmRvTpRbM3ypXfXLgnmm6+YIju\
    3GNGPZVCDFqOsKkW+eCbSDS1fE0Ldz4LcDB6FTY1DBhRMIIBAgYJKoZIhvcNAQcBoIH0BIHxMIHuMIHrBgsqhkiG9w0BDAoBAqCBtDCBsTAcBgoqhkiG9w0B\
    DAEDMA4ECJB8VNBLHg9CAgIIAASBkMlB1za51pqSI4bpRMhLl8sc5U4h7rHUGEaxR+w8/b1PHU3hZiSabfRtCBe0LoLJqMQTP4eFac7pC0Ue0rHQQlIco+26\
    hzKCljuB0uDUwvuRTYQD9A0TKlR2PU/btfsVlIkbXOfMmEw4WHGzt/WgG6Of6mjs+Jpd22V0O1YsYXSiD0jYqQDkndcwcgYS4exYyjElMCMGCSqGSIb3DQEJ\
    FTEWBBRlsx3SVenl6E11UpM5CF2IWUPTsTA5MCEwCQYFKw4DAhoFAAQUwaVM+2L25buTvIkRc9vGKYNXRA0EECEnvQk6vBIHJk/EHrQ5jOICAggA
    """

    static let identityB = """
    MIIDegIBAzCCAzgGCSqGSIb3DQEHAaCCAykEggMlMIIDITCCAhcGCSqGSIb3DQEHBqCCAggwggIEAgEAMIIB/QYJKoZIhvcNAQcBMBwGCiqGSIb3DQEMAQYw\
    DgQIhDCqxduBkCkCAggAgIIB0JGPT7QlJQRw4lFbHR9pbo/ejsHYLInSP7iNPKuDgFpPMw0wcmOV4UoeaVD0qLzcXjD7Apc8gyRJW/sgqXf9a+ju1q+70zV+\
    vDLc82W+vPpL2l2bPx+vxeQchNdo7Se6+J5CvmUu7xvR09jTOSVf74OpqHiBD0GiRztBywH6z/bEQzEom4xR0rz+qjlQYB7uLwTKT+09teQxMzA2jNTV6sBp\
    9oSpFffYNqJEDwIWYFlzBms4XwsFoXnR8Wg9Ij9NFy5br1HY0e7GSKEH0S4Y2nscpDnC0M88QhbSCUeDfn6909MaiHKIZdpkHNFa+oKfGzcGwFGaam9H9/09\
    M7BmeeZdLlti59jEppyJ7nepxDhGoTPOHt2ThpfOqiFSyzIxU5d4ETMQbxuw47dtyzesHVLrZ/GJ5FiGrj7gu85v98rzC84pS+k66+8FMHXq3FHf18EarDjU\
    VfI0LFUT1Rk6HbkBDxA2sMw4W/5trq2KDAaCB/Ek99N/vo5VpuW/4dSMCGa3rQObEVk9S3NF1YGUUgIm2R5dThNcBeY0fmv4KdN4VgrS6BdPa6Uv/o+UyplC\
    u4Bg+4rrPe/OCHjnICIUz8TgUFx/UEY6paWO7l+jtYKlMIIBAgYJKoZIhvcNAQcBoIH0BIHxMIHuMIHrBgsqhkiG9w0BDAoBAqCBtDCBsTAcBgoqhkiG9w0B\
    DAEDMA4ECCKSx331Hsc5AgIIAASBkHGmrMVkii5Sb3fQu03qdcvfwY1fIsxIO5L2UbK7T5wht6rTMrCfcNBclnf2f/M2IQcE5O6FaMc46f3MPD1L3lRoHCoL\
    /V6+myrqw2pUnl6+mw0H1QFHC4oOd9eqttP8lv2rdU/PDKB74qYe8VJPdFISUwjVPF7HLI/svV5a2LiGPS4cmmIfcaKEb+enTCD7RTElMCMGCSqGSIb3DQEJ\
    FTEWBBQ3vW15oEdkT2R5FQlbDuVW8VF9JTA5MCEwCQYFKw4DAhoFAAQU6UVGtvZsLzE/gUiWRp0ZPUmx1/YEEKxUsg8rDvUVHvD+nsqEjNACAggA
    """
}
