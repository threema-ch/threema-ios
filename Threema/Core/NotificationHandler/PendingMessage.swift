//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

@objc class PendingMessage: NSObject, NSCoding {
    
    @objc var completionHandler: (() -> Void)?
    
    var senderID: String
    var messageID: String
    @objc var key: String
    var threemaPushNotification: ThreemaPushNotification?
    var fireDate: Date?
    @objc var isPendingGroupMessages = false
    
    private var abstractMessage: AbstractMessage?
    private var baseMessage: BaseMessage?
    private var processed: Bool
    private var removeAll = false
    
    private static let removalQueue = DispatchQueue(label: "NotificationRemovalQueue", qos: .userInteractive)
    private static let addQueue = DispatchQueue(label: "NotificationAddQueue", qos: .userInteractive)
    
    enum NotificationStage: String, CaseIterable {
        case initial
        case abstract
        case base
        case final
    }
    
    private var currRemove: Set<String> = Set()
    
    // MARK: Public Functions
    
    @objc init(senderIdentity: String, messageIdentity: String) {
        self.senderID = senderIdentity
        self.messageID = messageIdentity
        self.key = senderIdentity + messageIdentity
        self.processed = false
    }
    
    @objc convenience init(senderIdentity: String, messageIdentity: String, pushPayload: [String: Any]) {
        let threemaPush = try? ThreemaPushNotification(from: pushPayload)
        self.init(senderIdentity: senderIdentity, messageIdentity: messageIdentity, threemaPush: threemaPush)
    }
    
    // Initalizer for `NSCoding`
    private init(senderIdentity: String, messageIdentity: String, threemaPush: ThreemaPushNotification?) {
        self.senderID = senderIdentity
        self.messageID = messageIdentity
        self.key = senderIdentity + messageIdentity
        self.processed = false
        self.threemaPushNotification = threemaPush
    }
    
    @objc init(receivedAbstractMessage: AbstractMessage) {
        self.abstractMessage = receivedAbstractMessage
        self.senderID = receivedAbstractMessage.fromIdentity
        self.messageID = receivedAbstractMessage.messageID.hexEncodedString()
        self.key = senderID + messageID
        self.processed = false
    }
    
    func isPendingNotification() -> Bool {
        var isPending = false
        let dispatch = DispatchSemaphore(value: 0)

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pendingNotifications in
            for pendingNotification in pendingNotifications {
                if pendingNotification.identifier == self.key {
                    isPending = true
                    break
                }
            }
            
            dispatch.signal()
        }
        
