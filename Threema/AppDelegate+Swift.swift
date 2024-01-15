//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

import BackgroundTasks
import Foundation
import Intents

extension AppDelegate {
    
    @objc func registerBackgroundTasks() {
        // Automatically delete messages in background
        let taskID = "ch.threema.messageRetention"
        let deletionTask: (BGTask) -> Void = { task in
            DDLogNotice("BG Operation with Task \(task.identifier) started")
            let deletionTask = Task {
                await BusinessInjector().messageRetentionManager.deleteOldMessages()
                DDLogNotice("BG Operation for deleting old messages completed")
                task.setTaskCompleted(success: !Task.isCancelled)
            }
            let onCancel = {
                DDLogNotice("BG Operation for deleting old messages cancelled")
                deletionTask.cancel()
            }
            task.expirationHandler = onCancel
        }
        
        setupTask(with: taskID, operation: deletionTask)
    }
    
    private func setupTask(with id: String, operation: @escaping (BGTask) -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: id,
            using: DispatchQueue.main,
            launchHandler: operation
        )

        BGTaskScheduler.shared.getPendingTaskRequests { tasks in
            if tasks.contains(where: { $0.identifier == id }) {
                DDLogNotice("Already got \(id) pending")
                return
            }
            
            self.scheduleTask(id)
        }
    }
    
    private func scheduleTask(_ taskID: String) {
        let request = BGProcessingTaskRequest(identifier: taskID)
        
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            DDLogNotice("Submitted background task request: \(taskID)")
        }
        catch {
            DDLogNotice("Error submitting background task request: \(error)")
        }
    }
    
    /// Used to handle Siri suggestions in widgets, search or on lock screen
    @objc func handleINSendMessageIntent(userActivity: NSUserActivity) -> Bool {
        guard let interaction = userActivity.interaction else {
            return false
        }
        
        guard let intent = interaction.intent as? INSendMessageIntent else {
            return false
        }
        
        if let selectedIdentity = intent.conversationIdentifier as String? {
            if let managedObject = EntityManager().entityFetcher.existingObject(withIDString: selectedIdentity) {
                if let contact = managedObject as? ContactEntity,
                   let conversation = EntityManager().entityFetcher.conversation(for: contact) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [
                            kKeyConversation: conversation,
                            kKeyForceCompose: true,
                        ]
                    )
                    return true
                }
                else if let group = managedObject as? Conversation {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [
                            kKeyConversation: group,
                            kKeyForceCompose: true,
                        ]
                    )
                    return true
                }
            }
        }
        
        if let recipient = intent.recipients?.first as? INPerson,
           let identity = recipient.personHandle?.value,
           identity.count == kIdentityLen,
           let singleConversation = EntityManager().entityFetcher.conversation(forIdentity: identity) {
            NotificationCenter.default.post(
                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                object: nil,
                userInfo: [
                    kKeyConversation: singleConversation,
                    kKeyForceCompose: true,
                ]
            )
            return true
        }
        
        return false
    }
}
