import Foundation

extension ImageMessageEntity: PreviewableMessage {
    
    public var privatePreviewText: String {
        caption ?? fileMessageType.localizedDescription
    }
    
    public var previewSymbolName: String? {
        fileMessageType.symbolName
    }
}
