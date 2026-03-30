//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2023-2025 Threema GmbH
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

import BackgroundTasks
import CocoaLumberjackSwift
import FileUtility
import Foundation
import Intents
import Keychain
import MBProgressHUD
import PushKit
import RemoteSecretProtocol
import SwiftUI
import ThreemaFramework
import ThreemaMacros

extension AppDelegate {

    static var keyWindow: UIWindow? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
        else {
            return nil
        }
        return window
    }

    // MARK: - App launch

    // TODO: (IOS-5305) See if we can merge this with the implementation in `CompletedIDViewController+Swift`
    @MainActor @objc func appLaunch() async throws -> BusinessInjector? {
        window.makeKeyAndVisible()
        
        do {
            let logFile = LogManager.appLaunchLogFile
            LogManager.deleteLogFile(logFile)
            LogManager.addFileLogger(logFile)
            
            if try KeychainManager.loadThreemaIdentity() == nil {
                // We end up here after an iOS data backup restore, because the ID won't be around. In that case we
                // reset the configuration for the previous ID, which also resets the `AppSetup` `state`
                
                // We always delete all ID configurations, because the restored ID might not be the same ID that was
                // used with this configuration before
                MyIdentityStore.shared().removeIdentityUserDefaults()
            }

            // If a user deletes an RS-enabled app from the Home Screen all information is still in the keychain, but
            // there is not preexisting data (and thus the `AppSetupState` is `notSetup`). In this case we delete all
            // RS-related data in keychain. As soon as `AppSetupState` is not `notSetup` anymore an ID was created or
            // restored and any potential new RS created. Thus we don't delete anything.
            // TODO: (IOS-6023) Can we generalize this cleanup?
            if KeychainManager.hasRemoteSecretInStore() &&
                AppSetup.hasPreexistingDatabaseFile == false &&
                AppSetup.state == .notSetup {
                
                try KeychainManager.deleteAllEncryptedItems()
                try KeychainManager.deleteRemoteSecret()
            }
            
            guard showOnboardingIfNeeded() == false else {
                return nil
            }

            let remoteSecretManager: RemoteSecretManagerProtocol
            if AppLaunchManager.remoteSecretManager == nil {
                
                // We store the current view hierarchy to restore it later
                let previousVC = window.rootViewController
                
                let navigationController = UINavigationController()
                navigationController.isNavigationBarHidden = true
                window.rootViewController = navigationController
                
                remoteSecretManager = try await AppLaunchManager.shared.initializeRemoteSecret(
                    navigationController: navigationController,
                    onDelete: { [weak self] in
                        guard let self else {
                            return
                        }
                    
                        deleteLocalDataWithoutRemoteSecretManager()
                    }, onCancel: nil
                )
                
                // Restore view hierarchy
                window.rootViewController = previousVC
            }
            else {
                DDLogNotice("Remote secret was already initialized. This should only happen if setup run before")
                remoteSecretManager = AppLaunchManager.remoteSecretManager
            }

            DebugLog.logAppConfiguration()

            // TODO: (IOS-5305) Move keychain manager creation out of here
            let keychainManager = KeychainManager(remoteSecretManager: remoteSecretManager)

            // Hack to make app migration work
            if let identity = try keychainManager.loadIdentity() {
                MyIdentityStore.shared().setupIdentity(identity)
            }
            else {
                assertionFailure("We should never end up here, identity should be set up at this point")
                throw AppLaunchManager.AppLaunchError.myIdentityIsMissing
            }
            
            let databaseManager = try await SetupApp
                .runDatabaseMigrationIfNeeded(remoteSecretManager: remoteSecretManager)

            try await SetupApp.runAppMigrationIsNeeded()

            // TODO: (IOS-5305) Fix with proper app setup
            // Hack to make app launch after setup work
            if let license = try? keychainManager.loadLicense() {
                LicenseStore.shared().licenseUsername = license.user
                LicenseStore.shared().licensePassword = license.password
                LicenseStore.shared().licenseDeviceID = license.deviceID ?? ""
                LicenseStore.shared().onPremConfigURL = license.onPremServer
            }
            
            // TODO: (IOS-5579) Check if this is still needed with full OPPF caching
            // After the license is set we can fetch the OPPF
            // Reset pinned certificates to ensure we (also) use pins from OPPF for OnPrem flavor apps
            if TargetManager.isOnPrem || TargetManager.isCustomOnPrem {
                NotificationCenter.default.post(name: .resetSSLCAHelperCache, object: nil)
            }

            LogManager.removeFileLogger(logFile)
            LogManager.deleteLogFile(logFile)

            let businessInjector = try AppLaunchManager.shared.business(
                remoteSecretManager: remoteSecretManager,
                databaseManager: databaseManager,
                myIdentityStore: MyIdentityStore.shared()
            )

            // At this point is allowed to use BusinessInjector

            let appLaunchTasks = AppLaunchTasks()
            appLaunchTasks.run(launchEvent: .didFinishLaunching)

            // Apply company MDM
            let mdmSetup = MDMSetup()
            mdmSetup?.applyCompanyMDMWithCachedThreemaMDM(sendForce: false)

            // Delete Threema-ID-Backup when backup is blocked from MDM
            if mdmSetup?.disableBackups() ?? false || mdmSetup?.disableIDExport() ?? false ||
                mdmSetup?.disableSystemBackups() ?? false {
                do {
                    try IdentityBackupStore.deleteIdentityBackup()
                }
                catch {
                    NotificationPresenterWrapper.shared.present(type: .deleteIdentityBackupFailed)
                }
            }

            // Prevent or release iOS iCloud backup
            let backupFilesManager = BackupFilesManager()
            backupFilesManager.setIsExcludedFromBackup(
                exclude: mdmSetup?.disableBackups() ?? false || mdmSetup?.disableSystemBackups() ?? false
            )

            registerMemoryWarningNotifications()

            return businessInjector
        }
        catch AppLaunchManager.AppLaunchError.requireDatabaseMigrationFailed {
            ErrorHandler.abort(
                withTitle: #localize("error_message_requires_migration_error_title"),
                message: #localize("error_message_requires_migration_error_description")
            )
            return nil
        }
        catch let DatabaseManager.DatabaseManagerError.notEnoughDiskSpaceAvailable(
            minimumRequiredDiskSpace: minimumRequiredDiskSpace,
            freeDiskSpace: freeDiskSpace
        ) {
            let message = String(
                format: #localize("database_migration_storage_warning_message"),
                minimumRequiredDiskSpace,
                freeDiskSpace
            )
            ErrorHandler.abort(withTitle: #localize("database_migration_storage_warning_title"), message: message)
            return nil
        }
    }
    
    /// Show the onboarding if needed
    /// - Returns: `true` if the onboarding is presented
    private func showOnboardingIfNeeded() -> Bool {
        guard AppLaunchManager.shared.isAppSetupCompleted == false else {
            return false
        }
        
        if KKPasscodeLock.shared().isPasscodeRequired(), AppDelegate.shared().isAppLocked {
            AppDelegate.shared().presentPasscodeView()
        }
        else {
            // Try to obtain an unencrypted license from the keychain
            if TargetManager.isBusinessApp, !KeychainManager.hasRemoteSecretInStore() {
                let setupApp = SetupApp(
                    delegate: nil,
                    licenseStore: LicenseStore.shared(),
                    myIdentityStore: MyIdentityStore.shared(),
                    mdmSetup: MDMSetup(),
                    hasPreexistingData: AppSetup.hasPreexistingDatabaseFile
                )
                
                do {
                    let keychainManager = KeychainManager(
                        remoteSecretManager: setupApp
                            .setupEmptyRemoteSecretManager()
                    )
                    if let license = try keychainManager.loadLicense() {
                        LicenseStore.shared().licenseUsername = license.user
                        LicenseStore.shared().licensePassword = license.password
                        if let deviceID = license.deviceID {
                            LicenseStore.shared().licenseDeviceID = deviceID
                        }
                        LicenseStore.shared().onPremConfigURL = license.onPremServer
                    }
                }
                catch {
                    DDLogError("Load license from keychain failed: \(error)")
                }
            }
            
            presentKeyGenerationOrProtectedDataUnavailable()
        }
        
        window.makeKeyAndVisible()
        return true
    }

    // MARK: UI stuff

    func presentSpinner<T>(
        label: String,
        while action: () throws -> T
    ) async throws -> T {
        let progressHUD = MBProgressHUD(view: window)
        progressHUD.label.numberOfLines = 0
        progressHUD.label.text = String(format: label, TargetManager.appName)
        progressHUD.mode = .indeterminate

        window.addSubview(progressHUD)
        progressHUD.show(animated: true)

        UIApplication.shared.isIdleTimerDisabled = true

        try await Task.sleep(seconds: 0.3)

        let result = try action()

        progressHUD.hide(animated: true)
        progressHUD.removeFromSuperview()

        applicationDidBecomeActive(UIApplication.shared)
        UIApplication.shared.isIdleTimerDisabled = false
        
        return result
    }

    func presentKeyGenerationOrProtectedDataUnavailable() {
        if KeychainManager.isKeychainLocked {
            presentProtectedDataUnavailable()
        }
        else {
            presentKeyGeneration()
        }
    }

    @objc func presentProtectedDataUnavailable() {
        window.rootViewController?.dismiss(animated: false)
        let unavailableVC = UIHostingController(rootView: ProtectedDataUnavailableView())
        window.rootViewController = unavailableVC
    }

    func presentKeyGeneration() {
        window.rootViewController?.dismiss(animated: false)

        let storyboard = UIStoryboard(name: "CreateID", bundle: Bundle.main)
        let createIDVC = storyboard.instantiateInitialViewController()

        window.rootViewController = createIDVC
    }

    // MARK: - Misc

    private func registerMemoryWarningNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: UIApplication.shared,
            queue: nil
        ) { _ in
            DDLogWarn("Received Memory Warning")
        }
    }

    // MARK: - Tasking
   
    // Note:
    // We do need to postpone some of the work on cold start due to the business no being ready.
   
    @objc func runWhenBusinessReady(task: @escaping () -> Void) {
        
        if isBusinessInjectorReady {
            task()
        }
        else {
            launchTaskManager.add(task)
        }
    }
    
    // MARK: Calls
    
    @objc func handlePush(payload: PKPushPayload, completion: @escaping () -> Void) {
        // Since we only receive VoIP pushes in here, we are sure its a call.
        // The delegate method requires us to report a call all the time.
        
        guard let dictionaryPayload = payload.dictionaryPayload as? [String: String],
              let identity = dictionaryPayload[Constants.notificationExtensionOffer],
              let displayName = dictionaryPayload[Constants.notificationExtensionCallerName],
              let ringtoneSound = dictionaryPayload[Constants.notificationExtensionRingtoneSoundName],
              let callIDString = dictionaryPayload[Constants.notificationExtensionCallID],
              let callIDRawValue = UInt32(callIDString)
        else {
            VoIPCallStateManager.shared.startAndCancelCall(
                from: TargetManager.appName,
                completion: completion
            )
            return
        }
        
        // Report initial call. We up date it once business is ready.
        let callID = VoIPCallID(callID: callIDRawValue)
        DDLogNotice("VoipCallService: [cid=\(callID.callID)]: Call reported from push kit notification. Reporting call")

        VoIPCallStateManager.shared.newIncomingCallFromBackground(
            with: callID,
            callPartnerIdentity: identity,
            callPartnerName: displayName,
            ringtoneSound: ringtoneSound
        ) { task in
            self.runWhenBusinessReady(task: task)
            completion()
        }
    }
    
    // MARK: Intents

    @objc func continueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        
        var task: (() -> Void)?
        
        if let messageIntent = userActivity.interaction?.intent as? INSendMessageIntent {
            task = handleIntent(messageIntent)
        }
        else if let callIntent = userActivity.interaction?.intent as? INStartAudioCallIntent {
            task = handleIntent(callIntent)
        }
        else if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            guard let url = userActivity.webpageURL else {
                return false
            }
            
            task = {
                URLHandler.handle(url)
            }
        }
        
        guard let task else {
            return false
        }
        
        runWhenBusinessReady(task: task)
        return true
    }
    
    private func handleIntent(_ intent: INSendMessageIntent) -> (() -> Void)? {
        var task: (() -> Void)?

        // Conversation
        if let selectedIdentity = intent.conversationIdentifier as String? {
            task = {
                Task { @MainActor in
                    if let managedObject = BusinessInjector.ui.entityManager.entityFetcher
                        .existingObject(with: selectedIdentity) {
                        // Contact
                        if let contact = managedObject as? ContactEntity,
                           let conversation = BusinessInjector.ui.entityManager.entityFetcher
                           .conversationEntity(for: contact.identity) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                                object: nil,
                                userInfo: [
                                    kKeyConversation: conversation,
                                    kKeyForceCompose: true,
                                ]
                            )
                        }
                        // Group
                        else if let group = managedObject as? ConversationEntity {
                            NotificationCenter.default.post(
                                name: NSNotification.Name(rawValue: kNotificationShowConversation),
                                object: nil,
                                userInfo: [
                                    kKeyConversation: group,
                                    kKeyForceCompose: true,
                                ]
                            )
                        }
                    }
                }
            }
        }
        
        // Contact
        if let recipient = intent.recipients?.first as? INPerson,
           let identity = recipient.personHandle?.value,
           identity.count == kIdentityLen {
            task = {
                Task { @MainActor in
                    guard let singleConversation = BusinessInjector.ui.entityManager.entityFetcher
                        .conversationEntity(for: identity) else {
                        return
                    }
                    NotificationCenter.default.post(
                        name: NSNotification.Name(rawValue: kNotificationShowConversation),
                        object: nil,
                        userInfo: [
                            kKeyConversation: singleConversation,
                            kKeyForceCompose: true,
                        ]
                    )
                }
            }
        }
        
        return task
    }
    
    private func handleIntent(_ intent: INStartAudioCallIntent) -> (() -> Void)? {
        guard let personHandle = intent.contacts?.first?.personHandle?.value else {
            return nil
        }
        
        return {
            Task { @MainActor in
                let em = BusinessInjector.ui.entityManager
                let contact = em.performAndWait {
                    em.entityFetcher.contactEntity(for: personHandle)
                }
                
                guard let contact else {
                    return
                }
                guard FeatureMask.check(contact: Contact(contactEntity: contact), for: .o2OAudioCallSupport) else {
                    guard let vc = self.window.rootViewController else {
                        return
                    }
                    UIAlertTemplate.showAlert(
                        owner: vc,
                        title: #localize("call_voip_not_supported_title"),
                        message: #localize("call_voip_not_supported_text")
                    )
                    return
                }
                
                VoIPCallStateManager.shared.startCall(callee: personHandle)
            }
        }
    }

    // MARK: Notification Center
    
    @objc func willPresent(
        _ notification: UNNotification,
        completion: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        
        let task: () -> Void = {
            Task { @MainActor in
                if !self.active {
                    DDLogNotice("[Push] willPresentNotification: Start NotificationExtension for received push")
                    // Do not handle notifications if the app is not active -> Show notification in iOS, not in the app
                    completion([.list, .banner, .badge, .sound])
                }
                else {
                    DDLogNotice("[Push] willPresentNotification: Handle notification for received push")
                    
                    NotificationManager().handleThreemaNotification(
                        payload: notification.request.content.userInfo,
                        receivedWhileRunning: true,
                        notification: notification,
                        withCompletionHandler: completion
                    )
                }
            }
        }
        
        runWhenBusinessReady(task: task)
    }
    
    @objc func didReceiveNotificationResponse(response: UNNotificationResponse, completion: @escaping () -> Void) {
        
        let task: () -> Void = {
            Task { @MainActor in
                let response = NotificationResponse(response: response, completion: completion)
                response.handleNotificationResponse()
            }
        }
        
        runWhenBusinessReady(task: task)
    }
    
    @objc func openSettingsNotification() {
        let task: () -> Void = {
            Task { @MainActor in
                guard let mainTabBar = AppDelegate.getMainTabBarController() as? MainTabBarController else {
                    return
                }
                UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: false)
                mainTabBar.showNotificationSettings()
            }
        }
        
        runWhenBusinessReady(task: task)
    }
    
    // MARK: URL & shortcut handling
    
    @objc func open(_ url: URL) -> Bool {
        // We can handle license urls before the business is ready
        guard !(url.host(percentEncoded: true) == "license") else {
            URLHandler.handleLicense(url)
            return true
        }
        
        let task: () -> Void = {
            Task { @MainActor in
                if self.isAppLocked {
                    // swiftformat:disable:next all
                    self.pendingUrl = url
                    return
                }
                
                URLHandler.handle(url)
            }
        }
        
        runWhenBusinessReady(task: task)
        
        return true
    }
    
    @objc func performAction(for shortcutItem: UIApplicationShortcutItem, completion: @escaping (Bool) -> Void) {
        
        let task: () -> Void = {
            Task { @MainActor in
                if self.isAppLocked {
                    self.pendingShortCutItem = shortcutItem
                    completion(true)
                    return
                }
                completion(URLHandler.handleShortCut(shortcutItem))
            }
        }
        
        runWhenBusinessReady(task: task)
    }
    
    private func deleteLocalDataWithoutRemoteSecretManager() {
        // Since we have no remote secret manager at this point, we delete the most important data. The rest is
        // encrypted anyways.
        try? KeychainManager.deleteAllItems()
        FileUtility.shared.removeItemsInAllDirectories(appGroupID: AppGroup.groupID())
        UserDefaults.resetStandardUserDefaults()
        AppGroup.resetUserDefaults()
        KKPasscodeLock.shared().disablePasscode()
       
        exit(0)
    }
}
