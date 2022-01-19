//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2022 Threema GmbH
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

@objc class WCSessionManager: NSObject {
    
    @objc static let shared = WCSessionManager()
    
    private var sessions: [Data: WCSession] = [Data: WCSession]()
    private(set) var running: [Data] = [Data]()
    private var runningSessionsQueue:DispatchQueue = DispatchQueue(label: "ch.threema.runningSessionsQueue", attributes: [])
    private var observerAlreadySet: Bool = false
    
    private override init() {
        super.init()
        loadSessionsFromArchive()
    }
    
    public class func isWebHostAllowed(scannedHostName: String, whiteList: String) -> Bool {
        if whiteList.count == 0 {
            return false
        }
        let arr = whiteList.components(separatedBy: ",")
        for host in arr {
            let pattern = host.trimmingCharacters(in: .whitespaces)
            if pattern == scannedHostName {
                return true
            }
            let slicedPattern = String(pattern.dropFirst())
            if pattern.hasPrefix("*") && scannedHostName.hasSuffix(slicedPattern) {
                return true;
            }
        }
        return false
    }
}

// MARK: Private functions
extension WCSessionManager {
    
    /**
     Add observers
     * batteryLevelDidChange
     * batteryStateDidChange
     * profileNicknameChanged
     * profilePictureChanged
     * blackListChanged
     */
    private func addObservers() {
        if observerAlreadySet == false {
            UIDevice.current.isBatteryMonitoringEnabled = true
            NotificationCenter.default.addObserver(self, selector: #selector(self.batteryLevelDidChange), name: UIDevice.batteryLevelDidChangeNotification , object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.profileNicknameChanged), name: NSNotification.Name(rawValue: kNotificationProfileNicknameChanged), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.profilePictureChanged), name: NSNotification.Name(rawValue: kNotificationProfilePictureChanged), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.blackListChanged), name: NSNotification.Name(rawValue: kNotificationBlockedContact), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.managedObjectContextDidChange), name: .NSManagedObjectContextObjectsDidChange, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.refreshDirtyObjects), name: NSNotification.Name(rawValue: kNotificationDBRefreshedDirtyObject), object: nil)
            observerAlreadySet = true
        }
    }
    
    private func removeObservers() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self)
        
        observerAlreadySet = false
    }
    
    private func allSessionsSavePath() -> String {
        let documentDir = DocumentManager.documentsDirectory()
        return documentDir!.appendingPathComponent("AllWCSessions").path
    }
    
    private func runningSessionsSavePath() -> String {
        let documentDir = DocumentManager.documentsDirectory()
        return documentDir!.appendingPathComponent("RunningWCSessions").path
    }
}

// MARK: Public functions
extension WCSessionManager {
    @objc public func saveSessionsToArchive() {
        let allSessionsSavePath = self.allSessionsSavePath()
        let runningSessionsSavePath = self.runningSessionsSavePath()
        do {
            try FileManager.default.removeItem(atPath: allSessionsSavePath)
        } catch { }
        NSKeyedArchiver.archiveRootObject(self.sessions, toFile: allSessionsSavePath)
        
        do {
            try FileManager.default.removeItem(atPath: runningSessionsSavePath)
        } catch { }
        NSKeyedArchiver.archiveRootObject(self.running, toFile: runningSessionsSavePath)
    }
    
    private func loadSessionsFromArchive() {
        let allSessionsSavePath = self.allSessionsSavePath()
        let runningSessionsSavePath = self.runningSessionsSavePath()
        
        if FileManager.default.fileExists(atPath: allSessionsSavePath) {
            if let allSessions = NSKeyedUnarchiver.unarchiveObject(withFile: allSessionsSavePath) as? [Data: WCSession] {
                self.sessions = allSessions
                do {
                    try FileManager.default.removeItem(atPath: allSessionsSavePath)
                } catch {
                    
                }
            }
        }
        
        if FileManager.default.fileExists(atPath: runningSessionsSavePath) {
            if let runningSessions = NSKeyedUnarchiver.unarchiveObject(withFile: runningSessionsSavePath) as? [Data] {
                self.running = runningSessions
                do {
                    try FileManager.default.removeItem(atPath: runningSessionsSavePath)
                } catch {
                    
                }
            }
        }
    }
    
