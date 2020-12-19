//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2020 Threema GmbH
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
import CocoaLumberjackSwift

@objc class PendingMessage: NSObject, NSCoding {
    
    @objc var completionHandler: (() -> Void)? = nil
    
    var senderId: String
    var messageId: String
    @objc var key: String
    var threemaPushNotification: ThreemaPushNotification?
    var fireDate: Date?
    @objc var isPendingGroupMessages = false
    
    private var abstractMessage: AbstractMessage?
    private var baseMessage: BaseMessage?
    private var processed: Bool
    
    // MARK: Public Functions
    
    @objc init(senderIdentity: String, messageIdentity: String) {
        senderId = senderIdentity
        messageId = messageIdentity
        key = senderIdentity + messageIdentity
        processed = false
    }
    
    @objc convenience init(senderIdentity: String, messageIdentity: String, pushPayload: [String: Any]) {
        let threemaPush = try? ThreemaPushNotification(from: pushPayload)
        self.init(senderIdentity: senderIdentity, messageIdentity: messageIdentity, threemaPush: threemaPush)
    }
    
    // Initalizer for `NSCoding`
    private init(senderIdentity: String, messageIdentity: String, threemaPush: ThreemaPushNotification?) {
        senderId = senderIdentity
        messageId = messageIdentity
        key = senderIdentity + messageIdentity
        processed = false
        threemaPushNotification = threemaPush
    }
    
    @objc init(receivedAbstractMessage: AbstractMessage) {
        abstractMessage = receivedAbstractMessage
        senderId = receivedAbstractMessage.fromIdentity
        messageId = receivedAbstractMessage.messageId.hexEncodedString()
        key = senderId + messageId
        processed = false
    }
    
    func isPendingNotification(completion: @escaping (_ pending: Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pendingNotifications in
            DispatchQueue.main.async {
                for pendingNotification in pendingNotifications {
                    if pendingNotification.identifier == self.key {
                        completion(true)
                        return
                    }
                }
                completion(false)
            }
        }
    }
    
    func isMessageAlreadyPushed() -> Bool {
        return processed
    }
    
    // First roundtrip when a new message is received
    func startInitialTimedNotification() {
         ValidationLogger.shared()?.logString("Push: start initial timed notification for message \(messageId)")
        startTimedNotification(setFireDate: true)
    }
    
    // Second roundtrip when a new message is received
    @objc func addAbstractMessage(message: AbstractMessage) {
         ValidationLogger.shared()?.logString("Push: add abstract message for message \(messageId)")
        abstractMessage = message
        startTimedNotification(setFireDate: true)
    }
    
    // Third roundtrip when a new message is received
    @objc func addBaseMessage(message: BaseMessage) {
         ValidationLogger.shared()?.logString("Push: add basemessage for message \(messageId)")
        baseMessage = message
        startTimedNotification(setFireDate: true)
    }
    
