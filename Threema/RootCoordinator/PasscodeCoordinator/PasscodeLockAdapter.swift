import ThreemaFramework

@MainActor
protocol PasscodeLockProtocol: AnyObject {
    var attemptsAllowed: Int { get set }

    func isPasscodeRequired() -> Bool
    func isWithinGracePeriod() -> Bool
    func isBiometricAuthenticationEnabled() -> Bool
    func updateLastUnlockTime()
    func setDefaultSettings()
    func upgradeAccessibility()
}

final class KKPasscodeLockAdapter: PasscodeLockProtocol {
    var attemptsAllowed: Int {
        get {
            Int(KKPasscodeLock.shared().attemptsAllowed)
        }
        set {
            KKPasscodeLock.shared().attemptsAllowed = UInt(newValue)
        }
    }

    func isPasscodeRequired() -> Bool {
        KKPasscodeLock.shared().isPasscodeRequired()
    }
    
    func isWithinGracePeriod() -> Bool {
        KKPasscodeLock.shared().isWithinGracePeriod()
    }
    
    func isBiometricAuthenticationEnabled() -> Bool {
        KKPasscodeLock.shared().isTouchIDOn()
    }

    func updateLastUnlockTime() {
        KKPasscodeLock.shared().updateLastUnlockTime()
    }

    func setDefaultSettings() {
        KKPasscodeLock.shared().setDefaultSettings()
    }

    func upgradeAccessibility() {
        KKPasscodeLock.shared().upgradeAccessibility()
    }
}
