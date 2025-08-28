//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2025 Threema GmbH
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
import ThreemaEssentials

protocol SafeConfigManagerProtocol {
    func destroy()
    func getKey() -> [UInt8]?
    func setKey(_ value: [UInt8]?)
    func getCustomServer() -> String?
    func setCustomServer(_ value: String?)
    func getServerUser() -> String?
    func setServerUser(_ value: String?)
    func getServerPassword() -> String?
    func setServerPassword(_ value: String?)
    func getServer() -> String?
    func setServer(_ value: String?)
    func getMaxBackupBytes() -> Int?
    func setMaxBackupBytes(_ value: Int?)
    func getRetentionDays() -> Int?
    func setRetentionDays(_ value: Int?)
    func getBackupSize() -> Int64?
    func setBackupSize(_ value: Int64?)
    func getBackupStartedAt() -> Date?
    func setBackupStartedAt(_ value: Date?)
    func getLastBackup() -> Date?
    func setLastBackup(_ value: Date?)
    func getLastResult() -> String?
    func setLastResult(_ value: String?)
    func getLastChecksum() -> [UInt8]?
    func setLastChecksum(_ value: [UInt8]?)
    func getLastAlertBackupFailed() -> Date?
    func setLastAlertBackupFailed(_ value: Date?)
    func getIsTriggered() -> Bool
    func setIsTriggered(_ value: Bool)
}

@objc class SafeConfigManager: NSObject, SafeConfigManagerProtocol {
    private let myIdentityStore: MyIdentityStoreProtocol

    private static let safeConfigMutationLock = DispatchQueue(label: "safeConfigMutationLock")
    private static var safeConfig: SafeData?

    var keychainHelper: KeychainHelper? {
        guard let identity = myIdentityStore.identity else {
            return nil
        }

        return KeychainHelper(identity: ThreemaIdentity(identity))
    }

    @objc override convenience init() {
        self.init(myIdentityStore: MyIdentityStore.shared())
    }

    init(myIdentityStore: MyIdentityStoreProtocol = MyIdentityStore.shared()) {
        self.myIdentityStore = myIdentityStore
    }

    // MARK: - safe config

    @objc public func destroy() {
        UserSettings.shared().safeConfig = nil
        SafeConfigManager.safeConfig = nil
        destroyKeychain()
    }

    public func getKey() -> [UInt8]? {
        getConfig().key
    }

    public func setKey(_ value: [UInt8]?) {
        let config = getConfig()
        config.key = value
        setConfig(config)
    }

    @objc public func getCustomServer() -> String? {
        getConfig().customServer
    }

    @objc public func setCustomServer(_ value: String?) {
        let config = getConfig()
        config.customServer = value
        setConfig(config)
    }

    @objc public func getServerUser() -> String? {
        getConfig().serverUser
    }

    @objc public func setServerUser(_ value: String?) {
        let config = getConfig()
        config.serverUser = value
        setConfig(config)
    }

    @objc public func getServerPassword() -> String? {
        getConfig().serverPassword
    }

    @objc public func setServerPassword(_ value: String?) {
        let config = getConfig()
        config.serverPassword = value
        setConfig(config)
    }

    @objc public func getServer() -> String? {
        getConfig().server
    }

    @objc public func setServer(_ value: String?) {
        let config = getConfig()
        config.server = value
        setConfig(config)
    }

    public func getMaxBackupBytes() -> Int? {
        getConfig().maxBackupBytes
    }
    
    @objc public func getMaxBackupBytesObjC() -> NSNumber? {
        getConfig().maxBackupBytes as NSNumber?
    }

    public func setMaxBackupBytes(_ value: Int?) {
        let config = getConfig()
        config.maxBackupBytes = value
        setConfig(config)
    }

    public func getRetentionDays() -> Int? {
        getConfig().retentionDays
    }
    
    @objc public func getRetentionDaysObjC() -> NSNumber? {
        getConfig().retentionDays as NSNumber?
    }

    public func setRetentionDays(_ value: Int?) {
        let config = getConfig()
        config.retentionDays = value
        setConfig(config)
    }

    public func getBackupSize() -> Int64? {
        getConfig().backupSize
    }

    public func setBackupSize(_ value: Int64?) {
        let config = getConfig()
        config.backupSize = value
        setConfig(config)
    }

    public func getBackupStartedAt() -> Date? {
        getConfig().backupStartedAt
    }

    public func setBackupStartedAt(_ value: Date?) {
        let config = getConfig()
        config.backupStartedAt = value
        setConfig(config)
    }

    public func getLastBackup() -> Date? {
        getConfig().lastBackup
    }

    public func setLastBackup(_ value: Date?) {
        let config = getConfig()
        config.lastBackup = value
        setConfig(config)
    }

    public func getLastResult() -> String? {
        getConfig().lastResult
    }

    public func setLastResult(_ value: String?) {
        let config = getConfig()
        config.lastResult = value
        setConfig(config)
    }

    public func getLastChecksum() -> [UInt8]? {
        getConfig().lastChecksum
    }

    public func setLastChecksum(_ value: [UInt8]?) {
        let config = getConfig()
        config.lastChecksum = value
        setConfig(config)
    }

    public func getLastAlertBackupFailed() -> Date? {
        getConfig().lastAlertBackupFailed
    }

    public func setLastAlertBackupFailed(_ value: Date?) {
        let config = getConfig()
        config.lastAlertBackupFailed = value
        setConfig(config)
    }

    @objc public func getIsTriggered() -> Bool {
        getConfig().isTriggered != 0
    }

