//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2023 Threema GmbH
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

class ForwardSecurityStatusSender: ForwardSecurityStatusListener {
    private let entityManager: EntityManager
    
    init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    func responderSessionEstablished(
        session: DHSession,
        contact: ForwardSecurityContact,
        existingSessionPreempted: Bool
    ) {
        if existingSessionPreempted {
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionReset, arg: 0)
        }
    }
    
    func rejectReceived(sessionID: DHSessionID, contact: ForwardSecurityContact, rejectedMessageID: Data) {
        // Refresh feature mask now, in case contact downgraded to a build without PFS
        updateFeatureMask(for: contact)
        
        postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionReset, arg: 0, allowDuplicates: false)
        
        entityManager.performAsyncBlockAndSafe { [self] in
            let message = entityManager.entityFetcher.ownMessage(with: rejectedMessageID)
            message?.sendFailed = NSNumber(booleanLiteral: true)
            message?.sent = NSNumber(booleanLiteral: false)
        }
    }
    
    func sessionTerminated(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        // Refresh feature mask now, in case contact downgraded to a build without PFS
        updateFeatureMask(for: contact)
        
        postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionReset, arg: 0, allowDuplicates: false)
    }
    
    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int) {
        postSystemMessage(for: contact.identity, reason: kSystemMessageFsMessagesSkipped, arg: numSkipped)
    }
    
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        postSystemMessage(for: contact.identity, reason: kSystemMessageFsOutOfOrder, arg: 0)
    }
    
    private func postSystemMessage(for contactIdentity: String, reason: Int, arg: Int, allowDuplicates: Bool = true) {
        entityManager.performAsyncBlockAndSafe {
            if let conversation = self.entityManager.conversation(for: contactIdentity, createIfNotExisting: true) {
                let lastSystemMessage = conversation.lastMessage as? SystemMessage
                if !allowDuplicates, let lastSystemMessage, lastSystemMessage.type.intValue == reason {
                    return
                }
                
                let systemMessage = self.entityManager.entityCreator.systemMessage(for: conversation)
                systemMessage?.type = NSNumber(value: reason)
                systemMessage?.arg = String(arg).data(using: .utf8)
                systemMessage?.remoteSentDate = Date()
                conversation.lastMessage = systemMessage
                conversation.lastUpdate = Date()
            }
            else {
                DDLogNotice("Forward Security: Can't add status message because conversation is nil")
            }
        }
    }
    
    private func updateFeatureMask(for contact: ForwardSecurityContact) {
        entityManager.performAsyncBlockAndSafe {
            let contactEntity = self.entityManager.entityFetcher.contact(for: contact.identity)
            FeatureMask
                .check(Int(FEATURE_MASK_FORWARD_SECURITY), forContacts: [contactEntity], forceRefresh: true) { _ in
                    // Feature mask has been updated in DB, will be respected on next message send
                }
        }
    }
}
