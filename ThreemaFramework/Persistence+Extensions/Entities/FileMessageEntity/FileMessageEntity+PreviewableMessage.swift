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
    
    public var privatePreviewDescription: MessagePreviewDescription {
        switch fileMessageType {
        case .voice:
            MessagePreviewDescription(typeName: privatePreviewText, quotedText: nil)

        case let .video(message):
            description(message: message)

        case let .image(message):
            description(message: message)

        case let .animatedImage(message):
            description(message: message)

        case let .sticker(message):
            description(message: message)

        case let .animatedSticker(message):
            description(message: message)

        case let .file(message):
            // A file is always named, either by its caption or by its file name
            MessagePreviewDescription(
                typeName: fileMessageType.localizedDescription,
                quotedText: message.caption ?? message.name
            )
        }
    }

    private func text(message: CommonFileMessageMetadata) -> String {
        message.caption ?? fileMessageType.localizedDescription
    }

    private func description(message: CommonFileMessageMetadata) -> MessagePreviewDescription {
        if let caption = message.caption {
            MessagePreviewDescription(typeName: nil, quotedText: caption)
        }
        else {
            MessagePreviewDescription(typeName: fileMessageType.localizedDescription, quotedText: nil)
        }
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
