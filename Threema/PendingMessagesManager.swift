//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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

@objc class PendingMessagesManager: NSObject {
    
    typealias TimeOfDay = (hour: Int, minute: Int)
    
    @objc static let shared = PendingMessagesManager()
    
    private var pendingMessages: [String: PendingMessage]
    private var doneMessages: NSMutableOrderedSet
    
    @objc private override init() {
        pendingMessages = [String: PendingMessage]()
        doneMessages = NSMutableOrderedSet()
    }
    
    
    // MARK: Public functions
    
    @objc func setup() {
        loadPendingMessages()
        loadDoneMessages()
    }
    
    @objc func pendingMessage(senderId: String?, messageId: String?, abstractMessage: AbstractMessage?, threemaDict: [String: Any]?, completion: @escaping (_ pendingMessage: PendingMessage?) -> Void) {
        
        var evalKey: String?
        if let abstractMessage = abstractMessage,
            let fromIdentity = abstractMessage.fromIdentity,
            let messageId = abstractMessage.messageId {
            
            evalKey = fromIdentity + messageId.hexEncodedString()
        }
        else if let senderId = senderId,
            let messageId = messageId {
            
            evalKey = senderId + messageId
        }
        
        guard let key = evalKey, let senderIdentity = senderId ?? abstractMessage?.fromIdentity else {
            DDLogWarn("PendingMessagesManager.pendingMessage: Some arguments invalid, no key or sender identity could be evaluated")
            completion(nil)
            return
        }
        
        self.checkPendingMessages()
        
        var pendingMessage = pendingMessages[key]
        if let pendingMessage = pendingMessage {
            // check is notification is fired
            pendingMessage.isPendingNotification { pending in
                if pending == false {
                    // not in notificationcenter or triggered
                    if pendingMessage.isMessageAlreadyPushed() {
                        // move message to done message
                        self.pendingMessageIsDone(pendingMessage: pendingMessage, cancelTask: true)
                        completion(nil)
                        return
                    } else {
                        // check is fire date over
                        var alreadyFired = false
                        if let fireDate = pendingMessage.fireDate, fireDate < Date() {
                            // push was already fired
                            alreadyFired = true
                            self.pendingMessageIsDone(pendingMessage: pendingMessage, cancelTask: true)
                            completion(nil)
                            return
                        }
                        if alreadyFired == false {
                            if let abstractMessage = abstractMessage {
                                pendingMessage.addAbstractMessage(message: abstractMessage)
                            }
                        }
                        
                        completion(pendingMessage)
                        return
                    }
                } else {
                    if let abstractMessage = abstractMessage {
                        pendingMessage.addAbstractMessage(message: abstractMessage)
                    }
                    completion(pendingMessage)
                    return
                }
            }
        } else {
            if doneMessages.contains(key) {
                // message is already done
                completion(nil)
                return
            } else {
                // create one
                if let abstractMessage = abstractMessage {
                    pendingMessage = PendingMessage(receivedAbstractMessage: abstractMessage)
                } else {
                    if let threemaDict = threemaDict {
                        pendingMessage = PendingMessage(senderIdentity: senderIdentity, messageIdentity: messageId!, pushPayload: threemaDict)
                    } else {
                        pendingMessage = PendingMessage(senderIdentity: senderIdentity, messageIdentity: messageId!)
                    }
                }
                
                pendingMessages.updateValue(pendingMessage!, forKey: pendingMessage!.key)
                pendingMessage?.startInitialTimedNotification()
                completion(pendingMessages[key])
                return
            }
        }
    }
    
    func pendingMessageIsDone(pendingMessage: PendingMessage, cancelTask: Bool) {
        if doneMessages.count >= 300 {
            let range: NSRange = NSRange(location: 0, length: doneMessages.count - 299)
            doneMessages.removeObjects(in: range)
        }
        doneMessages.add(pendingMessage.key)
        pendingMessages.removeValue(forKey: pendingMessage.key)
        
        if pendingMessages.count == 0 {
            BackgroundTaskManager.shared.cancelBackgroundTask(key: kAppPushBackgroundTask)
        }
    }
    
    @objc func save() {
        if Thread.isMainThread {
            saveAll()
        } else {
            DispatchQueue.main.sync {
                saveAll()
            }
        }
    }
    
