import Testing
@testable import Threema

@MainActor
struct PasscodeCoordinatorBiometricAttemptTests {

    typealias Attempt = PasscodeCoordinator.BiometricAttempt

    // MARK: - The regression

    @Test("A lock presented before the scene is active waits instead of failing an evaluation")
    func waitsWhileSceneIsInactive() {
        #expect(attempt(isSceneActive: false) == .sceneInactive)
    }

    @Test("The same lock evaluates as soon as the scene becomes active")
    func evaluatesOnceSceneIsActive() {
        #expect(attempt(isSceneActive: false) == .sceneInactive)
        #expect(attempt(isSceneActive: true) == .evaluating)
    }

    @Test("A lock on an active scene evaluates right away")
    func evaluatesOnActiveScene() {
        #expect(attempt() == .evaluating)
    }

    // MARK: - No unwanted prompts

    @Test("An activation after the sheet was dismissed does not re-present it")
    func doesNotRepeatAutomatically() {
        #expect(attempt(hasEvaluatedBiometrics: true) == .alreadyEvaluated)
    }

    @Test("A foreground trip earns a fresh evaluation")
    func foregroundTripPromptsAgain() {
        // `PasscodeCoordinator.sceneDidEnterBackground()` clears `hasEvaluatedBiometrics`.
        #expect(attempt(hasEvaluatedBiometrics: false) == .evaluating)
    }

    @Test("A user request is exempt, for lock screens that offer a biometric button")
    func userRequestIsExempt() {
        #expect(attempt(hasEvaluatedBiometrics: true, isUserRequested: true) == .evaluating)
    }

    @Test("Even a user request does not stack a second evaluation on an in-flight one")
    func doesNotStackEvaluations() {
        #expect(attempt(isAuthenticating: true) == .alreadyAuthenticated)
        #expect(attempt(isAuthenticating: true, isUserRequested: true) == .alreadyAuthenticated)
    }

    @Test("A released lock never prompts, however the attempt was triggered")
    func neverPromptsWithoutALock() {
        #expect(attempt(isLocked: false) == .notLocked)
        #expect(attempt(isLocked: false, isUserRequested: true) == .notLocked)
        #expect(attempt(isLocked: false, isSceneActive: false) == .notLocked)
    }

    @Test("Biometrics switched off in settings keeps the keypad as the only way in")
    func respectsBiometricsSetting() {
        #expect(attempt(isBiometricAuthenticationEnabled: false) == .biometricsDisabled)
        #expect(attempt(isBiometricAuthenticationEnabled: false, isUserRequested: true) == .biometricsDisabled)
    }

    // MARK: - Passcode required

    @Test("Once iOS asked for the passcode, the biometric button cannot bring Face ID / Touch ID back")
    func passcodeRequiredBlocksUserRequest() {
        #expect(attempt(requiresPasscode: true, isUserRequested: true) == .passcodeRequired)
        #expect(
            attempt(requiresPasscode: true, hasEvaluatedBiometrics: true, isUserRequested: true) == .passcodeRequired
        )
    }

    @Test("Once iOS asked for the passcode, no automatic attempt prompts either")
    func passcodeRequiredBlocksAutomaticAttempts() {
        #expect(attempt(requiresPasscode: true) == .passcodeRequired)
    }

    @Test("A foreground trip does not lift the passcode requirement")
    func passcodeRequiredSurvivesForegroundTrip() {
        // `PasscodeCoordinator.sceneDidEnterBackground()` clears `hasEvaluatedBiometrics`, but not `requiresPasscode`.
        #expect(attempt(requiresPasscode: true, hasEvaluatedBiometrics: false) == .passcodeRequired)
    }

    // MARK: - Precedence

    @Test("Reasons are reported most specific first")
    func precedence() {
        // Every other input is also in a skipping state, so only the guard order decides the reason.
        #expect(
            attempt(
                isLocked: false,
                isBiometricAuthenticationEnabled: false,
                requiresPasscode: true,
                isAuthenticating: true,
                hasEvaluatedBiometrics: true,
                isSceneActive: false
            ) == .notLocked
        )
        #expect(
            attempt(
                isBiometricAuthenticationEnabled: false,
                requiresPasscode: true,
                isAuthenticating: true,
                hasEvaluatedBiometrics: true,
                isSceneActive: false
            ) == .biometricsDisabled
        )
        #expect(
            attempt(
                requiresPasscode: true,
                isAuthenticating: true,
                hasEvaluatedBiometrics: true,
                isSceneActive: false,
                isUserRequested: true
            ) == .passcodeRequired
        )
        #expect(
            attempt(
                isAuthenticating: true,
                hasEvaluatedBiometrics: true,
                isSceneActive: false
            ) == .alreadyAuthenticated
        )
        #expect(
            attempt(
                hasEvaluatedBiometrics: true,
                isSceneActive: false
            ) == .alreadyEvaluated
        )
    }
    
    // MARK: - Helpers
    
    /// Defaults describe a lock that has just been presented on an active scene.
    private func attempt(
        isLocked: Bool = true,
        isBiometricAuthenticationEnabled: Bool = true,
        requiresPasscode: Bool = false,
        isAuthenticating: Bool = false,
        hasEvaluatedBiometrics: Bool = false,
        isSceneActive: Bool = true,
        isUserRequested: Bool = false
    ) -> Attempt {
        PasscodeCoordinator.biometricAttempt(
            isLocked: isLocked,
            isBiometricAuthenticationEnabled: isBiometricAuthenticationEnabled,
            requiresPasscode: requiresPasscode,
            isAuthenticating: isAuthenticating,
            hasEvaluatedBiometrics: hasEvaluatedBiometrics,
            isSceneActive: isSceneActive,
            isUserRequested: isUserRequested
        )
    }
}
