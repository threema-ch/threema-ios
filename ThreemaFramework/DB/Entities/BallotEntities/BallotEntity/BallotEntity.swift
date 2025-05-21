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

@objc(BallotEntity)
public final class BallotEntity: TMAManagedObject {
    
    // MARK: Attributes

    @NSManaged public var assessmentType: NSNumber?
    @NSManaged public var choicesType: NSNumber?
    @NSManaged public var createDate: Date?
    // swiftformat:disable:next acronyms
    @NSManaged public var creatorId: String?
    @NSManaged public var displayMode: NSNumber?
    @NSManaged public var id: Data
    @NSManaged public var modifyDate: Date?
    @NSManaged public var state: NSNumber?
    @NSManaged public var title: String?
    @NSManaged public var type: NSNumber?
    
    // MARK: Relationships

    @NSManaged public var choices: Set<BallotChoiceEntity>?
    @NSManaged public var conversation: ConversationEntity?
    @NSManaged public var message: Set<BallotMessageEntity>?
    @NSManaged public var participants: Set<ContactEntity>?
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - assessmentType: `BallotAssessmentType`, single- / multiple-choice
    ///   - choicesType: Type of choices
    ///   - createDate: Date of creation
    ///   - creatorId: ID of creator
    ///   - displayMode: `BallotDisplayMode`, list or summary
    ///   - id: ID of the ballot
    ///   - modifyDate: `Date` of last modification
    ///   - state: `BallotState` Open or closed
    ///   - title: Title of the ballot
    ///   - type: `BallotType`, intermediate or closed
    ///   - choices: Set of `BallotChoiceEntity` beloning to the ballot
    ///   - conversation: `ConversationEntity` the ballot belongs to
    ///   - message: Set of `BallotMessageEntity` belonging to the ballot
    ///   - participants: Set `ContactEntity` participating in the ballot
    init(
        context: NSManagedObjectContext,
        assessmentType: BallotAssessmentType,
        choicesType: NSNumber? = nil,
        createDate: Date? = nil,
        // swiftformat:disable:next acronyms
        creatorId: String? = nil,
        displayMode: BallotDisplayMode = .list,
        id: Data,
        modifyDate: Date? = nil,
        state: BallotState,
        title: String? = nil,
        type: BallotType,
        choices: Set<BallotChoiceEntity>? = nil,
        conversation: ConversationEntity? = nil,
        message: Set<BallotMessageEntity>? = nil,
        participants: Set<ContactEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Ballot", in: context)!
        super.init(entity: entity, insertInto: context)

        self.assessmentType = assessmentType.rawValue as NSNumber
        self.choicesType = choicesType
        self.createDate = createDate
        // swiftformat:disable:next acronyms
        self.creatorId = creatorId
        self.displayMode = displayMode.rawValue as NSNumber
        self.id = id
        self.modifyDate = modifyDate
        self.state = state.rawValue as NSNumber
        self.title = title
        self.type = type.rawValue as NSNumber
        
        self.choices = choices
        self.conversation = conversation
        self.message = message
        self.participants = participants
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
    
    // MARK: Generated accessors for choices

    @objc(addChoicesObject:)
    @NSManaged public func addToChoices(_ value: BallotChoiceEntity)

    @objc(removeChoicesObject:)
    @NSManaged public func removeFromChoices(_ value: BallotChoiceEntity)

    @objc(addChoices:)
    @NSManaged public func addToChoices(_ values: NSSet)

    @objc(removeChoices:)
    @NSManaged public func removeFromChoices(_ values: NSSet)
    
    // MARK: Generated accessors for message

    @objc(addMessageObject:)
    @NSManaged public func addToMessage(_ value: BallotMessageEntity)

    @objc(removeMessageObject:)
    @NSManaged public func removeFromMessage(_ value: BallotMessageEntity)

    @objc(addMessage:)
    @NSManaged public func addToMessage(_ values: NSSet)

    @objc(removeMessage:)
    @NSManaged public func removeFromMessage(_ values: NSSet)
    
    // MARK: Generated accessors for participants

    @objc(addParticipantsObject:)
    @NSManaged public func addToParticipants(_ value: ContactEntity)

    @objc(removeParticipantsObject:)
    @NSManaged public func removeFromParticipants(_ value: ContactEntity)

    @objc(addParticipants:)
    @NSManaged public func addToParticipants(_ values: NSSet)

    @objc(removeParticipants:)
    @NSManaged public func removeFromParticipants(_ values: NSSet)
}
