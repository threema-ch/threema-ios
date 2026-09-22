import Foundation

public enum DataRestoreError: Error {
    case remoteRestoreNotSupported
    case duplicatedIdentityDataInstruction
    case missingIdentityDataInstruction
}