    /**
     Connect a old or new session. Search for correct session or create a new one
     */
    @objc public func connect(authToken: Data?, wca: String?, publicKeyHash: String) {
        canConnectToWebClient(completionHandler: { (isValid) in
            if isValid == true {
                if let webClientSession = WebClientSessionStore.shared.webClientSessionForHash(publicKeyHash) {
                    var session: WCSession? = self.sessions[webClientSession.initiatorPermanentPublicKey!]
                    
                    if LicenseStore.requiresLicenseKey() == true {
                        let mdmSetup = MDMSetup(setup: false)!
                        if let webHosts = mdmSetup.webHosts() {
                            if WCSessionManager.isWebHostAllowed(scannedHostName: webClientSession.saltyRTCHost!, whiteList: webHosts) == false {
                                ValidationLogger.shared().logString("Threema Web: Scanned qr code host is not white listed")
                                if AppDelegate.shared().isAppInBackground() {
                                    Utils.sendErrorLocalNotification(NSLocalizedString("webClient_scan_error_mdm_host_title", comment: ""), body: NSLocalizedString("webClient_scan_error_mdm_host_message", comment: ""), userInfo: nil)
                                } else {
                                    let rootVC = UIApplication.shared.keyWindow?.rootViewController
                                    UIAlertTemplate.showAlert(owner: rootVC!, title: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_title"), message: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_message"))
                                }
                                return
                                

                            }
                        }
                    }
                    
                    if session != nil && wca != nil {
                        if let connectionWca = session?.connectionWca() {
                            if wca!.elementsEqual(connectionWca) {
                                // same wca, ignore this request
                                ValidationLogger.shared()?.logString("Threema Web: Ignore connect, because it's the same wca")
                                return
                            }
                        }
                    }
                    
                    if session == nil {
                        session = WCSession.init(webClientSession: webClientSession)
                        self.sessions[webClientSession.initiatorPermanentPublicKey!] = session
                    }
                    if wca != nil {
                        session!.setWcaForConnection(wca: wca!)
                    }
                    self.addWCSessionToRunning(webClientSession: webClientSession)
                    self.addObservers()
                    ServerConnector.shared().sendPushOverrideTimeout()
                    session!.connect(authToken: authToken)
                } else {
                    // session not found
                }
            }
        })
    }
    
    @objc public func connect(authToken: Data?, wca: String?, webClientSession: WebClientSession) {
        canConnectToWebClient(completionHandler: { (isValid) in
            if isValid == true {
                var session: WCSession? = self.sessions[webClientSession.initiatorPermanentPublicKey!]
                
                if session != nil && wca != nil {
                    if let connectionWca = session?.connectionWca() {
                        if wca!.elementsEqual(connectionWca) {
                            // same wca, ignore this request
                            ValidationLogger.shared()?.logString("Threema Web: Ignore connect, because it's the same wca")
                            return
                        }
                    }
                }
                if session == nil {
                    session = WCSession.init(webClientSession: webClientSession)
                    self.sessions[webClientSession.initiatorPermanentPublicKey!] = session
                }
                
                if LicenseStore.requiresLicenseKey() == true {
                    let mdmSetup = MDMSetup(setup: false)!
                    if let webHosts = mdmSetup.webHosts() {
                        if WCSessionManager.isWebHostAllowed(scannedHostName: webClientSession.saltyRTCHost!, whiteList: webHosts) == false {
                            ValidationLogger.shared().logString("Threema Web: Scanned qr code host is not white listed")
                            if AppDelegate.shared().isAppInBackground() {
                                Utils.sendErrorLocalNotification(NSLocalizedString("webClient_scan_error_mdm_host_title", comment: ""), body: NSLocalizedString("webClient_scan_error_mdm_host_message", comment: ""), userInfo: nil)
                            } else {
                                let rootVC = UIApplication.shared.keyWindow?.rootViewController
                                UIAlertTemplate.showAlert(owner: rootVC!, title: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_title"), message: BundleUtil.localizedString(forKey: "webClient_scan_error_mdm_host_message"))
                            }
                            return
                        }
                    }
                }

                if wca != nil {
                    session!.setWcaForConnection(wca: wca!)
                }
                self.addWCSessionToRunning(webClientSession: webClientSession)
                self.addObservers()
                ServerConnector.shared().sendPushOverrideTimeout()
                session!.connect(authToken: authToken)
            }
        })
    }
    
    @objc public func connectAllRunningSessions() {
        if running.count == 0 {
            ValidationLogger.shared()?.logString("Threema Web: There is no active session")
            WebClientSessionStore.shared.setAllWebClientSessionsInactive()
            return
        }
        addObservers()
        ServerConnector.shared().sendPushOverrideTimeout()
        ValidationLogger.shared()?.logString("Threema Web: Connect active sessions (\(running.count))")
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.connectionStatus() == .disconnected {
                    ValidationLogger.shared()?.logString("Threema Web: Connect active session")
                    session.connect(authToken: nil)
                } else {
                    if let connectionStatus = session.connectionStatus() {
                        ValidationLogger.shared()?.logString("Threema Web: Can't connect active session, wrong state \(connectionStatus)")
                    }
                    else {
                        ValidationLogger.shared()?.logString("Threema Web: Can't connect active session, connectionStatus is nil!")
                    }
                }
            }
        }
    }
    
    /**
     Stop all running sessions.
     Clears the list of running sessions
     */
    @objc public func stopAllSessions() {
        // disconnect all active sessions and set all sessions on core data to inactive
        ValidationLogger.shared().logString("Threema Web: Stop all active sessions")
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: true, forget: false, sendDisconnect: true, reason: .stop)
            }
        }
        removeObservers()
    }
    
    /**
     Stop and delete all running sessions.
     Clears the list of running sessions
     */
    @objc public func stopAndForgetAllSessions() {
        // disconnect all active sessions and set all sessions on core data to inactive
        ValidationLogger.shared().logString("Threema Web: Stop and forget all active sessions")
        WebClientSessionStore.shared.setAllWebClientSessionsInactive()
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: true, forget: true, sendDisconnect: true, reason: .stop)
            }
        }
    }
    
    /**
     Stop specific session.
     */
    public func stopSession(_ webClientSession: WebClientSession) {
        ValidationLogger.shared().logString("Threema Web: Stop session")
        if let session: WCSession = sessions[webClientSession.initiatorPermanentPublicKey!] {
            session.stop(close: true, forget: false, sendDisconnect: true, reason: .stop)
        }
    }
    
    /**
     Stop and delete specific session.
     */
    public func stopAndDeleteSession(_ webClientSession: WebClientSession) {
        ValidationLogger.shared().logString("Threema Web: Stop and delete all active sessions")
        let publicKey = webClientSession.initiatorPermanentPublicKey!
        if let session: WCSession = sessions[publicKey] {
            session.stop(close: true, forget: true, sendDisconnect: true, reason: .delete)
            sessions.removeValue(forKey: publicKey)
        }
        
        WebClientSessionStore.shared.deleteWebClientSession(webClientSession)
    }
    
    /**
     Remove WebClientSession from running list.
     */
    public func removeWCSessionFromRunning(_ session: WCSession) {
        if let publicKey = session.webClientSession?.initiatorPermanentPublicKey {
            runningSessionsQueue.sync {
                if let index = running.firstIndex(of: publicKey) {
                    running.remove(at: index)
                }
                WebClientSessionStore.shared.updateWebClientSession(session: session.webClientSession!, active: false)
            }
        }
        if running.count == 0 {
            ServerConnector.shared().resetPushOverrideTimeout()
        }
    }
    
    /**
     Remove all not permanent sessions.
     */
    public func removeAllNotPermanentSessions() {
        //Remove all not permanent sessions
        WebClientSessionStore.shared.removeAllNotPermanentSessions()
    }
    
    @objc public func isRunningWCSession() -> Bool {
        return running.count > 0
    }
    
    public func pauseAllRunningSessions() {
        ValidationLogger.shared().logString("Threema Web: Pause all sessions")
        sendConnectionAckToAllActiveSessions()
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: false, forget: false, sendDisconnect: false, reason: .pause)
            }
        }
        saveSessionsToArchive()
    }
    
    
    @objc public func updateConversationPushSetting(conversation: Conversation) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                let conversationResponse = WebConversationUpdate.init(conversation: conversation, objectMode: .modified, session: session)
                session.messageQueue.enqueue(data: conversationResponse.messagePack(), blackListed: false)
            }
        }
        
    }
}

