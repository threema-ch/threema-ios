//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2025 Threema GmbH
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

import CocoaLumberjackSwift
import Foundation
import PromiseKit

/// Process and ack incoming (reflected) message from mediator server.
final class TaskExecutionReceiveReflectedMessage: TaskExecution, TaskExecutionProtocol {
    func execute() -> Promise<Void> {
        guard let task = taskDefinition as? TaskDefinitionReceiveReflectedMessage else {
            return Promise(error: TaskExecutionError.wrongTaskDefinitionType)
        }

        // Decode incoming reflected message
        let (reflectID, reflectedEnvelopeData, reflectedAt) = MediatorMessageProtocol
            .decodeReflected(task.reflectedMessage)
        DDLogNotice("\(task) incoming reflected message (reflect ID \(reflectID.hexString))")

        return Promise { seal in
            // Decrypt incoming reflected message
            guard let reflectedEnvelope = self.frameworkInjector.mediatorMessageProtocol
                .decryptEnvelope(data: reflectedEnvelopeData) else {
                try ack(reflectID: reflectID)

                throw TaskExecutionError.decryptMessageFailed(reflectID: reflectID.hexString)
            }

            DDLogNotice("\(task) process reflected message \(reflectedEnvelope.loggingDescription)")

            // Process incoming reflected message
            self.frameworkInjector.mediatorReflectedProcessor.process(
                reflectedEnvelope: reflectedEnvelope,
                reflectedAt: reflectedAt,
                receivedAfterInitialQueueSend: task.receivedAfterInitialQueueSend,
                maxBytesToDecrypt: Int(task.maxBytesToDecrypt),
                timeoutDownloadThumbnail: Int(task.timeoutDownloadThumbnail)
            )
            .then {
                // Successfully processed
                try self.ack(reflectID: reflectID)

                seal.fulfill_()

                return Promise()
            }
            .catch(on: .global()) { processingError in
                // Discard incoming reflected message on error, if not ThreemaProtocolError.notLoggedIn,
                // MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage or
                // ThreemaProtocolError.doNotProcessOfferMessageInNotificationExtension
                switch processingError {
                case let nsError as NSError
                    where nsError.code == ThreemaProtocolError.notLoggedIn.rawValue:

                    seal.reject(processingError)
                case MediatorReflectedProcessorError.doNotAckIncomingVoIPMessage,
                     ThreemaProtocolError.doNotProcessOfferMessageInNotificationExtension:
                    seal.reject(processingError)
                default:
                    DDLogWarn(
                        "\(task) discard reflected message \(reflectedEnvelope.loggingDescription) with error: \(processingError)"
                    )

                    do {
                        try self.frameworkInjector.nonceGuard.processed(reflectedEnvelope: reflectedEnvelope)
                    }
                    catch {
                        DDLogError(
                            "\(task) store message nonce of reflected message failed: \(error)"
                        )
                    }

                    do {
                        try self.ack(reflectID: reflectID)
                        seal.fulfill_()
                    }
                    catch {
                        DDLogError(
                            "\(task) sending server ack of reflected message failed: \(error)"
                        )
                        seal.reject(error)
                    }
                }
            }
        }
    }

    private func ack(reflectID: Data) throws {
        if let error = frameworkInjector.serverConnector.reflectMessage(
            frameworkInjector.mediatorMessageProtocol.encodeReflectedAck(reflectID: reflectID)
        ) {
            throw error
        }
    }
}
