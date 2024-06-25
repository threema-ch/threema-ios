//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2024 Threema GmbH
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

public class DeleteRevokeIdentityManager: NSObject {
    
    enum DeleteRevokeIdentityManagerError: Error {
        case revocationFailed
    }

    @objc static func deleteLocalDataObjC(completion: @escaping () -> Void) {
        Task { @MainActor in
            await deleteLocalData()
            completion()
        }
    }
    
    static func deleteLocalData() async {
        do {
            let multiDeviceManager = MultiDeviceManager()
            try await multiDeviceManager.disableMultiDevice()
        }
        catch {
            DDLogError("Disabling multi-device: \(error)")
        }

        MyIdentityStore.shared().destroy()
        UserReminder.markIdentityAsDeleted()

        // Threema Safe
        let safeConfigManager = SafeConfigManager()
        safeConfigManager.destroy()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: BusinessInjector().groupManager
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
        safeManager.setBackupReminder()

        // DB & Files
        FileUtility.shared.removeItemsInAllDirectories()
        AppGroup.resetUserDefaults()
        DatabaseManager().eraseDB()

        await MainActor.run {
            UIApplication.shared.unregisterForRemoteNotifications()
            UIApplication.shared.applicationIconBadgeNumber = 0
        }

        KKPasscodeLock.shared().disablePasscode()

        if LicenseStore.requiresLicenseKey() {
            // Delete the license when we delete the ID, to give the user a chance to use a new license.
            // The license may have been supplied by MDM, so we load it again.
            LicenseStore.shared().deleteLicense()
            let mdmSetup = MDMSetup(setup: false)
            mdmSetup?.deleteThreemaMdm()
        }
    }

    static func deleteBackups() {
        // Delete Threema Safe backup
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: BusinessInjector().groupManager
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeApiService: SafeApiService()
        )
        safeManager.deactivate()

        // Delete ID Export
        IdentityBackupStore.deleteIdentityBackup()
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
