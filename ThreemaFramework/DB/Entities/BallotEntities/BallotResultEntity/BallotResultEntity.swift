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

/// Result might be a little misleading, in simpler terms, this is a vote by a participant.
@objc(BallotResultEntity)
public final class BallotResultEntity: TMAManagedObject {
    
    // Attributes
    @NSManaged @objc(createDate) public var createDate: Date?
    @NSManaged @objc(modifyDate) public var modifyDate: Date?
    // swiftformat:disable:next acronyms
    @NSManaged @objc(participantId) public var participantId: String
    // TODO: (IOS-4752) Change to Int16 once all uses are written in swift.
    @NSManaged @objc(value) public var value: NSNumber?

    // Relationships
    @NSManaged @objc(ballotChoice) public var ballotChoice: BallotChoice
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - createDate: Date when created
    ///   - modifyDate: Date when last modified
    ///   - participantID: ID of the participant
    ///   - value: Value of the result
    ///   - ballotChoice: BallotChoiceEntity the result belongs to
    public init(
        context: NSManagedObjectContext,
        createDate: Date? = nil,
        modifyDate: Date? = nil,
        participantID: String,
        value: Bool? = nil,
        ballotChoice: BallotChoice
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BallotResult", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.createDate = createDate
        self.modifyDate = modifyDate
        // swiftformat:disable:next acronyms
        self.participantId = participantID
        if let value {
            self.value = value as NSNumber
        }
        
        self.ballotChoice = ballotChoice
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
