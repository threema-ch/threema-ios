//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2024 Threema GmbH
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
import ThreemaEssentials
import ThreemaFramework
import ThreemaMacros

@objc class SafeStore: NSObject {
    private let safeConfigManager: SafeConfigManagerProtocol
    private let serverApiConnector: ServerAPIConnector
    private let groupManager: GroupManagerProtocol
    
    @objc public let masterKeyLength = 64
    private let backupIDLength = 32
    private let encryptionKeyLength = 32
    
    enum SafeError: Error {
        case invalidMasterKey
        case invalidData
        case invalidURL
        case badMasterKey
        case restoreError(message: String)
        case restoreFailed(message: String)
    }

    init(
        safeConfigManager: SafeConfigManagerProtocol,
        serverApiConnector: ServerAPIConnector,
        groupManager: GroupManagerProtocol
    ) {
        self.safeConfigManager = safeConfigManager
        self.serverApiConnector = serverApiConnector
        self.groupManager = groupManager
    }
    
    // NSObject thereby not the whole SafeConfigManagerProtocol interface must be like @objc
    @objc convenience init(
        safeConfigManagerAsObject safeConfigManager: NSObject,
        serverApiConnector: ServerAPIConnector,
        groupManager: GroupManager
    ) {
        self.init(
            safeConfigManager: safeConfigManager as! SafeConfigManagerProtocol,
            serverApiConnector: serverApiConnector,
            groupManager: groupManager
        )
    }
    
    // MARK: - keys and encryption
    
    /// Create/derive Threema Safe backup key
    /// - Parameters:
    ///   - identity: Threema ID
    ///   - safePassword: Password entered by the user when activating the backup
    func createKey(identity: String, safePassword: String?) -> [UInt8]? {
        guard let safePassword,
              !safePassword.isEmpty else {
            return nil
        }
        let pPassword = UnsafeMutablePointer<Int8>(strdup(safePassword))
        let pSalt = UnsafeMutablePointer<Int8>(strdup(identity))
        
        let pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: masterKeyLength)
        
        defer {
            pPassword?.deallocate()
            pSalt?.deallocate()
            pOut.deallocate()
        }
        
        if getDerivedKey(pPassword, pSalt, pOut) != 0 {
            return nil
        }
        
