import Foundation

extension FileMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        switch fileMessageType {
        case let .voice(voice):
            let formattedDuration = DateFormatter.timeFormatted(Int(voice.durationTimeInterval ?? 0.0))
            return "\(fileMessageType.localizedDescription) (\(formattedDuration))"

        case let .video(message):
            return text(message: message)
            
        case let .image(message):
            return text(message: message)
            
        case let .animatedImage(message):
            return text(message: message)
            
        case let .sticker(message):
            return text(message: message)
            
        case let .animatedSticker(message):
            return text(message: message)
            
        case let .file(message):
            return message.caption ?? message.name
        }
    }
    
    private func text(message: CommonFileMessageMetadata) -> String {
        message.caption ?? fileMessageType.localizedDescription
    }
    
    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
    
    public var mediaPreview: (thumbnail: UIImage, isPlayable: Bool)? {
        
        guard let thumbnailImage else {
            return nil
        }
        
        switch fileMessageType {
        case .image, .sticker:
            return (thumbnailImage, false)
            
        case .video, .animatedImage, .animatedSticker:
            return (thumbnailImage, true)
            
        case .file, .voice:
            return nil
        }
    }
}
