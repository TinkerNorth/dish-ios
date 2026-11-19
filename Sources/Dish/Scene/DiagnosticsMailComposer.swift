// SPDX-License-Identifier: LGPL-3.0-or-later
// Copyright (C) 2026 Dish contributors.

import DishEngine
import Foundation
import MessageUI
import UIKit

/// The person's own mail app behind the model's `DiagnosticsMailer` seam:
/// MessageUI's compose sheet addressed to support with the bundle attached,
/// or, where no mail account is set up, the share sheet with the file. The
/// one place MessageUI is touched; nothing is sent until the person presses
/// Send.
@MainActor
final class DiagnosticsMailComposer: NSObject, DiagnosticsMailer {
    /// The controller the sheet is presented over; the scene's to find.
    private let presenter: @MainActor () -> UIViewController?
    private let canSendMail: @MainActor () -> Bool

    init(
        presenter: @escaping @MainActor () -> UIViewController?,
        canSendMail: @escaping @MainActor () -> Bool = MFMailComposeViewController.canSendMail
    ) {
        self.presenter = presenter
        self.canSendMail = canSendMail
    }

    func compose(_ mail: DiagnosticsMail) {
        guard let presenter = presenter() else { return }
        presenter.present(sheet(for: mail), animated: true)
    }

    /// The compose sheet when mail is set up, else the share sheet.
    func sheet(for mail: DiagnosticsMail) -> UIViewController {
        guard canSendMail(), let data = try? Data(contentsOf: mail.attachment) else { return shareSheet(for: mail) }
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([mail.recipient])
        composer.setSubject(mail.subject)
        composer.setMessageBody(mail.body, isHTML: false)
        composer.addAttachmentData(data, mimeType: DiagnosticsMailComposer.mimeType, fileName: mail.attachment.lastPathComponent)
        return composer
    }

    private func shareSheet(for mail: DiagnosticsMail) -> UIViewController {
        UIActivityViewController(activityItems: [mail.attachment], applicationActivities: nil)
    }

    private static let mimeType = "application/json"
}

extension DiagnosticsMailComposer: MFMailComposeViewControllerDelegate {
    /// Whatever the person did, the sheet closes; the mail app sends.
    nonisolated func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith _: MFMailComposeResult,
        error _: Error?
    ) {
        MainActor.assumeIsolated {
            controller.dismiss(animated: true)
        }
    }
}

/// The controller on top of the window's stack, which a sheet is presented over.
@MainActor
func topmostController(_ root: UIViewController?) -> UIViewController? {
    guard let presented = root?.presentedViewController else { return root }
    return topmostController(presented)
}
