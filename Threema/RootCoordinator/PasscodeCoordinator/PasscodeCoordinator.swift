import CocoaLumberjackSwift
import Coordinator
import LocalAuthentication
import ThreemaFramework
import ThreemaMacros
import UIKit

// MARK: - Delegate

@MainActor
protocol PasscodeCoordinatorDelegate: AnyObject {
    func passcodeCoordinatorDidAuthenticate(
        _ coordinator: PasscodeCoordinator,
        appContainer: AppDependencyContainer,
        evaluatedPolicyDomainState: Data?
    )
    func passcodeCoordinatorDidRequestErase(_ coordinator: PasscodeCoordinator)
}

// MARK: - PasscodeCoordinator

/// Authenticate the user (passcode + biometrics) and report success/failure.
/// Privacy overlay is owned by `PrivacyCoordinator`.
@MainActor
final class PasscodeCoordinator: NSObject, Coordinator {

    // MARK: - Coordinator

    var childCoordinators: [any Coordinator] = []
    private(set) lazy var rootViewController: UIViewController = lockScreenViewController

    private lazy var lockScreenViewController: JKLLockScreenViewController = makeLockScreenViewController()

    // MARK: - Dependencies

    private weak var windowScene: UIWindowScene?
    private let appContainer: AppDependencyContainer
    private weak var delegate: PasscodeCoordinatorDelegate?

    private let setAppLocked: (Bool) -> Void
    private let authenticateBiometrics: () async throws -> Bool
    private let appName: String

    // MARK: - State

    /// Captured during a biometrics-changed error so the delegate can persist it to UserSettings.
    private var evaluatedPolicyDomainState: Data?
    private var passcodeWindow: PasscodeWindow?

    private var isAuthenticatingBiometrics = false

    /// `true` once an evaluation reached the system since the scene last left the foreground. Dismissing
    /// the system sheet activates the scene again, so retrying on activation would re-present it.
    private var hasEvaluatedBiometrics = false

    private var requiresPasscode = false

    private var isLocked: Bool {
        passcodeWindow != nil
    }

    /// `evaluatePolicy` only prompts on an active scene. It fails with `LAError.notInteractive`,
    /// `.systemCancel` or `.appCancel` while the scene is merely foreground, which is the state during
    /// `sceneWillEnterForeground` and for foreground transitions that never activate at all.
    private var isSceneActive: Bool {
        windowScene?.activationState == .foregroundActive
    }

    // MARK: - Init

    init(
        windowScene: UIWindowScene,
        appContainer: AppDependencyContainer,
        delegate: PasscodeCoordinatorDelegate,
        setAppLocked: @escaping (Bool) -> Void = { isAppLocked in
            MainActor.assumeIsolated({
                SceneDelegate.current?.isAppLocked = isAppLocked
            })
        },
        authenticateBiometrics: @escaping () async throws -> Bool = {
            try await TouchIDAuthentication.tryBiometricAuthentication()
        },
        appName: String = TargetManager.appName
    ) {
        self.windowScene = windowScene
        self.appContainer = appContainer
        self.delegate = delegate
        self.setAppLocked = setAppLocked
        self.authenticateBiometrics = authenticateBiometrics
        self.appName = appName
    }

    // MARK: - Coordinator lifecycle

