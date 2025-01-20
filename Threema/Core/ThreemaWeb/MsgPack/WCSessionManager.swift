//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@objc class WCSessionManager: NSObject {
    
    @objc static let shared = WCSessionManager()
    
    private let businessInjector: BusinessInjectorProtocol

    private var sessions = [Data: WCSession]()
    private(set) var running = [Data]()
    private var runningSessionsQueue = DispatchQueue(label: "ch.threema.runningSessionsQueue", attributes: [])
    private var observerAlreadySet = false
    
    override private init() {
        self.businessInjector = BusinessInjector()
        super.init()
        
        // Remove legacy files
        try? FileManager.default.removeItem(at: allSessionsURL())
        try? FileManager.default.removeItem(at: runningSessionsURL())
    }
    
    public class func isWebHostAllowed(scannedHostName: String, whiteList: String) -> Bool {
        if whiteList.isEmpty {
            return false
        }
        let arr = whiteList.components(separatedBy: ",")
        for host in arr {
            let pattern = host.trimmingCharacters(in: .whitespaces)
            if pattern == scannedHostName {
                return true
            }
            let slicedPattern = String(pattern.dropFirst())
            if pattern.hasPrefix("*"), scannedHostName.hasSuffix(slicedPattern) {
                return true
            }
        }
        return false
    }
}

// MARK: Private functions

extension WCSessionManager {
    
    /// Add observers
    /// * batteryLevelDidChange
    /// * batteryStateDidChange
    /// * profileNicknameChanged
    /// * profilePictureChanged
    /// * blackListChanged
    private func addObservers() {
        if observerAlreadySet == false {
            UIDevice.current.isBatteryMonitoringEnabled = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(batteryLevelDidChange),
                name: UIDevice.batteryLevelDidChangeNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(batteryStateDidChange),
                name: UIDevice.batteryStateDidChangeNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(profileNicknameChanged),
                name: NSNotification.Name(rawValue: kNotificationProfileNicknameChanged),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(profilePictureChanged),
                name: NSNotification.Name(rawValue: kNotificationProfilePictureChanged),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(blackListChanged),
                name: NSNotification.Name(rawValue: kNotificationBlockedContact),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(managedObjectContextDidChange),
                name: .NSManagedObjectContextObjectsDidChange,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(refreshDirtyObjects),
                name: NSNotification.Name(rawValue: kNotificationDBRefreshedDirtyObject),
                object: nil
            )
            observerAlreadySet = true
            NavigationBarPromptHandler.isWebActive = true
        }
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    private func removeObservers() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self)
        
        observerAlreadySet = false
        NavigationBarPromptHandler.isWebActive = false

        if NavigationBarPromptHandler.isCallActiveInBackground || VoIPCallStateManager.shared
            .currentCallState() == .idle, !NavigationBarPromptHandler.isGroupCallActive {
            
            DispatchQueue.main.async {
                if let mainTabBar = AppDelegate.getMainTabBarController(),
                   let viewControllers = mainTabBar.viewControllers {
                    if viewControllers.count <= kChatTabBarIndex {
                        UIApplication.shared.isIdleTimerDisabled = false
                        return
                    }
                    let chatNavVc = viewControllers[Int(kChatTabBarIndex)] as! UINavigationController
                    if let curChatVc = chatNavVc.topViewController as? ChatViewController {
                        if !curChatVc.isRecording(),
                           !curChatVc.isPlayingAudioMessage() {
                            UIApplication.shared.isIdleTimerDisabled = false
                        }
                        return
                    }
                }
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }
    
    private func allSessionsURL() -> URL {
        let documentDir = FileUtility.shared.appDataDirectory
        return documentDir!.appendingPathComponent("AllWCSessions")
    }
    
    private func runningSessionsURL() -> URL {
        let documentDir = FileUtility.shared.appDataDirectory
        return documentDir!.appendingPathComponent("RunningWCSessions")
    }
}

// MARK: Public functions

extension WCSessionManager {
    
