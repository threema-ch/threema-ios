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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.businessInjector.entityManager.performAsyncBlockAndSafe {
                guard let conversation = self.businessInjector.entityManager.entityFetcher
                    .conversationEntity(
                        for: groupModel.groupIdentity,
                        myIdentity: self.businessInjector.myIdentityStore.identity
                    ) else {
                    continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                    return
                }
                
                switch systemMessage {
                case let .groupCallStartedBy(threemaID, date):
                    guard let contact = self.businessInjector.entityManager.entityFetcher
                        .contactEntity(for: threemaID.rawValue) else {
                        continuation.resume(throwing: GroupCallSystemMessageAdapterError.MissingDataInDB)
                        return
                    }
                    
                    let dbSystemMessage = self.businessInjector.entityManager.entityCreator.systemMessageEntity(
                        for: .groupCallStartedBy,
                        in: conversation,
                        setLastUpdate: true
                    )
                    
                    dbSystemMessage.date = date
                    dbSystemMessage.arg = Data(contact.displayName.utf8)
                    
                case .groupCallEnded:
                    _ = self.businessInjector.entityManager.entityCreator.systemMessageEntity(
                        for: .groupCallEnded,
                        in: conversation
                    )
                    
                case .groupCallStarted:
                    _ = self.businessInjector.entityManager.entityCreator.systemMessageEntity(
                        for: .groupCallStarted,
                        in: conversation,
                        setLastUpdate: true
                    )
                }
                
                continuation.resume()
            }
        }
    }
}
