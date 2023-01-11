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

import CocoaLumberjackSwift
import Foundation

public final class MessageForwarder {
    
    private lazy var old_FileMessageSender = Old_FileMessageSender()

    // MARK: - Lifecycle

    public init() { }
    
    // MARK: - Forwarding

    /// Forwards a given base message to a conversation and adds additional text as caption or additional text message.
    /// - Parameters:
    ///   - message: Base message to be forwarded.
    ///   - conversation: Conversation which message should be forwarded to.
    ///   - additionalText: Additional text to be send as caption for file messages, or as normal text message for other types.
    public func forward(_ message: BaseMessage, to conversation: Conversation, additionalText: String?) {
        
        switch message {
        case let textMessage as TextMessage:
            MessageSender.sendMessage(textMessage.text, in: conversation, quickReply: false, requestID: nil)
            sendAdditionalText(additionalText, to: conversation)
            
        case let locationMessage as LocationMessage:
            let coordinates = CLLocationCoordinate2DMake(
                locationMessage.latitude.doubleValue,
                locationMessage.longitude.doubleValue
            )
            let accuracy = locationMessage.accuracy.doubleValue
            
            MessageSender.sendLocation(
                coordinates,
                accuracy: accuracy,
                poiName: locationMessage.poiName,
                poiAddress: locationMessage.poiAddress,
                in: conversation
            ) { _ in
                // Do nothing.
            }
            sendAdditionalText(additionalText, to: conversation)
            
        case let fileMessage as FileMessageEntity:
            let renderType = fileMessage.type
            
            guard let item = URLSenderItem(
                data: fileMessage.data?.data,
                fileName: fileMessage.fileName,
                type: fileMessage.blobGetUTI(),
                renderType: renderType,
                sendAsFile: true
            ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if let caption = additionalText {
                item.caption = caption
            }
            
            if UserSettings.shared().newChatViewActive {
                Task {
                    do {
                        try await BlobManager.shared.createMessageAndSyncBlobs(for: item, in: conversation.objectID)
                    }
                    catch {
                        DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                    }
                }
            }
            else {
                old_FileMessageSender.send(item, in: conversation, requestID: nil)
            }
            
        case let audioMessage as AudioMessageEntity:
            let type = kUTTypeAudio as String
            
            guard let item = URLSenderItem(
                data: audioMessage.audio.data,
                fileName: audioMessage.audio.getFilename(),
                type: type,
                renderType: 1,
                sendAsFile: true
            ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if UserSettings.shared().newChatViewActive {
                Task {
                    do {
                        try await BlobManager.shared.createMessageAndSyncBlobs(for: item, in: conversation.objectID)
                    }
                    catch {
                        DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                    }
                }
            }
            else {
                old_FileMessageSender.send(item, in: conversation, requestID: nil)
            }
            sendAdditionalText(additionalText, to: conversation)
            
        case let imageMessage as ImageMessageEntity:
            guard let item = URLSenderItem(
                data: imageMessage.image.data,
                fileName: imageMessage.image.getFilename(),
                type: imageMessage.blobGetUTI(),
                renderType: 1,
                sendAsFile: true
            ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if let caption = additionalText {
                item.caption = caption
            }
            
            if UserSettings.shared().newChatViewActive {
                Task {
                    do {
                        try await BlobManager.shared.createMessageAndSyncBlobs(for: item, in: conversation.objectID)
                    }
                    catch {
                        DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                    }
                }
            }
            else {
                old_FileMessageSender.send(item, in: conversation, requestID: nil)
            }
            
        case let videoMessage as VideoMessageEntity:
            guard let item = URLSenderItem(
                data: videoMessage.video.data,
                fileName: videoMessage.video.getFilename(),
                type: videoMessage.blobGetUTI(),
                renderType: 1,
                sendAsFile: true
            ) else {
                DDLogError("[MessageForwarder] Could not create URLSenderItem.")
                return
            }
            
            if let caption = additionalText {
                item.caption = caption
            }
            
            if UserSettings.shared().newChatViewActive {
                Task {
                    do {
                        try await BlobManager.shared.createMessageAndSyncBlobs(for: item, in: conversation.objectID)
                    }
                    catch {
                        DDLogError("[MessageForwarder] Could not send sender item, error: \(error)")
                    }
                }
            }
            else {
                old_FileMessageSender.send(item, in: conversation, requestID: nil)
            }
            
        default:
            DDLogError("[MessageForwarder] Unsupported message type received.")
        }
    }
    
    private func sendAdditionalText(_ text: String?, to conversation: Conversation) {
        guard let text = text else {
            return
        }
        
        MessageSender.sendMessage(text, in: conversation, quickReply: false, requestID: nil)
    }
}
