import CocoaLumberjackSwift
import Foundation
import RemoteSecretProtocol
import ThreemaEssentials

/// Manager to access all items stored in Keychain.
///
/// The KeychainManager manages only generics passwords (`kSecClass` -> `kSecClassGenericPassword`),
/// the primary keys include `kSecAttrAccount` and `kSecAttrService`!
public final class KeychainManager: NSObject, KeychainManagerProtocol {

    public enum KeychainManagerError: Error {
        case myIdentityMissing
        case threemaSafeServerMissing
        case invalidIdentityBackupData
    }

    // TODO: (IOS-5364) Check if `RemoteSecretCryptoProtocol` would also be sufficient here
    private let remoteSecretManager: RemoteSecretManagerProtocol
    
    private let keychainProvider: KeychainProviding

    // MARK: - Lifecycle

    override private init() {
        // no-op
        fatalError("Not supported")
    }
    
    public init(remoteSecretManager: RemoteSecretManagerProtocol) {
        self.remoteSecretManager = remoteSecretManager
        self.keychainProvider = KeychainProvider()
        super.init()
    }
    
    required init(
        remoteSecretManager: RemoteSecretManagerProtocol,
        keychainProvider: KeychainProviding = KeychainProvider()
    ) {
        self.remoteSecretManager = remoteSecretManager
        self.keychainProvider = keychainProvider
        super.init()
    }

    // MARK: - Public functions
    
    // MARK: - Locking Check
    
    /// Is Keychain locked for first unlock accesses?
    @objc public static var isKeychainLocked: Bool {
        do {
            _ = try KeychainProvider().load(.identity())
            return false
        }
        catch let KeychainProviderError.loadFailed(osStatus: osStatus)
            where osStatus == errSecInteractionNotAllowed {
            return true
        }
        catch {
            return false
        }
    }
    
    // MARK: - Remote Secret
    
    public static func loadRemoteSecret() throws -> (
        authenticationToken: Data,
        identityHash: Data
    )? {
        guard let result = try KeychainProvider().load(.remoteSecret()),
              let authenticationToken = result.password, let identityHash = result.generic else {
            return nil
        }
        
        return (authenticationToken, identityHash)
    }
    
    @objc public static func hasRemoteSecretInStore() -> Bool {
        do {
            return try KeychainProvider().load(.remoteSecret()) != nil
        }
        catch {
            DDLogError("[KeychainManager] RS check failed.")
            return false
        }
    }
    
    public static func storeRemoteSecret(authenticationToken: Data, identityHash: Data) throws {
        let item = KeychainItem.remoteSecret()
        try KeychainProvider().store(
            item,
            account: item.label,
            password: authenticationToken,
            generic: identityHash
        )
    }
    
    @objc public static func deleteRemoteSecret() throws {
        try KeychainProvider().delete(.remoteSecret())
    }
    
    // MARK: - Threema Identity
    
    public static func loadThreemaIdentity() throws -> ThreemaIdentity? {
        guard let result = try KeychainProvider().load(.identity()),
              let identity = result.account else {
            return nil
        }
        
        return ThreemaIdentity(identity)
    }

    // MARK: - Identity

    @available(swift, obsoleted: 1.0, renamed: "loadIdentity()", message: "Only use from Objective-C")
    @objc public func loadIdentity(
        identity: UnsafeMutablePointer<NSString?>,
        clientKey: UnsafeMutablePointer<NSData?>,
        publicKey: UnsafeMutablePointer<NSData?>,
        serverGroup: UnsafeMutablePointer<NSString?>
    ) -> Int32 {
        do {
            guard let myIdentity = try loadIdentity() else {
                return errSecNotAvailable
            }

            identity.pointee = myIdentity.$identity as NSString
            clientKey.pointee = myIdentity.$clientKey as NSData
            publicKey.pointee = myIdentity.$publicKey as NSData
            serverGroup.pointee = myIdentity.$serverGroup as NSString

            return errSecSuccess
        }
        catch let KeychainProviderError.loadFailed(osStatus: osStatus) {
            return osStatus
        }
        catch {
            return errSecNotAvailable
        }
    }

