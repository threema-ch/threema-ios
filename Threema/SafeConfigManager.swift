//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2021 Threema GmbH
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

protocol SafeConfigManagerProtocol {
    func destroy()
    func getKey() -> [UInt8]?
    func setKey(_ value: [UInt8]?)
    func getCustomServer() -> String?
    func setCustomServer(_ value: String?)
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
    
    private static let safeConfigMutaionLock: DispatchQueue = DispatchQueue(label: "safeConfigMutaionLock")
    private static var safeConfig: SafeData?

    //MARK: - safe config
    
    @objc public func destroy() {
        SafeConfigManager.safeConfig = nil
    }
    
    public func getKey() -> [UInt8]? {
        return getConfig().key
    }
    public func setKey(_ value: [UInt8]?) {
        let config = getConfig()
        config.key = value
        setConfig(config)
    }
    
    public func getCustomServer() -> String? {
        return getConfig().customServer
    }
    @objc public func setCustomServer(_ value: String?) {
        let config = getConfig()
        config.customServer = value
        setConfig(config)
    }
    
    public func getServer() -> String? {
        return getConfig().server
    }
    @objc public func setServer(_ value: String?) {
        let config = getConfig()
        config.server = value
        setConfig(config)
    }
    
    public func getMaxBackupBytes() -> Int? {
        return getConfig().maxBackupBytes
    }
    public func setMaxBackupBytes(_ value: Int?) {
        let config = getConfig()
        config.maxBackupBytes = value
        setConfig(config)
    }
    
    public func getRetentionDays() -> Int? {
        return getConfig().retentionDays
    }
    public func setRetentionDays(_ value: Int?) {
        let config = getConfig()
        config.retentionDays = value
        setConfig(config)
    }
    
    public func getBackupSize() -> Int64? {
        return getConfig().backupSize
    }
    public func setBackupSize(_ value: Int64?) {
        let config = getConfig()
        config.backupSize = value
        setConfig(config)
    }
    
    public func getBackupStartedAt() -> Date? {
        return getConfig().backupStartedAt
    }
    public func setBackupStartedAt(_ value: Date?) {
        let config = getConfig()
        config.backupStartedAt = value
        setConfig(config)
    }
    
    public func getLastBackup() -> Date? {
        return getConfig().lastBackup
    }
    public func setLastBackup(_ value: Date?) {
        let config = getConfig()
        config.lastBackup = value
        setConfig(config)
    }
    
    public func getLastResult() -> String? {
        return getConfig().lastResult
    }
    public func setLastResult(_ value: String?) {
        let config = getConfig()
        config.lastResult = value
        setConfig(config)
    }
    
    public func getLastChecksum() -> [UInt8]? {
        return getConfig().lastChecksum
    }
    public func setLastChecksum(_ value: [UInt8]?) {
        let config = getConfig()
        config.lastChecksum = value
        setConfig(config)
    }
    
    public func getLastAlertBackupFailed() -> Date? {
        return getConfig().lastAlertBackupFailed
    }
    public func setLastAlertBackupFailed(_ value: Date?) {
        let config = getConfig()
        config.lastAlertBackupFailed = value
        setConfig(config)
    }
    
    public func getIsTriggered() -> Bool {
        return getConfig().isTriggered != 0
    }
    public func setIsTriggered(_ value: Bool) {
        let config = getConfig()
        config.isTriggered = value ? 1 : 0
        setConfig(config)
    }
    
    private func getConfig() -> SafeData {
        SafeConfigManager.safeConfigMutaionLock.sync {
            if SafeConfigManager.safeConfig == nil {
                if let data = UserSettings.shared().safeConfig,
                    data.count > 0 {
                    
                    SafeConfigManager.safeConfig = NSKeyedUnarchiver.unarchiveObject(with: data) as? SafeData
                } else {
                    SafeConfigManager.safeConfig = SafeData(key: nil, customServer: nil, server: nil, maxBackupBytes: nil, retentionDays: nil, backupSize: nil, backupStartedAt: nil, lastBackup: nil, lastResult: nil, lastChecksum: nil, lastAlertBackupFailed: nil, isTriggered: 0)
                    UserSettings.shared().safeConfig = NSKeyedArchiver.archivedData(withRootObject: SafeConfigManager.safeConfig as Any)
                }
            }
        }
        return SafeConfigManager.safeConfig!
    }
    
    private func setConfig(_ config: SafeData?) {
        SafeConfigManager.safeConfigMutaionLock.sync {
            if let data = config {
                UserSettings.shared().safeConfig = NSKeyedArchiver.archivedData(withRootObject: data)
            } else {
                UserSettings.shared().safeConfig = nil
                destroy()
            }
        }
    }
}