    /// Connect a old or new session. Search for correct session or create a new one
    @objc public func connect(authToken: Data?, wca: String?, publicKeyHash: String) {
        canConnectToWebClient(completionHandler: { isValid in
            if isValid == true {
                if let webClientSession = WebClientSessionStore.shared.webClientSessionForHash(publicKeyHash) {
                    if webClientSession.isConnecting {
                        DDLogError("[Threema Web] WebClientSession try already to connect")
                        return
                    }
                    webClientSession.isConnecting = true
                    var session: WCSession? = self.sessions[webClientSession.initiatorPermanentPublicKey]
                    
                    if LicenseStore.requiresLicenseKey() == true {
                        let mdmSetup = MDMSetup(setup: false)!
                        if let webHosts = mdmSetup.webHosts() {
                            if WCSessionManager.isWebHostAllowed(
                                scannedHostName: webClientSession.saltyRTCHost,
                                whiteList: webHosts
                            ) == false {
                                DDLogNotice("[Threema Web] Scanned qr code host is not white listed")
                                if AppDelegate.shared().isAppInBackground() {
                                    ThreemaUtilityObjC.sendErrorLocalNotification(
                                        #localize("webClient_scan_error_mdm_host_title"),
                                        body: BundleUtil
                                            .localizedString(forKey: "webClient_scan_error_mdm_host_message"),
                                        userInfo: nil
                                    )
                                }
                                else {
                                    let rootVC = UIApplication.shared.windows.first!.rootViewController
                                    UIAlertTemplate.showAlert(
                                        owner: rootVC!,
                                        title: BundleUtil
                                            .localizedString(forKey: "webClient_scan_error_mdm_host_title"),
                                        message: BundleUtil
                                            .localizedString(forKey: "webClient_scan_error_mdm_host_message")
                                    )
                                }
                                webClientSession.isConnecting = false
                                return
                            }
                        }
                    }
                                      
                    if let session, let wca,
                       let connectionWca = session.connectionWca(),
                       wca.elementsEqual(connectionWca) {
                        // same wca, ignore this request
                        DDLogNotice("[Threema Web] Ignore connect, because it's the same wca")
                        webClientSession.isConnecting = false
                        return
                    }

                    if session == nil {
                        session = WCSession(webClientSession: webClientSession)
                        self.sessions[webClientSession.initiatorPermanentPublicKey] = session
                    }
                    if wca != nil {
                        session!.setWcaForConnection(wca: wca!)
                    }
                    self.addWCSessionToRunning(webClientSession: webClientSession)
                    self.addObservers()
                    session!.connect(authToken: authToken)
                }
                else {
                    // session not found
                }
            }
        })
    }
    
    @objc public func connect(authToken: Data?, wca: String?, webClientSession: WebClientSessionEntity) {
        DDLogNotice(
            "[Threema Web] Connect to host \(webClientSession.saltyRTCHost); port: \(webClientSession.saltyRTCPort.stringValue) selfHosted: \(webClientSession.selfHosted.stringValue); permanent: \(webClientSession.permanent.stringValue); version: \(webClientSession.version?.stringValue ?? "?")"
        )
        
        if webClientSession.isConnecting {
            DDLogError("[Threema Web] WebClientSession try already to connect")
            return
        }
        webClientSession.isConnecting = true
        
        canConnectToWebClient(completionHandler: { isValid in
            if isValid == true {
                var session: WCSession? = self.sessions[webClientSession.initiatorPermanentPublicKey]
                
                if let session, let wca,
                   let connectionWca = session.connectionWca(),
                   wca.elementsEqual(connectionWca) {
                    // same wca, ignore this request
                    DDLogNotice("[Threema Web] Ignore connect, because it's the same wca")
                    webClientSession.isConnecting = false
                    return
                }

                if session == nil {
                    session = WCSession(webClientSession: webClientSession)
                    self.sessions[webClientSession.initiatorPermanentPublicKey] = session
                }
                
                if LicenseStore.requiresLicenseKey() == true {
                    let mdmSetup = MDMSetup(setup: false)!
                    if let webHosts = mdmSetup.webHosts() {
                        if WCSessionManager.isWebHostAllowed(
                            scannedHostName: webClientSession.saltyRTCHost,
                            whiteList: webHosts
                        ) == false {
                            DDLogError("[Threema Web] Scanned qr code host is not white listed")
                            if AppDelegate.shared().isAppInBackground() {
                                ThreemaUtilityObjC.sendErrorLocalNotification(
                                    #localize("webClient_scan_error_mdm_host_title"),
                                    body: #localize("webClient_scan_error_mdm_host_message"),
                                    userInfo: nil
                                )
                            }
                            else {
                                let rootVC = UIApplication.shared.windows.first!.rootViewController
                                UIAlertTemplate.showAlert(
                                    owner: rootVC!,
                                    title: #localize("webClient_scan_error_mdm_host_title"),
                                    message: #localize("webClient_scan_error_mdm_host_message")
                                )
                            }
                            webClientSession.isConnecting = false
                            return
                        }
                    }
                }
                                
                if wca != nil {
                    session!.setWcaForConnection(wca: wca!)
                }
                self.addWCSessionToRunning(webClientSession: webClientSession)
                self.addObservers()
                session!.connect(authToken: authToken)
            }
            else {
                webClientSession.isConnecting = false
            }
        })
    }
    
