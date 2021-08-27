//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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
import CocoaLumberjackSwift

public class WebCreateFileMessageRequest: WebAbstractMessage {
    
    var backgroundIdentifier: String?
    
    var type: String
    var id: String?
    var groupId: Data?
    
    var name: String
    var fileType: String
    var sendAsFile: Bool
    var size: Int
    var fileData: Data?
    var caption: String?
    var tmpError: String? = nil
    
    var baseMessage: BaseMessage? = nil
    
    var session: WCSession?
    
    override init(message:WebAbstractMessage) {
        
        type = message.args!["type"] as! String
        if type == "contact" {
            id = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as! String
            groupId = idString.hexadecimal()
        }
        
        let data = message.data! as! [AnyHashable:Any?]
        name = data["name"] as! String
        fileType = data["fileType"] as! String
        sendAsFile = data["sendAsFile"] as! Bool
        
        if let tmpSize = data["size"] as? UInt8 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt16 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt32 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt64 {
            size = Int(tmpSize)
        }
        else {
            size = 0
        }
        
        self.fileData = data["data"] as? Data
        caption = data["caption"] as? String
        super.init(message: message)
    }
    
    init(message:WebAbstractMessage, session: WCSession) {
        
        type = message.args!["type"] as! String
        if type == "contact" {
            id = message.args!["id"] as? String
        } else {
            let idString = message.args!["id"] as! String
            groupId = idString.hexadecimal()
        }
        
        let data = message.data! as! [AnyHashable:Any?]
        name = data["name"] as! String
        fileType = data["fileType"] as! String
        sendAsFile = data["sendAsFile"] as! Bool
        
        if let tmpSize = data["size"] as? UInt8 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt16 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt32 {
            size = Int(tmpSize)
        }
        else if let tmpSize = data["size"] as? UInt64 {
            size = Int(tmpSize)
        }
        else {
            size = 0
        }
        
        self.fileData = data["data"] as? Data
        caption = data["caption"] as? String
        self.session = session
        super.init(message: message)
    }
    
    func sendMessage(completion: @escaping () -> ()) {
        var conversation: Conversation? = nil
        var entityManager: EntityManager?
        if self.type == "contact" {
                entityManager = EntityManager()
                let contact = entityManager?.entityFetcher.contact(forId: self.id)
                if contact == nil {
                    self.baseMessage = nil
                    tmpError = "internalError"
                    completion()
                    return
                }

                conversation = entityManager!.entityFetcher.conversation(for: contact)
                if conversation == nil {
                    entityManager?.performSyncBlockAndSafe({
                        conversation = entityManager!.entityCreator.conversation()
                        conversation?.contact = contact
                    })
                }
        } else {
                entityManager = EntityManager()
                conversation = entityManager?.entityFetcher.conversation(forGroupId: self.groupId)
        }
        
        
        if conversation != nil {
            if !PermissionChecker.init().canSend(in: conversation, entityManager: entityManager) {
                self.baseMessage = nil
                tmpError = "blocked"
                completion()
                return
            }
            
            if size > kMaxFileSize {
                self.baseMessage = nil
                tmpError = "fileTooLarge"
                completion()
                return
            }
            
            if fileData == nil {
                self.baseMessage = nil
                tmpError = "internalError"
                completion()
                return
            }
            
            backgroundIdentifier = BackgroundTaskManager.shared.counter(identifier: kAppSendingBackgroundTask)
            BackgroundTaskManager.shared.newBackgroundTask(key: backgroundIdentifier!, timeout: Int(kAppSendingBackgroundTaskTime)) {
                if !self.sendAsFile && (self.fileType == "image/jpeg" || self.fileType == "image/pjpeg" || self.fileType == "image/png" || self.fileType == "image/x-png" ) {
                    let imageSender = ImageURLSenderItemCreator()
                    guard let item = imageSender.senderItem(from: self.fileData!, uti: self.fileType) else {
                        DDLogError("Could not create URLSenderItem from image")
                        return
                    }
                    item.caption = self.caption
                    let sender = FileMessageSender()
                    sender.send(item, in: conversation, requestId: self.requestId)
                }
                else if !self.sendAsFile && ( self.fileType == "video/mp4" || self.fileType == "video/mpeg4" || self.fileType == "video/x-m4v" ) {
                    let creator = VideoURLSenderItemCreator()
                    guard let data = self.fileData else {
                        return
                    }
                    guard let videoURL = VideoURLSenderItemCreator.writeToTemporaryDirectory(data: data) else {
                        return
                    }
                    guard let senderItem = creator.senderItem(from: videoURL) else {
                        return
                    }
                    let fileSender = FileMessageSender()
                    fileSender.send(senderItem, in: conversation, requestId: self.requestId)
                    do {
                        try FileManager.default.removeItem(at: videoURL)
                    } catch {
                        DDLogError("Could not clear temporary directory \(error)")
                    }
                    
                }
                // Note: Audio files are always sent as file messages except when they are recorded voice
                // messages inside the app. Thus we don't have a special case for them here.
                else {
                    DispatchQueue.main.async {
                        let blobSender = FileMessageSender.init()
                        blobSender.fileNameFromWeb = self.name
                        let item = URLSenderItem.init(data: self.fileData, fileName: blobSender.fileNameFromWeb, type: UTIConverter.uti(fromMimeType: self.fileType), renderType:0, sendAsFile: true)
                        item?.caption = self.caption
                        blobSender.send(item, in: conversation, requestId: self.requestId)
                    }
                }
                completion()
                return
            }
        } else {
            self.baseMessage = nil
            tmpError = "internalError"
            completion()
            return
        }
    }
}