    public func setIsTriggered(_ value: Bool) {
        let config = getConfig()
        config.isTriggered = value ? 1 : 0
        setConfig(config)
    }

    private func getConfig() -> SafeData {
        SafeConfigManager.safeConfigMutationLock.sync {
            if SafeConfigManager.safeConfig == nil {
                if let data = UserSettings.shared().safeConfig,
                   !data.isEmpty,
                   let config = decode(safeData: data) {

                    migrateServer(config: config)

                    // Loading key, user and password from Keychain if is key missing,
                    // otherwise all the config values was migrated
                    if config.key == nil {
                        let key = loadKeyFromKeychain()
                        if let key {
                            config.key = key
                        }

                        let (serverUser, serverPassword, server) = loadServerFromKeychain()
                        if let serverUser {
                            config.serverUser = serverUser
                        }
                        if let serverPassword {
                            config.serverPassword = serverPassword
                        }
                        if let server {
                            config.server = server
                        }
                    }

                    SafeConfigManager.safeConfig = config
                }
                else {
                    SafeConfigManager.safeConfig = SafeData(
                        key: nil,
                        customServer: nil,
                        serverUser: nil,
                        serverPassword: nil,
                        server: nil,
                        maxBackupBytes: nil,
                        retentionDays: nil,
                        backupSize: nil,
                        backupStartedAt: nil,
                        lastBackup: nil,
                        lastResult: nil,
                        lastChecksum: nil,
                        lastAlertBackupFailed: nil,
                        isTriggered: 0
                    )
                    UserSettings.shared().safeConfig = encode(safeData: SafeConfigManager.safeConfig)
                }
            }
        }
        return SafeConfigManager.safeConfig!
    }

    private func setConfig(_ config: SafeData?) {
        SafeConfigManager.safeConfigMutationLock.sync {
            if let config {
                migrateServer(config: config)

                storeInKeychain(key: config.key)
                storeInKeychain(
                    serverUser: config.serverUser,
                    serverPassword: config.serverPassword,
                    server: config.server
                )

                UserSettings.shared().safeConfig = encode(safeData: SafeConfigManager.safeConfig)
            }
            else {
                destroy()
            }
        }
    }

    /// Migrate old server URL with including user and password. Don't remove this function
    /// to migrate older version of `SafeData`!
    ///
    /// The user and password will not be stored within the URL anymore.
    /// - Parameter config: Safe config to migrate is necessary
    private func migrateServer(config: SafeData) {
        guard let serverAuth = config.server, let serverAuthURL = URL(string: serverAuth) else {
            return
        }

        let (serverUser, serverPassword, server) = SafeStore.extractSafeServerAuth(server: serverAuthURL)
        if let serverUser {
            config.serverUser = serverUser
        }
        if let serverPassword {
            config.serverPassword = serverPassword
        }
        config.server = server.absoluteString
    }

    private func encode(safeData: SafeData?) -> Data? {
        guard let safeData else {
            return nil
        }

        var data: Data?

        do {
            data = try NSKeyedArchiver
                .archivedData(withRootObject: safeData as Any, requiringSecureCoding: true)
        }
        catch {
            DDLogError("Encoding of `SafeData` failed: \(error)")
        }

        return data
    }

    private func decode(safeData data: Data) -> SafeData? {
        var safeData: SafeData?

        do {
            safeData = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [SafeData.self, NSArray.self, NSDate.self, NSNumber.self, NSString.self],
                from: data
            ) as? SafeData
        }
        catch {
            DDLogError("Decoding for `SafeData` failed: \(error)")
        }

        return safeData
    }

    private func loadKeyFromKeychain() -> [UInt8]? {
        guard let keychainHelper else {
            return nil
        }

        let (password, _, _) = keychainHelper.load(item: .threemaSafeKey)

        return password != nil ? Array(password!) : nil
    }

    private func loadServerFromKeychain() -> (serverUser: String?, serverPassword: String?, server: String?) {
        guard let keychainHelper else {
            return (nil, nil, nil)
        }

        let result = keychainHelper.load(item: .threemaSafeServer)

        return (
            serverUser: result.generic != nil ? String(data: result.generic!, encoding: .utf8) : nil,
            serverPassword: result.password != nil ? String(data: result.password!, encoding: .utf8) : nil,
            server: result.service
        )
    }

    private func storeInKeychain(key: [UInt8]?) {
        guard let keychainHelper else {
            return
        }

        do {
            if let key {
                try keychainHelper.store(
                    password: Data(bytes: key, count: key.count),
                    item: .threemaSafeKey
                )
            }
            else {
                try keychainHelper.destroy(item: .threemaSafeKey)
            }
        }
        catch {
            DDLogError("\(error)")
        }
    }

    private func storeInKeychain(serverUser: String?, serverPassword: String?, server: String?) {
        guard let keychainHelper else {
            return
        }

        do {
            if let serverUser, let serverPassword, let server {
                try keychainHelper.store(
                    password: Data(serverPassword.utf8),
                    generic: Data(serverUser.utf8),
                    service: server,
                    item: .threemaSafeServer
                )
            }
            else {
                try keychainHelper.destroy(item: .threemaSafeServer)
            }
        }
        catch {
            DDLogError("\(error)")
        }
    }

    private func destroyKeychain() {
        guard let keychainHelper else {
            return
        }

        do {
            try keychainHelper.destroy(item: .threemaSafeKey)
            try keychainHelper.destroy(item: .threemaSafeServer)
        }
        catch {
            DDLogError("\(error)")
        }
    }
}
