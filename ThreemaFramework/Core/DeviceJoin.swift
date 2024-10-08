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
import Foundation
import ThreemaProtocols

/// Implement Device Join Protocol
///
/// The _offer to join the device group_ Variant is not considered in this implementation.
/// And for the  new device role only the some design considerations exist.
public final class DeviceJoin {
    
    public enum Error: Swift.Error {
        case notAllowedForRole(role: Role)
        case alreadyConnected
        case notConnected
        case noDeviceGroupKey
        case failedToGatherData
        case failedToGenerateRandomData
        case registrationFailed
        case noWorkCredentials
        
        case notImplemented
    }
    
    /// Role of this device
    public enum Role {
        /// The rendezvous nomination is done by the existing device
        case existingDevice // Currently only this is supported
        case newDevice
    }
    
    // MARK: - Private properties
    
    private let role: Role
    private let businessInjector: BusinessInjector
    
    private var connection: EncryptedRendezvousConnection?
    
    private let serverConnectionHelper = DeviceJoinServerConnectionHelper()
    private var wasMultiDeviceEnabled: Bool?
    
    // MARK: - Lifecycle
    
    /// Create object to host a device join
    /// - Parameters:
    ///   - role: Role of this device
    ///   - businessInjector: Business injector to use
    public init(role: Role, businessInjector: BusinessInjector = BusinessInjector()) {
        self.role = role
        self.businessInjector = businessInjector
    }
    
    // MARK: - Existing Device
    
    /// Establish connection to run device join after
    ///
    /// Compare and validate the returned rendezvous path hash data with the value on the new device before doing the
    /// join using `send()`
    ///
    /// - Parameter urlSafeBase64DeviceGroupJoinRequestOffer: Device group join request offer encodes as URL safe base
    /// 64 string
    /// - Returns: Rendezvous path hash
    public func connect(urlSafeBase64DeviceGroupJoinRequestOffer: String) async throws -> Data { // Rendezvous Path Hash
        guard role == .existingDevice else {
            throw Error.notAllowedForRole(role: role)
        }
        
        guard connection == nil else {
            throw Error.alreadyConnected
        }
        
        let (localConnection, pathHash) = try await RendezvousProtocol.connect(
            urlSafeBase64DeviceGroupJoinRequestOffer: urlSafeBase64DeviceGroupJoinRequestOffer,
            isNominator: true
        )
        
        connection = localConnection
        
        return pathHash
    }
    
    /// Send data to new device
    ///
    /// If this returns the new device was connected
    public func send() async throws {
        // TODO: (IOS-3868) Return async sequence with current state that can be used in the UI
        
        guard role == .existingDevice else {
            throw Error.notAllowedForRole(role: role)
        }
        
        guard let connection else {
            throw Error.notConnected
        }
        
        // Disconnect
        
        // Disconnect from server during joining
        try await serverConnectionHelper.blockCommunicationAndDisconnect()
        
        // Enable MD if needed

        // Long term Idea: Do creation via MultiDeviceManager and move disabling and more stuff into MultiDeviceManager
        // (from DeviceLinking/ServerConnector)
        
        // Generate new device group key if multi device was disabled before
        let deviceGroupKey: Data?
        let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: businessInjector.myIdentityStore)
        wasMultiDeviceEnabled = businessInjector.settingsStore.isMultiDeviceRegistered
        if !businessInjector.settingsStore.isMultiDeviceRegistered {
            deviceGroupKey = deviceGroupKeyManager.create()
        }
        else {
            deviceGroupKey = deviceGroupKeyManager.dgk
        }
        
        guard let deviceGroupKey else {
            throw Error.noDeviceGroupKey
        }
        
        // We don't set `isMultiDeviceRegistered` anywhere here as this is handled in the `MediatorMessageProcessor`
        // during the first handshake if a device group key exists.

