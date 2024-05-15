//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2024 Threema GmbH
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
    private static var didStart = false
    
    @objc override init() {
        super.init()
    }
    
    /// Create Sentry and start crash handler.
    @objc func start() {
        guard SentryClient.isEnabled() else {
            return
        }
        
        guard !SentryClient.didStart else {
            return
        }
        
        guard let sentryDsn = BundleUtil.object(forInfoDictionaryKey: "SentryClientDsn") as? String else {
            DDLogError("Could not retrieve sentryDsn from bundle. Sentry will not be started.")
            return
        }
        
        SentryClient.didStart = true
        
        SentrySDK.start { options in
            
            // Apply settings
            options.dsn = sentryDsn
            options.enableAutoSessionTracking = false
            options.enableNetworkTracking = false

            // Disable breadcrumbs
            options.maxBreadcrumbs = 0
            options.enableAutoBreadcrumbTracking = false
            options.enableNetworkBreadcrumbs = false
            
            // This will be called when an event occurs
            options.beforeSend = { event in
                self.handle(event: event)
            }
        }
    }
    
    private func handle(event: Event) -> Event? {
        //  TODO: IOS-3786
        guard !Thread.isMainThread else {
            DDLogError(
                "IOS-3786: Do not process crash on main thread because we would deadlock otherwise."
            )
            return nil
        }
        
        if let appDevice = event.context?["app"]?["device_app_hash"] as? String {
            // Save anonymous app device, it will be displayed under Settings -> Advanced
            UserSettings.shared()?.sentryAppDevice = appDevice
            
            // Send app device hash to count users per event on sentry ui
            // swiftformat:disable:next acronyms
            let user = User(userId: appDevice)
            event.user = user
        }
        
        // Remove registers
        event.threads?.forEach { $0.stacktrace?.registers = [:] }
        event.exceptions?.forEach { $0.stacktrace?.registers = [:] }
        
        if event.exceptions?.first?.value != nil {
            event.exceptions?.first?.value = redact(exceptionDescription: event.exceptions!.first!.value)
        }
        
        var send = false
        
        // Show alert
        let dispatch = DispatchGroup()
        dispatch.enter()
        DispatchQueue.main.async {
            let confirm = UIAlertController(
                title: String.localizedStringWithFormat(
                    "sentry_crash_send_title".localized,
                    ThreemaApp.currentName
                ),
                message: "sentry_crash_send_description".localized,
                preferredStyle: .alert
            )
            confirm.addTextField { textField in
                textField.placeholder = "sentry_crash_comment_placeholder".localized
            }
            confirm.addAction(UIAlertAction(
                title: "sentry_crash_send_yes".localized,
                style: .default,
                handler: { _ in
                    if let textField = confirm.textFields?.first,
                       let text = textField.text {
                        let sentryMessage = SentryMessage(formatted: text)
                        event.message = sentryMessage
                    }
                    send = true
                    dispatch.leave()
                }
            ))
            confirm.addAction(UIAlertAction(
                title: "sentry_crash_send_no".localized,
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
        
        let em = EntityManager()
        var idList: Set<String> = []
        
        em.performAndWait {
            guard let contacts = em.entityFetcher.allContacts() as? [ContactEntity] else {
                return
            }
            
            contacts.forEach {
                idList.insert($0.identity)
            }
        }
        
        for i in 0..<linesArray.count {
            for k in keys {
                if linesArray[i].contains(k) {
                    let range = linesArray[i].range(of: k)!
                    linesArray[i] = linesArray[i][..<range.lowerBound] + "***redacted***"
                }
            }
            for id in idList {
                if linesArray[i].contains(id) {
                    linesArray[i] = linesArray[i].replacingOccurrences(of: id, with: "***redacted***")
                }
            }
        }

        return linesArray.joined(separator: "\n")
    }
    
    /// Is Sentry enabled or not dependent on is file "SENTRY_NOT_ENABLED" exists in App documents directory. When the
    /// App crashes on start because of Sentry start handler, can the file adding per iTunes to disable it.
    ///
    /// - Returns: true -> start Sentry crash handler
    private static func isEnabled() -> Bool {
        !FileUtility.isExists(fileURL: FileUtility.appDocumentsDirectory?.appendingPathComponent(sentryNotEnabled))
    }
}
