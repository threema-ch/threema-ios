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
import ThreemaEssentials
import ThreemaProtocols

enum MediatorReflectedProcessorError: Error {
    case contactNotFound(identity: String)
    case contactToCreateAlreadyExists(identity: String)
    case contactToDeleteNotExists(identity: String)
    case contactToDeleteMemberOfGroup(identity: String)
    case contactToUpdateNotExists(identity: String)
    case createContactFailed(identity: String)
    case doNotAckIncomingVoIPMessage
    case downloadFailed(message: String)
    case groupCreateFailed(groupIdentity: GroupIdentity)
    case groupNotFound(message: String)
    case groupToCreateAlreadyExists(groupIdentity: GroupIdentity)
    case groupToDeleteNotExists(groupIdentity: GroupIdentity)
    case groupToUpdateNotExists(groupIdentity: GroupIdentity)
    case conversationNotFound(message: String)
    case messageDecodeFailed(message: String)
    case messageNotProcessed(message: String)
    case messageWontProcessed(message: String)
    case missingPublicKey(identity: String)
    case outgoingMessageTypeIsDeprecated(type: Common_CspE2eMessageType)
    case outgoingMessageReceiverNotFound(message: String)
    case receiverNotFound(identity: String)
    case senderNotFound(identity: String)
}

protocol MediatorReflectedProcessorProtocol {
    func process(
        reflectedEnvelope: D2d_Envelope,
        reflectedAt: Date,
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
    ///   - reflectedEnvelope: Reflected data
    ///   - reflectedAt: Date of reflected message given Mediator Server
    ///   - receivedAfterInitialQueueSend: True indicates the message was received before mediator server message queue
    ///                        is dry (abstract message will be marked with this flag, to control in app notification)
    ///   - maxBytesToDecrypt: When e.g. downloaded blob within Notification Extention, then only limited memory
    ///                        available to decrypt data
    ///   - timeoutDownloadThumbnail: Timeout for downloading blob (0 = infinity)
    func process(
        reflectedEnvelope: D2d_Envelope,
        reflectedAt: Date,
        receivedAfterInitialQueueSend: Bool,
        maxBytesToDecrypt: Int,
        timeoutDownloadThumbnail: Int
    ) -> Promise<Void> {

        switch reflectedEnvelope.content {
        case .distributionListSync:
            DDLogWarn("Distribution list sync not implemented")
            return Promise()
        case let .groupSync(groupSync):
            let processor = MediatorReflectedGroupSyncProcessor(
                frameworkInjector: frameworkInjector
            )
            return processor.process(groupSync: groupSync)
        case let .incomingMessageUpdate(incomingMessageUpdate):
            let processor = MediatorReflectedIncomingMessageUpdateProcessor(
                frameworkInjector: frameworkInjector,
                messageProcessorDelegate: messageProcessorDelegate
            )
            return processor.process(incomingMessageUpdate: incomingMessageUpdate)
        case let .outgoingMessageUpdate(outgoingMessageUpdate):
            let processor = MediatorReflectedOutgoingMessageUpdateProcessor(frameworkInjector: frameworkInjector)
            return processor.process(outgoingMessageUpdate: outgoingMessageUpdate, reflectedAt: reflectedAt)
        case let .outgoingMessage(outgoingMessage):
            return Promise<AbstractMessage> { seal in
                let decoder = MediatorReflectedMessageDecoder(frameworkBusinessInjector: self.frameworkInjector)
                try seal.fulfill(decoder.decode(outgoingMessage: outgoingMessage))
            }
            .then { abstractMessage -> Promise<Void> in
                let processor = MediatorReflectedOutgoingMessageProcessor(
                    frameworkInjector: self.frameworkInjector,
                    messageStore: MessageStore(
                        frameworkInjector: self.frameworkInjector,
                        messageProcessorDelegate: self.messageProcessorDelegate
                    ),
                    messageProcessorDelegate: self.messageProcessorDelegate,
                    reflectedAt: reflectedAt,
                    maxBytesToDecrypt: maxBytesToDecrypt,
                    timeoutDownloadThumbnail: timeoutDownloadThumbnail
                )
                return try processor.process(outgoingMessage: outgoingMessage, abstractMessage: abstractMessage)
                    .then {
                        self.frameworkInjector.nonceGuard.processed(nonces: outgoingMessage.nonces)
                        return Promise()
                    }
            }

        case let .incomingMessage(incomingMessage):
            return Promise<AbstractMessage> { seal in
                guard try !frameworkInjector.nonceGuard.isProcessed(d2dIncomingMessage: incomingMessage) else {
                    throw MediatorReflectedProcessorError
                        .messageWontProcessed(
                            message: "Nonce of message \(incomingMessage.loggingDescription) already processed"
                        )
                }

                let decoder = MediatorReflectedMessageDecoder(frameworkBusinessInjector: self.frameworkInjector)
                try seal.fulfill(
                    decoder.decode(
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
                    reflectedAt: reflectedAt,
                    maxBytesToDecrypt: maxBytesToDecrypt,
                    timeoutDownloadThumbnail: timeoutDownloadThumbnail
                )
                abstractMessage.receivedAfterInitialQueueSend = receivedAfterInitialQueueSend
                return try processor.process(incomingMessage: incomingMessage, abstractMessage: abstractMessage)
                    .then {
                        self.frameworkInjector.nonceGuard.processed(nonce: incomingMessage.nonce)
                        return Promise()
                    }
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
        case .mdmParameterSync:
            DDLogWarn("MDM parameter sync not implemented")
            return Promise()
        case .none:
            return Promise()
        }
    }
}