        dispatch.wait()
        return isPending
    }
        
    func isMessageAlreadyPushed() -> Bool {
        processed
    }
    
    // First roundtrip when a new message is received
    func startInitialTimedNotification() {
        DDLogNotice("Push: start initial timed notification for message \(messageID)")
        startTimedNotification(setFireDate: true, stage: .initial)
    }
    
    // Second roundtrip when a new message is received
    @objc func addAbstractMessage(message: AbstractMessage) {
        DDLogNotice("Push: add abstract message for message \(messageID)")
        abstractMessage = message
        PendingMessage.removalQueue.sync {
            self.removeNotifications(stages: [.initial])
        }
        startTimedNotification(setFireDate: true, stage: .abstract)
    }
    
    private func removeAllMyNotifications() {
        PendingMessage.removalQueue.sync {
            self.removeAll = true
            self.removeNotifications(stages: [.initial, .abstract, .base, .final])
            self.removeNotifications()
        }
    }
    
    // Third roundtrip when a new message is received
    @objc func addBaseMessage(message: BaseMessage) {
        DDLogNotice("Push: add basemessage for message \(messageID)")
        baseMessage = message
        PendingMessage.removalQueue.sync {
            self.removeNotifications(stages: [.initial, .abstract])
        }
        startTimedNotification(setFireDate: true, stage: .base)
    }
    
    @objc func finishedProcessing() {
        finishedProcessing(rejected: false)
    }
    
    // Final roundtrip when a new message is recieved
    @objc func finishedProcessing(rejected: Bool = false) {
        PendingMessage.removalQueue.sync {
            self.removeNotifications(stages: [.initial, .abstract, .base])
        }
        
        DDLogNotice("Push: finished processing for message \(messageID)")
        if isPendingGroupMessages == true {
            removeAllMyNotifications()
            completionHandler?()
            
            return
        }
        
        guard processed == false else {
            removeAllMyNotifications()
            return
        }
        
        processed = true
        
        if rejected {
            removeAllMyNotifications()
        }
        else {
            startTimedNotification(setFireDate: false, stage: .final)
            
            if let currentBaseMessage = baseMessage {
                // Broadcast a notification, just in case we're currently in another chat within the app
                if AppDelegate.shared().isAppInBackground() == false,
                   abstractMessage!.receivedAfterInitialQueueSend == true {
                    if PendingMessagesManager.canMasterDndSendPush() == true {
                        let pushSetting = PushSetting(for: currentBaseMessage.conversation)
                        if pushSetting.canSendPush(for: currentBaseMessage) {
                            threemaNewMessageReceived()
                            if !pushSetting.silent {
                                NotificationManager.sharedInstance().playReceivedMessageSound()
                            }
                        }
                        NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                    }
                }
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
        center.add(notificationRequest) { error in
            if let err = error {
                ValidationLogger.shared()?.logString("Error while adding test push notification: \(err)")
            }
            completion()
        }
    }
    
    // MARK: Private Functions
    
    private func startTimedNotification(setFireDate: Bool, stage: NotificationStage) {
        if PendingMessagesManager.canMasterDndSendPush() == false {
            NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
            removeAllMyNotifications()
            return
        }
        
        var pushSetting: PushSetting?
        
        // Check if we should even send any push notification
        
        if let currentBaseMessage = baseMessage {
            pushSetting = PushSetting(for: currentBaseMessage.conversation)
            
            // `pushSetting` will always be not `nil`
            if !pushSetting!.canSendPush(for: currentBaseMessage) {
                NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                if AppDelegate.shared().isAppInBackground() == false,
                   abstractMessage?.receivedAfterInitialQueueSend == true, processed == true {
                    threemaNewMessageReceived()
                }
                removeAllMyNotifications()
                return
            }
        }
        else {
            // Only non-group messages
            if let localThreemaPushNotification = threemaPushNotification,
               localThreemaPushNotification.command == .newMessage {
                pushSetting = PushSetting(forThreemaID: senderID)
                
                // `pushSetting` will always be not `nil`
                if !pushSetting!.canSendPush() {
                    NotificationManager.sharedInstance().updateUnreadMessagesCount(false)
                    if AppDelegate.shared().isAppInBackground() == false,
                       abstractMessage?.receivedAfterInitialQueueSend == true, processed == true {
                        threemaNewMessageReceived()
                    }
                    removeAllMyNotifications()
                    return
                }
            }
        }
        
        if let localAbstractMessage = abstractMessage,
           localAbstractMessage
           .shouldPush() == false ||
           (localAbstractMessage.shouldPush() == true && localAbstractMessage.isVoIP() == true) {
            // dont show notification for this message
            removeAllMyNotifications()
            return
        }
        
        // Don't scheudle messages for incoming voip calls
        if let localThreemaPushNotification = threemaPushNotification, localThreemaPushNotification.voip == true {
            DDLogDebug("Did not scheudle message for incoming voip call")
            removeAllMyNotifications()
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
        var attachmentURL: URL?
        var cmd: String?
        var categoryIdentifier: String?
        var groupID: String?
        
        if abstractMessage != nil, baseMessage != nil {
            // all data (maybe not the image) is loaded and we can show the correct message
            fromName = abstractMessage!.pushFromName
            if fromName == nil || fromName?.isEmpty == true {
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
                    
                    if (
                        abstractMessage!.isKind(of: GroupImageMessage.self) && (baseMessage as! ImageMessage)
                            .image != nil
                    ) ||
                        (
                            abstractMessage!.isKind(of: GroupVideoMessage.self) && (baseMessage as! VideoMessage)
                                .thumbnail != nil
                        ) ||
                        (
                            abstractMessage!.isKind(of: GroupFileMessage.self) && (baseMessage as! FileMessage)
                                .thumbnail != nil
                        ) {
                        let tmpDirectory: String! = NSSearchPathForDirectoriesInDomains(
                            .cachesDirectory,
                            .userDomainMask,
                            true
                        ).last
                        
                        let attachmentDirectory: String = tmpDirectory + "/PushImages"
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: attachmentDirectory) == false {
                            do {
                                try fileManager.createDirectory(
                                    at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true),
                                    withIntermediateDirectories: false,
                                    attributes: nil
                                )
                            }
                            catch {
                                DDLogWarn(
                                    "Unable to create direcotry for push images at \(attachmentDirectory): \(error)"
                                )
                            }
                        }
                        attachmentName = "PushImage_\(abstractMessage!.messageID.hexEncodedString())"
                        let fileName = "/\(attachmentName!).jpg"
                        let path = attachmentDirectory + fileName
                        var imageData: ImageData?
                        
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
                            attachmentURL = URL(fileURLWithPath: path)
                            if let imageData, let imageDataData = imageData.data {
                                try imageDataData.write(
                                    to: attachmentURL!,
                                    options: .completeFileProtectionUntilFirstUserAuthentication
                                )
                            }
                        }
                        catch {
                            // can't write file, no image preview
                            attachmentName = nil
                            attachmentURL = nil
                        }
                    }
                }
                else {
                    body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                }
                // add groupid if message is loaded to open the correct chat after tapping notification
                groupID = baseMessage!.conversation.groupID
                    .base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
                
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            }
            else {
                // non group message
                if !UserSettings.shared().pushShowNickname {
                    fromName = baseMessage!.conversation.contact.displayName
                }
                
                if UserSettings.shared().pushDecrypt {
                    title = fromName
                    body = TextStyleUtils.makeMentionsString(forText: baseMessage!.previewText())
                    
                    if (
                        abstractMessage!.isKind(of: BoxImageMessage.self) && (baseMessage as! ImageMessage)
                            .image != nil
                    ) ||
                        (
                            abstractMessage!.isKind(of: BoxVideoMessage.self) && (baseMessage as! VideoMessage)
                                .thumbnail != nil
                        ) ||
                        (
                            abstractMessage!.isKind(of: BoxFileMessage.self) && (baseMessage as! FileMessage)
                                .thumbnail != nil
                        ) {
                        let tmpDirectory: String! = NSSearchPathForDirectoriesInDomains(
                            .cachesDirectory,
                            .userDomainMask,
                            true
                        ).last
                        
                        let attachmentDirectory: String = tmpDirectory + "/PushImages"
                        let fileManager = FileManager.default
                        if fileManager.fileExists(atPath: attachmentDirectory) == false {
                            do {
                                try fileManager.createDirectory(
                                    at: URL(fileURLWithPath: attachmentDirectory, isDirectory: true),
                                    withIntermediateDirectories: false,
                                    attributes: nil
                                )
                            }
                            catch {
                                DDLogWarn(
                                    "Unable to create direcotry for push images at \(attachmentDirectory): \(error)"
                                )
                            }
                        }
                        
                        attachmentName = "PushImage_\(abstractMessage!.messageID.hexEncodedString())"
                        let fileName = "/\(attachmentName!).jpg"
                        let path = attachmentDirectory + fileName
                        var imageData: ImageData?
                        
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
                            attachmentURL = URL(fileURLWithPath: path)
                            if FileManager.default.fileExists(atPath: path) == true {
                                try FileManager.default.removeItem(at: attachmentURL!)
                            }
                            if let imageData, let imageDataData = imageData.data {
                                try imageDataData.write(
                                    to: attachmentURL!,
                                    options: .completeFileProtectionUntilFirstUserAuthentication
                                )
                            }
                        }
                        catch {
                            // can't write file, no image preview
                            attachmentName = nil
                            attachmentURL = nil
                        }
                    }
                }
                else {
                    body = String(format: NSLocalizedString("new_message_from_x", comment: ""), fromName!)
                }
                cmd = "newmsg"
                categoryIdentifier = "SINGLE"
            }
        }
        else if abstractMessage != nil {
            // abstract message is loaded and we can show the correct contact in the message
            fromName = abstractMessage!.pushFromName
            if fromName == nil || fromName?.isEmpty == true {
                fromName = abstractMessage!.fromIdentity
            }
            
            if let contact = ContactStore.shared().contact(for: senderID), !UserSettings.shared().pushShowNickname {
                fromName = contact.displayName
            }
            
            if abstractMessage!.isKind(of: AbstractGroupMessage.self) {
                // group message
                if UserSettings.shared().pushDecrypt {
                    title = NSLocalizedString("new_group_message", comment: "")
                    body = "\(fromName!): \(abstractMessage!.pushNotificationBody()!)"
                }
                else {
                    body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                }
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            }
            else {
                // non group message
                if UserSettings.shared().pushDecrypt {
                    title = fromName
                    body = abstractMessage!.pushNotificationBody()
                }
                else {
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
            
            if let senderID = threemaPushNotification?.from {
                if UserSettings.shared().blacklist.contains(senderID) {
                    // User is blocked, do not send push
                    return
                }
                let contact = ContactStore.shared().contact(for: senderID)
                
                if contact == nil {
                    if UserSettings.shared().blockUnknown == true {
                        // Unknown user, do not send push
                        return
                    }
                }
                
                if contact != nil && !UserSettings.shared().pushShowNickname {
                    fromName = contact!.displayName
                }
                else if fromName == nil || fromName?.isEmpty == true {
                    fromName = senderID
                }
            }
            
            if let localThreemaPushNotification = threemaPushNotification,
               localThreemaPushNotification.command == .newGroupMessage {
                // group message
                body = String(format: NSLocalizedString("new_group_message_from_x", comment: ""), fromName!)
                cmd = "newgroupmsg"
                categoryIdentifier = "GROUP"
            }
            else {
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
        DispatchQueue.main.async {
            self.createNotification(
                title: title,
                body: body,
                attachmentName: attachmentName,
                attachmentURL: attachmentURL,
                cmd: cmd!,
                categoryIdentifier: categoryIdentifier!,
                silent: silent,
                setFireDate: setFireDate,
                groupID: groupID,
                fromName: fromName,
                stage: stage
            )
        }
    }
    
    /// Remove notification if is there already one
    /// This function must be called on the removalQueue
    private func removeNotifications(stages: [NotificationStage]? = nil, except: String? = nil) {
        if let stages {
            ValidationLogger.shared()?.logString("Push: Adding stages as removable \(stages)")
            for stage in stages {
                let currKey = key.appending("-\(stage)")
                currRemove.insert(currKey)
            }
        }
        else {
            var currRemoveArr = [String](currRemove)
            if except != nil, !removeAll {
                currRemoveArr.removeAll(where: { $0 == except })
            }
            
            DispatchQueue.main.async {
                ValidationLogger.shared()?
                    .logString("Push: Remove notifications with key \(self.currRemove) for message \(self.messageID)")
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: currRemoveArr)
            }
        }
    }
    
    private func createNotification(
        title: String?,
        body: String?,
        attachmentName: String?,
        attachmentURL: URL?,
        cmd: String,
        categoryIdentifier: String,
        silent: Bool,
        setFireDate: Bool,
        groupID: String?,
        fromName: String?,
        stage: NotificationStage
    ) {
        var pushSound = UserSettings.shared().pushSound
        if categoryIdentifier == "GROUP" {
            pushSound = UserSettings.shared().pushGroupSound
        }
        
        let notification = UNMutableNotificationContent()
        notification.title = title ?? ""
        notification.body = body ?? ""
        
        if categoryIdentifier == "GROUP" {
            if UserSettings.shared().pushGroupSound != "none", silent == false {
                notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound! + ".caf"))
            }
        }
        else {
            if UserSettings.shared().pushSound != "none", silent == false {
                notification.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: pushSound! + ".caf"))
            }
        }
        
        if stage == .final, let attachmentName, let attachmentURL, processed {
            do {
                let attachment = try UNNotificationAttachment(
                    identifier: attachmentName,
                    url: attachmentURL,
                    options: nil
                )
                notification.attachments = [attachment]
            }
            catch { }
        }
        
        let unreadDict = NotificationManager.sharedInstance().unreadMessagesCount(!processed && !isPendingGroupMessages)
        let badgeCount = unreadDict!["badgeCount"] as? NSNumber ?? 0
        let markedCount = unreadDict!["markedCount"] as? NSNumber ?? 0
        notification.badge = NSNumber(value: badgeCount.intValue + markedCount.intValue)
        
        var trigger: UNTimeIntervalNotificationTrigger?
        if setFireDate == true {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            fireDate = trigger!.nextTriggerDate()
        }
        
        if categoryIdentifier == "GROUP" && groupID != nil {
            notification
                .userInfo = ["threema": ["cmd": cmd, "from": senderID, "messageId": messageID, "groupId": groupID!]]
        }
        else {
            notification.userInfo = ["threema": ["cmd": cmd, "from": senderID, "messageId": messageID]]
        }
        
        if categoryIdentifier == "SINGLE" || categoryIdentifier == "GROUP" {
            if UserSettings.shared().pushDecrypt {
                notification.categoryIdentifier = categoryIdentifier
            }
            else {
                notification.categoryIdentifier = ""
            }
        }
        else {
            notification.categoryIdentifier = categoryIdentifier
        }
        
        // Group notifictions
        if categoryIdentifier == "SINGLE" {
            notification.threadIdentifier = "SINGLE-\(senderID)"
        }
        else if categoryIdentifier == "GROUP" {
            if let groupID {
                notification.threadIdentifier = "GROUP-\(groupID)"
                
                if #available(iOS 12, *) {
                    if let fromName {
                        notification.summaryArgument = fromName
                    }
                }
            }
        }
        
        let currKey = key.appending("-\(stage)")
        let notificationRequest = UNNotificationRequest(identifier: currKey, content: notification, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.add(notificationRequest, withCompletionHandler: { error in
            if let error {
                DDLogNotice(
                    "Push: Adding notification for message \(self.messageID) was not successful. Error: \(error.localizedDescription)"
                )
            }
            else {
                DDLogNotice(
                    "Push: Added message \(self.messageID) to notification center with trigger \(trigger?.timeInterval ?? 0)s and identifier \(notificationRequest.identifier)"
                )
                PendingMessage.removalQueue.sync {
                    self.removeNotifications(except: notificationRequest.identifier)
                }
            }
        })
    }
    
    private func threemaNewMessageReceived() {
        if baseMessage != nil {
            if Thread.isMainThread {
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: "ThreemaNewMessageReceived"),
                    object: baseMessage,
                    userInfo: nil
                )
            }
            else {
                DispatchQueue.main.sync {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: "ThreemaNewMessageReceived"),
                        object: baseMessage,
                        userInfo: nil
                    )
                }
            }
        }
    }
    
    // MARK: NSCoding
    
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let dSenderID = aDecoder.decodeObject(forKey: "senderId") as? String else {
            return nil
        }
        guard let dMessageID = aDecoder.decodeObject(forKey: "messageId") as? String else {
            return nil
        }
        let dGenericThreemaDict = aDecoder.decodeObject(forKey: "threemaDict")
        
        if let dAbstractMessage = aDecoder.decodeObject(forKey: "abstractMessage") as? AbstractMessage,
           // We cannot initialize with an abstract message that has a nil messageID
           dAbstractMessage.messageID != nil {
            
            if dAbstractMessage.fromIdentity == nil {
                dAbstractMessage.fromIdentity = dSenderID
            }
            
            self.init(receivedAbstractMessage: dAbstractMessage)
        }
        else {
            if let dThreemaPush = dGenericThreemaDict as? ThreemaPushNotification {
                self.init(senderIdentity: dSenderID, messageIdentity: dMessageID, threemaPush: dThreemaPush)
            }
            else if let dThreemaDict = dGenericThreemaDict as? [String: Any] {
                // For backwards compatibility before 4.6.2 we also support reading the old format
                self.init(senderIdentity: dSenderID, messageIdentity: dMessageID, pushPayload: dThreemaDict)
            }
            else {
                self.init(senderIdentity: dSenderID, messageIdentity: dMessageID)
            }
        }
        
        self.fireDate = aDecoder.decodeObject(forKey: "fireDate") as? Date
        self.processed = aDecoder.decodeBool(forKey: "processed")
        self.removeAll = aDecoder.decodeBool(forKey: "removeAll")
        if let c = aDecoder.decodeObject(forKey: "currRemove") as? Set<String> {
            self.currRemove = c
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(senderID, forKey: "senderId")
        aCoder.encode(messageID, forKey: "messageId")
        aCoder.encode(abstractMessage, forKey: "abstractMessage")
        aCoder.encode(threemaPushNotification, forKey: "threemaDict")
        aCoder.encode(processed, forKey: "processed")
        aCoder.encode(fireDate, forKey: "fireDate")
        aCoder.encode(removeAll, forKey: "removeAll")
        aCoder.encode(currRemove, forKey: "currRemove")
    }
}
