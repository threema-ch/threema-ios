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
                ipv6Enabled: UserSettings.shared().enableIPv6
            ),
            groupCallSystemMessageAdapter: GroupCallSystemMessageAdapter<BusinessInjector>(
                businessInjector: BusinessInjector(forBackgroundProcess: true)
            ),
            notificationPresenterWrapper: NotificationPresenterWrapper.shared,
            groupCallParticipantInfoFetcher: GroupCallParticipantInfoFetcher.shared,
            groupCallSessionHelper: GroupCallSessionHelper.shared,
            groupCallBundleUtil: GroupCallBundleUtil.shared,
            isRunningForScreenshots: ProcessInfoHelper.isRunningForScreenshots,
            audioSessionManager: BusinessInjector.ui.audioSessionManager
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
            nickname: businessInjector.myIdentityStore.pushFromName ?? identity.rawValue
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

    /// Cancel the periodic refresh task when the app enters background.
    /// This prevents stale in-flight peek requests from incorrectly removing
    /// active calls after iOS suspends and resumes the app.
    public func handleAppDidEnterBackground() async {
        await groupCallManager.cancelPeriodicRefresh()
    }

    /// Restart the periodic refresh task when the app enters foreground,
    /// so we get a fresh peek of all tracked calls.
    public func handleAppWillEnterForeground() async {
        await groupCallManager.startPeriodicCheckIfNeeded()
    }

    /// Load calls from DB
    ///
    /// If the manager is still doing the initial load we'll just wait for that
    public func loadCallsFromDB() async {
        if let initialLoadTask {
            await initialLoadTask.value
        }
        else {
            await handleCallsFromDB()
        }
    }
    
    private func handleCallsFromDB() async {
        DDLogNotice("[Call:GroupCall:Singleton] [DB] Start loading calls from database.")
        
        let entityManager = currentBusinessInjector.entityManager
        let groupManager = currentBusinessInjector.groupManager
        
        // We fetch all calls, that could still be running, from the db an insert them into an array
        let storedGroupCalls = await entityManager.perform {
            entityManager.entityFetcher.groupCallEntities()
        }
        
        guard let storedGroupCalls, !storedGroupCalls.isEmpty else {
            DDLogNotice("[Call:GroupCall:Singleton] [DB] No stored calls found.")
            return
        }

        // TODO: (IOS-4677) Is this what we want?
        // If group calls are disabled, we delete all stored entities.
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls,
              !MDMSetup().disableGroupCalls() else {
            DDLogVerbose("[Call:GroupCall:Singleton] GroupCalls are not enabled. Deleting all stored entities.")
            deleteGroupCallEntities(storedGroupCalls)
            return
        }
        
        // These will be deleted due to having invalid state
        var invalidGroupCalls = [GroupCallEntity]()
        // These will be handled if their SFU base URL can be validated
        var storedGroupCallsToValidate = [(entity: GroupCallEntity, proposedGroupCall: ProposedGroupCall)]()

        await entityManager.perform {
            for groupCallEntity in storedGroupCalls {
                guard let group = groupCallEntity.group,
                      let creatorIdentity = group.groupCreator ?? self.currentBusinessInjector
                      .myIdentityStore.identity,
                      let fetchedGroup = groupManager.getGroup(group.groupID, creator: creatorIdentity)
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
                    DDLogNotice("[Call:GroupCall:Singleton] [DB] Loaded call with callID \(proposedGroupCall.hexCallID)")
                    storedGroupCallsToValidate.append((groupCallEntity, proposedGroupCall))
                }
                catch {
                    invalidGroupCalls.append(groupCallEntity)
                    
                    let message = "[Call:GroupCall:Singleton] Could not get create ProposedGroupCall for call from DB."
                    DDLogError("\(message)")
                    assertionFailure(message)
                }
            }
        }
        
        // A call might have been stored before we were able to fetch an SFU token, see `handleMessage(…)`. Thus we
        // validate the SFU base URL before the call is handled.
        var proposedGroupCalls = [ProposedGroupCall]()

        for storedGroupCall in storedGroupCallsToValidate {
            switch await validateSFUBaseURL(storedGroupCall.proposedGroupCall.sfuBaseURL) {
            case .valid:
                proposedGroupCalls.append(storedGroupCall.proposedGroupCall)

            case .invalid:
                DDLogError(
                    "[Call:GroupCall:Singleton] [DB] Stored call \(storedGroupCall.proposedGroupCall.hexCallID) has an SFU-URL that is not allowed. Delete it."
                )
                invalidGroupCalls.append(storedGroupCall.entity)

            case .undetermined:
                // We keep the call stored and try again the next time calls are loaded from the database
                DDLogWarn(
                    "[Call:GroupCall:Singleton] [DB] Could not validate SFU-URL of stored call \(storedGroupCall.proposedGroupCall.hexCallID) yet. Skip it for now."
                )
            }
        }

        DDLogNotice(
            "[Call:GroupCall:Singleton] [DB] We have loaded \(storedGroupCalls.count) items from the database, of which \(proposedGroupCalls.count) will be handled and \(invalidGroupCalls.count) will be deleted."
        )
        
        // Delete invalid
        if !invalidGroupCalls.isEmpty {
            deleteGroupCallEntities(invalidGroupCalls)
        }
        
        // For each of the fetched calls, we check if they are still running, if so we leave them
        for proposedGroupCall in proposedGroupCalls {
            Task { // TODO: (IOS-4047) Is Task what we want here?
                // TODO: (IOS-4678) This will also create an actor for the group call and then will be discarded if the app was active before and the call already existed at that point
                await groupCallManager.handleNewCallMessage(
                    for: proposedGroupCall,
                    creatorOrigin: .db,
                    calledFromExtension: AppGroup.getCurrentType() != AppGroupTypeApp
                )
            }
        }
    }
    
    /// Handles a group call message
    /// - Parameters:
    ///   - rawMessage: Message to be handled
    ///   - senderIdentity: Identity of the sender
    ///   - groupConversation: Group to handle message for
    ///   - receiveDate: Receive date
    /// - Returns: `false` if there is no call to join, either because the SFU explicitly told us that it is no longer
    ///            running or because the message does not describe a call we could ever join. `true` whenever a call
    ///            might be running, including when we could not determine its state.
    @discardableResult
    @objc public func handleMessage(
        rawMessage: Any,
        from senderIdentity: String,
        in groupConversationObjectID: NSManagedObjectID,
        receiveDate: Date
    ) async -> Bool {
       
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls else {
            if !MDMSetup().disableGroupCalls() {
                postGroupCallStartSystemMessage(in: groupConversationObjectID, by: senderIdentity)
            }
            DDLogVerbose("[Call:GroupCall:Singleton] GroupCalls are not enabled. Skip.")
            // Notifications for group calls are suppressed by the setting itself, there is nothing to report here
            return true
        }
        
        guard let convRawMessage = rawMessage as? CspE2e_GroupCallStart else {
            let msg = "[Call:GroupCall:Singleton] Incorrect message type passed into \(#function)"
            assertionFailure(msg)
            DDLogError("\(msg)")
            return false
        }
        
        guard let sfuBaseURL = URL(string: convRawMessage.sfuBaseURL) else {
            DDLogError(
                "[Call:GroupCall:Singleton] Received message with invalid SFU-URL String: \(convRawMessage.sfuBaseURL)"
            )
            return false
        }

        let sfuBaseURLValidationResult = await validateSFUBaseURL(sfuBaseURL)

        guard sfuBaseURLValidationResult != .invalid else {
            DDLogError(
                "[Call:GroupCall:Singleton] Received message with SFU-URL that is not allowed: \(convRawMessage.sfuBaseURL)"
            )
            return false
        }

        guard let groupModel = await groupCallManager.getGroupModel(for: groupConversationObjectID) else {
            DDLogError("[Call:GroupCall:Singleton] Could not get group model for group.")
            // This says nothing about the call itself, so we keep it eligible for a notification
            return true
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
            let message = "[Call:GroupCall:Singleton] Could not get create ProposedGroupCall for incoming message."
            DDLogError("\(message)")
            assertionFailure(message)
            return false
        }
        
        let wrappedMessage = WrappedGroupCallStartMessage(
            startMessage: convRawMessage,
            groupIdentity: groupModel.groupIdentity
        )
        
        // We persist the call before it is validated: validating needs an SFU token and thus a working connection. If
        // we dropped the message here it would be lost forever, even though the call might still be running. Stored
        // calls are validated again before they are handled, see `handleCallsFromDB()`.
        await saveGroupCallStartMessage(
            for: wrappedMessage,
            with: receiveDate
        )

        guard sfuBaseURLValidationResult == .valid else {
            DDLogWarn(
                "[Call:GroupCall:Singleton] Could not validate SFU-URL of call \(proposedGroupCall.hexCallID) yet. The call was stored and will be handled as soon as an SFU token is available."
            )
            return true
        }

        let senderThreemaID: GroupCallCreatorOrigin = .remote(ThreemaIdentity(senderIdentity))
        return await groupCallManager.handleNewCallMessage(
            for: proposedGroupCall,
            creatorOrigin: senderThreemaID,
            calledFromExtension: AppGroup.getCurrentType() != AppGroupTypeApp
        )
    }
    
    @MainActor
    public func startGroupCall(
        in group: Group,
        intent: GroupCallUserIntent
    ) throws {
        guard currentBusinessInjector.settingsStore.enableThreemaGroupCalls else {
            DDLogVerbose("[Call:GroupCall:Singleton] GroupCalls are not enabled. Skip.")
            throw GroupCallStartError.disabled
        }
        
        guard !NavigationBarPromptHandler.isCallActiveInBackground else {
            DDLogInfo("[Call:GroupCall:Singleton] Call exists in background.")
            uiDelegate?.showAlert(for: GroupCallError.alreadyInCall)
            throw GroupCallError.alreadyInCall
        }
        
        guard group.hasAtLeastOneMemberSupporting(.groupCallSupport) else {
            NotificationPresenterWrapper.shared.present(type: .groupCallStartError)
            throw GroupCallStartError.noOneSupports
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
                DDLogError("[Call:GroupCall:Singleton] Caught error, showing alert: \(error.localizedDescription).")
                uiDelegate?.showAlert(for: error)
                throw error
            }
            catch {
                DDLogError("[Call:GroupCall:Singleton] Caught error: \(error.localizedDescription).")
                uiDelegate?.showAlert(for: GroupCallError.creationError)
                throw error
            }
        }
    }
    
    public func showGroupCallViewController() {
        Task {
            guard let uiDelegate else {
                DDLogError("[Call:GroupCall:Singleton] Delegate is nil, cannot show group call.")
                return
            }
            guard let viewController = await groupCallManager.viewControllerForCurrentlyJoinedGroupCall() else {
                DDLogError("[Call:GroupCall:Singleton] Getting view controller failed, cannot show group call.")
                return
            }
            await MainActor.run {
                uiDelegate.showViewController(viewController)
            }
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
            if let contact = currentEntityManager.entityFetcher.contactEntity(for: identity) {
                displayName = contact.displayName
            }
            
            let dbSystemMessage = currentEntityManager.entityCreator.systemMessageEntity(
                for: .groupCallStartedBy,
                in: fetchedConversation,
                setLastUpdate: true
            )
            
            dbSystemMessage.arg = Data(displayName.utf8)
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
            DDLogVerbose("[Call:GroupCall:Singleton] GroupCalls are not enabled. Skip.")
            return
        }
        let addedObjectID: NSManagedObjectID? = await currentBusinessInjector.entityManager.performSave {

            guard let groupEntity = self.currentBusinessInjector.entityManager.entityFetcher
                .groupEntity(
                    for: wrappedMessage.groupIdentity,
                    myIdentity: self.currentBusinessInjector.myIdentityStore.identity
                ) else {
                DDLogError("[Call:GroupCall:Singleton] Could not find group entity for group call message.")
                return nil
            }

            assert(!groupEntity.groupID.isEmpty)
            
            // Setup group call
            let groupCallEntity = self.currentBusinessInjector.entityManager.entityCreator.groupCallEntity()
            groupCallEntity.group = groupEntity
            groupCallEntity.gck = wrappedMessage.startMessage.gck
            groupCallEntity.protocolVersion = NSNumber(value: wrappedMessage.startMessage.protocolVersion)
            groupCallEntity.sfuBaseURL = wrappedMessage.startMessage.sfuBaseURL
            groupCallEntity.startMessageReceiveDate = receiveDate
            
            DDLogNotice("[Call:GroupCall:Singleton] [DB] Saved group call to database.")
            
            return groupCallEntity.objectID
        }
        
        Task {
            // Mark entity as dirty
            currentBusinessInjector.entityManager.perform {
                guard let addedObjectID else {
                    DDLogError("[Call:GroupCall:Singleton] Could not mark added group call as dirty.")
                    return
                }
                
                let dirtyObjectManager = PersistenceManager(
                    appGroupID: AppGroup.groupID(),
                    userDefaults: AppGroup.userDefaults(),
                    remoteSecretManager: RemoteSecretProvider.remoteSecretManager
                ).dirtyObjectManager
                dirtyObjectManager.markAsDirty(objectID: addedObjectID) {
                    AppGroup.notifySyncNeeded()
                }
            }
        }
    }
    
    private enum SFUBaseURLValidationResult {
        /// The URL is allowed by the current SFU token
        case valid
        /// The URL is not allowed and thus the call must never be handled
        case invalid
        /// We were not able to fetch an SFU token, thus we do not know yet whether the URL is allowed
        case undetermined
    }

    private func validateSFUBaseURL(_ url: URL) async -> SFUBaseURLValidationResult {
        do {
            let token = try await httpHelper.sfuCredentials()
            // When receiving the SFU information, ensure the _SFU Base URL_ uses the scheme
            // `https` and the included hostname ends with one of the
            // _Allowed SFU Hostname Suffixes_.
            guard token.isValidSFUBaseURL(url) else {
                DDLogError("[Call:GroupCall:Singleton] Invalid baseURL: \(url.absoluteString)")
                return .invalid
            }

            return .valid
        }
        catch {
            // Without an SFU token we cannot tell whether the URL is allowed. This regularly happens when we have no
            // connection, e.g. when processing queued messages right after a launch.
            DDLogWarn(
                "[Call:GroupCall:Singleton] Could not fetch SFU credentials to validate \(url.absoluteString): \(error)"
            )
            return .undetermined
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
        
            await groupCallManager.handleNewCallMessage(
                for: proposedGroupCall,
                creatorOrigin: .local,
                calledFromExtension: false
            )
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
            to: group.members.map(\.identity.rawValue),
            groupCallStartMessage: message,
            sendContactProfilePicture: true
        )
        
        _ = TaskManager().add(taskDefinition: taskDefinition)
    }
}

