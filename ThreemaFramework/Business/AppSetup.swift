import CocoaLumberjackSwift
import FileUtility
import Foundation
import Keychain

public final class AppSetup: NSObject {
    
    // MARK: - Public
    
    /// Current `AppSetupState`. If is is not set before it is created with the correct state
    ///
    /// `.complete` should only be set as the last step of the setup!
    @objc public static var state: AppSetupState {
        get {
            resolveState().state
        }
        set {
            DDLogNotice("Update app setup state: old=\(state) new=\(newValue)")
            
            if !(state.rawValue <= newValue.rawValue || newValue == .notSetup) {
                // TODO: (IOS-4531) There might be an illegal transition if `th_safe_restore_enable` is enabled
                DDLogWarn("Illegal app setup state transition")
                assertionFailure(
                    "Illegal app setup state transition.\n"
                        + "Update app setup state: old=\(state) new=\(newValue)."
                )
            }
            
            if newValue == .complete {
                FileUtility.shared.deleteIfExists(at: AppSetup.noPreexistingDatabaseFile)
            }
            
            AppGroup.userDefaults().set(newValue.rawValue, forKey: Constants.appSetupStateKey)
        }
    }
    
    /// Is the application setup fully completed?
    ///
    /// - Important: This collapses "not completed" and "cannot be determined right now" into `false`. Callers
    ///              that react to `false` by sending the user down an irreversible path (onboarding) or by
    ///              deleting keychain material must consult ``resolveState()`` first.
    @objc public static var isCompleted: Bool {
        hasPreexistingDatabaseFile && state == .complete
    }

    /// Why the setup state could not be resolved authoritatively.
    public enum StateUnavailableReason: Equatable, CustomStringConvertible {
        case protectedDataUnavailable
        case keychainUnreadable

        // MARK: CustomStringConvertible

        public var description: String {
            switch self {
            case .protectedDataUnavailable:
                "protectedDataUnavailable"
            case .keychainUnreadable:
                "keychainUnreadable"
            }
        }
    }

    /// Current `AppSetupState` plus the reason it could not be determined, if any.
    ///
    /// Use this instead of ``state`` wherever a wrong answer is not recoverable: `state` alone cannot tell a
    /// genuine `.notSetup` apart from a `.notSetup` that only means "the keychain would not answer right now".
    public static func resolveState() -> (state: AppSetupState, unavailable: StateUnavailableReason?) {
        currentStateAndSetupIfNeeded()
    }

    // MARK: - Internal
    
    /// Should we skip the animation and directly show the setup wizard for with the existing identity?
    @objc public static var shouldDirectlyShowSetupWizard: Bool {
        // For the second one we might be able to skip to the last screen, but there is no time to really test this
        state == .identityAdded || state == .identitySetupComplete
    }

    // Is the identity added, but the setup not completed?
    static var isIdentityAdded: Bool {
        state == .identityAdded || AppSetup.isIdentityProvisioned
    }

    /// Is the identity provisioned, but maybe the setup not completed?
    @objc static var isIdentityProvisioned: Bool {
        state == .identitySetupComplete || state == .complete
    }

    // MARK: - Preexisting database file
    
    /// This file is created during a call to `registerIfADatabaseFileExists()` and only deleted if `state` is set to
    /// `.complete`
    private static let noPreexistingDatabaseFile: URL? = FileUtility.shared
        .appDataDirectory(appGroupID: AppGroup.groupID())?.appendingPathComponent(
            "APP_SETUP_NOT_COMPLETED" // Named like this for backwards compatibility
        )
    
    /// Create a marker if no database file exist when this is called. The marker can only be removed by completing the
    /// setup with setting`state` to `.complete`
    public static func registerIfADatabaseFileExists() {
        if !FileUtility.shared.fileExists(at: noPreexistingDatabaseFile),
           !DatabaseManager.dbExists(appGroupID: AppGroup.groupID(), fileUtility: FileUtility.shared) {
            FileUtility.shared.write(
                contents: nil,
                to: noPreexistingDatabaseFile
            )
        }
    }
    
    /// Did a database exist when the app was launched for the first time (& `registerIfADatabaseFileExists()` called)
    /// and no setup was completed in the meantime?
    @objc public static var hasPreexistingDatabaseFile: Bool {
        if ProcessInfoHelper.isRunningForScreenshots {
            // We create DB for screenshots. Return true to skip wizard
            return true
        }
        
        return !FileUtility.shared.fileExists(at: AppSetup.noPreexistingDatabaseFile)
    }
    
    // MARK: - Private helper
    
