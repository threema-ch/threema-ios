import Foundation

enum KeyWrappingError: CustomNSError {
    case badKeyLength
    case badWrappedKeyLength
    case keychainError
    case encryptionFailed
    case decryptionFailed
    
    var errorUserInfo: [String: Any] {
        if self == .keychainError {
            ["ShouldRetry": true]
        }
        else {
            [:]
        }
    }
}
