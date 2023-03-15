//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2019-2023 Threema GmbH
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

@objc open class AppSetupState: NSObject {
    
    private let appSetupNotCompleted = "APP_SETUP_NOT_COMPLETED"
    
    private let myIdentityStore: MyIdentityStore?

    @objc public init(myIdentityStore: MyIdentityStore?) {
        self.myIdentityStore = myIdentityStore
        super.init()
        
        checkDatabaseFile()
    }
    
    @objc override public convenience init() {
        self.init(myIdentityStore: nil)
    }
    
    /// Check is database not created at first time instanced and identity is provisioned.
    ///
    /// - Returns: True means setup process is finished and database and identity is ready
    @objc public func isAppSetupCompleted() -> Bool {
        guard let identityStore = myIdentityStore else {
            return false
        }

        return existsDatabaseFile() && identityStore.isProvisioned()
    }
    
    /// Call this if setup completed, otherwise setup screen will show again.
    @objc public func appSetupCompleted() {
        FileUtility.delete(at: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted))
    }
    
    /// Check is database not created at first time instanced.
    ///
    /// - Returns: True means database already exitsts on first instanced
    @objc public func existsDatabaseFile() -> Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            // We create DB for screenshots. Return true to skip wizard
            return true
        }
        return !FileUtility
            .isExists(fileURL: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted))
    }
    
    private func checkDatabaseFile() {
        if !FileUtility.isExists(fileURL: DatabaseManager.storeURL()),
           !FileUtility.isExists(fileURL: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted)) {
            
            FileUtility.write(
                fileURL: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted),
                contents: nil
            )
        }
    }
}