    private static func currentStateAndSetupIfNeeded() -> (state: AppSetupState, unavailable: StateUnavailableReason?) {

        // This will return 0 if it was not stored before
        let currentValue = AppGroup.userDefaults().integer(forKey: Constants.appSetupStateKey)

        // In general we should have a valid state and not fall back to the recompute below
        if let currentState = AppSetupState(rawValue: currentValue) {
            // This should be safe, because the setting is reset in `MyIdentityStore` if there is no identity during
            // setup.
            return (currentState, nil)
        }

        // The state key is absent: either this is a first launch, or `removeIdentityUserDefaults()` cleared it
        // during restore detection. Recompute the state. Two hazards to guard against:
        //
        // 1. The app-group UserDefaults that backs the state key lives in a data-protected container. When the
        //    app runs in the background while the device is locked (e.g. an "open to fetch" push before the first
        //    unlock), every key reads as 0, so the state looks "absent" even though it is really `.complete`.
        //    Persisting a recomputed `.notSetup` then would clobber the real value permanently. The
        //    `protectedDataAvailable` guard blocks any persist while we can't trust our own storage.
        // 2. Whether an identity exists must come from an authoritative source. The in-memory `MyIdentityStore`
        //    is unreliable in both directions (unloaded this early in launch, stale-populated right after an
        //    erase), so `identityPresence()` reads the keychain instead.
        let recomputed = recomputeState(
            identityPresence: identityPresence(),
            hasPreexistingDatabaseFile: hasPreexistingDatabaseFile,
            protectedDataAvailable: !KeychainManager.isKeychainLocked
        )

        guard let unavailable = recomputed.unavailable else {
            persist(recomputed.state)
            return (recomputed.state, nil)
        }

        DDLogWarn(
            "App setup state not persisted (\(unavailable)); returning \(recomputed.state) transiently"
        )

        return (recomputed.state, unavailable)
    }

    /// Whether an identity exists, from an authoritative source.
    enum IdentityPresence {
        /// An identity is present.
        case present
        /// No identity exists (the keychain is readable and holds no identity).
        case absent
        /// Presence can't be determined right now (keychain locked / read error). Must not be persisted.
        case undetermined
    }

    /// The outcome of recomputing the setup state when the persisted key is absent.
    struct RecomputedState {
        let state: AppSetupState
        let unavailable: StateUnavailableReason?

        /// Whether it is safe to persist `state`. `false` whenever the state could not be determined:
        /// a transiently unreadable keychain must never permanently record `.notSetup`.
        var shouldPersist: Bool {
            unavailable == nil
        }
    }

    /// Pure decision for recomputing an absent setup state.
    ///
    /// - `protectedDataAvailable == false` → `.notSetup`, but NOT persisted: the device is locked, the state
    ///   key read as "absent" only because the app-group container is unreadable, and a write could clobber
    ///   the real value. The state self-heals on the next read once protected data is available. This guard
    ///   also means a genuine reset can never be undone: an erase writes `.notSetup` while the user is present
    ///   (unlocked), and this path never persists while locked.
    /// - `.present` with a preexisting database → `.complete`; the identity lingering in the keychain without a
    ///   database (app deleted and reinstalled) is not a completed setup, so → `.notSetup`.
    /// - `.absent` → `.notSetup` (fresh install or a completed erase, where the keychain identity is gone).
    /// - `.undetermined` → `.notSetup`, but NOT persisted, so a transient keychain read failure self-heals on
    ///   the next read instead of permanently forcing onboarding.
    ///
    /// Both non-persisting outcomes carry a ``StateUnavailableReason``. Not persisting only protects the stored
    /// value; it does not protect the user, who would still be sent into onboarding by a `.notSetup` read. The
    /// reason is therefore surfaced through ``resolveState()`` so the launch sequence can show a retryable
    /// screen instead of an irreversible path.
    static func recomputeState(
        identityPresence: IdentityPresence,
        hasPreexistingDatabaseFile: Bool,
        protectedDataAvailable: Bool
    ) -> RecomputedState {
        guard protectedDataAvailable else {
            return RecomputedState(state: .notSetup, unavailable: .protectedDataUnavailable)
        }

        return switch identityPresence {
        case .present:
            RecomputedState(state: hasPreexistingDatabaseFile ? .complete : .notSetup, unavailable: nil)
        case .absent:
            RecomputedState(state: .notSetup, unavailable: nil)
        case .undetermined:
            RecomputedState(state: .notSetup, unavailable: .keychainUnreadable)
        }
    }

    private static func identityPresence() -> IdentityPresence {
        do {
            return try KeychainManager.loadThreemaIdentity() != nil ? .present : .absent
        }
        catch {
            DDLogWarn("Could not read identity from keychain to determine app setup state: \(error)")
            return .undetermined
        }
    }

    private static func persist(_ state: AppSetupState) {
        DDLogNotice("Reset app setup state to \(state)")
        AppGroup.userDefaults().set(state.rawValue, forKey: Constants.appSetupStateKey)
    }
}
