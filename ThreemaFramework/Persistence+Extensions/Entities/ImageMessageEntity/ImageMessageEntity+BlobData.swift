import CocoaLumberjackSwift
import Foundation

extension ImageMessageEntity: BlobData {
    
    public var isPersistingBlob: Bool {
        isGroupMessage
    }
    
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
            guard let newValue else {
                if let image {
                    managedObjectContext?.delete(image)
                    self.image = nil
                }
                
                return
            }
            
            let imageDataEntity: ImageDataEntity
            
            // We only create a new data if we do not have one already
            if let image {
                imageDataEntity = image
            }
            else {
                DDLogError("Unable to load managed object context or create new image data entity")
                return
            }
            
            imageDataEntity.data = newValue
            image = imageDataEntity
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
            
            let thumbnailDataEntity: ImageDataEntity
            
            // We only create a new data if we do not have one already
            if let thumbnail {
                thumbnailDataEntity = thumbnail
            }
            else if let managedObjectContext, let image = UIImage(data: newValue) {
                let entityCreator =
                    EntityCreator(managedObjectContext: managedObjectContext as! ThreemaManagedObjectContext)
                thumbnailDataEntity = entityCreator.imageDataEntity(data: newValue, size: image.size)
            }
            else {
                DDLogError("Unable to load managed object context or create new image data entity for thumbnail")
                return
            }
            
            // Load thumbnail image to get dimensions
            if let temporaryImage = UIImage(data: newValue) {
                thumbnailDataEntity.width = Int16(temporaryImage.size.width)
                thumbnailDataEntity.height = Int16(temporaryImage.size.height)
            }
            
            thumbnailDataEntity.data = newValue
            thumbnail = thumbnailDataEntity
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
    
    public var blobExportFilename: String {
        "\(DateFormatter.getDateForFilename(date))-image.\(MEDIA_EXTENSION_IMAGE)"
    }
}