    @objc public func connectAllRunningSessions() {
        if running.isEmpty {
            DDLogNotice("[Threema Web] There is no active session")
            WebClientSessionStore.shared.setAllWebClientSessionsInactive()

            removeObservers()
            return
        }
        canConnectToWebClient { isValid in
            if isValid == true {
                DDLogNotice("[Threema Web] Connect active sessions (\(self.running.count))")
                for publicKey in self.running {
                    if let session = self.sessions[publicKey] {
                        if session.connectionStatus() == .disconnected {
                            self.addObservers()
                            DDLogNotice("[Threema Web] Connect active session")
                            session.connect(authToken: nil)
                        }
                        else {
                            if let connectionStatus = session.connectionStatus() {
                                DDLogError(
                                    "[Threema Web] Can't connect active session, wrong state \(connectionStatus)"
                                )
                            }
                            else {
                                DDLogError("[Threema Web] Can't connect active session, connectionStatus is nil!")
                                self.removeWCSessionFromRunning(session)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Stop all running sessions.
    /// Clears the list of running sessions
    @objc public func stopAllSessions() {
        // disconnect all active sessions and set all sessions on core data to inactive
        DDLogNotice("[Threema Web] Stop all active sessions")
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: true, forget: false, sendDisconnect: true, reason: .stop)
            }
        }
        removeObservers()
    }
    
    /// Stop and delete all running sessions.
    /// Clears the list of running sessions
    @objc public func stopAndForgetAllSessions() {
        // disconnect all active sessions and set all sessions on core data to inactive
        DDLogNotice("[Threema Web] Stop and forget all active sessions")
        WebClientSessionStore.shared.setAllWebClientSessionsInactive()
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: true, forget: true, sendDisconnect: true, reason: .stop)
            }
        }
    }
    
    /// Stop specific session.
    public func stopSession(_ webClientSession: WebClientSessionEntity) {
        DDLogNotice("[Threema Web] Stop session")
        if let session: WCSession = sessions[webClientSession.initiatorPermanentPublicKey] {
            session.stop(close: true, forget: false, sendDisconnect: true, reason: .stop)
        }
    }
    
    /// Stop and delete specific session.
    public func stopAndDeleteSession(_ webClientSession: WebClientSessionEntity) {
        DDLogNotice("[Threema Web] Stop and delete all active sessions")
        let publicKey = webClientSession.initiatorPermanentPublicKey
        if let session: WCSession = sessions[publicKey] {
            session.stop(close: true, forget: true, sendDisconnect: true, reason: .delete)
            sessions.removeValue(forKey: publicKey)
        }
        
        WebClientSessionStore.shared.deleteWebClientSession(webClientSession)
    }
    
    /// Remove WebClientSession from running list.
    public func removeWCSessionFromRunning(_ session: WCSession) {
        if let publicKey = session.webClientSession?.initiatorPermanentPublicKey {
            runningSessionsQueue.sync {
                if let index = running.firstIndex(of: publicKey) {
                    running.remove(at: index)
                }
                WebClientSessionStore.shared.updateWebClientSession(session: session.webClientSession!, active: false)
            }
        }
        if running.isEmpty {
            removeObservers()
        }
    }
    
    /// Remove all not permanent sessions.
    public func removeAllNotPermanentSessions() {
        // Remove all not permanent sessions
        WebClientSessionStore.shared.removeAllNotPermanentSessions()
    }
    
    @objc public func isRunningWCSession() -> Bool {
        !running.isEmpty
    }
    
    @objc public func pauseAllRunningSessions() {
        DDLogNotice("[Threema Web] Pause all sessions")
        sendConnectionAckToAllActiveSessions()
        for publicKey in running {
            if let session = sessions[publicKey] {
                session.stop(close: false, forget: false, sendDisconnect: false, reason: .pause)
            }
        }
    }
    
    @objc public func updateConversationPushSetting(conversation: ConversationEntity) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                let conversationResponse = WebConversationUpdate(
                    conversation: conversation,
                    objectMode: .modified,
                    session: session
                )
                session.messageQueue.enqueue(data: conversationResponse.messagePack(), blackListed: false)
            }
        }
    }
}

extension WCSessionManager {
    // MARK: Private functions
    
    private func addWCSessionToRunning(webClientSession: WebClientSessionEntity) {
        runningSessionsQueue.sync {
            if !running.contains(webClientSession.initiatorPermanentPublicKey) {
                running.append(webClientSession.initiatorPermanentPublicKey)
                WebClientSessionStore.shared.updateWebClientSession(session: webClientSession, active: true)
            }
        }
    }
        