// MARK: - GroupCallManagerDatabaseDelegateProtocol

extension GlobalGroupCallManagerSingleton: GroupCallManagerDatabaseDelegateProtocol {
    public func removeFromStoredCalls(_ proposedGroupCall: ProposedGroupCall) {
        let entityManager = currentBusinessInjector.entityManager
        
        // TODO: (IOS-4070) Do not fetch all group calls, instead create a delete request matching the values we compare below.
        let storedGroupCalls = entityManager.performAndWait {
            entityManager.entityFetcher.groupCallEntities()
        }
        
        guard let storedGroupCalls, !storedGroupCalls.isEmpty else {
            DDLogNotice("[Call:GroupCall:Singleton] [DB] No stored calls found.")
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

                guard group.groupID == proposedGroupCall.groupRepresentation.groupIdentity.id else {
                    continue
                }
                
                let remoteAdminsAreEqual = group.groupCreator == proposedGroupCall
                    .groupRepresentation.groupIdentity.creator.rawValue
                let localAdminsAreEqual = (
                    group.groupCreator == nil &&
                        proposedGroupCall.groupRepresentation.groupIdentity.creator.rawValue ==
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
            DDLogNotice("[Call:GroupCall:Singleton] [DB] Deleted \(groupCallEntities.count)")
        }
    }
}

// MARK: - GroupCallManagerSingletonDelegate

extension GlobalGroupCallManagerSingleton: GroupCallManagerSingletonDelegate {
    public func showGroupCallViewController(viewController: GroupCallViewController) {
        guard let uiDelegate else {
            DDLogError("[Call:GroupCall:Singleton] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }

        DispatchQueue.main.async {
            uiDelegate.showViewController(viewController)
        }
    }
    
    public func updateGroupCallButtonsAndBanners(groupCallBannerButtonUpdate: GroupCalls.GroupCallBannerButtonUpdate) {
        globalGroupCallObserver.stateContinuation.yield(groupCallBannerButtonUpdate)
    }

    public func localUserLeftGroupCall(in groupIdentity: GroupIdentity) {
        DispatchQueue.main.async { [weak self] in
            guard let uiDelegate = self?.uiDelegate else {
                DDLogError("[Call:GroupCall:Singleton] Could not report the left group call, uiDelegate is nil.")
                return
            }

            uiDelegate.localUserLeftGroupCall(in: groupIdentity)
        }
    }
    
    public func sendStartCallMessage(_ wrappedMessage: WrappedGroupCallStartMessage) async throws {
        guard let group = currentBusinessInjector.groupManager.getGroup(
            wrappedMessage.groupIdentity.id,
            creator: wrappedMessage.groupIdentity.creator.rawValue
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
            DDLogError("[Call:GroupCall:Singleton] Could not show GroupCallViewController, uiDelegate is nil.")
            return
        }
        
        currentBusinessInjector.entityManager.perform {
            guard let conversation = self.currentBusinessInjector.entityManager.entityFetcher
                .conversationEntity(
                    for: groupModel.groupIdentity,
                    myIdentity: self.currentBusinessInjector.myIdentityStore.identity
                ) else {
                return
            }
            
            guard conversation.conversationCategory != .private else {
                uiDelegate.newBannerForStartGroupCall(
                    conversationManagedObjectID: conversation.objectID,
                    title: #localize("private_message_label"),
                    body: "",
                    identifier: groupModel.groupIdentity.id.hexString
                )
                return
            }
            
            guard let contact = self.currentBusinessInjector.entityManager.entityFetcher
                .contactEntity(for: senderThreemaID.rawValue) else {
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
                title: title,
                body: body,
                identifier: groupModel.groupIdentity.id.hexString
            )
        }
    }
    
    public func showGroupCallFullAlert(maxParticipants: Int?, onOK: @escaping () -> Void) {
        DispatchQueue.main.async { [uiDelegate] in
            uiDelegate?.showGroupCallFullAlert(maxParticipants: maxParticipants, onOK: onOK)
        }
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

            await MainActor.run {
                uiDelegate?.showViewController(groupCallViewControllerForScreenshots)
            }
        }
    }
}
