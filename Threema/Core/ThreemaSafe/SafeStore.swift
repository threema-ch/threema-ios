//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2025 Threema GmbH
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
import Gzip
import Keychain
import RemoteSecret
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@objc class SafeStore: NSObject {
    
    // MARK: - Static properties
    
    public static let masterKeyLength = 64
    private static let backupIDLength = 32
    private static let encryptionKeyLength = 32
    
    // MARK: - Properties
    
    private let safeConfigManager: SafeConfigManagerProtocol
    private let serverApiConnector: ServerAPIConnector
    private let groupManager: GroupManagerProtocol
    private let myIdentityStore: MyIdentityStoreProtocol
    
    // MARK: - Lifecycle
    
    init(
        safeConfigManager: SafeConfigManagerProtocol,
        serverApiConnector: ServerAPIConnector,
        groupManager: GroupManagerProtocol,
        myIdentityStore: MyIdentityStoreProtocol
    ) {
        self.safeConfigManager = safeConfigManager
        self.serverApiConnector = serverApiConnector
        self.groupManager = groupManager
        self.myIdentityStore = myIdentityStore
    }
    
    // NSObject thereby not the whole SafeConfigManagerProtocol interface must be like @objc
    @objc convenience init(
        safeConfigManagerAsObject safeConfigManager: NSObject,
        serverApiConnector: ServerAPIConnector,
        groupManager: GroupManager,
        myIdentityStore: MyIdentityStore
    ) {
        self.init(
            safeConfigManager: safeConfigManager as! SafeConfigManagerProtocol,
            serverApiConnector: serverApiConnector,
            groupManager: groupManager,
            myIdentityStore: myIdentityStore
        )
    }
    
    // MARK: - Keys and encryption
    
    /// Create/derive Threema Safe backup key
    /// - Parameters:
    ///   - identity: Threema ID
    ///   - safePassword: Password entered by the user when activating the backup
    static func createKey(identity: String, safePassword: String?) -> [UInt8]? {
        guard let safePassword,
              !safePassword.isEmpty else {
            return nil
        }
        let pPassword = UnsafeMutablePointer<Int8>(strdup(safePassword))
        let pSalt = UnsafeMutablePointer<Int8>(strdup(identity))
        
        let pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: SafeStore.masterKeyLength)
        
        defer {
            pPassword?.deallocate()
            pSalt?.deallocate()
            pOut.deallocate()
        }
        
        if getDerivedKey(pPassword, pSalt, pOut) != 0 {
            return nil
        }
        
        return Array(UnsafeMutableBufferPointer(start: pOut, count: SafeStore.masterKeyLength))
    }
    
    static func getBackupID(key: [UInt8]) -> [UInt8]? {
        if key.count == SafeStore.masterKeyLength {
            return Array(key[0..<backupIDLength])
        }
        return nil
    }
    
    static func getEncryptionKey(key: [UInt8]) -> [UInt8]? {
        if key.count == SafeStore.masterKeyLength {
            return Array(key[SafeStore.masterKeyLength - encryptionKeyLength..<SafeStore.masterKeyLength])
        }
        return nil
    }
    
    func encryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == SafeStore.masterKeyLength else {
            throw SafeError.backupError(.invalidKey)
        }
        guard !data.isEmpty else {
            throw SafeError.backupError(.encryptionFailed)
        }
        
        let backupID = SafeStore.getBackupID(key: key)
        let encryptionKey = SafeStore.getEncryptionKey(key: key)
        
        guard backupID != nil, encryptionKey != nil else {
            throw SafeError.backupError(.invalidID)
        }
        
        let unencryptedData = Data(data)
        // Use gzip for backward compatibility, but don't actually compress (to avoid compression oracles)
        let compressedData: Data = try unencryptedData.gzipped(level: .noCompression)
        
        if let nonce: Data = BytesUtility.generateRandomBytes(length: 24) {
            let crypto = NaClCrypto()
            let encryptedData: Data = crypto.symmetricEncryptData(
                compressedData,
                withKey: Data(bytes: encryptionKey!, count: encryptionKey!.count),
                nonce: nonce
            )
            
            var encryptedBackup = Data()
            encryptedBackup.append(nonce)
            encryptedBackup.append(encryptedData)
            
            return Array(encryptedBackup)
        }
        else {
            throw SafeError.backupError(.invalidData)
        }
    }
    
    static func decryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == SafeStore.masterKeyLength else {
            throw SafeError.restoreError(.invalidMasterKey)
        }
        guard !data.isEmpty else {
            throw SafeError.restoreError(.invalidData)
        }
        
        let backupID = SafeStore.getBackupID(key: key)
        let encryptionKey = getEncryptionKey(key: key)
        
        guard backupID != nil, encryptionKey != nil else {
            throw SafeError.restoreError(.invalidClientKey)
        }
        
        let nonce = data[0...23]
        let encryptedData = data[24...data.count - 1]
        
        let crypto = NaClCrypto()
        let decryptedData = crypto.symmetricDecryptData(
            Data(encryptedData),
            withKey: Data(encryptionKey!),
            nonce: Data(nonce)
        )!
        
        let uncompressedData = try decryptedData.gunzipped()
        
        return Array(uncompressedData)
    }
    
    // MARK: - Safe server
    
    /// Checks Threema Safe server has changed. Server can defined thru MDM or default server for OnPrem thru OPPF file.
    /// - Parameters:
    ///   - mdmSetup: MDM setup configuration
    ///   - completion: True if server has changed
    @objc func isSafeServerChanged(mdmSetup: MDMSetup, completion: @escaping (Bool) -> Void) {
        if mdmSetup.isSafeBackupServerPreset() {
            completion(
                mdmSetup.safeServerURL() != safeConfigManager.getServer()
                    || mdmSetup.safeServerUsername() != safeConfigManager.getServerUser()
                    || mdmSetup.safeServerPassword() != safeConfigManager.getServerPassword()
            )
        }
        else {
            guard safeConfigManager.getCustomServer() == nil || safeConfigManager.getCustomServer()?.isEmpty ?? true
            else {
                completion(false)
                return
            }
            
            SafeStore.getSafeDefaultServer(key: safeConfigManager.getKey()!) { result in
                switch result {
                case let .success(safeServer):
                    completion(self.safeConfigManager.getServer() != safeServer.server.absoluteString)
                case .failure:
                    completion(false)
                }
            }
        }
    }
    
    func getSafeServerToDisplay() -> String {
        if let server = safeConfigManager.getServer() {
            do {
                let regexDefaultServer = try NSRegularExpression(pattern: "https://safe-[0-9a-z]{2}.threema.ch")
                let regexResult = regexDefaultServer.matches(
                    in: server,
                    options: NSRegularExpression.MatchingOptions(rawValue: 0),
                    range: NSRange(location: 0, length: server.count)
                )
                if !regexResult.isEmpty {
                    return #localize("safe_use_default_server")
                }
            }
            catch {
                print("regex failed to check default server: \(error.localizedDescription)")
            }
            
            return safeConfigManager.getCustomServer() != nil ? safeConfigManager.getCustomServer()! : server
        }
        else {
            return #localize("safe_use_default_server")
        }
    }
    
    func getSafeServer(
        key: [UInt8],
        completion: @escaping (Swift.Result<(serverUser: String?, serverPassword: String?, server: URL), Error>) -> Void
    ) {
        if let server = safeConfigManager.getServer() {
            if let url = URL(string: server) {
                completion(.success((safeConfigManager.getServerUser(), safeConfigManager.getServerPassword(), url)))
            }
            else {
                completion(.failure(SafeError.invalidURL))
            }
        }
        else {
            SafeStore.getSafeDefaultServer(key: key, completion: completion)
        }
    }
    
    static func getSafeDefaultServer(
        key: [UInt8],
        completion: @escaping (Swift.Result<(serverUser: String?, serverPassword: String?, server: URL), Error>) -> Void
    ) {
        guard let backupID = SafeStore.getBackupID(key: key) else {
            completion(.failure(SafeError.backupError(.invalidKey)))
            return
        }
        
        ServerInfoProviderFactory.makeServerInfoProvider().safeServer(ipv6: false) { safeServerInfo, error in
            DispatchQueue.global().async {
                if let error {
                    completion(.failure(error))
                }
                else {
                    if let url = URL(string: safeServerInfo!.url.replacingOccurrences(
                        of: "{backupIdPrefix8}",
                        with: String(format: "%02hhx", backupID[0])
                    )) {
                        completion(.success((nil, nil, url)))
                    }
                    else {
                        completion(.failure(SafeError.invalidURL))
                    }
                }
            }
        }
    }
    
    /// Extract and return server url, user and password from https://user:password@host.com
    /// - Parameter server: Server URL with included credentials
    /// - Returns: User, Password and Server URL without credentials
    static func extractSafeServerAuth(server: URL) -> (serverUser: String?, serverPassword: String?, server: URL) {
        let httpProtocol = "https://"
        
        guard server.absoluteString.starts(with: httpProtocol) else {
            return (serverUser: nil, serverPassword: nil, server: server)
        }
        
        var user: String?
        var password: String?
        var serverURL: URL?
        
        if server.user != nil || server.password != nil {
            user = server.user?.removingPercentEncoding
            password = server.password?.removingPercentEncoding
            
            if let startServerURL = server.absoluteString.firstIndex(of: "@") {
                serverURL = URL(
                    string: httpProtocol + server
                        .absoluteString[
                            String
                                .Index(
                                    utf16Offset: startServerURL.utf16Offset(in: server.absoluteString) + 1,
                                    in: server.absoluteString
                                )...
                        ].description
                )
            }
            else {
                serverURL = server
            }
        }
        else {
            serverURL = server
        }
        
        return (serverUser: user, serverPassword: password, server: serverURL!)
    }
    
    // MARK: - Backup
    
    /// Get all backup data.
    /// - Parameter backupDeviceGroupKey: If false then DGK will not included in backup data (DGK must only included for
    /// device linking)
    /// - Returns: Backup data
    func backupData(backupDeviceGroupKey: Bool = false) -> [UInt8]? {
        // get identity
        guard let privateKey = myIdentityStore.clientKey else {
            return nil
        }
        let jUser = SafeJsonParser.SafeBackupData.User(privatekey: privateKey.base64EncodedString())
        
        if backupDeviceGroupKey {
            let deviceGroupKeyManager = DeviceGroupKeyManager()
            if let dgk = deviceGroupKeyManager.dgk {
                jUser.temporaryDeviceGroupKeyTodoRemove = dgk.base64EncodedString()
            }
        }
        
        jUser.nickname = myIdentityStore.pushFromName
        
        // get identity profile picture and its settings
        if let profilePicture = myIdentityStore.profilePicture {
            if let imageData = profilePicture["ProfilePicture"] as? Data {
                jUser.profilePic = downscaleImageAsBase64(data: imageData, max: 400)
            }
        }
        
        switch UserSettings.shared().sendProfilePicture {
        case SendProfilePictureAll:
            jUser.profilePicRelease = ["*"]
        case SendProfilePictureContacts:
            if let identities = UserSettings.shared().profilePictureContactList {
                jUser.profilePicRelease = identities.map { identity -> String in
                    "\(identity)"
                }
            }
        default:
            jUser.profilePicRelease = nil
        }
        
        // get identity linking, backup only email or mobile no is verified
        var jLinks = [SafeJsonParser.SafeBackupData.User.Link]()
        if let mobileNo = myIdentityStore.linkedMobileNo,
           !myIdentityStore.linkMobileNoPending {
            
            jLinks.append(SafeJsonParser.SafeBackupData.User.Link(type: "mobile", value: mobileNo))
        }
        if let email = MyIdentityStore.shared().linkedEmail,
           !MyIdentityStore.shared().linkEmailPending {
            jLinks.append(SafeJsonParser.SafeBackupData.User.Link(type: "email", value: email))
        }
        if !jLinks.isEmpty {
            jUser.links = jLinks
        }
        
        let privateEntityManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: AppLaunchManager.remoteSecretManager
        ).backgroundEntityManager
        
        // Get contacts
        var jContacts = [SafeJsonParser.SafeBackupData.Contact]()
        privateEntityManager.performAndWait {
            let allContacts = privateEntityManager.entityFetcher.contactEntities() ?? []
            for contact in allContacts {
                // Do not backup me as contact
                if contact.identity != MyIdentityStore.shared().identity {
                    
                    let jContact = SafeJsonParser.SafeBackupData.Contact(
                        identity: contact.identity,
                        verification: contact.contactVerificationLevel.rawValue
                    )
                    let verifiedLevel2OrInvalid = contact.contactVerificationLevel == .fullyVerified || !contact.isValid
                    jContact.publickey = verifiedLevel2OrInvalid ? contact.publicKey.base64EncodedString() : nil
                    jContact.workVerified = contact.workContact != 0
                    jContact.hidden = contact.isHidden
                    
                    if let firstname = contact.firstName {
                        jContact.firstname = firstname
                    }
                    if let lastname = contact.lastName {
                        jContact.lastname = lastname
                    }
                    if let nickname = contact.publicNickname {
                        jContact.nickname = nickname
                    }
                    if let createdAt = contact.createdAt {
                        jContact.createdAt = UInt64(createdAt.timeIntervalSince1970 * 1000)
                    }
                    
                    if let conversations = contact.conversations {
                        for conversation in conversations {
                            if conversation.conversationCategory == .private {
                                jContact.private = true
                                break
                            }
                        }
                    }
                    
                    jContact.readReceipts = contact.readReceipt.rawValue
                    jContact.typingIndicators = contact.typingIndicator.rawValue
                    
                    if let conversation = privateEntityManager.entityFetcher.conversationEntity(for: contact.identity),
                       let lastUpdate = conversation.lastUpdate {
                        jContact.lastUpdate = lastUpdate.millisecondsSince1970
                    }
                    
                    jContacts.append(jContact)
                }
            }
        }
        
        // Get groups
        var jGroups = [SafeJsonParser.SafeBackupData.Group]()
        privateEntityManager.performAndWait {
            let conversations = privateEntityManager.entityFetcher.groupConversationEntities() ?? []
            
            for conversation in conversations {
                guard let groupID = conversation.groupID,
                      let group = self.groupManager.getGroup(
                          groupID,
                          creator: conversation.contact?.identity ?? self.myIdentityStore.identity
                      )
                else {
                    continue
                }
                
                let id = group.groupID.hexString
                let creator: String =
                    if group.isOwnGroup {
                        self.myIdentityStore.identity
                    }
                    else {
                        group.groupCreatorIdentity
                    }
                
                let name = group.name ?? ""
                let members = Array(group.allMemberIdentities)
                
                var lastUpdate: UInt64?
                if let date = conversation.lastUpdate {
                    lastUpdate = date.millisecondsSince1970
                }
                
                let jGroup = SafeJsonParser.SafeBackupData.Group(
                    id: id,
                    creator: creator,
                    groupname: name,
                    members: members,
                    deleted: false,
                    lastUpdate: lastUpdate,
                    private: conversation.conversationCategory == .private
                )
                
                jGroups.append(jGroup)
            }
        }
        
        // Get settings
        let jSettings = SafeJsonParser.SafeBackupData.Settings()
        jSettings.syncContacts = UserSettings.shared().syncContacts
        jSettings.blockUnknown = UserSettings.shared().blockUnknown
        jSettings.readReceipts = UserSettings.shared().sendReadReceipts
        jSettings.sendTyping = UserSettings.shared().sendTypingIndicator
        jSettings.threemaCalls = UserSettings.shared().enableThreemaCall
        jSettings.relayThreemaCalls = UserSettings.shared().alwaysRelayCalls
        jSettings.blockedContacts = UserSettings.shared().blacklist.map { identity -> String in
            identity as! String
        }
        jSettings.syncExcludedIDs = UserSettings.shared().syncExclusionList.map { identity -> String in
            identity as! String
        }
        
        let parser = SafeJsonParser()
        var safeBackupData = parser.getSafeBackupData()
        
        safeBackupData.user = jUser
        if !jContacts.isEmpty {
            safeBackupData.contacts = jContacts
        }
        if !jGroups.isEmpty {
            safeBackupData.groups = jGroups
        }
        safeBackupData.settings = jSettings
        
        return parser.getJsonAsBytes(from: safeBackupData)!
    }
    
    // MARK: - Restore
    
    func restoreData(
        safeBackupData: SafeJsonParser.SafeBackupData,
        onlyIdentity: Bool
    ) async throws {
        
        DDLogNotice("[ThreemaSafe Restore] Restoring user data")

        // Check backup version
        guard safeBackupData.info.version == 1 else {
            DDLogError("[ThreemaSafe Restore] Safe version mismatch")
            throw SafeError.restoreError(.versionMismatch)
        }
        
        if let key = safeBackupData.user?.temporaryDeviceGroupKeyTodoRemove,
           let dgk = Data(base64Encoded: key) {
            let deviceGroupKeyManager = DeviceGroupKeyManager()
            deviceGroupKeyManager.store(dgk: dgk)
        }
        
        if let nickname = safeBackupData.user?.nickname {
            myIdentityStore.pushFromName = nickname
        }
        
        // Use MDM configuration for linking ID, if exists. Otherwise get linking configuration from Threema
        // Safe backup
        let mdmSetup = MDMSetup()!
        if mdmSetup.existsMdmKey(MDM_KEY_LINKED_PHONE) ||
            mdmSetup.existsMdmKey(MDM_KEY_LINKED_EMAIL) ||
            mdmSetup.readonlyProfile() {
            if let createIDPhone = myIdentityStore.createIDPhone,
               !createIDPhone.isEmpty {
                
                let normalizer: PhoneNumberNormalizer! = PhoneNumberNormalizer.sharedInstance()
                var prettyMobileNo: NSString?
               
                if let mobileNo = normalizer.phoneNumber(
                    toE164: myIdentityStore.createIDPhone,
                    withDefaultRegion: PhoneNumberNormalizer.userRegion(),
                    prettyFormat: &prettyMobileNo
                ),
                    !mobileNo.isEmpty {
                    
                    link(mobileNo: mobileNo)
                }
            }
            
            if let createIDEmail = myIdentityStore.createIDEmail,
               !createIDEmail.isEmpty {
                
                link(email: createIDEmail)
            }
        }
        else {
            if let links = safeBackupData.user?.links,
               !links.isEmpty {
                
                for link in links {
                    if link.type == "mobile" {
                        if var linkMobile = link.value {
                            if !linkMobile.starts(with: "+") {
                                linkMobile = "+\(linkMobile)"
                            }
                            let numbers = localizedMobileNo("+\(linkMobile)")
                            if let mobileNo = numbers.mobileNo {
                                self.link(mobileNo: mobileNo)
                            }
                        }
                    }
                    if link.type == "email",
                       let email = link.value {
                        
                        self.link(email: email)
                    }
                }
            }
        }
        
        // Restore profile picture
        if let profilePic = safeBackupData.user?.profilePic,
           let profilePicData = Data(base64Encoded: profilePic) {
            
            let profilePicture: NSMutableDictionary = myIdentityStore
                .profilePicture ?? NSMutableDictionary(dictionary: ["ProfilePicture": profilePicData])
            
            MyIdentityStore.shared().profilePicture = profilePicture
        }
        
        if onlyIdentity {
            setProfilePictureRequestList()
        }
        else {
            DDLogNotice("[ThreemaSafe Restore] Restoring user settings")
            restoreUserSettings(safeBackupData: safeBackupData)
            
            let entityManager = BusinessInjector.ui.entityManager
            
            try await restoreContacts(
                entityManager: entityManager,
                safeBackupData: safeBackupData
            )
            
            await restoreGroups(
                entityManager: entityManager,
                safeBackupData: safeBackupData
            )
        }
        
        DDLogNotice("[ThreemaSafe Restore] Updating work info in license store")
        LicenseStore.shared().performUpdateWorkInfo()
        
        AppSetup.state = .identitySetupComplete
    }
    
    private func restoreUserSettings(safeBackupData: SafeJsonParser.SafeBackupData) {
        
        let userSettings = UserSettings.shared()!
        
        if let profilePicRelease = safeBackupData.user?.profilePicRelease {
            if profilePicRelease.count == 1, profilePicRelease[0] == "*" {
                userSettings.sendProfilePicture = SendProfilePictureAll
            }
            else if profilePicRelease.count == 1, profilePicRelease[0] == nil {
                userSettings.sendProfilePicture = SendProfilePictureNone
            }
            else if !profilePicRelease.isEmpty {
                userSettings.sendProfilePicture = SendProfilePictureContacts
                var profilePicReleaseArray = [String]()
                for picReleaseIdentity in profilePicRelease {
                    if let identity = picReleaseIdentity,
                       identity.count == kIdentityLen {
                        profilePicReleaseArray.append(identity)
                    }
                }
                userSettings.profilePictureContactList = profilePicReleaseArray
            }
            else {
                userSettings.sendProfilePicture = SendProfilePictureNone
            }
        }
        else {
            userSettings.sendProfilePicture = SendProfilePictureNone
        }
        
        // Restore settings, contacts and groups
        let mdmSetup = MDMSetup()!
        let settings = safeBackupData.settings!
        userSettings.safeIntroShown = true
        if !mdmSetup.existsMdmKey(MDM_KEY_CONTACT_SYNC) {
            userSettings.syncContacts = settings.syncContacts
        }
        userSettings.blockUnknown = settings.blockUnknown ?? false
        userSettings.sendReadReceipts = settings.readReceipts ?? true
        userSettings.sendTypingIndicator = settings.sendTyping ?? true
        if ThreemaEnvironment.supportsCallKit() {
            userSettings.enableThreemaCall = settings.threemaCalls ?? true
        }
        else {
            userSettings.enableThreemaCall = false
        }
        userSettings.alwaysRelayCalls = settings.relayThreemaCalls ?? false
        if let blockedContacts = settings.blockedContacts {
            userSettings.blacklist = NSOrderedSet(array: blockedContacts)
        }
        if let syncExcludedIDs = settings.syncExcludedIDs {
            userSettings.syncExclusionList = syncExcludedIDs
        }
    }
    
    private func restoreContacts(
        entityManager: EntityManager,
        safeBackupData: SafeJsonParser.SafeBackupData
    ) async throws {
        DDLogNotice("[ThreemaSafe Restore] Restoring contacts")

        guard let backupContacts = safeBackupData.contacts else {
            DDLogNotice("[ThreemaSafe Restore] No contacts to restore")
            return
        }
        
        // Fetch info for identities
        let backupContactsIdentities = backupContacts.compactMap(\.identity)
        
        guard !backupContactsIdentities.isEmpty else {
            return
        }
        
        DDLogNotice("[ThreemaSafe Restore] Fetching contact identities")
        let (fetchedIdentities, publicKeys, featureMasks, states, types) = try await serverApiConnector
            .fetchBulkIdentityInfo(backupContactsIdentities)
        
        guard let fetchedIdentities, !fetchedIdentities.isEmpty else {
            DDLogNotice("[ThreemaSafe Restore] Fetched contact identities are empty")
            return
        }
        
        DDLogNotice("[ThreemaSafe Restore] Restoring contact entities")
        for (index, id) in fetchedIdentities.enumerated() {
            // Get contact from backup that matches id from fetched id's
            let backupContact = backupContacts.first {
                if let identity = $0.identity, identity.uppercased() == id as? String {
                    return true
                }
                return false
            }
            
            guard let backupContact, let backupContactIdentity = backupContact.identity else {
                continue
            }
            
            // Do not restore me as contact
            guard backupContactIdentity.uppercased() != myIdentityStore.identity.uppercased() else {
                continue
            }
            
            guard let publicKey = publicKeys?[index] as? Data else {
                continue
            }
            
            var contactForConversation: ContactEntity?
            
            // Check is contact already stored, could be when Threema MDM sync was running (it's a bug, should not
            // before restore is finished)
            try entityManager.performAndWaitSave {
                if let contact = entityManager.entityFetcher.contactEntity(for: backupContactIdentity) {
                    contact.contactVerificationLevel = ContactEntity
                        .VerificationLevel(
                            rawValue: backupContact.verification ?? ContactEntity
                                .VerificationLevel.unverified.rawValue
                        ) ?? .unverified
                    contact.setFirstName(
                        to: backupContact.firstname,
                        sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName
                    )
                    contact.setLastName(
                        to: backupContact.lastname,
                        sortOrderFirstName: BusinessInjector.ui.userSettings.sortOrderFirstName
                    )
                    contact.publicNickname = backupContact.nickname
                    
                    contactForConversation = contact
                }
                else {
                    let contact = try entityManager.getOrCreateContact(
                        identity: backupContactIdentity.uppercased(),
                        publicKey: publicKey,
                        sortOrderFirstName: BusinessInjector.ui.userSettings
                            .sortOrderFirstName
                    )
                    
                    contact.contactVerificationLevel = ContactEntity
                        .VerificationLevel(
                            rawValue: backupContact.verification ?? ContactEntity
                                .VerificationLevel.unverified.rawValue
                        ) ??
                        .unverified
                    contact.setFirstName(
                        to: backupContact.firstname,
                        sortOrderFirstName: BusinessInjector.ui.userSettings
                            .sortOrderFirstName
                    )
                    contact.setLastName(
                        to: backupContact.lastname,
                        sortOrderFirstName: BusinessInjector.ui.userSettings
                            .sortOrderFirstName
                    )
                    contact.publicNickname = backupContact.nickname
                    
                    if let createdAt = backupContact.createdAt,
                       createdAt != 0 {
                        contact
                            .createdAt =
                            Date(timeIntervalSince1970: Double(createdAt) / 1000)
                    }
                    else {
                        contact.createdAt = nil
                    }
                    
                    if let hidden = backupContact.hidden {
                        contact.isHidden = hidden
                    }
                    
                    contact.readReceipt =
                        if let readReceipts = backupContact.readReceipts {
                            ContactEntity.ReadReceipt(rawValue: readReceipts) ?? .default
                        }
                        else {
                            .default
                        }
                    
                    contact.typingIndicator =
                        if let typingIndicators = backupContact
                            .typingIndicators {
                            ContactEntity
                                .TypingIndicator(rawValue: typingIndicators) ?? .default
                        }
                        else {
                            .default
                        }
                    
                    if let workVerified = backupContact.workVerified {
                        contact.workContact = workVerified ? 1 : 0
                    }
                    else {
                        contact.workContact = 0
                    }
                    
                    if let featureMasks,
                       let featureMask = featureMasks[index] as? Int {
                        contact.setFeatureMask(to: featureMask)
                    }
                    
                    if let states,
                       let state = states[index] as? Int {
                        contact.contactState = ContactEntity
                            .ContactState(rawValue: state) ?? .active
                    }
                    if let types, let type = types[index] as? Int {
                        if type == 1 {
                            ContactStore.shared()
                                .addAsWork(
                                    identities: NSOrderedSet(array: [
                                        contact
                                            .identity,
                                    ]),
                                    contactSyncer: nil
                                )
                        }
                    }
                    
                    contactForConversation = contact
                }
            }
            
            // Create conversation if last update set or the contact is private
            if let contactForConversation,
               backupContact.lastUpdate != nil || backupContact.private ?? false {
                entityManager.performAndWaitSave {
                    if let conversation = entityManager.conversation(
                        forContact: contactForConversation,
                        createIfNotExisting: true,
                        setLastUpdate: false
                    ) {
                        
                        if let lastUpdate = backupContact.lastUpdate {
                            conversation.lastUpdate = Date(millisecondsSince1970: lastUpdate)
                        }
                        
                        if let isPrivate = backupContact.private, isPrivate {
                            conversation.changeCategory(to: .private)
                        }
                    }
                }
            }
        }
        
        setProfilePictureRequestList()
    }
    
    private func restoreGroups(
        entityManager: EntityManager,
        safeBackupData: SafeJsonParser.SafeBackupData,
    ) async {
        DDLogNotice("[ThreemaSafe Restore] Restoring groups")

        guard let backupGroups = safeBackupData.groups else {
            DDLogNotice("[ThreemaSafe Restore] No groups to restore")
            return
        }
        
        for backupGroup in backupGroups {
            guard let groupID = backupGroup.id,
                  let groupCreator = backupGroup.creator,
                  let members = backupGroup.members else {
                DDLogWarn("[ThreemaSafe Restore] Safe restore group id, creator or members missing")
                continue
            }
            
            do {
                guard let group = try await groupManager.createOrUpdateDB(
                    for: GroupIdentity(
                        id: Data(BytesUtility.toBytes(hexString: groupID)!),
                        creator: ThreemaIdentity(groupCreator)
                    ),
                    members: Set<String>(members.map { $0.uppercased() }),
                    systemMessageDate: nil,
                    sourceCaller: .local
                ) else {
                    DDLogWarn("[ThreemaSafe Restore] Restoring group failed")
                    return
                }
                
                var category: ConversationEntity.Category = .default
                
                if let isPrivate = backupGroup.private,
                   isPrivate {
                    category = .private
                }
                
                await entityManager.performSave {
                    group.conversation.groupName = backupGroup.groupname
                    group.conversation.changeCategory(to: category)
                    
                    if let lastUpdate = backupGroup.lastUpdate {
                        group.conversation.lastUpdate = Date(millisecondsSince1970: lastUpdate)
                    }
                }
                
                // No sync is needed as this will be done in the `AppUpdateSteps`
            }
            catch {
                DDLogWarn("[ThreemaSafe Restore] Restoring group failed with error: \(error)")
            }
        }
    }
    
    private func setProfilePictureRequestList() {
        DDLogNotice(
            "[ThreemaSafe Restore] Restoring profile picture request list"
        )
        guard let userSettings = UserSettings.shared() else {
            return
        }
        var profilePicRequest = [String]()
        
        let entityManager = BusinessInjector.ui.entityManager
        entityManager.performAndWait {
            if let contacts = entityManager.entityFetcher.contactEntities() {
                for contact in contacts {
                    if contact.identity != "ECHOECHO", contact.identity != self.myIdentityStore.identity {
                        profilePicRequest.append(contact.identity)
                    }
                }
            }
        }
        
        userSettings.profilePictureRequestList = profilePicRequest
    }
    
    private func downscaleImageAsBase64(data: Data, max: CGFloat) -> String? {
        if let image = UIImage(data: data) {
            // Downscale profile picture to max. size and quality 60, if is necessary
            if image.size.height > max || image.size.width > max {
                var newHeight: CGFloat
                var newWidth: CGFloat
                if image.size.height > image.size.width {
                    newHeight = max
                    newWidth = (newHeight / image.size.height) * image.size.width
                }
                else {
                    newWidth = max
                    newHeight = (newWidth / image.size.width) * image.size.height
                }
                
                let resizedImage = resizeImage(image: image, size: CGSize(width: newWidth, height: newHeight))!
                let resizedData = resizedImage.jpegData(compressionQuality: 0.6)
                
                return resizedData?.base64EncodedString()
            }
            else {
                return data.base64EncodedString()
            }
        }
        else {
            return nil
        }
    }
    
    private func resizeImage(image: UIImage, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    private func localizedMobileNo(_ mobileNo: String) -> (mobileNo: String?, prettyMobileNo: String?) {
        if !mobileNo.isEmpty {
            let normalizer: PhoneNumberNormalizer! = PhoneNumberNormalizer.sharedInstance()
            var prettyMobileNo: NSString?
            
            let localMobileNo = normalizer.phoneNumber(
                toE164: mobileNo,
                withDefaultRegion: PhoneNumberNormalizer.userRegion(),
                prettyFormat: &prettyMobileNo
            )
            return (mobileNo: localMobileNo, prettyMobileNo: prettyMobileNo as String?)
        }
        return (mobileNo: nil, prettyMobileNo: nil)
    }
    
    private func link(mobileNo: String) {
        serverApiConnector.linkMobileNo(
            with: myIdentityStore as? MyIdentityStore,
            mobileNo: mobileNo,
            onCompletion: { _ in
                DDLogInfo("Safe restore linking mobile no with identity successfull")
            },
            onError: { _ in
                DDLogError("Safe restore linking mobile no with identity failed")
            }
        )
    }
    
    private func link(email: String) {
        serverApiConnector.linkEmail(with: myIdentityStore as? MyIdentityStore, email: email, onCompletion: { _ in
            DDLogInfo("Safe restore linking email with identity successfull")
        }, onError: { _ in
            DDLogError("Safe restore linking email with identity failed")
        })
    }
}
