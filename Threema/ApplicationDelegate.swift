import CocoaLumberjackSwift
import PushKit
import ThreemaFramework
import UIKit
import UserNotifications

/// Modern application delegate for the scene-based lifecycle
///
/// Besides the app specific state & helpers at the beginning and at the end this class follows the same order &
/// sections as the [`UIApplicationDelegate` documentation]
/// (https://developer.apple.com/documentation/uikit/uiapplicationdelegate). Not used delegate methods are
/// in the code, but commented out if they might eventually become relevant to us. This allows us to have the full
/// knowledge in one place. The documentation comments are in parts the relevant parts of the official documentation.
@MainActor
final class ApplicationDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - App specific state

    /// Proxy created as the `UNUserNotificationCenter` and `PKPushRegistry` delegate at
    /// `ApplicationDelegate` instantiation time, i.e. before `didFinishLaunchingWithOptions` is
    /// invoked. Satisfies Apple's contract that the notification delegate exist at launch. The
    /// launch sequence later calls ``NotificationDelegateProxy/attach(_:)`` once the real
    /// ``NotificationHandler`` is constructed.
    let notificationDelegateProxy: NotificationDelegateProxy = {
        let pushRegistry = PKPushRegistry(queue: .main)
        let proxy = NotificationDelegateProxy(pushRegistry: pushRegistry)
        UNUserNotificationCenter.current().delegate = proxy
        pushRegistry.delegate = proxy
        pushRegistry.desiredPushTypes = [.voIP]
        return proxy
    }()
    
    private lazy var appLaunchManager: AppLaunchManagerProtocol = AppLaunchManagerAdapter()
    
    // MARK: - Lifecycle
    
    override init() {
        super.init()
        
        appLaunchManager.runSetupForApplicationDelegateInitialization()
    }
    
    // MARK: - Initializing the app
    
    /// UIKit calls these methods at the beginning of your app’s launch cycle. Use them to:
    /// - Initialize data structures that your app uses across scenes
    /// - Verify that your app has the resources it needs to run
    /// - Perform any one-time setup when your app launches for the first time. For example, install templates or
    ///   user-modifiable files in a writable directory
    /// - Connect to any critical services that your app uses. For example, connect to the Apple Push Notification
    ///   service if your app supports [...] notifications
    /// - For the scene-based lifecycle the `launchOptions` are empty
    ///
    /// <https://developer.apple.com/documentation/uikit/responding-to-the-launch-of-your-app#Initialize-your-apps-data-structures>

    /// Tells the delegate that the launch process has begun
    ///
    /// - When the system calls this method, your app is in the **inactive** state
    /// - In a scene-based lifecycle most of it's responsibility moved into the scene delegate
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:willfinishlaunchingwithoptions:)>
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DDLogNotice(#function)
        
        return true
    }

    /// Tells the delegate that the launch process is almost done and the app is almost ready to run
    ///
    /// - The system calls this method as soon as the process is done launching
    /// - The system then creates the scene(s) that you configured for your app
    /// - The system calls scene life-cycle methods, such as `scene(_:willConnectTo:options:)`
    /// - As the system presents a scene, it updates that scene’s `activationState`. The app’s state
    ///   [(`UIApplication.applicationState`)] is the aggregate of all the scene `UIScene.ActivationState` values
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didfinishlaunchingwithoptions:)>
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        DDLogNotice(#function)

        appLaunchManager.runSetupForApplicationDidFinishLaunchingWithOptions()

        return true
    }

    // MARK: - Configuring and discarding scenes

    /// Retrieves the configuration data for UIKit to use when creating a new scene
    ///
    /// - Returns: The configuration object containing the information needed to create the scene
    /// - Implement this method if you don’t include scene-configuration data in your app’s `Info.plist` file, or if you
    ///   want to alter the scene configuration data dynamically. UIKit calls this method shortly before creating a new
    ///   scene
    /// - If you don’t implement this method, you must provide scene-configuration data in your app’s `Info.plist` file
    /// - This might not be called on each launch because a scene-configuration might be "cached" & "restored" (this
    ///   seems to be independent to restoring a scene's content): https://stackoverflow.com/a/64457054
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:configurationforconnecting:options:)>
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        DDLogNotice(#function)

        let configuration = UISceneConfiguration(
            name: "Programmatically Created Scene",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        
        return configuration
    }

    /// Tells the delegate that the user closed one or more of the app’s scenes from the app switcher
    ///
    /// - When the user removes a scene from the app switcher, UIKit calls this method
    /// - UIKit also calls this method to discard scenes that it can no longer display
    /// - If your app isn’t running, UIKit calls this method the _next time your app launches_ [shortly after
    ///   `application(_:didFinishLaunchingWithOptions:)`]
    /// - Use this method to update your app’s data structures and to release any resources associated with the scene
    /// - UIKit calls this method only when dismissing scenes permanently. It doesn’t call it when the system
    ///   disconnects a scene to free up memory. Memory reclamation deletes the scene objects, but preserves the
    ///   sessions associated with those scenes
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:diddiscardscenesessions:)>
    // Currently not needed as we don't store anything that is just related to one specific scene
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        DDLogNotice(#function)
//    }
    
    // MARK: - Responding to app life-cycle events
    
    // Note: All other methods are not called with a scene delegate. However, the notifications are still posted
    
    /// Tells the delegate when the app is about to terminate
    ///
    /// - This method lets your app know that it is about to be terminated and purged from memory entirely
    /// - [Run] any final clean-up tasks for your app, such as freeing shared resources, saving user data, and
    ///   invalidating timers
    /// - [You have] approximately **five** seconds to perform any tasks
    /// - This method is generally not called when the user quits the app because the app simply moves to the background
    ///   in that case. However, this method may be called in situations where the app is running in the **background**
    ///   (not suspended) and the system needs to **terminate** it for some reason
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/applicationwillterminate(_:)>
    func applicationWillTerminate(_ application: UIApplication) {
        DDLogNotice(#function)
        
        AppGroup.setMeInactive()

        LogManager.flushLogs()

        // TODO: (IOS-6088) Cleanup memory
    }
    
    // MARK: - Responding to environment changes
        
    /// Tells the delegate that protected files are available now
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        DDLogNotice(#function)

        // A cold launch while the device was locked (e.g. for a background task)
        // dead-ends in `.protectedDataUnavailable` — continue it now that the
        // keychain is accessible.
        SceneDelegate.current?.rootCoordinator?.retryLaunchIfProtectedDataBecameAvailable()
    }
    
    /// Tells the delegate that the protected files are about to become unavailable
    ///
    /// - If your app is currently accessing a protected file, you can use this method to release any references to that
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) {
        DDLogNotice(#function)
        // TODO: (IOS-6088) Cleanup memory; otherwise probably not relevant (anymore) as all files are accessible after the first unlock
    }
    
    /// Tells the delegate when the app receives a memory warning from the system
    ///
    /// - It is strongly recommended that you implement this method. If your app does not release enough memory during
    ///   low-memory conditions, the system may terminate it outright
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        DDLogWarn(#function)
    }
    
    /// Tells the delegate when there is a significant change in the time
    ///
    /// - Examples of significant time changes include the arrival of midnight, an update of the time by a carrier, and
    ///   the change to daylight savings time
    func applicationSignificantTimeChange(_ application: UIApplication) {
        DDLogNotice(#function)
    }
    
    // MARK: - Managing app state restoration
    
    // This methods might become relevant if we add state restoration
    
    /// Asks the delegate whether to securely preserve the app’s state
    ///
    /// - Apps must implement both this method and [the next one] for state preservation to occur
    /// - This method supersedes `application(_:shouldSaveApplicationState:)`
//    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
//        DDLogNotice(#function)
//        return false
//    }
    
    /// Asks the delegate whether to restore the app’s saved state
    ///
    /// - This method supersedes `application(_:shouldRestoreApplicationState:)`
//    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
//        DDLogNotice(#function)
//        // Doesn't seem to be called if no state is saved
//        return false
//    }
    
    /// Asks the delegate to provide the specified view controller
//    func application(
//        _ application: UIApplication,
//        viewControllerWithRestorationIdentifierPath identifierComponents: [String],
//        coder: NSCoder
//    ) -> UIViewController? {
//        DDLogNotice(#function)
//        return nil
//    }
    
    /// Tells your delegate to save any high-level state information at the beginning of the state preservation process
//    func application(_ application: UIApplication, willEncodeRestorableStateWith coder: NSCoder) {
//        DDLogNotice(#function)
//    }
    
    /// Tells your delegate to restore any high-level state information as part of the state restoration process
//    func application(_ application: UIApplication, didDecodeRestorableStateWith coder: NSCoder) {
//        DDLogNotice(#function)
//    }
    
    // MARK: - Downloading data in the background
    
    /// Tells the delegate that events related to a URL session are waiting to be processed
    ///
    /// - `identifier`: If your app was just launched, you can use this identifier to create a new `URLSession` object
    ///   that can receive the events
    /// - The app also calls this method if authentication is required for one or more transfers
    /// - There also exists an async version of this
    /// - For more details see the [documentation](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:handleeventsforbackgroundurlsession:completionhandler:))
//    func application(
//        _ application: UIApplication,
//        handleEventsForBackgroundURLSession identifier: String,
//        completionHandler: @escaping () -> Void
//    ) {
//        DDLogNotice("\(#function): \(identifier)")
//        completionHandler()
//    }
    
    // MARK: - Handling remote notification registration
    
    /// Tells the delegate that the app successfully registered with Apple Push Notification service (APNs)
    ///
    /// - APNs device tokens are of variable length. Do not hard-code their size
    /// - Never cache the device token locally on the user’s device
    ///
    /// <https://developer.apple.com/documentation/uikit/uiapplicationdelegate/application(_:didregisterforremotenotificationswithdevicetoken:)>
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        AppGroup.setMeActiveUnlessIPC()

        ServerConnector.shared().setPushToken(deviceToken)
    }

    /// Tells the delegate when Apple Push Notification service cannot successfully complete the registration process
    ///
    /// - The app can choose to display [the error] information to the user
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        DDLogError("APNS registration failed: \(error)")
    }
    
    // Omitted `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`, because we implement a
    // `UNUserNotificationCenterDelegate`
    
    // MARK: - More methods
    
    // "Interacting with WatchKit", "Interacting with HealthKit", "Disallowing specified app extension types",
    // "Handling SiriKit intents", "Localizing keyboard shortcuts" and "Managing interface geometry" skipped
}

// MARK: - App specific helpers

extension ApplicationDelegate {
    static var delegate: ApplicationDelegate? {
        UIApplication.shared.delegate as? ApplicationDelegate
    }
}
