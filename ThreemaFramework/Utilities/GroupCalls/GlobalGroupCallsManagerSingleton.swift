//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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
import Combine
import Foundation
import GroupCalls
import ThreemaEssentials
import ThreemaProtocols
import WebRTC

public final class GlobalGroupCallsManagerSingleton: NSObject {
    
    // MARK: - Public properties

    @objc public static let shared = GlobalGroupCallsManagerSingleton()
    
    public let globalGroupCallObserver = AsyncStreamContinuationToSharedPublisher<GroupCallBannerButtonUpdate>()
    
    // TODO: (IOS-4029) Is this needed?
    public var processBackgroundBusinessInjector: BusinessInjectorProtocol?

    public let httpHelper = GroupCallsSFUTokenFetcher()
    
    public weak var uiDelegate: GroupCallManagerSingletonUIDelegate?

    // MARK: - Private properties

    fileprivate let groupCallManager: GroupCallManager
        
    // TODO: (IOS-4029) Is this needed?
    fileprivate var currentBusinessInjector: BusinessInjectorProtocol {
        guard let processBackgroundBusinessInjector else {
            return businessInjector
        }
        return processBackgroundBusinessInjector
    }
    
    fileprivate let businessInjector: BusinessInjectorProtocol
    fileprivate let dependencies: Dependencies
    
    fileprivate var initialLoadTask: Task<Void, Never>?
    
    // MARK: - Lifecycle

    @available(*, unavailable)
    override public init() {
        fatalError()
    }
    
    fileprivate init(
        dependencies: Dependencies = Dependencies(
            groupCallsHTTPClientAdapter: HTTPClient(),
            httpHelper: GroupCallsSFUTokenFetcher(),
            groupCallCrypto: GroupCallCrypto(),
            groupCallDateFormatter: GroupCallDateFormatterAdapter(),
            userSettings: GroupCallUserSettings(ipv6Enabled: UserSettings.shared().enableIPv6),
            groupCallSystemMessageAdapter: GroupCallSystemMessageAdapter<BusinessInjector>(businessInjector: BusinessInjector(forBackgroundProcess: true)),
            notificationPresenterWrapper: NotificationPresenterWrapper.shared,
            groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcher.shared,
            groupCallSessionHelper: GroupCallSessionHelper.shared,
            groupCallBundleUtil: GroupCallsBundleUtil.shared,
            isRunningForScreenshots: ProcessInfoHelper.isRunningForScreenshots
        ),
        backgroundBusinessInjector: BusinessInjectorProtocol = BusinessInjector(forBackgroundProcess: true)
    ) {
        self.dependencies = dependencies
        self.businessInjector = backgroundBusinessInjector
        
        let identity = ThreemaIdentity(businessInjector.myIdentityStore.identity)
        let localContactModel = ContactModel(
            identity: identity,
            nickname: businessInjector.myIdentityStore.pushFromName ?? identity.string
        )
        
        self.groupCallManager = GroupCallManager(
            dependencies: dependencies,
            localContactModel: localContactModel
        )
        
        super.init()
        
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            return
        }
        