    private func canConnectToWebClient(completionHandler: @escaping ((_ isValid: Bool) -> Void)) {
        if UserSettings.shared().threemaWeb, !MDMSetup(setup: false).disableWeb() {
            if LicenseStore.shared().isValid() == true {
                completionHandler(true)
            }
            else {
                LicenseStore.shared().performLicenseCheck(completion: { success in
                    if success == true {
                        completionHandler(true)
                    }
                    else {
                        DDLogWarn("[Threema Web] LicenseStore is invalid, stop all sessions")
                        self.stopAllSessions()
                        completionHandler(false)
                    }
                })
            }
        }
        else {
            DDLogWarn("Threema Web is not enabled, stop all sessions")
            stopAllSessions()
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
    
    private func sendMessagePackToAllActiveSessions(
        with requestedConversationID: String,
        messagePack: Data,
        blackListed: Bool
    ) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationID) == true {
                    session.sendMessageToWeb(blacklisted: blackListed, msgpack: messagePack)
                }
            }
        }
    }
    
    private func sendMessagePackToRequestedSession(with requestID: String, messagePack: Data, blackListed: Bool) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestMessage(for: requestID) != nil {
                    session.sendMessageToWeb(blacklisted: blackListed, msgpack: messagePack)
                }
            }
        }
    }
    
    private func responseUpdateContact(contact: ContactEntity, objectMode: WebReceiverUpdate.ObjectMode) {
        let receiverUpdate = WebReceiverUpdate(updatedContact: contact, objectMode: objectMode)
        DDLogVerbose("[Threema Web] MessagePack -> Send update/receiver")
        sendMessagePackToAllActiveSessions(messagePack: receiverUpdate.messagePack(), blackListed: false)
    }
    
    private func responseUpdateAvatar(contact: ContactEntity?, group: Group?) {
        if contact != nil {
            let avatarUpdate = WebAvatarUpdate(contact: contact!)
            DDLogVerbose("[Threema Web] MessagePack -> Send update/avatar")
            sendMessagePackToAllActiveSessions(messagePack: avatarUpdate.messagePack(), blackListed: false)
        }
        else if group != nil {
            let avatarUpdate = WebAvatarUpdate(group: group!)
            DDLogVerbose("[Threema Web] MessagePack -> Send update/avatar")
            sendMessagePackToAllActiveSessions(messagePack: avatarUpdate.messagePack(), blackListed: false)
        }
    }
    
    private func responseUpdateMessage(
        with requestedConversationID: String,
        message: BaseMessage,
        conversation: ConversationEntity,
        objectMode: WebMessagesUpdate.ObjectMode,
        exclude requestID: String
    ) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationID) == true {
                    if session.requestMessage(for: requestID) == nil {
                        sendResponseUpdateMessage(
                            message: message,
                            conversation: conversation,
                            objectMode: objectMode,
                            session: session
                        )
                    }
                }
            }
        }
    }
    
    private func responseUpdateMessage(
        with requestedConversationID: String,
        message: BaseMessage,
        conversation: ConversationEntity,
        objectMode: WebMessagesUpdate.ObjectMode
    ) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestedConversations(contains: requestedConversationID) == true {
                    sendResponseUpdateMessage(
                        message: message,
                        conversation: conversation,
                        objectMode: objectMode,
                        session: session
                    )
                }
            }
        }
    }
    
    private func sendResponseUpdateMessage(
        message: BaseMessage,
        conversation: ConversationEntity,
        objectMode: WebMessagesUpdate.ObjectMode,
        session: WCSession
    ) {
        let messageUpdate = WebMessagesUpdate(
            baseMessage: message,
            conversation: conversation,
            objectMode: objectMode,
            session: session
        )
        DDLogVerbose("[Threema Web] MessagePack -> Send update/messages")
        session.sendMessageToWeb(blacklisted: false, msgpack: messageUpdate.messagePack())
    }
    
    private func responseUpdateConversation(
        conversation: ConversationEntity,
        objectMode: WebConversationUpdate.ObjectMode
    ) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                let conversationResponse = WebConversationUpdate(
                    conversation: conversation,
                    objectMode: objectMode,
                    session: session
                )
                DDLogVerbose("[Threema Web] MessagePack -> Send update/conversation")
                session.sendMessageToWeb(blacklisted: false, msgpack: conversationResponse.messagePack())
            }
        }
    }
    
    private func responseUpdateGroup(group: Group, objectMode: WebReceiverUpdate.ObjectMode) {
        let receiverUpdate = WebReceiverUpdate(updatedGroup: group, objectMode: objectMode)
        DDLogVerbose("[Threema Web] MessagePack -> Send update/receiver")
        sendMessagePackToAllActiveSessions(messagePack: receiverUpdate.messagePack(), blackListed: false)
    }

    private func responseUpdateTyping(identity: ThreemaIdentity, isTyping: Bool) {
        let typingUpdate = WebTypingUpdate(identity: identity, typing: isTyping)
        DDLogVerbose("[Threema Web] MessagePack -> Send update/typing")
        sendMessagePackToAllActiveSessions(messagePack: typingUpdate.messagePack(), blackListed: true)
    }
    
    private func responseUpdateDeletedConversation(
        conversation: ConversationEntity,
        contact: ContactEntity?,
        objectMode: WebConversationUpdate.ObjectMode
    ) {
        let conversationResponse = WebConversationUpdate(
            conversation: conversation,
            contact: contact,
            objectMode: objectMode
        )
        DDLogVerbose("[Threema Web] MessagePack -> Send update/conversation")
        sendMessagePackToAllActiveSessions(messagePack: conversationResponse.messagePack(), blackListed: false)
    }

    private func webRequestMessage(for requestID: String) -> WebAbstractMessage? {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if let webAbstractMessage = session.requestMessage(for: requestID) {
                    return webAbstractMessage
                }
            }
        }
        return nil
    }
    
    private func removeWebRequestMessage(with requestID: String) {
        for publicKey in running {
            if let session = sessions[publicKey] {
                if session.requestMessage(for: requestID) != nil {
                    session.removeRequestCreateMessage(requestID: requestID)
                }
            }
        }
    }
}

extension WCSessionManager {
    //     MARK: Database Observer
    
