import Foundation

extension AudioMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        let formattedDuration = DateFormatter.timeFormatted(Int(durationTimeInterval ?? 0.0))
        return "\(fileMessageType.localizedDescription) (\(formattedDuration))"
    }
    
    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
}
