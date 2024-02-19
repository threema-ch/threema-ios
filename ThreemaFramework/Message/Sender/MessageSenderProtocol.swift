//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import CoreLocation
import Foundation
import PromiseKit
import ThreemaEssentials

public enum MessageSenderError: Error {
    case tooBig
    case noID
    case unableToLoadConversation
    case unableToLoadMessage
    case sendingFailed
}

public enum MessageSenderReceivers {
    // Send to all members in this conversation (For 1:1 there is just one receiver)
    case all
    // Send to a subset of members in a group. This is invalid for 1:1 conversations.
    case groupMembers([ThreemaIdentity])
}

/// Central place to send or resend a message
///
/// Use this to send any message (including blob messages)
public protocol MessageSenderProtocol {

    // MARK: - Type specific sending
    
    func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessage?) -> Void)?
    )
    
    func sanitizeAndSendText(_ rawText: String, in conversation: Conversation)
    
    func sendBlobMessage(
        for item: URLSenderItem,
        in conversationObjectID: NSManagedObjectID,
        correlationID: String?,
        webRequestID: String?
    ) async throws

    func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: Conversation
    )

    func sendBallotMessage(for ballot: Ballot)

    func sendBallotVoteMessage(for ballot: Ballot)

    // MARK: - Generic sending

    /// Send abstract message
    ///
    /// This should only be used for abstract messages that are not stored in Core Data, because this won't update all
    /// flags of the CD object correctly. Use `sendBaseMessage(with:to:)` instead.
    ///
    /// - Parameters:
    ///   - abstractMessage: Abstract message
    ///   - isPersistent: Should task (and thus the abstract message) be persisted if the app is terminated?
    ///   - completion: Called when the task is completed (NOT when adding is completed). This handler is not persisted!
    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool, completion: (() -> Void)?)
    
    func sendBaseMessage(with objectID: NSManagedObjectID, to receivers: MessageSenderReceivers) async
    
    // MARK: - Status update

    func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> Promise<Void>

    func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaIdentity) async

    func sendReadReceipt(for messages: [BaseMessage], toGroupIdentity: GroupIdentity) async

    func sendUserAck(for message: BaseMessage, toIdentity: ThreemaIdentity) async

    func sendUserAck(for message: BaseMessage, toGroup: Group) async

    func sendUserDecline(for message: BaseMessage, toIdentity: ThreemaIdentity) async

    func sendUserDecline(for message: BaseMessage, toGroup: Group) async

    func sendTypingIndicator(typing: Bool, toIdentity: ThreemaIdentity)

    func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool

    func doSendReadReceipt(to conversation: Conversation) -> Bool

    func doSendTypingIndicator(to contact: ContactEntity?) -> Bool

    func doSendTypingIndicator(to conversation: Conversation) -> Bool
}

extension MessageSenderProtocol {
    public func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String? = nil
    ) {
        sendTextMessage(text: text, in: conversation, quickReply: quickReply, requestID: requestID, completion: nil)
    }
    
    public func sendBlobMessage(
        for item: URLSenderItem,
        in conversationObjectID: NSManagedObjectID,
        correlationID: String? = nil,
        webRequestID: String? = nil
    ) async throws {
        try await sendBlobMessage(
            for: item,
            in: conversationObjectID,
            correlationID: correlationID,
            webRequestID: webRequestID
        )
    }

    /// Send abstract message
    ///
    /// This should only be used for abstract messages that are not stored in Core Data, because this won't update all
    /// flags of the CD object correctly. Use `sendBaseMessage(with:to:)` instead.
    ///
    /// - Parameters:
    ///   - abstractMessage: Abstract message
    ///   - isPersistent: Should task (and thus the abstract message) be persisted if the app is terminated?
    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool = true) {
        sendMessage(abstractMessage: abstractMessage, isPersistent: isPersistent, completion: nil)
    }
    
    public func sendBaseMessage(with objectID: NSManagedObjectID) async {
        await sendBaseMessage(with: objectID, to: .all)
    }

    func sendReadReceipt(
        for messages: [BaseMessage],
        toGroupIdentity: GroupIdentity,
        completion: @escaping () -> Void
    ) {
        Task {
            await self.sendReadReceipt(for: messages, toGroupIdentity: toGroupIdentity)
            completion()
        }
    }
}