    @objc func managedObjectContextDidChange(notification: NSNotification) {
        if let managedObjectContext = notification.object as? NSManagedObjectContext,
           managedObjectContext.concurrencyType == .mainQueueConcurrencyType {
            
            // MARK: inserted

            handleInsertedObjects(insertedObjects: managedObjectContext.insertedObjects)
            
            // MARK: update

            handleUpdatedObjects(updatedObjects: managedObjectContext.updatedObjects)
            
            // MARK: deleted

            handleDeletedObjects(deletedObjects: managedObjectContext.deletedObjects)
        }
        else {
            if let managedObjectContext = notification.object as? NSManagedObjectContext {
                for managedObject in managedObjectContext.insertedObjects {
                    switch managedObject {
                    case is ContactEntity:
                        let contact = managedObject as! ContactEntity
                        DDLogNotice("New contact added on wrong context \(contact.identity)")
                    case is BaseMessage:
                        let baseMessage = managedObject as! BaseMessage
                        DDLogNotice("New message added on wrong context \(baseMessage.id.hexString)")
                    case is ConversationEntity:
                        let conversation = managedObject as! ConversationEntity
                        if conversation.isGroup {
                            DDLogNotice(
                                "New conversation added on wrong context \(conversation.groupID?.hexString ?? "?")"
                            )
                        }
                        else {
                            DDLogNotice(
                                "New conversation added on wrong context \(conversation.contact?.identity ?? "?")"
                            )
                        }
                    default:
                        break
                    }
                }
                for managedObject in managedObjectContext.updatedObjects {
                    switch managedObject {
                    case is ContactEntity:
                        let contact = managedObject as! ContactEntity
                        DDLogNotice("Updated contact on wrong context \(contact.identity)")
                    case is BaseMessage:
                        let baseMessage = managedObject as! BaseMessage
                        DDLogNotice("Updated message on wrong context \(baseMessage.id.hexString)")
                    case is ConversationEntity:
                        let conversation = managedObject as! ConversationEntity
                        if conversation.isGroup {
                            DDLogNotice(
                                "Updated conversation on wrong context \(conversation.groupID?.hexString ?? "?")"
                            )
                        }
                        else {
                            DDLogNotice(
                                "Updated conversation on wrong context \(conversation.contact?.identity ?? "?")"
                            )
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func handleUpdatedObjects(updatedObjects: Set<NSManagedObject>, _ dirtyObjects: Bool = false) {
        for managedObject in updatedObjects {
            switch managedObject {
            case is ContactEntity:
                updateContact(managedObject as! ContactEntity, dirtyObjects: dirtyObjects)
            case is BaseMessage:
                // This is a workaround for an issue that was introduced with IOS-3233 / IOS-3212
                // With the new changes we do not insert new file messages immediately but wait until they are properly
                // decoded (we check if the mimeType has changed/been set) and only then insert them into the web
                // client.
                // These changes caused a crash when using web client because we force unwrap `fileName`, `fileSize` and
                // `mimeType` when creating a `WebFile` struct.
                // As we're sunsetting the web client we just avoid the crash (the message will be updated later anyways
                // so the user impact is low) instead of fixing it properly.
                if let fileMessageEntity = managedObject as? FileMessageEntity,
                   fileMessageEntity.changedValues().keys.contains("mimeType") {
                    insertBaseMessage(managedObject as! BaseMessage)
                    continue
                }
                updateBaseMessage(managedObject as! BaseMessage, dirtyObjects: dirtyObjects)
            case is ConversationEntity:
                updateConversation(managedObject as! ConversationEntity, dirtyObjects: dirtyObjects)
            default:
                break
            }
        }
    }
    
    private func handleInsertedObjects(insertedObjects: Set<NSManagedObject>) {
        for managedObject in insertedObjects {
            switch managedObject {
            case is ContactEntity:
                insertContact(managedObject as! ContactEntity)
            case is BaseMessage:
                if let fileMessageEntity = managedObject as? FileMessageEntity {
                    guard fileMessageEntity.fileName != nil, fileMessageEntity.fileSize != nil,
                          fileMessageEntity.mimeType != nil else {
                        continue
                    }
                }
                
                insertBaseMessage(managedObject as! BaseMessage)
            case is ConversationEntity:
                insertConversation(managedObject as! ConversationEntity)
            default:
                break
            }
        }
    }
    
    private func handleDeletedObjects(deletedObjects: Set<NSManagedObject>) {
        for managedObject in deletedObjects {
            switch managedObject {
            case is ContactEntity:
                deleteContact(managedObject as! ContactEntity)
            case is BaseMessage:
                deleteBaseMessage(managedObject as! BaseMessage)
            case is ConversationEntity:
                deleteConversation(managedObject as! ConversationEntity)
            default:
                break
            }
        }
    }
        
    private func updateContact(_ contact: ContactEntity, dirtyObjects: Bool = false) {
        let changedValues = contact.changedValues()
        
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            guard let currentContact = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: contact.objectID) as? ContactEntity else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            DDLogNotice("Updated contact on main context \(currentContact.identity)")
            
            if changedValues.keys.contains("firstName") ||
                changedValues.keys.contains("lastName") ||
                changedValues.keys.contains("displayName") ||
                changedValues.keys.contains("publicNickname") ||
                changedValues.keys.contains("verificationLevel") ||
                changedValues.keys.contains("state") ||
                changedValues.keys.contains("featureMask") ||
                changedValues.keys.contains("workContact") ||
                changedValues.keys.contains("hidden") ||
                dirtyObjects {
                let objectMode: WebReceiverUpdate.ObjectMode = .modified
                self.responseUpdateContact(contact: currentContact, objectMode: objectMode)
            }
            
            if changedValues.keys.contains("contactImage") || changedValues.keys.contains("imageData") {
                self.responseUpdateAvatar(contact: currentContact, group: nil)
            }
            
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func updateBaseMessage(_ baseMessage: BaseMessage, dirtyObjects: Bool = false) {
        let changedValues = baseMessage.changedValuesForCurrentEvent()
        
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            guard let currentMessage = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: baseMessage.objectID) as? BaseMessage,
                let conversation = currentMessage.conversation else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            
            DDLogNotice("Updated message on main context \(currentMessage.id.hexString)")
                        
            let identity = conversation.isGroup ? conversation.groupID!.hexEncodedString() : self
                .baseMessageIdentity(baseMessage)
            self.processBaseMessageUpdate(baseMessage: currentMessage, changedValues: changedValues, identity: identity)
            
            if let lastMessage = conversation.lastMessage,
               lastMessage.id == currentMessage.id,
               self.shouldSendUpdate(changedValues: changedValues) || dirtyObjects {
                let objectMode: WebConversationUpdate.ObjectMode = .modified
                self.responseUpdateConversation(conversation: conversation, objectMode: objectMode)
                // background task to send ack to server
                let backgroundKey = kAppAckBackgroundTask + currentMessage.id.hexEncodedString()
                BackgroundTaskManager.shared.newBackgroundTask(
                    key: backgroundKey,
                    timeout: Int(kAppAckBackgroundTaskTime),
                    completionHandler: nil
                )
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func processBaseMessageUpdate(baseMessage: BaseMessage, changedValues: [String: Any], identity: String) {
        if shouldSendUpdate(changedValues: changedValues) {
            let objectMode: WebMessagesUpdate.ObjectMode = .modified
            responseUpdateMessage(
                with: identity,
                message: baseMessage,
                conversation: baseMessage.conversation,
                objectMode: objectMode
            )
            // background task to send ack to server
            let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
            BackgroundTaskManager.shared.newBackgroundTask(
                key: backgroundKey,
                timeout: Int(kAppAckBackgroundTaskTime),
                completionHandler: nil
            )
        }
    }
    
    private func shouldSendUpdate(changedValues: [String: Any]) -> Bool {
        if changedValues.count == 1 {
            let changedValueDict = changedValues.first
            if changedValueDict?.key == "progress" {
                return false
            }
        }
        else if changedValues.isEmpty {
            return false
        }
        return true
    }
        
    private func updateConversation(_ conversation: ConversationEntity, dirtyObjects: Bool = false) {
        let changedValues = conversation.changedValues()
        
        let changedValuesForCurrentEvent = conversation.changedValuesForCurrentEvent()
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            guard let currentConversation = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? ConversationEntity else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            
            DDLogNotice(
                "Updated conversation on main context \(currentConversation.isGroup ? currentConversation.groupID?.hexString ?? "?" : currentConversation.contact?.identity ?? "?")"
            )
                        
            if currentConversation.isGroup {
                
                if changedValues.keys.contains("groupName") || changedValues.keys.contains("members") {
                    if let group = self.businessInjector.groupManager.getGroup(conversation: currentConversation) {
                        self.responseUpdateGroup(group: group, objectMode: .modified)
                    }
                }
                else if changedValues.keys.contains("groupImage"),
                        let group = self.businessInjector.groupManager.getGroup(conversation: currentConversation) {
                    self.responseUpdateAvatar(contact: nil, group: group)
                }
            }
            else if let contact = currentConversation.contact,
                    changedValuesForCurrentEvent.keys.contains("typing") {
                self.responseUpdateTyping(
                    identity: contact.threemaIdentity,
                    isTyping: currentConversation.typing.boolValue
                )
            }
            
            if (
                changedValues.keys.contains("lastMessage") || changedValues.keys.contains("visibility") || changedValues
                    .keys.contains("unreadMessageCount") || changedValues.keys.contains("lastUpdate")
                    || dirtyObjects
            ) && currentConversation.lastMessage != nil {
                let objectMode: WebConversationUpdate.ObjectMode = .modified
                self.responseUpdateConversation(conversation: currentConversation, objectMode: objectMode)
            }
            else if !conversation.isGroup,
                    let contact = conversation.contact,
                    changedValues.keys.contains("category") || changedValues.keys.contains("visibility") {
                self.responseUpdateContact(contact: contact, objectMode: .modified)
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertContact(_ contact: ContactEntity) {
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            guard let currentContact = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: contact.objectID) as? ContactEntity else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            DDLogNotice("New contact added on main context \(currentContact.identity)")
            
            let objectMode: WebReceiverUpdate.ObjectMode = .new
            self.responseUpdateContact(contact: currentContact, objectMode: objectMode)
            
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertConversation(_ conversation: ConversationEntity) {
        
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            
            // Show only chats where lastUpdate is not `nil` to avoid showing chats that only contain system messages
            guard let currentConversation = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: conversation.objectID) as? ConversationEntity,
                currentConversation.lastUpdate != nil else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            
            DDLogNotice(
                "New conversation added on main context \(currentConversation.isGroup ? currentConversation.groupID?.hexString ?? "?" : currentConversation.contact?.identity ?? "?")"
            )
            
            if currentConversation.isGroup,
               let group = self.businessInjector.groupManager.getGroup(conversation: currentConversation) {
                self.responseUpdateGroup(group: group, objectMode: .new)
            }

            self.responseUpdateConversation(conversation: currentConversation, objectMode: .new)
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func insertBaseMessage(_ baseMessage: BaseMessage) {
        let backgroundKey = kAppAckBackgroundTask + SwiftUtils.pseudoRandomString(length: 10)
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppCoreDataProcessMessageBackgroundTaskTime)
        ) {
            guard let currentMessage = self.businessInjector.entityManager.entityFetcher
                .getManagedObject(by: baseMessage.objectID) as? BaseMessage,
                let conversation = currentMessage.conversation else {
                BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
                return
            }
            
            DDLogNotice("New message added on main context \(currentMessage.id.hexString)")
            
            let id: String =
                if conversation.isGroup,
                let groupID = conversation.groupID {
                    groupID.hexEncodedString()
                }
                else {
                    if let sender = currentMessage.sender {
                        sender.identity
                    }
                    else {
                        if let contact = conversation.contact {
                            contact.identity
                        }
                        else {
                            MyIdentityStore.shared().identity
                        }
                    }
                }
            
            switch currentMessage {
            case is TextMessageEntity:
                self.processTextMessageResponse(currentMessage, id)
            case is FileMessageEntity, is ImageMessageEntity, is VideoMessageEntity, is AudioMessageEntity:
                self.processFileMessageResponse(currentMessage, id)
            default:
                self.processBaseMessageResponse(currentMessage, id)
            }
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundKey)
        }
    }
    
    private func deleteContact(_ contact: ContactEntity) {
        let objectMode: WebReceiverUpdate.ObjectMode = .removed
        responseUpdateContact(contact: contact, objectMode: objectMode)
    }
    
    private func deleteBaseMessage(_ baseMessage: BaseMessage) {
        let changedValues = baseMessage.changedValues()
        let changedValuesForCurrentEvent = baseMessage.changedValuesForCurrentEvent()
        let identity: String?
        var conversation: ConversationEntity?
        
        if changedValues.keys.contains("conversation"), changedValuesForCurrentEvent["conversation"] != nil {
            conversation = changedValuesForCurrentEvent["conversation"] as? ConversationEntity
        }
        if let conv = baseMessage.conversation {
            conversation = conv
        }
        
        if let conv = conversation {
            if let sender = baseMessage.sender {
                identity = sender.identity
            }
            else {
                if let contact = conv.contact {
                    identity = contact.identity
                }
                else {
                    identity = MyIdentityStore.shared().identity
                }
            }
            
            if conv.isGroup {
                let objectMode: WebMessagesUpdate.ObjectMode = .removed
                responseUpdateMessage(
                    with: conv.groupID!.hexEncodedString(),
                    message: baseMessage,
                    conversation: conv,
                    objectMode: objectMode
                )
            }
            if let identity, !conv.isGroup {
                let objectMode: WebMessagesUpdate.ObjectMode = .removed
                responseUpdateMessage(
                    with: identity,
                    message: baseMessage,
                    conversation: conv,
                    objectMode: objectMode
                )
            }
        }
    }
    
    private func deleteConversation(_ conversation: ConversationEntity) {
        let changedValuesForCurrentEvent = conversation.changedValuesForCurrentEvent()
        let objectMode: WebConversationUpdate.ObjectMode = .removed
        let contact: ContactEntity? = changedValuesForCurrentEvent["contact"] as? ContactEntity
        responseUpdateDeletedConversation(conversation: conversation, contact: contact, objectMode: objectMode)
    }
    
    private func processTextMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        var createTextMessageResponse: WebCreateTextMessageResponse?
        if baseMessage.webRequestID != nil {
            if let createTextMessageRequest = webRequestMessage(
                for: baseMessage
                    .webRequestID
            ) as? WebCreateTextMessageRequest {
                createTextMessageResponse = WebCreateTextMessageResponse(
                    message: baseMessage,
                    request: createTextMessageRequest
                )
            }
        }
        
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        if createTextMessageResponse != nil, baseMessage.webRequestID != nil {
            DDLogVerbose("[Threema Web] MessagePack -> Send create/textMessage")
            sendMessagePackToRequestedSession(
                with: baseMessage.webRequestID!,
                messagePack: createTextMessageResponse!.messagePack(),
                blackListed: false
            )
            responseUpdateMessage(
                with: id,
                message: baseMessage,
                conversation: baseMessage.conversation,
                objectMode: objectMode,
                exclude: baseMessage.webRequestID!
            )
            removeWebRequestMessage(with: baseMessage.webRequestID!)
        }
        else {
            responseUpdateMessage(
                with: id,
                message: baseMessage,
                conversation: baseMessage.conversation,
                objectMode: objectMode
            )
        }
        
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppAckBackgroundTaskTime),
            completionHandler: nil
        )
    }
    
    private func processBaseMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        responseUpdateMessage(
            with: id,
            message: baseMessage,
            conversation: baseMessage.conversation,
            objectMode: objectMode
        )
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppAckBackgroundTaskTime),
            completionHandler: nil
        )
    }
    
