//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2021 Threema GmbH
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

import Foundation
import CocoaLumberjackSwift
import Gzip
import ThreemaFramework


@objc class SafeStore: NSObject {
    private static let SAFE_DEFAULT_SERVER: String = "https://safe-%02hhx.threema.ch"
    
    private var safeConfigManager: SafeConfigManagerProtocol
    private var serverApiConnector: ServerAPIConnector
    
    @objc public let masterKeyLength: Int = 64
    private let backupIdLength: Int = 32
    private let encryptionKeyLength: Int = 32
    
    enum SafeError: Error {
        case invalidMasterKey
        case inavlidData
        case restoreError(message: String)
        case restoreFailed(message: String)
    }

    init(safeConfigManager: SafeConfigManagerProtocol, serverApiConnector: ServerAPIConnector) {
        self.safeConfigManager = safeConfigManager
        self.serverApiConnector = serverApiConnector
    }
    
    //NSObject thereby not the whole SafeConfigManagerProtocol interface must be like @objc
    @objc convenience init(safeConfigManagerAsObject safeConfigManager: NSObject, serverApiConnector: ServerAPIConnector) {
        self.init(safeConfigManager: safeConfigManager as! SafeConfigManagerProtocol, serverApiConnector: serverApiConnector)
    }
    
    //MARK: - keys and encryption
    
    func createKey(identity: String, password: String) -> [UInt8]? {
        let pPassword = UnsafeMutablePointer<Int8>(strdup(password))
        let pSalt = UnsafeMutablePointer<Int8>(strdup(identity))
        
        var pOut = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: self.masterKeyLength)
        
        defer {
            pPassword?.deallocate()
            pSalt?.deallocate()
            pOut.deallocate()
        }
        
        if(getDerivedKey(pPassword, pSalt, pOut) != 0) {
            return nil
        }
        
