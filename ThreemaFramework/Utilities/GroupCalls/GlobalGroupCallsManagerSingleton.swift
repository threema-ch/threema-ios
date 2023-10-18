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
    public var processBusinessInjector: BusinessInjectorProtocol?
    
    public let httpHelper = GroupCallsSFUTokenFetcher()
    
    public weak var uiDelegate: GroupCallManagerSingletonUIDelegate?

    // MARK: - Private properties

    fileprivate let groupCallManager: GroupCallManager
        
    // TODO: (IOS-4029) Is this needed?
    fileprivate var currentBusinessInjector: BusinessInjectorProtocol {
        guard let processBusinessInjector else {
            return businessInjector
        }
        return processBusinessInjector
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
            groupCallSystemMessageAdapter: GroupCallSystemMessageAdapter<BusinessInjector>(businessInjector: BusinessInjector()),
            notificationPresenterWrapper: NotificationPresenterWrapper.shared,
            groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcher.shared,
            groupCallSessionHelper: GroupCallSessionHelper.shared,
            groupCallBundleUtil: GroupCallsBundleUtil.shared
        ),
        businessInjector: BusinessInjectorProtocol = BusinessInjector()
    ) {
        self.dependencies = dependencies
        self.businessInjector = businessInjector
        
        self.groupCallManager = GroupCallManager(
            dependencies: dependencies,
            localIdentity: businessInjector.myIdentityStore.identity
        )
        
        super.init()
        
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
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
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
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
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        
        DDLogNotice("[GroupCall] [DB] Start loading calls from database")
        
        // We fetch all calls, that could still be running, from the db an insert them into an array
        let entityManager = currentBusinessInjector.backgroundEntityManager
        let groupManager = GroupManager()
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
                    
                    let groupCreatorID: String = creatorIdentity
                    let groupCreatorNickname: String? = group.groupCreatorNickname
                    let groupID = group.groupID
                    let members = group.members
                        .compactMap { try? ThreemaID(id: $0.identity, nickname: $0.publicNickname) }

                    // TODO: (IOS-4124) Remove force-unwrapped try
                    let groupModel = GroupCallsThreemaGroupModel(
                        creator: try! ThreemaID(id: groupCreatorID, nickname: groupCreatorNickname),
                        groupID: groupID,
                        groupName: group.name ?? "",
                        members: Set(members)
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
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            onCompletion?()
            return
        }
        
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
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        
        guard let convRawMessage = rawMessage as? CspE2e_GroupCallStart else {
            let msg = "[GroupCall] Incorrect message type passed into \(#function)"
            assertionFailure(msg)
            DDLogError(msg)
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
        
        await saveGroupCallStartMessage(
            for: convRawMessage,
            with: receiveDate,
            creatorID: groupModel.creator,
            groupID: groupModel.groupID
        )
        
        // TODO: (IOS-4124) Remove force-unwrapped try
        let senderThreemaID: GroupCallCreatorOrigin = .remote(try! ThreemaID(id: senderIdentity, nickname: nil))
        
        await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: senderThreemaID)
    }
    
    @MainActor
    public func startGroupCall(
        in group: Group,
        intent: GroupCallUserIntent
    ) {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        
        Task {
            do {
                let groupCreatorID: String = group.groupCreatorIdentity
                let groupCreatorNickname: String? = group.groupCreatorNickname
                let groupID = group.groupID
                let members = group.members.compactMap { try? ThreemaID(id: $0.identity, nickname: $0.publicNickname) }
                
                // TODO: (IOS-4124) Remove force-unwrapped try
                let groupModel = GroupCallsThreemaGroupModel(
                    creator: try! ThreemaID(id: groupCreatorID, nickname: groupCreatorNickname),
                    groupID: groupID,
                    groupName: group.name ?? "",
                    members: Set(members)
                )
                
                let myIdentity = try ThreemaID(
                    id: MyIdentityStore.shared().identity,
                    nickname: MyIdentityStore.shared().pushFromName
                )
                
                try await groupCallManager.createOrJoinCall(
                    in: groupModel,
                    with: intent,
                    localIdentity: myIdentity
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
    
    // MARK: - Private functions

    private func getCallID(in groupModel: GroupCallsThreemaGroupModel) async -> String {
        await groupCallManager.getCallID(in: groupModel)
    }
    
    public func groupCallViewController(for viewModel: GroupCallViewModel) -> UIViewController {
        GroupCallViewController(viewModel: viewModel, dependencies: dependencies)
    }

    // MARK: - UI
                
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

    private func saveGroupCallStartMessage(
        for convRawMessage: CspE2e_GroupCallStart,
        with receiveDate: Date = Date.now,
        creatorID: ThreemaID,
        groupID: Data
    ) async {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        let addedObject: NSManagedObjectID? = await currentBusinessInjector.backgroundEntityManager.performSave {
            
            guard let groupEntity = self.currentBusinessInjector.backgroundEntityManager.entityFetcher.groupEntity(
                for: groupID,
                with: creatorID.id
            ) else {
                DDLogError("[GroupCall] Could not find group entity for group call message.")
                return nil
            }
            
            assert(!groupEntity.groupID.isEmpty)
            
            // Setup group call
            let groupCallEntity = self.currentBusinessInjector.backgroundEntityManager.entityCreator.groupCallEntity()
            groupCallEntity?.group = groupEntity
            groupCallEntity?.gck = convRawMessage.gck
            groupCallEntity?.protocolVersion = NSNumber(value: convRawMessage.protocolVersion)
            groupCallEntity?.sfuBaseURL = convRawMessage.sfuBaseURL
            groupCallEntity?.startMessageReceiveDate = receiveDate
            
            DDLogNotice("[GroupCall] [DB] Saved group call to database.")
            
            return groupCallEntity?.objectID
        }
        
        // Mark entity as dirty
        currentBusinessInjector.backgroundEntityManager.performBlock {
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
        
            let myIdentity = try! ThreemaID(
                id: MyIdentityStore.shared().identity,
                nickname: MyIdentityStore.shared().pushFromName
            )
            
            try! await groupCallManager.createOrJoinCall(in: groupModel, with: .createOrJoin, localIdentity: myIdentity)
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
        businessInjector.backgroundEntityManager.performBlockAndWait {
            let conversation = businessInjector.backgroundEntityManager.entityFetcher
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
        let callIDString = await GlobalGroupCallsManagerSingleton.shared.getCallID(in: groupModel)
        
        businessInjector.backgroundEntityManager.performBlockAndWait {
            let conversation = businessInjector.backgroundEntityManager.entityFetcher
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
            to: group.members.map(\.identity),
            groupCallStartMessage: message,
            sendContactProfilePicture: true
        )
        
        TaskManager().add(taskDefinition: taskDefinition)
    }
}

// MARK: - GroupCallManagerDatabaseDelegateProtocol

extension GlobalGroupCallsManagerSingleton: GroupCallManagerDatabaseDelegateProtocol {
    public func removeFromStoredCalls(_ proposedGroupCall: ProposedGroupCall) {
        currentBusinessInjector.backgroundEntityManager.performBlockAndWait {
            let toDeleteGroupCalls = self.currentBusinessInjector.backgroundEntityManager.entityFetcher
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
                    
                    guard groupCallEntity.group.groupID == proposedGroupCall.groupRepresentation.groupID else {
                        return nil
                    }
                    
                    let remoteAdminsAreEqual = groupCallEntity.group.groupCreator == proposedGroupCall
                        .groupRepresentation.creator.id
                    let localAdminsAreEqual = (
                        groupCallEntity.group.groupCreator == nil && proposedGroupCall
                            .groupRepresentation.creator.id == self.businessInjector.myIdentityStore.identity
                    )
                    
                    guard remoteAdminsAreEqual || localAdminsAreEqual else {
                        return nil
                    }
                    
                    return groupCallEntity
                }
            
            // Delete found old calls
            self.currentBusinessInjector.backgroundEntityManager.performSyncBlockAndSafe {
                for toDeleteGroupCall in toDeleteGroupCalls {
                    self.currentBusinessInjector.backgroundEntityManager.entityDestroyer
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
            wrappedMessage.groupID,
            creator: wrappedMessage.creatorID.id
        ) else {
            return
        }
            
        await saveGroupCallStartMessage(
            for: wrappedMessage.startMessage,
            creatorID: wrappedMessage.creatorID,
            groupID: wrappedMessage.groupID
        )
            
        try await sendGroupCallStartMessage(wrappedMessage.startMessage, to: group)
    }
    
    public func showIncomingGroupCallNotification(
        groupModel: GroupCalls.GroupCallsThreemaGroupModel,
        senderThreemaID: ThreemaID
    ) {
        guard let uiDelegate else {
            DDLogError("[GroupCall] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }
        
        currentBusinessInjector.backgroundEntityManager.performBlock {
            guard let conversation = self.currentBusinessInjector.backgroundEntityManager.entityFetcher.conversation(
                for: groupModel.groupID,
                creator: groupModel.creator.id
            ) else {
                return
            }
            
            guard conversation.conversationCategory != .private else {
                uiDelegate.newBannerForStartGroupCall(
                    conversationManagedObjectID: conversation.objectID,
                    title: BundleUtil.localizedString(forKey: "private_message_label"),
                    body: " ",
                    contactImage: AvatarMaker.shared().unknownGroupImage()!,
                    identifier: groupModel.groupID.hexString
                )
                return
            }
            
            guard let contact = self.currentBusinessInjector.backgroundEntityManager.entityFetcher
                .contact(for: senderThreemaID.id) else {
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
                    identifier: groupModel.groupID.hexString
                )
            }
        }
    }
}