    private func processFileMessageResponse(_ baseMessage: BaseMessage, _ id: String) {
        var createFileMessageResponse: WebCreateFileMessageResponse?
        var backgroundIdentifier: String?
        
        if baseMessage.webRequestID != nil {
            if let createFileMessageRequest = webRequestMessage(
                for: baseMessage
                    .webRequestID
            ) as? WebCreateFileMessageRequest {
                createFileMessageRequest.ack = WebAbstractMessageAcknowledgement(baseMessage.webRequestID, true, nil)
                createFileMessageResponse = WebCreateFileMessageResponse(
                    message: baseMessage,
                    request: createFileMessageRequest
                )
                if let bgIdentifier = createFileMessageRequest.backgroundIdentifier {
                    backgroundIdentifier = bgIdentifier
                }
            }
        }
        
        let objectMode: WebMessagesUpdate.ObjectMode = .new
        if createFileMessageResponse != nil, baseMessage.webRequestID != nil {
            DDLogVerbose("[Threema Web] MessagePack -> Send create/fileMessage")
            sendMessagePackToRequestedSession(
                with: baseMessage.webRequestID!,
                messagePack: createFileMessageResponse!.messagePack(),
                blackListed: false
            )
            responseUpdateMessage(
                with: id,
                message: baseMessage,
                conversation: baseMessage.conversation,
                objectMode: objectMode,
                exclude: baseMessage.webRequestID!
            )
            removeWebRequestMessage(with: baseMessage.webRequestID!)
        }
        else {
            responseUpdateMessage(
                with: id,
                message: baseMessage,
                conversation: baseMessage.conversation,
                objectMode: objectMode
            )
        }
        
        // background task to send ack to server
        let backgroundKey = kAppAckBackgroundTask + baseMessage.id.hexEncodedString()
        BackgroundTaskManager.shared.newBackgroundTask(
            key: backgroundKey,
            timeout: Int(kAppAckBackgroundTaskTime),
            completionHandler: nil
        )
        
        if backgroundIdentifier != nil {
            BackgroundTaskManager.shared.cancelBackgroundTask(key: backgroundIdentifier!)
        }
    }
        