    // Final roundrip when a new message is recieved
    @objc func finishedProcessing() {
         ValidationLogger.shared()?.logString("Push: finished processing for message \(messageId)")
        if isPendingGroupMessages == true {
            removeNotification()
            completionHandler?()
            return
        }
        
        guard processed == false else {
            return
        }
        
        processed = true
        
        startTimedNotification(setFireDate: false)
        
        if let currentBaseMessage = baseMessage {
            /* Broadcast a notification, just in case we're currently in another chat within the app */
            if AppDelegate.shared().isAppInBackground() == false && self.abstractMessage!.receivedAfterInitialQueueSend == true {
                if PendingMessagesManager.canMasterDndSendPush() == true {
                    if let pushSetting = PushSetting.find(for: currentBaseMessage.conversation) {
                        if pushSetting.canSendPush(for: currentBaseMessage) {
                            threemaNewMessageReceived()
                            if !pushSetting.silent {
                                NotificationManager.sharedInstance().playReceivedMessageSound()
                            }
                        }
                    } else {
                        threemaNewMessageReceived()
                        NotificationManager.sharedInstance().playReceivedMessageSound()
                    }
                }
                NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
            }
        }
        
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + key
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime)) {
            PendingMessagesManager.shared.pendingMessageIsDone(pendingMessage: self, cancelTask: true)
            self.completionHandler?()
        }
    }
    
    @objc final class func createTestNotification(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        let pushSound = UserSettings.shared().pushSound
        var pushText = "PushTest"
        if let aps = payload["aps"] as? [AnyHashable: Any] {
            if let alert = aps["alert"] {
                pushText = "\(pushText): \(alert)"
            }
        }
        let notification = UNMutableNotificationContent()
        notification.body = pushText
        
        if UserSettings.shared().pushSound != "none" {
            notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound! + ".caf"))
        }
        
        notification.badge = 999
        
        let notificationRequest = UNNotificationRequest(identifier: "PushTest", content: notification, trigger: nil)
        let center = UNUserNotificationCenter.current()
        center.add(notificationRequest) { _ in
            completion()
        }
    }
    
    
    // MARK: Private Functions
    
    private func startTimedNotification(setFireDate: Bool) {
        
        removeNotification()
        
        if PendingMessagesManager.canMasterDndSendPush() == false {
            NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
            return
        }
        
        var pushSetting: PushSetting?
        
        // Check if we should even send any push notification
        
        if let currentBaseMessage = baseMessage {
            pushSetting = PushSetting.find(for: currentBaseMessage.conversation)
            if let localPushSetting = pushSetting, !localPushSetting.canSendPush(for: currentBaseMessage) {
                NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                if AppDelegate.shared().isAppInBackground() == false && self.abstractMessage?.receivedAfterInitialQueueSend == true && processed == true {
                    threemaNewMessageReceived()
                }
                return
            }
        } else {
            // Only non-group messages
            if let localThreemaPushNotification = threemaPushNotification, localThreemaPushNotification.command == .newMessage {
                pushSetting = PushSetting.find(forIdentity: senderId)
                
                if let localPushSetting = pushSetting, !localPushSetting.canSendPush() {
                    NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                    if AppDelegate.shared().isAppInBackground() == false && self.abstractMessage?.receivedAfterInitialQueueSend == true && processed == true {
                        threemaNewMessageReceived()
                    }
                    return
                }
            }
        }
        
        if let localAbstractMessage = abstractMessage,
            localAbstractMessage.shouldPush() == false || (localAbstractMessage.shouldPush() == true && localAbstractMessage.isVoIP() == true) {
            // dont show notification for this message
            return
        }
        
        // Don't scheudle messages for incoming voip calls
        if let localThreemaPushNotification = threemaPushNotification, localThreemaPushNotification.voip == true {
            DDLogDebug("Did not scheudle message for incoming voip call")
            return
        }
        
        // Yes, we want to send a notification
        
        var fromName: String?
        var title: String?
        var body: String?
        var attachmentName: String?
        var attachmentUrl: URL?
        var cmd: String?
        var categoryIdentifier: String?
        var groupId: String?
        
        if abstractMessage != nil && baseMessage != nil {
            // all data (maybe not the image) is loaded and we can show the correct message
            fromName = abstractMessage!.pushFromName
            if fromName == nil || fromName?.count == 0 {
                fromName = abstractMessage!.fromIdentity
            }
            if abstractMessage!.isKind(of: AbstractGroupMessage.self) {
                // group message
                if !UserSettings.shared().pushShowNickname {
                    fromName = baseMessage!.sender.displayName
                }
                
                if UserSettings.shared().pushDecrypt {
                    title = baseMessage!.conversation.groupName
                    if title == nil {
                        title = fromName
                    }
                    body = TextStyleUtils.makeMentionsString(forText: "\(fromName!): \(baseMessage!.previewText()!)")
                    
                    if (abstractMessage!.isKind(of: GroupImageMessage.self) && (baseMessage as! ImageMessage).image != nil) || (abstractMessage!.isKind(of: GroupVideoMessage.self) && (baseMessage as! VideoMessage).thumbnail != nil) ||
                        (abstractMessage!.isKind(of: GroupFileMessage.self) && (baseMessage as! FileMessage).thumbnail != nil) {
                        let tmpDirectory: String! = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last
                        
                        let attachmentDirectory: String = tmpDirectory + "/PushImages"
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: attachmentDirectory) == false {
                            do {
                                try fileManager.createDirectory(at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true), withIntermediateDirectories: false, attributes: nil)
                            } catch {
                                DDLogWarn("Unable to create direcotry for push images at \(attachmentDirectory): \(error)")
                            }
                        }
                        attachmentName = "PushImage_\(abstractMessage!.messageId.hexEncodedString())"
                        let fileName = "/\(attachmentName!).jpg"
                        let path = attachmentDirectory + fileName
                        var imageData: ImageData? = nil
                        
                        if abstractMessage!.isKind(of: GroupVideoMessage.self) {
                            imageData = (baseMessage as! VideoMessage).thumbnail
                        }
                        else if abstractMessage!.isKind(of: GroupFileMessage.self) {
                            imageData = (baseMessage as! FileMessage).thumbnail
                        }
                        else {
                            imageData = (baseMessage as! ImageMessage).image
                        }
                        do {
                            attachmentUrl = URL(fileURLWithPath: path)
                            try imageData!.data.write(to:attachmentUrl! , options: .completeFileProtectionUntilFirstUserAuthentication)
                        }
                        catch {
                            // can't write file, no image preview
                            attachmentName = nil
                            attachmentUrl = nil
                        }
                    }
                } else {
                    body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                }
                // add groupid if message is loaded to open the correct chat after tapping notification
                groupId = baseMessage!.conversation.groupId.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            } else {
                // non group message
                if !UserSettings.shared().pushShowNickname {
                    fromName = baseMessage!.conversation.contact.displayName
                }
                
                if UserSettings.shared().pushDecrypt {
                    title = fromName
                    body = TextStyleUtils.makeMentionsString(forText: baseMessage!.previewText())
                    
                    if (abstractMessage!.isKind(of: BoxImageMessage.self) && (baseMessage as! ImageMessage).image != nil) || (abstractMessage!.isKind(of: BoxVideoMessage.self) && (baseMessage as! VideoMessage).thumbnail != nil) ||
                        (abstractMessage!.isKind(of: BoxFileMessage.self) && (baseMessage as! FileMessage).thumbnail != nil) {
                        let tmpDirectory: String! = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last
                        
                        let attachmentDirectory: String = tmpDirectory + "/PushImages"
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: attachmentDirectory) == false {
                            do {
                                try fileManager.createDirectory(at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true), withIntermediateDirectories: false, attributes: nil)
                            } catch {
                                DDLogWarn("Unable to create direcotry for push images at \(attachmentDirectory): \(error)")
                            }
                        }
                        
                        attachmentName = "PushImage_\(abstractMessage!.messageId.hexEncodedString())"
                        let fileName = "/\(attachmentName!).jpg"
                        let path = attachmentDirectory + fileName
                        var imageData: ImageData? = nil
                        
                        if abstractMessage!.isKind(of: BoxVideoMessage.self) {
                            imageData = (baseMessage as! VideoMessage).thumbnail
                        }
                        else if abstractMessage!.isKind(of: BoxFileMessage.self) {
                            imageData = (baseMessage as! FileMessage).thumbnail
                        }
                        else {
                            imageData = (baseMessage as! ImageMessage).image
                        }
                        do {
                            attachmentUrl = URL(fileURLWithPath: path)
                            if FileManager.default.fileExists(atPath: path) == true {
                                try FileManager.default.removeItem(at: attachmentUrl!)
                            }
                            try imageData!.data.write(to:attachmentUrl! , options: .completeFileProtectionUntilFirstUserAuthentication)
                        }
                        catch {
                            // can't write file, no image preview
                            attachmentName = nil
                            attachmentUrl = nil
                        }
                    }
                } else {
                    body = String(format: NSLocalizedString("new_message_from_x", comment: ""), fromName!)
                }
                cmd = "newmsg"
                categoryIdentifier = "SINGLE"
            }
        }
        else if abstractMessage != nil {
            // abstract message is loaded and we can show the correct contact in the message
            fromName = abstractMessage!.pushFromName
            if fromName == nil || fromName?.count == 0 {
                fromName = abstractMessage!.fromIdentity
            }
            
            if let contact = ContactStore.shared().contact(forIdentity: senderId), !UserSettings.shared().pushShowNickname {
                fromName = contact.displayName
            }
            
            if abstractMessage!.isKind(of: AbstractGroupMessage.self) {
                // group message
                if UserSettings.shared().pushDecrypt {
                    title = NSLocalizedString("new_group_message", comment: "")
                    body = "\(fromName!): \(abstractMessage!.pushNotificationBody()!)"
                } else {
                    body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                }
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            } else {
                // non group message
                if UserSettings.shared().pushDecrypt {          
                    title = fromName
                    body = abstractMessage!.pushNotificationBody()
                } else {
                    body = String(format: NSLocalizedString("new_message_from_x", comment: ""), fromName!)
                }
                cmd = "newmsg"
                categoryIdentifier = "SINGLE"
            }
        }
        else {
            if let nickname = threemaPushNotification?.nickname {
                fromName = nickname
            }
            
            if let senderId = threemaPushNotification?.from {
                if UserSettings.shared().blacklist.contains(senderId) {
                    // User is blocked, do not send push
                    return
                }
                let contact = ContactStore.shared().contact(forIdentity: senderId)
                
                if contact == nil {
                    if UserSettings.shared().blockUnknown == true {
                        // Unknown user, do not send push
                        return
                    }
                }
                
                if contact != nil && !UserSettings.shared().pushShowNickname {
                    fromName = contact!.displayName
                }
                else if fromName == nil || fromName?.count == 0 {
                    fromName = senderId
                }
            }
            
            if let localThreemaPushNotification = threemaPushNotification, localThreemaPushNotification.command == .newGroupMessage {
                // group message
                body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            } else {
                // single message
                body = String(format: NSLocalizedString("new_message_from_x", comment: ""), fromName!)
                cmd = "newmsg"
                categoryIdentifier = "SINGLE"
            }
        }
        
        var silent = false
        if pushSetting != nil {
            silent = pushSetting!.silent
        }
        
        createNotification(title: title, body: body, attachmentName: attachmentName, attachmentUrl: attachmentUrl, cmd: cmd!, categoryIdentifier: categoryIdentifier!, silent: silent, setFireDate: setFireDate, groupId: groupId, fromName: fromName)
    }
    
    /// Remove notification if is there already one
    private func removeNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [key])
    }
    
    private func createNotification(title: String?, body: String?, attachmentName: String?, attachmentUrl: URL?, cmd: String, categoryIdentifier: String, silent: Bool, setFireDate: Bool, groupId: String?, fromName: String?) {
        var pushSound = UserSettings.shared().pushSound
        if categoryIdentifier == "GROUP" {
            pushSound = UserSettings.shared().pushGroupSound
        }
        
        let notification = UNMutableNotificationContent()
        notification.title = title ?? ""
        notification.body = body ?? ""
        
        if categoryIdentifier == "GROUP" {
            if UserSettings.shared().pushGroupSound != "none" && silent == false {
                notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound! + ".caf"))
            }
        } else {
            if UserSettings.shared().pushSound != "none" && silent == false {
                notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound! + ".caf"))
            }
        }
        
        if let attachmentName = attachmentName, let attachmentUrl = attachmentUrl, processed {
            do {
                let attachment = try UNNotificationAttachment(identifier: attachmentName, url: attachmentUrl, options: nil)
                notification.attachments = [attachment]
            }
            catch {
            }
        }
        
        notification.badge = NotificationManager.sharedInstance().unreadMessagesCount(!self.processed)
        
        var trigger: UNTimeIntervalNotificationTrigger? = nil
        if setFireDate == true {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            fireDate = trigger!.nextTriggerDate()
        }
        
        if categoryIdentifier == "GROUP" && groupId != nil {
            notification.userInfo = ["threema": ["cmd": cmd, "from": senderId, "messageId": messageId, "groupId": groupId!]]
        } else {
            notification.userInfo = ["threema": ["cmd": cmd, "from": senderId, "messageId": messageId]]
        }
        
        if categoryIdentifier == "SINGLE" || categoryIdentifier == "GROUP" {
            if UserSettings.shared().pushDecrypt {
                notification.categoryIdentifier = categoryIdentifier
            } else {
                notification.categoryIdentifier = ""
            }
        } else {
            notification.categoryIdentifier = categoryIdentifier
        }
        
        // Group notifictions
        if categoryIdentifier == "SINGLE" {
            notification.threadIdentifier = "SINGLE-\(senderId)"
        } else if categoryIdentifier == "GROUP" {
            if let groupId = groupId {
                notification.threadIdentifier = "GROUP-\(groupId)"
                
                if #available(iOS 12, *) {
                    if let fromName = fromName {
                        notification.summaryArgument = fromName
                    }
                }
            }
        }
        
        let notificationRequest = UNNotificationRequest(identifier: self.key, content: notification, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.add(notificationRequest, withCompletionHandler: { _ in
            ValidationLogger.shared().logString("Push: Added message \(self.messageId) to notification center with trigger \(trigger?.timeInterval ?? 0)s")
        })
    }
    
    private func threemaNewMessageReceived() {
        if (baseMessage != nil) {
            if Thread.isMainThread {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ThreemaNewMessageReceived"), object: baseMessage, userInfo: nil)
            } else {
                DispatchQueue.main.sync {
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ThreemaNewMessageReceived"), object: baseMessage, userInfo: nil)
                }
            }
        }
    }
    
    
    // MARK: NSCoding
    
    public convenience required init?(coder aDecoder: NSCoder) {
        let dSenderId = aDecoder.decodeObject(forKey: "senderId") as! String
        let dMessageId = aDecoder.decodeObject(forKey: "messageId") as! String
        let dAbstractMessage = aDecoder.decodeObject(forKey: "abstractMessage") as? AbstractMessage
        
        let dGenericThreemaDict = aDecoder.decodeObject(forKey: "threemaDict")
        
        if dAbstractMessage != nil {
            if dAbstractMessage!.fromIdentity == nil {
                dAbstractMessage!.fromIdentity = dSenderId
            }
            self.init(receivedAbstractMessage: dAbstractMessage!)
        } else {
            if let dThreemaPush = dGenericThreemaDict as? ThreemaPushNotification {
                self.init(senderIdentity: dSenderId, messageIdentity: dMessageId, threemaPush: dThreemaPush)
            } else if let dThreemaDict = dGenericThreemaDict as? [String: Any] {
                // For backwards compatibility before 4.6.2 we also support reading the old format
                self.init(senderIdentity: dSenderId, messageIdentity: dMessageId, pushPayload: dThreemaDict)
            } else {
                self.init(senderIdentity: dSenderId, messageIdentity: dMessageId)
            }
        }
        
        self.fireDate = aDecoder.decodeObject(forKey: "fireDate") as? Date
        self.processed = aDecoder.decodeBool(forKey: "processed")
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.senderId, forKey: "senderId")
        aCoder.encode(self.messageId, forKey: "messageId")
        aCoder.encode(self.abstractMessage, forKey: "abstractMessage")
        aCoder.encode(self.threemaPushNotification, forKey: "threemaDict")
        aCoder.encode(self.processed, forKey: "processed")
        aCoder.encode(self.fireDate, forKey: "fireDate")
    }
    
}
