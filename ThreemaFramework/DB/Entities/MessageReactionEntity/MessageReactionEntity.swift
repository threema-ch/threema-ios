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

@objc(MessageReactionEntity)
public final class MessageReactionEntity: TMAManagedObject {

    // MARK: Attributes

    @NSManaged public var reaction: String
    @NSManaged public var date: Date

    // MARK: Relationships

    @NSManaged public var message: BaseMessageEntity
    @NSManaged public var creator: ContactEntity?
    
    // MARK: Lifecycle

    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - creator: The `ContactEntity` of the creator of the reaction, nil if we reacted
    ///   - reaction: The string of the reaction itself, e.g. the emoji
    ///   - message: `BaseMessageEntity` the entity belongs to
    public init(
        context: NSManagedObjectContext,
        reaction: String,
        contact: ContactEntity? = nil,
        message: BaseMessageEntity
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "MessageReaction", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.creator = contact
        self.reaction = reaction
        
        self.message = message
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

extension MessageReactionEntity {
    var emoji: Emoji? {
        .init(rawValue: reaction)
    }
}
