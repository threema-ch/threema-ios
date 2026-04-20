import CocoaLumberjackSwift
import Foundation

extension FileMessageEntity: BlobData {
    
    public var isPersistingBlob: Bool {
        isGroupMessage
    }
    
    public var blobIdentifier: Data? {
        get {
            blobID
        }
        set {
            blobID = newValue
        }
    }
    
    public var blobThumbnailIdentifier: Data? {
        get {
            blobThumbnailID
        }
        set {
            blobThumbnailID = newValue
        }
    }
    
    public var blobData: Data? {
        get {
            data?.data
        }
        set {
            guard let newValue else {
                if let data {
                    managedObjectContext?.delete(data)
                    self.data = nil
                }
                
                return
            }
            
            let fileDataEntity: FileDataEntity
            
            // We only create a new data if we do not have one already
            if let data {
                fileDataEntity = data
            }
            else if let managedObjectContext {
                let entityCreator =
                    EntityCreator(managedObjectContext: managedObjectContext as! ThreemaManagedObjectContext)
                fileDataEntity = entityCreator.fileDataEntity(data: newValue)
            }
            else {
                DDLogError("Unable to load managed object context or create new file data entity")
                return
            }
            
            fileDataEntity.data = newValue
            data = fileDataEntity
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
        UTIConverter.uti(fromMimeType: mimeType ?? "")
    }
    
    public var blobSize: Int {
        Int(truncating: fileSize ?? 0)
    }
    
    public var blobOrigin: BlobOrigin {
        get {
            guard let value = origin as? Int else {
                return .public
            }
            return BlobOrigin(rawValue: value) ?? .public
        }
        set {
            origin = NSNumber(integerLiteral: newValue.rawValue)
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
        "\(id.hexString)-\(fileName ?? "unknown-file-name")"
    }
    
    public var blobExportFilename: String {
        "\(DateFormatter.getDateForFilename(date))-file-\(fileName ?? "unknown-file-name")"
    }
}