extension WCSessionManager {
    // MARK: Private functions
    
    private func addWCSessionToRunning(webClientSession: WebClientSession) {
        runningSessionsQueue.sync {
            if !running.contains(webClientSession.initiatorPermanentPublicKey!) {
                running.append(webClientSession.initiatorPermanentPublicKey!)
                WebClientSessionStore.shared.updateWebClientSession(session: webClientSession, active: true)
            }
        }
    }
    
    private func canConnectToWebClient(completionHandler: @escaping ((_ isValid: Bool) -> Void)) {
        if UserSettings.shared().threemaWeb {
            if LicenseStore.shared().isValid() == true {
                completionHandler(true)
            } else {
                LicenseStore.shared()?.performLicenseCheck(completion: { (success) in
                    if success == true {
                        completionHandler(true)
                    } else {
                        ValidationLogger.shared()?.logString("Threema Web: LicenseStore is invalid, stop all sessions")
                        self.stopAllSessions()
                        completionHandler(false)
                    }
                })
            }
        } else {
            ValidationLogger.shared()?.logString("Threema Web: LicenseStore is invalid, stop all sessions")
            self.stopAllSessions()
            completionHandler(false)
        }
    }
    
    private func sendConnectionAckToAllActiveSessions() {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if let context = session.connectionContext() {
                    context.sendConnectionAck()
                }
            }
        }
    }
    
    private func sendMessagePackToAllActiveSessions(messagePack: Data, blackListed: Bool) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.sendMessageToWeb(blacklisted: blackListed, msgpack: messagePack)
            }
        }
    }
    
    private func sendMessagePackToAllActiveSessions(with requestedConversationId: String, messagePack: Data, blackListed: Bool) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationId) == true {
                    session.sendMessageToWeb(blacklisted: blackListed, msgpack: messagePack)
                }
                
            }
        }
    }
    
    private func sendMessagePackToRequestedSession(with requestId: String, messagePack: Data, blackListed: Bool) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if (session.requestMessage(for: requestId) != nil) {
                    session.sendMessageToWeb(blacklisted: blackListed, msgpack: messagePack)
                }
            }
        }
    }
    
    private func responseUpdateContact(contact: Contact, objectMode: WebReceiverUpdate.ObjectMode) {
        let receiverUpdate = WebReceiverUpdate.init(updatedContact: contact, objectMode: objectMode)
        DDLogVerbose("Threema Web: MessagePack -> Send update/receiver")
        sendMessagePackToAllActiveSessions(messagePack: receiverUpdate.messagePack(), blackListed: false)
    }
    
    private func responseUpdateAvatar(contact: Contact?, groupProxy: GroupProxy?) {
            if contact != nil {
                let avatarUpdate = WebAvatarUpdate.init(contact: contact!)
                DDLogVerbose("Threema Web: MessagePack -> Send update/avatar")
                sendMessagePackToAllActiveSessions(messagePack: avatarUpdate.messagePack(), blackListed: false)
            }
            else if groupProxy != nil {
                let avatarUpdate = WebAvatarUpdate.init(groupProxy: groupProxy!)
                DDLogVerbose("Threema Web: MessagePack -> Send update/avatar")
                sendMessagePackToAllActiveSessions(messagePack: avatarUpdate.messagePack(), blackListed: false)
            }
    }
    
    private func responseUpdateMessage(with requestedConversationId: String, message: BaseMessage, conversation: Conversation, objectMode: WebMessagesUpdate.ObjectMode, exclude requestId: String) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationId) == true {
                    if (session.requestMessage(for: requestId) == nil) {
                        sendResponseUpdateMessage(message: message, conversation: conversation, objectMode: objectMode, session: session)
                    }
                }
            }
        }
    }
    
    private func responseUpdateMessage(with requestedConversationId: String, message: BaseMessage, conversation: Conversation, objectMode: WebMessagesUpdate.ObjectMode) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationId) == true {
                    sendResponseUpdateMessage(message: message, conversation: conversation, objectMode: objectMode, session: session)
                }
            }
        }
    }
    
    private func sendResponseUpdateMessage(message: BaseMessage, conversation: Conversation, objectMode: WebMessagesUpdate.ObjectMode, session: WCSession) {
        if objectMode == .removed {
            let messageUpdate: WebMessagesUpdate = WebMessagesUpdate.init(baseMessage: message, conversation: conversation, objectMode: objectMode, session: session)
            DDLogVerbose("Threema Web: MessagePack -> Send update/messages")
            session.sendMessageToWeb(blacklisted: false, msgpack: messageUpdate.messagePack())
        } else {
            let messageUpdate: WebMessagesUpdate = WebMessagesUpdate.init(baseMessage: message, conversation: conversation, objectMode: objectMode, session: session)
            DDLogVerbose("Threema Web: MessagePack -> Send update/messages")
            session.sendMessageToWeb(blacklisted: false, msgpack: messageUpdate.messagePack())
        }
    }
    
    private func responseUpdateConversation(conversation: Conversation, objectMode: WebConversationUpdate.ObjectMode) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                let conversationResponse = WebConversationUpdate(conversation: conversation, objectMode: objectMode, session: session)
                DDLogVerbose("Threema Web: MessagePack -> Send update/conversation")
                session.sendMessageToWeb(blacklisted: false, msgpack: conversationResponse.messagePack())
            }
        }
    }
    
    private func responseUpdateGroup(group: GroupProxy, objectMode: WebReceiverUpdate.ObjectMode) {
        let receiverUpdate = WebReceiverUpdate.init(updatedGroup: group, objectMode: objectMode)
        DDLogVerbose("Threema Web: MessagePack -> Send update/receiver")
        sendMessagePackToAllActiveSessions(messagePack: receiverUpdate.messagePack(), blackListed: false)
    }

    private func responseUpdateTyping(identity: String, isTyping: Bool) {
        let typingUpdate = WebTypingUpdate.init(identity: identity, typing: isTyping)
        DDLogVerbose("Threema Web: MessagePack -> Send update/typing")
        sendMessagePackToAllActiveSessions(messagePack: typingUpdate.messagePack(), blackListed: true)
    }
    
    private func responseUpdateDeletedConversation(conversation: Conversation, contact: Contact?, objectMode: WebConversationUpdate.ObjectMode) {
        let conversationResponse = WebConversationUpdate.init(conversation: conversation, contact: contact, objectMode: objectMode)
        DDLogVerbose("Threema Web: MessagePack -> Send update/conversation")
        sendMessagePackToAllActiveSessions(messagePack: conversationResponse.messagePack(), blackListed: false)
    }

    private func webRequestMessage(for requestId: String) -> WebAbstractMessage? {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if let webAbstractMessage = session.requestMessage(for: requestId) {
                    return webAbstractMessage
                }
            }
        }
        return nil
    }
    
    private func removeWebRequestMessage(with requestId: String) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if (session.requestMessage(for: requestId) != nil) {
                    session.removeRequestCreateMessage(requestId: requestId)
                }
            }
        }
    }
}