        do {
            // TODO: (IOS-3671) This should be called inside a transaction
            try await sendInternal(deviceGroupKey: deviceGroupKey, over: connection)
        }
        catch {
            // Tear down started linking
            cancel()
                        
            throw error
        }
        
        // Reconnect to CS
        try await serverConnectionHelper.unblockCommunicationAndReconnect()
        
        // Disable PFS
        do {
            try await disablePFSAndTerminateAllSessions()
        }
        catch {
            // We fail silently if this fails
            DDLogWarn("Disabling PFS and terminating all sessions failed: \(error)")
        }
        
        // Everything should work now...
    }
    
    /// Cancel currently running device join
    ///
    /// This is only implemented for the existing device role
    public func cancel() {
        guard role == .existingDevice else {
            DDLogError("Cancel called with wrong role")
            return
        }
        
        // Close rendezvous connection
        connection?.close()
        connection = nil
        
        // Disable MD again if it was not enabled before
        if !(wasMultiDeviceEnabled ?? true) {
            businessInjector.serverConnector.deactivateMultiDevice()
            FeatureMask.updateLocal() // Needed to activate PFS again
        }
        wasMultiDeviceEnabled = nil
        
        // Reconnect to CS
        Task {
            do {
                try await serverConnectionHelper.unblockCommunicationAndReconnect()
            }
            catch {
                DDLogError("Unable to unblock and reconnect: \(error)")
            }
        }
    }
    
    /// Cleanup a failed join (i.e. when connections are still blocked)
    public static func cleanupFailedJoin() {
        Task {
            do {
                try await BusinessInjector().multiDeviceManager.disableMultiDevice()
            }
            catch {
                DDLogError("Unable to cleanup by disabling multi-device: \(error)")
            }
            
            do {
                try await DeviceJoinServerConnectionHelper().unblockCommunicationAndReconnect()
            }
            catch {
                DDLogError("Unable to cleanup by unblocking the communication: \(error)")
            }
        }
    }
    
    // MARK: Send helper
    
    // TODO: (IOS-3671) This should happen inside a transaction
    private func sendInternal(deviceGroupKey: Data, over connection: EncryptedRendezvousConnection) async throws {
        
        //     ED ------- Begin ------> ND   [1]
        
        let edToNdBegin = Join_EdToNd.with {
            $0.begin = Join_Begin()
        }
        
        let edToNdBeginData = try edToNdBegin.serializedData()
        
        DDLogNotice("Send begin")
        DDLogVerbose("Send begin: \(edToNdBeginData)")
        try await connection.send(edToNdBeginData)

        //     ED -- common.BlobData -> ND   [0..N]
        
        // Gather data & send all the profile pictures if needed
        DDLogNotice("Send blobs")
        let userProfile = try await gatherUserProfileAndSendPictureIfNeeded(over: connection)
        let augmentedContacts = try await gatherContactsAndSendProfilePicturesIfNeeded(over: connection)
        let augmentedGroups = try await gatherGroupsAndSendProfilePicturesIfNeeded(over: connection)
        
        //     ED --- EssentialData --> ND   [1]
        
        let identityData = try gatherIdentityData()
        let deviceGroupData = Join_EssentialData.DeviceGroupData.with {
            $0.dgk = deviceGroupKey
        }
        let cspNonces = try await gatherCSPNonces()
        
        let essentialData = try Join_EssentialData.with {
            // $0.mediatorServer // This is only required for custom servers
            
            $0.identityData = identityData
            
            // Add credentials for "a Threema Work app"
            if [.work, .blue, .onPrem].contains(ThreemaApp.current) {
                $0.workCredentials = try gatherWorkCredentials()
            }
            
            $0.deviceGroupData = deviceGroupData
            $0.userProfile = userProfile
            
            $0.settings = businessInjector.settingsStore.asSyncSettings
            // $0.mdmParameters // Out of scope in IOS-3674
            
            $0.contacts = augmentedContacts
            $0.groups = augmentedGroups
            // $0.distributionLists // Not implemented in iOS
            
            $0.cspHashedNonces = cspNonces
            // $0.d2DHashedNonces // IOS-3978: Send nonces from D2D scope

            $0.mdmParameters = gatherMdmParameters()
        }
        
        let edToNdEssentialData = Join_EdToNd.with {
            $0.essentialData = essentialData
        }
        
        let serializedEdToNdEssentialData = try edToNdEssentialData.serializedData()
        
        // WARNING: Essential data contains the private key so we need to be careful that we only log the size here!
        let essentialDataSize = serializedEdToNdEssentialData.count
        DDLogNotice("Send essential data... (\(essentialDataSize) bytes)")
        
        try await connection.send(serializedEdToNdEssentialData)
        
        // ED <---- Registered ---- ND   [1]
        
        DDLogNotice("Wait for 'registered' message...")
        let ndToEdRegisteredData = try await connection.receive()
        let ndToEdRegisteredMessage = try Join_NdToEd(serializedData: ndToEdRegisteredData)
        
        guard ndToEdRegisteredMessage.registered.isInitialized else {
            throw Error.registrationFailed
        }
    }
    
    // MARK: Gathering data
    
    private func gatherUserProfileAndSendPictureIfNeeded(over connection: EncryptedRendezvousConnection) async throws
        -> Sync_UserProfile {
        var (userProfile, profilePicture) = ProfileStore().profile().asSyncUserProfile
        if let profilePicture {
            let profilePictureCommonImage = try await sendBlobImage(data: profilePicture, over: connection)
            userProfile.profilePicture.updated = profilePictureCommonImage
        }
        
        return userProfile
    }
    
    private func gatherContactsAndSendProfilePicturesIfNeeded(
        over connection: EncryptedRendezvousConnection
    ) async throws -> [Join_EssentialData.AugmentedContact] {
        
        let mediatorSyncableContacts = MediatorSyncableContacts()
        let allDeltaContacts = mediatorSyncableContacts.getAllDeltaSyncContacts()
        
        var augmentedContacts = [Join_EssentialData.AugmentedContact]()
        for deltaContact in allDeltaContacts {
            var syncContact = deltaContact.syncContact
            
            if let profilePicture = deltaContact.image {
                let profilePictureCommonImage = try await sendBlobImage(data: profilePicture, over: connection)
                syncContact.userDefinedProfilePicture.updated = profilePictureCommonImage
            }
            
            if let contactProfilePicture = deltaContact.contactImage {
                let contactProfilePictureCommonImage = try await sendBlobImage(
                    data: contactProfilePicture,
                    over: connection
                )
                syncContact.contactDefinedProfilePicture.updated = contactProfilePictureCommonImage
            }
            
            let augmentedContact = Join_EssentialData.AugmentedContact.with {
                $0.contact = syncContact
                if let lastUpdate = deltaContact.lastConversationUpdate {
                    $0.lastUpdateAt = lastUpdate.millisecondsSince1970
                }
            }
            
            augmentedContacts.append(augmentedContact)
        }
        
        DDLogNotice("\(augmentedContacts.count) contacts gathered")
        
        return augmentedContacts
    }
    
    private func gatherGroupsAndSendProfilePicturesIfNeeded(
        over connection: EncryptedRendezvousConnection
    ) async throws -> [Join_EssentialData.AugmentedGroup] {
        
        // Load groups from Core Data and map them to business objects
        let allGroups = try await businessInjector.entityManager.perform {
            guard let allGroupConversations = self.businessInjector.entityManager.entityFetcher
                .allGroupConversations() else {
                throw Error.failedToGatherData
            }
                    
            var groups = [Group]()
            groups.reserveCapacity(allGroupConversations.count)
            
            for anyGroupConversation in allGroupConversations {
                guard let groupConversation = anyGroupConversation as? Conversation,
                      let groupID = groupConversation.groupID,
                      let groupCreator = groupConversation.contact?.identity ?? self.businessInjector.myIdentityStore
                      .identity,
                      let group = self.businessInjector.groupManager.getGroup(groupID, creator: groupCreator)
                else {
                    continue
                }
                
                groups.append(group)
            }
            
            return groups
        }
        
        // Process the loaded groups
            
        var augmentedGroups = [Join_EssentialData.AugmentedGroup]()
        augmentedGroups.reserveCapacity(allGroups.count)
        
        for group in allGroups {
            var (syncGroup, profilePicture) = group.asSyncGroup
            
            if let profilePicture {
                let profilePictureCommonImage = try await sendBlobImage(data: profilePicture, over: connection)
                syncGroup.profilePicture.updated = profilePictureCommonImage
            }
            
            let augmentedGroup = Join_EssentialData.AugmentedGroup.with {
                $0.group = syncGroup
                if let lastUpdate = group.lastUpdate {
                    $0.lastUpdateAt = lastUpdate.millisecondsSince1970
                }
                else if let lastMessageDate = group.lastMessageDate {
                    $0.lastUpdateAt = lastMessageDate.millisecondsSince1970
                }
                else {
                    $0.lastUpdateAt = 0
                }
            }
            
            augmentedGroups.append(augmentedGroup)
        }
        
        DDLogNotice("\(augmentedGroups.count) groups gathered")
        
        return augmentedGroups
    }

    private func gatherIdentityData() throws -> Join_EssentialData.IdentityData {
        guard let identity = businessInjector.myIdentityStore.identity,
              let privateClientKey = businessInjector.myIdentityStore.keySecret() else {
            throw Error.failedToGatherData
        }
        
        guard let deviceCookie = DeviceCookieManager.obtainDeviceCookie() else {
            throw Error.failedToGatherData
        }
        
        guard let serverGroup = businessInjector.myIdentityStore.serverGroup else {
            throw Error.failedToGatherData
        }
        
        return Join_EssentialData.IdentityData.with {
            $0.identity = identity
            $0.ck = privateClientKey
            $0.cspDeviceCookie = deviceCookie
            $0.cspServerGroup = serverGroup
        }
    }
    
    private func gatherWorkCredentials() throws -> Sync_ThreemaWorkCredentials {
        guard let username = LicenseStore.shared().licenseUsername,
              let password = LicenseStore.shared().licensePassword else {
            throw Error.noWorkCredentials
        }

        return Sync_ThreemaWorkCredentials.with {
            $0.username = username
            $0.password = password
        }
    }
    
    private func gatherCSPNonces() async throws -> [Data] {
        try await businessInjector.entityManager.perform {
            guard let allNonces = self.businessInjector.entityManager.entityFetcher.allNonces() else {
                throw Error.failedToGatherData
            }
            
            DDLogNotice("Nonces: \(allNonces.count) nonces gathered")
            
            // This removes the `nil` nonces if there are any
            let nonNilNonces = allNonces.compactMap(\.nonce)
            DDLogNotice("Nonces: \(allNonces.count - nonNilNonces.count) nonces were nil")
            
            let filteredNonces = nonNilNonces.filter {
                $0.count == 32
            }
            DDLogNotice("Nonces: \(nonNilNonces.count - filteredNonces.count) nonces were not 32 bytes")

            return filteredNonces
        }
    }

    private func gatherMdmParameters() -> Sync_MdmParameters {
        MDMSetup(setup: false).mdmParameters()
    }

    private func sendBlobImage(
        data: Data,
        over connection: EncryptedRendezvousConnection
    ) async throws -> Common_Image {
        guard let blobID = BytesUtility.generateRandomBytes(length: ThreemaProtocol.blobIDLength) else {
            throw Error.failedToGenerateRandomData
        }
        
        let commonBlobData = Common_BlobData.with {
            $0.id = blobID
            $0.data = data
        }
        
        let edToNdCommonBlobData = Join_EdToNd.with {
            $0.blobData = commonBlobData
        }
        
        let serializedEdToNdCommonBlobData = try edToNdCommonBlobData.serializedData()
        
        let commonDataSize = serializedEdToNdCommonBlobData.count
        DDLogNotice("Send blob... (\(commonDataSize) bytes)")
        
        try await connection.send(serializedEdToNdCommonBlobData)
        
        return Common_Image.with {
            $0.type = .jpeg
            $0.blob = Common_Blob.with {
                $0.id = blobID
                $0.uploadedAt = Date.now.millisecondsSince1970
            }
        }
    }
    
    // MARK: Disable PFS
    
    private func disablePFSAndTerminateAllSessions() async throws {
        // Update feature mask to disable forward secrecy
        await updateFeatureMask()
        
        // Terminate all existing sessions
        // Contacts will react by fetching new feature mask
        let pfsEnabledContacts = await pfsEnabledContacts()
        try await disablePFS(for: pfsEnabledContacts)
    }
    
    private func updateFeatureMask() async {
        await withCheckedContinuation { continuation in
            FeatureMask.updateLocal {
                continuation.resume()
            }
        }
    }
    
    private func pfsEnabledContacts() async -> [ContactEntity] {
        await businessInjector.entityManager.perform {
            guard let allContacts = self.businessInjector.entityManager.entityFetcher.allContacts() as? [ContactEntity]
            else {
                return []
            }
            
            return allContacts.filter {
                $0.isForwardSecurityAvailable()
            }
        }
    }
    
    private func disablePFS(for contacts: [ContactEntity]) async throws {
        let sessionTerminator = try ForwardSecuritySessionTerminator(businessInjector: businessInjector)
        
        await businessInjector.entityManager.performSave {
            for contact in contacts {
                // Disable PFS
                contact.forwardSecurityState = NSNumber(value: ForwardSecurityState.off.rawValue)
                
                // Terminate existing session
                do {
                    try sessionTerminator.terminateAllSessions(with: contact, cause: .disabledByLocal)
                }
                catch {
                    DDLogError("An error occurred while terminating session with \(contact.identity): \(error)")
                }
                
                // Post system message
                guard let conversation = self.businessInjector.entityManager.entityFetcher
                    .conversation(forIdentity: contact.identity) else {
                    // If we don't have a conversation don't post a system message
                    continue
                }
                guard let systemMessage = self.businessInjector.entityManager.entityCreator
                    .systemMessage(for: conversation) else {
                    DDLogNotice("Unable to create system message for changing PFS state")
                    continue
                }
                systemMessage.type = NSNumber(value: kSystemMessageFsDisabledOutgoing)
                systemMessage.remoteSentDate = Date()
                if systemMessage.isAllowedAsLastMessage {
                    conversation.lastMessage = systemMessage
                }
            }
        }
    }
    
    // MARK: - New Device (this is just a draft)
    
    // Returns a `urlSafeBase64DeviceGroupJoinRequestOffer`
    func joinRequest() async throws -> String {
        guard role == .newDevice else {
            throw Error.notAllowedForRole(role: role)
        }
        
        throw Error.notImplemented
    }
    
    func waitAndJoin() async throws {
        guard role == .newDevice else {
            throw Error.notAllowedForRole(role: role)
        }
        
        throw Error.notImplemented
    }
}

