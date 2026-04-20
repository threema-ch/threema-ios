import CocoaLumberjackSwift
import FileUtility
import Foundation
import Photos

extension VideoMessageEntity: VideoMessage {
    
    override public var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            true
        default:
            false
        }
    }
    
    // MARK: - FileMessageProvider
    
    public var fileMessageType: FileMessageType {
        .video(self)
    }
    
    // MARK: - ThumbnailDisplayMessage
    
    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let videoSize = videoSize?.doubleValue {
            return .init(value: videoSize, unit: .bytes)
        }
        else {
            assertionFailure("No video file size available")
            return .init(value: 0, unit: .bytes)
        }
    }
    
    public var thumbnailImage: UIImage? {
        thumbnail?.uiImage()
    }
    
    public var heightToWidthAspectRatio: Double {
        // Take the thumbnail if it exists as this is what we show
        if let height = thumbnail?.height,
           let width = thumbnail?.width,
           width > 0, height > 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
    
    public var caption: String? {
        // Legacy videos did not support captions
        nil
    }
    
    public var durationTimeInterval: TimeInterval? {
        duration.doubleValue
    }
    
    public func temporaryBlobDataURL() -> URL? {
        guard let videoData = video?.data else {
            return nil
        }
        
        let filename = "v1-videoMessage-\(UUID().uuidString)"
        let fileUtility = FileUtility.shared!
        let url = fileUtility.appTemporaryUnencryptedDirectory.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_VIDEO)"
        )
        
        guard fileUtility.write(contents: videoData, to: url) else {
            DDLogWarn("Writing video blob data to temporary file failed.")
            return nil
        }
        
        return url
    }
    
    public var assetResourceTypeForAutosave: PHAssetResourceType? {
        .video
    }
    
    public func createSaveMediaItem(forAutosave: Bool) -> AlbumManager.SaveMediaItem? {
        guard let url = temporaryBlobDataURL() else {
            return nil
        }
        
        return AlbumManager.SaveMediaItem(
            url: url,
            type: .video,
            filename: readableFileName
        )
    }
}
