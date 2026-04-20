import CocoaLumberjackSwift
import Foundation
import ThreemaEssentials
import ThreemaFramework

final class WebCreateGroupResponse: WebAbstractMessage {
    
    var groupRequest: WebCreateGroupRequest
    
    init(request: WebCreateGroupRequest) {
        self.groupRequest = request
        let tmpAck = WebAbstractMessageAcknowledgement(request.requestID, true, nil)
        
        super.init(messageType: "create", messageSubType: "group", requestID: nil, ack: tmpAck, args: nil, data: nil)
    }
    
    func addGroup(completion: @escaping () -> Void) {
        let mdmSetup = MDMSetup()!
        if mdmSetup.disableCreateGroup() {
            createErrorResponse(errorDescription: "disabledByPolicy", completion: completion)
            return
        }

        Task {
            do {
                let businessInjector = BusinessInjector.ui
                try await businessInjector.runInBackground { backgroundBusinessInjector in
                    let (group, _) = try await backgroundBusinessInjector.groupManager.createOrUpdate(
                        for: GroupIdentity(
                            id: NaClCrypto.shared().randomBytes(Int32(ThreemaProtocol.groupIDLength)),
                            creator: ThreemaIdentity(MyIdentityStore.shared().identity)
                        ),
                        members: Set(self.groupRequest.members),
                        systemMessageDate: Date()
                    )

                    if let name = self.groupRequest.name {
                        try await backgroundBusinessInjector.groupManager.setName(
                            group: group,
                            name: name
                        )
                    }

                    if let photo = self.groupRequest.avatar {
                        try await backgroundBusinessInjector.groupManager.setPhoto(
                            group: group,
                            imageData: photo,
                            sentDate: Date()
                        )
                    }
                }
            }
            catch {
                DDLogError("Could not create group: \(error)")
                self.createErrorResponse(errorDescription: "internalError", completion: completion)
            }
        }
    }

    func createSuccessResponse(group: Group, completion: @escaping () -> Void) {
        ack!.success = true
        args = nil
        let webGroup = WebGroup(group: group)
        data = ["receiver": webGroup.objectDict()]
        completion()
    }
    
    func createErrorResponse(errorDescription: String, completion: @escaping () -> Void) {
        DDLogError("\(errorDescription)")
        
        ack!.success = false
        ack!.error = errorDescription
        args = nil
        data = nil
        
        completion()
    }
}
