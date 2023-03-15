//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2023 Threema GmbH
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
import Intents

extension MessageSender {

    /// Reflect incoming message update read, only when no read receipt will be send to the sender
    /// - Parameters:
    ///    - messages: Messages are read
    ///    - identity: Sender of the read messages
    public static func reflectReadReceipt(messages: [BaseMessage], senderIdentity identity: String) {
        guard ServerConnector.shared().isMultiDeviceActivated else {
            return
        }

        // swiftformat:disable:next all
        var conversationID = D2d_ConversationId()
        conversationID.contact = identity

        reflectReadReceipt(messages: messages, conversationID: conversationID)
    }

    /// Reflect incoming message update read, for group messages
    /// - Parameters:
    ///    - messages: Messages are read
    ///    - identity: Sender of the read messages
    public static func reflectReadReceipt(messages: [BaseMessage], senderGroupIdentity identity: GroupIdentity) {
        guard ServerConnector.shared().isMultiDeviceActivated else {
            return
        }

        // swiftformat:disable:next all
        var conversationID = D2d_ConversationId()
        conversationID.group.groupID = identity.id.convert()
        conversationID.group.creatorIdentity = identity.creator

        reflectReadReceipt(messages: messages, conversationID: conversationID)
    }

    // swiftformat:disable:next all
    private static func reflectReadReceipt(messages: [BaseMessage], conversationID: D2d_ConversationId) {
        let em = EntityManager()
        em.performBlockAndWait {
            guard !messages.isEmpty else {
                return
            }

            var messageIDs = [Data]()
            var messageReadDates = [Date]()
            for message in messages {
                if let readDate = message.readDate {
                    messageIDs.append(message.id)
                    messageReadDates.append(readDate)
                }
            }

            if !messageIDs.isEmpty {
                let tm = TaskManager()
                tm.add(
                    taskDefinition: TaskDefinitionSendIncomingMessageUpdate(
                        messageIDs: messages.map(\.id),
                        messageReadDates: messageReadDates,
                        conversationID: conversationID
                    )
                )
            }
        }
    }

    @objc static func sendTypingIndicator(conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }
        
        return sendTypingIndicator(contact: conversation.contact)
    }

    @objc static func sendTypingIndicator(contact: ContactEntity?) -> Bool {
        guard let contact = contact else {
            return false
        }
        
        return (UserSettings.shared().sendTypingIndicator && contact.typingIndicator == .default) || contact
            .typingIndicator == .send
    }
    
    @objc static func sendReadReceipt(conversation: Conversation) -> Bool {
        guard !conversation.isGroup() else {
            return false
        }
        
        return sendReadReceipt(contact: conversation.contact)
    }

    @objc static func sendReadReceipt(contact: ContactEntity?) -> Bool {
        guard let contact = contact else {
            return false
        }
        
        return (UserSettings.shared().sendReadReceipts && contact.readReceipt == .default) || contact
            .readReceipt == .send
    }
    
    public static func sanitizeAndSendText(_ rawText: String, in conversation: Conversation) {
        DispatchQueue.global(qos: .userInitiated).async {
            let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let splitMessages = ThreemaUtilityObjC.getTrimmedMessages(trimmedText)
            
            if let splitMessages = splitMessages as? [String] {
                for splitMessage in splitMessages {
                    DispatchQueue.main.async {
                        MessageSender.sendMessage(
                            splitMessage,
                            in: conversation,
                            quickReply: false,
                            requestID: nil,
                            completion: nil
                        )
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    MessageSender.sendMessage(
                        trimmedText,
                        in: conversation,
                        quickReply: false,
                        requestID: nil,
                        completion: nil
                    )
                }
            }
        }
    }
    
    /// Donate outgoing message interaction for conversation
    /// Checks whether donations are enabled or not
    /// - Parameter conversation: conversation for which the donation is made
    @objc public static func donateInteractionForOutgoingMessage(in conversation: Conversation) {
        donateInteractionForOutgoingMessage(in: conversation.objectID, with: BusinessInjector())
            .done { donated in
                if donated {
                    DDLogVerbose("[Intents] Successfully donated interaction for conversation")
                }
                else {
                    DDLogVerbose("[Intents] Could not donate interaction for conversation")
                }
            }
    }
    
    /// Donate interaction for conversation
    /// Checks whether donations are enabled or not
    /// - Parameters:
    ///   - conversationManagedObjectID: conversation for which the donation is made
    ///   - businessInjector: BusinessInjector instance
    /// - Returns: true if the donation was successful and false otherwise
    static func donateInteractionForOutgoingMessage(
        in conversationManagedObjectID: NSManagedObjectID,
        with businessInjector: BusinessInjectorProtocol
    ) -> Guarantee<Bool> {
        firstly {
            Guarantee { $0(businessInjector.userSettings.donateInteractions) }
        }
        .then { doDonateInteractions -> Guarantee<Bool> in
            Guarantee<Bool> { seal in
                guard doDonateInteractions else {
                    DDLogVerbose("Donations are disabled by the user")
                    seal(false)
                    return
                }

                businessInjector.backgroundEntityManager.performBlockAndWait {
                    guard let conversation = businessInjector.backgroundEntityManager.entityFetcher
                        .existingObject(with: conversationManagedObjectID) as? Conversation else {
                        let msg = "Could not donate interaction because object is not a conversation"
                        DDLogError(msg)
                        assertionFailure(msg)

                        seal(false)
                        return
                    }

                    guard conversation.conversationCategory != .private else {
                        DDLogVerbose("Do not donate for private conversations")
                        seal(false)
                        return
                    }

                    if conversation.isGroup(),
                       let group = businessInjector.backgroundGroupManager.getGroup(conversation: conversation) {
                        _ = IntentCreator(
                            userSettings: businessInjector.userSettings,
                            entityManager: businessInjector.backgroundEntityManager
                        )
                        .donateInteraction(for: group).done {
                            seal(true)
                        }.catch { _ in
                            seal(false)
                        }
                    }
                    else {
                        guard let contact = conversation.contact else {
                            seal(false)
                            return
                        }
                        _ = IntentCreator(
                            userSettings: businessInjector.userSettings,
                            entityManager: businessInjector.backgroundEntityManager
                        )
                        .donateInteraction(for: contact).done {
                            seal(true)
                        }.catch { _ in
                            seal(false)
                        }
                    }
                }
            }
        }
    }
}
