//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

public protocol MessageSenderProtocol {

    func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String?,
        completion: ((BaseMessage?) -> Void)?
    )

    func sendLocationMessage(
        coordinates: CLLocationCoordinate2D,
        accuracy: CLLocationAccuracy,
        poiName: String?,
        poiAddress: String?,
        in conversation: Conversation
    )

    func sendBallotMessage(for ballot: Ballot)

    func sendBallotVoteMessage(for ballot: Ballot)

    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool, completion: (() -> Void)?)

    func sendMessage(baseMessage: BaseMessage)

    func sendDeliveryReceipt(for abstractMessage: AbstractMessage) -> Promise<Void>

    func sendReadReceipt(for messages: [BaseMessage], toIdentity: ThreemaIdentity) async

    func sendReadReceipt(for messages: [BaseMessage], toGroupIdentity: GroupIdentity) async

    func sendUserAck(for message: BaseMessage, toIdentity: ThreemaIdentity) async

    func sendUserAck(for message: BaseMessage, toGroup: Group) async

    func sendUserDecline(for message: BaseMessage, toIdentity: ThreemaIdentity) async

    func sendUserDecline(for message: BaseMessage, toGroup: Group) async

    func sendTypingIndicator(typing: Bool, toIdentity: ThreemaIdentity)

    func doSendReadReceipt(to contactEntity: ContactEntity?) -> Bool

    func doSendReadReceipt(to conversation: Conversation) -> Bool

    func doSendTypingIndicator(to contact: ContactEntity?) -> Bool

    func doSendTypingIndicator(to conversation: Conversation) -> Bool

    func sanitizeAndSendText(_ rawText: String, in conversation: Conversation)
}

extension MessageSenderProtocol {
    public func sendTextMessage(
        text: String?,
        in conversation: Conversation,
        quickReply: Bool,
        requestID: String? = nil
    ) {
        sendTextMessage(text: text, in: conversation, quickReply: quickReply, requestID: requestID, completion: nil)
    }

    func sendMessage(abstractMessage: AbstractMessage, isPersistent: Bool) {
        sendMessage(abstractMessage: abstractMessage, isPersistent: isPersistent, completion: nil)
    }

    func sendReadReceipt(
        for messages: [BaseMessage],
        toGroupIdentity: GroupIdentity,
        completion: @escaping () -> Void
    ) {
        Task {
            await self.sendReadReceipt(for: messages, toGroupIdentity: toGroupIdentity)
            completion()
        }
    }
}
