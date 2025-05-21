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
import CoreServices
import Foundation
import PromiseKit
import ThreemaFramework
import ThreemaMacros

protocol SenderItemDelegate: AnyObject {
    func showAlert(with title: String, message: String)
    func setProgress(progress: NSNumber, forItem: Any)
    func finishedItem(item: Any)
    func setFinished()
}

class ItemSender: NSObject {
    private var recipientConversations: Set<ConversationEntity>?
    var itemsToSend: [URL]?
    var textToSend: String?
    var sendAsFile = false
    var captions = [String?]()
    
    private var sentItemCount: Int?
    private var totalSendCount: Int?
    
    private var correlationIDs: [String] = Array()
    
    var shouldCancel = false
    
    private var uploadSema = DispatchSemaphore(value: 0)
    private var sender: Old_FileMessageSender?
    
    weak var delegate: SenderItemDelegate?
    
    func itemCount() -> Promise<Int> {
        var count = 0
        if itemsToSend != nil {
            return .value(itemsToSend!.count)
        }
        
        guard let text = textToSend else {
            return .value(count)
        }
        if !text.isEmpty {
            count = count + 1
        }
        
        return .value(count)
    }
    
    func addText(text: String) {
        textToSend = text
    }
    
    private func sendTextItems() {
        for conversation in recipientConversations! {
            if shouldCancel {
                return
            }
            sendItem(senderItem: textToSend!, toConversation: conversation, correlationID: nil)
        }
    }
    
    private func sendMediaItems() {
        let conv: [ConversationEntity] = Array(recipientConversations!)
        DispatchQueue.global().async {
            var senderItem: URLSenderItem?
            for i in 0..<self.itemsToSend!.count {
                guard !self.shouldCancel else {
                    return
                }
                
                autoreleasepool {
                    senderItem = self.getMediaSenderItem(url: self.itemsToSend![i], caption: self.captions[i])
                    
                    for j in 0..<conv.count {
                        guard !self.shouldCancel else {
                            senderItem = nil
                            return
                        }
                        
                        autoreleasepool {
                            self.sendItem(
                                senderItem: senderItem!,
                                toConversation: conv[j],
                                correlationID: self.correlationIDs[j]
                            )
                        }
                        // We do no longer call refreshDirtyObjects(false) since it lead to some changes not being saved
                        // correctly, and thus have higher memory usage in the share extension.
                    }
                    senderItem = nil
                }
            }
        }
    }
    
