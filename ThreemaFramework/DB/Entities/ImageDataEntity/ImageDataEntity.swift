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

@objc(ImageDataEntity)
public class ImageDataEntity: TMAManagedObject {
    
    // Attributes
    @NSManaged @objc(data) public var data: Data
    @NSManaged @objc(height) public var height: Int16
    @NSManaged @objc(width) public var width: Int16
    
    // Relationships
    @NSManaged public var message: ImageMessageEntity?
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - data: Data for the entity
    ///   - height: Height of the underlying image
    ///   - width: Width of the underlying image
    ///   - message: ImageMessageEntity the entity belongs to
    public init(
        context: NSManagedObjectContext,
        data: Data,
        height: Int16,
        width: Int16,
        message: ImageMessageEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "ImageData", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.data = data
        self.height = height
        self.width = width
        
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