extension WCSessionManager {
    //     MARK: Database Observer
    
    @objc func managedObjectContextDidChange(notification: NSNotification) {
        let managedObjectContext = notification.object as! NSManagedObjectContext
        
        // MARK: update
        self.handleUpdatedObjects(updatedObjects: managedObjectContext.updatedObjects)
        
        // MARK: inserted
        self.handleInsertedObjects(insertedObjects: managedObjectContext.insertedObjects)
        
        // MARK: deleted
        self.handleDeletedObjects(deletedObjects: managedObjectContext.deletedObjects)
    }
    
    private func handleUpdatedObjects(updatedObjects: Set<NSManagedObject>) {
        for managedObject in updatedObjects {
            switch managedObject {
            case is Contact:
                updateContact(managedObject as! Contact)
            case is BaseMessage:
                updateBaseMessage(managedObject as! BaseMessage)
            case is Conversation:
                updateConversation(managedObject as! Conversation)
            default:
                break
            }
        }
    }
    
    private func handleInsertedObjects(insertedObjects: Set<NSManagedObject>) {
        for managedObject in insertedObjects {
            switch managedObject {
            case is Contact:
                insertContact(managedObject as! Contact)
            case is BaseMessage:
                insertBaseMessage(managedObject as! BaseMessage)
            case is Conversation:
                insertConversation(managedObject as! Conversation)
            default:
                break
            }
        }
    }
    
