import LocalAuthentication
import Testing
import ThreemaFramework
@testable import Threema

@MainActor
struct PasscodeCoordinatorRequiresPasscodeTests {

    private typealias BiometricAuthenticationError = TouchIDAuthentication.BiometricAuthenticationError

    @Test(
        "Fallback, no match and lockout require the passcode",
        arguments: [LAError.Code.userFallback, .authenticationFailed, .biometryLockout]
    )
    func requiresPasscode(code: LAError.Code) {
        #expect(PasscodeCoordinator.requiresPasscode(after: BiometricAuthenticationError.underlying(LAError(code))))
        #expect(PasscodeCoordinator.requiresPasscode(after: LAError(code)))
    }

    @Test(
        "Cancelled or never shown prompts leave the biometric button available",
        arguments: [
            LAError.Code.userCancel,
            .systemCancel,
            .appCancel,
            .notInteractive,
            .biometryNotAvailable,
            .biometryNotEnrolled,
        ]
    )
    func keepsBiometrics(code: LAError.Code) {
        #expect(!PasscodeCoordinator.requiresPasscode(after: BiometricAuthenticationError.underlying(LAError(code))))
        #expect(!PasscodeCoordinator.requiresPasscode(after: LAError(code)))
    }

    @Test("Errors from other domains do not count, even with a matching code")
    func ignoresOtherDomains() {
        let error = NSError(domain: "OtherDomain", code: LAError.Code.userFallback.rawValue)
        #expect(!PasscodeCoordinator.requiresPasscode(after: BiometricAuthenticationError.underlying(error)))
    }

    @Test("A changed biometry enrollment is handled by its own alert")
    func ignoresBiometricsChanged() {
        #expect(!PasscodeCoordinator.requiresPasscode(after: BiometricAuthenticationError.biometricsChanged(
            newPolicyDomainState: Data()
        )))
    }
}
