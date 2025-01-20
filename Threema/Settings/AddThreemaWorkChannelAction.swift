//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
import ThreemaMacros

enum AddThreemaWorkChannelAction {
    
    private static let threemaWorkChannelIdentity = "*3MAWORK"
    
    static func run(in viewController: UIViewController) {
        if let contact = ContactStore.shared().contact(for: threemaWorkChannelIdentity) {
            let info = notificationInfo(for: contact)
            showConversation(for: info)
            return
        }
        
        UIAlertTemplate.showAlert(
            owner: viewController,
            title: #localize("threema_work_channel_intro"),
            message: #localize("threema_work_channel_info"),
            titleOk: #localize("add_button"),
            actionOk: { _ in
                addWorkChannel(in: viewController)
            }
        )
    }
    
    private static func addWorkChannel(in viewController: UIViewController) {
        ContactStore.shared().addContact(
            with: threemaWorkChannelIdentity,
            verificationLevel: Int32(kVerificationLevelUnverified),
            onCompletion: { contact, _ in
                guard let contact else {
                    UIAlertTemplate.showAlert(
                        owner: viewController,
                        title: #localize("threema_work_channel_failed"),
                        message: nil
                    )
                    return
                }
                
                let info = notificationInfo(for: contact)
                showConversation(for: info)
                
                let initialMessages = createInitialMessages()
                dispatchInitialMessages(messages: initialMessages, with: contact)
                
            }, onError: { error in
                UIAlertTemplate.showAlert(
                    owner: viewController,
                    title: #localize("threema_work_channel_failed"),
                    message: error.localizedDescription
                )
            }
        )
    }
    
    private static func notificationInfo(for contact: ContactEntity) -> [AnyHashable: Any] {
        [
            kKeyContact: contact,
            kKeyForceCompose: NSNumber(value: false),
        ]
    }
    
    private static func showConversation(for notificationInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: notificationInfo
            )
        }
    }
    
    private static func createInitialMessages() -> [String] {
        var initialMessages = [String]()
        
        if !(Bundle.main.preferredLocalizations[0].hasPrefix("de")) {
            initialMessages.append("en")
        }
        else {
            initialMessages.append("de")
        }
        initialMessages.append("Start iOS")
        initialMessages.append("Info")
        
        return initialMessages
    }
    
    private static func dispatchInitialMessages(messages: [String], with contact: ContactEntity) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            let businessInjector = BusinessInjector()

            guard let conversation = businessInjector.entityManager.entityFetcher.conversation(for: contact) else {
                DDLogWarn("Unable to add initial messages to Threema Work Channel. Reason: conversation not found.")
                return
            }
            
            for (index, message) in messages.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(index)) {
                    businessInjector.messageSender.sendTextMessage(
                        containing: message,
                        in: conversation
                    )
                }
            }
        }
    }
}