    private func handleDeletedObjects(deletedObjects: Set<NSManagedObject>) {
        for managedObject in deletedObjects {
            switch managedObject {
            case is Contact:
                deleteContact(managedObject as! Contact)
            case is BaseMessage:
                deleteBaseMessage(managedObject as! BaseMessage)
            case is Conversation:
                deleteConversation(managedObject as! Conversation)
            default:
                break
            }
        }
    }
        
    private func updateContact(_ contact: Contact) {
        let changedValues = contact.changedValues()
        
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            if (contact.identity != nil) && (changedValues.keys.contains("firstName") || changedValues.keys.contains("lastName") || changedValues.keys.contains("displayName") || changedValues.keys.contains("publicNickname") || changedValues.keys.contains("verificationLevel") || changedValues.keys.contains("state") || changedValues.keys.contains("featureLevel") || changedValues.keys.contains("workContact") || changedValues.keys.contains("hidden")) {
                let objectMode: WebReceiverUpdate.ObjectMode = .modified
                self.responseUpdateContact(contact: contact, objectMode: objectMode)
            }
            if contact.changedValues().keys.contains("contactImage") || contact.changedValues().keys.contains("imageData") {
                self.responseUpdateAvatar(contact: contact, groupProxy: nil)
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func updateBaseMessage(_ baseMessage: BaseMessage) {
        let changedValues = baseMessage.changedValuesForCurrentEvent()
        
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            
            guard let conversation = baseMessage.conversation else {
                return
            }
                        
            let identity = conversation.isGroup() ? conversation.groupId.hexEncodedString() : self.baseMessageIdentity(baseMessage)
            self.processBaseMessageUpdate(baseMessage: baseMessage, changedValues: changedValues, identity: identity)
            
            if let lastMessage = conversation.lastMessage, lastMessage.id == baseMessage.id {
                if self.shouldSendUpdate(changedValues: changedValues) {
                    let objectMode: WebConversationUpdate.ObjectMode = .modified
                    self.responseUpdateConversation(conversation: conversation, objectMode: objectMode)
                    // background task to send ack to server
                    let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
                    BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime), completionHandler: nil)
                }
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func processBaseMessageUpdate(baseMessage: BaseMessage, changedValues: [String : Any], identity: String) {
        if shouldSendUpdate(changedValues: changedValues) {
            let objectMode: WebMessagesUpdate.ObjectMode = .modified
            self.responseUpdateMessage(with: identity, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode)
            // background task to send ack to server
            let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
            BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime), completionHandler:nil)
        }
    }
    
