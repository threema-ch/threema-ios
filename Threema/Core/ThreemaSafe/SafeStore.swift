//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2022 Threema GmbH
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
import ThreemaFramework

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
    
    func createKey(identity: String, password: String) -> [UInt8]? {
        let pPassword = UnsafeMutablePointer<Int8>(strdup(password))
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
                    return BundleUtil.localizedString(forKey: "safe_use_default_server")
                }
            }
            catch {
                print("regex faild to check default server: \(error.localizedDescription)")
            }
            
            return safeConfigManager.getCustomServer() != nil ? safeConfigManager.getCustomServer()! : server
        }
        else {
            return BundleUtil.localizedString(forKey: "safe_use_default_server")
        }
    }
    
    func getSafeServer(key: [UInt8], completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        if let server = safeConfigManager.getServer() {
            if let url = URL(string: server) {
                completion(.success(url))
            }
            else {
                completion(.failure(SafeError.invalidURL))
            }
        }
        else {
            getSafeDefaultServer(key: key, completion: completion)
        }
    }
    
    func getSafeDefaultServer(key: [UInt8], completion: @escaping (Swift.Result<URL, Error>) -> Void) {
        guard let backupID = getBackupID(key: key) else {
            completion(.failure(SafeError.badMasterKey))
            return
        }
        
        ServerInfoProviderFactory.makeServerInfoProvider().safeServer(ipv6: false) { safeServerInfo, error in
            DispatchQueue.global().async {
                if let error = error {
                    completion(.failure(error))
                }
                else {
                    if let url = URL(string: safeServerInfo!.url.replacingOccurrences(
                        of: "{backupIdPrefix}",
                        with: String(format: "%02hhx", backupID[0])
                    )) {
                        completion(.success(url))
                    }
                    else {
                        completion(.failure(SafeError.invalidURL))
                    }
                }
            }
        }
    }
    
    /// Compose URL like https://user:password@host.com
    /// - returns: Server URL with credentials
    @objc func composeSafeServerAuth(server: String?, user: String?, password: String?) -> URL? {
        guard let server = server, !server.lowercased().starts(with: "http://") else {
            return nil
        }
        
        let httpProtocol = "https://"
        
        var url: String!
        if !server.lowercased().starts(with: httpProtocol) {
            url = httpProtocol
            url.append(server)
        }
        else {
            url = server
        }
        
        let userEncoded = user?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        let passwordEncoded = password?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        
        if userEncoded != nil || passwordEncoded != nil {
            var concatURL = url[...String.Index(utf16Offset: httpProtocol.count - 1, in: httpProtocol)]
            concatURL.append(contentsOf: userEncoded != nil ? userEncoded! : "")
            concatURL.append(contentsOf: ":")
            concatURL.append(contentsOf: passwordEncoded != nil ? passwordEncoded! : "")
            concatURL.append(contentsOf: "@")
            concatURL.append(contentsOf: url[String.Index(utf16Offset: httpProtocol.count, in: httpProtocol)...])
            
            return URL(string: String(concatURL))
        }

        return URL(string: url)
    }
    
    /// Extract and return server url, user and password from https://user:password@host.com
    /// - returns: User, Password and Server URL without credentials
    func extractSafeServerAuth(server: URL) -> (user: String?, password: String?, server: URL) {
        let httpProtocol = "https://"
        
        guard server.absoluteString.starts(with: httpProtocol) else {
            return (user: nil, password: nil, server: server)
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

        return (user: user, password: password, server: serverURL!)
    }

    // MARK: - back up and restore data
    
    func backupData() -> [UInt8]? {
        // get identity
        if MyIdentityStore.shared().keySecret() == nil {
            return nil
        }
        let jUser = SafeJsonParser.SafeBackupData
            .User(privatekey: MyIdentityStore.shared().keySecret().base64EncodedString())
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
        privateEntityManager.performBlockAndWait {
            let allContacts = privateEntityManager.entityFetcher.allContacts() ?? []
            for item in allContacts {
                // do not backup me as contact
                if let contact = item as? Contact,
                   contact.identity != MyIdentityStore.shared()?.identity {
                    
                    let jContact = SafeJsonParser.SafeBackupData.Contact(
                        identity: contact.identity,
                        verification: Int(truncating: contact.verificationLevel)
                    )
                    jContact.publickey = contact.verificationLevel == 2 ? contact.publicKey.base64EncodedString() : nil
                    jContact.workVerified = contact.workContact != 0
                    
                    // function to hide contacts is not implemented in iOS; hidden could be nil
                    // till then set hidden to false
                    jContact.hidden = false
                    
                    if let firstname = contact.firstName {
                        jContact.firstname = firstname
                    }
                    if let lastname = contact.lastName {
                        jContact.lastname = lastname
                    }
                    if let nickname = contact.publicNickname {
                        jContact.nickname = nickname
                    }
                    
                    if let conversations = contact.conversations {
                        for conversation in conversations {
                            guard let conversation = conversation as? Conversation else {
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
                    
                    jContacts.append(jContact)
                }
            }
        }
        
        // get groups
        var jGroups = [SafeJsonParser.SafeBackupData.Group]()
        privateEntityManager.performBlockAndWait {
            let conversations = privateEntityManager.entityFetcher.allGroupConversations() ?? []
            
            for item in conversations {
                guard let conversation = item as? Conversation,
                      let group = self.groupManager.getGroup(conversation: conversation)
                else {
                    continue
                }
                
                let id = group.groupID.hexString
                let creator: String
                if group.isOwnGroup {
                    creator = MyIdentityStore.shared().identity
                }
                else {
                    creator = group.groupCreatorIdentity
                }
                
                let name = group.name ?? ""
                let members = Array(group.allMemberIdentities)
                
                let jGroup = SafeJsonParser.SafeBackupData.Group(
                    id: id,
                    creator: creator,
                    groupname: name,
                    members: members,
                    deleted: false,
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
        catch {
            throw SafeError.restoreFailed(message: error.localizedDescription)
        }
        
        guard safeBackupData.info.version == 1 else {
            throw SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_version_mismatch"))
        }
        
        // Restore identity store
        guard let privateKey = safeBackupData.user?.privatekey,
              let secretKey = Data(base64Encoded: privateKey) else {
                
            DDLogError("Private key could not be restored")
            throw SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found"))
        }
        
        MyIdentityStore.shared().restore(fromBackup: identity, withSecretKey: secretKey, onCompletion: {
            MyIdentityStore.shared().storeInKeychain()
            
            // Store identity in keychain
            self.serverApiConnector.update(MyIdentityStore.shared(), onCompletion: { () in
                MyIdentityStore.shared().storeInKeychain()
                MyIdentityStore.shared().pendingCreateID = true
                
                if let nickname = safeBackupData.user?.nickname {
                    MyIdentityStore.shared().pushFromName = nickname
                }
                
                // Use MDM configuration for linking ID, if exists. Otherwise get linking configuration from Threema Safe backup
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
                        
                        links.forEach { link in
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
                MyIdentityStore.shared().pendingCreateID = false
            }, onError: { _ in
                DDLogError("Safe restore error:update identity store failed")
                completionHandler(
                    SafeError
                        .restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found"))
                )
            })
        }) { _ in
            DDLogError("Safe restore error:update restore identity store failed")
            completionHandler(
                SafeError
                    .restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found"))
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
        userSettings.enableThreemaCall = settings.threemaCalls ?? true
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
            bContacts.forEach { bContact in
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
                            if let bContact = bContact,
                               let contactIdentity = bContact.identity,
                               contactIdentity.uppercased() != identity.uppercased() {
                            
                                if let publicKey = publicKeys?[index] as? Data {
                                    // check is contact already stored, could be when Threema MDM sync was running (it's a bug, should not before restore is finished)
                                    if let contact = entityManager.entityFetcher.contact(for: bContact.identity) {
                                        entityManager.performSyncBlockAndSafe {
                                            contact.verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                            contact.firstName = bContact.firstname
                                            contact.lastName = bContact.lastname
                                            contact.publicNickname = bContact.nickname
                                        }
                                    }
                                    else {
                                        entityManager.performSyncBlockAndSafe {
                                            if let contact = entityManager.entityCreator.contact(),
                                               let bIdentity = bContact.identity {
                                                contact.identity = bIdentity.uppercased()
                                                contact
                                                    .verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                                contact.firstName = bContact.firstname
                                                contact.lastName = bContact.lastname
                                                contact.publicNickname = bContact.nickname
                                                // function to hide contacts is not implemented in iOS; hidden could be nil
                                                // till then set hidden to false
                                                contact.hidden = 0
                                            
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
                                            
                                                if let featureMasks = featureMasks,
                                                   let featureMask = featureMasks[index] as? Int {
                                                    contact.setFeatureMask(NSNumber(integerLiteral: featureMask))
                                                }
                                                if let states = states,
                                                   let state = states[index] as? Int {
                                                    contact.state = NSNumber(integerLiteral: state)
                                                }
                                                if let types = types,
                                                   let type = types[index] as? Int {
                                                    if type == 1 {
                                                        let workIdentities = NSMutableOrderedSet(
                                                            orderedSet: UserSettings
                                                                .shared().workIdentities
                                                        )
                                                        if !workIdentities.contains(contact.identity) {
                                                            workIdentities.add(contact.identity)
                                                            UserSettings.shared().workIdentities = workIdentities
                                                        }
                                                    }
                                                }
                                                // We create conversations for private contacts
                                                if let isPrivate = bContact.private,
                                                   isPrivate {
                                                    let conversation = entityManager.conversation(
                                                        forContact: contact,
                                                        createIfNotExisting: true
                                                    )
                                                    conversation?.conversationCategory = .private
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
                if let error = error {
                    DDLogError("Safe error while request identities:\(error.localizedDescription)")
                    completionHandler(
                        SafeError
                            .restoreError(message: BundleUtil.localizedString(forKey: "safe_restore_error"))
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
                    
                    groupManager.createOrUpdateDB(
                        groupID: Data(BytesUtility.toBytes(hexString: groupID)!),
                        creator: groupCreator.uppercased(),
                        members: Set<String>(members.map { $0.uppercased() }),
                        systemMessageDate: nil
                    )
                    .done { group in
                        guard let group = group else {
                            DDLogWarn("Safe restore group could not be created")
                            return
                        }
                        var category: ConversationCategory = .default

                        if let isPrivate = bGroup.private,
                           isPrivate {
                            category = .private
                        }

                        entityManager.performSyncBlockAndSafe {
                            group.conversation.groupName = bGroup.groupname
                            group.conversation.conversationCategory = category
                        }

                        // Sync only group is active
                        if group.isOwnGroup {
                            self.groupManager.sync(group: group)
                                .catch { error in
                                    DDLogError("Safe restore group sync failed: \(error)")
                                }
                        }
                        else {
                            self.groupManager.sendSyncRequest(
                                groupID: group.groupID,
                                creator: group.groupCreatorIdentity
                            )
                        }
                    }
                    .catch { error in
                        DDLogError("Safe restore group failed: \(error)")
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
            if let contacts = entityManager.entityFetcher.allContacts() as? [Contact] {
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
}
