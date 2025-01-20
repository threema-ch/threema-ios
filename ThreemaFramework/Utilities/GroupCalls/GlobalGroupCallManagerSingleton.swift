//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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
import ThreemaMacros
import ThreemaProtocols
import WebRTC

/// Entry point to group calls from app
public final class GlobalGroupCallManagerSingleton: NSObject {
    
    // MARK: - Public properties
    
    /// An injected Business Injector.
    /// This can be set such the the singleton will always use this Business Injector instead of a new one (e.g. from
    /// the notification extension)
    public static var injectedBackgroundBusinessInjector: BusinessInjectorProtocol?

    @objc public static let shared = GlobalGroupCallManagerSingleton()
    
    public let globalGroupCallObserver = AsyncStreamContinuationToSharedPublisher<GroupCallBannerButtonUpdate>()
    
    public weak var uiDelegate: GroupCallManagerSingletonUIDelegate?

    // MARK: - Private properties

    private let dependencies: Dependencies
    
    // Never use this one. Always use `currentBusinessInjector` directly
    private let businessInjector: BusinessInjectorProtocol
    
    private var currentBusinessInjector: BusinessInjectorProtocol {
        guard let processBackgroundBusinessInjector = GlobalGroupCallManagerSingleton
            .injectedBackgroundBusinessInjector else {
            return businessInjector
        }
        return processBackgroundBusinessInjector
    }
    
    private let groupCallManager: GroupCallManager
    private let httpHelper = GroupCallSFUTokenFetcher()
    
    private var initialLoadTask: Task<Void, Never>?
    
    // MARK: - Lifecycle

    @available(*, unavailable)
    override public init() {
        fatalError()
    }
    
    fileprivate init(
        dependencies: Dependencies = Dependencies(
            groupCallsHTTPClientAdapter: HTTPClient(),
            httpHelper: GroupCallSFUTokenFetcher(),
            groupCallCrypto: GroupCallCrypto(),
            groupCallDateFormatter: GroupCallDateFormatterAdapter(),
            userSettings: GroupCallUserSettings(
                ipv6Enabled: UserSettings.shared().enableIPv6,
                disableProximityMonitoring: UserSettings.shared().disableProximityMonitoring
            ),
            groupCallSystemMessageAdapter: GroupCallSystemMessageAdapter<BusinessInjector>(
                businessInjector: BusinessInjector(forBackgroundProcess: true)
            ),
            notificationPresenterWrapper: NotificationPresenterWrapper.shared,
            groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcher.shared,
            groupCallSessionHelper: GroupCallSessionHelper.shared,
            groupCallBundleUtil: GroupCallBundleUtil.shared,
            isRunningForScreenshots: ProcessInfoHelper.isRunningForScreenshots
        ),
        backgroundBusinessInjector: BusinessInjectorProtocol = BusinessInjector(forBackgroundProcess: true)
    ) {
        self.dependencies = dependencies
        self.businessInjector = backgroundBusinessInjector
        
        // In theory we should use `currentBusinessInjector` here, but we cannot access `self` and it is not that
        // significant for these accessed values
        
        // TODO: (IOS-4674) A nickname change will not be reflected until the app is fully terminated again
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
        
        self.initialLoadTask = Task {
            await handleCallsFromDB()
        }
        
        Task {
            await groupCallManager.set(databaseDelegate: self)
            await groupCallManager.set(singletonDelegate: self)
            
            await initialLoadTask?.value
            self.initialLoadTask = nil
        }
    }
    
    // MARK: - Public functions
        
    /// Load calls from DB
    ///
    /// If the manager is still doing the initial load we'll just wait for that
    @objc public func loadCallsFromDB() async {
        if let initialLoadTask {
            await initialLoadTask.value
        }
        else {
            await handleCallsFromDB()
        }
    }
    
