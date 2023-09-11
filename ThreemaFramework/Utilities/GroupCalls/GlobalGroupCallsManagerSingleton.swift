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
import ThreemaProtocols
import WebRTC

@objc public final class GlobalGroupCallsManagerSingleton: NSObject {
    @objc public static let shared = GlobalGroupCallsManagerSingleton()
    
    public let groupCallManager: GroupCallManager
    
    public var processBusinessInjector: BusinessInjectorProtocol?
    
    public let httpHelper = GroupCallsSFUTokenFetcher()
    
    fileprivate var currentBusinessInjector: BusinessInjectorProtocol {
        guard let processBusinessInjector else {
            return businessInjector
        }
        return processBusinessInjector
    }
    
    fileprivate let businessInjector: BusinessInjectorProtocol
    fileprivate let dependencies: Dependencies
    
    fileprivate var initialLoadTask: Task<Void, Never>?
    
    @available(*, unavailable)
    override public init() {
        fatalError()
    }
    
    fileprivate init(dependencies: Dependencies = Dependencies(
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
    ), businessInjector: BusinessInjectorProtocol = BusinessInjector()) {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            fatalError()
        }
        
        self.dependencies = dependencies
        self.businessInjector = businessInjector
        
        self.groupCallManager = GroupCallManager(
            dependencies: dependencies,
            localIdentity: businessInjector.myIdentityStore.identity
        )
        
        super.init()
        