    private func baseMessageIdentity(_ baseMessage: BaseMessage) -> String {
        if let sender = baseMessage.sender {
            return sender.identity
        }
        
        if let contact = baseMessage.conversation?.contact {
            return contact.identity
        }
        
        return MyIdentityStore.shared().identity
    }
}

extension WCSessionManager {
    // MARK: BatteryNotifications
    
    @objc func batteryLevelDidChange(_ notification: Notification) {
        let batteryResponse = WebBatteryStatusUpdate()
        DDLogVerbose("[Threema Web] MessagePack -> Send update/batteryStatus")
        sendMessagePackToAllActiveSessions(messagePack: batteryResponse.messagePack(), blackListed: true)
    }
    
    @objc func batteryStateDidChange(_ notification: Notification) {
        let batteryResponse = WebBatteryStatusUpdate()
        DDLogVerbose("[Threema Web] MessagePack -> Send update/batteryStatus")
        sendMessagePackToAllActiveSessions(messagePack: batteryResponse.messagePack(), blackListed: true)
    }
    
    // MARK: ProfileNotifications
    
    @objc func profileNicknameChanged(_ notification: Notification) {
        let profileUpdate = WebProfileUpdate(
            nicknameChanged: true,
            newNickname: MyIdentityStore.shared().pushFromName,
            newAvatar: nil,
            deleteAvatar: false
        )
        DDLogVerbose("[Threema Web] MessagePack -> Send update/profile")
        sendMessagePackToAllActiveSessions(messagePack: profileUpdate.messagePack(), blackListed: false)
    }
    
