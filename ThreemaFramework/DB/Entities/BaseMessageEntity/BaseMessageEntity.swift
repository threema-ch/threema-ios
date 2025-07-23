//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import CoreData
import Foundation

@objc(BaseMessageEntity)
public class BaseMessageEntity: TMAManagedObject {
    
    struct BaseMessageFlags: OptionSet {
        let rawValue: Int
        static let sendPush = 1 << 0
        static let dontQueue = 1 << 1
        static let dontAck = 1 << 2
        static let alreadyDelivered = 1 << 3
        static let group = 1 << 4
        static let immediateDelivery = 1 << 5
        static let silentPush = 1 << 6
        static let noDeliveryReceipt = 1 << 7
    }
    
    // MARK: Attributes

    /// Creation date of this message in Core Data, non-optional in DB Model
    @NSManaged public var date: Date?
    @NSManaged public var deletedAt: Date?
    @NSManaged public var delivered: NSNumber
    
    /// Outgoing message:
    /// - Displayed as delivered
    /// - Update -> CSP: Sent (created) date set by sender (incoming `DeliveryReceiptMessage.date`), MDP: Created date
    /// set by sender (`D2d_IncomingMessage.createdAt`)
    /// Incoming message:
    /// - Displayed as received
    /// - Update -> CSP: Date set by receiver (`Date.now`), MDP: Reflected date set by receiver after reflecting
    /// (leader) or when processing incoming reflected message (none leader)
    @NSManaged public var deliveryDate: Date?
    @NSManaged public var flags: NSNumber?
    @NSManaged public var forwardSecurityMode: NSNumber
    @NSManaged public var groupDeliveryReceipts: [GroupDeliveryReceipt]?
    @NSManaged public var id: Data
    @NSManaged public var isCreatedFromWeb: NSNumber?
   
    /// Is this a message I sent?
    @NSManaged public var isOwn: NSNumber
    @NSManaged public var lastEditedAt: Date?
    @NSManaged private var property1: String?
    @NSManaged private var property2: NSNumber?
    @NSManaged public var read: NSNumber
    @NSManaged public var readDate: Date?
   
    /// Remote sent date of message. This can be `nil` and these must be handled by the caller.
    /// Before we rewrote this class in Swift, this was never `nil`.
    ///
    /// Outgoing message:
    /// - Displayed as sent
    /// - Update -> CSP: Staring with with 4.9 date when message was acknowledged by server. For local messages and
    /// before 4.7 `date` is returned. MDP: Reflected date after reflecting
    /// Incoming message:
    /// - Displayed as sent
    /// - Update -> CSP: Sent (created) date set by sender (`AbstractMessage.date`), MDP: Created date set by sender
    /// (`D2d_IncomingMessage.createdAt`)
    @NSManaged public var remoteSentDate: Date?
    
    /// Set if sending failed (this includes rejected by FS)
    @NSManaged public var sendFailed: NSNumber?
    @NSManaged public var sent: NSNumber
    
    @available(*, deprecated, message: "Ack/Dec have been migrated to `reactions` in Version 6.0. Do not use.")
    @NSManaged public var userack: NSNumber
    
    @available(*, deprecated, message: "Ack/Dec have been migrated to `reactions` in Version 6.0. Do not use.")
    @NSManaged public var userackDate: Date?
   
    // swiftformat:disable:next acronyms
    @NSManaged public var webRequestId: String?
    
    // MARK: Relationships

    @NSManaged public var conversation: ConversationEntity
    @NSManaged public var distributedMessages: Set<BaseMessageEntity>?
    @NSManaged public var distributionListMessage: BaseMessageEntity?
    @NSManaged public var historyEntries: Set<MessageHistoryEntryEntity>?
    @NSManaged public var messageMarkers: MessageMarkersEntity?
    @NSManaged public var reactions: Set<MessageReactionEntity>?
    
    /// Contacts that rejected this message
    ///
    /// This is only set for group messages.
    /// The inverse is `rejectedMessages` in `ContactEntity`.
    @NSManaged public var rejectedBy: Set<ContactEntity>?
    @NSManaged public var sender: ContactEntity?
    
