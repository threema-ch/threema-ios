import Foundation

extension ImageMessageEntity: PreviewableMessage {
    
    public var privatePreviewText: String {
        caption ?? fileMessageType.localizedDescription
    }
    
    public var privatePreviewDescription: MessagePreviewDescription {
        if let caption {
            MessagePreviewDescription(typeName: nil, quotedText: caption)
        }
        else {
            MessagePreviewDescription(typeName: fileMessageType.localizedDescription, quotedText: nil)
        }
    }

    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
}
