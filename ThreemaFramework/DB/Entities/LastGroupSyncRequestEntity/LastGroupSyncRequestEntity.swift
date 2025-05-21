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

@objc(LastGroupSyncRequestEntity)
public final class LastGroupSyncRequestEntity: TMAManagedObject {
    
    // MARK: Attributes

    @NSManaged public var groupCreator: String
    // swiftformat:disable:next acronyms
    @NSManaged public var groupId: Data
    @NSManaged public var lastSyncRequest: Date
   
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - groupCreator: ID of the creator of the group of which the request was made
    ///   - groupID: ID of the group of which the request was made
    ///   - lastSyncRequest: Date when the request was made
    public init(
        context: NSManagedObjectContext,
        groupCreator: String,
        groupID: Data,
        lastSyncRequest: Date
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "LastGroupSyncRequest", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.groupCreator = groupCreator
        // swiftformat:disable:next acronyms
        self.groupId = groupID
        self.lastSyncRequest = lastSyncRequest
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
