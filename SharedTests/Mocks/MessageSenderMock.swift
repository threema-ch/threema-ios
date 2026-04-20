import CoreLocation
import Foundation
import PromiseKit
import ThreemaEssentials
import ThreemaFramework

final class MessageSenderMock: NSObject, MessageSenderProtocol {
    let doSendReadReceiptContacts: [ContactEntity]

    override convenience init() {
        self.init(doSendReadReceiptContacts: [ContactEntity]())
    }

    init(doSendReadReceiptContacts: [ContactEntity]) {
        self.doSendReadReceiptContacts = doSendReadReceiptContacts
    }

    var sentAbstractMessagesQueue = [AbstractMessage]()
    
    var sendDeliveryReceiptCalls = [AbstractMessage]()

    func sendTextMessage(
        text: String?,
        in conversation: ConversationEntity,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessageEntity?) -> Void)?
    ) {
        // no-op
    }

    func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: ConversationEntity
    ) {
        // no-op
    }

    func sendBallotMessage(for ballot: BallotEntity) {
        // no-op
    }

    func sendBallotVoteMessage(for ballot: BallotEntity) {
        // no-op
    }

    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool, completion: (() -> Void)?) {
        sentAbstractMessagesQueue.append(abstractMessage)
    }

    func sendBaseMessage(with objectID: NSManagedObjectID, to receivers: MessageSenderReceivers) {
        // no-op
    }

    func sendDeleteMessage(with objectID: NSManagedObjectID, receiversExcluded: [ThreemaFramework.Contact]?) throws {
        // no-op
    }

    func sendEditMessage(
        with objectID: NSManagedObjectID,
        rawText: String,
        receiversExcluded: [ThreemaFramework.Contact]?
    ) throws {
        // no-op
    }

    func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> PromiseKit.Promise<Void> {
        sendDeliveryReceiptCalls.append(abstractMessage)
        return Promise()
    }
    
    func sendReaction(
        to objectID: NSManagedObjectID,
        reaction: ThreemaFramework.EmojiVariant
    ) async throws -> ThreemaFramework.ReactionsManager
        .ReactionSendingResult {
        .success
    }
    
    func sendReadReceipt(for messages: [BaseMessageEntity], toIdentity: ThreemaEssentials.ThreemaIdentity) async {
        // no-op
    }

    func sendReadReceipt(for messages: [BaseMessageEntity], toGroupIdentity: ThreemaEssentials.GroupIdentity) async {
        // no-op
    }

    func sendTypingIndicator(typing: Bool, toIdentity: ThreemaEssentials.ThreemaIdentity) {
        // no-op
    }

    func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool {
        guard let contactEntity else {
            return false
        }
        return doSendReadReceiptContacts.first(where: { $0 == contactEntity })?.readReceipt ?? .doNotSend == .send
    }

    func doSendReadReceipt(to conversation: ConversationEntity) -> Bool {
        true
    }

    func doSendTypingIndicator(to contact: ContactEntity?) -> Bool {
        true
    }

    func doSendTypingIndicator(to conversation: ConversationEntity) -> Bool {
        true
    }
}
