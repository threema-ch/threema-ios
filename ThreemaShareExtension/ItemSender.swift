//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021-2022 Threema GmbH
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

protocol SenderItemDelegate: AnyObject {
    func showAlert(with title: String, message: String)
    func setProgress(progress: NSNumber, forItem: Any)
    func finishedItem(item: Any)
    func setFinished()
}

class ItemSender: NSObject {
    private var recipientConversations: Set<Conversation>?
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
        let conv: [Conversation] = Array(recipientConversations!)
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
                        DatabaseManager.db()?.refreshDirtyObjects(false)
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
                DDLogError(msg)
                fatalError(msg)
            }
            senderItem = item
        }
        if let caption = caption, !caption.isEmpty {
            senderItem.caption = caption
        }
        return senderItem
    }
    
    func sendItemsTo(conversations: Set<Conversation>) {
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
                DDLogError(err)
                fatalError(err)
            }
        }
    }
    
    private func sendItem(senderItem: Any, toConversation: Conversation, correlationID: String?) {
        if let senderItem = senderItem as? URLSenderItem {
            sendURLSenderItem(senderItem: senderItem, toConversation: toConversation, correlationID: correlationID)
        }
        else if let message = senderItem as? String {
            if !message.isEmpty {
                sendString(message: message, toConversation: toConversation)
            }
            else {
                delegate?.finishedItem(item: progressItemKey(item: message, conversation: toConversation)!)
                sentItemCount = sentItemCount! + 1
                checkIsFinished()
            }
        }
        else {
            let title = BundleUtil.localizedString(forKey: "error_message_no_items_title")
            let message = BundleUtil.localizedString(forKey: "error_message_no_items_message")
            delegate!.showAlert(with: title, message: message)
            
            sentItemCount = sentItemCount! + 1
            checkIsFinished()
        }
    }
    
    private func sendURLSenderItem(senderItem: URLSenderItem, toConversation: Conversation, correlationID: String?) {
        sender = Old_FileMessageSender()
        sender!.uploadProgressDelegate = self
        sender!.send(senderItem, in: toConversation, requestID: nil, correlationID: correlationID)
        toConversation.conversationVisibility = .default
        uploadSema.wait()
        sender = nil
    }
    
    private func sendString(message: String, toConversation: Conversation) {
        DispatchQueue.main.async {
            self.delegate?.setProgress(
                progress: 0.1,
                forItem: self.progressItemKey(item: message, conversation: toConversation)!
            )
            
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !(trimmedMessage == "" || trimmedMessage == "\u{fffc}") {
                let messages = ThreemaUtilityObjC.getTrimmedMessages(trimmedMessage)
                
                if let messages = messages {
                    for m in messages {
                        MessageSender.sendMessage(
                            m as? String,
                            in: toConversation,
                            quickReply: false,
                            requestID: nil,
                            completion: self.textMessageCompletionHandler(baseMessage:)
                        )
                    }
                }
                else {
                    MessageSender.sendMessage(
                        trimmedMessage,
                        in: toConversation,
                        quickReply: false,
                        requestID: nil,
                        completion: self.textMessageCompletionHandler(baseMessage:)
                    )
                }
            }
        }
    }
    
    @objc private func textMessageCompletionHandler(baseMessage: BaseMessage?) {
        if let message = baseMessage as? TextMessage {
            delegate?.finishedItem(item: [progressItemKey(item: message.text!, conversation: message.conversation)])
            
            message.conversation.conversationVisibility = .default
            
            DatabaseManager.db()?.addDirtyObject(message.conversation)
            DatabaseManager.db()?.addDirtyObject(message.conversation.lastMessage)
            
            sentItemCount! += 1
            checkIsFinished()
        }
        else {
            DDLogError("Expected a TextMessage but received something else \(type(of: baseMessage))")
        }
    }
    
    private func progressItemKey(item: String, conversation: Conversation) -> Any? {
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
        for message: BaseMessage!
    ) {
        delegate?.setProgress(progress: progress, forItem: message.id!)
    }
    
    public func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender!,
        uploadSucceededFor message: BaseMessage
    ) {
        sentItemCount! += 1
        delegate?.finishedItem(item: message.id!)

        markDirty(for: message)

        checkIsFinished()
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
    }
    
    public func blobMessageSender(
        _ blobMessageSender: Old_BlobMessageSender!,
        uploadFailedFor message: BaseMessage!,
        error: UploadError
    ) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
        sentItemCount! += 1
        
        let errorTitle = BundleUtil.localizedString(forKey: "error_sending_failed")
        let errorMessage = Old_FileMessageSender.message(forError: error)
        
        delegate?.showAlert(with: errorTitle, message: errorMessage!)
        
        if error == UploadErrorSendFailed {
            markDirty(for: message)
        }
    }
    
    private func markDirty(for message: BaseMessage) {
        DatabaseManager.db()?.addDirtyObject(message.conversation)
        DatabaseManager.db()?.addDirtyObject(message)
        
        if let fileMessageEntity = message as? FileMessageEntity {
            DatabaseManager.db()?.addDirtyObject(fileMessageEntity.thumbnail)
            DatabaseManager.db()?.addDirtyObject(fileMessageEntity.data)
        }
    }
}