    private func shouldSendUpdate(changedValues: [String: Any]) -> Bool {
        if changedValues.count == 1 {
            let changedValueDict = changedValues.first
            if changedValueDict?.key == "progress" {
                return false
            }
        }
        else if changedValues.count == 0 {
            return false
        }
        return true
    }
        
    private func updateConversation(_ conversation: Conversation) {
        let changedValues = conversation.changedValues()
        let changedValuesForCurrentEvent = conversation.changedValuesForCurrentEvent()
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            if conversation.isGroup() {
                if changedValues.keys.contains("groupName") || changedValues.keys.contains("members") {
                    let objectMode: WebReceiverUpdate.ObjectMode = .modified
                    let groupProxy = GroupProxy.init(for: conversation)
                    self.responseUpdateGroup(group: groupProxy!, objectMode: objectMode)
                }
                else if changedValues.keys.contains("groupImage") {
                    let groupProxy = GroupProxy.init(for: conversation)
                    self.responseUpdateAvatar(contact: nil, groupProxy: groupProxy)
                }
            }
            else if changedValuesForCurrentEvent.keys.contains("typing") {
                self.responseUpdateTyping(identity: conversation.contact.identity, isTyping: conversation.typing.boolValue)
            }
            
            if (changedValues.keys.contains("lastMessage") || changedValues.keys.contains("marked") || changedValues.keys.contains("unreadMessageCount")) && conversation.lastMessage != nil {
                let objectMode: WebConversationUpdate.ObjectMode = .modified
                self.responseUpdateConversation(conversation: conversation, objectMode: objectMode)
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertContact(_ contact: Contact) {
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            if contact.identity != nil && contact.publicKey != nil {
                let objectMode: WebReceiverUpdate.ObjectMode = .new
                self.responseUpdateContact(contact: contact, objectMode: objectMode)
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertConversation(_ conversation: Conversation) {
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            if conversation.isGroup() {
                let receiverObjectMode: WebReceiverUpdate.ObjectMode = .new
                let groupProxy = GroupProxy.init(for: conversation)
                self.responseUpdateGroup(group: groupProxy!, objectMode: receiverObjectMode)
            }
            
            let objectMode: WebConversationUpdate.ObjectMode = .new
            self.responseUpdateConversation(conversation: conversation, objectMode: objectMode)
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertBaseMessage(_ baseMessage: BaseMessage) {
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)) {
            if let conversation = baseMessage.conversation {
                var id: String
                if conversation.isGroup() {
                    id = conversation.groupId.hexEncodedString()
                } else {
                    if let sender = baseMessage.sender {
                        id = sender.identity
                    } else {
                        if let contact = conversation.contact {
                            id = contact.identity
                        } else {
                            id = MyIdentityStore.shared().identity
                        }
                    }
                }
                
                switch baseMessage {
                case is TextMessage:
                    self.processTextMessageResponse(baseMessage, id)
                case is FileMessage, is ImageMessage, is VideoMessage, is AudioMessage:
                    self.processFileMessageResponse(baseMessage, id)
                default:
                    self.processBaseMessageResponse(baseMessage, id)
                    break
                }
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func deleteContact(_ contact: Contact) {
        if contact.identity != nil && contact.publicKey != nil {
            let objectMode: WebReceiverUpdate.ObjectMode = .removed
            self.responseUpdateContact(contact: contact, objectMode: objectMode)
        }
    }
    
    private func deleteBaseMessage(_ baseMessage: BaseMessage) {
        let changedValues = baseMessage.changedValues()
        let changedValuesForCurrentEvent = baseMessage.changedValuesForCurrentEvent()
        let identity: String?
        var conversation: Conversation? = nil
        
        if changedValues.keys.contains("conversation") && changedValuesForCurrentEvent["conversation"] != nil {
            conversation = changedValuesForCurrentEvent["conversation"] as? Conversation
        }
        if let conv = baseMessage.conversation {
            conversation = conv
        }
        
        if let conv = conversation {
            if let sender = baseMessage.sender {
                identity = sender.identity
            } else {
                if let contact = conv.contact {
                    identity = contact.identity
                }
                else {
                    identity = MyIdentityStore.shared().identity
                }
            }
            
            if conv.isGroup() {
                let objectMode: WebMessagesUpdate.ObjectMode = .removed
                self.responseUpdateMessage(with: conv.groupId.hexEncodedString(), message: baseMessage, conversation: conv, objectMode: objectMode)
            }
            if let identity = identity, !conv.isGroup() {
                    let objectMode: WebMessagesUpdate.ObjectMode = .removed
                    self.responseUpdateMessage(with: identity, message: baseMessage, conversation: conv, objectMode: objectMode)
            }
        }
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        let changedValuesForCurrentEvent = conversation.changedValuesForCurrentEvent()
        let objectMode: WebConversationUpdate.ObjectMode = .removed
        let contact: Contact? = changedValuesForCurrentEvent["contact"] as? Contact
        self.responseUpdateDeletedConversation(conversation: conversation, contact: contact, objectMode: objectMode)
    }
    
    private func processTextMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        var createTextMessageResponse: WebCreateTextMessageResponse?
        if baseMessage.webRequestId != nil {
            if let createTextMessageRequest = self.webRequestMessage(for: baseMessage.webRequestId) as? WebCreateTextMessageRequest {
                createTextMessageResponse = WebCreateTextMessageResponse.init(message: baseMessage, request: createTextMessageRequest)
            }
        }
        
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        if createTextMessageResponse != nil && baseMessage.webRequestId != nil {
            DDLogVerbose("Threema Web: MessagePack -> Send create/textMessage")
            self.sendMessagePackToRequestedSession(with: baseMessage.webRequestId!, messagePack: createTextMessageResponse!.messagePack(), blackListed: false)
            self.responseUpdateMessage(with: id, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode, exclude: baseMessage.webRequestId!)
            self.removeWebRequestMessage(with: baseMessage.webRequestId!)
        } else {
            self.responseUpdateMessage(with: id, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode)
        }
        
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime), completionHandler: nil)

    }
    
    private func processBaseMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        self.responseUpdateMessage(with: id, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode)
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime), completionHandler: nil)
    }
    
