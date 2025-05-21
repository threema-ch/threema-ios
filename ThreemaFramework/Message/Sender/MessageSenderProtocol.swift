//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
    case noData
    case noID
    case unableToLoadConversation
    case unableToLoadMessage
    case sendingFailed
    case editedTextToLong
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
@preconcurrency public protocol MessageSenderProtocol {

    // MARK: - Type specific sending
    
    /// Sanitizes, splits if needed and sends a text as TextMessage(s). Also works for distribution lists.
    @discardableResult
    func sendTextMessage(
        containing text: String,
        in conversation: ConversationEntity,
        sendProfilePicture: Bool,
        requestID: String?
    ) async -> [TextMessageEntity]
        
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
        in conversation: ConversationEntity
    ) async

    func sendBallotMessage(for ballot: BallotEntity)

    func sendBallotVoteMessage(for ballot: BallotEntity)

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

    func sendDeleteMessage(with objectID: NSManagedObjectID, receiversExcluded: [Contact]?) throws

    /// Send `EditMessage` to all the receiver(s) of the given message.
    ///
    /// - Parameters:
    ///   - objectID: Object-ID of the edited message
    ///   - rawText: New text of the message
    ///   - receiversExcluded: Excluded contacts from sending `EditMessage`
    func sendEditMessage(with objectID: NSManagedObjectID, rawText: String, receiversExcluded: [Contact]?) throws

    // MARK: - Status update
    
    @discardableResult
    func sendReaction(to objectID: NSManagedObjectID, reaction: EmojiVariant) async throws -> ReactionsManager
        .ReactionSendingResult
    
    func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> Promise<Void>

    func sendReadReceipt(for messages: [BaseMessageEntity], toIdentity: ThreemaIdentity) async

    func sendReadReceipt(for messages: [BaseMessageEntity], toGroupIdentity: GroupIdentity) async

    func sendTypingIndicator(typing: Bool, toIdentity: ThreemaIdentity)

    func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool

    func doSendReadReceipt(to conversation: ConversationEntity) -> Bool

    func doSendTypingIndicator(to contact: ContactEntity?) -> Bool

    func doSendTypingIndicator(to conversation: ConversationEntity) -> Bool
}

extension MessageSenderProtocol {
    // MARK: - TextMessage

    public func sendTextMessage(
        containing text: String,
        in conversation: ConversationEntity,
        sendProfilePicture: Bool = true,
        requestID: String? = nil
    ) {
        Task {
            await sendTextMessage(
                containing: text,
                in: conversation,
                sendProfilePicture: sendProfilePicture,
                requestID: requestID
            )
        }
    }
    
    public func sendTextMessage(
        containing text: String,
        in conversation: ConversationEntity,
        sendProfilePicture: Bool = true,
        requestID: String? = nil
    ) async -> [TextMessageEntity] {
        await sendTextMessage(
            containing: text,
            in: conversation,
            sendProfilePicture: sendProfilePicture,
            requestID: requestID
        )
    }
    
    // MARK: - BlobMessage

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
    
    // MARK: - LocationMessage

    public func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: ConversationEntity
    ) {
        Task {
            await sendLocationMessage(
                coordinates: coordinates,
                accuracy: accuracy,
                poiName: poiName,
                poiAddress: poiAddress,
                in: conversation
            )
        }
    }

    /// Send abstract message
    ///
    /// This should only be used for abstract messages that are not stored in Core Data, because this won't update all
    /// flags of the CD object correctly. Use `sendBaseMessage(with:to:)` instead.
    ///
    /// - Parameters:
    ///   - abstractMessage: Abstract message
    ///   - isPersistent: Should task (and thus the abstract message) be persisted if the app is terminated? If `true`
    ///                   the task type is `persistent` otherwise `volatile`.
    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool = true) {
        sendMessage(abstractMessage: abstractMessage, isPersistent: isPersistent, completion: nil)
    }
    
    public func sendBaseMessage(with objectID: NSManagedObjectID) async {
        await sendBaseMessage(with: objectID, to: .all)
    }

    func sendReadReceipt(
        for messages: [BaseMessageEntity],
        toGroupIdentity: GroupIdentity,
        completion: @escaping () -> Void
    ) {
        Task {
            await self.sendReadReceipt(for: messages, toGroupIdentity: toGroupIdentity)
            completion()
        }
    }
}
