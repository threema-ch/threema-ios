//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
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

import RemoteSecret

/// Store setup configuration of steps after the ID is set
@objc class SetupConfiguration: NSObject {
    @objc let remoteSecretAndKeychain: RemoteSecretAndKeychainObjC
    
    // Parameters from `SafeViewController`
    @objc var safePassword: String?
    @objc var safeServer: String?
    @objc var safeCustomServer: String?
    @objc var safeServerUsername: String?
    @objc var safeServerPassword: String?
    @objc var safeMaxBackupBytes: NSNumber?
    @objc var safeRetentionDays: NSNumber?
    
    // Parameters from `PickNicknameViewController`
    @objc var nickname: String?
    
    // Parameters from `LinkIDViewController`
    @objc var linkEmail: String?
    @objc var linkPhoneNumber: String?
    
    // Parameters from `SyncContactsViewController`
    @objc var syncContacts = false
    
    // MARK: Lifecycle
    
    @objc init(remoteSecretAndKeychain: RemoteSecretAndKeychainObjC, mdm: MDMSetup) {
        self.remoteSecretAndKeychain = remoteSecretAndKeychain
        
        // These MDM parameters are user editable thus we set them here once
        
        if mdm.existsMdmKey(MDM_KEY_NICKNAME), let nickname = mdm.nickname() {
            self.nickname = nickname
        }
        
        if mdm.existsMdmKey(MDM_KEY_LINKED_EMAIL), let linkEmail = mdm.linkEmail() {
            self.linkEmail = linkEmail
        }
        
        if mdm.existsMdmKey(MDM_KEY_LINKED_PHONE), let linkPhoneNumber = mdm.linkPhoneNumber() {
            self.linkPhoneNumber = linkPhoneNumber
        }
    }
}
