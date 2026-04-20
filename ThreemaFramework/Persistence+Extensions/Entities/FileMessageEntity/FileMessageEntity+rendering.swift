import Foundation

extension FileMessageEntity {
    
    /// Possible render types of a file message entity
    public enum RenderType {
        /// An image represented though its thumbnail
        case imageMessage
        /// Like an image but no background
        case stickerMessage
        /// Like an image but animated
        case animatedImageMessage
        /// Like an image but animated and no background
        case animatedStickerMessage
        /// A video represented by a playable thumbnail
        case videoMessage
        /// An voice message that can be played inline
        case voiceMessage
        /// A file that can be opened
        case fileMessage
    }
    
    /// How should this message be rendered?
    /// When changing this you should also change `func fileMessagesForPhotoBrowser(_)` in `EntityFetcher`
    public var renderType: RenderType {
        let mimeType = mimeType ?? ""
        
        if UTIConverter.isImageMimeType(mimeType), UTIConverter.isRenderingImageMimeType(mimeType) {
            if type?.intValue == 1 {
                return .imageMessage
            }
            else if type?.intValue == 2 {
                return .stickerMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isGifMimeType(mimeType) {
            if type?.intValue == 1 {
                return .animatedImageMessage
            }
            else if type?.intValue == 2 {
                return .animatedStickerMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isRenderingVideoMimeType(mimeType) {
            if type?.intValue == 1 || type?.intValue == 2 {
                return .videoMessage
            }
            
            return .fileMessage
        }
        else if UTIConverter.isRenderingAudioMimeType(mimeType) {
            if type?.intValue == 1 || type?.intValue == 2 {
                return .voiceMessage
            }
            
            return .fileMessage
        }
        
        return .fileMessage
    }
    
    override public var showRetryAndCancelButton: Bool {
        switch blobDisplayState {
        case .pending, .sendingError, .uploading:
            true
        default:
            false
        }
    }
}
