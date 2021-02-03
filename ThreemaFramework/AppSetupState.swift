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

@objc public class AppSetupState: NSObject {
    
    private let appSetupNotCompleted = "APP_SETUP_NOT_COMPLETED"
    
    private let myIdentityStore: MyIdentityStore?

    @objc init(myIdentityStore: MyIdentityStore?) {
        self.myIdentityStore = myIdentityStore
        super.init()
        
        self.checkDatabaseFile()
    }
    
    @objc override convenience init() {
        self.init(myIdentityStore: nil)
    }
    
    /**
     Check is database not created at first time instanced and identity is provisioned.
     
     - Returns: True means setup process is finished and database and identity is ready
    */
    @objc public func isAppSetupCompleted() -> Bool {
        guard self.myIdentityStore != nil else {
            return false;
        }
        
        return self.existsDatabaseFile() && self.myIdentityStore?.isProvisioned() ?? false;
    }
    
    /**
     Call this if setup completed, otherwise setup screen will show again.
    */
    @objc public func appSetupCompleted() {
        FileUtility.delete(at: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted))
    }
    
    /**
     Check is database not created at first time instanced.
     
     - Returns: True means database already exitsts on first instanced
    */
    @objc public func existsDatabaseFile() -> Bool {
        if UserDefaults.standard.bool(forKey: "FASTLANE_SNAPSHOT") {
            // We create DB for screenshots. Return true to skip wizard
            return true
        }
        return !FileUtility.isExists(fileUrl: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted))
    }
    
    private func checkDatabaseFile() {
        if !FileUtility.isExists(fileUrl: DatabaseManager.storeUrl()) && !FileUtility.isExists(fileUrl: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted)) {
            
            FileUtility.write(fileUrl: FileUtility.appDataDirectory?.appendingPathComponent(appSetupNotCompleted), contents: nil)
        }
    }
}
