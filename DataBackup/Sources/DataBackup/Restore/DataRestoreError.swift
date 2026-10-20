import Foundation

public enum DataRestoreError: Error {
    case duplicatedIdentityDataInstruction
    case missingIdentityDataInstruction
}
