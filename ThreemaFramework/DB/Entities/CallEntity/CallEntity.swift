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

@objc(CallEntity)
public final class CallEntity: TMAManagedObject {
    
    // Attributes
    @NSManaged @objc(callID) public var callID: NSNumber?
    @NSManaged @objc(date) public var date: NSDate?
   
    // Relationships
    @NSManaged public var contact: ContactEntity?
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - callID: ID of the call
    ///   - date: Date the call was started
    ///   - contactEntity: Contact the call was held with
    public init(
        context: NSManagedObjectContext,
        callID: Int32? = nil,
        date: Date? = nil,
        contactEntity: ContactEntity?
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "Call", in: context)!
        super.init(entity: entity, insertInto: context)
        
        if let callID {
            self.callID = callID as NSNumber
        }
        if let date {
            self.date = date as NSDate
        }
        
        self.contact = contactEntity
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
