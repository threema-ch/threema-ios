import CocoaLumberjackSwift
import Foundation

extension AudioMessageEntity: BlobData {
    
    public var isPersistingBlob: Bool {
        isGroupMessage
    }
    
    public var blobIdentifier: Data? {
        get {
            audioBlobID
        }
        set {
            audioBlobID = newValue
        }
    }
    
    public var blobThumbnailIdentifier: Data? {
        get {
            nil
        }
        set {
            assertionFailure("AudioMessageEntity does not have a thumbnailID.")
            return
        }
    }
    
    public var blobData: Data? {
        get {
            audio?.data as? Data
        }
        set {
            guard let newValue else {
                if let audio {
                    managedObjectContext?.delete(audio)
                    self.audio = nil
                }
                
                return
            }
            
            let resolvedAudioDataEntity: AudioDataEntity
            
            // We only create a new data if we do not have one already
            if let audio {
                resolvedAudioDataEntity = audio
            }
            else if let managedObjectContext {
                let entityCreator =
                    EntityCreator(managedObjectContext: managedObjectContext as! ThreemaManagedObjectContext)
                resolvedAudioDataEntity = entityCreator.audioDataEntity(data: newValue)
            }
            else {
                DDLogError("Unable to load managed object context or create new audio data entity")
                return
            }
            
            resolvedAudioDataEntity.data = newValue
            audio = resolvedAudioDataEntity
        }
    }
    
    public var blobThumbnail: Data? {
        get {
            nil
        }
        set {
            assertionFailure("AudioMessageEntity does not have a thumbnail.")
            return
        }
    }
    
    public var blobIsOutgoing: Bool {
        isOwnMessage
    }
    
    public var blobEncryptionKey: Data? {
        encryptionKey
    }
    
    public var blobUTTypeIdentifier: String? {
        UTType.audio.identifier
    }
    
    public var blobSize: Int {
        Int(truncating: audioSize ?? 0)
    }
    
    public var blobOrigin: BlobOrigin {
        get {
            .public
        }
        set {
            assertionFailure("AudioMessageEntity origin is always .public .")
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
        "\(id.hexString).\(MEDIA_EXTENSION_AUDIO)"
    }
    
    public var blobExportFilename: String {
        "\(DateFormatter.getDateForFilename(date))-audio.\(MEDIA_EXTENSION_AUDIO)"
    }
}
