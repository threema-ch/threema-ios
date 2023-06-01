//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023 Threema GmbH
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

public class DeleteRevokeIdentityManager: NSObject {
    
    enum DeleteRevokeIdentityManagerError: Error {
        case revocationFailed
    }
    
    @objc public static func deleteLocalData() {
        
        MyIdentityStore.shared().destroy()
        UserReminder.markIdentityAsDeleted()
        
        // Threema Safe
        let safeConfigManager = SafeConfigManager()
        safeConfigManager.destroy()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: GroupManager()
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
        safeManager.setBackupReminder()
        
        // DB & Files
        FileUtility.removeItemsInAllDirectories()
        AppGroup.resetUserDefaults()
        DatabaseManager().eraseDB()
        
        Task { @MainActor in
            UIApplication.shared.unregisterForRemoteNotifications()
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        KKPasscodeLock.shared().disablePasscode()
        
        if LicenseStore.requiresLicenseKey() {
            // Delete the license when we delete the ID, to give the user a chance to use a new license.
            // The license may have been supplied by MDM, so we load it again.
            LicenseStore.shared().deleteLicense()
            let mdmSetup = MDMSetup()
            mdmSetup.loadLicenseInfo()
            if LicenseStore.shared().licenseUsername == nil || LicenseStore.shared().licensePassword == nil {
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: kNotificationLicenseMissing),
                    object: nil
                )
            }
            mdmSetup.deleteThreemaMdm()
        }
    }
    
    static func revokeIdentity() async throws {
        
        try await withCheckedThrowingContinuation { continuation in
            let connector = ServerAPIConnector()
            connector.revokeID(MyIdentityStore.shared()) {
                continuation.resume()
            } onError: { error in
                guard let error else {
                    continuation.resume(throwing: DeleteRevokeIdentityManagerError.revocationFailed)
                    return
                }
                continuation.resume(throwing: error)
            }
        }
    }
}
