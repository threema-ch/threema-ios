//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2025 Threema GmbH
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
import ThreemaEssentials
import ThreemaProtocols

class ForwardSecurityStatusSender: ForwardSecurityStatusListener {
    
    private let entityManager: EntityManager
    
    init(entityManager: EntityManager) {
        self.entityManager = entityManager
    }
    
    func newSessionInitiated(session: DHSession, contact: ForwardSecurityContact) {
        DDLogDebug("[ForwardSecurity] New initiator DH session \(session.description), contact: \(contact.identity)")

        guard ThreemaEnvironment.fsDebugStatusMessages else {
            return
        }
        
        postSystemMessage(
            for: contact.identity,
            reason: kFsDebugMessage,
            arg: "New initiator DH session \(session.description)"
        )
    }
    
    func responderSessionEstablished(
        session: DHSession,
        contact: ForwardSecurityContact,
        existingSessionPreempted: Bool
    ) {
        DDLogNotice(
            "[ForwardSecurity] Responder session established \(session.description), contact: \(contact.identity) existingSessionPreempted \(existingSessionPreempted)"
        )
        if ThreemaEnvironment.fsDebugStatusMessages {
            postSystemMessage(
                for: contact.identity,
                reason: kFsDebugMessage,
                arg: "Responder session established \(session.description)"
            )
        }
        
        if existingSessionPreempted {
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionReset, arg: 0)
        }
        