    public func loadIdentity() throws -> MyIdentity? {
        guard let result = try keychainProvider.load(.identity()),
              let account = result.account,
              let password = result.password,
              let generic = result.generic,
              let service = result.service else {
            return nil
        }
        
        let retrievedPassword = remoteSecretManager.decryptDataIfNeeded(password)
        let retrievedGeneric = remoteSecretManager.decryptDataIfNeeded(generic)
        
        guard let retrievedService = try remoteSecretManager.decryptBase64StringIfNeeded(service) else {
            return nil
        }
        
        return MyIdentity(
            identity: ThreemaIdentity(account),
            clientKey: ThreemaClientKey(retrievedPassword),
            publicKey: ThreemaPublicKey(retrievedGeneric),
            serverGroup: ServerGroup(retrievedService)
        )
    }

    public func storeIdentity(_ myIdentity: MyIdentity) throws {
        let storingPassword =
            remoteSecretManager.encryptDataIfNeeded(myIdentity.$clientKey)
        let storingGeneric =
            remoteSecretManager.encryptDataIfNeeded(myIdentity.$publicKey)
        let storingService =
            remoteSecretManager.encryptToBase64StringIfNeeded(myIdentity.$serverGroup)
        
        try keychainProvider.store(
            .identity(),
            account: myIdentity.$identity,
            password: storingPassword,
            generic: storingGeneric,
            service: storingService
        )
    }

    @objc public func deleteIdentity() throws {
        try keychainProvider.delete(.identity())
    }

    // MARK: - Identity Backup

    @available(swift, obsoleted: 1.0, renamed: "loadIdentityBackup()", message: "Only use from Objective-C")
    @objc public static func loadIdentityBackup(data: UnsafeMutablePointer<NSString?>) -> Int32 {
        do {
            data.pointee = try loadIdentityBackup() as NSString
            return errSecSuccess
        }
        catch let KeychainProviderError.loadFailed(osStatus: osStatus) {
            return osStatus
        }
        catch {
            return errSecNotAvailable
        }
    }

    public static func loadIdentityBackup() throws -> String {
        guard let result = try KeychainProvider().load(.identityBackup()),
              let identityBackupData = result.password
        else {
            throw KeychainProviderError.loadFailed(osStatus: errSecItemNotFound)
        }
                
        guard let identityBackup = String(data: identityBackupData, encoding: .ascii) else {
            throw KeychainManagerError.invalidIdentityBackupData
        }
        
        return identityBackup
    }

    @objc public static func storeIdentityBackup(_ data: String) throws {
        let item = KeychainItem.identityBackup()
        
        guard let identityData = data.data(using: .ascii) else {
            throw KeychainManagerError.invalidIdentityBackupData
        }
                
        try KeychainProvider().store(
            item,
            account: item.label,
            password: identityData
        )
    }

    @objc public static func deleteIdentityBackup() throws {
        try KeychainProvider().delete(.identityBackup())
    }

    // MARK: - Device Cookie

    public func loadDeviceCookie() throws -> Data? {
        guard let result = try keychainProvider.load(.deviceCookie()),
              let deviceCookie = result.password else {
            return nil
        }
        
        let loadingDeviceCookie = remoteSecretManager.decryptDataIfNeeded(deviceCookie)
        
        return loadingDeviceCookie
    }

    public func storeDeviceCookie(_ cookie: Data) throws {
        let item = KeychainItem.deviceCookie()
        
        let storingCookie = remoteSecretManager.encryptDataIfNeeded(cookie)
        
        try keychainProvider.store(
            item,
            account: item.label,
            password: storingCookie
        )
    }

    public static func deleteDeviceCookie() throws {
        try KeychainProvider().delete(.deviceCookie())
    }

    // MARK: - Device Group Key

    public func loadMultiDeviceGroupKey() throws -> Data? {
        guard let result = try keychainProvider.load(.multiDeviceGroupKey()),
              let multiDeviceGroupKey = result.password else {
            return nil
        }
        
        let loadingMultiDeviceGroupKey = remoteSecretManager.decryptDataIfNeeded(multiDeviceGroupKey)
        
        return loadingMultiDeviceGroupKey
    }

    public func storeMultiDeviceGroupKey(key: Data) throws {
        let item = KeychainItem.multiDeviceGroupKey()
        
        let storingKey = remoteSecretManager.encryptDataIfNeeded(key)
        
        try keychainProvider.store(
            item,
            account: item.label,
            password: storingKey
        )
    }
    