        Task {
            await groupCallManager.set(databaseDelegate: self)
            await groupCallManager.set(singletonDelegate: self)
            
            await self.handleCallsFromDB()
        }
    }
    
    // MARK: - Public functions
    
    public func initialCallsFromDBLoaded() async {
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return
        }
        
        if let initialLoadTask {
            await initialLoadTask.value
        }
        else {
            initialLoadTask = Task { await handleCallsFromDB() }
            await initialLoadTask?.value
        }
        
        // TODO: (IOS-4047) Should the `initialLoadTask` be reset to `nil` here?
    }
    
    @objc public func handleCallsFromDB() async {
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return
        }
        
        DDLogNotice("[GroupCall] [DB] Start loading calls from database")
        
        // We fetch all calls, that could still be running, from the db an insert them into an array
        let entityManager = currentBusinessInjector.entityManager
        let groupManager = currentBusinessInjector.groupManager
        let proposedGroupCalls = await entityManager.perform {
            entityManager.entityFetcher
                .allGroupCallEntities()
                .compactMap { groupCallEntity -> ProposedGroupCall? in
                    guard let groupCallEntity = groupCallEntity as? GroupCallEntity else {
                        return nil
                    }
                    
                    guard let creatorIdentity = groupCallEntity.group.groupCreator ?? self.businessInjector
                        .myIdentityStore.identity,
                        let group = groupManager.getGroup(groupCallEntity.group.groupID, creator: creatorIdentity)
                    else {
                        return nil
                    }
                    
                    let groupModel = GroupCallsThreemaGroupModel(
                        groupIdentity: group.groupIdentity,
                        groupName: group.name ?? ""
                    )
                    
                    var startMessage = CspE2e_GroupCallStart()
                    startMessage.sfuBaseURL = groupCallEntity.sfuBaseURL
                    startMessage.protocolVersion = groupCallEntity.protocolVersion.uint32Value
                    startMessage.gck = groupCallEntity.gck

                    let proposedGroupCall = ProposedGroupCall(
                        groupRepresentation: groupModel,
                        protocolVersion: startMessage.protocolVersion,
                        gck: startMessage.gck,
                        sfuBaseURL: startMessage.sfuBaseURL,
                        startMessageReceiveDate: groupCallEntity.startMessageReceiveDate,
                        dependencies: self.dependencies
                    )

                    DDLogNotice("[GroupCall] [DB] Load call with callID \(proposedGroupCall.hexCallID)")
                    
                    return proposedGroupCall
                }
        }
        
        DDLogNotice("[GroupCall] [DB] We have loaded \(proposedGroupCalls.count) items from the database")
        
        // For each of the fetched calls, we check if they are still running, if so we leave them
        for proposedGroupCall in proposedGroupCalls {
            Task { // TODO: (IOS-4047) Is that what we want here?
                await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)
            }
        }
    }
    
    /// Handles a group call message
    /// - Parameters:
    ///   - rawMessage: Message to be handled
    ///   - senderIdentity: Identity of the sender
    ///   - groupConversation: Group to handle message for
    ///   - receiveDate: Receive date
    ///   - onCompletion: Called after handling, run on main thread
    @objc public func handleMessage(
        rawMessage: Any,
        from senderIdentity: String,
        in groupConversation: Conversation,
        receiveDate: Date,
        onCompletion: (() -> Void)?
    ) {
        Task {
            await self.handleMessage(
                rawMessage: rawMessage,
                from: senderIdentity,
                receiveDate: receiveDate,
                in: groupConversation
            )
            
            if let onCompletion {
                DispatchQueue.main.async {
                    onCompletion()
                }
            }
        }
    }
    
    /// Handles a group call message
    /// - Parameters:
    ///   - rawMessage: Message to be handled
    ///   - senderIdentity: Identity of the sender
    ///   - receiveDate: Receive date
    ///   - groupConversation: Group to handle message for
    public func handleMessage(
        rawMessage: Any,
        from senderIdentity: String,
        receiveDate: Date,
        in groupConversation: Conversation
    ) async {
       
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            if !MDMSetup(setup: false).disableGroupCalls() {
                postGroupCallStartSystemMessage(in: groupConversation, by: senderIdentity)
            }
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return
        }
        
        guard let convRawMessage = rawMessage as? CspE2e_GroupCallStart else {
            let msg = "[GroupCall] Incorrect message type passed into \(#function)"
            assertionFailure(msg)
            DDLogError("\(msg)")
            return
        }
        
        guard await isValidSFUURL(convRawMessage.sfuBaseURL) else {
            DDLogError("[GroupCall] Received message with invalid SFU-URL: \(convRawMessage.sfuBaseURL)")
            return
        }
        
        guard let groupModel = await groupCallManager.getGroupModel(for: groupConversation.objectID) else {
            DDLogError("[GroupCall] Could not get group model for group.")
            return
        }
        
        let proposedGroupCall = ProposedGroupCall(
            groupRepresentation: groupModel,
            protocolVersion: convRawMessage.protocolVersion,
            gck: convRawMessage.gck,
            sfuBaseURL: convRawMessage.sfuBaseURL,
            startMessageReceiveDate: receiveDate,
            dependencies: dependencies
        )
        
        let wrappedMessage = WrappedGroupCallStartMessage(
            startMessage: convRawMessage,
            groupIdentity: groupModel.groupIdentity
        )
        
        await saveGroupCallStartMessage(
            for: wrappedMessage,
            with: receiveDate
        )
        
        let senderThreemaID: GroupCallCreatorOrigin = .remote(ThreemaIdentity(senderIdentity))
        
        await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: senderThreemaID)
    }
    
    @MainActor
    public func startGroupCall(
        in group: Group,
        intent: GroupCallUserIntent
    ) {
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return
        }
        
        guard !NavigationBarPromptHandler.isCallActiveInBackground else {
            uiDelegate?.showAlert(for: GroupCallError.alreadyInCall)
            return
        }
        
        guard group.hasAtLeastOneMemberSupporting(.groupCallSupport) else {
            NotificationPresenterWrapper.shared.present(type: .groupCallStartError)
            return
        }
                
        Task(priority: .userInitiated) {
            do {
                let groupModel = GroupCallsThreemaGroupModel(
                    groupIdentity: group.groupIdentity,
                    groupName: group.name ?? ""
                )
                
                try await groupCallManager.createOrJoinCall(
                    in: groupModel,
                    with: intent
                )
                
                showGroupCallViewController()
            }
            catch let error as GroupCallError {
                uiDelegate?.showAlert(for: error)
            }
            catch {
                DDLogError("[GroupCall] Caught error: \(error.localizedDescription).")
                uiDelegate?.showAlert(for: GroupCallError.creationError)
            }
        }
    }
    
    public func showGroupCallViewController() {
        Task {
            guard let uiDelegate else {
                return
            }
            guard let viewController = await groupCallManager.viewControllerForCurrentlyJoinedGroupCall() else {
                return
            }
            uiDelegate.showViewController(viewController)
        }
    }
    
    // MARK: - Private functions
    
    private func postGroupCallStartSystemMessage(in conversation: Conversation, by identity: String) {
        // TODO: (IOS-3199) Move & improve
        businessInjector.entityManager.performAndWaitSave {
            guard let fetchedConversation = self.businessInjector.entityManager.entityFetcher
                .existingObject(with: conversation.objectID) as? Conversation else {
                return
            }
            
            var displayName = identity
            if let contact = self.businessInjector.entityManager.entityFetcher.contact(for: identity) {
                displayName = contact.displayName
            }
            
            guard let dbSystemMessage = self.businessInjector.entityManager.entityCreator
                .systemMessage(for: fetchedConversation) else {
                return
            }
            
            dbSystemMessage.type = NSNumber(value: kSystemMessageGroupCallStartedBy)
            dbSystemMessage.arg = Data(displayName.utf8)
            fetchedConversation.lastMessage = dbSystemMessage
        }
    }
    
    private func getCallID(in groupModel: GroupCallsThreemaGroupModel) async -> String? {
        await groupCallManager.getCallID(in: groupModel)
    }
    
    private func saveGroupCallStartMessage(
        for wrappedMessage: WrappedGroupCallStartMessage,
        with receiveDate: Date = Date.now
    ) async {
        guard businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Skip.")
            return
        }
        let addedObject: NSManagedObjectID? = await currentBusinessInjector.entityManager.performSave {

            guard let groupEntity = self.currentBusinessInjector.entityManager.entityFetcher.groupEntity(
                for: wrappedMessage.groupIdentity.id,
                with: wrappedMessage.groupIdentity.creator.string
            ) else {
                DDLogError("[GroupCall] Could not find group entity for group call message.")
                return nil
            }
            
            assert(!groupEntity.groupID.isEmpty)
            
            // Setup group call
            let groupCallEntity = self.currentBusinessInjector.entityManager.entityCreator.groupCallEntity()
            groupCallEntity?.group = groupEntity
            groupCallEntity?.gck = wrappedMessage.startMessage.gck
            groupCallEntity?.protocolVersion = NSNumber(value: wrappedMessage.startMessage.protocolVersion)
            groupCallEntity?.sfuBaseURL = wrappedMessage.startMessage.sfuBaseURL
            groupCallEntity?.startMessageReceiveDate = receiveDate
            
            DDLogNotice("[GroupCall] [DB] Saved group call to database.")
            
            return groupCallEntity?.objectID
        }
        
        // Mark entity as dirty
        currentBusinessInjector.entityManager.performBlock {
            guard let addedObject else {
                DDLogError("[GroupCall] Could not mark added group call as dirty.")
                return
            }
            
            DatabaseManager().addDirtyObjectID(addedObject)
        }
    }
    
    private func isValidSFUURL(_ baseURL: String) async -> Bool {
        do {
            let token = try await httpHelper.sfuCredentials()
            // When receiving the SFU information, ensure the _SFU Base URL_ uses the scheme
            // `https` and the included hostname ends with one of the _Allowed SFU Hostname
            // Suffixes_.
            return token.isAllowedBaseURL(baseURL: baseURL)
        }
        catch {
            DDLogError("[GroupCall] Invalid baseURL: \(baseURL)")
            return false
        }
    }
}

