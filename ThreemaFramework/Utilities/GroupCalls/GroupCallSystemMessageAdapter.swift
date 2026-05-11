import Foundation
import GroupCalls
import ThreemaProtocols

/// Allows the Group Calls module to post system messages
final class GroupCallSystemMessageAdapter<BusinessInjectorImpl: BusinessInjectorProtocol>: Sendable {
    // MARK: - Private Properties
    
    // `BusinessInjectorProtocol` is not explicitly sendable. We accept this limitation.
    private let businessInjector: BusinessInjectorImpl
    
    // MARK: - Lifecycle
    
    init(businessInjector: BusinessInjectorImpl) {
        self.businessInjector = businessInjector
    }
}

// MARK: - GroupCallSystemMessageAdapterProtocol

extension GroupCallSystemMessageAdapter: GroupCallSystemMessageAdapterProtocol {
    func post(_ systemMessage: GroupCallSystemMessage, in groupModel: GroupCallThreemaGroupModel) async throws {
        let entityManager = businessInjector.entityManager
        let entityFetcher = entityManager.entityFetcher
        let identity = businessInjector.myIdentityStore.identity
        try await entityManager.performSave {
            guard let conversation = entityFetcher.conversationEntity(
                for: groupModel.groupIdentity,
                myIdentity: identity
            ) else {
                throw GroupCallSystemMessageAdapterError.MissingDataInDB
            }
            
            switch systemMessage {
            case let .groupCallStartedBy(threemaID, date):
                guard let contact = entityFetcher.contactEntity(for: threemaID.rawValue) else {
                    throw GroupCallSystemMessageAdapterError.MissingDataInDB
                }
                
                let dbSystemMessage = entityManager.entityCreator.systemMessageEntity(
                    for: .groupCallStartedBy,
                    in: conversation,
                    setLastUpdate: true
                )
                
                dbSystemMessage.date = date
                dbSystemMessage.arg = Data(contact.displayName.utf8)
                
            case .groupCallEnded:
                _ = entityManager.entityCreator.systemMessageEntity(
                    for: .groupCallEnded,
                    in: conversation
                )
                
            case .groupCallStarted:
                _ = entityManager.entityCreator.systemMessageEntity(
                    for: .groupCallStarted,
                    in: conversation,
                    setLastUpdate: true
                )
            }
        }
    }
}
