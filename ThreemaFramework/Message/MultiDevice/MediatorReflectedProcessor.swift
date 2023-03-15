//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2020-2023 Threema GmbH
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
import SwiftProtobuf

enum MediatorReflectedProcessorError: Error {
    case contactNotFound(identity: String)
    case contactToCreateAlreadyExists(identity: String)
    case contactToDeleteNotExists(identity: String)
    case contactToDeleteMemberOfGroup(identity: String)
    case contactToUpdateNotExists(identity: String)
    case createContactFailed(identity: String)
    case doNotAckIncomingVoIPMessage
    case downloadFailed(message: String)
    case groupCreateFailed(groupID: String, groupCreatorIdentity: String)
    case groupNotFound(message: String)
    case conversationNotFound(message: String)
    case messageDecodeFailed(message: String)
    case messageNotProcessed(message: String)
    case messageWontProcessed(message: String)
    case missingPublicKey(identity: String)
    case outgoingMessageTypeIsDeprecated(type: D2d_MessageType)
    case outgoingMessageReceiverNotFound(message: String)
    case receiverNotFound(identity: String)
    case senderNotFound(identity: String)
}

protocol MediatorReflectedProcessorProtocol {
    func process(
        envelope: D2d_Envelope,
        timestamp: Date,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void>
}

@objc class MediatorReflectedProcessor: NSObject, MediatorReflectedProcessorProtocol {
    
    private let frameworkInjector: FrameworkInjectorProtocol
    private let messageProcessorDelegate: MessageProcessorDelegate
    
    private var maxBytesToDecrypt = 0
    private var timeoutDownloadThumbnail = 0
    
    required init(
        frameworkInjector: FrameworkInjectorProtocol,
        messageProcessorDelegate: MessageProcessorDelegate
    ) {
        self.frameworkInjector = frameworkInjector
        self.messageProcessorDelegate = messageProcessorDelegate
    }
    
    /// Process reflected message, decode and store message into DB.
    /// - Parameters:
    ///   - envelope: Reflected data
    ///   - timestamp: Date of reflected message given Mediator Server
    ///   - receivedAfterInitialQueueSend: True indicates the message was received before mediator server message queue is dry (abstract message will be marked with this flag, to control in app notification)
    ///   - maxBytesToDecrypt: When e.g. downloaded blob within Notification Extention, then only limited memory available to decrypt data
    ///   - timeoutDownloadThumbnail: Timeout for downloading blob (0 = infinity)
    func process(
        envelope: D2d_Envelope,
        timestamp: Date,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {

        switch envelope.content {
        case .distributionListSync:
            return Promise()
        case .groupSync:
            return Promise()
        case let .incomingMessageUpdate(incomingMessageUpdate):
            let processor = MediatorReflectedIncomingMessageUpdateProcessor(
                frameworkInjector: frameworkInjector,
                messageProcessorDelegate: messageProcessorDelegate
            )
            return processor.process(incomingMessageUpdate: incomingMessageUpdate)
        case let .outgoingMessageUpdate(outgoingMessageUpdate):
            let processor = MediatorReflectedOutgoingMessageUpdateProcessor(frameworkInjector: frameworkInjector)
            return processor.process(outgoingMessageUpdate: outgoingMessageUpdate)
        case let .outgoingMessage(outgoingMessage):
            return Promise<AbstractMessage> { seal in
                let decoder = MediatorReflectedMessageDecoder(frameworkBusinessInjector: frameworkInjector)
                seal.fulfill(try decoder.decode(outgoingMessage: outgoingMessage))
            }
            .then { abstractMessage -> Promise<Void> in
                let processor = MediatorReflectedOutgoingMessageProcessor(
                    frameworkInjector: self.frameworkInjector,
                    messageStore: MessageStore(
                        frameworkInjector: self.frameworkInjector,
                        messageProcessorDelegate: self.messageProcessorDelegate
                    ),
                    messageProcessorDelegate: self.messageProcessorDelegate,
                    timestamp: timestamp,
                    maxBytesToDecrypt: maxBytesToDecrypt,
                    timeoutDownloadThumbnail: timeoutDownloadThumbnail
                )
                return try processor.process(outgoingMessage: outgoingMessage, abstractMessage: abstractMessage)
            }

        case let .incomingMessage(incomingMessage):
            return Promise<AbstractMessage> { seal in
                let decoder = MediatorReflectedMessageDecoder(frameworkBusinessInjector: frameworkInjector)
                seal
                    .fulfill(
                        try decoder
                            .decode(
                                incomingMessage: incomingMessage,
                                receivedAfterInitialQueueSend: receivedAfterInitialQueueSend
                            )
                    )
            }
            .then { abstractMessage -> Promise<Void> in
                let processor = MediatorReflectedIncomingMessageProcessor(
                    frameworkInjector: self.frameworkInjector,
                    messageStore: MessageStore(
                        frameworkInjector: self.frameworkInjector,
                        messageProcessorDelegate: self.messageProcessorDelegate
                    ),
                    messageProcessorDelegate: self.messageProcessorDelegate,
                    timestamp: timestamp,
                    maxBytesToDecrypt: maxBytesToDecrypt,
                    timeoutDownloadThumbnail: timeoutDownloadThumbnail
                )
                abstractMessage.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend
                return try processor.process(incomingMessage: incomingMessage, abstractMessage: abstractMessage)
            }
        case let .userProfileSync(userProfileSync):
            let processor = MediatorReflectedUserProfileSyncProcessor(
                frameworkInjector: frameworkInjector
            )
            return processor.process(userProfileSync: userProfileSync)
        case let .contactSync(contactSync):
            let processor = MediatorReflectedContactSyncProcessor(
                frameworkInjector: frameworkInjector
            )
            return processor.process(contactSync: contactSync)
        case let .settingsSync(settingsSync):
            let processor = MediatorReflectedSettingsSyncProcessor(
                frameworkInjector: frameworkInjector
            )
            return processor.process(settingsSync: settingsSync)
        case .none:
            return Promise()
        }
    }
}
