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

@objc(GroupEntity)
public final class GroupEntity: TMAManagedObject {
    
    // MARK: Attributes

    @NSManaged public var groupCreator: String?
    // swiftformat:disable:next acronyms
    @NSManaged public var groupId: Data
    @NSManaged public var lastPeriodicSync: Date?
    @NSManaged public var state: NSNumber
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - groupCreator: Threema ID of the creator
    ///   - groupID: Group ID
    ///   - lastPeriodicSync: `Date` of last periodic group sync
    ///   - state: Our current state for the group
    public init(
        context: NSManagedObjectContext,
        groupCreator: String? = nil,
        groupID: Data,
        lastPeriodicSync: Date? = nil,
        state: NSNumber
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Group", in: context)!
        super.init(entity: entity, insertInto: context)

        self.groupCreator = groupCreator
        // swiftformat:disable:next acronyms
        self.groupId = groupID
        self.lastPeriodicSync = lastPeriodicSync
        self.state = state
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
