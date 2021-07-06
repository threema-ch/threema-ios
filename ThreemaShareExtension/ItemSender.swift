//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2021 Threema GmbH
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
import ThreemaFramework
import CoreServices
import PromiseKit
import CocoaLumberjackSwift

protocol SenderItemDelegate : AnyObject {
    func showAlert(with title : String, message : String)
    func setProgress(progress : NSNumber, forItem : Any)
    func finishedItem(item : Any)
    func setFinished()
}

class ItemSender : NSObject {
    private var recipientConversations : Set<Conversation>?
    var itemsToSend : [URL]?
    var textToSend : String?
    var sendAsFile : Bool = false
    var captions : [String?] = [String?]()
    
    private var sentItemCount : Int?
    private var totalSendCount : Int?
    
    private var correlationIDs : Array<String> = Array()
    
    var shouldCancel : Bool = false
    
    private var uploadSema = DispatchSemaphore(value: 0)
    private var sender : FileMessageSender?
    
    weak var delegate : SenderItemDelegate?
    
    func itemCount() -> Promise<Int> {
        var count = 0
        if itemsToSend != nil {
            return .value(itemsToSend!.count)
        }
        
        guard let text = textToSend else {
            return .value(count)
        }
        if text.count > 0 {
            count = count + 1
        }
        
        return .value(count)
    }
    
    func addText(text : String) {
        textToSend = text
    }
    
    private func sendTextItems() {
        for conversation in recipientConversations! {
            if shouldCancel {
                return
            }
            self.sendItem(senderItem: textToSend!, toConversation: conversation, correlationId: nil)
        }
    }
    
    private func sendMediaItems() {
        let conv : [Conversation] = Array(recipientConversations!)
        DispatchQueue.global(qos: .userInitiated).async {
            var senderItem : URLSenderItem?
            var sentItems = 0
            for i in 0..<self.itemsToSend!.count {
                autoreleasepool {
                    senderItem = self.getMediaSenderItem(url:self.itemsToSend![i], caption: self.captions[i])
                    
                    for j in 0..<conv.count {
                        autoreleasepool {
                            self.sendItem(senderItem: senderItem!,
                                          toConversation: conv[j],
                                          correlationId: self.correlationIDs[j])
                        }
                        sentItems += 1
                        if sentItems > 10 {
                            sentItems = 0
                            DatabaseManager.db()?.refreshDirtyObjects()
                        }
                    }
                }
            }
        }
    }
    
