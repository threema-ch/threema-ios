import CocoaLumberjackSwift
import FileUtility
import Foundation
import Photos

extension ImageMessageEntity: ImageMessage {
    
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
        .image(self)
    }
    
    // MARK: - ThumbnailDisplayMessage
    
    public var dataBlobFileSize: Measurement<UnitInformationStorage> {
        if let imageSize = imageSize?.doubleValue {
            return .init(value: imageSize, unit: .bytes)
        }
        else {
            assertionFailure("No image file size available")
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
        
        // Take the metadata if no thumbnail data is available
        if let height = image?.height,
           let width = image?.width,
           width > 0, height > 0 {
            return Double(height) / Double(width)
        }
        
        // Show as square otherwise
        return 1
    }
    
    public var caption: String? {
        image?.caption()
    }
    
    public func temporaryBlobDataURL() -> URL? {
        guard let imageData = image?.data else {
            return nil
        }
        
        let filename = "v1-imageMessage-\(UUID().uuidString)"
        let fileUtility = FileUtility.shared!
        let url = fileUtility.appTemporaryUnencryptedDirectory.appendingPathComponent(
            "\(filename).\(MEDIA_EXTENSION_IMAGE)"
        )
        
        guard fileUtility.write(contents: imageData, to: url) else {
            DDLogWarn("Writing image blob data to temporary file failed.")
            return nil
        }
        
        return url
    }
    
    public var assetResourceTypeForAutosave: PHAssetResourceType? {
        .photo
    }
    
    public func createSaveMediaItem(forAutosave: Bool) -> AlbumManager.SaveMediaItem? {
        guard let url = temporaryBlobDataURL() else {
            return nil
        }
        
        return AlbumManager.SaveMediaItem(
            url: url,
            type: .photo,
            filename: readableFileName
        )
    }
}
