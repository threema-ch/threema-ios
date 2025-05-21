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

import CoreData
import Foundation

@objc(ConversationEntity)
public final class ConversationEntity: TMAManagedObject {
    
    // MARK: Attributes

    @NSManaged public var category: NSNumber
    // swiftformat:disable:next acronyms
    @NSManaged public var groupId: Data?
    @NSManaged public var groupImageSetDate: Date?
    @NSManaged public var groupMyIdentity: String?
    @NSManaged public var groupName: String?
    @NSManaged public private(set) var lastTypingStart: Date?
    @NSManaged public var lastUpdate: Date?
    @available(*, deprecated, renamed: "visibility", message: "Use `.pinned` in `visibility` instead.")
    @NSManaged public var marked: NSNumber
    @NSManaged public private(set) var typing: NSNumber
    @NSManaged public var unreadMessageCount: NSNumber
    @NSManaged public var visibility: NSNumber

    // MARK: Relationships

    @NSManaged public var ballots: Set<BallotEntity>?
    @NSManaged public var contact: ContactEntity?
    @NSManaged public var distributionList: DistributionListEntity?
    @NSManaged public var groupImage: ImageDataEntity?
    @NSManaged public var lastMessage: BaseMessageEntity?
    @NSManaged public var members: Set<ContactEntity>?

    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - category: `Category` of the conversation
    ///   - groupID: GroupID of the conversation
    ///   - groupImageSetDate: `Date` the group image was set
    ///   - groupMyIdentity: Our ID when we were added to the group
    ///   - groupName: The name of the group
    ///   - lastTypingStart: `Date` we last received a start typing
    ///   - lastUpdate: `Date` the conversation was last updated at
    ///   - typing: `True` if the other side is typing at the moment
    ///   - unreadMessageCount: Count of unread messages
    ///   - visibility: `Visibility` of the conversation
    ///   - groupImage: `ImageDataEntity` of the group picture
    ///   - lastMessage: `BaseMessageEntity` that is the last message
    ///   - distributionList: `DistributionListEntity` if the conversation is a distribution list
    ///   - contact: `ContactEntity` other participant if conversation is 1:1
    ///   - members: Set of `ContactEntity` if conversation is a group
    public init(
        context: NSManagedObjectContext,
        category: Category = .default,
        groupID: Data? = nil,
        groupImageSetDate: Date? = nil,
        groupMyIdentity: String? = nil,
        groupName: String? = nil,
        lastTypingStart: Date? = nil,
        lastUpdate: Date? = nil,
        typing: Bool = false,
        unreadMessageCount: NSNumber = 0,
        visibility: Visibility = .default,
        groupImage: ImageDataEntity? = nil,
        lastMessage: BaseMessageEntity? = nil,
        distributionList: DistributionListEntity? = nil,
        contact: ContactEntity? = nil,
        members: Set<ContactEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Conversation", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.category = category.rawValue as NSNumber
        // swiftformat:disable:next acronyms
        self.groupId = groupID
        self.groupImageSetDate = groupImageSetDate
        self.groupMyIdentity = groupMyIdentity
        self.groupName = groupName
        self.lastTypingStart = lastTypingStart
        self.lastUpdate = lastUpdate
        // Deprecated
        self.marked = false
        self.typing = NSNumber(booleanLiteral: typing)
        self.unreadMessageCount = unreadMessageCount
        self.visibility = visibility.rawValue as NSNumber
        
        self.groupImage = groupImage
        self.lastMessage = lastMessage
        self.ballots = ballots
        self.distributionList = distributionList
        self.contact = contact
        self.members = members
    }
    
    @objc override private init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
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
    
    // MARK: Generated accessors for ballots

    @objc(addBallotsObject:)
    @NSManaged public func addToBallots(_ value: BallotEntity)

    @objc(removeBallotsObject:)
    @NSManaged public func removeFromBallots(_ value: BallotEntity)

    @objc(addBallots:)
    @NSManaged public func addToBallots(_ values: NSSet)

    @objc(removeBallots:)
    @NSManaged public func removeFromBallots(_ values: NSSet)
    
    // MARK: Generated accessors for members

    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: ContactEntity)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: ContactEntity)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)
}