        return Array(UnsafeMutableBufferPointer(start: pOut, count: masterKeyLength))
    }

    func getBackupID(key: [UInt8]) -> [UInt8]? {
        if key.count == masterKeyLength {
            return Array(key[0..<backupIDLength])
        }
        return nil
    }
    
    func getEncryptionKey(key: [UInt8]) -> [UInt8]? {
        if key.count == masterKeyLength {
            return Array(key[masterKeyLength - encryptionKeyLength..<masterKeyLength])
        }
        return nil
    }
    
    func encryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == masterKeyLength else {
            throw SafeError.invalidMasterKey
        }
        guard !data.isEmpty else {
            throw SafeError.invalidData
        }
        
        let backupID = getBackupID(key: key)
        let encryptionKey = getEncryptionKey(key: key)
        
        guard backupID != nil, encryptionKey != nil else {
            throw SafeError.invalidMasterKey
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
            throw SafeError.invalidData
        }
    }
    
    func decryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == masterKeyLength else {
            throw SafeError.invalidMasterKey
        }
        guard !data.isEmpty else {
            throw SafeError.invalidData
        }
        
        let backupID = getBackupID(key: key)
        let encryptionKey = getEncryptionKey(key: key)
        
        guard backupID != nil, encryptionKey != nil else {
            throw SafeError.invalidMasterKey
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
    
    func isDateOlderThenDays(date: Date?, days: Int) -> Bool {
        date == nil || (date != nil && (date!.addingTimeInterval(TimeInterval(86400 * days)) < Date()))
    }
    
    // MARK: - safe server
    
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
            getSafeDefaultServer(key: safeConfigManager.getKey()!) { result in
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
            getSafeDefaultServer(key: key, completion: completion)
        }
    }
    
    func getSafeDefaultServer(
        key: [UInt8],
        completion: @escaping (Swift.Result<(serverUser: String?, serverPassword: String?, server: URL), Error>) -> Void
    ) {
        guard let backupID = getBackupID(key: key) else {
            completion(.failure(SafeError.badMasterKey))
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

    // MARK: - back up and restore data

    /// Get all backup data.
    /// - Parameter backupDeviceGroupKey: If false then DGK will not included in backup data (DGK must only included for
    /// device linking)
    /// - Returns: Backup data
    func backupData(backupDeviceGroupKey: Bool = false) -> [UInt8]? {
        // get identity
        if MyIdentityStore.shared().keySecret() == nil {
            return nil
        }
        let jUser = SafeJsonParser.SafeBackupData
            .User(privatekey: MyIdentityStore.shared().keySecret().base64EncodedString())

        if backupDeviceGroupKey {
            let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: MyIdentityStore.shared())
            if let dgk = deviceGroupKeyManager.dgk {
                jUser.temporaryDeviceGroupKeyTodoRemove = dgk.base64EncodedString()
            }
        }

        jUser.nickname = MyIdentityStore.shared().pushFromName
        
        // get identity profile picture and its settings
        if let profilePicture = MyIdentityStore.shared().profilePicture {
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
        if let mobileNo = MyIdentityStore.shared().linkedMobileNo,
           !MyIdentityStore.shared().linkMobileNoPending {
            
            jLinks.append(SafeJsonParser.SafeBackupData.User.Link(type: "mobile", value: mobileNo))
        }
        if let email = MyIdentityStore.shared().linkedEmail,
           !MyIdentityStore.shared().linkEmailPending {
            jLinks.append(SafeJsonParser.SafeBackupData.User.Link(type: "email", value: email))
        }
        if !jLinks.isEmpty {
            jUser.links = jLinks
        }
        
        let privateEntityManager = EntityManager(withChildContextForBackgroundProcess: true)

        // get contacts
        var jContacts = [SafeJsonParser.SafeBackupData.Contact]()
        privateEntityManager.performAndWait {
            let allContacts = privateEntityManager.entityFetcher.allContacts() ?? []
            for item in allContacts {
                // do not backup me as contact
                if let contact = item as? ContactEntity,
                   contact.identity != MyIdentityStore.shared()?.identity {
                    
                    let jContact = SafeJsonParser.SafeBackupData.Contact(
                        identity: contact.identity,
                        verification: Int(truncating: contact.verificationLevel)
                    )
                    let verifiedLevel2OrInvalid = contact.verificationLevel == 2 || !contact.isValid()
                    jContact.publickey = verifiedLevel2OrInvalid ? contact.publicKey.base64EncodedString() : nil
                    jContact.workVerified = contact.workContact != 0
                    jContact.hidden = contact.isContactHidden
                    
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
                            guard let conversation = conversation as? ConversationEntity else {
                                continue
                            }
                            if conversation.conversationCategory == .private {
                                jContact.private = true
                                break
                            }
                        }
                    }
                    
                    jContact.readReceipts = contact.readReceipt.rawValue
                    jContact.typingIndicators = contact.typingIndicator.rawValue

                    if let conversation = privateEntityManager.entityFetcher.conversation(for: contact),
                       let lastUpdate = conversation.lastUpdate {
                        jContact.lastUpdate = lastUpdate.millisecondsSince1970
                    }
                    
                    jContacts.append(jContact)
                }
            }
        }
        
        // get groups
        var jGroups = [SafeJsonParser.SafeBackupData.Group]()
        privateEntityManager.performAndWait {
            let conversations = privateEntityManager.entityFetcher.allGroupConversations() ?? []
            
            for item in conversations {
                guard let conversation = item as? ConversationEntity,
                      let groupID = conversation.groupID,
                      let group = self.groupManager.getGroup(
                          groupID,
                          creator: conversation.contact?.identity ?? MyIdentityStore.shared().identity
                      )
                else {
                    continue
                }
                
                let id = group.groupID.hexString
                let creator: String =
                    if group.isOwnGroup {
                        MyIdentityStore.shared().identity
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

        // get settings
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
        
        // print(parser.getJsonAsString(from: safeBackupData)!)
        return parser.getJsonAsBytes(from: safeBackupData)!
    }
    
    func restoreData(
        identity: String,
        data: [UInt8],
        onlyIdentity: Bool,
        completionHandler: @escaping (SafeError?) -> Swift.Void
    ) throws {
        
        // print(String(bytes: data, encoding: .utf8)!)
        
        // Check backup version
        let parser = SafeJsonParser()
        var safeBackupData: SafeJsonParser.SafeBackupData

        do {
            safeBackupData = try parser.getSafeBackupData(from: Data(data))
        }
        catch let error as DecodingError {
            // Log more informations about the parser error
            switch error {
            case let .typeMismatch(_, value):
                throw SafeError
                    .restoreFailed(
                        message: "\(error.localizedDescription) (TypeMissmatch: \(value.debugDescription), \(self.allKeys(from: value.codingPath)))"
                    )
            case let .valueNotFound(_, value):
                throw SafeError
                    .restoreFailed(
                        message: "\(error.localizedDescription) (ValueNotFound: \(value.debugDescription), \(self.allKeys(from: value.codingPath)))"
                    )
            case let .keyNotFound(_, value):
                throw SafeError
                    .restoreFailed(
                        message: "\(error.localizedDescription) (KeyNotFound: \(value.debugDescription), \(self.allKeys(from: value.codingPath)))"
                    )
            case let .dataCorrupted(context):
                throw SafeError
                    .restoreFailed(
                        message: "\(error.localizedDescription) (DataCorrupted: \(context.debugDescription), \(context.codingPath)"
                    )
            default:
                throw SafeError.restoreFailed(message: error.localizedDescription)
            }
        }
        
        guard safeBackupData.info.version == 1 else {
            throw SafeError.restoreFailed(message: #localize("safe_version_mismatch"))
        }
        
        // Restore identity store
        guard let privateKey = safeBackupData.user?.privatekey,
              let secretKey = Data(base64Encoded: privateKey) else {
                
            DDLogError("Private key could not be restored")
            throw SafeError.restoreFailed(message: #localize("safe_no_backup_found"))
        }
        
        MyIdentityStore.shared().restore(fromBackup: identity, withSecretKey: secretKey, onCompletion: {
            // Store identity in keychain
            MyIdentityStore.shared().storeInKeychain()

            if let key = safeBackupData.user?.temporaryDeviceGroupKeyTodoRemove,
               let dgk = Data(base64Encoded: key) {
                let deviceGroupKeyManager = DeviceGroupKeyManager(myIdentityStore: MyIdentityStore.shared())
                deviceGroupKeyManager.store(dgk: dgk)
            }

            self.serverApiConnector.update(MyIdentityStore.shared(), onCompletion: { () in
                MyIdentityStore.shared().storeInKeychain()

                AppSetup.state = .identityAdded
                
                if let nickname = safeBackupData.user?.nickname {
                    MyIdentityStore.shared().pushFromName = nickname
                }
                
                // Use MDM configuration for linking ID, if exists. Otherwise get linking configuration from Threema
                // Safe backup
                let mdmSetup = MDMSetup(setup: true)!
                if mdmSetup.existsMdmKey(MDM_KEY_LINKED_PHONE) || mdmSetup
                    .existsMdmKey(MDM_KEY_LINKED_EMAIL) || mdmSetup.readonlyProfile() {
                    if let createIDPhone = MyIdentityStore.shared()?.createIDPhone,
                       !createIDPhone.isEmpty {
                        
                        let normalizer: PhoneNumberNormalizer! = PhoneNumberNormalizer.sharedInstance()
                        var prettyMobileNo: NSString?
                        if let mobileNo = normalizer.phoneNumber(
                            toE164: MyIdentityStore.shared()?.createIDPhone,
                            withDefaultRegion: PhoneNumberNormalizer.userRegion(),
                            prettyFormat: &prettyMobileNo
                        ),
                            !mobileNo.isEmpty {
                            
                            self.link(mobileNo: mobileNo)
                        }
                    }
                    
                    if let createIDEmail = MyIdentityStore.shared()?.createIDEmail,
                       !createIDEmail.isEmpty {
                        
                        self.link(email: createIDEmail)
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
                                    let numbers = self.localizedMobileNo("+\(linkMobile)")
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
                    
                    let profilePicture: NSMutableDictionary = MyIdentityStore.shared()
                        .profilePicture != nil ? MyIdentityStore.shared()
                        .profilePicture : NSMutableDictionary(dictionary: ["ProfilePicture": profilePicData])
                    
                    MyIdentityStore.shared().profilePicture = profilePicture
                }
                
                if onlyIdentity {
                    self.setProfilePictureRequestList()
                    
                    completionHandler(nil)
                }
                else {
                    self.restoreUserSettings(safeBackupData: safeBackupData)
                    self.restoreContactsAndGroups(
                        identity: identity,
                        safeBackupData: safeBackupData,
                        completionHandler: completionHandler
                    )
                }
                
                LicenseStore.shared().performUpdateWorkInfo()
                
                AppSetup.state = .identitySetupComplete
                
            }, onError: { _ in
                DDLogError("Safe restore error:update identity store failed")
                completionHandler(
                    SafeError
                        .restoreFailed(message: #localize("safe_no_backup_found"))
                )
            })
        }) { _ in
            DDLogError("Safe restore error:update restore identity store failed")
            completionHandler(
                SafeError
                    .restoreFailed(message: #localize("safe_no_backup_found"))
            )
        }
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
                userSettings.profilePictureContactList = profilePicRelease as [Any]
            }
            else {
                userSettings.sendProfilePicture = SendProfilePictureNone
            }
        }
        else {
            userSettings.sendProfilePicture = SendProfilePictureNone
        }

        // Restore settings, contacts and groups
        let mdmSetup = MDMSetup(setup: true)!
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
    
    private func restoreContactsAndGroups(
        identity: String,
        safeBackupData: SafeJsonParser.SafeBackupData,
        completionHandler: @escaping (SafeError?) -> Swift.Void
    ) {
        
        let entityManager = EntityManager()

        if let bContacts = safeBackupData.contacts {
    
            var fetchIdentities = [String]()
            for bContact in bContacts {
                if let identity = bContact.identity {
                    fetchIdentities.append(identity)
                }
            }
            
            serverApiConnector.fetchBulkIdentityInfo(
                fetchIdentities,
                onCompletion: { identities, publicKeys, featureMasks, states, types in
                
                    var index = 0
                    for id in identities! {
                        var bContact: SafeJsonParser.SafeBackupData.Contact?
                        if bContacts.contains(where: { c -> Bool in
                            if let identity = c.identity,
                               identity.uppercased() == id as! String {
                            
                                bContact = c
                                return true
                            }
                            return false
                        }) {
                            // Do not restore me as contact
                            if let bContact,
                               let contactIdentity = bContact.identity,
                               contactIdentity.uppercased() != identity.uppercased() {

                                if let publicKey = publicKeys?[index] as? Data {
                                    var contactForConversation: ContactEntity?

                                    // check is contact already stored, could be when Threema MDM sync was running (it's
                                    // a bug, should not before restore is finished)
                                    if let contact = entityManager.entityFetcher.contact(for: bContact.identity) {
                                        entityManager.performAndWaitSave {
                                            contact.verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                            contact.firstName = bContact.firstname
                                            contact.lastName = bContact.lastname
                                            contact.publicNickname = bContact.nickname
                                        }

                                        contactForConversation = contact
                                    }
                                    else {
                                        entityManager.performAndWaitSave {
                                            if let contact = entityManager.entityCreator.contact(),
                                               let bIdentity = bContact.identity {
                                                contact.identity = bIdentity.uppercased()
                                                contact
                                                    .verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                                contact.firstName = bContact.firstname
                                                contact.lastName = bContact.lastname
                                                contact.publicNickname = bContact.nickname
                                                
                                                if let createdAt = bContact.createdAt,
                                                   createdAt != 0 {
                                                    contact
                                                        .createdAt =
                                                        Date(timeIntervalSince1970: Double(createdAt) / 1000)
                                                }
                                                else {
                                                    contact.createdAt = nil
                                                }
                                                
                                                if let hidden = bContact.hidden {
                                                    contact.isContactHidden = hidden
                                                }
                                            
                                                contact.readReceipt = bContact
                                                    .readReceipts != nil ?
                                                    ReadReceipt(rawValue: bContact.readReceipts!)! :
                                                    ReadReceipt.default
                                                contact.typingIndicator = bContact
                                                    .typingIndicators != nil ?
                                                    TypingIndicator(rawValue: bContact.typingIndicators!)! :
                                                    TypingIndicator
                                                    .default
                                            
                                                if let workVerified = bContact.workVerified {
                                                    contact.workContact = workVerified ? 1 : 0
                                                }
                                                else {
                                                    contact.workContact = 0
                                                }
                                                contact.publicKey = publicKey
                                            
                                                if let featureMasks,
                                                   let featureMask = featureMasks[index] as? Int {
                                                    contact.featureMask = NSNumber(integerLiteral: featureMask)
                                                }
                                                if let states,
                                                   let state = states[index] as? Int {
                                                    contact.state = NSNumber(integerLiteral: state)
                                                }
                                                if let types,
                                                   let type = types[index] as? Int {
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
                                    }

                                    // Create conversation if last update set or the contact is private
                                    if let contactForConversation,
                                       bContact.lastUpdate != nil || bContact.private ?? false {
                                        entityManager.performAndWaitSave {
                                            if let conversation = entityManager.conversation(
                                                forContact: contactForConversation,
                                                createIfNotExisting: true,
                                                setLastUpdate: false
                                            ) {

                                                if let lastUpdate = bContact.lastUpdate {
                                                    conversation.lastUpdate = Date(millisecondsSince1970: lastUpdate)
                                                }

                                                if let isPrivate = bContact.private, isPrivate {
                                                    conversation.changeCategory(to: .private)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    
                        index += 1
                    }
                
                    if index > 0 {
                        self.setProfilePictureRequestList()

                        self.restoreGroups(
                            identity: identity,
                            safeBackupData: safeBackupData,
                            entityManager: entityManager
                        )
                    }
                
                    completionHandler(nil)
                }
            ) { error in
                if let error {
                    DDLogError("Safe error while request identities:\(error.localizedDescription)")
                    completionHandler(
                        SafeError
                            .restoreError(message: #localize("safe_restore_error"))
                    )
                }
            }
        }
        else {
            DDLogError("Contact list was nil")
            completionHandler(nil)
        }
    }
    
    private func restoreGroups(
        identity: String,
        safeBackupData: SafeJsonParser.SafeBackupData,
        entityManager: EntityManager
    ) {
        if let bGroups = safeBackupData.groups {
            for bGroup in bGroups {
                if let groupID = bGroup.id,
                   let groupCreator = bGroup.creator,
                   let members = bGroup.members {
                    
                    Task { @MainActor in
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
                                DDLogWarn("Safe restore group could not be created")
                                return
                            }

                            var category: ConversationEntity.Category = .default

                            if let isPrivate = bGroup.private,
                               isPrivate {
                                category = .private
                            }

                            await entityManager.performSave {
                                group.conversation.groupName = bGroup.groupname
                                group.conversation.changeCategory(to: category)

                                if let lastUpdate = bGroup.lastUpdate {
                                    group.conversation.lastUpdate = Date(millisecondsSince1970: lastUpdate)
                                }
                            }

                            // No sync is needed as this will be done in the `AppUpdateSteps`
                        }
                        catch {
                            DDLogError("Safe restore group failed: \(error)")
                        }
                    }
                }
                else {
                    DDLogWarn("Safe restore group id, creator or members missing")
                }
            }
        }
    }

    private func setProfilePictureRequestList() {
        if let userSettings = UserSettings.shared() {
            var profilePicRequest = [String]()
            
            let entityManager = EntityManager()
            if let contacts = entityManager.entityFetcher.allContacts() as? [ContactEntity] {
                for contact in contacts {
                    if contact.identity != "ECHOECHO", contact.identity != MyIdentityStore.shared()?.identity {
                        profilePicRequest.append(contact.identity)
                    }
                }
            }
        
            userSettings.profilePictureRequestList = profilePicRequest
        }
    }
    
    private func downscaleImageAsBase64(data: Data, max: CGFloat) -> String? {
        if let image = UIImage(data: data) {
        
            // downscale profile picture to max. size and quality 60, if is necessary
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
    
    func localizedMobileNo(_ mobileNo: String) -> (mobileNo: String?, prettyMobileNo: String?) {
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
        serverApiConnector.linkMobileNo(with: MyIdentityStore.shared(), mobileNo: mobileNo, onCompletion: { _ in
            DDLogInfo("Safe restore linking mobile no with identity successfull")
        }, onError: { _ in
            DDLogError("Safe restore linking mobile no with identity failed")
        })
    }
    
    private func link(email: String) {
        serverApiConnector.linkEmail(with: MyIdentityStore.shared(), email: email, onCompletion: { _ in
            DDLogInfo("Safe restore linking email with identity successfull")
        }, onError: { _ in
            DDLogError("Safe restore linking email with identity failed")
        })
    }
    
    /// Get all keys from the CodingKey array
    /// - Parameter codingKeys: CodingKey array
    /// - Returns: A array with all keys
    private func allKeys(from codingKeys: [CodingKey]) -> [String] {
        var allKeys = [String]()
        for codingKey in codingKeys {
            allKeys.append(codingKey.stringValue)
        }
        return allKeys
    }
}
