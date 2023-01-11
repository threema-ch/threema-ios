//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CocoaLumberjackSwift
import Foundation
import Sentry

@objc class SentryClient: NSObject {
    
    private static let sentryNotEnabled = "SENTRY_NOT_ENABLED"
    
    @objc override init() {
        super.init()
    }
    
    /// Create Sentry and start crash handler.
    ///
    /// - Parameters:
    ///    - rootViewController: Parent view controller
    @objc func start() {
        guard SentryClient.isEnabled(),
              let sentryDsn = BundleUtil.object(forInfoDictionaryKey: "SentryClientDsn") as? String else {
                
            return
        }
        
        do {
            let options = try Sentry.Options(dict: ["dsn": sentryDsn])
            options.enableAutoSessionTracking = false
            options.enableNetworkTracking = false

            options.beforeSend = { event in
                if let appDevice = event.context?["app"]?["device_app_hash"] as? String {
                    // Save anonymous app device, it will be displayed under Settings - Advanced
                    UserSettings.shared()?.sentryAppDevice = appDevice

                    // Send app device hash to count users per event on sentry ui
                    // swiftformat:disable:next acronyms
                    let user = User(userId: appDevice)
                    event.user = user
                }

                if event.exceptions?.first?.value != nil {
                    event.exceptions?.first?.value = self.redact(exceptionDescription: event.exceptions!.first!.value)
                }
                
                var send = false
                
                let dispatch = DispatchGroup()
                dispatch.enter()
                DispatchQueue.main.async {
                    let confirm = UIAlertController(
                        title: String.localizedStringWithFormat(
                            BundleUtil.localizedString(forKey: "sentry_crash_send_title"),
                            ThreemaApp.currentName
                        ),
                        message: BundleUtil.localizedString(forKey: "sentry_crash_send_description"),
                        preferredStyle: .alert
                    )
                    confirm.addTextField { textField in
                        textField.placeholder = BundleUtil.localizedString(forKey: "sentry_crash_comment_placeholder")
                    }
                    confirm.addAction(UIAlertAction(
                        title: BundleUtil.localizedString(forKey: "sentry_crash_send_yes"),
                        style: .default,
                        handler: { _ in
                            if let textField = confirm.textFields?.first, let text = textField.text {
                                let sentryMessage = SentryMessage(formatted: text)
                                event.message = sentryMessage
                            }
                            send = true
                            dispatch.leave()
                        }
                    ))
                    confirm.addAction(UIAlertAction(
                        title: BundleUtil.localizedString(forKey: "sentry_crash_send_no"),
                        style: .cancel,
                        handler: { _ in
                            dispatch.leave()
                        }
                    ))

                    DispatchQueue.main.async {
                        if let vc = AppDelegate.shared()?.currentTopViewController() {
                            vc.present(confirm, animated: true, completion: nil)
                        }
                        else {
                            dispatch.leave()
                        }
                    }
                }
                
                dispatch.wait()
                
                if send {
                    return event
                }
                return nil
            }

            SentrySDK.start(options: options)
        }
        catch {
            DDLogError("Could not start Sentry!")
        }
    }
    
    private func redact(exceptionDescription: String) -> String {
        let keys = [
            "encryptionKey",
            "k:",
            "password",
            "blobId",
            "blobThumbnailId",
            "\"k\"",
            "\\\"k\\\"",
            "json",
            "text",
            // CoreData `Contact`
            "cnContactId",
            "firstName",
            "lastName",
            "publicNickname",
            "sortInitial",
        ]
        
        var linesArray = exceptionDescription.linesArray

        for i in 0..<linesArray.count {
            for k in keys {
                if linesArray[i].contains(k) {
                    let range = linesArray[i].range(of: k)!
                    linesArray[i] = linesArray[i][..<range.lowerBound] + "***redacted***"
                }
            }
        }

        return linesArray.joined(separator: "\n")
    }
    
    /// Is Sentry enabled or not dependent on is file "SENTRY_NOT_ENABLED" exists in App documents directory. When the App crashes on start because of Sentry start handler, can the file adding per iTunes to disable it.
    ///
    /// - Returns: true -> start Sentry crash handler
    private static func isEnabled() -> Bool {
        !FileUtility.isExists(fileURL: FileUtility.appDocumentsDirectory?.appendingPathComponent(sentryNotEnabled))
    }
}
