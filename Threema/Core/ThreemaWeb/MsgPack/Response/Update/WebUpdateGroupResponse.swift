import Foundation

final class WebUpdateGroupResponse: WebAbstractMessage {
    
    var id: String
    
    var receiver: [AnyHashable: Any?]?
    
    init(groupRequest: WebUpdateGroupRequest) {
        
        self.id = groupRequest.id.hexEncodedString()

        if groupRequest.ack!.success {
            let webGroup = WebGroup(group: groupRequest.group!)
            self.receiver = webGroup.objectDict()
        }
        
        let tmpArgs: [AnyHashable: Any?] = ["id": id]
        let tmpData: [AnyHashable: Any?] = ["receiver": receiver]
        
        super.init(
            messageType: "update",
            messageSubType: "group",
            requestID: nil,
            ack: groupRequest.ack,
            args: tmpArgs,
            data: tmpData
        )
    }
}
