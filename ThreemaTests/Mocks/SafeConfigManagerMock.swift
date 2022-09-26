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

@testable import Threema

class SafeConfigManagerMock: NSObject, SafeConfigManagerProtocol {
    var safeConfigDestroyCallCount = 0
    
    private var server: String?
    
    init(server: String?) {
        self.server = server
    }
    
    func destroy() {
        safeConfigDestroyCallCount += 1
    }
    
    func getKey() -> [UInt8]? {
        nil
    }
    
    func setKey(_ value: [UInt8]?) { }
    
    func getCustomServer() -> String? {
        nil
    }
    
    func setCustomServer(_ value: String?) { }
    
    func getServer() -> String? {
        server
    }
    
    func setServer(_ value: String?) { }
    
    func getMaxBackupBytes() -> Int? {
        nil
    }
    
    func setMaxBackupBytes(_ value: Int?) { }
    
    func getRetentionDays() -> Int? {
        nil
    }
    
    func setRetentionDays(_ value: Int?) { }
    
    func getBackupSize() -> Int64? {
        nil
    }
    
    func setBackupSize(_ value: Int64?) { }
    
    func getBackupStartedAt() -> Date? {
        nil
    }
    
    func setBackupStartedAt(_ value: Date?) { }
    
    func getLastBackup() -> Date? {
        nil
    }
    
    func setLastBackup(_ value: Date?) { }
    
    func getLastResult() -> String? {
        nil
    }
    
    func setLastResult(_ value: String?) { }
    
    func getLastChecksum() -> [UInt8]? {
        nil
    }
    
    func setLastChecksum(_ value: [UInt8]?) { }
    
    public func getLastAlertBackupFailed() -> Date? {
        nil
    }
    
    public func setLastAlertBackupFailed(_ value: Date?) { }

    func getIsTriggered() -> Bool {
        false
    }
    
    func setIsTriggered(_ value: Bool) { }
}