    @objc public static func deleteMultiDeviceGroupKey() throws {
        try KeychainProvider().delete(.multiDeviceGroupKey())
    }

    // MARK: - Device ID for Multi Device

    @available(swift, obsoleted: 1.0, renamed: "loadMultiDeviceID()", message: "Only use from Objective-C")
    @objc public func loadMultiDeviceIDObjC() -> Data? {
        do {
            return try loadMultiDeviceID()
        }
        catch {
            return nil
        }
    }

    public func loadMultiDeviceID() throws -> Data? {
        guard let result = try keychainProvider.load(.multiDeviceID()),
              let multiDeviceID = result.password else {
            return nil
        }
        
        let loadingMultiDeviceID = remoteSecretManager.decryptDataIfNeeded(multiDeviceID)
        
        return loadingMultiDeviceID
    }

    @objc public func storeMultiDeviceID(id: Data) throws {
        let item = KeychainItem.multiDeviceID()
        
        let storingID = remoteSecretManager.encryptDataIfNeeded(id)
        
        try keychainProvider.store(
            item,
            account: item.label,
            password: storingID
        )
    }

    public func deleteMultiDeviceID() throws {
        try keychainProvider.delete(.multiDeviceID())
    }

    // MARK: - Forward Security Key

    public func loadForwardSecurityWrappingKey() throws -> Data? {
        guard let result = try keychainProvider.load(.forwardSecurityWrappingKey()),
              let forwardSecurityWrappingKey = result.password else {
            return nil
        }
        
        let loadingKey = remoteSecretManager.decryptDataIfNeeded(forwardSecurityWrappingKey)
        
        return loadingKey
    }

    public func storeForwardSecurityWrappingKey(_ key: Data) throws {
        let item = KeychainItem.forwardSecurityWrappingKey()
        
        let storingKey = remoteSecretManager.encryptDataIfNeeded(key)
        
        try keychainProvider.store(
            item,
            account: item.label,
            password: storingKey
        )
    }

    public static func deleteForwardSecurityKey() throws {
        try KeychainProvider().delete(.forwardSecurityWrappingKey())
    }

    // MARK: - License (Work and OnPrem)

    public static func loadOnPremServer() throws -> String? {
        guard let result = try KeychainProvider().load(.license()),
              let server = result.service else {
            return nil
        }

        return server
    }

    @available(swift, obsoleted: 1.0, renamed: "loadLicense()", message: "Only use from Objective-C")
    @objc public func loadLicense(
        user: UnsafeMutablePointer<NSString?>,
        password: UnsafeMutablePointer<NSString?>,
        deviceID: UnsafeMutablePointer<NSString?>,
        onPremServer: UnsafeMutablePointer<NSString?>
    ) throws {
        if let result = try loadLicense() {
            user.pointee = result.user as NSString
            password.pointee = result.password as NSString
            deviceID.pointee = result.deviceID as? NSString
            if let server = result.onPremServer {
                onPremServer.pointee = server as NSString
            }
        }
    }

    public func loadLicense() throws -> ThreemaLicense? {
        guard let result = try keychainProvider.load(.license()),
              let loadingUser = try remoteSecretManager.decryptBase64StringIfNeeded(result.account),
              let loadingPassword = try remoteSecretManager.decryptDataToStringIfNeeded(result.password)
        else {
            return nil
        }
        
        let loadingDeviceID = try remoteSecretManager.decryptDataToStringIfNeeded(result.generic)

        return ThreemaLicense(
            user: loadingUser,
            password: loadingPassword,
            deviceID: loadingDeviceID,
            onPremServer: result.service
        )
    }

    @objc public func storeLicense(_ license: ThreemaLicense) throws {
        let storingUser = remoteSecretManager.encryptToBase64StringIfNeeded(license.user)
        let storingPassword = remoteSecretManager.encryptStringIfNeeded(license.password)
        let storingGeneric = remoteSecretManager.encryptStringIfNeeded(license.deviceID)

        try keychainProvider.store(
            .license(),
            account: storingUser,
            password: storingPassword,
            generic: storingGeneric,
            service: license.onPremServer
        )
    }