        return Array(UnsafeMutableBufferPointer(start: pOut, count: self.masterKeyLength))
    }

    func getBackupId(key: [UInt8]) -> [UInt8]? {
        if key.count == self.masterKeyLength {
            return Array(key[0..<self.backupIdLength])
        }
        return nil
    }
    
    func getEncryptionKey(key: [UInt8]) -> [UInt8]? {
        if key.count == self.masterKeyLength {
            return Array(key[self.masterKeyLength - self.encryptionKeyLength..<self.masterKeyLength])
        }
        return nil
    }
    
    func encryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == self.masterKeyLength else {
            throw SafeError.invalidMasterKey
        }
        guard data.count != 0 else {
            throw SafeError.inavlidData
        }
        
        let backupId = getBackupId(key: key)
        let encryptionKey = getEncryptionKey(key: key)
        
        guard backupId != nil && encryptionKey != nil else {
            throw SafeError.invalidMasterKey
        }
        
        
        
        let decryptedData: Data = Data(data)
        let compressedData: Data = try decryptedData.gzipped()
        
        if let nonce: Data = generateRandomBytes() {
            let crypto: NaClCrypto = NaClCrypto()
            let encryptedData: Data = crypto.symmetricEncryptData(compressedData, withKey: Data(bytes: encryptionKey!, count: encryptionKey!.count), nonce: nonce)
            
            var encryptedBackup = Data()
            encryptedBackup.append(nonce)
            encryptedBackup.append(encryptedData)
            
            return Array(encryptedBackup)
        }
        else {
            throw SafeError.inavlidData
        }
    }
    
    func decryptBackupData(key: [UInt8], data: [UInt8]) throws -> [UInt8] {
        guard key.count == self.masterKeyLength else {
            throw SafeError.invalidMasterKey
        }
        guard data.count != 0 else {
            throw SafeError.inavlidData
        }
        
        let backupId = getBackupId(key: key)
        let encryptionKey = getEncryptionKey(key: key)
        
        guard backupId != nil && encryptionKey != nil else {
            throw SafeError.invalidMasterKey
        }

        let nonce = data[0...23]
        let encryptedData = data[24...data.count-1]
        
        let crypto: NaClCrypto = NaClCrypto()
        let decryptedData = crypto.symmetricDecryptData(Data(encryptedData), withKey: Data(encryptionKey!), nonce: Data(nonce))!
        
        let unpressedData = try decryptedData.gunzipped()
        
        return Array(unpressedData)
    }
    
    public static func dataToHexString(_ data: [UInt8]) -> String {
        return data.map { String(format: "%02hhx", $0) }.joined(separator: "")
    }
    
    public static func hexStringToData(_ hexString: String) -> Data {
        var hex = hexString
        var data = Data()
        while(hex.count > 0) {
            let subIndex = hex.index(hex.startIndex, offsetBy: 2)
            let c = String(hex[..<subIndex])
            hex = String(hex[subIndex...])
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
    public func sha1(data: Data) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA1($0, CC_LONG(data.count), &digest)
        }
        return digest
    }
    
    private func generateRandomBytes() -> Data? {
        var keyData = Data(count: 24)
        let result = keyData.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 24, $0)
        }
        if result == errSecSuccess {
            return keyData
        } else {
            return nil
        }
    }
    
    func isDateOlderThenDays(date: Date?, days: Int) -> Bool {
        return date == nil || (date != nil && (date!.addingTimeInterval(TimeInterval(86400 * days)) < Date()))
    }
    
    //MARK: - safe server
    
    func getSafeServerToDisplay() -> String {
        if let server = self.safeConfigManager.getServer() {
            do {
                let regexDefaultServer = try NSRegularExpression(pattern: "https://safe-[0-9a-z]{2}.threema.ch")
                let regexResult = regexDefaultServer.matches(in: server, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSRange(location: 0, length: server.count))
                if regexResult.count > 0 {
                    return BundleUtil.localizedString(forKey: "safe_use_default_server")
                }
            } catch let error {
                print("regex faild to check default server: \(error.localizedDescription)")
            }
            
            return self.safeConfigManager.getCustomServer() != nil ? self.safeConfigManager.getCustomServer()! : server
        } else {
            return BundleUtil.localizedString(forKey: "safe_use_default_server")
        }
    }
    
    func getSafeServer(key: [UInt8]) -> URL? {
        return self.safeConfigManager.getServer() != nil ? URL(string: self.safeConfigManager.getServer()!) : self.getSafeDefaultServer(key: key)!
    }
    
    func getSafeDefaultServer(key: [UInt8]) -> URL? {
        guard let backupId = getBackupId(key: key) else {
            return nil
        }
        
        return URL(string: String(format: SafeStore.SAFE_DEFAULT_SERVER, backupId[0]))
    }
    
    /// Compose URL like https://user:password@host.com
    /// - returns: Server Url with credentials
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
            var concatUrl = url[...String.Index(utf16Offset: httpProtocol.count - 1, in: httpProtocol)]
            concatUrl.append(contentsOf: userEncoded != nil ? userEncoded! : "")
            concatUrl.append(contentsOf: ":")
            concatUrl.append(contentsOf: passwordEncoded != nil ? passwordEncoded! : "")
            concatUrl.append(contentsOf: "@")
            concatUrl.append(contentsOf: url[String.Index(utf16Offset: httpProtocol.count, in: httpProtocol)...])
            
            return URL(string: String(concatUrl))
        }

        return URL(string: url)
    }
    
    /// Extract and return server url, user and password from https://user:password@host.com
    /// - returns: User, Password and Server Url without credentials
    func extractSafeServerAuth(server: URL) -> (user: String?, password: String?, server: URL) {
        let httpProtocol = "https://"
        
        guard server.absoluteString.starts(with: httpProtocol) else {
            return (user: nil, password: nil, server: server)
        }
        
        var user: String?
        var password: String?
        var serverUrl: URL?
        
        if server.user != nil || server.password != nil {
            user = server.user?.removingPercentEncoding
            password = server.password?.removingPercentEncoding

            if let startServerUrl = server.absoluteString.firstIndex(of: "@") {
                serverUrl = URL(string: httpProtocol + server.absoluteString[String.Index(utf16Offset: startServerUrl.utf16Offset(in: server.absoluteString)+1, in: server.absoluteString)...].description)
            } else {
                serverUrl = server
            }
        } else {
            serverUrl = server
        }

        return (user: user, password: password, server: serverUrl!)
    }

    //MARK: - back up and restore data
    
    func backupData() -> [UInt8]? {
        // get identity
        if MyIdentityStore.shared().keySecret() == nil {
            return nil
        }
        let jUser = SafeJsonParser.SafeBackupData.User(privatekey: MyIdentityStore.shared().keySecret().base64EncodedString())
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
                jUser.profilePicRelease = identities.map({ (identity) -> String in
                    return "\(identity)"
                })
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
        if jLinks.count > 0 {
            jUser.links = jLinks
        }

        // get contacts
        var jContacts = [SafeJsonParser.SafeBackupData.Contact]()
        for item in ContactStore.shared().allContacts() {
            // do not backup me as contact
            if let contact = item as? Contact,
                contact.identity != MyIdentityStore.shared()?.identity {
                
                let jContact = SafeJsonParser.SafeBackupData.Contact(identity: contact.identity, verification: Int(truncating: contact.verificationLevel))
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
                jContacts.append(jContact)
            }
        }
        
        // get groups
        var jGroups = [SafeJsonParser.SafeBackupData.Group]()
        let entityManager = EntityManager()
        let groupConversations = entityManager.entityFetcher.allGroupConversations()
        
        for item in groupConversations! {
            if let groupConversation = item as? Conversation {
                if groupConversation.isGroup() {
                    if let group = GroupProxy(for: groupConversation, entityManager: entityManager) {
                        let id = SafeStore.dataToHexString(Array(group.groupId))
                        var creator: String? = nil
                        if group.isOwnGroup() {
                            creator = MyIdentityStore.shared().identity
                        } else if let groupCreator = group.creator {
                            creator = groupCreator.identity
                        }
                        
                        let name = group.name
                        let members = Array(group.memberIdsIncludingSelf) as! [String]
                        
                        if creator != nil {
                            let jGroup = SafeJsonParser.SafeBackupData.Group(id: id, creator: creator!, groupname: name!, members: members, deleted: false)
                            jGroups.append(jGroup)
                        }
                    }
                }
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
        jSettings.blockedContacts = UserSettings.shared().blacklist.map { (identity) -> String in
            return (identity as! String)
        }
        jSettings.syncExcludedIds = UserSettings.shared().syncExclusionList.map { (identity) -> String in
            return (identity as! String)
        }
        
        let parser = SafeJsonParser()
        var safeBackupData = parser.getSafeBackupData()
        
        safeBackupData.user = jUser;
        if jContacts.count > 0 {
            safeBackupData.contacts = jContacts
        }
        if jGroups.count > 0 {
            safeBackupData.groups = jGroups
        }
        safeBackupData.settings = jSettings
        
        //print(parser.getJsonAsString(from: safeBackupData)!)
        return parser.getJsonAsBytes(from: safeBackupData)!
    }
    
    func restoreData(identity: String, data: [UInt8], onlyIdentity: Bool, completionHandler: @escaping (SafeError?) -> Swift.Void) throws {
        
        //print(String(bytes: data, encoding: .utf8)!)
        
        //Check backup version
        let parser = SafeJsonParser()
        var safeBackupData: SafeJsonParser.SafeBackupData

        do {
             safeBackupData = try parser.getSafeBackupData(from: Data(data))
        } catch let error {
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
                if mdmSetup.existsMdmKey(MDM_KEY_LINKED_PHONE) || mdmSetup.existsMdmKey(MDM_KEY_LINKED_EMAIL) || mdmSetup.readonlyProfile() {
                    if let createIDPhone = MyIdentityStore.shared()?.createIDPhone,
                        createIDPhone.count > 0 {
                        
                        let normalizer: PhoneNumberNormalizer = PhoneNumberNormalizer.sharedInstance()
                        var prettyMobileNo: NSString? = nil
                        if let mobileNo = normalizer.phoneNumber(toE164: MyIdentityStore.shared()?.createIDPhone, withDefaultRegion: PhoneNumberNormalizer.userRegion(), prettyFormat: &prettyMobileNo),
                            mobileNo.count > 0 {
                            
                            self.link(mobileNo: mobileNo)
                        }
                    }
                    
                    if let createIDEmail = MyIdentityStore.shared()?.createIDEmail,
                        createIDEmail.count > 0 {
                        
                        self.link(email: createIDEmail)
                    }
                }
                else {
                    if let links = safeBackupData.user?.links,
                        links.count > 0 {
                        
                        links.forEach { (link) in
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
                    
                    let profilePicture: NSMutableDictionary = MyIdentityStore.shared().profilePicture != nil ? MyIdentityStore.shared().profilePicture : NSMutableDictionary(dictionary: ["ProfilePicture": profilePicData])
                    
                    MyIdentityStore.shared().profilePicture = profilePicture
                }
                
                if onlyIdentity {
                    self.setProfilePictureRequestList()
                    
                    completionHandler(nil)
                } else {
                    self.restoreUserSettings(safeBackupData: safeBackupData)
                    self.restoreContactsAndGroups(identity: identity, safeBackupData: safeBackupData, completionHandler: completionHandler)
                }
                LicenseStore.shared().performUpdateWorkInfo()
                MyIdentityStore.shared().pendingCreateID = false
            }, onError: { (error) in
                DDLogError("Safe restore error:update identity store failed")
                completionHandler(SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found")))
            })
        }) { (error) in
            DDLogError("Safe restore error:update restore identity store failed")
            completionHandler(SafeError.restoreFailed(message: BundleUtil.localizedString(forKey: "safe_no_backup_found")))
        }
    }
    
    private func restoreUserSettings(safeBackupData: SafeJsonParser.SafeBackupData) {
        
        let userSettings = UserSettings.shared()!
        
        if let profilePicRelease = safeBackupData.user?.profilePicRelease {
            if profilePicRelease.count == 1 && profilePicRelease[0] == "*" {
                userSettings.sendProfilePicture = SendProfilePictureAll
            }
            else if profilePicRelease.count == 1 && profilePicRelease[0] == nil {
                userSettings.sendProfilePicture = SendProfilePictureNone
            } else if profilePicRelease.count > 0 {
                userSettings.sendProfilePicture = SendProfilePictureContacts
                userSettings.profilePictureContactList = profilePicRelease as [Any]
            } else {
                userSettings.sendProfilePicture = SendProfilePictureNone
            }
        } else {
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
        if let syncExcludedIds = settings.syncExcludedIds {
            userSettings.syncExclusionList = syncExcludedIds
        }
    }
    
    private func restoreContactsAndGroups(identity: String, safeBackupData: SafeJsonParser.SafeBackupData, completionHandler: @escaping (SafeError?) -> Swift.Void) {
        
        let entityManager = EntityManager()

        if let bContacts = safeBackupData.contacts {
    
            var fetchIdentities = [String]()
            bContacts.forEach { (bContact) in
                if let identity = bContact.identity {
                    fetchIdentities.append(identity)
                }
            }
            
            self.serverApiConnector.fetchBulkIdentityInfo(fetchIdentities, onCompletion: { (identities, publicKeys, featureMasks, states, types) in
                
                var index = 0
                for id in identities! {
                    var bContact: SafeJsonParser.SafeBackupData.Contact?
                    if bContacts.contains(where: { (c) -> Bool in
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
                                if let contact = entityManager.entityFetcher.contact(forId: bContact.identity) {
                                    entityManager.performSyncBlockAndSafe({
                                        contact.verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                        contact.firstName = bContact.firstname
                                        contact.lastName = bContact.lastname
                                        contact.publicNickname = bContact.nickname
                                    })
                                }
                                else {
                                    entityManager.performSyncBlockAndSafe({
                                        if let contact = entityManager.entityCreator.contact() {
                                            contact.identity = bContact.identity?.uppercased()
                                            contact.verificationLevel = Int32(bContact.verification ?? 0) as NSNumber
                                            contact.firstName = bContact.firstname
                                            contact.lastName = bContact.lastname
                                            contact.publicNickname = bContact.nickname
                                            // function to hide contacts is not implemented in iOS; hidden could be nil
                                            // till then set hidden to false
                                            contact.hidden = 0
                                            if let workVerified = bContact.workVerified {
                                                contact.workContact = workVerified ? 1 : 0
                                            } else {
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
                                                if type == 1 && contact.identity != nil {
                                                    let workIdentities = NSMutableOrderedSet.init(orderedSet: UserSettings.shared().workIdentities)
                                                    if !workIdentities.contains(contact.identity!) {
                                                        workIdentities.add(contact.identity!)
                                                        UserSettings.shared().workIdentities = workIdentities
                                                    }
                                                }
                                            }
                                        }
                                    })
                                }
                            }
                        }
                    }
                    
                    index += 1
                }
                
                if index > 0 {
                    self.setProfilePictureRequestList()

                    self.restoreGroups(identity: identity, safeBackupData: safeBackupData, entityManager: entityManager)
                }
                
                completionHandler(nil)
            }) { (error) in
                if let error = error {
                    DDLogError("Safe error while request identities:\(error.localizedDescription)")
                    completionHandler(SafeError.restoreError(message: BundleUtil.localizedString(forKey: "safe_restore_error")))
                }
            }
            
        }
    }
    
    private func restoreGroups(identity: String, safeBackupData: SafeJsonParser.SafeBackupData, entityManager: EntityManager) {
        if let bGroups = safeBackupData.groups {
            for bGroup in bGroups {
                if let creatorIdentity = bGroup.creator {
                    
                    var creatorContact: Contact?
                    if creatorIdentity.uppercased() != identity.uppercased() {
                        creatorContact = entityManager.entityFetcher.contact(forId: creatorIdentity.uppercased())
                    }
                    
                    if creatorIdentity.uppercased() == identity.uppercased() || creatorContact != nil {
                        var conversation: Conversation?
                        
                        if let groupId = bGroup.id,
                            let groupMembers = bGroup.members {
                            
                            entityManager.performSyncBlockAndSafe({
                                conversation = entityManager.entityCreator.conversation()
                                conversation?.groupId = SafeStore.hexStringToData(groupId)
                                if groupMembers.contains(where: { (member) -> Bool in
                                    member.uppercased().contains(identity.uppercased())
                                }) {
                                    conversation?.groupMyIdentity = identity.uppercased()
                                }
                                conversation?.contact = creatorContact
                                conversation?.groupName = bGroup.groupname
                            })
                            
                            if let conversation = conversation {
                                //sync restored group
                                if let group = GroupProxy(for: conversation, entityManager: entityManager) {
                                    group.adminAddMembers(fromBackup: Set(groupMembers), entityManager: entityManager)

                                    //sync only group is active
                                    if (group.isSelfMember()) {
                                        if creatorIdentity.uppercased() == identity.uppercased() {
                                            group.syncGroupInfoToAll()
                                        } else {
                                            GroupProxy.sendSyncRequest(withGroupId: group.groupId, creator: group.creator.identity)
                                        }
                                    }
                                }
                            }
                        }
                        else {
                            DDLogWarn("Safe restore group id or members missing")
                        }
                    }
                    else {
                        DDLogWarn("Safe restore group creator not found")
                    }
                } else {
                    DDLogWarn("Safe restore group has no creator")
                }
            }
        }
    }

    private func setProfilePictureRequestList() {
        if let userSettings = UserSettings.shared() {
            var profilePicRequest = [String]()
            
            let entityManager = EntityManager()
            if let contacts =  entityManager.entityFetcher.allContacts() as? [Contact] {
                for contact in contacts {
                    if contact.identity != "ECHOECHO" && contact.identity !=  MyIdentityStore.shared()?.identity {
                        profilePicRequest.append(contact.identity)
                    }
                }
            }
        
            userSettings.profilePictureRequestList = profilePicRequest
        }
    }
    
    private func downscaleImageAsBase64(data: Data, max: CGFloat) -> String? {
        if let image: UIImage = UIImage(data: data) {
        
            // downscale profile picture to max. size and quality 60, if is necessary
            if image.size.height > max || image.size.width > max {
                var newHeight: CGFloat
                var newWidth: CGFloat
                if image.size.height > image.size.width {
                    newHeight = max
                    newWidth = (newHeight / image.size.height) * image.size.width
                } else {
                    newWidth = max
                    newHeight = (newWidth / image.size.width) * image.size.height
                }
                
                let resizedImage = resizeImage(image: image, size: CGSize(width: newWidth, height: newHeight))!
                let resizedData = resizedImage.jpegData(compressionQuality: 0.6)
                
                return resizedData?.base64EncodedString()
            } else {
                return data.base64EncodedString()
            }
        } else {
            return nil;
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
        if mobileNo.count > 0 {
            let normalizer: PhoneNumberNormalizer = PhoneNumberNormalizer.sharedInstance()
            var prettyMobileNo: NSString?
            
            let localMobileNo = normalizer.phoneNumber(toE164: mobileNo, withDefaultRegion: PhoneNumberNormalizer.userRegion(), prettyFormat: &prettyMobileNo)
            return (mobileNo: localMobileNo, prettyMobileNo: prettyMobileNo as String?)
        }
        return (mobileNo: nil, prettyMobileNo: nil)
    }
    
    private func link(mobileNo: String) {
        self.serverApiConnector.linkMobileNo(with: MyIdentityStore.shared(), mobileNo: mobileNo, onCompletion: { (linked) in
            DDLogInfo("Safe restore linking mobile no with identity successfull")
        }, onError: { (error) in
            DDLogError("Safe restore linking mobile no with identity failed")
        })
    }
    
    private func link(email: String) {
        self.serverApiConnector.linkEmail(with: MyIdentityStore.shared(), email: email, onCompletion: { (linked) in
            DDLogInfo("Safe restore linking email with identity successfull")
        }, onError: { (error) in
            DDLogError("Safe restore linking email with identity failed")
        })
    }
}