// MARK: - Extensions to gather data

// TODO: This will be replaces by `update` and `from` extensions on the Threema Protocol types (IOS-3869)

extension ProfileStore.Profile {
    fileprivate var asSyncUserProfile: (Sync_UserProfile, profileImage: Data?) {
        var syncUserProfile = Sync_UserProfile()
        
        if let nickname {
            syncUserProfile.nickname = nickname
        }
        else {
            // When the user cleared its nickname, send an empty string.
            syncUserProfile.nickname = ""
        }
        
        // Profile picture is not filled out and can be added later if needed

        syncUserProfile.profilePictureShareWith.policy = profilePictureShareWithPolicy(
            for: sendProfilePicture,
            identities: profilePictureContactList
        )
        
        syncUserProfile.identityLinks.links = []
        
        if !isLinkMobileNoPending, let mobilePhoneNo {
            syncUserProfile.identityLinks.links.append(Sync_UserProfile.IdentityLinks.IdentityLink.with {
                $0.phoneNumber = mobilePhoneNo
            })
        }
        
        if !isLinkEmailPending, let email {
            syncUserProfile.identityLinks.links.append(Sync_UserProfile.IdentityLinks.IdentityLink.with {
                $0.email = email
            })
        }
        
        return (syncUserProfile, profileImage)
    }
    