    @objc public func deleteLicense() throws {
        try keychainProvider.delete(.license())
    }

    // MARK: - Threema Safe Key

    public func loadThreemaSafeKey() throws -> Data? {
        guard let result = try keychainProvider.load(.threemaSafeKey()),
              let key = result.password else {
            return nil
        }

        let loadingKey = remoteSecretManager.decryptDataIfNeeded(key)
        
        return loadingKey
    }

    public func storeThreemaSafeKey(key: Data) throws {
        let storingKey = remoteSecretManager.encryptDataIfNeeded(key)
        
        let keychainItem = KeychainItem.threemaSafeKey()
        try keychainProvider.store(
            keychainItem,
            account: keychainItem.label,
            password: storingKey
        )
    }

    public func deleteThreemaSafeKey() throws {
        try keychainProvider.delete(.threemaSafeKey())
    }

    // MARK: - Threema Safe Server

    public func loadThreemaSafeServer() throws -> ThreemaSafeServerInfo? {
        guard let result = try keychainProvider.load(.threemaSafeServer()) else {
            return nil
        }

        guard let loadingServer = try remoteSecretManager.decryptBase64StringIfNeeded(result.service) else {
            throw KeychainManagerError.threemaSafeServerMissing
        }
        
        let loadingUser = try remoteSecretManager.decryptBase64StringIfNeeded(result.account)
        let loadingPassword = try remoteSecretManager.decryptDataToStringIfNeeded(result.password)
        
        return ThreemaSafeServerInfo(
            user: loadingUser,
            password: loadingPassword,
            server: loadingServer
        )
    }

    public func storeThreemaSafeServer(_ server: ThreemaSafeServerInfo) throws {
        let storingUser = remoteSecretManager.encryptToBase64StringIfNeeded(server.user)
        let storingPassword = remoteSecretManager.encryptStringIfNeeded(server.password)
        let storingServer = remoteSecretManager.encryptToBase64StringIfNeeded(server.server)

        try keychainProvider.store(
            .threemaSafeServer(),
            account: storingUser,
            password: storingPassword,
            service: storingServer
        )
    }

    public func deleteThreemaSafeServer() throws {
        try keychainProvider.delete(.threemaSafeServer())
    }

    // MARK: - Migrate Keychain

    public func migrateToDowngrade() throws {
        try KeychainMigration.migrateToDowngrade()
    }

    public func migrateToVersion0() throws {
        try KeychainMigration.migrateToVersion0()
    }

    public func migrateToVersion1(myIdentity: ThreemaEssentials.ThreemaIdentity) throws {
        try KeychainMigration.migrateToVersion1(myIdentity: myIdentity)
    }
    
    // MARK: - Deletion
    
    @objc public static func deleteAllItems() throws {
        let keychainProvider = KeychainProvider()
        for item in KeychainItem.allCases {
            try keychainProvider.delete(item)
        }
    }
    
    public static func deleteAllThisDeviceOnlyItems() throws {
        let keychainProvider = KeychainProvider()
        for item in KeychainItem.allCases where item.accessibility == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly {
            try keychainProvider.delete(item)
        }
    }
    
    public static func deleteAllEncryptedItems() throws {
        guard hasRemoteSecretInStore() else {
            return
        }
        
        let keychainProvider = KeychainProvider()
        for item in KeychainItem.allCases where item.mightContainEncryptedData {
            try keychainProvider.delete(item)
        }
    }

    // MARK: - Debug stuff

    #if DEBUG
        public static func printKeychainItems() {
            let classes = [
                kSecClassGenericPassword,
                kSecClassInternetPassword,
                kSecClassCertificate,
                kSecClassIdentity,
                kSecClassKey,
            ]

            for secClass in classes {
                do {
                    guard let items = try KeychainMigration.allItems(of: secClass) else {
                        continue
                    }

                    print("Found \(items.count) items")

                    for item in items {
                        print("Found item: \(item)")
                    }
                }
                catch {
                    print(error)
                }
            }
        }

        public static func deleteKeychainItemsExceptIdentity() {
            do {
                try KeychainMigration.migrateToDowngrade()
            }
            catch {
                print(error)
            }
        }
    #endif
}