    private func processFileMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        var createFileMessageResponse: WebCreateFileMessageResponse?
        var backgroundIdentifier: String?
        
        if baseMessage.webRequestId != nil {
            if let createFileMessageRequest = self.webRequestMessage(for: baseMessage.webRequestId) as? WebCreateFileMessageRequest {
                createFileMessageRequest.ack = WebAbstractMessageAcknowledgement.init(baseMessage.webRequestId, true, nil)
                createFileMessageResponse = WebCreateFileMessageResponse.init(message: baseMessage, request: createFileMessageRequest)
                if let bgIdentifier = createFileMessageRequest.backgroundIdentifier {
                    backgroundIdentifier = bgIdentifier
                }
            }
        }
        
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        if createFileMessageResponse != nil && baseMessage.webRequestId != nil {
            DDLogVerbose("Threema Web: MessagePack -> Send create/fileMessage")
            self.sendMessagePackToRequestedSession(with: baseMessage.webRequestId!, messagePack: createFileMessageResponse!.messagePack(), blackListed: false)
            self.responseUpdateMessage(with: id, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode, exclude: baseMessage.webRequestId!)
            self.removeWebRequestMessage(with: baseMessage.webRequestId!)
        } else {
            self.responseUpdateMessage(with: id, message: baseMessage, conversation: baseMessage.conversation, objectMode: objectMode)
        }
        
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(key: backgroundKey, timeout: Int(kAppAckBackgroundTaskTime), completionHandler: nil)
        
