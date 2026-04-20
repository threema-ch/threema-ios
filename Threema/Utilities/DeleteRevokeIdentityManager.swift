import CocoaLumberjackSwift
import FileUtility
import Foundation
import Keychain
import UserNotifications

public final class DeleteRevokeIdentityManager: NSObject {
    
    enum DeleteRevokeIdentityManagerError: Error {
        case revocationFailed
    }

    @available(
        swift,
        obsoleted: 1.0,
        renamed: "deleteLocalDataWithoutBusinessReady()",
        message: "Only use from Objective-C"
    )
    @objc static func deleteLocalDataWithoutBusinessReadyObjC(completion: @escaping () -> Void) {
        Task { @MainActor in
            await deleteLocalDataWithoutBusinessReady()
            completion()
        }
    }
    
    /// Since business might no be available in all cases (e.g. when entering the passcode), and we need
    /// to delete all data, we cannot remove everything that would make use of business.
    static func deleteLocalDataWithoutBusinessReady() async {
        // Files
        UserDefaults.resetStandardUserDefaults()
        FileUtility.shared.removeItemsInAllDirectories(appGroupID: AppGroup.groupID())
       
        // Keychain
        do {
            try KeychainManager.deleteAllItems()
        }
        catch {
            DDLogError("Not all Keychain items could be deleted: \(error)")
        }
        
        KKPasscodeLock.shared().disablePasscode()
    }
    
    static func deleteLocalData() async {
        // Stop RS monitoring to prevent any monitoring error crashing during deletion
        do {
            try KeychainManager.deleteRemoteSecret()
            await AppLaunchManager.remoteSecretManager.stopMonitoring()
        }
        catch {
            DDLogError("Stopping RS monitoring failed: \(error)")
        }
        
        // Multi device
        do {
            let multiDeviceManager = MultiDeviceManager()
            try await multiDeviceManager.disableMultiDevice(runForwardSecurityRefreshSteps: false)
        }
        catch {
            DDLogError("Disabling multi-device: \(error)")
        }

        // My identity
        MyIdentityStore.shared().destroy()
        UserReminder.markIdentityAsDeleted()

        // Threema Safe
        let safeConfigManager = SafeConfigManager()
        safeConfigManager.destroy()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: BusinessInjector.ui.groupManager,
            myIdentityStore: BusinessInjector.ui.myIdentityStore
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeAPIService: SafeApiService()
        )
        safeManager.setBackupReminder()

        // DB & Files
        UserDefaults.resetStandardUserDefaults()
        AppGroup.resetUserDefaults()
        FileUtility.shared.removeItemsInAllDirectories(appGroupID: AppGroup.groupID())
        try? PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: AppLaunchManager.remoteSecretManager
        ).databaseManager.eraseDB()

        Task { @MainActor in
            UIApplication.shared.unregisterForRemoteNotifications()
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(0)
            }
            catch {
                DDLogError("[DeleteRevokeIdentityManager] Failed to reset badge count with error: \(error)")
            }
        }

        KKPasscodeLock.shared().disablePasscode()

        if TargetManager.isBusinessApp {
            // Delete the license when we delete the ID, to give the user a chance to use a new license.
            // The license may have been supplied by MDM, so we load it again.
            LicenseStore.shared().deleteLicense()
            let mdmSetup = MDMSetup()
            mdmSetup?.deleteThreemaMdm()
        }

        // Keychain
        do {
            try KeychainManager.deleteAllItems()
        }
        catch {
            DDLogError("Not all Keychain items could be deleted: \(error)")
        }
    }

    static func deleteBackups() {
        // Delete Threema Safe backup
        let safeConfigManager = SafeConfigManager()
        let safeStore = SafeStore(
            safeConfigManager: safeConfigManager,
            serverApiConnector: ServerAPIConnector(),
            groupManager: BusinessInjector.ui.groupManager,
            myIdentityStore: BusinessInjector.ui.myIdentityStore
        )
        let safeManager = SafeManager(
            safeConfigManager: safeConfigManager,
            safeStore: safeStore,
            safeAPIService: SafeApiService()
        )
        safeManager.deactivate()

        // Delete ID Export
        do {
            try IdentityBackupStore.deleteIdentityBackup()
        }
        catch {
            NotificationPresenterWrapper.shared.present(type: .deleteIdentityBackupFailed)
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
