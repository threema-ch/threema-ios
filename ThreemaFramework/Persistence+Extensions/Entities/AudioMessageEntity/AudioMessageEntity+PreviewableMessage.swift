import Foundation

extension AudioMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        let formattedDuration = DateFormatter.timeFormatted(Int(durationTimeInterval ?? 0.0))
        return "\(fileMessageType.localizedDescription) (\(formattedDuration))"
    }
    
    public var privatePreviewDescription: MessagePreviewDescription {
        MessagePreviewDescription(typeName: privatePreviewText, quotedText: nil)
    }

    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
}
