//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

@objc(GroupCallEntity)
public class GroupCallEntity: NSManagedObject, Identifiable {
    
    // Attributes
    @NSManaged @objc(gck) public var gck: Data?
    // TODO: (IOS-4752) Change to Int32 once all uses are written in swift.
    @NSManaged @objc(protocolVersion) public var protocolVersion: NSNumber?
    @NSManaged @objc(sfuBaseURL) public var sfuBaseURL: String?
    @NSManaged @objc(startMessageReceiveDate) public var startMessageReceiveDate: Date?
    
    // Relationships
    @NSManaged public var group: GroupEntity?
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - gck: GroupCallKey
    ///   - protocolVersion: Version of the protocol
    ///   - sfuBaseURL: String of group call base URL
    ///   - startMessageReceiveDate: Date the start message was received
    ///   - group: GroupEntity of the group the start message was received in
    public init(
        context: NSManagedObjectContext,
        gck: Data? = nil,
        protocolVersion: Int32? = nil,
        sfuBaseURL: String? = nil,
        startMessageReceiveDate: Date? = nil,
        group: GroupEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "GroupCallEntity", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.gck = gck
        if let protocolVersion {
            self.protocolVersion = protocolVersion as NSNumber
        }
        self.sfuBaseURL = sfuBaseURL
        self.startMessageReceiveDate = startMessageReceiveDate
        
        self.group = group
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