        Task {
            await groupCallManager.set(databaseDelegate: self)
            
            await self.handleCallsFromDB()
        }
    }
    
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
    }
    
    @objc public func handleCallsFromDB() async {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        
        DDLogNotice("[GroupCall] [DB] Start loading calls from database")
        
        // We fetch all calls, that could still be running, from the db an insert them into an array
        let entityManager = currentBusinessInjector.backgroundEntityManager
        let proposedGroupCalls = await entityManager.perform {
            entityManager.entityFetcher
                .allGroupCallEntities()
                .compactMap { groupCallEntity -> ProposedGroupCall? in
                    guard let groupCallEntity = groupCallEntity as? GroupCallEntity else {
                        return nil
                    }
                    
                    guard let creatorIdentity = groupCallEntity.group.groupCreator ?? self.businessInjector
                        .myIdentityStore.identity,
                        let group = GroupManager().getGroup(groupCallEntity.group.groupID, creator: creatorIdentity)
                    else {
                        return nil
                    }
                    
                    let groupCreatorID: String = creatorIdentity
                    let groupCreatorNickname: String? = group.groupCreatorNickname
                    let groupID = group.groupID
                    let members = group.members
                        .compactMap { try? ThreemaID(id: $0.identity, nickname: $0.publicNickname) }
                    
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
            Task {
                await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .db)
            }
        }
    }
    
    /// Handles a group call message
    /// - Parameters:
    ///   - rawMessage: Message to be handled
    ///   - senderIdentity: Identity of the sender
    ///   - groupConversation: Group to handle message for
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
    ///   - groupConversation: Group to handle message for
    public func handleMessage(
        rawMessage: Any,
        from senderIdentity: String?,
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
        
        do {
            try await saveGroupCallStartMessage(
                for: convRawMessage,
                with: receiveDate,
                in: groupModel,
                in: groupConversation
            )
        }
        catch {
            // TODO: (IOS-3813) Filter error and print its desc
            // We do not return here to still make it possible to join call.
            DDLogError(
                "[GroupCall] Could not save group call start message. Error: \(error.localizedDescription). GroupID: \(groupModel.groupID)"
            )
        }
        
        let senderThreemaID: GroupCallCreatorOrigin
        if let senderIdentity {
            senderThreemaID = .remote(try! ThreemaID(id: senderIdentity, nickname: nil))
        }
        else {
            senderThreemaID = .local
        }
        
        await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: senderThreemaID)
    }
    
    private func saveGroupCallStartMessage(
        for convRawMessage: CspE2e_GroupCallStart,
        with receiveDate: Date,
        in groupModel: GroupCallsThreemaGroupModel,
        in groupConversation: Conversation
    ) async throws {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return
        }
        var addedObject: NSManagedObjectID?

        try await currentBusinessInjector.backgroundEntityManager.performSave {

            guard let conversation = self.currentBusinessInjector.backgroundEntityManager.entityFetcher
                .existingObject(with: groupConversation.objectID) as? Conversation,
                let groupEntity = self.currentBusinessInjector.backgroundEntityManager.entityFetcher
                .groupEntity(for: conversation) else {
                DDLogError("[GroupCall] Could not find group entity for group call message")
                throw GroupCallError.groupNotFound
            }
            
            assert(!groupEntity.groupID.isEmpty)
            
            // Setup group call
            let groupCallEntity = self.currentBusinessInjector.backgroundEntityManager.entityCreator
                .groupCallEntity()
            groupCallEntity?.group = groupEntity
            groupCallEntity?.gck = convRawMessage.gck
            groupCallEntity?.protocolVersion = NSNumber(value: convRawMessage.protocolVersion)
            groupCallEntity?.sfuBaseURL = convRawMessage.sfuBaseURL
            groupCallEntity?.startMessageReceiveDate = receiveDate
            
            addedObject = groupCallEntity?.objectID
            
            DDLogNotice("[GroupCall] [DB] Saved group call to database")
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
    
    /// Starts a group call from local interaction
    /// - Parameters:
    ///   - groupModel: Model of group the call should be started for
    ///   - localIdentity: Local ThreemaID
    /// - Returns: Start message ???
    public func startGroupCall(
        groupModel: GroupCallsThreemaGroupModel,
        localIdentity: ThreemaID
    ) async throws -> CspE2e_GroupCallStart? {
        
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return nil
        }
        
        let message = try await groupCallManager.createCall(in: groupModel, localIdentity: localIdentity)
        
        var conversation: Conversation!
        
        await currentBusinessInjector.backgroundEntityManager.perform {
            conversation = self.currentBusinessInjector.backgroundEntityManager.entityFetcher.conversation(
                for: groupModel.groupID,
                creator: groupModel.creator.id
            )
        }
        
        try await saveGroupCallStartMessage(for: message, with: Date(), in: groupModel, in: conversation)
        
        return message
    }
    
    public func joinCall(in groupModel: GroupCallsThreemaGroupModel) async -> GroupCallViewModel? {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return nil
        }
        
        return await groupCallManager.joinCall(in: groupModel, intent: .join)
    }
    
    public func viewModel(for group: GroupCallsThreemaGroupModel) async -> GroupCallViewModel? {
        guard ThreemaEnvironment.groupCalls, businessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[GroupCall] GroupCalls are not yet enabled. Skip.")
            return nil
        }
        
        await initialCallsFromDBLoaded()
        
        return await groupCallManager.viewModel(for: group)
    }
    
    public func groupCallViewController(for viewModel: GroupCallViewModel) -> UIViewController {
        GroupCallViewController(viewModel: viewModel, dependencies: dependencies)
    }
    
    @MainActor
    public func getViewControllerForCurrentlyJoinedGroupCall() async -> UIViewController? {
        
        let task = Task { () -> GroupCallViewModel? in
            await groupCallManager.viewModelForCurrentlyJoinedGroupCall()
        }
        
        // TODO: (IOS-3813) Show error msgs and leave call
        guard let viewModel = try? await task.result.get() else {
            return nil
        }
        
        return GroupCallViewController(viewModel: viewModel, dependencies: dependencies)
    }
    
    public func getCallID(in groupModel: GroupCallsThreemaGroupModel) async -> String {
        await groupCallManager.getCallID(in: groupModel)
    }
    
    // TODO: (IOS-3813) Make this throw instead of bool
    private func isValidSFUURL(_ baseURL: String) async -> Bool {
        do {
            let token = try await httpHelper.sfuCredentials()
            return token.isAllowedBaseURL(baseURL: baseURL)
        }
        catch {
            DDLogError("[GroupCall] Invalid baseURL: \(baseURL)")
            return false
        }
    }

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

// MARK: - Debug Call Start Functions

