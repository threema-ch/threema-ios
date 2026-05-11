import FileUtility
import RemoteSecretProtocol

/// Centralized access point for the current `RemoteSecretManagerProtocol`.
///
/// This exists to bridge the gap between:
/// - The **legacy flow**, which sets `RemoteSecretProvider.shared.current` (a global static)
/// - The **new coordinator flow**, which creates and injects RS through `AppDependencyContainer`
///
/// Components that previously read `AppLaunchManager.remoteSecretManager` should migrate to
/// `RemoteSecretProvider.remoteSecretManager` as an intermediate step in the future. The final step is full
/// constructor injection — receive RS via your initializer, not from any global/provider.
public final class RemoteSecretProvider: Sendable {

    fileprivate static let shared = RemoteSecretProvider()

    /// Backing storage. `nonisolated(unsafe)` because it's set exactly once during
    /// app launch (before any concurrent access) and never mutated again.
    private nonisolated(unsafe) var _remoteSecretManager: (any RemoteSecretManagerProtocol)?

    private init() { }

    // TODO: (IOS-5387) Replace this by exposing `PersistenceManager` in `BusinessInjector` and remove this
    /// The current `RemoteSecretManagerProtocol`.
    ///
    /// - In the **new coordinator flow**: set by `AppLaunchSequenceManager` / `OnboardingCoordinator`
    ///   after RS is resolved.
    /// - In the **legacy flow**: set by `RemoteSecretProvider.set` (via the bridge).
    ///
    /// - Precondition: Must be set before any component accesses it. Accessing before
    ///   initialization is a programming error (force-unwrap crash, same as the old global).
    private var remoteSecretManager: any RemoteSecretManagerProtocol {
        guard let remoteSecretManager = _remoteSecretManager else {
            fatalError(
                "RemoteSecretProvider.remoteSecretManager accessed before initialization. "
                    + "Ensure the launch sequence sets the provider before any component reads it."
            )
        }
        return remoteSecretManager
    }
    
    private var isRemoteSecretManagerSet: Bool {
        _remoteSecretManager != nil
    }

    private var isRemoteSecretEnabled: Bool {
        /// Before we had two ways of accessing `isRemoteSecretEnabled`.
        /// 1) Through the static stored variable `AppLaunchManager.isRemoteSecretEnabled`,
        /// which when accessed, it wouldn't crash in case remote secret was not set;
        /// 2) Through `AppLaunchManager.remoteSecret.isRemoteSecretEnabled`, which
        /// when accessed, would crash in case remote secret was not set.
        /// For the new coordinator flow, we're centering it into the static API
        /// of `RemoteSecretProvider`, meaning it will crash if accessed before it should.
        /// In case this happens, we'll fix the crashes as we go.
        #if SCENE_DELEGATE_ROOT_COORDINATOR_DEVELOPMENT
            remoteSecretManager.isRemoteSecretEnabled
        #else
            _remoteSecretManager?.isRemoteSecretEnabled ?? false
        #endif
    }

    /// Called exactly once during app launch to set the active RS manager.
    /// - Parameter remoteSecretManager: The resolved RS manager for this session.
    private func set(_ remoteSecretManager: any RemoteSecretManagerProtocol) {
        _remoteSecretManager = remoteSecretManager
        
        FileUtility.updateSharedInstance(with: FileUtilityRemoteSecretDecorator(
            wrapped: FileUtility(),
            remoteSecretManager: remoteSecretManager,
            whitelist: Set(RemoteSecretFileEncryptionWhitelist.whiteList)
        ))
    }
}

extension RemoteSecretProvider {
    public static var isRemoteSecretManagerSet: Bool {
        shared.isRemoteSecretManagerSet
    }
    
    public static var isRemoteSecretEnabled: Bool {
        shared.isRemoteSecretEnabled
    }
    
    public static var remoteSecretManager: any RemoteSecretManagerProtocol {
        shared.remoteSecretManager
    }
    
    public static func setRemoteSecretManager(_ remoteSecretManager: any RemoteSecretManagerProtocol) {
        shared.set(remoteSecretManager)
    }
}