    private func getMediaSenderItem(url: URL, caption: String?) -> URLSenderItem {
        var senderItem: URLSenderItem
        if sendAsFile {
            let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
            senderItem = URLSenderItem(
                url: url,
                type: mimeType,
                renderType: 0,
                sendAsFile: true
            )
        }
        else {
            guard let item = URLSenderItemCreator.getSenderItem(for: url, maxSize: .large) else {
                let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url)) ?? "unknown type"
                let msg = "Could not create sender item for item of type \(mimeType)"
                DDLogError("\(msg)")
                fatalError(msg)
            }
            senderItem = item
        }
        if let caption, !caption.isEmpty {
            senderItem.caption = caption
        }
        return senderItem
    }
    
    func sendItemsTo(conversations: Set<ConversationEntity>) {
        recipientConversations = conversations
        _ = itemCount().done { itemCount in
            self.totalSendCount = self.recipientConversations!.count * itemCount
            self.sentItemCount = 0
            
            if self.textToSend != nil {
                self.sendTextItems()
            }
            else if self.itemsToSend != nil {
                for _ in 0..<self.recipientConversations!.count {
                    self.correlationIDs.append(ImageURLSenderItemCreator.createCorrelationID())
                }
                self.sendMediaItems()
            }
            else {
                let err = "No sendable items provided"
                DDLogError("\(err)")
                fatalError(err)
            }
        }
    }
    
    private func sendItem(senderItem: Any, toConversation: ConversationEntity, correlationID: String?) {
        if let senderItem = senderItem as? URLSenderItem {
            sendURLSenderItem(senderItem: senderItem, toConversation: toConversation, correlationID: correlationID)
        }
        else if let message = senderItem as? String {
            
            let trimmedMessage = ThreemaUtility.trimCharacters(in: message)
            if !(trimmedMessage == "" || trimmedMessage == "\u{fffc}"), !trimmedMessage.isEmpty {
                sendString(message: message, toConversation: toConversation)
            }
            else {
                let title = #localize("error_message_no_items_title")
                let message = #localize("error_message_no_items_message")
                delegate!.showAlert(with: title, message: message)
                
                delegate?.finishedItem(item: progressItemKey(item: message, conversation: toConversation)!)
                sentItemCount = sentItemCount! + 1
                checkIsFinished()
            }
        }
        else {
            let title = #localize("error_message_no_items_title")
            let message = #localize("error_message_no_items_message")
            delegate!.showAlert(with: title, message: message)
            
            sentItemCount = sentItemCount! + 1
            checkIsFinished()
        }
    }
    
    private func sendURLSenderItem(
        senderItem: URLSenderItem,
        toConversation: ConversationEntity,
        correlationID: String?
    ) {
        sender = Old_FileMessageSender()
        sender!.uploadProgressDelegate = self
        sender!.send(senderItem, in: toConversation, requestID: nil, correlationID: correlationID)
        if toConversation.conversationVisibility == .archived {
            toConversation.visibility = ConversationEntity.Visibility.default.rawValue as NSNumber
        }
        uploadSema.wait()
        sender = nil
    }
    
    private func sendString(message: String, toConversation: ConversationEntity) {
        Task { @MainActor in
            self.delegate?.setProgress(
                progress: 0.1,
                forItem: self.progressItemKey(item: message, conversation: toConversation)!
            )
            
            Task {
                let textMessages = await BusinessInjector().messageSender.sendTextMessage(
                    containing: message,
                    in: toConversation
                )
                Task { @MainActor in
                    self.textMessageCompletionHandler(textMessages: textMessages)
                }
            }
        }
    }
    
    private func textMessageCompletionHandler(textMessages: [TextMessageEntity]) {
        for textMessage in textMessages {
            delegate?
                .finishedItem(item: [progressItemKey(item: textMessage.text, conversation: textMessage.conversation)])
            
            if textMessage.conversation.conversationVisibility == .archived {
                textMessage.conversation.visibility = ConversationEntity.Visibility.default
                    .rawValue as NSNumber
            }
            
            DatabaseManager.db()?.addDirtyObject(textMessage.conversation)
            DatabaseManager.db()?.addDirtyObject(textMessage.conversation.lastMessage)
            
            sentItemCount! += 1
            checkIsFinished()
        }
    }
    
    private func progressItemKey(item: String, conversation: ConversationEntity) -> Any? {
        let hash: NSInteger = (item as AnyObject).hash + conversation.hashValue
        return NSNumber(value: hash)
    }
    
    private func checkIsFinished() {
        if sentItemCount == totalSendCount {
            let when = DispatchTime.now() + 0.75
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: when) {
                DispatchQueue.main.async {
                    self.delegate?.setFinished()
                }
            }
        }
    }
}

// MARK: - UploadProgressDelegate

extension ItemSender: UploadProgressDelegate {
    public func blobMessageSenderUploadShouldCancel(_ blobMessageSender: Old_BlobMessageSender!) -> Bool {
        shouldCancel
    }
    
    public func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender!,
        uploadProgress progress: NSNumber!,
        forMessage message: BaseMessageEntity!
    ) {
        delegate?.setProgress(progress: progress, forItem: message.id)
    }
    
    public func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender!,
        uploadSucceededForMessage message: BaseMessageEntity
    ) {
        sentItemCount! += 1
        delegate?.finishedItem(item: message.id)

        markDirty(for: message)

        checkIsFinished()
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
    }
    
    public func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender!,
        uploadFailedForMessage message: BaseMessageEntity!,
        error: UploadError
    ) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
        sentItemCount! += 1
        
        let errorTitle = #localize("error_sending_failed")
        let errorMessage = Old_FileMessageSender.message(forError: error)
        
        delegate?.showAlert(with: errorTitle, message: errorMessage!)
        
        if error == UploadErrorSendFailed {
            markDirty(for: message)
        }
    }
    
    private func markDirty(for message: BaseMessageEntity) {
        DatabaseManager.db()?.addDirtyObject(message.conversation)
        DatabaseManager.db()?.addDirtyObject(message)
        
        if let fileMessageEntity = message as? FileMessageEntity {
            DatabaseManager.db()?.addDirtyObject(fileMessageEntity.thumbnail)
            DatabaseManager.db()?.addDirtyObject(fileMessageEntity.data)
        }
    }
}