    func start() {
        guard appContainer.passcodeLock.isPasscodeRequired() else {
            DDLogWarn("PasscodeCoordinator started but passcode is not required.")
            reportSuccess()
            return
        }
        
        if appContainer.passcodeLock.isWithinGracePeriod() {
            DDLogVerbose("Passcode within grace period — skipping prompt.")
            reportSuccess()
            return
        }

        guard let windowScene else {
            DDLogError("Cannot present the passcode screen: the window scene is gone.")
            return
        }

        for sceneWindow in windowScene.windows {
            sceneWindow.endEditing(true)
        }

        let window = PasscodeWindow(windowScene: windowScene)
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
        passcodeWindow = window
        setAppLocked(true)

        // Defer biometrics so the lock UI is on screen before iOS shows the system sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tryBiometricAuthentication(isUserRequested: false)
        }
    }

    // MARK: - Biometrics

    enum BiometricAttempt: Equatable {
        case evaluating
        case notLocked
        case biometricsDisabled
        case passcodeRequired
        case alreadyAuthenticated
        case alreadyEvaluated
        case sceneInactive
    }

    static func biometricAttempt(
        isLocked: Bool,
        isBiometricAuthenticationEnabled: Bool,
        requiresPasscode: Bool,
        isAuthenticating: Bool,
        hasEvaluatedBiometrics: Bool,
        isSceneActive: Bool,
        isUserRequested: Bool
    ) -> BiometricAttempt {
        guard isLocked else {
            return .notLocked
        }
        guard isBiometricAuthenticationEnabled else {
            return .biometricsDisabled
        }
        guard !requiresPasscode else {
            return .passcodeRequired
        }
        guard !isAuthenticating else {
            return .alreadyAuthenticated
        }
        guard isUserRequested || !hasEvaluatedBiometrics else {
            return .alreadyEvaluated
        }
        guard isSceneActive else {
            return .sceneInactive
        }
        return .evaluating
    }

    /// Call when the scene becomes active. The attempt from `start()` is skipped while the scene is not
    /// active yet, and this is the only thing that prompts afterwards.
    func retryBiometricAuthenticationIfNeeded() {
        tryBiometricAuthentication(isUserRequested: false)
    }

    /// A lock can outlive a foreground trip. Coming back is a new attempt to open the app, so it earns a
    /// fresh evaluation even if the previous one was cancelled. Not after iOS asked for the passcode, see
    /// `requiresPasscode`.
    func sceneDidEnterBackground() {
        hasEvaluatedBiometrics = false
    }

    private func tryBiometricAuthentication(isUserRequested: Bool) {
        let decision = Self.biometricAttempt(
            isLocked: isLocked,
            isBiometricAuthenticationEnabled: appContainer.passcodeLock.isBiometricAuthenticationEnabled(),
            requiresPasscode: requiresPasscode,
            isAuthenticating: isAuthenticatingBiometrics,
            hasEvaluatedBiometrics: hasEvaluatedBiometrics,
            isSceneActive: isSceneActive,
            isUserRequested: isUserRequested
        )

        guard decision == .evaluating else {
            if decision == .sceneInactive {
                DDLogNotice("Skip biometric authentication while the scene is not active. Waiting for activation.")
            }
            return
        }

        isAuthenticatingBiometrics = true
        hasEvaluatedBiometrics = true

        // Captured so nothing holds this coordinator across the suspension: the sheet can be up for
        // seconds, and a scene teardown in the meantime should take the lock screen with it.
        let authenticateBiometrics = authenticateBiometrics

        Task { @MainActor [weak self] in
            defer {
                self?.isAuthenticatingBiometrics = false
            }

            do {
                let ok = try await authenticateBiometrics()
                guard ok else {
                    DDLogNotice("Biometric authentication was not successful. Passcode entry required.")
                    return
                }
                DDLogNotice("Authenticated using biometrics.")
                self?.reportSuccess()
            }
            catch let TouchIDAuthentication.BiometricAuthenticationError.biometricsChanged(newPolicyDomainStateData) {
                DDLogWarn("Biometrics changed. Passcode entry required.")
                self?.handleBiometricsChanged(evaluatePolicyStateData: newPolicyDomainStateData)
            }
            catch {
                DDLogNotice("Biometric authentication failed: \(Self.describe(error))")
                if Self.requiresPasscode(after: error) {
                    self?.handlePasscodeRequired()
                }
            }
        }
    }

    private func handlePasscodeRequired() {
        DDLogNotice("Biometric unlock disabled for this lock. Passcode entry required.")
        requiresPasscode = true
        lockScreenViewController.disableBiometricUnlock()
    }

    private func handleBiometricsChanged(evaluatePolicyStateData: Data?) {
        evaluatedPolicyDomainState = evaluatePolicyStateData

        let context = LAContext()
        let title: String = {
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                return ""
            }
            
            switch context.biometryType {
            case .faceID:
                return #localize("alert_biometrics_changed_title_face")
            case .touchID:
                return #localize("alert_biometrics_changed_title_touch")
            case .none, .opticID:
                return ""
            @unknown default:
                return ""
            }
        }()
        
        let message = String.localizedStringWithFormat(
            #localize("alert_biometrics_changed_message"),
            appName,
            appName
        )

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: #localize("ok"), style: .default))
        rootViewController.present(alert, animated: true)
    }

    // MARK: - Helpers

    /// Whether `error` from `authenticateBiometrics` means the passcode must be entered for this lock.
    static func requiresPasscode(after error: Error) -> Bool {
        TouchIDAuthentication.requiresPasscode(after: unwrap(error))
    }

    /// Domain and code of the underlying `LAError`. That is what tells a cancelled prompt apart from one
    /// that was never shown; `localizedDescription` does not.
    private static func describe(_ error: Error) -> String {
        let nsError = unwrap(error) as NSError
        return "\(nsError.domain) \(nsError.code) (\(nsError.localizedDescription))"
    }

    private static func unwrap(_ error: Error) -> Error {
        if case let TouchIDAuthentication.BiometricAuthenticationError.underlying(wrapped) = error {
            return wrapped
        }
        return error
    }

    private func makeLockScreenViewController() -> JKLLockScreenViewController {
        let vc = JKLLockScreenViewController(
            nibName: NSStringFromClass(JKLLockScreenViewController.self),
            bundle: BundleUtil.frameworkBundle()
        )
        vc.lockScreenMode = .normal
        vc.delegate = self
        return vc
    }

    private func reportSuccess() {
        // Only a lock that was actually shown ends in an unlock worth announcing. `start()` also reports
        // success when no passcode is required or the grace period still holds.
        let wasLocked = passcodeWindow != nil

        passcodeWindow?.isHidden = true
        // Must happen before releasing the window, see `UIWindow.removeSecure()`
        passcodeWindow?.removeSecure()
        passcodeWindow = nil
        setAppLocked(false)
        delegate?.passcodeCoordinatorDidAuthenticate(
            self,
            appContainer: appContainer,
            evaluatedPolicyDomainState: evaluatedPolicyDomainState
        )

        if wasLocked {
            NotificationCenter.default.post(name: .appUnlocked, object: nil)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    /// Posted on the main thread after the passcode lock was released, so anything that has to wait for
    /// an interactive UI can try again. Not an app state change, so `didBecomeActiveNotification` does
    /// not cover it.
    static let appUnlocked = Notification.Name("ThreemaAppUnlocked")
}

// MARK: - PasscodeCoordinator + JKLLockScreenViewControllerDelegate

extension PasscodeCoordinator: JKLLockScreenViewControllerDelegate {

    func didPasscodeEnteredCorrectly(_ viewController: JKLLockScreenViewController) {
        DDLogVerbose("Passcode entered correctly.")
        reportSuccess()
    }

    func didPasscodeViewDismiss(_ viewController: JKLLockScreenViewController) {
        // Intentional no-op. Dismissal only happens after we swap windows.
    }

    func shouldEraseApplicationData(_ viewController: JKLLockScreenViewController) {
        DDLogError("Erase application data requested from passcode screen.")
        delegate?.passcodeCoordinatorDidRequestErase(self)
    }

    func allowTouchIDLockScreenViewController(_ lockScreenViewController: JKLLockScreenViewController) -> Bool {
        appContainer.passcodeLock.isBiometricAuthenticationEnabled()
    }

    func didRequestBiometricAuthentication(_ viewController: JKLLockScreenViewController) {
        DDLogNotice("Biometric authentication requested from passcode screen.")
        tryBiometricAuthentication(isUserRequested: true)
    }
}