    private func getMediaSenderItem(url : URL, caption : String?) -> URLSenderItem {
        var senderItem : URLSenderItem
        if self.sendAsFile {
            let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url))
            senderItem = URLSenderItem(url: url,
                                       type: mimeType,
                                       renderType: 0,
                                       sendAsFile: true)
        } else {
            guard let item = URLSenderItemCreator.getSenderItem(for: url, maxSize: "large") else {
                let mimeType = UTIConverter.mimeType(fromUTI: UTIConverter.uti(forFileURL: url)) ?? "unknown type"
                let msg = "Could not create sender item for item of type \(mimeType )"
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
    
    func sendItemsTo(conversations : Set<Conversation>) {
        self.recipientConversations = conversations
        _ = self.itemCount().done { itemCount in
            self.totalSendCount = self.recipientConversations!.count * itemCount
            self.sentItemCount = 0
            
            if self.textToSend != nil {
                self.sendTextItems()
            } else if self.itemsToSend != nil {
                for _ in 0..<self.recipientConversations!.count {
                    self.correlationIDs.append(ImageURLSenderItemCreator.createCorrelationID())
                }
                self.sendMediaItems()
            } else {
                let err = "No sendable items provided"
                DDLogError(err)
                fatalError(err)
            }
        }
    }
    
    private func sendItem(senderItem : Any, toConversation : Conversation, correlationId : String?) {
        if let senderItem = senderItem as? URLSenderItem {
            sendUrlSenderItem(senderItem: senderItem, toConversation: toConversation, correlationId: correlationId)
        } else if let message = senderItem as? String {
            if message.count > 0 {
                sendString(message: message, toConversation: toConversation)
            } else {
                delegate?.finishedItem(item: self.progressItemKey(item: message, conversation: toConversation)!)
                sentItemCount = sentItemCount! + 1
                self.checkIsFinished()
            }
        } else {
            let title = BundleUtil.localizedString(forKey:"error_message_no_items_title")
            let message = BundleUtil.localizedString(forKey:"error_message_no_items_message")
            delegate!.showAlert(with: title, message: message)
            
            sentItemCount = sentItemCount! + 1
            self.checkIsFinished()
        }
    }
    
    private func sendUrlSenderItem(senderItem : URLSenderItem, toConversation : Conversation, correlationId : String?) {
        sender = FileMessageSender()
        sender!.uploadProgressDelegate = self
        sender!.send((senderItem), in: toConversation, requestId: nil, correlationId: correlationId)
        self.uploadSema.wait()
        sender = nil
    }
    
    private func sendString(message : String, toConversation : Conversation) {
        DispatchQueue.main.async {
            self.delegate?.setProgress(progress: 0.1, forItem: self.progressItemKey(item: message, conversation:toConversation)!)
            
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !(trimmedMessage == "" || trimmedMessage == "\u{fffc}") {
                let messages = Utils.getTrimmedMessages(trimmedMessage)
                
                if messages == nil {
                    MessageSender.sendMessage(trimmedMessage, in: toConversation, async: true, quickReply: false, requestId: nil, onCompletion: {(textMessage, conversation) in
                        self.awaitAckForMessageId(messageId: textMessage!.id)
                    })
                } else {
                    for m in messages! {
                        MessageSender.sendMessage(m as? String, in: toConversation, async: true, quickReply: false, requestId: nil, onCompletion: {(textMessage, conversation) in
                            self.awaitAckForMessageId(messageId: textMessage!.id)
                        })
                    }
                }
            }
        }
    }
    
    private func awaitAckForMessageId(messageId : Data) {
        let entityManager = EntityManager()
        let message = entityManager.entityFetcher.ownMessage(withId: messageId)
        
        message?.addObserver(self, forKeyPath: "sent", options: .new, context: nil)
    }
    
    //MARK: - KVO
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object is TextMessage {
            let message = object as! TextMessage
            
            delegate?.finishedItem(item: [self.progressItemKey(item: message.text!, conversation: message.conversation)])
            
            message.removeObserver(self, forKeyPath: "sent")
            
            DatabaseManager.db()?.addDirtyObject(message.conversation)
            DatabaseManager.db()?.addDirtyObject(message.conversation.lastMessage)
            
            sentItemCount! += 1
            self.checkIsFinished()
        }
    }
    
    private func progressItemKey(item : String, conversation : Conversation) -> Any? {
        let hash : NSInteger = (item as AnyObject).hash + conversation.hashValue
        return NSNumber(value: hash)
    }
    
    private func checkIsFinished() {
        if sentItemCount == totalSendCount {
            let when = DispatchTime.now() + 0.75
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: when, execute: {
                DispatchQueue.main.async { [self] in
                    self.delegate?.setFinished()
                }
            })
        }
    }
}

//MARK: - UploadProgressDelegate

extension ItemSender : UploadProgressDelegate {
    public func blobMessageSenderUploadShouldCancel(_ blobMessageSender: BlobMessageSender!) -> Bool {
        return shouldCancel
    }
    
    public func blobMessageSender(_ blobMessageSender: BlobMessageSender!, uploadProgress progress: NSNumber!, for message: BaseMessage!) {
        delegate?.setProgress(progress: progress, forItem: message.id!)
    }
    
    public func blobMessageSender(_ blobMessageSender: BlobMessageSender!, uploadSucceededFor message: BaseMessage) {
        sentItemCount! += 1
        delegate?.finishedItem(item: message.id!)

        markDirty(for: message)

        self.checkIsFinished()
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
    }
    
    public func blobMessageSender(_ blobMessageSender: BlobMessageSender!, uploadFailedFor message: BaseMessage!, error: UploadError) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.uploadSema.signal()
        }
        sentItemCount! += 1
        
        
        let errorTitle = BundleUtil.localizedString(forKey:"error_sending_failed")
        let errorMessage = FileMessageSender.message(forError: error)
        
        delegate?.showAlert(with: errorTitle, message: errorMessage!)
        
        if error == UploadErrorSendFailed {
            markDirty(for: message)
        }
    }
    
    private func markDirty(for message: BaseMessage) {
        DatabaseManager.db()?.addDirtyObject(message.conversation)
        DatabaseManager.db()?.addDirtyObject(message)
        
        if let fileMessage = message as? FileMessage {
            DatabaseManager.db()?.addDirtyObject(fileMessage.thumbnail)
            DatabaseManager.db()?.addDirtyObject(fileMessage.data)
        }
    }
}