    // MARK: Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - date: `Date` the message was created in CoreData
    ///   - deletedAt: `Date` the message was deleted
    ///   - delivered: `True` if message was delivered
    ///   - deliveryDate: `Date` the message was delivered
    ///   - flags: Flags of the message
    ///   - forwardSecurityMode: Forward security mode of the message
    ///   - groupDeliveryReceipts: `GroupDeliveryReceipt` of the message
    ///   - id: ID of the Message
    ///   - isCreatedFromWeb: `True` if message was created in Web
    ///   - isOwn: `True` if message is own
    ///   - lastEditedAt: `Date` the message was last edited at
    ///   - read: `True` if message was read
    ///   - readDate: `Date` the message was read
    ///   - remoteSentDate: `Date` the message sent
    ///   - sendFailed: `True` if message sending failed
    ///   - sent: `True` if message has been sent
    ///   - webRequestID: ID of the web request of the message
    ///   - conversation: `ConversationEntity` the message belongs to
    ///   - distributedMessages: Set of `BaseMessageEntity` that were distributed to other chats
    ///   - distributionListMessage: `BaseMessageEntity` from where this message was distributed from
    ///   - historyEntries: Set of `MessageHistoryEntryEntity` that contain the edit history
    ///   - messageMarkers: `MessageMarkersEntity` containing the markers applied to this nessage
    ///   - reactions: Set of `MessageReactionEntity` that contains the reactions applied to this message
    ///   - rejectedBy: Set of `ContactEntity` that contains contacts that have rejected this message
    ///   - sender: `ContactEntity` that sent this message
    init(
        context: NSManagedObjectContext,
        date: Date,
        deletedAt: Date? = nil,
        delivered: NSNumber,
        deliveryDate: Date? = nil,
        flags: NSNumber? = nil,
        forwardSecurityMode: NSNumber,
        groupDeliveryReceipts: [GroupDeliveryReceipt]? = nil,
        id: Data,
        isCreatedFromWeb: NSNumber? = nil,
        isOwn: NSNumber,
        lastEditedAt: Date? = nil,
        read: NSNumber,
        readDate: Date? = nil,
        remoteSentDate: Date? = nil,
        sendFailed: NSNumber? = nil,
        sent: NSNumber,
        webRequestID: String? = nil,
        conversation: ConversationEntity,
        distributedMessages: Set<BaseMessageEntity>? = nil,
        distributionListMessage: BaseMessageEntity? = nil,
        historyEntries: Set<MessageHistoryEntryEntity>? = nil,
        messageMarkers: MessageMarkersEntity? = nil,
        reactions: Set<MessageReactionEntity>? = nil,
        rejectedBy: Set<ContactEntity>? = nil,
        sender: ContactEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Message", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.date = date
        self.deletedAt = deletedAt
        self.delivered = delivered
        self.deliveryDate = deliveryDate
        self.flags = flags
        self.forwardSecurityMode = forwardSecurityMode
        self.groupDeliveryReceipts = groupDeliveryReceipts
        self.id = id
        self.isCreatedFromWeb = isCreatedFromWeb
        self.isOwn = isOwn
        self.lastEditedAt = lastEditedAt
        self.read = read
        self.readDate = readDate
        self.remoteSentDate = remoteSentDate
        self.sendFailed = sendFailed
        self.sent = sent
        
        // Deprecated
        self.userack = NSNumber(booleanLiteral: false)
        self.userackDate = nil
        
        // swiftformat:disable:next acronyms
        self.webRequestId = webRequestID
        
        self.conversation = conversation
        self.distributedMessages = distributedMessages
        self.distributionListMessage = distributionListMessage
        self.historyEntries = historyEntries
        self.messageMarkers = messageMarkers
        self.reactions = reactions
        self.rejectedBy = rejectedBy
        self.sender = sender
    }
    
    @objc override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    @available(*, unavailable)
    public init() {
        fatalError("\(#function) not implemented")
    }
    
    @available(*, unavailable)
    public convenience init(context: NSManagedObjectContext) {
        fatalError("\(#function) not implemented")
    }

    // MARK: Generated accessors for distributedMessages

    @objc(addDistributedMessagesObject:)
    @NSManaged public func addToDistributedMessages(_ value: BaseMessageEntity)

    @objc(removeDistributedMessagesObject:)
    @NSManaged public func removeFromDistributedMessages(_ value: BaseMessageEntity)

    @objc(addDistributedMessages:)
    @NSManaged public func addToDistributedMessages(_ values: NSSet)

    @objc(removeDistributedMessages:)
    @NSManaged public func removeFromDistributedMessages(_ values: NSSet)
    
    // MARK: Generated accessors for historyEntries

    @objc(addHistoryEntriesObject:)
    @NSManaged public func addToHistoryEntries(_ value: MessageHistoryEntryEntity)

    @objc(removeHistoryEntriesObject:)
    @NSManaged public func removeFromHistoryEntries(_ value: MessageHistoryEntryEntity)

    @objc(addHistoryEntries:)
    @NSManaged public func addToHistoryEntries(_ values: NSSet)

    @objc(removeHistoryEntries:)
    @NSManaged public func removeFromHistoryEntries(_ values: NSSet)
    
    // MARK: Generated accessors for reactions

    @objc(addReactionsObject:)
    @NSManaged public func addToReactions(_ value: MessageReactionEntity)

    @objc(removeReactionsObject:)
    @NSManaged public func removeFromReactions(_ value: MessageReactionEntity)

    @objc(addReactions:)
    @NSManaged public func addToReactions(_ values: NSSet)

    @objc(removeReactions:)
    @NSManaged public func removeFromReactions(_ values: NSSet)
    
    // MARK: Generated accessors for rejectedBy

    @objc(addRejectedByObject:)
    @NSManaged public func addToRejectedBy(_ value: ContactEntity)

    @objc(removeRejectedByObject:)
    @NSManaged public func removeFromRejectedBy(_ value: ContactEntity)

    @objc(addRejectedBy:)
    @NSManaged public func addToRejectedBy(_ values: NSSet)

    @objc(removeRejectedBy:)
    @NSManaged public func removeFromRejectedBy(_ values: NSSet)
}