    // Copied from ProfileStore
    private func profilePictureShareWithPolicy(
        for sendProfilePicture: SendProfilePicture,
        identities: [String]
    ) -> Sync_UserProfile.ProfilePictureShareWith.OneOf_Policy {
        switch sendProfilePicture {
        case SendProfilePictureNone:
            return .nobody(Common_Unit())
        case SendProfilePictureContacts:
            var allowList = Common_Identities()
            allowList.identities = identities
            return .allowList(allowList)
        case SendProfilePictureAll:
            return .everyone(Common_Unit())
        default:
            return .nobody(Common_Unit())
        }
    }
}

extension SettingsStoreProtocol {
    fileprivate var asSyncSettings: Sync_Settings {
        Sync_Settings.with {
            $0.contactSyncPolicy = syncContacts ? .sync : .notSynced
            $0.unknownContactPolicy = blockUnknown ? .blockUnknown : .allowUnknown
            $0.readReceiptPolicy = sendReadReceipts ? .sendReadReceipt : .dontSendReadReceipt
            $0.typingIndicatorPolicy = sendTypingIndicator ? .sendTypingIndicator : .dontSendTypingIndicator
            $0.o2OCallPolicy = enableThreemaCall ? .allowO2OCall : .denyO2OCall
            $0.o2OCallConnectionPolicy = alwaysRelayCalls ? .requireRelayedConnection : .allowDirectConnection
            // Screenshot policy doesn't exist
            // Keyboard collection policy doesn't exist
            $0.blockedIdentities.identities = Array(blacklist)
            $0.excludeFromSyncIdentities.identities = syncExclusionList
        }
    }
}