    @objc class func canMasterDndSendPush() -> Bool {
        if LicenseStore.requiresLicenseKey() {
            if UserSettings.shared().enableMasterDnd {
                let calendar = Calendar.current
                let currentDate = Date()
                let currentWeekDay = calendar.component(.weekday, from: currentDate)
                let selectedWorkingDays = UserSettings.shared().masterDndWorkingDays
                if selectedWorkingDays!.contains(currentWeekDay) {
                    let currentTime = TimeOfDay(hour: calendar.component(.hour, from: currentDate), minute:calendar.component(.minute, from: currentDate))
                    let startTime = timeOfDayFromTimeString(timeString: UserSettings.shared().masterDndStartTime)
                    let endTime = timeOfDayFromTimeString(timeString: UserSettings.shared().masterDndEndTime)
                    
                    if currentTime >= startTime && currentTime <= endTime {
                        return true
                    }
                    
                }
                return false
            }
        }
        
        return true
    }
    
    
    // MARK: Private functions
    
    /// Mark all handled pending messages as done
    private func checkPendingMessages() {
        for (_, pendingMessage) in pendingMessages {
            if pendingMessage.isMessageAlreadyPushed() == true {
                pendingMessageIsDone(pendingMessage: pendingMessage, cancelTask: false)
            } else {
                if let fireDate = pendingMessage.fireDate {
                    if fireDate < Date() {
                        pendingMessageIsDone(pendingMessage: pendingMessage, cancelTask: false)
                    }
                }
            }
        }
    }
    
    private func saveAll() {
        let savePathPendingMessages = self.savePathPendingMessages()
        do {
            if FileManager.default.fileExists(atPath: savePathPendingMessages) {
                try FileManager.default.removeItem(atPath: savePathPendingMessages)
            }
        } catch {
            DDLogError("Unable to delete pending messages file: \(error.localizedDescription)")
        }
        
        if self.pendingMessages.count > 0 {
            NSKeyedArchiver.archiveRootObject(self.pendingMessages, toFile: savePathPendingMessages)
        }
        
        let savePathDoneMessages = self.savePathDoneMessages()
        do {
            if FileManager.default.fileExists(atPath: savePathDoneMessages) {
                try FileManager.default.removeItem(atPath: savePathDoneMessages)
            }
        } catch {
            DDLogError("Unable to delete done messages file: \(error.localizedDescription)")
        }
        
        if self.doneMessages.count > 0 {
            NSKeyedArchiver.archiveRootObject(self.doneMessages, toFile: savePathDoneMessages)
        }
    }
    
    private func loadPendingMessages() {
        DispatchQueue.main.async {
            let savePath = self.savePathPendingMessages()
            if FileManager.default.fileExists(atPath: savePath) {
                if let savedPendingMessages = NSKeyedUnarchiver.unarchiveObject(withFile: savePath) as? [String: PendingMessage] {
                    for pendingMessage in savedPendingMessages {
                        if (pendingMessage.value.fireDate == nil) {
                            continue
                        }
                        self.pendingMessages[pendingMessage.key] = pendingMessage.value
                    }
                }
                do {
                    try FileManager.default.removeItem(atPath: savePath)
                } catch {
                    DDLogError("Unable to delete pending messages file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadDoneMessages() {
        DispatchQueue.main.async {
            let savePath = self.savePathDoneMessages()
            if FileManager.default.fileExists(atPath: savePath) {
                let savedDoneMessages = NSKeyedUnarchiver.unarchiveObject(withFile: savePath)
                
                if let savedDoneMessagesDict = savedDoneMessages as? [String: PendingMessage] {
                    for doneMessage in savedDoneMessagesDict {
                        self.doneMessages.add(doneMessage.key)
                    }
                }
                else if let savedDoneMessagesSet = savedDoneMessages as? NSMutableOrderedSet {
                    self.doneMessages.addObjects(from: savedDoneMessagesSet.array)
                }
                do {
                    try FileManager.default.removeItem(atPath: savePath)
                } catch {
                    DDLogError("Unable to delete done messages file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func savePathPendingMessages() -> String {
        let documentDir = DocumentManager.documentsDirectory()
        return documentDir!.appendingPathComponent("PendingMessages").path
    }
    
    private func savePathDoneMessages() -> String {
        let documentDir = DocumentManager.documentsDirectory()
        return documentDir!.appendingPathComponent("DoneMessages").path
    }
    
    private class func timeOfDayFromTimeString(timeString: String) -> TimeOfDay {
        let components: [String] = timeString.components(separatedBy: ":")
        return TimeOfDay(hour: Int(components[0])!, minute: Int(components[1])!)
    }
}

