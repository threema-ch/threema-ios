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

@objc(LocationMessageEntity)
public final class LocationMessageEntity: BaseMessage {
    
    // Attributes
    @NSManaged @objc(accuracy) public var accuracy: NSNumber?
    @NSManaged @objc(latitude) public var latitude: NSNumber
    @NSManaged @objc(longitude) public var longitude: NSNumber
    @NSManaged @objc(poiAddress) public var poiAddress: String?
    @NSManaged @objc(poiName) public var poiName: String?
    
    // Lifecycle
    
    // TODO: (IOS-4752) Use in EntityCreator/DB Preparer
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: NSManagedObjectContext to insert created entity into
    ///   - accuracy: Accuracy of the POI
    ///   - latitude: Latitude of the POI
    ///   - longitude: Longitude of the POI
    ///   - poiAddress: Address of the POI
    ///   - poiName: Name of the POI
    public init(
        context: NSManagedObjectContext,
        accuracy: Double? = nil,
        latitude: Double,
        longitude: Double,
        poiAddress: String? = nil,
        poiName: String? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "LocationMessage", in: context)!
        super.init(entity: entity, insertInto: context)
        if let accuracy {
            self.accuracy = accuracy as NSNumber
        }
        self.latitude = latitude as NSNumber
        self.longitude = longitude as NSNumber
        self.poiAddress = poiAddress
        self.poiName = poiName
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