extension Group {
    fileprivate var asSyncGroup: (Sync_Group, groupProfileImage: Data?) {
        var syncGroup = Sync_Group()
        
        syncGroup.groupIdentity = Common_GroupIdentity.from(groupIdentity)
        
        if let name {
            syncGroup.name = name
        }
        else {
            // An empty string is valid.
            syncGroup.name = ""
        }
        
        // Created at is currently not stored on iOS: IOS-2825 / SE-341
        // As discussed we'll set it to 0 for now
        syncGroup.createdAt = 0
        
        syncGroup.update(state: state)
        
        // `notification_trigger_policy_override` is currently not supported on iOS: IOS-2825
        syncGroup.notificationTriggerPolicyOverride.default = Common_Unit()
        // `notification_sound_policy_override` is currently not supported on iOS: IOS-2825
        syncGroup.notificationSoundPolicyOverride.default = Common_Unit()
        
        syncGroup.memberIdentities.identities = allActiveMemberIdentitiesWithoutCreator
        
        if let category = Sync_ConversationCategory(rawValue: conversationCategory.rawValue) {
            syncGroup.conversationCategory = category
        }
        
        if let visibility = Sync_ConversationVisibility(rawValue: conversationVisibility.rawValue) {
            syncGroup.conversationVisibility = visibility
        }
        
        return (syncGroup, old_ProfilePicture)
    }
}
