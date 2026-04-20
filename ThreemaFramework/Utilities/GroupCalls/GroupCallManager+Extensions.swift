import CocoaLumberjackSwift
import Foundation
import GroupCalls
import ThreemaEssentials

extension GroupCallManager {
    public func getGroupModel(for groupConversationManagedObjectID: NSManagedObjectID) async
        -> GroupCallThreemaGroupModel? {
        guard UserSettings.shared().enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            let businessInjector = BusinessInjector()
            
            businessInjector.entityManager.performAndWait {
                guard let conversation = businessInjector.entityManager.entityFetcher
                    .managedObject(with: groupConversationManagedObjectID) as? ConversationEntity else {
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let group = businessInjector.groupManager.getGroup(conversation: conversation) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let groupIdentity = group.groupIdentity
                
                let groupModel = GroupCallThreemaGroupModel(
                    groupIdentity: groupIdentity,
                    groupName: group.name ?? ""
                )
                
                continuation.resume(returning: groupModel)
            }
        }
    }
}
