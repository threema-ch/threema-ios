import CocoaLumberjackSwift
import FileUtility
import Foundation

open class MediaPreviewURLDataProcessor {
    
    public var addMore: (([Any], [MediaPreviewItem]) -> Void)?
    public var cancelAction: (() -> Void)?
    public var memoryConstrained = false
    public var sendAsFile = false
    
    public init() { }
    
    open func loadItems(dataArray: [Any]) -> (items: [MediaPreviewItem], errors: [PhotosPickerError]) {
        var mediaData = [MediaPreviewItem]()
        var errorList = [PhotosPickerError]()
        for index in 0..<dataArray.count {
            do {
                guard let item = try loadItem(item: dataArray[index]) else {
                    continue
                }
                mediaData.append(item)
            }
            catch {
                if let error = error as? PhotosPickerError {
                    errorList.append(error)
                }
                else {
                    fatalError("Unhandled error: \(error)")
                }
            }
        }
        
        return (mediaData, errorList)
    }
    
    open func loadItem(item: Any) throws -> MediaPreviewItem? {
        switch item {
        case is MediaPreviewItem:
            return item as? MediaPreviewItem
        case is URL, is NSURL:
            let url = item as! URL
            let fileSize = Double(FileUtility.shared.fileSizeInBytes(fileURL: url) ?? Int64(kMaxFileSize))
            let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
            let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
            let isVideo = UTIConverter.isVideoMimeType(mimeType) || UTIConverter.isMovieMimeType(mimeType)
            let estimatedVideoFileSize = VideoConversionHelper().getEstimatedVideoFileSize(for: url)
            
            let isValidVideoDuration: Bool =
                if isVideo {
                    MediaConverter.isVideoDurationValid(at: url)
                }
                else {
                    false
                }
            
            guard Double(kMaxFileSize) > fileSize || (isVideo && isValidVideoDuration) else {
                throw PhotosPickerError.fileTooLargeForSending
            }
            
            guard !memoryConstrained ||
                kShareExtensionMaxFileShareSize > fileSize ||
                (
                    isVideo && kShareExtensionMaxFileShareSize >
                        (estimatedVideoFileSize ?? Double.greatestFiniteMagnitude)
                ) else {
                throw PhotosPickerError.fileTooLargeForShareExtension
            }

            let isPhoto = UTIConverter.isImageMimeType(mimeType)
            guard !memoryConstrained || !isPhoto || kShareExtensionMaxImageShareSize > fileSize else {
                throw PhotosPickerError.fileTooLargeForShareExtension
            }
            
            guard let item = addDataItemFrom(url: url) else {
                throw PhotosPickerError.unknown
            }
            item.memoryConstrained = memoryConstrained
            return item
        case is PhotosPickerError:
            return nil
        default:
            return nil
        }
    }
    
    open func addDataItemFrom(url: URL) -> MediaPreviewItem? {
        let uti = UTIConverter.uti(forFileURL: url) ?? UTType.data.identifier
        let mimeType = UTIConverter.mimeType(fromUTI: uti) ?? "application/octet-stream"
        if UTIConverter.isImageMimeType(mimeType) {
            let item = ImagePreviewItem(itemURL: url)
            return item
        }
        else if UTIConverter.isMovieMimeType(mimeType) || UTIConverter.isVideoMimeType(mimeType) {
            let item = VideoPreviewItem(itemURL: url)
            return item
        }
        else {
            let item = DocumentPreviewItem(itemURL: url)
            return item
        }
    }
    
    open func processItemForSending(item: MediaPreviewItem) -> Any? {
        if item is ImagePreviewItem {
            guard let assetURL = item.itemURL else {
                return nil
            }
            return assetURL
        }
        
        if item is VideoPreviewItem {
            guard let videoItem = item as? VideoPreviewItem else {
                return nil
            }
            return sendAsFile ? videoItem.getOriginalItem() : videoItem.getTranscodedItem()
        }
        
        if item is DocumentPreviewItem {
            guard let documentItem = item as? DocumentPreviewItem else {
                return nil
            }
            guard let assetURL: URL = documentItem.itemURL else {
                return nil
            }
            return assetURL
        }
        
        let err = "Unknown Media Type processed"
        DDLogError("\(err)")
        fatalError(err)
    }
    
    open func returnAction(mediaData: [MediaPreviewItem]) {
        let err = "Not implemented"
        DDLogError("\(err)")
        fatalError(err)
    }
    
    open func executeCancelAction() {
        cancelAction?()
    }
}
