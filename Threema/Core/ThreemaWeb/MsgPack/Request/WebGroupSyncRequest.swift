import CocoaLumberjackSwift
import Foundation

final class WebGroupSyncRequest: WebAbstractMessage {
    
    let id: Data
    
    override init(message: WebAbstractMessage) {
        let idString = message.args!["id"] as! String
        self.id = idString.hexadecimal!
        super.init(message: message)
    }
    
    func syncGroup() {
        ack = WebAbstractMessageAcknowledgement(requestID, false, nil)
        let businessInjector = BusinessInjector.ui

        let id = id
        let group: Group? = businessInjector.entityManager.performAndWait {
            guard let conversation = businessInjector.entityManager.entityFetcher
                .legacyConversationEntity(for: id) else {
                return nil
            }
            return businessInjector.groupManager.getGroup(conversation: conversation)
        }

        guard let group else {
            ack!.success = false
            ack!.error = "invalidGroup"
            return
        }

        if !group.isOwnGroup {
            ack!.success = false
            ack!.error = "notAllowed"
            return
        }

        Task {
            do {
                try await businessInjector.groupManager.sync(group: group)
            }
            catch {
                DDLogError("Unable to sync group: \(error)")
            }
            ack!.success = true
        }
    }
}
