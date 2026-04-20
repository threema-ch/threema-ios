import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaProtocols

class MediatorReflectedIncomingMessageUpdateProcessor {

    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate

    init(frameworkInjector: FrameworkInjectorProtocol, messageProcessorDelegate: MessageProcessorDelegate) {
        self.frameworkInjector = frameworkInjector
        self.messageProcessorDelegate = messageProcessorDelegate
    }

    func process(incomingMessageUpdate: D2d_IncomingMessageUpdate) -> Promise<Void> {
        Promise { seal in
            do {
                for item in incomingMessageUpdate.updates {
                    switch item.update {
                    case .read:
                        var senderIdentity: ThreemaIdentity?
                        var senderGroupIdentity: GroupIdentity?
                        if !item.conversation.contact.isEmpty {
                            senderIdentity = ThreemaIdentity(item.conversation.contact)
                        }
                        else if item.conversation.group.groupID > 0 {
                            senderGroupIdentity = GroupIdentity(
                                id: item.conversation.group.groupID.littleEndianData,
                                creator: ThreemaIdentity(item.conversation.group.creatorIdentity)
                            )
                        }

                        try self.saveMessageRead(
                            messageID: item.messageID,
                            senderIdentity: senderIdentity,
                            senderGroupIdentity: senderGroupIdentity,
                            readDate: Date(millisecondsSince1970: item.read.at)
                        )
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

    // MARK: Private functions

    private func saveMessageRead(
        messageID: UInt64,
        senderIdentity: ThreemaIdentity?,
        senderGroupIdentity: GroupIdentity?,
        readDate: Date
    ) throws {
        var readMessageConversations = Set<ConversationEntity>()

        try frameworkInjector.entityManager.performAndWait {
            let conversation: ConversationEntity
            if let senderIdentity,
               let contactConversation = self.frameworkInjector.entityManager.conversation(
                   for: senderIdentity.rawValue,
                   createIfNotExisting: false
               ) {
                conversation = contactConversation
            }
            else if let senderGroupIdentity,
                    let groupConversation = self.frameworkInjector.entityManager.entityFetcher
                    .conversationEntity(
                        for: GroupIdentity(
                            id: senderGroupIdentity.id,
                            creator: ThreemaIdentity(senderGroupIdentity.creator.rawValue)
                        ),
                        myIdentity: self.frameworkInjector.myIdentityStore.identity
                    ) {
                conversation = groupConversation
            }
            else {
                throw MediatorReflectedProcessorError
                    .messageNotProcessed(
                        message: "Incoming message (ID: \(messageID.littleEndianData.hexString)) update failed, could get neither conversation for contact nor group"
                    )
            }
            
            let id = messageID.littleEndianData
            if let message = self.frameworkInjector.entityManager.entityFetcher.message(
                with: id,
                in: conversation
            ) {
                
                // If it is not a message from myself then update as read and refresh unread badge
                if !message.isOwnMessage {
                    DDLogNotice("Message ID \(message.id.hexString) has been read by other device")
                    self.frameworkInjector.entityManager.performAndWaitSave {
                        message.read = true
                        message.readDate = readDate
                    }
                    readMessageConversations.insert(message.conversation)
                }

                // If it is a read receipt of a reflected incoming message, then remove all notifications of this
                // message
                let identity: String? = message.sender?.identity ?? message.conversation.contact?.identity
                if let contentKey = PendingUserNotificationKey.key(identity: identity, messageID: message.id) {
                    DDLogNotice("Removing notifications from \(#function)")
                    self.frameworkInjector.userNotificationCenterManager.remove(
                        contentKey: contentKey,
                        exceptStage: nil,
                        justPending: false
                    )
                }
            }
        }

        if !readMessageConversations.isEmpty {
            messageProcessorDelegate.readMessage(inConversations: readMessageConversations)
        }
    }
}
