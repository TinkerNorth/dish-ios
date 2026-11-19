// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishCore
import Foundation

/// The app and the device it runs on, as the scene read them once: what
/// the diagnostics bundle names, and what a database issue is matched on.
package struct DeviceIdentity: Equatable {
    package let appVersion: String
    package let appBuild: String
    /// The hardware's model identifier, "iPhone18,1".
    package let model: String
    /// "26.1".
    package let systemVersion: String

    package init(appVersion: String, appBuild: String, model: String, systemVersion: String) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.model = model
        self.systemVersion = systemVersion
    }

    /// What a model built outside the scene knows: nothing.
    package static let unknown = DeviceIdentity(appVersion: "", appBuild: "", model: "", systemVersion: "")

    /// The device as an issue names one; a version that does not read as a
    /// number matches no issue tied to one.
    package var controllerHost: ControllerHost {
        let major = systemVersion.split(separator: ".").first.flatMap { Int($0) }
        return ControllerHost(model: model, platform: DiagnosticsApp.platform, osMajor: major)
    }
}

package enum DiagnosticsApp {
    /// The app's name in the bundle and the attachment's.
    package static let name = "dish-ios"
    /// The app's name in the mail's subject.
    package static let mailName = "Dish for iOS"
    /// The platform's key under an issue's `os`.
    package static let platform = "ios"
    package static let systemName = "iOS"
}

/// One message for the person's own mail app: to support, the contract's
/// subject, the page's summary and the bundle attached.
package struct DiagnosticsMail: Equatable {
    package let recipient: String
    package let subject: String
    package let body: String
    package let attachment: URL

    package init(recipient: String, subject: String, body: String, attachment: URL) {
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.attachment = attachment
    }
}

/// The mail app as a seam: the scene hands the model one over MessageUI,
/// which falls back to the share sheet with the file where no account is
/// set up; nothing is sent until the person presses Send there.
@MainActor
package protocol DiagnosticsMailer: AnyObject {
    func compose(_ mail: DiagnosticsMail)
}

/// A mailer that opens nothing: a model built outside the scene.
@MainActor
package final class InertDiagnosticsMailer: DiagnosticsMailer {
    package init() {}

    package func compose(_: DiagnosticsMail) {}
}

/// A mailer that keeps what it was asked to open, for the tests.
@MainActor
package final class RecordedDiagnosticsMailer: DiagnosticsMailer {
    package private(set) var mails: [DiagnosticsMail] = []

    package init() {}

    package func compose(_ mail: DiagnosticsMail) {
        mails.append(mail)
    }
}
