//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
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

public enum CallSystemMessageHelper {
    public static func maybeAddMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((Conversation?, SystemMessage?) -> Void)? = nil
    ) {
        Task {
            let callHistoryManager = CallHistoryManager(
                identity: hangupMessage.contactIdentity,
                businessInjector: businessInjector
            )
            if await callHistoryManager.isMissedCall(
                from: hangupMessage.contactIdentity,
                callID: hangupMessage.callID.callID
            ) {
                addMissedCallNotificationToConversation(
                    with: hangupMessage,
                    on: businessInjector,
                    messsageCreateCompletion: messsageCreateCompletion
                )
            }
            else {
                messsageCreateCompletion?(nil, nil)
                DDLogVerbose("Not a missed call. Do not add message!")
            }
        }
    }
    
    public static func addRejectedMessageToConversation(
        contactIdentity: String,
        reason: Int,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((Conversation, SystemMessage) -> Void)? = nil
    ) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            guard let conversation = businessInjector.backgroundEntityManager.conversation(
                for: contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add rejected message because conversation is nil"
                DDLogError(msg)
                assertionFailure(msg)
                return
            }
            guard let systemMessage = businessInjector.backgroundEntityManager.entityCreator
                .systemMessage(for: conversation) else {
                let msg = "Could not create system message"
                DDLogError(msg)
                assertionFailure(msg)
                return
            }
            
            businessInjector.backgroundEntityManager.performSyncBlockAndSafe {
                systemMessage.type = NSNumber(value: reason)
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: false),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: false)
                    systemMessage.conversation = conversation
                    conversation.lastMessage = systemMessage
                    conversation.lastUpdate = Date()
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
            messsageCreateCompletion?(conversation, systemMessage)
        }
    }
    
    // MARK: Private Functions
    
    private static func addMissedCallNotificationToConversation(
        with hangupMessage: VoIPCallHangupMessage,
        on businessInjector: BusinessInjectorProtocol,
        messsageCreateCompletion: ((Conversation, SystemMessage) -> Void)? = nil
    ) {
        businessInjector.backgroundEntityManager.performBlockAndWait {
            guard let conversation = businessInjector.backgroundEntityManager.conversation(
                for: hangupMessage.contactIdentity,
                createIfNotExisting: true
            ) else {
                let msg = "Threema Calls: Can't add rejected message because conversation is nil"
                DDLogError(msg)
                assertionFailure(msg)
                return
            }
            
            guard let systemMessage = businessInjector.backgroundEntityManager.entityCreator
                .systemMessage(for: conversation) else {
                let msg = "Could not create system message"
                DDLogError(msg)
                assertionFailure(msg)
                return
            }
            
            businessInjector.backgroundEntityManager.performSyncBlockAndSafe {
                systemMessage.remoteSentDate = hangupMessage.date
                systemMessage.type = NSNumber(integerLiteral: kSystemMessageCallMissed)
                
                let callInfo = [
                    "DateString": DateFormatter.shortStyleTimeNoDate(Date()),
                    "CallInitiator": NSNumber(booleanLiteral: false),
                ] as [String: Any]
                do {
                    let callInfoData = try JSONSerialization.data(withJSONObject: callInfo, options: .prettyPrinted)
                    systemMessage.arg = callInfoData
                    systemMessage.isOwn = NSNumber(booleanLiteral: false)
                    systemMessage.conversation = conversation
                    conversation.lastMessage = systemMessage
                    conversation.lastUpdate = Date()
                }
                catch {
                    DDLogError("An error occurred: \(error.localizedDescription)")
                }
            }
            
            messsageCreateCompletion?(conversation, systemMessage)
        }
    }
}