        // Rationale for local/outgoing applied version: Should be identical to remote/incoming
        // version after initial negotiation.
        if session.outgoingAppliedVersion.rawValue >= CspE2eFs_Version.v11.rawValue {
            // If a new session has been established with V1.1 or higher, we display the message, that forward security
            // has been enabled (by both participants) in this chat.
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionEstablished)
        }
    }
    
    func rejectReceived(
        sessionID: DHSessionID,
        contact: ForwardSecurityContact,
        session: DHSession?,
        rejectedMessageID: Data,
        groupIdentity: GroupIdentity?,
        rejectCause: CspE2eFs_Reject.Cause,
        hasForwardSecuritySupport: Bool
    ) {
        let msg =
            "Reject received for session \(session?.description ?? "nil") (session-id=\(sessionID), rejected-message-id=\(rejectedMessageID.hexString), cause=\(rejectCause))"
        DDLogNotice("[ForwardSecurity] \(msg)")
        
        if ThreemaEnvironment.fsDebugStatusMessages {
            postSystemMessage(
                for: contact.identity,
                reason: kFsDebugMessage,
                arg: msg
            )
        }
        
        if let groupIdentity {
            // 3. If `group_identity` has been provided:
            handleRejectedGroupMessage(
                rejectedMessageID: rejectedMessageID,
                sender: ThreemaIdentity(contact.identity),
                groupIdentity: groupIdentity
            )
        }
        else {
            // 2. If `group_identity` has not been provided:
            handleRejectedMessage(contact: contact, rejectedMessageID: rejectedMessageID)
        }
        
        //  Only show status message for sessions that are known. It doesn't make sense to report a terminated
        //  session we don't even know about.
        if session != nil {
            showResetOrNotSupportedAnymore(contact: contact, hasForwardSecuritySupport)
        }
    }
    
    func handleRejectedGroupMessage(rejectedMessageID: Data, sender: ThreemaIdentity, groupIdentity: GroupIdentity) {
        // 1. Run the _Common Group Receive Steps_. If the message has been
        //    discarded, abort these steps.
        guard CommonGroupReceiveSteps().run(for: groupIdentity, sender: sender) == .keepMessage else {
            DDLogWarn("[ForwardSecurity] Discard Group FS Reject message")
            return
        }
                
        let messageFound: Bool = entityManager.performAndWaitSave {
            // 2. Lookup the message for `message_id` in the `group` and let `message` be
            //    the result.
            guard let conversation = self.entityManager.entityFetcher.conversationEntity(
                for: groupIdentity.id,
                creator: groupIdentity.creator.string
            ) else {
                return false
            }
            
            guard let message = self.entityManager.entityFetcher.ownMessage(
                with: rejectedMessageID,
                conversation: conversation
            ) else {
                // 4. If the user is not the sender of (the original) `message`, abort these
                //    steps.
                return false
            }
            
            // 5. If the _when rejected_ property associated to `message` allows to
            //    re-send after confirmation, mark `message` with _re-send requested_ and
            //    add `sender` to the list of group members requesting a re-send for
            //    `message`.
            switch message {
            case is TextMessageEntity, is LocationMessageEntity, is FileMessageEntity, is BallotMessage:
                guard let contactEntity = self.entityManager.entityFetcher.contact(for: sender.string) else {
                    DDLogError("[ForwardSecurity] Unable to find contact entity for \(sender.string)")
                    return true
                }
                
                message.sendFailed = NSNumber(booleanLiteral: true)
                // Add contact to rejected by list
                message.addRejectedBy(contactEntity)
                
            default:
                DDLogError(
                    "[ForwardSecurity] Not handled message type for rejected group message: \(message.loggingDescription)"
                )
                assertionFailure()
            }
            
            return true
        }
        
        if !messageFound {
            // 3. If `message` is not defined:
            //    1. If the user is the creator of the group, assume that a
            //       `group-sync-request` has been received from the sender and run the
            //       associated steps.
            //    2. Abort these steps.
            
            let groupManager = GroupManager(entityManager: entityManager)
            guard let group = groupManager.getGroup(groupIdentity.id, creator: groupIdentity.creator.string) else {
                DDLogWarn("[ForwardSecurity] Unable to load group")
                return
            }
            
            if group.isOwnGroup {
                Task {
                    do {
                        try await groupManager.sync(group: group, to: Set([sender.string]), withoutCreateMessage: false)
                    }
                    catch {
                        DDLogError("[ForwardSecurity] Error while syncing group: \(error)")
                    }
                }
            }
        }
    }
    
    func handleRejectedMessage(contact: ForwardSecurityContact, rejectedMessageID: Data) {
        entityManager.performAndWaitSave { [self] in
            // 1. Lookup the message for `message_id` in the associated 1:1 conversation
            //    and let `message` be the result.
            guard let conversation = entityManager.entityFetcher.conversationEntity(forIdentity: contact.identity)
            else {
                DDLogError(
                    "[ForwardSecurity] Conversation for rejected message ID \(rejectedMessageID.hexString) not found"
                )
                assertionFailure()
                return
            }
            
            guard let message = entityManager.entityFetcher.ownMessage(
                with: rejectedMessageID,
                conversation: conversation
            ) else {
                // 2. If `message` is not defined or the user is not the sender of `message`,
                //    abort these steps.
                return
            }
            
            // 3. If the _when rejected_ property associated to `message` allows to
            //    re-send after confirmation, mark `message` with _re-send requested_.
            switch message {
            case is TextMessageEntity, is LocationMessageEntity, is FileMessageEntity, is BallotMessage:
                message.sendFailed = NSNumber(booleanLiteral: true)
            // TODO: (IOS-4253) Handle call offer, call answer & call ringing and abort call.
            default:
                DDLogError(
                    "[ForwardSecurity] Not handled message type for rejected message: \(message.loggingDescription)"
                )
                assertionFailure()
            }
        }
    }
    
    func sessionTerminated(
        sessionID: DHSessionID?,
        contact: ForwardSecurityContact,
        sessionUnknown: Bool,
        hasForwardSecuritySupport: Bool
    ) {
        DDLogNotice(
            "[ForwardSecurity] Session terminated: \(sessionID?.description ?? "nil") with contact: \(contact.identity)"
        )
        //  Only show status message for sessions that are known. It doesn't make sense to report a terminated
        //  session we don't even know about.
        if !sessionUnknown {
            showResetOrNotSupportedAnymore(contact: contact, hasForwardSecuritySupport)
        }
    }
    
    func messagesSkipped(sessionID: DHSessionID, contact: ForwardSecurityContact, numSkipped: Int) {
        // No-op
        assert(numSkipped < 10)
        DDLogDebug(
            "[ForwardSecurity] Skipped \(numSkipped) ratchet turns. This is normal for missed non-queued or short lived messages (e.g. typing indicators) received when in the background. But should not happen all the time. Check if the ratchet is actually persisted after the message is processed"
        )
    }
    
    func messageOutOfOrder(sessionID: DHSessionID, contact: ForwardSecurityContact, messageID: Data) {
        let msg =
            "IMPORTANT: REACH OUT TO THE IOS TEAM. Message with id \(messageID.hexString) was received out of order in session \(sessionID.description) with contact: \(contact.identity)."
        
        DDLogError("[ForwardSecurity] \(msg)")
        
        if ThreemaEnvironment.fsDebugStatusMessages {
            postSystemMessage(
                for: contact.identity,
                reason: kFsDebugMessage,
                arg: msg
            )
        }
    }
    
    func first4DhMessageReceived(session: DHSession, contact: ForwardSecurityContact) {
        DDLogNotice(
            "[ForwardSecurity] First 4DH message received in \(session)"
        )

        if ThreemaEnvironment.fsDebugStatusMessages {
            postSystemMessage(
                for: contact.identity,
                reason: kFsDebugMessage,
                arg: "First 4DH message received in session \(session.description)"
            )
        }
        
        // If we received a message with forward security in a session of version 1.0, then we inform that forward
        // security has been enabled (by both participants). Note that this is only necessary for version 1.0, as
        // forward security is enabled by default starting in version 1.1 and therefore the status is shown as soon as
        // the session has been established
        
        if session.outgoingAppliedVersion == .v10 {
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionEstablished)
            
            // We do not save here but wait for this change to be saved together with the final save in message
            // processing.
            // If we were to save here we might stop processing the message and retry at a later date having state that
            // is not quite correct. It could for example happen that we stop processing a message and then wait for
            // long
            // enough for the message to be deleted from server. We then have weird state.
            entityManager.performAndWait {
                guard let contact = self.entityManager.entityFetcher.contact(for: contact.identity) else {
                    DDLogError(
                        "[ForwardSecurity] Could not fetch contact (\(contact.identity)) when attempting to set FS flag to enabled"
                    )
                    return
                }
                
                contact.forwardSecurityState = NSNumber(value: ForwardSecurityState.on.rawValue)
            }
        }
    }
    
    func initiatorSessionEstablished(session: DHSession, contact: ForwardSecurityContact) {
        DDLogNotice(
            "[ForwardSecurity] Initiator DH session established \(session)"
        )

        if ThreemaEnvironment.fsDebugStatusMessages {
            postSystemMessage(
                for: contact.identity,
                reason: kFsDebugMessage,
                arg: "Initiator DH session established \(session.description)"
            )
        }
        
        // Rationale for local/outgoing applied version: Should be identical to remote/incoming
        // version after initial negotiation.
        if session.outgoingAppliedVersion.rawValue >= CspE2eFs_Version.v11.rawValue {
            // If a new session has been established with V1.1 or higher, we display the message, that forward security
            // has been enabled (by both participants) in this chat.
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionEstablished)
        }
    }
    
    func versionsUpdated(
        in session: DHSession,
        versionUpdatedSnapshot: UpdatedVersionsSnapshot,
        contact: ForwardSecurityContact
    ) {
        DDLogNotice(
            "[ForwardSecurity] \(session.description) updated \(versionUpdatedSnapshot.description) with contact: \(contact.identity)"
        )

        if ThreemaEnvironment.fsDebugStatusMessages {
            let string = "\(session.description) updated \(versionUpdatedSnapshot.description)"
            postSystemMessage(for: contact.identity, reason: kFsDebugMessage, arg: string)
        }
        
        var forwardSecurityStateIsOff: Bool? = nil
        
        // See `first4DhMessageReceived(session:contact:)` for an explanation of why this is not
        // `performBlockSyncAndSafe`.
        entityManager.performAndWait {
            guard let contact = self.entityManager.entityFetcher.contact(for: contact.identity) else {
                DDLogError(
                    "[ForwardSecurity] Could not find contact (\(contact.identity)) when attempting to post negotiated version update"
                )
                return
            }
            forwardSecurityStateIsOff = ForwardSecurityState(rawValue: contact.forwardSecurityState.uintValue) ==
                ForwardSecurityState.off
        }
        
        guard let forwardSecurityStateIsOff else {
            DDLogError(
                "[ForwardSecurity] Could not determine forward security state for contact (\(contact.identity))"
            )
            return
        }
        
        // If we update a session from version 1.0 to 1.1 (or newer), then we show a status message, that forward
        // security has been enabled (by both participants). Note that this message is only shown, when no 4DH message
        // has been received in the session with version 1.0 because the message has already been shown at this point.
        // TODO(ANDR-2452): Remove this status message when most of clients support 1.1 anyway
        if versionUpdatedSnapshot.before.local == .v10,
           versionUpdatedSnapshot.after.local.rawValue >= CspE2eFs_Version.v11.rawValue,
           forwardSecurityStateIsOff {
            postSystemMessage(for: contact.identity, reason: kSystemMessageFsSessionEstablished)
        }
    }
    
    func sessionForMessageNotFound(in sessionDescription: String, messageID: String, contact: ForwardSecurityContact) {
        let string = "\(sessionDescription) for message with ID \(messageID) not found"
        DDLogNotice("[ForwardSecurity] \(string)")
        
        guard ThreemaEnvironment.fsDebugStatusMessages else {
            return
        }
        postSystemMessage(for: contact.identity, reason: kFsDebugMessage, arg: string)
    }
    
    func messageWithoutFSReceived(in session: DHSession, contactIdentity: String, message: AbstractMessage) {
        DDLogError(
            "[ForwardSecurity] Received message \(message.messageID.hexString) from \(contactIdentity) without forward security of type \(message.type()) despite having a session \(session.description) with negotiated version \(session)"
        )
        
        // Rationale for local/outgoing applied version: We expect both sides to speak the version
        // eventually if it was offered by remote (but not yet applied) and we also use it in
        // `first4DhMessageReceived`.
        if session.outgoingAppliedVersion == .v10 {
            // See `first4DhMessageReceived(session:contact:)` for an explanation of why this is not
            // `performBlockSyncAndSafe`.
            entityManager.performAndWait {
                guard let contact = self.entityManager.entityFetcher.contact(for: contactIdentity) else {
                    DDLogError(
                        "[ForwardSecurity] Could not fetch contact (\(contactIdentity)) when attempting to update the forward security state"
                    )
                    return
                }
                            
                // For sessions of version 1.0 show warning only once
                if ForwardSecurityState(rawValue: contact.forwardSecurityState.uintValue) ==
                    ForwardSecurityState.on {
                    contact.forwardSecurityState = NSNumber(value: ForwardSecurityState.off.rawValue)
                    self.postSystemMessage(
                        for: contactIdentity,
                        reason: kSystemMessageFsMessageWithoutForwardSecurity
                    )
                }
            }
        }
        else if session.outgoingAppliedVersion.rawValue >= CspE2eFs_Version.v11.rawValue {
            // TODO(ANDR-2452): Do not distinguish between 1.0 and newer versions when enough clients have updated. Show this status message for every message without FS.
            //  For sessions with version 1.1 or newer, inform for every message without fs
            postSystemMessage(for: contactIdentity, reason: kSystemMessageFsMessageWithoutForwardSecurity)
        }
    }
    
    func sessionNotFound(sessionID: DHSessionID, contact: ForwardSecurityContact) {
        DDLogNotice("[ForwardSecurity] DH session not found (ID=\(sessionID), contact=\(contact.identity)")

        guard ThreemaEnvironment.fsDebugStatusMessages else {
            return
        }
        
        postSystemMessage(
            for: contact.identity,
            reason: kFsDebugMessage,
            arg: "DH session not found (ID \(sessionID.description))"
        )
    }
    
    func illegalSessionState(identity: String, sessionID: DHSessionID) {
        postSystemMessage(for: identity, reason: kSystemMessageFsIllegalSessionState, arg: 0)
    }
    
    private func showResetOrNotSupportedAnymore(contact: ForwardSecurityContact, _ hasForwardSecuritySupport: Bool) {
        if hasForwardSecuritySupport {
            postSystemMessage(
                for: contact.identity,
                reason: kSystemMessageFsSessionReset,
                arg: 0,
                allowDuplicates: true
            )
        }
        else {
            postSystemMessage(
                for: contact.identity,
                reason: kSystemMessageFsNotSupportedAnymore,
                arg: 0,
                allowDuplicates: false
            )
        }
    }
    
    private func postSystemMessage(for contactIdentity: String, reason: Int, arg: Int, allowDuplicates: Bool = true) {
        postSystemMessage(for: contactIdentity, reason: reason, arg: String(arg), allowDuplicates: allowDuplicates)
    }
    
    private func postSystemMessage(
        for contactIdentity: String,
        reason: Int,
        arg: String? = nil,
        allowDuplicates: Bool = true
    ) {
        entityManager.performAndWaitSave {
            if let conversation = self.entityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: true,
                setLastUpdate: false,
                keepContactHidden: true
            ) {
                if !allowDuplicates {
                    let messageFetcher = MessageFetcher(for: conversation, with: self.entityManager)
                    if let lastSystemMessage = messageFetcher.lastMessage() as? SystemMessageEntity,
                       lastSystemMessage.type.intValue == reason {
                        DDLogNotice("[ForwardSecurity] Don't post duplicate system message for \(reason)")
                        return
                    }
                }
                
                let systemMessage = self.entityManager.entityCreator.systemMessageEntity(for: conversation)
                systemMessage?.type = NSNumber(value: reason)
                systemMessage?.arg = arg?.data(using: .utf8)
                systemMessage?.remoteSentDate = Date()
                if systemMessage?.isAllowedAsLastMessage ?? false {
                    conversation.lastMessage = systemMessage
                }
            }
            else {
                DDLogNotice("[ForwardSecurity] Can't add status message because conversation is nil")
            }
        }
    }
    
    func updateFeatureMask(for contact: ForwardSecurityContact) async -> Bool {
        await withCheckedContinuation { continuation in
            entityManager.performAndWaitSave {
                guard let contactEntity = self.entityManager.entityFetcher.contact(for: contact.identity) else {
                    continuation.resume(returning: false)
                    return
                }
                
                FeatureMask.check(
                    contacts: [contactEntity],
                    for: Int(FEATURE_MASK_FORWARD_SECURITY),
                    force: true
                ) { _ in
                    // Feature mask has been updated in DB, will be respected on next message send
                    self.entityManager.performAndWait {
                        continuation.resume(returning: contactEntity.isForwardSecurityAvailable())
                    }
                }
            }
        }
    }
    
    func hasForwardSecuritySupport(_ contact: ForwardSecurityContact) async -> Bool {
        await entityManager.perform {
            guard let contactEntity = self.entityManager.entityFetcher.contact(for: contact.identity) as? ContactEntity
            else {
                return false
            }
            
            return contactEntity.isForwardSecurityAvailable()
        }
    }
}