// MARK: - Debug Call Start Functions

extension GlobalGroupCallsManagerSingleton {
    #if DEBUG
        public func asyncHandleMessage(
            rawMessage: Any,
            groupModel: GroupCallsThreemaGroupModel,
            messageReceiveDate: Date
        ) async {
            guard let convRawMessage = rawMessage as? CspE2e_GroupCallStart else {
                fatalError()
            }
        
            let proposedGroupCall = ProposedGroupCall(
                groupRepresentation: groupModel,
                protocolVersion: convRawMessage.protocolVersion,
                gck: convRawMessage.gck,
                sfuBaseURL: convRawMessage.sfuBaseURL,
                startMessageReceiveDate: messageReceiveDate,
                dependencies: dependencies
            )
        
            await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .local)
        }
    
        public func startAndJoinDebugCall(groupModel: GroupCallsThreemaGroupModel) async {
            let rawGroupCall = ""
        
            let rawData = rawGroupCall.hexadecimal!
        
            var newMessage = CspE2e_GroupCallStart()
            newMessage.gck = rawData
            newMessage.protocolVersion = 1
            newMessage.sfuBaseURL = ""
        
            await asyncHandleMessage(
                rawMessage: newMessage,
                groupModel: groupModel,
                messageReceiveDate: Date()
            )
            
            try! await Task.sleep(seconds: 1)
            try! await groupCallManager.createOrJoinCall(in: groupModel, with: .createOrJoin)
        }
    #endif

    public static func sendDebugInitMessages(
        for conversationObjectID: NSManagedObjectID,
        and groupModel: GroupCallsThreemaGroupModel,
        startMessage: ThreemaProtocols.CspE2e_GroupCallStart
    ) async {
        try! await Task.sleep(seconds: 1)
        
        var groupDict = [String: String]()
        var memberDict = [[String: String]]()
        
        let businessInjector = BusinessInjector()
        businessInjector.entityManager.performBlockAndWait {
            let conversation = businessInjector.entityManager.entityFetcher
                .existingObject(with: conversationObjectID) as! Conversation
            
            if UserSettings.shared().groupCallsDebugMessages {
                groupDict["creator"] = conversation.contact?.identity ?? businessInjector.myIdentityStore.identity
                groupDict["id"] = conversation.groupID!.base64EncodedString()
                
                let myMember: [String: String] = [
                    "identity": businessInjector.myIdentityStore.identity,
                    "publicKey": MyIdentityStore.shared().publicKey.base64EncodedString(),
                ]
                
                memberDict = conversation.members
                    .map { ["identity": $0.identity, "publicKey": $0.publicKey.base64EncodedString()] } + [myMember]
            }
        }
        
        var dict = [String: Any]()
        dict["type"] = "group-call"
        dict["protocolVersion"] = 1
        dict["group"] = groupDict
        dict["members"] = memberDict
        dict["gck"] = startMessage.gck.base64EncodedString()
        dict["sfuBaseUrl"] = startMessage.sfuBaseURL
        
        let callInfoString = Data(try! JSONSerialization.data(withJSONObject: dict)).base64EncodedString()
        guard let callIDString = await GlobalGroupCallsManagerSingleton.shared.getCallID(in: groupModel) else {
            assertionFailure("Could not retrieve CallID for Debug Call.")
            return
        }
        
        businessInjector.entityManager.performBlockAndWait {
            let conversation = businessInjector.entityManager.entityFetcher
                .existingObject(with: conversationObjectID) as! Conversation
            
            businessInjector.messageSender.sendTextMessage(text: "*CallID*", in: conversation, quickReply: false)
            businessInjector.messageSender.sendTextMessage(
                text: callIDString,
                in: conversation,
                quickReply: false,
                requestID: nil
            )
            
            businessInjector.messageSender.sendTextMessage(
                text: "*CallInfo*",
                in: conversation,
                quickReply: false,
                requestID: nil
            )
            businessInjector.messageSender.sendTextMessage(
                text: callInfoString,
                in: conversation,
                quickReply: false,
                requestID: nil
            )
            
            businessInjector.messageSender.sendTextMessage(
                text: "*GCK*",
                in: conversation,
                quickReply: false,
                requestID: nil
            )
            businessInjector.messageSender.sendTextMessage(
                text: "\(startMessage.gck.hexEncodedString())",
                in: conversation,
                quickReply: false,
                requestID: nil
            )
        }
    }
}

