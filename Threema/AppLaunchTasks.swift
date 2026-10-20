import CocoaLumberjackSwift
import FileUtility
import Foundation
import Keychain
import ThreemaEssentials
import ThreemaFramework

enum AppLaunchEvent {
    case didFinishLaunching
    case willEnterForeground
}

protocol AppLaunchTasksProtocol {
    func run(launchEvent: AppLaunchEvent)
}

final class AppLaunchTasks: AppLaunchTasksProtocol {

    private let businessInjector: BusinessInjectorProtocol
    private static var isRunning = false
    private static let isRunningQueue = DispatchQueue(label: "ch.threema.AppLaunchTasks.isRunningQueue")
    
    // Did the version or build change since the last launch? (This also detects changes between Store, TestFlight and
    // Xcode builds.)
    static var lastLaunchedVersionChanged: Bool {
        let lastVersion = AppGroup.userDefaults().string(forKey: "LastLaunchedAppVersionAndBuild")
        let currentVersion = ThreemaUtility.appAndBuildVersion
        
        guard let lastVersion else {
            DDLogNotice("Version has changed since last launch of app. Last: nil, current: \(currentVersion)")
            return true
        }
        
        if lastVersion != ThreemaUtility.appAndBuildVersion {
            DDLogNotice(
                "Version has changed since last launch of app. Last: \(lastVersion), current: \(currentVersion)"
            )
            return true
        }
        
        // No change
        return false
    }

    init(businessInjector: BusinessInjectorProtocol) {
        self.businessInjector = businessInjector
    }
    
    /// Runs some tasks/procedures when the App will be launched or will enter foreground. Especially DB repairing and
    /// checks must be run in the right order. But also other tasks can be started here, with the benefit this tasks
    /// will be run in serial.
    ///
    /// - Parameter launchEvent: App is launching or will enter foreground
    func run(launchEvent: AppLaunchEvent) {
        AppLaunchTasks.isRunningQueue.sync {
            guard !AppLaunchTasks.isRunning else {
                return
            }
            AppLaunchTasks.isRunning = true
            
            // Refresh dirty objects as early as possible
            let persistenceManager = PersistenceManager(
                appGroupID: AppGroup.groupID(),
                userDefaults: AppGroup.userDefaults(),
                remoteSecretManager: RemoteSecretProvider.remoteSecretManager
            )
            persistenceManager.dirtyObjectManager.refreshDirtyObjects(reset: true)
            
            switch launchEvent {
            case .didFinishLaunching:
                
                // Repairs database integrity only on app start and synchronously,
                // must be finished before running other tasks and returning to the caller
                businessInjector.entityManager.repairDatabaseIntegrity()

                // Delete all files and directories from temporary app directory
                FileUtility.shared.removeItemsInDirectory(directoryURL: FileUtility.shared.appTemporaryDirectory)
                
                // Reset MD setting if needed
                businessInjector.multiDeviceManager.resetEnableMultiDeviceIfNeeded()

                createPushNotificationEncryptionKeyIfNeeded()

                if AppLaunchTasks.lastLaunchedVersionChanged {
                    Task {
                        do {
                            try await AppUpdateSteps().run()
                            // Only persist last launched version if update steps were successful
                            AppLaunchTasks.updateLastLaunchedVersion()
                        }
                        catch {
                            DDLogWarn("Failed to run application update steps. Try again on next launch. \(error)")
                        }
                    }
                }
            case .willEnterForeground:
                // Validate RS if needed (& existing)
                RemoteSecretProvider.remoteSecretManager.checkValidity()
            }
            
            // Publish the microphone permission for the extensions, it might have been changed in the settings
            RecordPermission.storeCurrentAccess()

            checkLastMessageOfAllConversations()
            businessInjector.messageRetentionManager.deleteOldMessages()
            
            // All other tasks runs in a background thread
            Task {
                await businessInjector.runInBackground { businessInjector in
                    // This allows to disable multi-device if MD linking failed with a crash or if all other devices
                    // left the MD group
                    if launchEvent == .didFinishLaunching {
                        businessInjector.multiDeviceManager.disableMultiDeviceIfNeeded()
                    }
                    
                    AppLaunchTasks.isRunningQueue.async {
                        AppLaunchTasks.isRunning = false
                    }
                }
            }
        }
    }
    
    /// Create the key that the server uses to encrypt the payload of push notifications, if there is none
    ///
    /// Only the app may create it, because it is registered with the server when the push token is sent
    /// (`ServerConnector`). The extensions just read it to decrypt an incoming push.
    private func createPushNotificationEncryptionKeyIfNeeded() {
        do {
            guard try KeychainManager.loadPushNotificationEncryptionKey() == nil else {
                return
            }

            guard let key = BytesUtility.generateRandomBytes(length: Int(kNaClCryptoSymmKeySize)) else {
                DDLogError("Unable to create push notification encryption key")
                return
            }

            try KeychainManager.storePushNotificationEncryptionKey(key)

            DDLogNotice("Created push notification encryption key")
        }
        catch {
            DDLogError("Unable to create push notification encryption key: \(error)")
        }
    }

    private static func updateLastLaunchedVersion() {
        guard AppLaunchTasks.lastLaunchedVersionChanged else {
            return
        }
        let currentVersion = ThreemaUtility.appAndBuildVersion
        DDLogNotice("Update last launched version to: \(currentVersion)")
        AppGroup.userDefaults().setValue(currentVersion, forKey: "LastLaunchedAppVersionAndBuild")
    }

    /// Checks if the currently assigned last message of given Conversations is actually the correct one and fixes it
    /// if not (and recalculate count of unread messages for this conversation).
    private func checkLastMessageOfAllConversations() {
        var doUpdateUnreadMessagesCount = false

        businessInjector.entityManager.performAndWaitSave {
            guard let conversations = self.businessInjector.entityManager.entityFetcher
                .conversationEntities() else {
                return
            }

            for conversation in conversations {
                guard let effectiveLastMessage = MessageFetcher(
                    for: conversation,
                    with: self.businessInjector.entityManager
                ).lastDisplayMessage() else {
                    conversation.lastMessage = nil
                    continue
                }
                
                if conversation.lastMessage != effectiveLastMessage {
                    DDLogNotice(
                        "Assigned last message \(conversation.lastMessage?.id.hexString ?? "nil") did not equal effective last message \(effectiveLastMessage.id.hexString)"
                    )
                    conversation.lastMessage = effectiveLastMessage

                    self.businessInjector.unreadMessages.count(for: conversation)

                    doUpdateUnreadMessagesCount = true
                }
            }
        }

        if doUpdateUnreadMessagesCount {
            NotificationManager(businessInjector: businessInjector).updateUnreadMessagesCount()
        }
    }
}
