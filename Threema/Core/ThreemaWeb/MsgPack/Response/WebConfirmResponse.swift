import Foundation

final class WebConfirmResponse: WebAbstractMessage {
    
    init(message: WebAbstractMessage, success: Bool, error: String?) {
        let ack = WebAbstractMessageAcknowledgement(message.requestID, success, error)
        super.init(messageType: "update", messageSubType: "confirm", requestID: nil, ack: ack, args: nil, data: nil)
    }
    
    init(webReadRequest: WebReadRequest) {
        super.init(
            messageType: "update",
            messageSubType: "confirm",
            requestID: nil,
            ack: webReadRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webCleanReceiverConversationRequest: WebCleanReceiverConversationRequest) {
        let tmpAck = WebAbstractMessageAcknowledgement(webCleanReceiverConversationRequest.requestID, true, nil)
        super.init(messageType: "update", messageSubType: "confirm", requestID: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    init(webUpdateProfileRequest: WebUpdateProfileRequest) {
        super.init(
            messageType: "update",
            messageSubType: "confirm",
            requestID: nil,
            ack: webUpdateProfileRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webGroupSyncRequest: WebGroupSyncRequest) {
        super.init(
            messageType: "update",
            messageSubType: "confirm",
            requestID: nil,
            ack: webGroupSyncRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webDeleteMessageRequest: WebDeleteMessageRequest) {
        super.init(
            messageType: "update",
            messageSubType: "confirm",
            requestID: nil,
            ack: webDeleteMessageRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webDeleteGroupRequest: WebDeleteGroupRequest) {
        super.init(
            messageType: "update",
            messageSubType: "confirm",
            requestID: nil,
            ack: webDeleteGroupRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webUpdateConversationRequest: WebUpdateConversationRequest) {
        super.init(
            messageType: "response",
            messageSubType: "confirmAction",
            requestID: nil,
            ack: webUpdateConversationRequest.ack,
            args: nil,
            data: nil
        )
    }
    
    init(webUpdateActiveConversationRequest: WebUpdateActiveConversationRequest) {
        super.init(
            messageType: "response",
            messageSubType: "confirm",
            requestID: nil,
            ack: webUpdateActiveConversationRequest.ack,
            args: nil,
            data: nil
        )
    }
}
