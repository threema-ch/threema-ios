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

@objc(ImageMessageEntity)
public final class ImageMessageEntity: BaseMessageEntity {
    
    // MARK: Attributes

    @NSManaged public var encryptionKey: Data?
    // swiftformat:disable:next acronyms
    @NSManaged public var imageBlobId: Data?
    @NSManaged public var imageNonce: Data?
    @NSManaged public var imageSize: NSNumber?
    @NSManaged public var progress: NSNumber?

    // MARK: Relationships

    @NSManaged public var image: ImageDataEntity?
    @NSManaged public var thumbnail: ImageDataEntity?
    
    // MARK: Lifecycle
    
    /// Preferred initializer that ensures all non optional values are set
    /// - Parameters:
    ///   - context: `NSManagedObjectContext` to insert created entity into
    ///   - encryptionKey: Key the image data is encrypted with
    ///   - imageBlobID: BlobID of the image data
    ///   - imageNonce: Nonce of the image
    ///   - imageSize: Size of the image data
    ///   - progress: Progress
    ///   - image: `ImageDataEntity` of the image
    ///   - thumbnail: `ImageDataEntity` of the thumbnail
    public init(
        context: NSManagedObjectContext,
        encryptionKey: Data? = nil,
        imageBlobID: Data? = nil,
        imageNonce: Data? = nil,
        imageSize: NSNumber? = nil,
        progress: NSNumber? = nil,
        image: ImageDataEntity? = nil,
        thumbnail: ImageDataEntity? = nil
    ) {
        let entity = NSEntityDescription.entity(forEntityName: "ImageMessage", in: context)!
        super.init(entity: entity, insertInto: context)
        
        self.encryptionKey = encryptionKey
        // swiftformat:disable:next acronyms
        self.imageBlobId = imageBlobID
        self.imageNonce = imageNonce
        self.imageSize = imageSize
        self.progress = progress
        
        self.image = image
        self.thumbnail = thumbnail
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
