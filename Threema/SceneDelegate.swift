import CocoaLumberjackSwift
import SwiftUI
import ThreemaFramework
import UIKit

/// Methods to respond to life-cycle events and to manage app-specific tasks occurring in a scene
///
/// - Don’t create `UISceneDelegate` objects directly. Instead, specify the name of your custom delegate class as part
///   of the configuration data for your scenes. [...] You can specify this information in your app’s `Info.plist` file,
///   or in the `UISceneConfiguration` object you return from your app delegate’s
///   `application(_:configurationForConnecting:options:)` method
/// - In our current setup we only support one scene/window
///
/// Besides the scene specific state & helpers at the beginning and at the end this class follows the same order &
/// sections as the [`UISceneDelegate` documentation]
/// (https://developer.apple.com/documentation/uikit/uiscenedelegate) followed by the
/// [`UIWindowSceneDelegate` documentation](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate). Not
/// used delegate methods are in the code, but commented out if they might eventually become relevant to us. This allows
/// us to have the full knowledge in one place. The documentation comments are in parts the relevant parts of the
/// official documentation.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private(set) weak static var current: SceneDelegate?

    /// Proxy created at ``SceneDelegate`` instantiation time, before the launch sequence finishes.
    /// Forwards intent/URL/shortcut work to the real ``IntentHandler`` once attached, and queues
    /// calls in receipt order until then.
    let intentHandlerProxy = IntentHandlerProxy()
    
    /// Readable from any thread (see `AppBackgroundState`). Backed by a write-through flag updated on every
    /// foreground/background transition, so it no longer blocks on `DispatchQueue.main.sync` off the main thread.
    static var isAppInBackground: Bool {
        AppBackgroundState.isInBackground
    }
    
    var currentTopViewController: UIViewController? {
        var topViewController = window?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }
    
    var keyWindowCurrentTopViewController: UIViewController? {
        var topViewController = windowScene?.keyWindow?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }
    
    /// The main window associated with the scene (part of `UIWindowSceneDelegate`)
    var window: UIWindow?
    private var windowScene: UIWindowScene?
    private(set) var rootCoordinator: RootCoordinator?
    
    /// Write through, so the state can be read from any thread (see `AppActiveState`)
    var isActive = false {
        didSet {
            AppActiveState.isActive = isActive
        }
    }

    var isAppLocked: Bool = false
    var orientationLock: UIInterfaceOrientationMask = .all

    var isPresentingEnterLicense: Bool {
        window?.rootViewController?.presentedViewController is EnterLicenseViewController
    }

    var isPresentingKeyGeneration: Bool {
        let vc = window?.rootViewController?.presentedViewController
        return vc is SplashViewController
            || vc is RestoreOptionDataViewController
            || vc is RestoreOptionBackupViewController
            || vc is RestoreIdentityViewController
    }
    
    // MARK: - Lifecycle
    
    override init() {
        super.init()
        Self.current = self
    }
    
    // MARK: - UISceneDelegate
    
    // MARK: Connecting and disconnecting the scene

    /// Tells the delegate about the addition of a scene to the app
    ///
    /// - `connectionOptions`: Use the information in this object to handle actions that caused the creation of the
    ///   scene [e.g.] respond to a quick action
    /// - This method is called when your app creates or restores an instance of your user interface
    /// - Use this method [...] to begin loading any data that the scene needs to display
    /// - When your app restores state, the user activity is presented in the `stateRestorationActivity` property of
    ///   `session`
    /// - In addition to calling this method, UIKit also posts a `willConnectNotification` notification
    /// - Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`
    /// - This delegate does not imply the connecting scene or session are new (see
    ///   `application:configurationForConnectingSceneSession` instead)
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:willconnectto:options:)>
    /// <https://developer.apple.com/documentation/uikit/responding-to-the-launch-of-your-app#Determine-why-your-scene-connected?
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        DDLogNotice(#function)

        // UIKit might reconnect a persisted scene session without asking the app delegate for a configuration again
        // (see `configurationForConnecting` above). If the app ran normally before on this device, the persisted
        // configuration names this class, so we end up here even for tests, previews & playgrounds where
        // `TestAplicationDelegate` replaces `ApplicationDelegate` and `AppLaunchManager.preLaunchSetup()` never ran.
        guard !AppLaunchMode.isTestingOrPreviewing else {
            DDLogNotice("Running for tests, previews or playgrounds: skip launch sequence")
            return
        }

        guard let windowScene = scene as? UIWindowScene else {
            DDLogError("Scene is not a UIWindowScene")
            return
        }
        self.windowScene = windowScene
        
        // `ThemedWindow` keeps `Colors.theme` in sync with the system appearance (and posts
        // `kNotificationColorThemeChanged`) when following the system theme. A plain `UIWindow` would leave
        // `Colors.theme` stale on a dark/light switch, so theme-dependent rendering (e.g. verification dots) wouldn't
        // update.
        let window = ThemedWindow(windowScene: windowScene)
        self.window = window
        
        let rootCoordinator = RootCoordinator(
            window: window,
            windowScene: windowScene,
            bootstrap: .live()
        )
        self.rootCoordinator = rootCoordinator
        rootCoordinator.start()

        for userActivity in connectionOptions.userActivities {
            intentHandlerProxy.handle(userActivity: userActivity)
        }
        if let shortcut = connectionOptions.shortcutItem {
            intentHandlerProxy.handle(shortcutItem: shortcut)
        }
        for urlContext in connectionOptions.urlContexts {
            handleOpenURL(urlContext.url)
        }
    }
    
    /// Tells the delegate that UIKit removed a scene from your app
    ///
    /// - Final cleanup before your scene is purged from memory. [e.g.] use it to release references to files or shared
    ///   resources and to save user data
    /// - The removal of a scene is a precursor to the destruction of that scene
    /// - [It] disconnects [...] when the user explicitly closes it in the app switcher
    /// - [It] may also disconnect [...] in order to reclaim memory for other processes
    /// - [It] does **not** automatically disconnect [...] when the user switches to another app
    /// - UIKit also posts a `didDisconnectNotification` notification in addition to calling this method
    /// - Release any resources associated with this scene that can be re-created the next time the scene connects
    /// - The scene may re-connect later, as its session was not necessarily discarded (see
    ///   `application:didDiscardSceneSessions` instead)
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scenediddisconnect(_:)>
    func sceneDidDisconnect(_ scene: UIScene) {
        DDLogNotice(#function)
    }
    
    // MARK: Transitioning to the foreground
    
    /// Tells the delegate that the scene is about to begin running in the foreground and become visible to the user
    ///
    /// - This transition occurs both for newly created and connected scenes, as well as for scenes that were running in
    ///   the background and were brought to the foreground by the system or a user action
    /// - A scene enters the foreground as a precursor to becoming visible onscreen, so this method is invariably
    ///   followed by a call to the `sceneDidBecomeActive(_:)` method
    /// - In addition to calling this method, UIKit posts [...] a `willEnterForegroundNotification`
    /// - Use this method to undo the changes made on entering the background
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scenewillenterforeground(_:)>
    func sceneWillEnterForeground(_ scene: UIScene) {
        DDLogNotice(#function)
        
        AppBackgroundState.isInBackground = false
        rootCoordinator?.sceneWillEnterForeground()
    }
    
    /// Tells the delegate that the scene became active and is now responding to user events
    ///
    /// - UIKit calls this method after loading the interface for your scene, but before that interface appears onscreen
    /// - In addition to calling this method, UIKit posts a `didActivateNotification` and a
    ///   `didBecomeActiveNotification`
    ///
    /// Activation is a good time to configure your app’s UI and runtime behavior:
    /// - Show your app’s windows
    /// - Update the data values and state of views and controls
    /// - Start or resume any dispatch queues that you use to execute tasks
    /// - Update data source objects
    /// - Start timers for periodic tasks
    ///
    /// - Don’t run any code that might block your activation method
    /// - Be prepared to display existing data while you fetch changes asynchronously
    /// - Use your view controller’s `viewWillAppear(_:)` method to perform any final updates to your interface.
    ///
    /// - Inactive -> active
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scenedidbecomeactive(_:)>
    /// <https://developer.apple.com/documentation/uikit/preparing-your-ui-to-run-in-the-foreground>
    func sceneDidBecomeActive(_ scene: UIScene) {
        DDLogNotice(#function)
        
        isActive = true
        rootCoordinator?.hidePrivacyOverlay()
        AppBackgroundState.isInBackground = false
        rootCoordinator?.sceneDidBecomeActive()
    }
    
    // MARK: Transitioning to the background

    /// Tells the delegate that the scene is about to resign the active state and stop responding to user events
    ///
    /// - UIKit calls this method for temporary interruptions, such as when displaying system alerts. It also calls the
    ///   method before transitioning your app to the background state
    /// - By the time this method returns, your app should be doing minimal work while it waits to transition to the
    ///   background or to the foreground again
    /// - Save [...] data in this method to ensure that it isn’t lost. However, never save data solely from this method.
    ///   Instead, save it at appropriate points from your view controllers, usually in response to user actions. For
    ///   example, save data when the user dismisses a data-entry screen. Don’t rely on specific app transitions to save
    ///   all of your app’s critical data
    /// - In addition to calling this method, UIKit posts a `willDeactivateNotification` and a
    ///   `willResignActiveNotification`
    /// - Active -> inactive
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scenewillresignactive(_:)#Discussion>
    func sceneWillResignActive(_ scene: UIScene) {
        DDLogNotice(#function)

        defer {
            isActive = false
        }

        // No launch sequence ran, see `scene(_:willConnectTo:options:)`.
        guard !AppLaunchMode.isTestingOrPreviewing else {
            return
        }

        UIApplication.shared.shortcutItems = UIApplicationShortcutItemProvider.items(
            for: MDMSetup()
        )

        rootCoordinator?.sceneWillResignActive()
    }

    /// Tells the delegate that the scene is running in the background and is no longer onscreen
    ///
    /// - Reduce your scene’s memory usage, free up any shared resources, and clean up your scene’s user interface
    /// - Shortly after this method returns, **UIKit takes a snapshot of your scene’s interface for display in the app
    ///   switcher**. Make sure your interface doesn’t contain sensitive user information
    /// - In addition to calling this method, UIKit posts a `didEnterBackgroundNotification` notification from
    ///   `UIApplication` and `UIScene`
    /// - Store enough scene-specific state information to restore the scene back to its current state
    /// - Foreground -> Background
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scenedidenterbackground(_:)>
    func sceneDidEnterBackground(_ scene: UIScene) {
        DDLogNotice(#function)
        
        AppBackgroundState.isInBackground = true
        rootCoordinator?.sceneDidEnterBackground()
    }

    // MARK: Opening URLs
    
    /// Asks the delegate to open one or more URLs
    ///
    /// - `URLContexts`: One or more `UIOpenURLContext` objects. Each object contains one URL to open and any additional
    ///   information needed to open that URL
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:openurlcontexts:)>
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        DDLogNotice(#function)
        
        for urlContext in URLContexts {
            handleOpenURL(urlContext.url)
        }
    }
    
    // MARK: - Continuing user activities
    
    /// Tells the delegate that it’s about to receive Handoff-related data
    ///
    /// - After this method returns, UIKit provides feedback to the user that your scene is handling the activity
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:willcontinueuseractivitywithtype:)>
//    func scene(
//        _ scene: UIScene,
//        willContinueUserActivityWithType userActivityType: String
//    ) {
//        DDLogNotice(#function)
//    }
    
    /// Tells the delegate to handle the specified Handoff-related activity
    ///
    /// - UIKit calls this method on your app’s main thread only after it receives all of the data for an activity
    ///   object, which might originate from a different device
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:continue:)>
    func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        DDLogNotice(#function)
        
        intentHandlerProxy.handle(userActivity: userActivity)
    }
    
    /// Tells the delegate that the activity couldn’t be continued
    ///
    /// - If you don’t implement this method, UIKit displays an error to the user with an appropriate message about the
    ///   reason for the failure
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:didfailtocontinueuseractivitywithtype:error:)>
//    func scene(_ scene: UIScene, didFailToContinueUserActivityWithType userActivityType: String, error: any Error) {
//        DDLogError("\(#function): error=\(error)")
//    }

    // MARK: Saving the state of the scene
    
    // This methods might become relevant if we add state restoration
    
    /// Returns a user activity object encapsulating the current state of the specified scene
    ///
    /// - Save enough information to be able to restore that state again after UIKit disconnects and then reconnects the
    ///   scene
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/staterestorationactivity(for:)>
//    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
//        DDLogNotice(#function)
//
//        return nil
//    }
    
    // No documentation:
    // https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:restoreinteractionstatewith:)
//    func scene(_ scene: UIScene, restoreInteractionStateWith stateRestorationActivity: NSUserActivity) {
//        DDLogNotice(#function)
//    }
    
    /// Tells the delegate that the specified activity object was updated
    ///
    /// - Add any final data to the specified user activity object
    /// - UIKit calls this method on your app’s main thread after calling your `stateRestorationActivity(for:)` method
    ///   and after giving other parts of your app an opportunity to update the activity object returned by that method
    ///
    /// <https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:didupdate:)>
//    func scene(_ scene: UIScene, didUpdate userActivity: NSUserActivity) {
//        DDLogNotice(#function)
//    }
    
    // MARK: - UIWindowSceneDelegate
    
    // MARK: Managing the scene’s main window
    
    // See `window` above
    
    // MARK: Responding to scene changes
    
    /// Called when the window scene’s effective geometry has changed
    ///
    /// - Always called when a `UIWindowScene` moves between screens
    ///
    /// <https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/windowscene(_:didupdateeffectivegeometry:)>
//    func windowScene(
//        _ windowScene: UIWindowScene,
//        didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry
//    ) {
//        DDLogNotice(#function)
//    }
    
    // MARK: Performing tasks
    
    /// Asks the delegate to perform the user-selected action
    ///
    /// - `completionHandler`: A Boolean value indicating whether you successfully completed the specified action
    /// - This is called when a Home Screen Quick Action is selected and the app is in memory
    /// - There also exists an async version of this
    ///
    /// <https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/windowscene(_:performactionfor:completionhandler:)>
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        DDLogNotice(#function)
        
        let handled = intentHandlerProxy.handle(shortcutItem: shortcutItem)
        completionHandler(handled)
    }
    
    // Omitted `windowScene(_:userDidAcceptCloudKitShareWith:)`, because we don't support CloudKit (also needs CloudKit
    // import)
    
    // MARK: Instance Methods
    
    /// Called by the system to determine the windowing control style for the provided scene
    ///
    /// - `automatic` will be used if this method is not implemented
    ///
    /// <https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/preferredwindowingcontrolstyle(for:)>
    @available(iOS 26, *)
    func preferredWindowingControlStyle(
        for windowScene: UIWindowScene
    ) -> UIWindowScene.WindowingControlStyle {
        DDLogDebug(#function)
        
        return .minimal
    }

    // MARK: - Helpers
    
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        if url.host()?.lowercased() == "license" {
            // License activation links must also work before the app is set up, so they are routed
            // through the `RootCoordinator` instead of the app-only intent handler. It covers every
            // launch state: onboarding, the running app and a launch sequence that is still deciding
            // where to go.
            guard let rootCoordinator else {
                let message = "Received a license activation link without a root coordinator. Dropping the link."
                DDLogError(message)
                assertionFailure(message)
                return true
            }

            rootCoordinator.handleLicenseURL(url)
            return true
        }
        return intentHandlerProxy.handle(openURL: url)
    }
    
    func presentPasscodeView() {
        rootCoordinator?.requestReauthenticationIfNeeded()
    }
    
    func presentIDBackupRestore() {
        let vc = window?.rootViewController?.presentedViewController
        if let splashVC = vc as? SplashViewController {
            splashVC.showRestoreIdentityViewController()
        }
        else if let restoreBackupVC = vc as? RestoreOptionBackupViewController,
                let splashVC = restoreBackupVC.parent as? SplashViewController {
            splashVC.showRestoreIdentityViewController()
        }
        else if let restoreVC = vc as? RestoreIdentityViewController {
            restoreVC.updateTextViewWithBackupCode()
        }
    }
}
