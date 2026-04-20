import Foundation

extension SystemMessageEntity: PreviewableMessage {
    public var privatePreviewText: String {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.localizedMessage
        case let .systemMessage(type: systemType):
            systemType.localizedMessage()
        case let .workConsumerInfo(type: workConsumerInfo):
            workConsumerInfo.localizedMessage
        }
    }
    
    public var previewSymbolName: String? {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.symbolName
        default:
            nil
        }
    }
        
    public var previewSymbolTintColor: UIColor? {
        switch systemMessageType {
        case let .callMessage(type: callType):
            callType.tintColor
        default:
            nil
        }
    }
}
