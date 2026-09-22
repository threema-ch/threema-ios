import CocoaLumberjackSwift
import os
import UIKit

/// Centralized accessor for app-level shared state (window, top view controller,
/// tab bar controller, lifecycle flags, etc) owned by the `SceneDelegate` /
/// `RootCoordinator` hierarchy.
@MainActor
enum SharedAppProvider {

    // MARK: - Navigation

    static var tabBarController: UITabBarController? {
        SceneDelegate.current?.rootCoordinator?.tabBarController
    }

    static var currentTopViewController: UIViewController? {
        SceneDelegate.current?.currentTopViewController
    }

    static var window: UIWindow? {
        SceneDelegate.current?.window
    }

    // MARK: - Lifecycle

    /// Readable from any thread
    nonisolated static var isAppActive: Bool {
        AppActiveState.isActive
    }

    static var isAppLocked: Bool {
        SceneDelegate.current?.isAppLocked == true
    }

    // MARK: - Coordinator access

    static var appCoordinator: AppCoordinator? {
        SceneDelegate.current?.rootCoordinator?.appCoordinator
    }

    static func execute(_ closure: (AppCoordinator) -> Void) {
        if let appCoordinator {
            closure(appCoordinator)
        }
        else {
            fatalError("AppCoordinator not found.")
        }
    }

    // MARK: - License

    static var isPresentingEnterLicense: Bool {
        SceneDelegate.current?.isPresentingEnterLicense == true
    }

    static var isPresentingKeyGeneration: Bool {
        SceneDelegate.current?.isPresentingKeyGeneration == true
    }

    static func presentIDBackupRestore() {
        SceneDelegate.current?.presentIDBackupRestore()
    }

    // MARK: - Passcode

    static func presentPasscodeView() {
        SceneDelegate.current?.presentPasscodeView()
    }

    // MARK: - Class-level bridges

    /// Readable from any thread (see `AppBackgroundState`), so it never blocks on the main thread.
    nonisolated static var isAppInBackground: Bool {
        AppBackgroundState.isInBackground
    }

    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    static var alertViewShown: UIAlertController? {
        window?.rootViewController?.presentedViewController as? UIAlertController
    }

    // MARK: - Trait collection

    static var isCompactSizeClass: Bool {
        appCoordinator?.splitViewController.traitCollection.horizontalSizeClass == .compact
    }

    // MARK: - Orientation (per-scene)

    static var orientationLock: UIInterfaceOrientationMask {
        get {
            SceneDelegate.current?.orientationLock ?? .all
        }
        set {
            SceneDelegate.current?.orientationLock = newValue
        }
    }
}

// MARK: - AtomicFlag

/// Thread-safe boolean flag, readable and writable from any thread. Backs the app lifecycle flags below so they can be
/// read without hopping to the main thread.
final class AtomicFlag: @unchecked Sendable {

    private let lock: OSAllocatedUnfairLock<Bool>

    init(_ initialValue: Bool) {
        lock = OSAllocatedUnfairLock(initialState: initialValue)
    }

    var value: Bool {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}

// MARK: - AppActiveState

/// Thread-safe storage of `SharedAppProvider.isAppActive`
///
/// `AppDelegate` and `SceneDelegate` write it on every change, so it can be read without hopping to the main thread.
@objc final class AppActiveState: NSObject {

    @objc static var isActive: Bool {
        get { state.value }
        set { state.value = newValue }
    }

    private static let state = AtomicFlag(false)
}

// MARK: - AppBackgroundState

/// Thread-safe storage of `SharedAppProvider.isAppInBackground`
///
/// `AppDelegate` and `SceneDelegate` write it on every foreground/background transition, so it can be read without
/// hopping to the main thread. Previously `isAppInBackground` read `UIApplication.applicationState` behind a
/// `DispatchQueue.main.sync`, which deadlocked (app freeze) when read off the main thread from a context the main
/// thread waits on — e.g. from inside a Core Data `performAndWait` block (see `WCSessionManager`). Mirrors
/// `AppActiveState`.
@objc final class AppBackgroundState: NSObject {

    @objc static var isInBackground: Bool {
        get { state.value }
        set { state.value = newValue }
    }

    private static let state = AtomicFlag(false)
}
