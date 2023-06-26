//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import CoreLocation
import Foundation
import PromiseKit
import ThreemaFramework

class MessageSenderMock: NSObject, MessageSenderProtocol {
    let doSendReadReceiptContacts: [ContactEntity]

    override convenience init() {
        self.init(doSendReadReceiptContacts: [ContactEntity]())
    }

    init(doSendReadReceiptContacts: [ContactEntity]) {
        self.doSendReadReceiptContacts = doSendReadReceiptContacts
    }

    var sendDeliveryReceiptCalls = [AbstractMessage]()

    func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessage?) -> Void)?
    ) {
        // no-op
    }

    func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: Conversation
    ) {
        // no-op
    }

    func sendBallotMessage(for ballot: Ballot) {
        // no-op
    }

    func sendBallotVoteMessage(for ballot: Ballot) {
        // no-op
    }

    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool, completion: (() -> Void)?) {
        // no-op
    }

    func sendMessage(baseMessage: BaseMessage) {
        // no-op
    }

    func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> PromiseKit.Promise<Void> {
        sendDeliveryReceiptCalls.append(abstractMessage)
        return Promise()
    }

    func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaFramework.ThreemaIdentity) async {
        // no-op
    }

    func sendReadReceipt(for messages: [BaseMessage], toGroupIdentity: ThreemaFramework.GroupIdentity) async {
        // no-op
    }

    func sendUserAck(for message: BaseMessage, toIdentity: ThreemaFramework.ThreemaIdentity) async {
        // no-op
    }

    func sendUserAck(for message: BaseMessage, toGroup: ThreemaFramework.Group) async {
        // no-op
    }

    func sendUserDecline(for message: BaseMessage, toIdentity: ThreemaFramework.ThreemaIdentity) async {
        // no-op
    }

    func sendUserDecline(for message: BaseMessage, toGroup: ThreemaFramework.Group) async {
        // no-op
    }

    func sendTypingIndicator(typing: Bool, toIdentity: ThreemaFramework.ThreemaIdentity) {
        // no-op
    }

    func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool {
        guard let contactEntity else {
            return false
        }
        return doSendReadReceiptContacts.first(where: { $0 == contactEntity })?.readReceipt ?? .doNotSend == .send
    }

    func doSendReadReceipt(to conversation: Conversation) -> Bool {
        true
    }

    func doSendTypingIndicator(to contact: ContactEntity?) -> Bool {
        true
    }

    func doSendTypingIndicator(to conversation: Conversation) -> Bool {
        true
    }

    func sanitizeAndSendText(_ rawText: String, in conversation: Conversation) {
        // no-op
    }
}