        if backgroundIdentifier != nil {
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundIdentifier!)
        }
    }
        
    private func baseMessageIdentity(_ baseMessage: BaseMessage) -> String {
        if let sender = baseMessage.sender {
            return sender.identity
        }
        
        if let contact = baseMessage.conversation.contact {
            return contact.identity
        }
        
        return MyIdentityStore.shared().identity
    }
}

extension WCSessionManager {
    // MARK: BatteryNotifications
    
    @objc func batteryLevelDidChange(_ notification: Notification) {
        let batteryResponse = WebBatteryStatusUpdate.init()
        DDLogVerbose("Threema Web: MessagePack -> Send update/batteryStatus")
        sendMessagePackToAllActiveSessions(messagePack: batteryResponse.messagePack(), blackListed: true)
    }
    
    @objc func batteryStateDidChange(_ notification: Notification) {
        let batteryResponse = WebBatteryStatusUpdate.init()
        DDLogVerbose("Threema Web: MessagePack -> Send update/batteryStatus")
        sendMessagePackToAllActiveSessions(messagePack: batteryResponse.messagePack(), blackListed: true)
    }
    
    // MARK: ProfileNotifications
    
    @objc func profileNicknameChanged(_ notification: Notification) {
        let profileUpdate = WebProfileUpdate.init(nicknameChanged: true, newNickname: MyIdentityStore.shared().pushFromName, newAvatar: nil, deleteAvatar: false)
        DDLogVerbose("Threema Web: MessagePack -> Send update/profile")
        sendMessagePackToAllActiveSessions(messagePack: profileUpdate.messagePack(), blackListed: false)
    }
    
    @objc func profilePictureChanged(_ notification: Notification) {
        var profileUpdate: WebProfileUpdate?
        if let profileDict = MyIdentityStore.shared().profilePicture as? [AnyHashable: Any] {
            if let pictureData = profileDict["ProfilePicture"] {
                profileUpdate = WebProfileUpdate.init(nicknameChanged: false, newNickname: nil, newAvatar: pictureData as? Data, deleteAvatar: false)
            } else {
                profileUpdate = WebProfileUpdate.init(nicknameChanged: false, newNickname: nil, newAvatar: nil, deleteAvatar: true)
            }
        } else {
            profileUpdate = WebProfileUpdate.init(nicknameChanged: false, newNickname: nil, newAvatar: nil, deleteAvatar: true)
        }
        DDLogVerbose("Threema Web: MessagePack -> Send update/profile")
        sendMessagePackToAllActiveSessions(messagePack: profileUpdate!.messagePack(), blackListed: false)
    }
    
    @objc func blackListChanged(_ notification: Notification) {
        let identity = notification.object as! String
        var contact: Contact?
        
        let entityManager = EntityManager()
        contact = entityManager.entityFetcher.contact(forId: identity)
        
        if contact != nil {
            if contact!.identity != nil && contact!.publicKey != nil {
                let objectMode: WebReceiverUpdate.ObjectMode = .modified
                self.responseUpdateContact(contact: contact!, objectMode: objectMode)
            }
        }
    }
    
    @objc func refreshDirtyObjects(_ notification: Notification) {
        if let objectID = notification.userInfo?[kKeyObjectID] as? NSManagedObjectID {
            let entityManager = EntityManager()
            if let managedObject = entityManager.entityFetcher.getManagedObject(by: objectID) as? NSManagedObject {
                var insertedObjects = Set<NSManagedObject>()
                insertedObjects.insert(managedObject)
                self.handleInsertedObjects(insertedObjects: insertedObjects)
            }
        }
    }
}