extension GlobalGroupCallsManagerSingleton {
    private func sendGroupCallStartMessage(_ message: CspE2e_GroupCallStart, to group: Group) async throws {
        let frameworkInjector = BusinessInjector()
        
        let taskDefinition = TaskDefinitionSendGroupCallStartMessage(
            group: group,
            from: frameworkInjector.myIdentityStore.identity,
            to: group.members.map(\.identity.string),
            groupCallStartMessage: message,
            sendContactProfilePicture: true
        )
        
        TaskManager().add(taskDefinition: taskDefinition)
    }
}

// MARK: - GroupCallManagerDatabaseDelegateProtocol

extension GlobalGroupCallsManagerSingleton: GroupCallManagerDatabaseDelegateProtocol {
    public func removeFromStoredCalls(_ proposedGroupCall: ProposedGroupCall) {
        currentBusinessInjector.entityManager.performBlockAndWait {
            let toDeleteGroupCalls = self.currentBusinessInjector.entityManager.entityFetcher
                .allGroupCallEntities().compactMap { groupCallEntity -> GroupCallEntity? in
                    guard let groupCallEntity = groupCallEntity as? GroupCallEntity else {
                        return nil
                    }
                    
                    guard groupCallEntity.gck == proposedGroupCall.gck else {
                        return nil
                    }
                    
                    guard groupCallEntity.sfuBaseURL == proposedGroupCall.sfuBaseURL else {
                        return nil
                    }
                    
                    guard groupCallEntity.group.groupID == proposedGroupCall.groupRepresentation.groupIdentity.id else {
                        return nil
                    }
                    
                    let remoteAdminsAreEqual = groupCallEntity.group.groupCreator == proposedGroupCall
                        .groupRepresentation.groupIdentity.creator.string
                    let localAdminsAreEqual = (
                        groupCallEntity.group.groupCreator == nil && proposedGroupCall
                            .groupRepresentation.groupIdentity.creator.string == self.businessInjector.myIdentityStore
                            .identity
                    )
                    
                    guard remoteAdminsAreEqual || localAdminsAreEqual else {
                        return nil
                    }
                    
                    return groupCallEntity
                }
            
            // Delete found old calls
            self.currentBusinessInjector.entityManager.performSyncBlockAndSafe {
                for toDeleteGroupCall in toDeleteGroupCalls {
                    self.currentBusinessInjector.entityManager.entityDestroyer
                        .deleteObject(object: toDeleteGroupCall)
                }
                DDLogNotice("[GroupCall] [DB] Deleted \(toDeleteGroupCalls.count)")
            }
        }
    }
}

