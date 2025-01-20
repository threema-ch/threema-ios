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
public class ConversationEntity: TMAManagedObject {
    
    // Attributes
    @NSManaged @objc(category) public var category: NSNumber
    // swiftformat:disable:next acronyms
    @NSManaged @objc(groupId) public var groupId: Data?
    @NSManaged @objc(groupImageSetDate) public var groupImageSetDate: Date?
    @NSManaged @objc(groupMyIdentity) public var groupMyIdentity: String?
    @NSManaged @objc(groupName) public var groupName: String?
    @NSManaged @objc(lastTypingStart) public private(set) var lastTypingStart: Date?
    @NSManaged @objc(lastUpdate) public var lastUpdate: Date?
    @NSManaged @objc(marked) public var marked: NSNumber
    @NSManaged @objc(typing) public private(set) var typing: NSNumber
    @NSManaged @objc(unreadMessageCount) public var unreadMessageCount: NSNumber
    @NSManaged @objc(visibility) public var visibility: NSNumber

    // Relationships
    @NSManaged public var groupImage: ImageDataEntity?
    @NSManaged public var lastMessage: BaseMessage?
    @NSManaged public var ballots: Set<Ballot>?
    @NSManaged public var distributionList: DistributionListEntity?
    @NSManaged public var contact: ContactEntity?
    @NSManaged public var members: Set<ContactEntity>?

    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into

    public init(
        context: NSManagedObjectContext,
        category: Category = .default,
        groupID: Data? = nil,
        groupImageSetDate: Date? = nil,
        groupMyIdentity: String? = nil,
        groupName: String? = nil,
        lastTypingStart: Date? = nil,
        lastUpdate: Date? = nil,
        marked: Bool = false,
        typing: Bool = false,
        unreadMessageCount: NSNumber = 0,
        visibility: Visibility = .default,
        groupImage: ImageDataEntity? = nil,
        lastMessage: BaseMessage? = nil,
        ballots: Set<Ballot>? = nil,
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
        self.marked = NSNumber(booleanLiteral: marked)
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
}
