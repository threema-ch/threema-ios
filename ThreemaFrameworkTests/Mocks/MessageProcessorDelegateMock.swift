//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2022-2024 Threema GmbH
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

import Foundation
@testable import ThreemaFramework

class MessageProcessorDelegateMock: NSObject, MessageProcessorDelegate {
    func beforeDecode() {
        // no-op
    }

    func changedManagedObjectID(_ objectID: NSManagedObjectID) {
        // no-op
    }

    func incomingMessageStarted(_ message: AbstractMessage) {
        // no-op
    }

    func incomingMessageChanged(_ message: BaseMessage, fromIdentity: String) {
        // no-op
    }

    func incomingMessageFinished(_ message: AbstractMessage) {
        // no-op
    }

    func incomingMessageFailed(_ message: BoxedMessage) {
        // no-op
    }
    
    func incomingAbstractMessageFailed(_ message: AbstractMessage) {
        // no-op
    }

    func readMessage(inConversations: Set<Conversation>?) {
        // no-op
    }

    func taskQueueEmpty(_ queueTypeName: String) {
        // no-op
    }

    func chatQueueDry() {
        // no-op
    }

    func reflectionQueueDry() {
        // no-op
    }

    func processTypingIndicator(_ message: TypingIndicatorMessage) {
        // no-op
    }

    func processVoIPCall(
        _ message: NSObject,
        identity: String?,
        onCompletion: ((MessageProcessorDelegate) -> Void)? = nil
    ) {
        // no-op
    }
}