// MARK: - GroupCallManagerSingletonDelegate

extension GlobalGroupCallsManagerSingleton: GroupCallManagerSingletonDelegate {
    public func showGroupCallViewController(viewController: GroupCallViewController) {
        guard let uiDelegate else {
            DDLogError("[GroupCall] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }
        
        uiDelegate.showViewController(viewController)
    }
    
    public func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCalls.GroupCallBannerButtonUpdate) {
        globalGroupCallObserver.stateContinuation.yield(groupCallBannerButtonUpdate)
    }
    
    public func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws {
        guard let group = businessInjector.groupManager.getGroup(
            wrappedMessage.groupIdentity.id,
            creator: wrappedMessage.groupIdentity.creator.string
        ) else {
            return
        }
            
        await saveGroupCallStartMessage(for: wrappedMessage)
            
        try await sendGroupCallStartMessage(wrappedMessage.startMessage, to: group)
    }
    
    public func showIncomingGroupCallNotification(
        groupModel: GroupCalls.GroupCallsThreemaGroupModel,
        senderThreemaID: ThreemaIdentity
    ) {
        guard let uiDelegate else {
            DDLogError("[GroupCall] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }
        
        currentBusinessInjector.entityManager.performBlock {
            guard let conversation = self.currentBusinessInjector.entityManager.entityFetcher.conversation(
                for: groupModel.groupIdentity.id,
                creator: groupModel.groupIdentity.creator.string
            ) else {
                return
            }
            
            guard conversation.conversationCategory != .private else {
                uiDelegate.newBannerForStartGroupCall(
                    conversationManagedObjectID: conversation.objectID,
                    title: BundleUtil.localizedString(forKey: "private_message_label"),
                    body: " ",
                    contactImage: AvatarMaker.shared().unknownGroupImage()!,
                    identifier: groupModel.groupIdentity.id.hexString
                )
                return
            }
            
            guard let contact = self.currentBusinessInjector.entityManager.entityFetcher
                .contact(for: senderThreemaID.string) else {
                return
            }
            
            let title = conversation.displayName
            let body = String(
                format: BundleUtil.localizedString(forKey: "group_call_started_by_contact_system_message"),
                contact.displayName
            )
            let conversationObjectID = conversation.objectID
            AvatarMaker.shared().avatar(for: conversation, size: 56.0, masked: true) { conversationImage, _ in
                uiDelegate.newBannerForStartGroupCall(
                    conversationManagedObjectID: conversationObjectID,
                    title: title ?? "",
                    body: body,
                    contactImage: conversationImage ?? AvatarMaker.shared().unknownGroupImage()!,
                    identifier: groupModel.groupIdentity.id.hexString
                )
            }
        }
    }
    
    public func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        uiDelegate?.showGroupCallFullAlert(maxParticipants: maxParticipants, onOK: onOK)
    }
}

extension GlobalGroupCallsManagerSingleton {
    /// Only use when running screenshots
    public func startGroupCallForScreenshots(group: Group) {
        guard ProcessInfoHelper.isRunningForScreenshots else {
            assertionFailure("This should only be called during screenshots.")
            return
        }
        
        Task {
            let groupCallViewControllerForScreenshots = await groupCallManager.groupCallViewControllerForScreenshots(
                groupName: group.name!,
                localID: businessInjector.myIdentityStore.identity,
                participantThreemaIdentities: group.members.map(\.identity)
            )
            
            uiDelegate?.showViewController(groupCallViewControllerForScreenshots)
        }
    }
}
