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

@objc(BallotChoiceEntity)
public final class BallotChoiceEntity: TMAManagedObject {
    
    // MARK: Attributes

    @NSManaged public var createDate: Date?
    @NSManaged public var id: NSNumber
    @NSManaged public var modifyDate: Date?
    @NSManaged public var name: String?
    @NSManaged public var orderPosition: NSNumber?
    @NSManaged public var totalVotes: NSNumber?
    
    // MARK: Relationships

    @NSManaged public var ballot: BallotEntity
    @NSManaged public var result: Set<BallotResultEntity>?
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - createDate: `Date` of the creation
    ///   - id: ID of the choice
    ///   - modifyDate: `Date` last modified
    ///   - name: Name of the choice
    ///   - orderPosition: Position of the choice for ordering
    ///   - totalVotes: Ammount of votes for the choice
    ///   - ballot: `BallotEntity` the entity belongs to
    ///   - result: Set of `BallotResultEntity` belonging to the choice
    init(
        context: NSManagedObjectContext,
        createDate: Date? = nil,
        id: NSNumber,
        modifyDate: Date? = nil,
        name: String? = nil,
        orderPosition: NSNumber? = nil,
        totalVotes: NSNumber? = nil,
        ballot: BallotEntity,
        result: Set<BallotResultEntity>? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "BallotChoice", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.createDate = createDate
        self.id = id
        self.modifyDate = modifyDate
        self.name = name
        self.orderPosition = orderPosition
        self.totalVotes = totalVotes
        
        self.ballot = ballot
        self.result = result
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
    
    // MARK: Generated accessors for result

    @objc(addResultObject:)
    @NSManaged public func addToResult(_ value: BallotResultEntity)

    @objc(removeResultObject:)
    @NSManaged public func removeFromResult(_ value: BallotResultEntity)

    @objc(addResult:)
    @NSManaged public func addToResult(_ values: NSSet)

    @objc(removeResult:)
    @NSManaged public func removeFromResult(_ values: NSSet)
}
