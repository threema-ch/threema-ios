import Foundation

import ThreemaEssentials

extension ConversationEntity {
    /// Set `lastMessage` property to correct last message
    /// - Parameter entityManager: Entity manager to be used for the update
    public func updateLastDisplayMessage(with entityManager: EntityManager) {
        entityManager.performAndWaitSave {
            let messageFetcher = MessageFetcher(for: self, with: entityManager)
            guard let message = messageFetcher.lastDisplayMessage() else {
                self.lastMessage = nil
                return
            }
            
            guard self.lastMessage != message else {
                return
            }
            
            self.lastMessage = message
        }
    }
    
    @objc public class var keyPathsForValuesAffectingDisplayName: Set<String> {
        [
            #keyPath(groupName),
            #keyPath(contact.displayName),
            #keyPath(members),
        ]
    }
    
    @objc public var displayName: String {
        if isGroup {
            if let groupName, !groupName.isEmpty {
                groupName
            }
            else {
                ListFormatter.localizedString(
                    byJoining: participants.prefix(10).map(\.displayName).sorted()
                )
            }
        }
        else if let distributionList {
            distributionList.name ?? ""
        }
        else if let contact {
            contact.displayName
        }
        else {
            ""
        }
    }
}
