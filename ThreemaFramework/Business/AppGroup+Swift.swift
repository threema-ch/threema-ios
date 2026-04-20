import CocoaLumberjackSwift
import Foundation

extension AppGroup {
    @objc static func refreshDirtyObjects() {
        guard let remoteSecretManager = AppLaunchManager.remoteSecretManager else {
            DDLogWarn(
                "Refresh of dirty objects not possible rigth now, because remote secret manager is not initialized"
            )
            return
        }

        let persistenceManager = PersistenceManager(
            appGroupID: AppGroup.groupID(),
            userDefaults: AppGroup.userDefaults(),
            remoteSecretManager: remoteSecretManager
        )

        // Call refresh of dirty objects with reset `false` to not remove them from NSUserDefault.
        // Because of different processes of the Notification Extension (adding dirty objects)
        // and the App (refresh and remove dirty objects) it's not guaranteed that a dirty object has been refreshed.
        persistenceManager.dirtyObjectManager.refreshDirtyObjects(reset: false)
    }
}
