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

import Foundation
import PromiseKit

protocol MessageProcessorProtocol {
    func processIncoming(
        boxedMessage: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int32,
        timeoutDownloadThumbnail: Int32
    ) -> Promise<AbstractMessageAndFSMessageInfo?>
}

enum MessageProcessorError: Error {
    /// An unknown message was received. If it was inside a FS session the session is passed on. This is needed to
    /// persist the updated session anyway.
    case unknownMessageType(session: DHSession?)
}

// MARK: - MessageProcessor + MessageProcessorProtocol

extension MessageProcessor: MessageProcessorProtocol {
    func processIncoming(
        boxedMessage: BoxedMessage,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int32,
        timeoutDownloadThumbnail: Int32
    ) -> Promise<AbstractMessageAndFSMessageInfo?> {
        Promise { seal in
            processIncomingBoxedMessage(
                boxedMessage,
                receivedAfterInitialQueueSend: receivedAfterInitialQueueSend,
                maxBytesToDecrypt: maxBytesToDecrypt,
                timeoutDownloadThumbnail: timeoutDownloadThumbnail
            ) { abstractMessage, fsMessageInfoObject in
                if abstractMessage == nil, fsMessageInfoObject == nil {
                    seal.fulfill(nil)
                }
                else {
                    seal.fulfill(
                        AbstractMessageAndFSMessageInfo(
                            message: abstractMessage,
                            fsMessageInfo: fsMessageInfoObject
                        )
                    )
                }
            } onError: { error, fsMessageInfoObject in
                // We need to persist the session also for unknown messages. Thus we pass the FS session along with
                // the error
                if (error as NSError).code == ThreemaProtocolError.unknownMessageType.rawValue,
                   let fsMessageInfo = fsMessageInfoObject as? FSMessageInfo {
                    seal.reject(MessageProcessorError.unknownMessageType(session: fsMessageInfo.session))
                }
                else {
                    seal.reject(error)
                }
            }
        }
    }
}