    @objc func profilePictureChanged(_ notification: Notification) {
        let profileUpdate: WebProfileUpdate? =
            if let profileDict = MyIdentityStore.shared().profilePicture as? [AnyHashable: Any] {
                if let pictureData = profileDict["ProfilePicture"] {
                    WebProfileUpdate(
                        nicknameChanged: false,
                        newNickname: nil,
                        newAvatar: pictureData as? Data,
                        deleteAvatar: false
                    )
                }
                else {
                    WebProfileUpdate(
                        nicknameChanged: false,
                        newNickname: nil,
                        newAvatar: nil,
                        deleteAvatar: true
                    )
                }
            }
            else {
                WebProfileUpdate(
                    nicknameChanged: false,
                    newNickname: nil,
                    newAvatar: nil,
                    deleteAvatar: true
                )
            }
        DDLogVerbose("[Threema Web] MessagePack -> Send update/profile")
        sendMessagePackToAllActiveSessions(messagePack: profileUpdate!.messagePack(), blackListed: false)
    }
    
    @objc func blackListChanged(_ notification: Notification) {
        let identity = notification.object as! String
        if let contact = businessInjector.entityManager.entityFetcher.contact(for: identity) {
            responseUpdateContact(contact: contact, objectMode: .modified)
        }
    }
    
    @objc func refreshDirtyObjects(_ notification: Notification) {
        if let objectID = notification.userInfo?[kKeyObjectID] as? NSManagedObjectID {
            if let managedObject = businessInjector.entityManager.entityFetcher
                .getManagedObject(by: objectID) as? NSManagedObject {
                DDLogInfo("[t-dirty-objects] Send dirty object to webclient (insert and update): \(objectID)")
                var insertedObjects = Set<NSManagedObject>()
                insertedObjects.insert(managedObject)
                handleInsertedObjects(insertedObjects: insertedObjects)
                handleUpdatedObjects(updatedObjects: insertedObjects, true)
            }
        }
    }
}
