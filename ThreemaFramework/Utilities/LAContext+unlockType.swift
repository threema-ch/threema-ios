import Foundation
import LocalAuthentication

extension LAContext {
    public enum UnlockType: Int {
        case none
        case touchID
        case faceID
    }

    public func unlockType() -> UnlockType {
        var error: NSError?

        guard canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch biometryType {
        case .none, .opticID:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        @unknown default:
            return .none
        }
    }
}