    private func handleCallsFromDB() async {
        DDLogNotice("[GroupCall] [DB] Start loading calls from database.")
        
        let entityManager = currentBusinessInjector.entityManager
        let groupManager = currentBusinessInjector.groupManager
        
        // We fetch all calls, that could still be running, from the db an insert them into an array
        let storedGroupCalls = await entityManager.perform {
            entityManager.entityFetcher.allGroupCallEntities()
        }
        
        guard !storedGroupCalls.isEmpty else {
            DDLogNotice("[GroupCall] [DB] No stored calls found.")
            return
        }

        // TODO: (IOS-4677) Is this what we want?
        // If group calls are disabled, we delete all stored entities.
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls,
              !MDMSetup(setup: false).disableGroupCalls() else {
            DDLogVerbose("[GroupCall] GroupCalls are not enabled. Deleting all stored entities.")
            deleteGroupCallEntities(storedGroupCalls)
            return
        }
        
        // These will be deleted due to having invalid state
        var invalidGroupCalls = [GroupCallEntity]()
        // These will be handled
        var proposedGroupCalls = [ProposedGroupCall]()
        
        await entityManager.perform {
            for groupCallEntity in storedGroupCalls {
                guard let group = groupCallEntity.group,
                      let creatorIdentity = group.groupCreator ?? self.currentBusinessInjector
                      .myIdentityStore.identity,
                      // swiftformat:disable:next acronyms
                      let fetchedGroup = groupManager.getGroup(group.groupId, creator: creatorIdentity)
                else {
                    invalidGroupCalls.append(groupCallEntity)
                    continue
                }
                
                guard let urlString = groupCallEntity.sfuBaseURL, let sfuBaseURL = URL(string: urlString) else {
                    invalidGroupCalls.append(groupCallEntity)
                    continue
                }
                
                guard let gck = groupCallEntity.gck else {
                    continue
                }
                
                guard let protocolVersion = groupCallEntity.protocolVersion?.int32Value else {
                    continue
                }
                
                guard let startMessageReceiveDate = groupCallEntity.startMessageReceiveDate else {
                    continue
                }
                
                assert(groupCallEntity.sfuBaseURL == sfuBaseURL.absoluteString, "These must match.")
                
                let groupModel = GroupCallThreemaGroupModel(
                    groupIdentity: fetchedGroup.groupIdentity,
                    groupName: fetchedGroup.name ?? ""
                )
                
                do {
                    let proposedGroupCall = try ProposedGroupCall(
                        groupRepresentation: groupModel,
                        protocolVersion: UInt32(protocolVersion),
                        gck: gck,
                        sfuBaseURL: sfuBaseURL,
                        startMessageReceiveDate: startMessageReceiveDate,
                        dependencies: self.dependencies
                    )
                    DDLogNotice("[GroupCall] [DB] Loaded call with callID \(proposedGroupCall.hexCallID)")
                    proposedGroupCalls.append(proposedGroupCall)
                }
                catch {
                    invalidGroupCalls.append(groupCallEntity)
                    
                    let message = "[GroupCall] Could not get create ProposedGroupCall for call from DB."
                    DDLogError("\(message)")
                    assertionFailure(message)
                }
            }
        }
        
        DDLogNotice(
            "[GroupCall] [DB] We have loaded \(storedGroupCalls.count) items from the database, of which \(proposedGroupCalls.count) will be handled and \(invalidGroupCalls.count) will be deleted."
        )
        
        // Delete invalid
        if !invalidGroupCalls.isEmpty {
            deleteGroupCallEntities(invalidGroupCalls)
        }
        
        // For each of the fetched calls, we check if they are still running, if so we leave them
        for proposedGroupCall in proposedGroupCalls {
            Task { // TODO: (IOS-4047) Is Task what we want here?
                // TODO: (IOS-4678) This will also create an actor for the group call and then will be discarded if the app was active before and the call already existed at that point
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
    @objc public func handleMessage(
        rawMessage: Any,
        from senderIdentity: String,
        in groupConversationObjectID: NSManagedObjectID,
        receiveDate: Date
    ) async {
       
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls else {
            if !MDMSetup(setup: false).disableGroupCalls() {
                postGroupCallStartSystemMessage(in: groupConversationObjectID, by: senderIdentity)
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
        
        guard let sfuBaseURL = URL(string: convRawMessage.sfuBaseURL), await validateSFUBaseURL(sfuBaseURL) else {
            DDLogError("[GroupCall] Received message with invalid SFU-URL String: \(convRawMessage.sfuBaseURL)")
            return
        }
        
        guard let groupModel = await groupCallManager.getGroupModel(for: groupConversationObjectID) else {
            DDLogError("[GroupCall] Could not get group model for group.")
            return
        }
        
        let proposedGroupCall: ProposedGroupCall
        
        do {
            proposedGroupCall = try ProposedGroupCall(
                groupRepresentation: groupModel,
                protocolVersion: convRawMessage.protocolVersion,
                gck: convRawMessage.gck,
                sfuBaseURL: sfuBaseURL,
                startMessageReceiveDate: receiveDate,
                dependencies: dependencies
            )
        }
        catch {
            let message = "[GroupCall] Could not get create ProposedGroupCall for incoming message."
            DDLogError("\(message)")
            assertionFailure(message)
            return
        }
        
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
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls else {
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
                let groupModel = GroupCallThreemaGroupModel(
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
    
    private func postGroupCallStartSystemMessage(in conversationObjectID: NSManagedObjectID, by identity: String) {
        let currentEntityManager = currentBusinessInjector.entityManager
        
        // TODO: (IOS-3199) Move & improve
        currentEntityManager.performAndWaitSave {
            guard let fetchedConversation = currentEntityManager.entityFetcher
                .existingObject(with: conversationObjectID) as? ConversationEntity else {
                return
            }
            
            var displayName = identity
            if let contact = currentEntityManager.entityFetcher.contact(for: identity) {
                displayName = contact.displayName
            }
            
            guard let dbSystemMessage = currentEntityManager.entityCreator
                .systemMessageEntity(for: fetchedConversation) else {
                return
            }
            
            dbSystemMessage.type = NSNumber(value: kSystemMessageGroupCallStartedBy)
            dbSystemMessage.arg = Data(displayName.utf8)
            fetchedConversation.lastMessage = dbSystemMessage
        }
    }
    
    private func getCallID(in groupModel: GroupCallThreemaGroupModel) async -> String? {
        await groupCallManager.getCallID(in: groupModel)
    }
    
    private func saveGroupCallStartMessage(
        for wrappedMessage: WrappedGroupCallStartMessage,
        with receiveDate: Date = Date.now
    ) async {
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls else {
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
            // swiftformat:disable:next acronyms
            assert(!groupEntity.groupId.isEmpty)
            
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
    
    private func validateSFUBaseURL(_ url: URL) async -> Bool {
        do {
            let token = try await httpHelper.sfuCredentials()
            // When receiving the SFU information, ensure the _SFU Base URL_ uses the scheme
            // `https` and the included hostname ends with one of the
            // _Allowed SFU Hostname Suffixes_.
            return token.isValidSFUBaseURL(url)
        }
        catch {
            DDLogError("[GroupCall] Invalid baseURL: \(url.absoluteString)")
            return false
        }
    }
}

// MARK: - Debug Call Start Functions

extension GlobalGroupCallManagerSingleton {
    #if DEBUG
        public func asyncHandleMessage(
            rawMessage: Any,
            groupModel: GroupCallThreemaGroupModel,
            messageReceiveDate: Date
        ) async {
            guard let convRawMessage = rawMessage as? CspE2e_GroupCallStart else {
                fatalError()
            }
        
            let proposedGroupCall = try! ProposedGroupCall(
                groupRepresentation: groupModel,
                protocolVersion: convRawMessage.protocolVersion,
                gck: convRawMessage.gck,
                sfuBaseURL: URL(string: convRawMessage.sfuBaseURL)!,
                startMessageReceiveDate: messageReceiveDate,
                dependencies: dependencies
            )
        
            await groupCallManager.handleNewCallMessage(for: proposedGroupCall, creatorOrigin: .local)
        }
    
        public func startAndJoinDebugCall(groupModel: GroupCallThreemaGroupModel) async {
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
        and groupModel: GroupCallThreemaGroupModel,
        startMessage: ThreemaProtocols.CspE2e_GroupCallStart
    ) async {
        try! await Task.sleep(seconds: 1)
        
        var groupDict = [String: String]()
        var memberDict = [[String: String]]()
        
        let businessInjector = BusinessInjector()
        businessInjector.entityManager.performAndWait {
            let conversation = businessInjector.entityManager.entityFetcher
                .existingObject(with: conversationObjectID) as! ConversationEntity
            
            if UserSettings.shared().groupCallsDebugMessages {
                groupDict["creator"] = conversation.contact?.identity ?? businessInjector.myIdentityStore.identity
                groupDict["id"] = conversation.groupID!.base64EncodedString()
                
                let myMember: [String: String] = [
                    "identity": businessInjector.myIdentityStore.identity,
                    "publicKey": MyIdentityStore.shared().publicKey.base64EncodedString(),
                ]
                
                memberDict = conversation.unwrappedMembers
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
        guard let callIDString = await GlobalGroupCallManagerSingleton.shared.getCallID(in: groupModel) else {
            assertionFailure("Could not retrieve CallID for Debug Call.")
            return
        }
        
        businessInjector.entityManager.performAndWait {
            let conversation = businessInjector.entityManager.entityFetcher
                .existingObject(with: conversationObjectID) as! ConversationEntity
            
            businessInjector.messageSender.sendTextMessage(containing: "*CallID*", in: conversation)
            businessInjector.messageSender.sendTextMessage(
                containing: callIDString,
                in: conversation
            )
            
            businessInjector.messageSender.sendTextMessage(
                containing: "*CallInfo*",
                in: conversation
            )
            businessInjector.messageSender.sendTextMessage(
                containing: callInfoString,
                in: conversation
            )
            
            businessInjector.messageSender.sendTextMessage(
                containing: "*GCK*",
                in: conversation
            )
            businessInjector.messageSender.sendTextMessage(
                containing: "\(startMessage.gck.hexEncodedString())",
                in: conversation
            )
        }
    }
}

extension GlobalGroupCallManagerSingleton {
    private func sendGroupCallStartMessage(_ message: CspE2e_GroupCallStart, to group: Group) async throws {
        let frameworkInjector = currentBusinessInjector
        
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

extension GlobalGroupCallManagerSingleton: GroupCallManagerDatabaseDelegateProtocol {
    public func removeFromStoredCalls(_ proposedGroupCall: ProposedGroupCall) {
        let entityManager = currentBusinessInjector.entityManager
        
        // TODO: (IOS-4070) Do not fetch all group calls, instead create a delete request matching the values we compare below.
        let storedGroupCalls = entityManager.performAndWait {
            entityManager.entityFetcher.allGroupCallEntities()
        }
        
        guard !storedGroupCalls.isEmpty else {
            DDLogNotice("[GroupCall] [DB] No stored calls found.")
            return
        }
        
        var toDeleteGroupCalls = [GroupCallEntity]()

        entityManager.performAndWait {
            for groupCallEntity in storedGroupCalls {
                
                // If some values are nil, we delete the entity directly
                guard let gck = groupCallEntity.gck,
                      let sfuBaseURL = groupCallEntity.sfuBaseURL,
                      let group = groupCallEntity.group else {
                    toDeleteGroupCalls.append(groupCallEntity)
                    continue
                }
                
                guard gck == proposedGroupCall.gck else {
                    continue
                }
                
                guard sfuBaseURL == proposedGroupCall.sfuBaseURL.absoluteString else {
                    continue
                }
                // swiftformat:disable:next acronyms
                guard group.groupId == proposedGroupCall.groupRepresentation.groupIdentity.id else {
                    continue
                }
                
                let remoteAdminsAreEqual = group.groupCreator == proposedGroupCall
                    .groupRepresentation.groupIdentity.creator.string
                let localAdminsAreEqual = (
                    group.groupCreator == nil &&
                        proposedGroupCall.groupRepresentation.groupIdentity.creator.string ==
                        self.currentBusinessInjector.myIdentityStore.identity
                )
                
                guard remoteAdminsAreEqual || localAdminsAreEqual else {
                    continue
                }
                
                toDeleteGroupCalls.append(groupCallEntity)
            }
        }
        
        // Delete found old calls
        deleteGroupCallEntities(toDeleteGroupCalls)
    }
    
    private func deleteGroupCallEntities(_ groupCallEntities: [GroupCallEntity]) {
        guard !groupCallEntities.isEmpty else {
            return
        }
        
        currentBusinessInjector.entityManager.performAndWaitSave {
            for groupCallEntity in groupCallEntities {
                self.currentBusinessInjector.entityManager.entityDestroyer
                    .delete(groupCallEntity: groupCallEntity)
            }
            DDLogNotice("[GroupCall] [DB] Deleted \(groupCallEntities.count)")
        }
    }
}

// MARK: - GroupCallManagerSingletonDelegate

extension GlobalGroupCallManagerSingleton: GroupCallManagerSingletonDelegate {
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
        guard let group = currentBusinessInjector.groupManager.getGroup(
            wrappedMessage.groupIdentity.id,
            creator: wrappedMessage.groupIdentity.creator.string
        ) else {
            return
        }
            
        await saveGroupCallStartMessage(for: wrappedMessage)
            
        try await sendGroupCallStartMessage(wrappedMessage.startMessage, to: group)
    }
    
    public func showIncomingGroupCallNotification(
        groupModel: GroupCalls.GroupCallThreemaGroupModel,
        senderThreemaID: ThreemaIdentity
    ) {
        guard let uiDelegate else {
            DDLogError("[GroupCall] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }
        
        currentBusinessInjector.entityManager.performBlock {
            guard let conversation = self.currentBusinessInjector.entityManager.entityFetcher.conversationEntity(
                for: groupModel.groupIdentity.id,
                creator: groupModel.groupIdentity.creator.string
            ) else {
                return
            }
            
            guard conversation.conversationCategory != .private else {
                uiDelegate.newBannerForStartGroupCall(
                    conversationManagedObjectID: conversation.objectID,
                    title: #localize("private_message_label"),
                    body: " ",
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
                format: #localize("group_call_started_by_contact_system_message"),
                contact.displayName
            )
            let conversationObjectID = conversation.objectID
            
            uiDelegate.newBannerForStartGroupCall(
                conversationManagedObjectID: conversationObjectID,
                title: title ?? "",
                body: body,
                identifier: groupModel.groupIdentity.id.hexString
            )
        }
    }
    
    public func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        uiDelegate?.showGroupCallFullAlert(maxParticipants: maxParticipants, onOK: onOK)
    }
}

extension GlobalGroupCallManagerSingleton {
    /// Only use when running screenshots
    public func startGroupCallForScreenshots(group: Group) {
        guard ProcessInfoHelper.isRunningForScreenshots else {
            assertionFailure("This should only be called during screenshots.")
            return
        }
        
        Task {
            let groupCallViewControllerForScreenshots = await groupCallManager.groupCallViewControllerForScreenshots(
                groupName: group.name!,
                localID: currentBusinessInjector.myIdentityStore.identity,
                participantThreemaIdentities: group.members.map(\.identity)
            )
            
            uiDelegate?.showViewController(groupCallViewControllerForScreenshots)
        }
    }
}
