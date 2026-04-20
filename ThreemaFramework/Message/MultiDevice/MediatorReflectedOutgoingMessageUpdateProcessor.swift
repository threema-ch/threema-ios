import CocoaLumberjackSwift
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

class MediatorReflectedOutgoingMessageUpdateProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol

    init(frameworkInjector: FrameworkInjectorProtocol) {
        self.frameworkInjector = frameworkInjector
    }

    func process(outgoingMessageUpdate: D2d_OutgoingMessageUpdate, reflectedAt: Date) -> Promise<Void> {
        Promise { seal in
            frameworkInjector.entityManager.performAndWait {
                do {
                    for item in outgoingMessageUpdate.updates {
                        switch item.update {
                        case .sent:
                            if item.conversation.contact != "" {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverIdentity: item.conversation.contact,
                                    reflectedAt: reflectedAt
                                )
                            }
                            else {
                                try self.saveMessageSent(
                                    messageID: item.messageID,
                                    receiverGroupID: item.conversation.group.groupID,
                                    receiverGroupCreator: item.conversation.group.creatorIdentity,
                                    reflectedAt: reflectedAt
                                )
                            }
                        case .none:
                            break
                        }
                    }
                    seal.fulfill_()
                }
                catch {
                    seal.reject(error)
                }
            }
        }
    }

    // MARK: Private functions

    private func saveMessageSent(messageID: UInt64, receiverIdentity: String, reflectedAt: Date) throws {
        let id = messageID.littleEndianData

        guard let conversation = frameworkInjector.entityManager.entityFetcher
            .conversationEntity(for: receiverIdentity),
            let message = frameworkInjector.entityManager.entityFetcher.message(
                with: id,
                in: conversation,
                isOwn: true
            ) else {
            DDLogError("Own message ID \(messageID.littleEndianData.hexString) to set as sent not found")
            return
        }

        guard let contact = message.conversation.contact, contact.identity == receiverIdentity else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
        }

        frameworkInjector.entityManager.performAndWaitSave {
            message.sent = NSNumber(booleanLiteral: true)
            message.remoteSentDate = reflectedAt
        }
    }

    private func saveMessageSent(
        messageID: UInt64,
        receiverGroupID: UInt64,
        receiverGroupCreator: String,
        reflectedAt: Date
    ) throws {
        let id = messageID.littleEndianData

        let groupIdentity = GroupIdentity(
            id: receiverGroupID.littleEndianData,
            creator: ThreemaIdentity(receiverGroupCreator)
        )
        guard let conversation = frameworkInjector.entityManager.entityFetcher.conversationEntity(
            for: groupIdentity,
            myIdentity: frameworkInjector.myIdentityStore.identity
        ),
            let message = frameworkInjector.entityManager.entityFetcher
            .message(with: id, in: conversation, isOwn: true) else {
            DDLogError("Own message ID \(messageID.littleEndianData.hexString) to set as sent not found")
            return
        }

        guard let group = frameworkInjector.groupManager.getGroup(conversation: message.conversation),
              group.groupID.elementsEqual(receiverGroupID.littleEndianData),
              group.groupCreatorIdentity == receiverGroupCreator else {
            throw MediatorReflectedProcessorError.messageNotProcessed(message: "id: \(id.hexString)")
        }

        frameworkInjector.entityManager.performAndWaitSave {
            message.sent = NSNumber(booleanLiteral: true)
            message.remoteSentDate = reflectedAt
        }
    }
}
