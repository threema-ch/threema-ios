import SwiftUI
import ThreemaFramework
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    private(set) weak static var current: SceneDelegate?
    
    static var isAppInBackground: Bool {
        if Thread.isMainThread {
            UIApplication.shared.applicationState == .background
        }
        else {
            DispatchQueue.main.sync {
                UIApplication.shared.applicationState == .background
            }
        }
    }
    
    var currentTopViewController: UIViewController? {
        var topViewController = window?.rootViewController
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        return topViewController
    }
    
    var window: UIWindow?
    private(set) var rootCoordinator: RootCoordinator?
    
    override init() {
        AppLaunchManager.preLaunchSetup()
        super.init()
        startSentryIfNeeded()
        
        Self.current = self
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene
        // `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see
        // `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
                
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        
        let rootCoordinator = RootCoordinator(
            window: window,
            bootstrap: .live()
        )
        self.rootCoordinator = rootCoordinator
        rootCoordinator.start()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see
        // `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        TypingIndicatorManager.sharedInstance.startObserving()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        TypingIndicatorManager.sharedInstance.stopObserving()
    }
    
    // MARK: - Helpers
    
    private func startSentryIfNeeded() {
        #if !DISABLE_SENTRY
            guard !ProcessInfoHelper.isRunningForScreenshots else {
                return
            }
            let sentry = SentryClient()
            sentry.start()
        #endif
    }
}