#if DEBUG
    extension GlobalGroupCallsManagerSingleton {
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
    
        public func startAndJoinDebugCall(groupModel: GroupCallsThreemaGroupModel) async -> GroupCallViewModel {
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
            
            if #available(iOSApplicationExtension 16.0, *) {
                try! await Task.sleep(for: .seconds(1))
            }
            else {
                // Fallback on earlier versions
            }
        
            return await groupCallManager.joinCall(in: groupModel, intent: .create)!
        }
    }
#endif

extension GlobalGroupCallsManagerSingleton {
    @MainActor
    public func startGroupCall(
        in conversation: Conversation,
        with identity: String
    ) async throws -> GroupCallViewModel {

        guard let group = GroupManager().getGroup(conversation: conversation) else {
            DDLogError("[GroupCall] Could not get group to start a group call.")
            throw GroupCallError.creationError
        }
        
        let groupCreatorID: String = group.groupCreatorIdentity
        let groupCreatorNickname: String? = group.groupCreatorNickname
        let groupID = group.groupID
        let members = group.members.compactMap { try? ThreemaID(id: $0.identity, nickname: $0.publicNickname) }
        
        let groupModel = GroupCallsThreemaGroupModel(
            creator: try! ThreemaID(id: groupCreatorID, nickname: groupCreatorNickname),
            groupID: groupID,
            groupName: group.name ?? "",
            members: Set(members)
        )
        
        let myIdentity = try ThreemaID(id: identity, nickname: MyIdentityStore.shared().pushFromName)
        
        let (groupCallStartMessage, viewModel) = try await startGroupCall(in: groupModel, with: myIdentity)
        
        guard let viewModel else {
            throw GroupCallError.creationError
        }
                
        if UserSettings.shared().groupCallsDebugMessages, let groupCallStartMessage {
            Task.detached {
                try! await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                
                await GlobalGroupCallsManagerSingleton.sendDebugInitMessages(
                    for: conversation.objectID,
                    and: groupModel,
                    startMessage: groupCallStartMessage
                )
            }
        }
        
        if let groupCallStartMessage {
            try GlobalGroupCallsManagerSingleton.send(from: groupCallStartMessage, conversation: conversation)
        }
        
        return viewModel
    }
    
    public func startGroupCall(
        in groupModel: GroupCallsThreemaGroupModel,
        with localIdentity: ThreemaID
    ) async throws -> (CspE2e_GroupCallStart?, GroupCallViewModel?) {
        #if DEBUG
            let debugCall = false
        
            guard !debugCall else {
                let viewModel = await GlobalGroupCallsManagerSingleton.shared
                    .startAndJoinDebugCall(groupModel: groupModel)
                return (nil, viewModel)
            }
        #endif
        
        var groupCallStartMessage: CspE2e_GroupCallStart?
        
        do {
            groupCallStartMessage = try await GlobalGroupCallsManagerSingleton.shared.startGroupCall(
                groupModel: groupModel,
                localIdentity: localIdentity
            )
        }
        catch {
            guard let error = error as? GroupCallManager.GroupCallManagerError,
                  error == .cannotJoinAlreadyInACall else {
                throw error
            }
        }
        
        guard let viewModel = await GlobalGroupCallsManagerSingleton.shared.joinCall(in: groupModel) else {
            throw GroupCallError.creationError
        }
        
        return (groupCallStartMessage, viewModel)
    }
}

extension GlobalGroupCallsManagerSingleton {
    public static func send(from message: CspE2e_GroupCallStart, conversation: Conversation) throws {
        let frameworkInjector = BusinessInjector()
        
        var group: Group!
        
        frameworkInjector.entityManager.performBlockAndWait {
            // TODO: (IOS-3813) This should throw, use async EM
            guard let groupEntity = frameworkInjector.entityManager.entityFetcher.groupEntity(for: conversation) else {
                DDLogError("[GroupCall] Could not get group to send a group call start message.")
                return
            }
            
            group = Group(
                myIdentityStore: frameworkInjector.myIdentityStore,
                userSettings: frameworkInjector.userSettings,
                groupEntity: groupEntity,
                conversation: conversation,
                lastSyncRequest: nil
            )
        }
        
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
    // TODO: (IOS-3813) Make throwing?
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
