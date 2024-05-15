//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2018-2023 Threema GmbH
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

@objc public class SafeData: NSObject, NSSecureCoding {
    public static var supportsSecureCoding = true

    public var key: [UInt8]?
    public var customServer: String?
    public var serverUser: String?
    public var serverPassword: String?
    public var server: String?
    public var maxBackupBytes: Int?
    public var retentionDays: Int?
    public var backupSize: Int64?
    public var backupStartedAt: Date?
    public var lastBackup: Date?
    public var lastResult: String?
    public var lastChecksum: [UInt8]?
    public var lastAlertBackupFailed: Date?
    public var isTriggered: Int? = 0

    public init(
        key: [UInt8]?,
        customServer: String?,
        serverUser: String?,
        serverPassword: String?,
        server: String?,
        maxBackupBytes: Int?,
        retentionDays: Int?,
        backupSize: Int64?,
        backupStartedAt: Date?,
        lastBackup: Date?,
        lastResult: String?,
        lastChecksum: [UInt8]?,
        lastAlertBackupFailed: Date?,
        isTriggered: Int?
    ) {
        self.key = key
        self.customServer = customServer
        self.serverUser = serverUser
        self.serverPassword = serverPassword
        self.server = server
        self.maxBackupBytes = maxBackupBytes
        self.retentionDays = retentionDays
        self.backupSize = backupSize
        self.backupStartedAt = backupStartedAt
        self.lastBackup = lastBackup
        self.lastResult = lastResult
        self.lastChecksum = lastChecksum
        self.lastAlertBackupFailed = lastAlertBackupFailed
        self.isTriggered = isTriggered
    }
    
    public required convenience init?(coder aDecoder: NSCoder) {
        let key = aDecoder.decodeObject(forKey: "key") as? [UInt8]
        let customServer = aDecoder.decodeObject(forKey: "customServer") as? String
        let server = aDecoder.decodeObject(forKey: "server") as? String
        let maxBackupBytes = aDecoder.decodeObject(forKey: "maxBackupBytes") as? Int
        let retentionDays = aDecoder.decodeObject(forKey: "retentionDays") as? Int
        let backupSize = aDecoder.decodeObject(forKey: "backupSize") as? Int64
        let backupStartedAt = aDecoder.decodeObject(forKey: "backupStartedAt") as? Date
        let lastBackup = aDecoder.decodeObject(forKey: "lastBackup") as? Date
        let lastResult = aDecoder.decodeObject(forKey: "lastResult") as? String
        let lastChecksum = aDecoder.decodeObject(forKey: "lastChecksum") as? [UInt8]
        let lastAlertBackupFailed = aDecoder.decodeObject(forKey: "lastAlertBackupFailed") as? Date
        let isTriggered = aDecoder.decodeObject(forKey: "isTriggered") as? Int

        self.init(
            key: key,
            customServer: customServer,
            serverUser: nil, // Stored in keychain
            serverPassword: nil, // Stored in keychain
            server: server,
            maxBackupBytes: maxBackupBytes,
            retentionDays: retentionDays,
            backupSize: backupSize,
            backupStartedAt: backupStartedAt,
            lastBackup: lastBackup,
            lastResult: lastResult,
            lastChecksum: lastChecksum,
            lastAlertBackupFailed: lastAlertBackupFailed,
            isTriggered: isTriggered ?? 0
        )
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(customServer, forKey: "customServer")
        aCoder.encode(server, forKey: "server")
        aCoder.encode(maxBackupBytes, forKey: "maxBackupBytes")
        aCoder.encode(retentionDays, forKey: "retentionDays")
        aCoder.encode(backupSize, forKey: "backupSize")
        aCoder.encode(backupStartedAt, forKey: "backupStartedAt")
        aCoder.encode(lastBackup, forKey: "lastBackup")
        aCoder.encode(lastResult, forKey: "lastResult")
        aCoder.encode(lastChecksum, forKey: "lastChecksum")
        aCoder.encode(lastAlertBackupFailed, forKey: "lastAlertBackupFailed")
        aCoder.encode(isTriggered, forKey: "isTriggered")
    }
}
