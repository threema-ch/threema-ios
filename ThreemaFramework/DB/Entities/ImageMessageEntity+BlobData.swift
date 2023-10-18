//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation

extension ImageMessageEntity: BlobData {
    public var blobIdentifier: Data? {
        get {
            imageBlobID
        }
        set {
            imageBlobID = newValue
        }
    }
    
    public var blobThumbnailIdentifier: Data? {
        get {
            nil
        }
        set {
            assertionFailure("ImageMessageEntity does not have a thumbnailID.")
            return
        }
    }
    
    public var blobData: Data? {
        get {
            image?.data
        }
        set {
            guard newValue != nil else {
                if let image {
                    managedObjectContext?.delete(image)
                    self.image = nil
                }
                
                return
            }
            
            let imageData: ImageData
            
            // We only create a new data if we do not have one already
            if let image {
                imageData = image
            }
            else if let managedObjectContext,
                    let newData = NSEntityDescription.insertNewObject(
                        forEntityName: "ImageData",
                        into: managedObjectContext
                    ) as? ImageData {
                imageData = newData
            }
            else {
                DDLogError("Unable to load managed object context or create new image data entity")
                return
            }
            
            imageData.data = newValue
            image = imageData
        }
    }
    
    public var blobThumbnail: Data? {
        get {
            thumbnail?.data
        }
        set {
            guard let newValue else {
                if let thumbnail {
                    managedObjectContext?.delete(thumbnail)
                    self.thumbnail = nil
                }
                
                return
            }
            
            let thumbnailData: ImageData
            
            // We only create a new data if we do not have one already
            if let thumbnail {
                thumbnailData = thumbnail
            }
            else if let managedObjectContext,
                    let newData = NSEntityDescription.insertNewObject(
                        forEntityName: "ImageData",
                        into: managedObjectContext
                    ) as? ImageData {
                thumbnailData = newData
            }
            else {
                DDLogError("Unable to load managed object context or create new image data entity for thumbnail")
                return
            }
            
            // Load thumbnail image to get dimensions
            if let temporaryImage = UIImage(data: newValue) {
                thumbnailData.width = NSNumber(floatLiteral: temporaryImage.size.width)
                thumbnailData.height = NSNumber(floatLiteral: temporaryImage.size.height)
            }
            
            thumbnailData.data = newValue
            thumbnail = thumbnailData
        }
    }
    
    public var blobIsOutgoing: Bool {
        isOwnMessage
    }
    
    public var blobEncryptionKey: Data? {
        encryptionKey
    }
    
    public var blobUTTypeIdentifier: String? {
        UTType.image.identifier
    }
    
    public var blobSize: Int {
        Int(truncating: imageSize ?? 0)
    }
    
    public var blobOrigin: BlobOrigin {
        get {
            .public
        }
        set {
            assertionFailure("AudioMessageEntity origin is always .public")
            return
        }
    }
    
    public var blobProgress: NSNumber? {
        get {
            progress
        }
        set {
            progress = newValue
        }
    }
    
    public var blobError: Bool {
        get {
            sendFailed?.boolValue ?? false
        }
        set {
            sendFailed = NSNumber(booleanLiteral: newValue)
        }
    }
    
    public var blobFilename: String? {
        "\(id.hexString).\(MEDIA_EXTENSION_IMAGE)"
    }
    
    public var blobWebFilename: String {
        "threema-\(DateFormatter.getDateForFilename(date))-image.\(MEDIA_EXTENSION_IMAGE)"
    }
    
    public var blobExternalFilename: String? {
        image?.getFilename()
    }
    
    public var blobThumbnailExternalFilename: String? {
        thumbnail?.getFilename()
    }
}
